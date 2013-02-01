mongoose = require "mongoose"
Stadium = require "../../common/models/Stadium"
Team = require "../../common/models/Team"
async = require "async"

module.exports =

   load: (obj, cb) ->
      console.log "HIT"
      creates = {}

      if obj.teams
         creates.teams = (done) -> Team.create(obj.teams, done)

      if obj.stadiums
         creates.stadiums = (done) -> Stadium.create(obj.stadiums, done)

      async.parallel(creates, cb)

   unload: (obj, cb) ->
      team_ids = if obj.teams then (t._id for t in obj.teams) else []
      stadium_ids = if obj.stadiums then (s._id for s in obj.stadiums) else []

      console.log team_ids
      console.log stadium_ids

      async.parallel [
         (done) -> Team.remove({_id: { $in: team_ids }}, done)
         (done) -> Stadium.remove({_id: { $in: stadium_ids }}, done)
      ], cb


