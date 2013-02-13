Team = require "../common/models/Team"
TeamProfile = require "../common/models/TeamProfile"
Group = require "../common/models/Group"
parser = require "../common/utils/xmlParser"
request = require "request"
async = require "async"
log = require "../utils/Log"
url = process.env.XMLTEAM_URL or "http://fannect:k4ns4s@sportscaster.xmlteam.com/gateway/php_ci"

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
         log.errors("#{red}Process: Failed: #{err.stack}#{reset}") if err
         return cb(err) if err
         team.is_processing = false
         team.needs_processing = false
         bookie.rankTeam team, cb

   processBatch: (team, skip, cb) ->
      TeamProfile
      .find({ team_id: team._id })
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

   rankTeam: (team, cb) ->
      # Reset points so they can be freshly added
      team.set("points", {overall: 0, passion: 0, dedication: 0, knowledge: 0})
      bookie.rankBatch team, 0, (err) ->
         return cb(err) if err
         team.save (err) ->
            return cb(err) if err
            bookie.rankGroups(team._id, cb)

   rankBatch: (team, skip, cb) ->
      TeamProfile
      .find({ team_id: team._id })
      .skip(skip)
      .limit(batchSize)
      .sort({"points.overall": -1, name: 1})
      .select("rank points")
      .exec (err, profiles) ->
         if err
            log.error("#{red}Rank: Failed to rank team: #{team._id} (team_id), #{err}#{reset}")
            return cb(err)
         if profiles.length < 1
            log.write("Rank: No team profiles for: #{team._id} (team_id)") if skip == 0
            return cb(err)

         async.parallel
            batch: (done) ->
               if profiles.length == batchSize
                  bookie.rankBatch team, skip + batchSize, (err) ->
                     log.error "#{red}Rank: Failed: #{err.stack}#{reset}" if err
                     done()
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
                     log.error "#{red}Rank: Failed: #{err.stack}#{reset}" if err
                     done() if --count == 0
         , cb

   rankGroups: (team_id, cb) ->
      TeamProfile
      # .find { team_id: team_id }
      .aggregate { $match: { "team_id": team_id }}
      , { $unwind: "$groups" }
      , { $group: { 
         _id: "$groups.group_id",
         members: { $sum: 1 },
         overall: { $sum: "$points.overall" },
         passion: { $sum: "$points.passion" }, 
         dedication: { $sum: "$points.dedication" }, 
         knowledge: { $sum: "$points.knowledge" }}}
      , (err, groups) ->

         run = []

         for g in groups 
            do (group = g) ->
               run.push (done) ->
                  Group.update _id: group._id,
                     members: group.members
                     points: 
                        overall: group.overall
                        passion: group.passion
                        dedication: group.dedication
                        knowledge: group.knowledge
                  , (err, results) ->
                     log.error("Groups: Fail: #{err.stack}") if err
                     done()


         async.parallel run, (err) ->
            log.error("Groups: Fail: #{err.stack}") if err
            cb()
