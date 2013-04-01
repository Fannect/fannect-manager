Team = require "../common/models/Team"
TeamProfile = require "../common/models/TeamProfile"
Group = require "../common/models/Group"
request = require "request"
async = require "async"
log = require "../utils/Log"
url = process.env.XMLTEAM_URL or "http://fannect:k4ns4s@sportscaster.xmlteam.com/gateway/php_ci"
sportsML = require "../common/sportsMLParser/sportsMLParser"

TeamRankUpdateJob = require "../common/jobs/TeamRankUpdateJob"

# Colors
red = "\u001b[31m"
green = "\u001b[32m"
white = "\u001b[37m"
reset = "\u001b[0m"

batchSize = parseInt(process.env.BATCH_SIZE or 50)

bookie = module.exports =
   
   updateAll: (cb) ->
      log.empty()
      log.write "#{white}Starting bookie... #{green}#{new Date()}#{reset}"
      bookie.findAndUpdate (err) ->
         log.error "#{red}Failed: #{err}#{reset}" if err
         log.sendErrors("Postgame", cb)

   findAndUpdate: (cb) ->
      Team.findOneAndUpdate { needs_processing: true, is_processing: { $ne: true }}
      , { is_processing: true }
      , { select: "full_name schedule sport_key needs_processing is_processing points" }
      , (err, team) ->
         return cb(err) if err 
         return cb() unless team

         bookie.processTeam team, (err) ->
            if err
               log.error "#{red}Failed to process team: #{team._id} (team_id): #{err}#{reset}"
            else
               log.write "#{white}Finished: #{team._id} #{reset}(team_id)"

            bookie.findAndUpdate(cb)

   processTeam: (team, cb) ->
      bookie.processBatch team, 0, (err) ->
         log.errors("#{red}Process: Failed: #{err.stack}#{reset}") if err
         return cb(err) if err
         team.is_processing = false
         team.needs_processing = false
         
         # queue rank update job
         job = new TeamRankUpdateJob({ team_id: team._id })
         job.queue(cb)

   processBatch: (team, skip, cb) ->
      TeamProfile
      .find({ team_id: team._id })
      .sort("_id")
      .skip(skip)
      .limit(batchSize)
      .select("points events waiting_events")
      .exec (err, profiles) ->
         if err
            log.error "#{red}Process: Failed: on #{team._id} (team_id), #{err}#{reset}"
            return cb(err)
         if profiles.length < 1
            log.write "Process: No team profiles for: #{team._id} (team_id)" if skip == 0
            return cb()

         run = [
            (done) -> 
               if profiles and profiles.length == batchSize
                  bookie.processBatch team, skip + batchSize, (err) -> 
                     log.error "#{red}Process: Failed: #{err.stack}#{reset}" if err
                     done()
               else 
                  done()
         ]

         for p in profiles
            do (profile = p) ->
               profile.processEvents(team) 
               run.push (done) ->
                  profile.save (err) ->
                     log.error "#{red}Process: Failed: #{err.stack}#{reset}" if err
                     done()

         async.parallel run, (err) ->
            log.error "#{red}Process: Failed: #{err.stack}#{reset}" if err
            cb()
