mongoose = require "mongoose"
Stadium = require "../../common/models/Stadium"
Team = require "../../common/models/Team"
TeamProfile = require "../../common/models/TeamProfile"
Group = require "../../common/models/Group"
async = require "async"

module.exports =

   load: (obj, cb) ->
      creates = {}

      if obj.teams
         creates.teams = (done) -> Team.create(obj.teams, done)

      if obj.stadiums
         creates.stadiums = (done) -> Stadium.create(obj.stadiums, done)

      if obj.teamprofiles
         creates.teamprofiles = (done) -> TeamProfile.create(obj.teamprofiles, done)

      if obj.groups
         creates.groups = (done) -> Group.create(obj.groups, done)

      async.parallel(creates, cb)

   unload: (obj, cb) ->
      team_ids = if obj.teams then (t._id for t in obj.teams) else []
      stadium_ids = if obj.stadiums then (s._id for s in obj.stadiums) else []
      teamprofile_ids = if obj.teamprofiles then (s._id for s in obj.teamprofiles) else []
      group_ids = if obj.groups then (s._id for s in obj.groups) else []

      async.parallel [
         (done) -> Team.remove({_id: { $in: team_ids }}, done)
         (done) -> Stadium.remove({_id: { $in: stadium_ids }}, done)
         (done) -> TeamProfile.remove({_id: { $in: teamprofile_ids }}, done)
         (done) -> Group.remove({_id: { $in: group_ids }}, done)
      ], cb


