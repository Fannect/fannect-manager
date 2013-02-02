Team = require "../common/models/Team"
Stadium = require "../common/models/Stadium"
parser = require "../common/utils/xmlParser"
request = require "request"
async = require "async"

url = process.env.XMLTEAM_URL or "http://sportscaster.xmlteam.com/gateway/php_ci"
username = process.env.XMLTEAM_USERNAME or "fannect"
password = process.env.XMLTEAM_PASSWORD or "k4ns4s"

scheduler = module.exports =

   update: (league_key, cb) ->
      # Get schedules for league
      Team
      .find({ league_key: league_key })
      .select("schedule team_key")
      .lean()
      .exec (err, teams) ->
         return cb(err) if err
         return cb(new Error("No teams found")) if teams.length == 0
         teamsRunning = 0

         for t in teams
            teamsRunning++
            do (team = t) ->
               team.schedule = {} unless team.schedule
               team.schedule.season = []

               request.get
                  url: "#{url}/searchDocuments.php"            
                  qs:
                     "team-keys": team.team_key
                     "fixture-keys": "schedule-single-team"
                     "max-result-count": 1
                     "content-returned": "all-content"
                  auth:
                     user: username
                     pass: password
                     sendImmediately: true
               , (err, resp, body) ->
                  return cb(err) if err
                  parser.parse body, (err, doc) ->
                     return cb(err) if err
                     games = parser.schedule.parseGames(doc)

                     gamesRunning = 0
                     for g in games
                        game = parser.schedule.parseGameToJson(g)
                        continue if game.is_past
                        
                        game.is_home = game.home_key == t.team_key
                        gamesRunning++

                        async.parallel 
                           opponent: (done) ->
                              if game.is_home
                                 Team.findOne { team_key: game.away_key }, "full_name", done
                              else
                                 Team.findOne { team_key: game.home_key }, "full_name", done
                           stadium: (done) ->
                              Stadium.findOne { key: game.stadium_key }, done
                        , (err, results) ->
                           return cb(err) if err
                           game.opponent = results.opponent.full_name
                           game.opponent_id = results.opponent._id
                           game.stadium_name = results.stadium.name
                           game.stadium_location = results.stadium.location
                           game.stadium_coords = results.stadium.coords
                           delete game.home_key
                           delete game.away_key
                           delete game.stadium_key
                           team.schedule.season.push(game)
                          
                           if --gamesRunning <= 0
                              # Remove id to allow updating
                              id = team._id 
                              delete team._id
                              Team.update { _id: id }, team, (err) ->
                                 return cb(err) if err
                                 if --teamsRunning <= 0 
                                    cb() 







