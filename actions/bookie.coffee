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

batchSize = process.env.BATCH_SIZE = 50

bookie = module.exports =
   
   # updateAll: (cb) ->


   # findAndUpdate: () ->

   processTeam: (team, cb) ->
      TeamProfile
      .find({ team_id: team._id })
      .skip()

   processBatch: (team, skip, cb) ->
      TeamProfile
      .find({ team_id: team._id })
      .skip(skip)
      .limit(batchSize)
      .select("schedule.postgame points events")
      .exec (err, profiles) ->
         async.parallel
            batch: (done) ->
               if profiles and profiles.length == batchSize
                  processBatch(team, skip + batchSize, done)
               else 
                  done()
            teamProfiles: (done) ->
               cargo = async.cargo (profile, done) ->
                  new EventProcessor profile, () -> profile.save(done)
               , 10

               cargo.push(p) for p in profiles
               cargo.drain(done)
         , cb

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
            log.write("#{white}No team profiles for: #{teamId}#{reset} (team_id)")
            return cb(err)

         async.parallel
            batch: (done) ->
               if profiles and profiles.length == batchSize
                  processBatch(team, skip + batchSize, done)
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



