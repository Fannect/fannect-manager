mongoose = require "mongoose"
Stadium = require "../../common/models/Stadium"
Team = require "../../common/models/Team"
TeamProfile = require "../../common/models/TeamProfile"
Group = require "../../common/models/Group"
Highlight = require "../../common/models/Highlight"
Huddle = require "../../common/models/Huddle"
User = require "../../common/models/User"

async = require "async"

module.exports =

   load: (obj, cb) ->
      creates = {}

      if obj.users
         creates.users = (done) -> User.create(obj.users, done)

      if obj.teams
         creates.teams = (done) -> Team.create(obj.teams, done)

      if obj.stadiums
         creates.stadiums = (done) -> Stadium.create(obj.stadiums, done)

      if obj.teamprofiles
         creates.teamprofiles = (done) -> TeamProfile.create(obj.teamprofiles, done)

      if obj.groups
         creates.groups = (done) -> Group.create(obj.groups, done)

      if obj.huddles
         creates.huddles = (done) -> Huddle.create(obj.huddles, done)

      if obj.highlights
         creates.highlights = (done) -> Highlight.create(obj.highlights, done)

      async.parallel(creates, cb)

   unload: (obj, cb) ->
      user_ids = if obj.users then (u._id for u in obj.users) else []
      team_ids = if obj.teams then (t._id for t in obj.teams) else []
      stadium_ids = if obj.stadiums then (s._id for s in obj.stadiums) else []
      profile_ids = if obj.teamprofiles then (t._id for t in obj.teamprofiles) else []
      group_ids = if obj.groups then (t._id for t in obj.groups) else []
      huddle_ids = if obj.huddles then (h._id for h in obj.huddles) else []
      highlight_ids = if obj.highlights then (h._id for h in obj.highlights) else []

      async.parallel [
         (done) -> User.remove({_id: { $in: user_ids }}, done)
         (done) -> Team.remove({_id: { $in: team_ids }}, done)
         (done) -> Stadium.remove({_id: { $in: stadium_ids }}, done)
         (done) -> TeamProfile.remove({_id: { $in: profile_ids }}, done)
         (done) -> TeamProfile.remove({user_id: { $in: user_ids }}, done)
         (done) -> TeamProfile.remove({_id: { $in: profile_ids }}, done)
         (done) -> Group.remove({_id: { $in: group_ids }}, done)
         (done) -> Group.remove({team_id: { $in: team_ids }}, done)
         (done) -> Huddle.remove({_id: { $in: huddle_ids }}, done)
         (done) -> Huddle.remove({team_id: { $in: team_ids }}, done)
         (done) -> Highlight.remove({_id: { $in: highlight_ids }}, done)
         (done) -> Highlight.remove({team_id: { $in: team_ids }}, done)
      ], cb


