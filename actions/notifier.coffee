Team = require "../common/models/Team"
request = require "request"
async = require "async"
log = require "../utils/Log"

# Colors
red = "\u001b[31m"
green = "\u001b[32m"
white = "\u001b[37m"
reset = "\u001b[0m"

parse = new (require "kaiseki")(
   process.env.PARSE_APP_ID or "EP2BOLtJpCtZP1gMWc65YxIMUvum8qqjKswCESJi",
   process.env.PARSE_API_KEY or "G8ZsbWBu0Is83VVsyvWcJeAqXhL0FI7cQeJvSHxU"
)

notifier = module.exports =
   
   sendAll: (hours_out, cb) ->
      if typeof hours_out == "function"
         cb = hours_out
         hours_out = null
      hours_out = 22 if hours_out == null

      log.empty()
      log.write "#{white}Starting notifier... #{green}#{new Date()}#{reset}"
      
      milliseconds = 3.6e6
      now = new Date()
      until_time = (now / 1) + (milliseconds * hours_out)

      Team
      .find({ "schedule.pregame.game_time": { $gt: now, $lt: until_time } })
      .select("full_name mascot")
      .exec (err, teams) ->
         return cb(err) if err

         # Log state
         if teams.length <= 0
            log.write "#{white}No teams found to notify.#{reset}"
            return cb()
         else
            log.write "#{white}Found #{green}#{teams.length}#{white} to notify..#{reset}"
         
         q = async.queue (team, callback) ->
            parse.sendPushNotification 
               channels: ["team_#{team._id}"]
               data: 
                  alert: "It's Gameday for #{team.full_name}!"
                  event: "gameday"
                  title: "Gameday"
                  teamId: team._id
            , (err) ->
               if err
                  log.err "#{red}Failed to notify: #{team._id} #{reset} (team_id)"
               else
                  log.write "#{white}Finished notifying: #{team.full_name} - #{team._id} #{reset} (team_id)"
               callback()
         , 20
         
         q.push(team) for team in teams
         q.drain = () ->
            log.sendErrors("Notify", cb)
