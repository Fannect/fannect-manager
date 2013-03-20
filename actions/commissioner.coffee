TeamProfile = require "../common/models/TeamProfile"
request = require "request"
async = require "async"
log = require "../utils/Log"
_ = require "underscore"
gameFace = require "../common/utils/eventProcessor/gameFace"

# Colors
red = "\u001b[31m"
green = "\u001b[32m"
white = "\u001b[37m"
reset = "\u001b[0m"

batchSize = parseInt(process.env.BATCH_SIZE or 50)

commissioner = module.exports =
   
   processAll: (cb) ->
      log.empty()
      log.write "#{white}Starting commissioner... #{green}#{new Date()}#{reset}"
      commissioner.processBatch 0, (err) ->
         log.error "#{red}Failed: #{err}#{reset}" if err
         log.sendErrors("Commissioner", cb)

   processBatch: (skip, cb) ->
      TeamProfile
      .find()
      .sort("_id")
      .skip(skip)
      .limit(batchSize)
      .select("points events")
      .exec (err, profiles) ->
         if err
            log.error "#{red}Failed: #{err}#{reset}"
            return cb(err)
         if profiles.length < 1
            log.write "No profiles" if skip == 0
            return cb()

         run = [
            (done) -> 
               if profiles and profiles.length == batchSize
                  commissioner.processBatch skip + batchSize, (err) -> 
                     log.error "#{red}Failed: #{err.stack}#{reset}" if err
                     done()
               else 
                  done()
         ]

         for p in profiles
            do (profile = p) ->
               updateEvents(profile) if profile.events?.length > 0
               run.push (done) ->
                  profile.save (err) ->
                     log.error "#{red}Failed: #{err.stack}#{reset}" if err
                     done()

         async.parallel run, (err) ->
            log.error "#{red}Failed: #{err.stack}#{reset}" if err
            cb()

updateEvents = (profile) ->
   gamefaces = _.where(profile.events, {type: "game_face"})
   
   for ev in gamefaces
      if ev.meta?.face_on
         ev.points_earned.passion = gameFace.calcScore(ev.meta?.motivated_count or 0)

   profile.points = {} unless profile.points
   profile.points.passion = 0
   profile.points.dedication = 0
   profile.points.knowledge = 0
   profile.points.overall = 0

   for ev in profile.events
      profile.points.passion += ev.points_earned.passion if ev.points_earned.passion
      profile.points.dedication += ev.points_earned.dedication if ev.points_earned.dedication
      profile.points.knowledge += ev.points_earned.knowledge if ev.points_earned.knowledge

   profile.points.overall = profile.points.passion + profile.points.dedication + profile.points.knowledge
