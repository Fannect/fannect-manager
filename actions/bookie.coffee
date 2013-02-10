Team = require "../common/models/Team"
TeamProfile = require "../common/models/TeamProfile"
parser = require "../common/utils/xmlParser"
request = require "request"
async = require "async"
Log = require "../utils/Log"
EventProcessor = require "../common/utils/EventProcessor"

url = process.env.XMLTEAM_URL or "http://fannect:k4ns4s@sportscaster.xmlteam.com/gateway/php_ci"

# Colors
red = "\u001b[31m"
green = "\u001b[32m"
white = "\u001b[37m"
reset = "\u001b[0m"

log = new Log()

batchSize = parseInt(process.env.BATCH_SIZE or 50)

bookie = module.exports =
   
   # updateAll: (cb) ->


   # findAndUpdate: () ->

   processTeam: (team, cb) ->
      bookie.processBatch(team, 0, cb)

   processBatch: (team, skip, cb) ->
      TeamProfile
      .find({ team_id: team._id })
      .skip(skip)
      .limit(batchSize)
      .select("schedule.postgame points events waiting_events")
      .exec (err, profiles) ->
         if err
            log.error("#{red}Failed: on #{team._id} (team_id), #{err}#{reset}")
            return cb(err)
         if profiles.length < 1
            log.write("#{white}No team profiles for: #{team._id}#{reset} (team_id)") if skip == 0
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

   rankTeam: (teamId, cb) ->
      bookie.rankBatch(teamId, 0, cb)

   rankBatch: (teamId, skip, cb) ->
      TeamProfile
      .find({ team_id: teamId })
      .skip(skip)
      .limit(batchSize)
      .sort("-points.overall")
      .select("rank points.overall")
      .exec (err, profiles) ->
         if err
            log.error("#{red}Failed: on #{teamId} (team_id), #{err}#{reset}")
            return cb(err)
         if profiles.length < 1
            log.write("#{white}No team profiles for: #{teamId}#{reset} (team_id)") if skip == 0
            return cb(err)

         async.parallel
            batch: (done) ->
               if profiles.length == batchSize
                  bookie.rankBatch(teamId, skip + batchSize, done)
               else
                  done()
            teamProfiles: (done) ->
               rank = skip + 1
               count = 0
               for profile in profiles
                  count++
                  profile.rank = rank++
                  profile.save (err) -> 
                     return done(err) if err
                     done() if --count == 0
         , cb



