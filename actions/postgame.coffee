Team = require "../common/models/Team"
parser = require "../common/utils/xmlParser"
request = require "request"
async = require "async"

url = process.env.XMLTEAM_URL or "http://fannect:k4ns4s@sportscaster.xmlteam.com/gateway/php_ci"

postgame = module.exports =

   update: (cb) ->
      time = new Date(new Date() / 1 - 1000 * 60 * 120)

      Team
      .find({ "schedule.pregame.game_time": { $lt: time }})
      .select({ "schedule.pregame": 1, "schedule.postgame": 1, "schedule.season": { $slice: [0, 1]}})
      .exec (err, teams) ->
         return cb(err) if err
         return cb(err) unless teams.length > 0
         
         count = 0
         for t in teams
            do (team = t) ->
               count++
               request.get
                  url: "#{url}/searchDocuments.php"            
                  qs:
                     "team-keys": team._id
                     "fixture-keys": "event-stats"
                     "max-result-count": 1
                     "content-returned": "all-content"
               , (err, resp, body) ->
                  return cb(err) if err   

                  parser.parse body, (err, doc) ->
                     return cb(err) if err

                     outcome = parser.boxScores.parseBoxScoreToJson(doc)

                     # Return if no real data
                     if not (outcome.opponent_score and outcome.score)
                        return cb(null, "No outcome")

                     nextgame = team.schedule.season[0]
                     oldpregame = team.schedule.pregame
                     
                     # Handle pregame move to postgame
                     team.schedule.postgame.game_time = oldpregame.game_time
                     team.schedule.postgame.opponent = oldpregame.opponent
                     team.schedule.postgame.opponent_id = oldpregame.opponent_id
                     team.schedule.postgame.is_home = oldpregame.is_home
                     team.schedule.postgame.score = outcome.score
                     team.schedule.postgame.opponent_score = outcome.opponent_score
                     team.schedule.postgame.won = outcome.won
                     team.schedule.postgame.attendance = outcome.attendance

                     # Handle pregame
                     team.set("schedule.pregame", nextgame)
                     team.schedule.season.remove(nextgame)
                     
                     team.save (err) ->
                        return cb(err) if err   
                        if --count <= 0 then cb() 
