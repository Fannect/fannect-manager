Team = require "../common/models/Team"
Stadium = require "../common/models/Stadium"
sportsML = require "../common/sportsMLParser/sportsMLParser"
request = require "request"
async = require "async"
_ = require "underscore"
fs = require "fs"

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
      .exec (err, teams) ->
         return cb(err) if err
         return cb(new Error("#{white}No teams found.#{reset}")) if teams?.length == 0
         
         teamsRunning = teams.length
         teamErrors = []

         q = async.queue (team, callback) ->
               scheduler.updateTeam team, (err) ->
                  console.log err if err
                  console.log "#{white}Finished: #{team.team_key} (#{green}#{teamsRunning--} left#{white})#{reset}"
                  callback()
            , 8

         q.drain = cb;
         q.push(t) for t in teams

   updateTeam: (team, cb) ->
      team.schedule = {} unless team.schedule
      team.schedule.season = []
      request.get
         url: "#{url}/searchDocuments.php"            
         qs:
            "team-keys": team.team_key
            "fixture-keys": "schedule-single-team"
            "revision-control": "latest-only"
            "content-returned": "all-content"
            "earliest-date-time": "20130901T010000"
            # "date-window": 200000
         timeout: 1800000
      , (err, resp, body) ->
         # console.log body
         # console.log resp
         return cb(err) if err
         sportsML.schedule body, (err, schedule) ->
            return cb(err) if err
            unless schedule
               return cb("#{red}No XML Team results for: #{team.team_key}#{reset}")      
            
            scheduler.updateSchedule(team, schedule, cb)

   updateTeamWithFile: (team, file_name, cb) ->
      team.schedule = {} unless team.schedule
      team.schedule.season = []
      fs.readFile file_name, "utf8", (err, xml) ->
         return cb(err) if err
         sportsML.schedule xml, (err, schedule) ->
            return cb(err) if err

            unless schedule
               return cb("#{red}No XML Team results for: #{team.team_key}#{reset}")      
         
            scheduler.updateSchedule(team, schedule, cb)
      
   updateSchedule: (team, schedule, cb) ->
      games = schedule.sportsEvents

      if not games
         return cb("#{red}No XML Team results for: #{team.team_key}#{reset}")  

      gamesRunning = 0
      gameErrors = []


      for game, i in games
         continue unless (game.eventMeta.isBefore() and game.isValid())

         gamesRunning++

         scheduler.addGame team, game, (err) ->
            if err then gameErrors.push(err)
            if --gamesRunning <= 0

               # sort games to be in correct order
               team.schedule.season = _.sortBy(team.schedule.season, (e) -> (e.game_time / 1))
               team.schedule.pregame = team.schedule.season.shift()

               team.save (err) ->
                  return cb(err) if err
                  return cb(gameErrors) if gameErrors.length > 0
                  cb()

      # return if no games to run
      if gamesRunning == 0
         cb("#{white}No future games to schedule for: #{team.team_key}#{reset}")
               
   addGame: (team, game, cb) ->
      async.parallel 
         opponent: (done) ->
            if game.isHome(team.team_key)
               Team.findOne { team_key: game.away_team.team_key }, "full_name", done
            else
               Team.findOne { team_key: game.home_team.team_key }, "full_name", done
         stadium: (done) ->

            # Hack get change the field from KU => NE because both have same key
            if game.home_team.team_key == "l.ncaa.org.mfoot-t.553"
               game.eventMeta.stadium_key = "Memorial_Stadium_NE"
               
            Stadium.findOne
               $or: [
                  { stadium_key: game.eventMeta.stadium_key }
                  { alias_keys: game.eventMeta.stadium_key }
               ], done
      , (err, results) ->
         return cb(err) if err

         if not results.opponent
            if game.isHome(team.team_key)
               console.log "#{red}Fail: #{game.home_team.team_key}, can't find opponent: #{game.away_team.team_key}#{reset}"
            else
               console.log "#{red}Fail: #{game.away_team.team_key}, can't find opponent: #{game.home_team.team_key}#{reset}"
            cb()

         if not results.stadium
            console.log "#{red}Unable to find stadium: #{game.eventMeta.stadium_key}#{reset} (stadium_key)"
            
         team.schedule.season.push
            event_key: game.eventMeta.event_key
            game_time: game.eventMeta.start_date_time
            is_home: game.isHome(team.team_key)
            opponent: results.opponent?.full_name
            opponent_id: results.opponent?._id
            stadium_name: results.stadium?.name or ""
            stadium_location: results.stadium?.location or ""
            stadium_coords: results.stadium?.coords or []
            coverage: game.eventMeta.coverage
            
         cb(null)

                         





