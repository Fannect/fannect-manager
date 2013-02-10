Team = require "../common/models/Team"
TeamProfile = require "../common/models/TeamProfile"
parser = require "../common/utils/xmlParser"
request = require "request"
async = require "async"
Log = require "../utils/Log"
url = process.env.XMLTEAM_URL or "http://fannect:k4ns4s@sportscaster.xmlteam.com/gateway/php_ci"

# Colors
red = "\u001b[31m"
green = "\u001b[32m"
white = "\u001b[37m"
reset = "\u001b[0m"

log = new Log()

batchSize = parseInt(process.env.BATCH_SIZE or 50)

bookie = module.exports =
   
   updateAll: (cb) ->
      log.empty()
      bookie.findAndUpdate (err) ->
         log.error "#{red}Failed: #{err}#{reset}" if err
         log.sendErrors("Postgame", cb)

   findAndUpdate: (cb) ->
      Team.findOneAndUpdate { needs_processing: true, is_processing: { $ne: true }}
      , { is_processing: true }
      , { select: "schedule.postgame sport_key needs_processing is_processing points" }
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
         return cb(err) if err
         team.is_processing = false
         team.needs_processing = false
         bookie.rankTeam team, cb

   processBatch: (team, skip, cb) ->
      TeamProfile
      .find({ team_id: team._id })
      .skip(skip)
      .limit(batchSize)
      .select("schedule.postgame points events waiting_events")
      .exec (err, profiles) ->
         if err
            log.error "#{red}Failed: on #{team._id} (team_id), #{err}#{reset}"
            return cb(err)
         if profiles.length < 1
            log.write "#{white}No team profiles for: #{team._id}#{reset} (team_id)" if skip == 0
            return cb()

         run = [
            (done) -> 
               if profiles and profiles.length == batchSize
                  bookie.processBatch(team, skip + batchSize, cb)
               else 
                  cb()
         ]

         for p in profiles
            do (profile = p) ->
               profile.processEvents(team) 
               run.push (done) -> profile.save()

         async.parallel run, cb

   rankTeam: (team, cb) ->
      # Reset points so they can be freshly added
      team.points = 
         overall: 0
         passion: 0
         dedication: 0
         knowledge: 0
      
      bookie.rankBatch team, 0, (err) ->
         return cb(err) if err
         team.save(cb)

   rankBatch: (team, skip, cb) ->
      TeamProfile
      .find({ team_id: team._id })
      .skip(skip)
      .limit(batchSize)
      .sort("-points.overall")
      .select("rank points")
      .exec (err, profiles) ->
         if err
            log.error("#{red}Failed to rank team: #{team._id} (team_id), #{err}#{reset}")
            return cb(err)
         if profiles.length < 1
            log.write("#{white}No team profiles for: #{team._id}#{reset} (team_id)") if skip == 0
            return cb(err)

         async.parallel
            batch: (done) ->
               if profiles.length == batchSize
                  bookie.rankBatch(team, skip + batchSize, done)
               else
                  done()
            teamProfiles: (done) ->
               rank = skip + 1
               count = 0
               for profile in profiles
                  count++

                  # Add points to team
                  team.points.overall += profile.points.overall
                  team.points.passion += profile.points.passion
                  team.points.dedication += profile.points.dedication
                  team.points.knowledge += profile.points.knowledge

                  profile.rank = rank++
                  profile.save (err) -> 
                     return done(err) if err
                     done() if --count == 0
         , cb



