require "mocha"
should = require "should"
http = require "http"
request = require "request"
async = require "async"
crypt = require "../common/utils/crypt"
fs = require "fs"
sportsML = require "../common/sportsMLParser/sportsMLParser"
Job = require "../common/jobs/Job"

mongoose = require "mongoose"
mongooseTypes = require "mongoose-types"
mongoose.connect "mongodb://localhost:27017" # "mongodb://admin:testing@linus.mongohq.com:10064/fannect"
mongooseTypes.loadTypes mongoose
request = require "request"

process.env.NODE_ENV = "production"
process.env.NODE_TESTING = true
process.env.BATCH_SIZE = 1

Team = require "../common/models/Team"
Group = require "../common/models/Group"
TeamProfile = require "../common/models/TeamProfile"
Highlight = require "../common/models/Highlight"

data_standard = require "./res/json/standard"
data_postgame = require "./res/json/postgametest"
data_bookie = require "./res/json/bookie-test"
data_commissioner = require "./res/json/commissioner-test"
data_judge = require "./res/json/judge-test"
dbSetup = require "./utils/dbSetup"

scheduler = require "../actions/scheduler"
previewer = require "../actions/previewer"
postgame = require "../actions/postgame"
bookie = require "../actions/bookie"
commissioner = require "../actions/commissioner"
judge = require "../actions/judge"

prepMongo = (done) -> dbSetup.load data_standard, done
emptyMongo = (done) -> dbSetup.unload data_standard, done

describe "Fannect Manager", () ->
   
   describe "Scheduler", () ->
      before (done) ->
         request.get = (options, done) -> fs.readFile "#{__dirname}/res/xml/fakeschedule.xml", "utf8", (err, xml) -> done null, null, xml
         emptyMongo () -> prepMongo(done)
      after emptyMongo

      it "should update schedules from fake schedule", (done) ->
         scheduler.update "l.test.nba.com", (err) ->
            return done(err) if err
            Team
            .findById("51084c08f71f44551a7b1ef6")
            .select("schedule")
            .lean()
            .exec (err, team) ->

               pregame = team.schedule.pregame
               (team.schedule.season[0].game_time > pregame.game_time).should.be.true
               pregame.is_home.should.be.true
               pregame.opponent.should.equal("Milwaukee Bucks")
               pregame.opponent_id.toString().should.equal("51084c08f71f44551a7b1ef7")
               pregame.stadium_name.should.equal("TD Garden")
               pregame.stadium_location.should.equal("Boston, MA")
               pregame.stadium_coords[0].should.equal(-71.06222)
               pregame.stadium_coords[1].should.equal(42.366289)

               done()

   describe "Previewer", () ->
      before (done) ->
         request.get = (options, done) -> fs.readFile "#{__dirname}/res/xml/fakepreview.xml", "utf8", (err, xml) -> done null, null, xml
         emptyMongo () -> prepMongo(done)
      after emptyMongo

      it "should update previews from fake preview", (done) ->
         previewer.update "l.test.nba.com", (err) ->
            Team
            .findById("51084c08f71f44551a7b1ef6")
            .select("schedule.pregame")
            .exec (err, team) ->
               return done(err) if err
               team.schedule.pregame.preview.should.be.ok
               done()

   describe "Bookie", () ->
      before (cb) -> 
         context = @
         context.old_queue_fn = Job.prototype.queue
         Job::queue = (cb = ->) ->
            context.queued = @
            process.nextTick(cb)

         async.series [
            (done) -> dbSetup.unload data_bookie, done
            (done) -> dbSetup.load data_bookie, done
            (done) -> 
               Team.findById "51084c19f71f55551a7b1ef6", "schedule full_name sport_key needs_processing is_processing points", (err, team) ->
                  return done(err) if err
                  bookie.processTeam team, (err) ->
                     done(err)
            (done) =>
               TeamProfile
               .find(team_id: "51084c19f71f55551a7b1ef6")
               .sort("points.overall")
               .select("rank points waiting_events events groups")
               .exec (err, profiles) =>
                  return done(err) if err
                  @profiles = profiles
                  done()
         ], cb

      after (done) -> 
         Job.prototype.queue = context.old_queue_fn
         dbSetup.unload data_bookie, done

      it "should processes all waiting_events", () ->
         for profile in @profiles
            profile.waiting_events.length.should.equal(0)

      it "should add events", () ->
         @profiles[0].events.length.should.equal(2)
         @profiles[1].events.length.should.equal(2)
         @profiles[2].events.length.should.equal(4)

      it "should update all team profiles to have the correct points", () ->
         @profiles[0].points.overall.should.equal(3)
         @profiles[1].points.overall.should.equal(11)
         @profiles[2].points.overall.should.equal(34)

      it "should queue team rank update", () ->
         @queued.meta.team_id.toString().should.equal("51084c19f71f55551a7b1ef6")

   describe "Postgame", () ->
      before (done) ->
         context = @
         context.old_queue_fn = Job.prototype.queue
         Job::queue = (cb = ->) ->
            context.queued = @
            process.nextTick(cb)
         request.get = (options, done) -> 
            if options.url.indexOf("getEvents") != -1
               fs.readFile "#{__dirname}/res/xml/fakeEventStats.xml", "utf8", (err, xml) -> done null, null, xml
            else if options.url.indexOf("xt.17971005-box")
               fs.readFile "#{__dirname}/res/xml/fakeBoxScore1.xml", "utf8", (err, xml) -> done null, null, xml

         dbSetup.unload data_postgame, (err) =>
            return done(err) if err
            dbSetup.load data_postgame, (err) =>
               return done(err) if err
               Team
               .findById("51084c08f71f55551a7b1ef6")
               .select("schedule team_key sport_key needs_processing is_processing points")
               .exec (err, team) =>
                  return done(err) if err
                  postgame.updateTeam team, true, (err) =>
                     return done(err) if err
                     Team
                     .findById("51084c08f71f55551a7b1ef6")
                     .select("schedule points")               
                     .exec (err, team) =>
                        @team = team
                        done(err)

      after (done) -> 
         Job.prototype.queue = context.old_queue_fn
         dbSetup.unload data_postgame, done

      it "should remove next game from season", () ->
         @team.schedule.season.length.should.equal(1)

      it "should update pregame", () ->
         @team.schedule.pregame.event_key.should.equal("l.nba.com-2012-e.17838")
         @team.schedule.pregame.opponent_id.toString().should.equal("51084c08f71f44551a7b3ef7")
         @team.schedule.pregame.is_home.should.be.false

      it "should queue team rank update", () ->
         @queued.meta.team_id.toString().should.equal("51084c08f71f55551a7b1ef6")

   describe "Judge", () ->
      before () ->
         context = @
         context.old_queue_fn = Job.prototype.queue
         Job::queue = (cb = ->) ->
            context.queued = @
            process.nextTick(cb)
      after (done) -> 
         Job.prototype.queue = context.old_queue_fn
         dbSetup.unload data_judge, done

      describe "updateWinners", () ->
         team_id = "7116822f0952930200000111"
         before (done) -> 
            async.series [
               (done) -> dbSetup.unload data_judge, done
               (done) -> dbSetup.load data_judge, done
               (done) -> 
                  Highlight.find {team_id: team_id, game_type: "gameday_pics", is_active: true}, (err, highlights) ->
                     return done(err) if err
                     judge.updateWinners(1, "gameday_pics", highlights, done)
            ], done
         after (done) -> dbSetup.unload data_judge, done

         it "should update profiles to have correct points", (done) ->
            TeamProfile.find {team_id: team_id}, (err, profiles) ->
               return done(err) if err
               profiles.length.should.equal(6)
               for profile in profiles
                  continue if profile._id.toString() == "6116822f0952930200000001"
                  profile.points.passion.should.equal(11)
                  profile.points.overall.should.equal(13)
               done()

         it "should mark all highlights processed as inactive", (done) ->
            Highlight.find {team_id: team_id, game_type: "gameday_pics", is_active: true}, (err, highlights) ->
               return done(err) if err
               highlights.length.should.equal(0)
               done()

      describe "judgeTeam", () ->
         team_id = "7116822f0952930200000111"
         before (done) ->
            context = @ 
            async.series [
               (done) -> dbSetup.unload data_judge, done
               (done) -> dbSetup.load data_judge, done
               (done) -> 
                  judge.judgeTeam
                     team_id: team_id
                     game_type: "gameday_pics"
                     level_count: 4
                  , (err, ranked) ->
                     return done(err) if err
                     context.ranked = ranked
                     done() 
            ], done
         after (done) -> dbSetup.unload data_judge, done

         it "should rank highlights by up votes", () ->
            @ranked[0][0].up_votes.should.equal(100)
            
         it "should break ties by down_votes", () ->
            @ranked[1].length.should.equal(1)
            @ranked[2].length.should.equal(1)
            @ranked[1][0].up_votes.should.equal(90)
            @ranked[2][0].up_votes.should.equal(90)
            
         it "should allow absolute ties", () ->
            @ranked[3].length.should.equal(2)
            @ranked[3][0].up_votes.should.equal(10)
            @ranked[3][1].up_votes.should.equal(10)

      describe "updateConsolationBatch", () ->
         team_id = "7116822f0952930200000111"
         before (done) ->
            context = @ 
            async.series [
               (done) -> dbSetup.unload data_judge, done
               (done) -> dbSetup.load data_judge, done
               (done) -> 
                  judge.updateConsolationBatch 
                     team_id: team_id
                     game_type: "gameday_pics"
                     batch_size: 1
                     exclude: [ "6116822f0952930200000001" ]
                  , done
            ], done
         after (done) -> dbSetup.unload data_judge, done

         it "should update consolation batch", (done) ->
            Highlight.find {team_id: team_id, is_active: false}, (err, highlights) ->
               highlights.length.should.equal(9)
               done()

      describe "processTeam", () ->
         team_id = "7116822f0952930200000111"
         before (done) ->
            context = @ 
            async.series [
               (done) -> dbSetup.unload data_judge, done
               (done) -> dbSetup.load data_judge, done
               (done) -> 
                  judge.processTeam team_id, done
            ], done
         after (done) -> dbSetup.unload data_judge, done

         it "should queue teamRankUpdateJob", () ->
            @queued.should.be.ok

         it "should update all highlights to inactive", (done) ->
            Highlight.find {team_id: team_id, is_active: true}, (err, highlights) ->
               highlights.length.should.equal(0)
               done()

         it "should judge all game types", (done) ->
            TeamProfile.find {team_id: team_id, "events.meta.rank": 1 }, (err, profiles) ->
               profiles.length.should.equal(2)
               for profile in profiles
                  type = profile.events[0].type
                  (type == "spirit_wear" or type == "gameday_pics").should.be.true
               done()
               

   describe.skip "Commissioner", () ->
      before (cb) -> 
         async.series [
            (done) -> dbSetup.unload data_commissioner, done
            (done) -> dbSetup.load data_commissioner, done
            (done) -> 
               commissioner.processAll (err) ->
                  done(err)
            (done) =>
               TeamProfile
               .findOne(_id: "6116922f0952930200000005")
               .select("rank points waiting_events events groups")
               .exec (err, profile) =>
                  return done(err) if err
                  @profile = profile
                  done()
         ], cb

      after (done) -> dbSetup.unload data_commissioner, done

      it "should correct points and overall points", () ->
         console.log @profile
         