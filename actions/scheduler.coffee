Team = require "../common/models/Team"
Stadium = require "../common/models/Stadium"
parser = require "../common/utils/xmlParser"
request = require "request"
async = require "async"
_ = require "underscore"

url = process.env.XMLTEAM_URL or "http://fannect:k4ns4s@sportscaster.xmlteam.com/gateway/php_ci"

# Colors
red = "\u001b[31m"
green = "\u001b[32m"
white = "\u001b[37m"
reset = "\u001b[0m"

scheduler = module.exports =

   update: (league_key, cb) ->
      # Get schedules for league
      Team
      .find({ league_key: league_key })
      .select("schedule team_key")
      .lean()
      .exec (err, teams) ->
         return cb(err) if err
         return cb(new Error("#{white}No teams found.#{reset}")) if teams?.length == 0
         
         teamsRunning = 0
         teamErrors = []

         for t in teams
            do (team = t) -> 
               teamsRunning++
               scheduler.updateTeam team, (err) ->
                  teamErrors.push(err) if err

                  console.log "#{white}Finished: #{team.team_key} (#{green}#{teamsRunning - 1} left#{white})#{reset}"
                  if --teamsRunning <= 0 
                     cb() 

   updateTeam: (team, cb) ->
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
               return cb("#{red}No XML Team results for: #{team.team_key}#{reset}")      
            
            games = parser.schedule.parseGames(doc)

            if not games
               return cb("#{red}No XML Team results for: #{team.team_key}#{reset}")  

            gamesRunning = 0
            gameErrors = []

            for g in games
               continue unless g
               game = parser.schedule.parseGameToJson(g)
               continue if game.is_past

               gamesRunning++
               game.is_home = game.home_key == team.team_key

               scheduler.addGame game, (err, gameObj) ->
                  if err then gameErrors.push(err)
                  else team.schedule.season.push(gameObj)

                  if --gamesRunning <= 0
                     # Remove id to allow updating
                     id = team._id 
                     delete team._id
                  
                     # sort games to be in correct order
                     team.schedule.season = _.sortBy(team.schedule.season, (e) -> (e.game_time / 1))
                     team.schedule.pregame = team.schedule.season.shift()

                     Team.update { _id: id }, team, (err) ->
                        return cb(err) if err
                        return cb(gameErrors) if gameErrors.length > 0

                        cb()

   addGame: (game, cb) ->
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

         if not results.opponent
            if game.is_home
               console.log "#{red}Fail: #{game.home_key}, can't find opponent: #{game.away_key}#{reset}"
            else
               console.log "#{red}Fail: #{game.away_key}, can't find opponent: #{game.home_key}#{reset}"

         game.opponent = results.opponent?.full_name
         game.opponent_id = results.opponent?._id
         game.stadium_name = results.stadium?.name or ""
         game.stadium_location = results.stadium?.location or ""
         game.stadium_coords = results.stadium?.coords or []
         delete game.home_key
         delete game.away_key
         delete game.stadium_key
         delete game.is_past

         cb(null, game)

                         





