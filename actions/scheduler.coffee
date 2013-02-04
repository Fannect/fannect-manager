Team = require "../common/models/Team"
Stadium = require "../common/models/Stadium"
parser = require "../common/utils/xmlParser"
request = require "request"
async = require "async"
_ = require "underscore"

url = process.env.XMLTEAM_URL or "http://fannect:k4ns4s@sportscaster.xmlteam.com/gateway/php_ci"

scheduler = module.exports =

   update: (league_key, cb) ->
      # Get schedules for league
      Team
      .find({ league_key: league_key })
      .select("schedule team_key")
      .lean()
      .exec (err, teams) ->
         return cb(err) if err
         return cb(new Error("No teams found")) if teams?.length == 0
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
                     "earliest-date-time": "20130101T010000"
                  timeout: 1200000
               , (err, resp, body) ->
                  return cb(err) if err
                  parser.parse body, (err, doc) ->
                     return cb(err) if err

                     if parser.isEmpty(doc)
                        return cb(new Error("No XML Team results for: #{team.team_key}"))      
                     
                     games = parser.schedule.parseGames(doc)

                     if not games
                        return new Error(("No XML Team results for: #{team.team_key}"))  

                     gamesRunning = 0
                     for g in games
                        do (gameStr = g) ->
                           game = parser.schedule.parseGameToJson(gameStr)
                           return if game.is_past
                           
                           game.is_home = game.home_key == team.team_key
                           gamesRunning++

                           async.parallel 
                              opponent: (done) ->
                                 if game.is_home
                                    Team.findOne { team_key: game.away_key }, "full_name", done
                                 else
                                    Team.findOne { team_key: game.home_key }, "full_name", done
                              stadium: (done) ->
                                 Stadium.findOne { stadium_key: game.stadium_key }, done
                           , (err, results) ->
                              return cb(err) if err

                              game.opponent = results.opponent?.full_name
                              game.opponent_id = results.opponent?._id
                              game.stadium_name = results.stadium?.name or ""
                              game.stadium_location = results.stadium?.location or ""
                              game.stadium_coords = results.stadium?.coords or []
                              delete game.home_key
                              delete game.away_key
                              delete game.stadium_key
                              delete game.is_past
                              team.schedule.season.push(game)
                             
                              if --gamesRunning <= 0
                                 # Remove id to allow updating
                                 id = team._id 
                                 delete team._id

                                 # sort games to be in correct order
                                 team.schedule.season = _.sortBy(team.schedule.season, (e) -> (e.game_time / -1))
                                 team.schedule.pregame = team.schedule.season.shift()

                                 Team.update { _id: id }, team, (err) ->
                                    return cb(err) if err

                                    console.log "Finished: #{team.team_key} (#{teamsRunning - 1} left)"
                                    if --teamsRunning <= 0 
                                       cb() 







