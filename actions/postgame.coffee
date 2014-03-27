Team = require "../common/models/Team"
request = require "request"
async = require "async"
_ = require "underscore"
log = require "../utils/Log"
sportsML = require "../common/sportsMLParser/sportsMLParser"
scheduler = require "./scheduler"
TeamRankUpdateJob = require "../common/jobs/TeamRankUpdateJob"

url = process.env.XMLTEAM_URL or "http://fannect:k4ns4s@sportscaster.xmlteam.com/gateway/php_ci"

# Colors
red = "\u001b[31m"
green = "\u001b[32m"
white = "\u001b[37m"
reset = "\u001b[0m"

bookie = require "./bookie"

postgame = module.exports =

   update: (runBookie, cb) ->
      time = new Date(new Date() / 1 - 1000 * 60 * 90)
      log.empty()
      log.write "#{white}Starting postgame... #{green}#{new Date()}#{reset}"

      Team
      .find({ "schedule.pregame.game_time": { $lt: time }})
      .select("schedule full_name team_key sport_key needs_processing is_processing points")
      .exec (err, teams) ->
         return cb(err) if err

         # Log state
         if teams.length <= 0
            log.write "#{white}No teams found to updated.#{reset}"
            return cb()
         else
            log.write "#{white}Found #{green}#{teams.length}#{white} in progress..#{reset}"
         
         # Get all the event keys
         all_event_keys = []
         sets_of_keys = [[]]
         set_index = 0
         for t in teams 
            if (k = t.schedule.pregame.event_key) and not (k in all_event_keys)
               if sets_of_keys[set_index].length >= 10
                  sets_of_keys[++set_index] = []
               sets_of_keys[set_index].push(k)
               all_event_keys.push(k)

         set_queue = async.queue (key_set, done) ->
            
            # Exit if there are no keys in set
            if (key_set.keys.length == 0) 
               return done()
            
            getEvents key_set.keys.join(","), (err, events) ->
               results = []
               for t in teams 
                  s = _.find events.sportsEvents, (e) -> e.eventMeta.event_key == t?.schedule.pregame?.event_key
                  if s 
                     results.push   
                        team: t
                        stats: s

               q = async.queue (event, callback) ->
                  gameUpdate event.team, event.stats, runBookie, () ->
                     # errors are already logged so swallow at this point
                     callback()
               , 10

               q.push(event) for event in results
               q.drain = done
         , 2

         set_queue.push({ keys: set }) for set in sets_of_keys
         set_queue.drain = () -> log.sendErrors("Postgame", cb)


   updateTeam: (team, runBookie, cb) ->
      return cb("No pregame...") unless team?.schedule?.pregame?.event_key
      getEvents team.schedule.pregame.event_key, (err, events) ->
         event = _.find events.sportsEvents, (e) -> e.eventMeta.event_key == team.schedule.pregame.event_key
         gameUpdate(team, event, runBookie, cb)

getEvents = (event_keys, cb) ->
   event_keys = event_keys.join(",") if typeof event_keys != "string" 
   request.get
      url: "#{url}/getEvents.php"            
      qs:
         "event-keys": event_keys
         "content-returned": "metadata"
         "revision-control": "latest-only"
      timeout: 120000
   , (err, resp, body) ->
      if err
         log.error("#{red}Failed: XML Team event stats failed #{event_keys}#{reset} \nError:\n#{JSON.stringify(err)}")
         return cb(err) 

      sportsML.eventStats body, (err, eventStats) ->
         if err
            log.error("#{red}Failed: couldn't parse event stats for #{event_keys}#{reset} \nError:\n#{JSON.stringify(err)}")
            return cb(err)    

         cb(null, eventStats)

gameUpdate = (team, eventStatsML, runBookie, cb) ->
   # Manually added in games
   if !eventStatsML
      log.write("#{white}No event data for team: #{team.team_key} #{reset}(team_key)")
      return cb()

   if eventStatsML.eventMeta.isBefore() or not team?.schedule?.pregame?.event_key
      log.write("#{white}In progress: #{team.team_key} #{reset}(team_key)")
      return cb() 

   if eventStatsML.eventMeta.isPast()

      unless eventStatsML?.eventMeta?.docs["event_stats"]?
         log.write("No event stats yet: #{team.team_key}")
         return cb()

      request.get
         url: "#{url}/getDocuments.php"            
         qs:
            "doc-ids": eventStatsML?.eventMeta?.docs["event_stats"]
            "content-returned": "all-content"
         timeout: 120000
      , (err, resp, body) ->
         if err
            log.error("#{red}Failed: XML Team box score failed #{team.team_key}#{reset} \nError:\n#{JSON.stringify(err)}")
            return cb(err) 

         sportsML.eventStats body, (err, boxscores) ->
            if err
               log.error("#{red}Failed: couldn't parse box score for #{team.team_key}#{reset} \nError:\n#{JSON.stringify(err)}")
               return cb(err)

            unless boxscores
               return log.write("No box scores in document for #{team.team_key}")
               return cb()

            # Ensure it is the correct event
            outcome = _.find boxscores.sportsEvents, (e) -> e.eventMeta.event_key == team.schedule.pregame.event_key

            # Return if not the correct event
            unless outcome
               log.error("#{red}Event was not found in box scores for #{team.team_key}#{reset}")
               return cb()

            # Sort schedules
            if team.schedule.season?.length > 0
               nextgame = _.sortBy(team.schedule.season, (e) -> (e.game_time / 1))[0]

            oldpregame = team.schedule.pregame

            # Handle pregame move to postgame
            team.schedule.postgame.game_time = oldpregame.game_time
            team.schedule.postgame.event_key = oldpregame.event_key
            team.schedule.postgame.opponent = oldpregame.opponent
            team.schedule.postgame.opponent_id = oldpregame.opponent_id
            team.schedule.postgame.stadium_id = oldpregame.stadium_id
            team.schedule.postgame.stadium_name = oldpregame.stadium_name
            team.schedule.postgame.stadium_location = oldpregame.stadium_location
            team.schedule.postgame.is_home = oldpregame.is_home
            team.schedule.postgame.attendance = outcome.eventMeta.attendance

            if team.schedule.postgame.is_home
               team.schedule.postgame.score = outcome.home_team.score
               team.schedule.postgame.opponent_score = outcome.away_team.score
               team.schedule.postgame.won = outcome.home_team.won()
            else
               team.schedule.postgame.score = outcome.away_team.score
               team.schedule.postgame.opponent_score = outcome.home_team.score
               team.schedule.postgame.won = outcome.away_team.won()

            # Handle set next pregame if one exists
            if team.schedule.season?.length > 0
               nextgame = _.sortBy(team.schedule.season, (e) -> (e.game_time / 1))[0]
               team.set("schedule.pregame", nextgame)
               team.schedule.season.remove(nextgame)
            else
               team.schedule.pregame = undefined
            
            # Set the needs processing flag (only used if bookie is not immediately run)
            team.needs_processing = true

            team.save (err) ->
               if err
                  log.error("#{red}Failed: couldn't update pregame/postgame for #{team.team_key}#{reset} (team_key)\nERROR:#{err?.toString()}")
                  return cb()

               # Run bookie if required
               if runBookie
                  log.write("#{white}Finished postgame, starting bookie: #{team.team_key}#{reset} (team_key)")
                  return bookie.processTeam(team, cb)
               else
                  log.write("#{white}Finished: #{team.team_key}#{reset} (team_key)")
               
               return cb()

   else if eventStatsML.eventMeta.isPostponed()
      # run scheduler to find next game
      log.write("#{white}Game has been postponed for #{team.team_key}, running scheduler#{reset}")
      scheduler.updateTeam(team, cb)
   else
      # game is still in progress (or XML Team hasn't published box scores)
      log.write("#{white}In progress: #{team.team_key} #{reset}(team_key)")
      return cb()
