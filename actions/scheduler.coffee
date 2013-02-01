Team = require "./common/models/Team"
parser = require "./common/utils/xmlParser"
MongoError = require "./common/errors/MongoError"
request = require "request"
async = require "async"


url = process.env.XMLTEAM_URL or "http://sportscaster.xmlteam.com/gateway/php_ci"
username = process.env.XMLTEAM_USERNAME or "fannect"
password = process.env.XMLTEAM_PASSWORD or "k4ns4s"

request.auth(username, password, true)

updateSchedules = (league_key, cb) ->
   league_key

   # Get schedules for league
   Team
   .find({ league_key: league_key })
   .select("schedule")
   .lean()
   .exec (err, teams) ->
      return cb(err) if err
      teamsRunning = 0

      for t in teams
         teamsRunning++
         do (team = t) ->
            team.schedule.length = 0
            request
               url: "#{url}/searchDocuments.php"            
               qs:
                  "team-keys": team.team_key
                  "fixture-keys": "schedule-single-team"
                  "max-result-count": 1
                  "content-returned": "all-content"
            , (err, resp, body) ->
               return cb(err) if err
               parser.parse body, (err, doc) ->
                  return cb(err) if err
                  games = parser.parseGames(doc)

                  gamesRunning = 0
                  for g in games
                     game = parser.schedule.parseGameToJson(g)
                     game.is_home = game.home_key == t.team_key
                     gamesRunning++

                     async.parallel 
                        opponent: () ->
                           if game.is_home
                              Team.findOne { team_key: game.away_key }, "full_name", done
                           else
                              Team.findOne { team_key: game.home_key }, "full_name", done
                        stadium: () ->
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

                        team.schedule.push(game)

                        if --gamesRunning <= 0
                           console.log "TEAM: ", team
                           Team.update { _id: team._id }, team, (err) ->
                              return cb(err) if err
                              cb() if --teamsRunning <= 0 







