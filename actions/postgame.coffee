Team = require "../common/models/Team"
parser = require "../common/utils/xmlParser"
request = require "request"
async = require "async"
_ = require "underscore"
log = require "../utils/Log"

url = process.env.XMLTEAM_URL or "http://fannect:k4ns4s@sportscaster.xmlteam.com/gateway/php_ci"

# Colors
red = "\u001b[31m"
green = "\u001b[32m"
white = "\u001b[37m"
reset = "\u001b[0m"

bookie = require "./bookie"

postgame = module.exports =

   update: (runBookie, cb) ->
      time = new Date(new Date() / 1 - 1000 * 60 * 120)
      log.empty()
      log.write "#{white}Starting postgame... #{green}#{new Date()}#{reset}"

      Team
      .find({ "schedule.pregame.game_time": { $lt: time }})
      .select("schedule team_key sport_key needs_processing is_processing points")
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
            postgame.updateTeam team, runBookie, (err) ->
               if --count <= 0
                  log.sendErrors("Postgame", cb)

   updateTeam: (team, runBookie, cb) ->
      request.get
         url: "#{url}/searchDocuments.php"            
         qs:
            "team-keys": team.team_key
            "fixture-keys": "event-stats"
            "content-returned": "all-content"
         timeout: 10000
      , (err, resp, body) ->
         return cb(err) if err   

         parser.parse body, (err, doc) ->
            return cb(err) if err

            sportsEvents = parser.boxScores.parseEvents(doc)

            if not (sportsEvents?.length >= 1)
               log.write("In progress: #{team.team_key}")
               return cb()

            alreadyChecked = []
            q = async.queue (ev, callback) ->
               
               outcome = parser.boxScores.parseBoxScoreToJson(ev)

               return callback() if (outcome.event_key in alreadyChecked)
               alreadyChecked.push outcome.event_key

               if not outcome.is_past or outcome.event_key != team.schedule.pregame.event_key
                  log.write("In progress: #{team.team_key}")
                  return callback()

               # Return if no real data
               if not (outcome.home?.team_key == team.team_key or outcome.away?.team_key == team.team_key)
                  log.error("#{red}Failed: couldn't find score for #{team.team_key}#{reset}")
                  return callback() 

               if team.schedule.season?.length > 1
                  nextgame = _.sortBy(team.schedule.season, (e) -> (e.game_time / 1))[0]

               oldpregame = team.schedule.pregame
               
               # Handle pregame move to postgame
               team.schedule.postgame.game_time = oldpregame.game_time
               team.schedule.postgame.opponent = oldpregame.opponent
               team.schedule.postgame.opponent_id = oldpregame.opponent_id
               team.schedule.postgame.is_home = oldpregame.is_home
               team.schedule.postgame.attendance = outcome.attendance

               if outcome.home.team_key == team.team_key
                  team.schedule.postgame.score = outcome.home.score
                  team.schedule.postgame.opponent_score = outcome.away.score
                  team.schedule.postgame.won = outcome.home.won
               else
                  team.schedule.postgame.score = outcome.away.score
                  team.schedule.postgame.opponent_score = outcome.home.score
                  team.schedule.postgame.won = outcome.away.won

               # Handle pregame
               team.set("schedule.pregame", nextgame)
               team.schedule.season.remove(nextgame)
               
               team.needs_processing = true


               if runBookie
                  log.write("#{white}Finished postgame, starting bookie: #{team.team_key}#{reset} (team_key)")
                  bookie.processTeam team, (err) ->
                     if err
                        log.error("#{red}Failed: couldn't update bookie for #{team.team_key}#{reset} (team_key)")
                     else
                        log.write("#{white}Finished bookie: #{team.team_key}#{reset} (team_key)")
                     callback()
               else
                  team.save (err) ->
                     if err
                        log.error("#{red}Failed: couldn't update pregame/postgame for #{team.team_key}#{reset} (team_key)")
                     else
                        log.write("#{white}Finished: #{team.team_key}#{reset} (team_key)")
                     callback()
            , 5
                  
            q.push(ev) for ev in sportsEvents
            q.drain = cb
            