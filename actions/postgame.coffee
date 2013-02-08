Team = require "../common/models/Team"
parser = require "../common/utils/xmlParser"
request = require "request"
async = require "async"
_ = require "underscore"
Log = require "../utils/Log"

url = process.env.XMLTEAM_URL or "http://fannect:k4ns4s@sportscaster.xmlteam.com/gateway/php_ci"

# Colors
red = "\u001b[31m"
green = "\u001b[32m"
white = "\u001b[37m"
reset = "\u001b[0m"

log = new Log()

postgame = module.exports =

   update: (cb) ->
      time = new Date(new Date() / 1 - 1000 * 60 * 120)
      log.empty()

      Team
      .find({ "schedule.pregame.game_time": { $lt: time }})
      .select("schedule team_key")
      .exec (err, teams) ->
         return cb(err) if err

         if teams.length <= 0
            log.write "#{white}No teams found to updated.#{reset}"
            return cb()
         else
            log.write "#{white}Found #{green}#{teams.length}#{white} in progress..#{reset}"
         
         count = 0
         for team in teams
            count++
            postgame.updateTeam team, (err) ->
               if --count <= 0
                  log.sendErrors("Postgame", cb)

   updateTeam: (team, cb) ->
      request.get
         url: "#{url}/searchDocuments.php"            
         qs:
            "team-keys": team.team_key
            "fixture-keys": "event-stats"
            "max-result-count": 1
            "content-returned": "all-content"
         timeout: 10000
      , (err, resp, body) ->
         return cb(err) if err   

         parser.parse body, (err, doc) ->
            return cb(err) if err

            outcome = parser.boxScores.parseBoxScoreToJson(doc)

            if not outcome.is_past
               log.write("In progress: #{team.team_key}")
               return cb()
               
            # Return if no real data
            if not (outcome.opponent_score and outcome.score)
               log.error("#{red}Failed: couldn't find score for #{team.team_key}#{reset}")
               return cb() 

            if team.schedule.season?.length > 0
               nextgame = _.sortBy(team.schedule.season, (e) -> (e.game_time / 1))[0]

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
               if err
                  log.error("#{red}Failed: couldn't update pregame/postgame for #{team.team_key}#{reset} (team_key)")
               else
                  log.write("#{white}Finished: #{team.team_key}#{reset} (team_key)")
               cb()

               
