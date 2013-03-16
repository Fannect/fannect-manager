require "mocha"
should = require "should"
http = require "http"
request = require "request"
async = require "async"
crypt = require "../common/utils/crypt"
fs = require "fs"
parser = require "../common/utils/xmlParser"
sportsML = require "../common/sportsMLParser/sportsMLParser"

mongoose = require "mongoose"
mongooseTypes = require "mongoose-types"
mongoose.connect "mongodb://admin:testing@linus.mongohq.com:10064/fannect"
mongooseTypes.loadTypes mongoose
request = require "request"

process.env.NODE_ENV = "production"
process.env.BATCH_SIZE = 1

Team = require "../common/models/Team"
Group = require "../common/models/Group"
TeamProfile = require "../common/models/TeamProfile"

data_standard = require "./res/json/standard"
data_postgame = require "./res/json/postgametest"
data_bookie = require "./res/json/bookie-test"
data_commissioner = require "./res/json/commissioner-test"
dbSetup = require "./utils/dbSetup"

scheduler = require "../actions/scheduler"
previewer = require "../actions/previewer"
postgame = require "../actions/postgame"
bookie = require "../actions/bookie"
commissioner = require "../actions/commissioner"

prepMongo = (done) -> dbSetup.load data_standard, done
emptyMongo = (done) -> dbSetup.unload data_standard, done


describe "Fannect Manager", () ->
   
   describe "XML Parser", () ->

      it "should identify empty document", (done) ->
         fs.readFile "#{__dirname}/res/xml/fakeNoResult.xml", (err, xml) ->
            return done(err) if err
            sportsML.preview xml, (err, preview) ->
               should.not.exist(preview)
               done()

      it "should parse sample schedule xml file", (done) ->
         fs.readFile "#{__dirname}/res/xml/fakeschedule.xml", (err, xml) ->
            return done(err) if err
            sportsML.schedule xml, (err, schedule) ->
               result1 = schedule.sportsEvents[0]
               result1.eventMeta.event_key.should.equal("l.nba.com-2012-e.16887")
               result1.away_team.team_key.should.equal("l.nba.com-t.1")
               result1.home_team.team_key.should.equal("l.nba.com-t.2")
               result1.eventMeta.stadium_key.should.equal("AmericanAirlines_Arena_TEST")
               result1.eventMeta.coverage.should.equal("TNT, CSN-NE")
               result1.eventMeta.isPast().should.be.true
               done()

      it "should parse sample game preview xml file", (done) ->
         fs.readFile "#{__dirname}/res/xml/fakepreview.xml", (err, xml) ->
            return done(err) if err
            sportsML.preview xml, (err, preview) ->
               return done(err) if err
               preview.articles.length.should.equal(2)
               preview.articles[0].event_key.should.equal("l.nba.com-2012-e.17856")
               preview.articles[0].preview.should.be.ok
               done()

            parser.parse xml, (err, doc) ->

      it "should parse sample event", (done) ->
         fs.readFile "#{__dirname}/res/xml/fakeevent.xml", (err, xml) ->
            return done(err) if err
            sportsML.eventStats xml, (err, eventStats) ->
               docs = eventStats.sportsEvents[0].eventMeta.docs
               docs.lineup.should.equal("xt.17810278-lineup")
               docs.pre_event_coverage.should.equal("xt.17810721-preview")
               docs.schedule_day.should.equal("xt.17810570-daysked")
               docs.event_score.should.equal("xt.17814385-update-post-event")
               docs.post_event_coverage.should.equal("xt.17814590-recap")
               docs.event_stats.should.equal("xt.17814514-box")
               done()

      it "should parse sample box scores xml file", (done) ->
         fs.readFile "#{__dirname}/res/xml/fakeboxscores.xml", (err, xml) ->
            return done(err) if err
            sportsML.eventStats xml, (err, eventStats) ->
               eventStats.sportsEvents[0].eventMeta.attendance.should.equal("18624")
               eventStats.sportsEvents[0].home_team.score.should.equal(99)
               eventStats.sportsEvents[0].away_team.score.should.equal(81)
               eventStats.sportsEvents[0].home_team.won().should.be.true
               eventStats.sportsEvents[0].away_team.won().should.be.false
               done()

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

      describe "Ranking", () ->
         before (done) -> 
            async.series [
               (done) -> dbSetup.unload data_bookie, done
               (done) -> dbSetup.load data_bookie, done
               (done) => 
                  Team.findById "51084c19f71f55551a7b1ef6", (err, team) =>
                     return done(err) if err
                     bookie.rankTeam team, done
               (done) => 
                  TeamProfile
                  .find(team_id: "51084c19f71f55551a7b1ef6")
                  .sort("rank")
                  .select("rank points")
                  .exec (err, profiles) =>
                     return done(err) if err
                     @profiles = profiles
                     done()
            ], done

         after (done) -> dbSetup.unload data_bookie, done

         it "should update all team profiles to have the correct rank", () ->
               @profiles[0].rank.should.equal(1)
               @profiles[1].rank.should.equal(2)
               @profiles[2].rank.should.equal(3)
               (@profiles[0].points.overall >= @profiles[1].points.overall).should.be.true
               (@profiles[1].points.overall >= @profiles[2].points.overall).should.be.true
           
         it "should update the points of the team", (done) ->
            Team.findById "51084c19f71f55551a7b1ef6", "points", (err, team) =>
               return done(err) if err
               overall = @profiles[0].points.overall + @profiles[1].points.overall + @profiles[2].points.overall 
               passion = @profiles[0].points.passion + @profiles[1].points.passion + @profiles[2].points.passion 
               dedication = @profiles[0].points.dedication + @profiles[1].points.dedication + @profiles[2].points.dedication 
               knowledge = @profiles[0].points.knowledge + @profiles[1].points.knowledge + @profiles[2].points.knowledge 

               team.points.overall.should.equal(overall)
               team.points.passion.should.equal(passion)
               team.points.dedication.should.equal(dedication)
               team.points.knowledge.should.equal(knowledge)
               done()

      describe "Scoring", () ->
         before (cb) -> 
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

         after (done) -> dbSetup.unload data_bookie, done

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

         it "should update team points correctly", (done) ->
            Team.findById "51084c19f71f55551a7b1ef6", "points", (err, team) =>
               sum = @profiles[0].points.overall + @profiles[1].points.overall + @profiles[2].points.overall
               team.points.overall.should.equal(sum)
               done()

         it "should update group points correctly", (done) ->
            group_id = "51084c19f71f55551a7b2ef7"
            Group.findById group_id, "points", (err, group) =>
               group = group.toObject()
               sum = 0
               for profile in @profiles
                  for g in profile.groups
                     if g.group_id?.toString() == "51084c19f71f55551a7b2ef7"
                        sum += profile.points.overall
                        break
               group.points.overall.should.equal(sum)
               done()

   describe.only "Postgame", () ->
      before (done) ->
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

      after (done) -> dbSetup.unload data_postgame, done

      it "should remove next game from season", () ->
         @team.schedule.season.length.should.equal(1)

      it "should update pregame", () ->
         @team.schedule.pregame.event_key.should.equal("l.nba.com-2012-e.17838")
         @team.schedule.pregame.opponent_id.toString().should.equal("51084c08f71f44551a7b3ef7")
         @team.schedule.pregame.is_home.should.be.false

      it "should update box scores", () ->
         @team.schedule.postgame.attendance.should.equal(18624)
         @team.schedule.postgame.won.should.be.false
         @team.schedule.postgame.score.should.equal(81)
         @team.schedule.postgame.opponent_score.should.equal(99)

      it "should update team points", () ->
         @team.points.overall.should.equal(45)

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
         
