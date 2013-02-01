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


# Have to do this because mongoose is initialized later
data_standard = require "./res/standard"
dbSetup = require "./utils/dbSetup"

emptyMongo = (done) -> dbSetup.unload data_standard, done
prepMongo = (done) ->
   context = @
   dbSetup.load data_standard, (err, data) ->
      return done(err) if err
      context.db = data
   done()

process.env.REDIS_URL = "redis://redistogo:f74caf74a1f7df625aa879bf817be6d1@perch.redistogo.com:9203"
process.env.NODE_ENV = "production"

describe "Fannect Manager", () ->
   
   describe "XML Parser", () ->
      it "should parse sample schedule xml file", (done) ->
         fs.readFile "#{__dirname}/res/fakeschedule.xml", (err, xml) ->
            return done(err) if err
            parser.parse xml, (err, doc) ->
               return done(err) if err
               games = parser.schedule.parseGames(doc)
               games.length.should.equal(2)
               result1 = parser.schedule.parseGameToJson(games[0])
               result1.event_key.should.equal("l.nba.com-2012-e.16887")
               result1.away_key.should.equal("l.nba.com-t.1")
               result1.home_key.should.equal("l.nba.com-t.2")
               result1.stadium_key.should.equal("AmericanAirlines_Arena")
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
               outcome.won.should.be.false
               outcome.opponent_score.should.equal(99)
               outcome.score.should.equal(81)
               done()

   describe.only "Scheduler", () ->
      before emptyMongo
      after prepMongo

      it "should"
         
