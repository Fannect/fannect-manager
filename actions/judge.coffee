Highlight = require "../common/models/Highlight"
TeamProfile = require "../common/models/TeamProfile"
Config = require "../common/models/Config"
request = require "request"
async = require "async"
log = require "../utils/Log"
sportsML = require "../common/sportsMLParser/sportsMLParser"

TeamRankUpdateJob = require "../common/jobs/TeamRankUpdateJob"
photoProcessor = require "../common/utils/eventProcessor/photos"

# Colors
red = "\u001b[31m"
green = "\u001b[32m"
white = "\u001b[37m"
reset = "\u001b[0m"

judge = module.exports =
   
   processAll: (cb) ->
      log.empty()
      log.write "#{white}Starting judge... #{green}#{new Date()}#{reset}"
      
      Highlight
      .aggregate { $match: { is_active: true }}
      , { $group: { _id: "$team_id" }}
      , (err, results) ->
         if err
            log.error "#{red}Failed to find teams to judge: #{err.stack or err}#{reset}" 
            return log.sendErrors("Judge", cb)

         q = async.queue (team_id, callback) ->
            judge.processTeam team_id, (err) ->
               log.error "#{red}Failed to judge: #{team_id}#{reset} (team_id)" if err 
               log.write "#{white}Finished judging: #{team_id} #{reset}(team_id)"
               callback()
         , 1
         
         if results.length == 0
            log.write "#{white}No judgements to be made.#{reset}" 
            judge.nextPhotoChallenge () -> log.sendErrors("Judge", cb)
         else
            log.write "#{white}Found #{green}#{results.length}#{white} teams to judge...#{reset}"

         q.push(result._id) for result in results
         q.drain = () -> 
            judge.nextPhotoChallenge () -> log.sendErrors("Judge", cb)

   nextPhotoChallenge: (cb) ->
      log.write "#{white}Setting next photo challenge..#{reset}"
      Config.nextPhotoChallenge (err) ->
         if err
            log.error "#{red}Failed to set next photo challenge: #{err.stack or err}#{reset}" 
         cb()

   processTeam: (team_id, cb) ->
      game_types = photoProcessor.getTypes()

      q = async.queue (type, callback) ->
         judge.judgeTeam
            team_id: team_id
            game_type: type
            level_count: 9
         , (err, ranked, exclude) ->
            return callback(err) if err
            judge.updateRanked ranked, type, (err) ->
               return callback(err) if err
               judge.updateConsolationBatch
                  team_id: team_id
                  game_type: type
                  exclude: exclude
               , callback
      , 10

      q.push(type) for type in game_types
      q.drain = (err) ->
         return cb(err) if err
         # queue rank update job
         job = new TeamRankUpdateJob({ team_id: team_id })
         job.queue(cb)

   # build a ranked object
   judgeTeam: (options, cb) ->
      teamId = options.team_id
      gameType = options.game_type
      levelCount = options.level_count or 10
      batchSize = options.batch_size or 30
      startTime = "#{Math.floor(new Date()/1000).toString(16)}0000000000000000"
      
      skip = 0
      rank = 0
      ranked = [ [] ]
      exclude = []

      pullHighlights = (cb) ->
         Highlight
         .find({ team_id: teamId, game_type: gameType, is_active: true, _id: { $lt: startTime }, up_votes: { $gt: 0 } })
         .sort("-up_votes down_votes")
         .skip(skip)
         .limit(batchSize)
         .select("up_votes down_votes owner_id image_url game_meta")
         .exec (err, highlights) ->
            return cb(err) if err
            return cb() unless highlights.length > 0
            
            for highlight in highlights
               # skip if owner has already been rewarded
               continue if (highlight.owner_id.toString() in exclude)
                  
               if rank == 0 and ranked[rank].length == 0
                  # first highlight so just add it
                  ranked[rank].push(highlight)
                  exclude.push(highlight.owner_id.toString())
                  continue
               
               if highlight.up_votes == ranked[rank][0].up_votes
                  # tied by up_votes, compare down votes
                  if highlight.down_votes == ranked[rank][0].down_votes 
                     # tied overall, add to current rank
                     ranked[rank].push(highlight)
                  else
                     # check if already at the end, push if not
                     break if ++rank == levelCount
                     ranked[rank] = [ highlight ]
               else
                  # check if already at the end, push if not
                  break if ++rank == levelCount
                  ranked[rank] = [ highlight ]

               exclude.push(highlight.owner_id.toString())

            # check if at rank levelCount, meaning all the spots are filled
            if rank < levelCount
               skip += batchSize
               pullHighlights(cb)
            else
               # all ranks are filled so call callback
               cb()

      pullHighlights (err) ->
         return cb(err) if err
         cb(null, ranked, exclude)

   updateConsolationBatch: (options, cb) ->
      teamId = options.team_id
      gameType = options.game_type
      batchSize = options.batchSize or 50
      exclude = options.exclude or []

      Highlight
      .find({ team_id: teamId, game_type: gameType, is_active: true })
      .sort("_id")
      .limit(batchSize)
      .select("up_votes down_votes owner_id image_url game_meta")
      .exec (err, highlights) ->
         return cb(err) if err
         return cb(exclude) unless highlights?.length > 0

         clear = []
         include = []

         # filter out highlights that have been excluded
         for highlight in highlights
            # continue if highlight has no votes
            if highlight.up_votes == 0
               clear.push(highlight)
               continue

            skip = false
            for id in exclude
               if id.toString() == highlight.owner_id.toString()
                  skip = true
                  break
            if skip
               clear.push(highlight)
            else
               include.push(highlight) 
               exclude.push(highlight.owner_id.toString())

         async.parallel
            clear: (done) ->
               Highlight.update {_id: { $in: clear }}, {is_active: false}, {multi: true}, done
            winners: (done) ->
               judge.updateWinners 10, gameType, include, done
         , (err) ->
            return cb(err) if err
            # if highlights was full there must be more so start next batch
            if highlights.length == batchSize
               judge.updateConsolationBatch 
                  team_id: teamId
                  game_type: gameType
                  batch_size: batchSize
                  exclude: exclude
               , cb
            else
               cb(null, exclude)

   # update profiles
   updateRanked: (ranked, game_type, cb) ->
      q = async.queue (rank, callback) ->
         judge.updateWinners(rank.rank, game_type, rank.highlights, callback)
      , 10

      for highlights, rank in ranked
         q.push({ rank: rank + 1, highlights: highlights })
      q.drain = cb

   updateWinners: (rank, game_type, highlights, cb) ->
      return cb() unless highlights?.length > 0
      score = photoProcessor.calcScore(rank)
      point_type = photoProcessor.getPointType(game_type)
   
      q = async.queue (highlight, callback) ->
         eventItem = 
            type: game_type
            points_earned: {}
            meta: 
               highlight_id: highlight._id
               image_url: highlight.image_url
               up_votes: highlight.up_votes
               down_votes: highlight.down_votes
               rank: rank

         eventItem.points_earned[point_type] = score

         # add metadata for challenge
         if highlight.game_type == "photo_challenge"
            eventItem.meta.challenge = highlight.game_meta.challenge
            
         # create profile update object
         profileUpdate = 
            $inc: { "points.overall": score }
            $push: { events: eventItem } 

         profileUpdate["$inc"]["points.#{point_type}"] = score

         # run update async
         async.parallel
            highlight: (done) ->
               Highlight.update {_id: highlight._id}, {is_active: false}, done
            profile: (done) ->   
               TeamProfile.update {_id: highlight.owner_id}, profileUpdate, done
         , callback
      , 10
      q.push(highlight) for highlight in highlights
      q.drain = cb
