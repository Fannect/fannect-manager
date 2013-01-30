require "mocha"
should = require "should"
http = require "http"
request = require "request"
mongoose = require "mongoose"
async = require "async"
crypt = require "../common/utils/crypt"
mockAuth = require "./utils/mockAuthenticate"

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
         before (done) ->
            context = @
            request
               url: "#{context.host}/v1/token"
               method: "PUT"
               json: refresh_token: "hereisatoken"
            , (err, resp, body) ->
               return done(err) if err
               context.body = body
               done() 

         it "should retrieve fresh access_token with refresh_token", () ->
            context = @
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

   describe "/v1/users/:user_id", () ->
      describe "PUT", () ->
         it "should update email if email", (done) ->
            context = @
            user_id = "5102b17168a0c8f70c000102"
            request
               url: "#{context.host}/v1/users/#{user_id}"
               method: "PUT"
               json: { email: "hithere@fannect.me" }
            , (err, resp, body) ->
               return done(err) if err
               body.status.should.equal("success")
               body.refresh_token.should.be.ok
               User.findById user_id, "email", (err, user) ->
                  return done(err) if err
                  user.email.should.equal("hithere@fannect.me")
                  done()

         it "should update password if password", (done) ->
            context = @
            user_id = "5102b17168a0c8f70c000102"
            pw = "newpassword"
            request
               url: "#{context.host}/v1/users/#{user_id}"
               method: "PUT"
               json: { password: pw }
            , (err, resp, body) ->
               return done(err) if err
               body.status.should.equal("success")
               body.refresh_token.should.be.ok
               User.findById user_id, "password", (err, user) ->
                  return done(err) if err
                  user.password.should.equal(crypt.hashPassword(pw))
                  done()

         it "should update both if both", (done) ->
            context = @
            user_id = "5102b17168a0c8f70c000102"
            pw = "newpassword2"
            request
               url: "#{context.host}/v1/users/#{user_id}"
               method: "PUT"
               json: { email: "hithere2@fannect.me", password: pw  }
            , (err, resp, body) ->
               return done(err) if err
               body.status.should.equal("success")
               body.refresh_token.should.be.ok
               User.findById user_id, "email password", (err, user) ->
                  return done(err) if err
                  user.email.should.equal("hithere2@fannect.me")
                  user.password.should.equal(crypt.hashPassword(pw))
                  done()

   describe "/v1/reset", () ->
      before (done) ->
          dbSetup.unload () -> dbSetup.load data_standard, done
      after (done) -> dbSetup.unload done

      describe "POST", () ->
         it "should set to new password", (done) ->
            context = @
            pw = "hi"
            request
               url: "#{context.host}/v1/reset"
               method: "POST"
               json:
                  email: "testingmctester@fannect.me"
            , (err, resp, body) ->
               return done(err) if err
               body.status.should.equal("success")
               done()

         it "should fail with 400 if invalid email", (done) ->
            context = @
            request
               url: "#{context.host}/v1/reset"
               method: "POST"
               json:
                  email: "immafailure@fannect.me"
            , (err, resp, body) ->
               return done(err) if err
               body.status.should.equal("fail")
               done()


