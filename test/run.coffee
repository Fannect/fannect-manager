require "mocha"
should = require "should"
http = require "http"
request = require "request"
async = require "async"
crypt = require "../common/utils/crypt"
fs = require "fs"
parser = require "../common/utils/xmlParser"

mongoose = require "mongoose"
mongooseTypes = require "mongoose-types"
mongoose.connect "mongodb://admin:testing@linus.mongohq.com:10064/fannect"
mongooseTypes.loadTypes mongoose
request = require "request"

Team = require "../common/models/Team"

data_standard = require "./res/standard"
data_postgame = require "./res/postgametest"
dbSetup = require "./utils/dbSetup"

scheduler = require "../actions/scheduler"
previewer = require "../actions/previewer"
postgame = require "../actions/postgame"

prepMongo = (done) -> dbSetup.load data_standard, done
emptyMongo = (done) -> dbSetup.unload data_standard, done

process.env.REDIS_URL = "redis://redistogo:f74caf74a1f7df625aa879bf817be6d1@perch.redistogo.com:9203"
process.env.NODE_ENV = "production"

describe "Fannect Manager", () ->
   
   describe "XML Parser", () ->

      it "should identify empty document", (done) ->
         fs.readFile "#{__dirname}/res/fakeNoResult.xml", (err, xml) ->
            return done(err) if err
            parser.parse xml, (err, doc) ->
               parser.isEmpty(doc).should.be.true
               done()

      it "should parse sample schedule xml file", (done) ->
         fs.readFile "#{__dirname}/res/fakeschedule.xml", (err, xml) ->
            return done(err) if err
            parser.parse xml, (err, doc) ->
               return done(err) if err
               games = parser.schedule.parseGames(doc)
               games.length.should.equal(3)
               result1 = parser.schedule.parseGameToJson(games[0])
               result1.event_key.should.equal("l.nba.com-2012-e.16887")
               result1.away_key.should.equal("l.nba.com-t.1")
               result1.home_key.should.equal("l.nba.com-t.2")
               result1.stadium_key.should.equal("AmericanAirlines_Arena_TEST")
               result1.coverage.should.equal("TNT, CSN-NE")
               result1.is_past.should.be.true
               done()

      it "should parse sample game preview xml file", (done) ->
         fs.readFile "#{__dirname}/res/fakepreview.xml", (err, xml) ->
            return done(err) if err
            parser.parse xml, (err, doc) ->
               return done(err) if err
               articles = parser.preview.parseArticles(doc)
               articles.length.should.equal(2)
               article = parser.preview.parseArticleToJson(articles[0])
               article.event_key.should.equal("l.nba.com-2012-e.17856")
               article.preview.should.be.ok
               done()

      it "should parse sample box scores xml file", (done) ->
         fs.readFile "#{__dirname}/res/fakeboxscores.xml", (err, xml) ->
            return done(err) if err
            parser.parse xml, (err, doc) ->
               return done(err) if err
               outcome = parser.boxScores.parseBoxScoreToJson(doc)
               outcome.is_past.should.be.true
               outcome.won.should.be.false
               outcome.opponent_score.should.equal(99)
               outcome.score.should.equal(81)
               done()

   describe "Scheduler", () ->
      before (done) ->
         request.get = (options, done) -> fs.readFile "#{__dirname}/res/fakeschedule.xml", "utf8", (err, xml) -> done null, null, xml
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
               (team.schedule.season[0].game_time > team.schedule.pregame.game_time).should.be.true
               done()

   describe "Previewer", () ->
      before (done) ->
         request.get = (options, done) -> fs.readFile "#{__dirname}/res/fakepreview.xml", "utf8", (err, xml) -> done null, null, xml
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

   describe "Postgame", () ->
      before (done) ->
         request.get = (options, done) -> fs.readFile "#{__dirname}/res/fakeboxscores.xml", "utf8", (err, xml) -> done null, null, xml
         async.series
            setup: (done) -> dbSetup.load data_postgame, done
            update: postgame.update
         , (err) =>
            Team
            .findById("51084c08f71f55551a7b1ef6")
            .select("schedule")
            .exec (err, team) =>
               @team = team
               done(err)

      after (done) ->
         dbSetup.unload data_postgame, done

      it "should remove next game from season", () ->
         team = @team
         # console.log team
         team.schedule.season.length.should.equal(1)

      it "should update pregame", () ->
         team = @team
         team.schedule.pregame.event_key.should.equal("l.nba.com-2012-e.17838")
         team.schedule.pregame.is_home.should.be.false

      it "should update box scores", () ->
         team = @team
         team.schedule.postgame.attendance.should.equal(18624)
         team.schedule.postgame.won.should.be.false
         team.schedule.postgame.score.should.equal(81)
         team.schedule.postgame.opponent_score.should.equal(99)





