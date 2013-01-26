require "mocha"
should = require "should"
http = require "http"
request = require "request"
mongoose = require "mongoose"
async = require "async"

# Have to do this because mongoose is initialized later
redis = null
dbSetup = null
Team = null
TeamProfile = null
User = null

data_standard = require "./res/standard"

process.env.REDIS_URL = "redis://redistogo:f74caf74a1f7df625aa879bf817be6d1@perch.redistogo.com:9203"
process.env.MONGO_URL = "mongodb://admin:testing@linus.mongohq.com:10064/fannect"
process.env.NODE_ENV = "production"

app = require "../controllers/host"

describe "Fannect Login", () ->
   before (done) ->
      context = @
      server = http.createServer(app).listen 0, () ->
         context.host = "http://localhost:#{this.address().port}"
         User = require "../common/models/User"
         redis = require("../common/utils/redis").client
         dbSetup = require "./utils/dbSetup"
         dbSetup.unload () -> dbSetup.load data_standard, done
   after (done) -> dbSetup.unload done

   describe "/v1/token", () ->
      describe "POST", () ->
         before (done) ->
            context = @
            request
               url: "#{context.host}/v1/token"
               method: "POST"
               json: 
                  email: "testingmctester@fannect.me"
                  password: "hi"
            , (err, resp, body) ->
               return done(err) if err
               context.body = body
               console.log body
               done() 

         it "should retrieve access_token and refresh_token", () ->
            context = @
            context.body.refresh_token.should.be.ok
            context.body.access_token.should.be.ok

         it "should access_token to redis", (done) ->
            context = @
            redis.get context.body.access_token, (err, user) ->
               return done(err) if err
               user = JSON.parse(user)
               user.email.should.equal("testingmctester@fannect.me")
               user.first_name.should.equal("Mc")
               user.last_name.should.equal("Tester")
               should.not.exist(user.password)
               done()



      describe "PUT", () ->
         it "should retrieve fresh access_token with refresh_token"

   describe "/v1/users", () ->
      describe "POST", () ->
         before (done) ->
            context = @
            request
               url: "#{context.host}/v1/users"
               method: "POST"
               json: 
                  email: "imatester@fannect.me"
                  password: "hi"
                  first_name: "Bill"
                  last_name: "Tester"
            , (err, resp, body) ->
               return done(err) if err
               context.body = body
               done() 

         it "should return created user", () ->
            context = @
            context.body._id.should.be.ok
            context.body.access_token.should.be.ok
            context.body.email.should.equal("imatester@fannect.me")
            context.body.first_name.should.equal("Bill")
            context.body.last_name.should.equal("Tester")
            should.not.exist(context.body.password)

         it "should create a new user in mongo", (done) ->
            context = @
            User.findById context.body._id, (err, user) ->
               return done(err) if err
               user.email.should.equal("imatester@fannect.me")
               user.first_name.should.equal("Bill")
               user.last_name.should.equal("Tester")
               user.password.should.not.equal("hi")
               done()

         it "should access_token to redis", (done) ->
            context = @
            redis.get context.body.access_token, (err, user) ->
               return done(err) if err
               user = JSON.parse(user)
               user.email.should.equal("imatester@fannect.me")
               user.first_name.should.equal("Bill")
               user.last_name.should.equal("Tester")
               should.not.exist(user.password)
               done()


   # describe "/v1/users/[user_id]/password", () ->
   #    describe "POST"
   #       it ""


