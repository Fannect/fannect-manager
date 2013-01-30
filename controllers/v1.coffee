express = require "express"
mongoose = require "mongoose"
User = require "../common/models/User"
crypt = require "../common/utils/crypt"
redis = require("../common/utils/redis").client
InvalidArgumentError = require "../common/errors/InvalidArgumentError"
NotAuthorizedError = require "../common/errors/NotAuthorizedError"
MongoError = require "../common/errors/MongoError"
RedisError = require "../common/errors/RedisError"
sendgrid = new (require("sendgrid-web"))({ user: "fannect", key: "1Billion!" })
auth = require "../common/middleware/authenticate"

app = module.exports = express()

# Retrieve access_token and refresh_token (login)
app.post "/v1/token", (req, res, next) ->
   # Validate before querying
   if not req.body?.email or not req.body?.password
      next(new InvalidArgumentError("Required: email, password"))
   
   email = req.body.email?.toLowerCase()
   password = crypt.hashPassword(req.body.password)

   User
   .findOne({ "email": email, "password", password })
   .select("_id email first_name last_name refresh_token birth gender")
   .exec (err, user) ->
      return next(new MongoError(err)) if err
      return next(new NotAuthorizedError("Invalid credentials")) if not user
      
      user = user.toObject()

      refresh_token = user.refresh_token
      createAccessToken user, (err, access_token) ->
         return next(err) if err
         
         user.access_token = access_token
         res.json user

# Refresh access_token with refresh_token
app.put "/v1/token", (req, res, next) ->
   next(new InvalidArgumentError("Required: refresh_token")) unless req.body.refresh_token
   
   User
   .findOne({ "refresh_token": req.body.refresh_token })
   .select("_id email first_name last_name refresh_token birth gender")
   .exec (err, user) ->
      return next(new MongoError(err)) if err
      return next(new NotAuthorizedError("Invalid refresh_token")) if not user
      
      createAccessToken user, (err, access_token) ->
         return next(err) if err
         
         res.json
            access_token: access_token
         
app.post "/v1/users", (req, res, next) ->
   if not body = req.body then next(new InvalidArgumentError("Missing body"))

   User.create
      email: body.email
      password: crypt.hashPassword body.password
      first_name: body.first_name
      last_name: body.last_name
      refresh_token: crypt.generateRefreshToken()
      profile_image_url: ""
   , (err, user) ->
      return next(new MongoError(err)) if err

      user = user.toObject()
      delete user.password
      delete user.__v

      refresh_token = user.refresh_token
      createAccessToken user, (err, access_token) ->
         return next(new MongoError(err)) if err
      
         user.access_token = access_token
         res.json user

app.post "/v1/reset", (req, res, next) ->
   email = req.body.email?.trim()
   return next(new InvalidArgumentError("Required: email")) unless email

   token = crypt.generateRefreshToken()
   reset = crypt.generateResetToken()
   pw = crypt.hashPassword(reset)

   User.update { email: email }, { password: pw, refresh_token: token }, (err, data) ->
      return next(new MongoError(err)) if err
      if data == 0
         next(new InvalidArgumentError("Invalid: email"))
      else
         sendgrid.send
            to: email
            from: "admin@fannect.me"
            subject: "Password Reset"
            html: "Your password has been reset! Please copy the following temporary password into the app:\n\n<strong style='font:2em'>#{reset}</strong>"
         , (err) ->
            if err
               next(new InvalidArgumentError("Failed to send email"))
            else
               res.json
                  status: "success"

app.put "/v1/users/:user_id", auth.rookieStatus, (req, res, next) ->
   user_id = req.params.user_id
   email = req.body.email?.trim()
   pw = req.body.password?.trim()

   next(new InvalidArgumentError("Required: email and/or password")) unless (email or pw)

   update = {}
   update.refresh_token = crypt.generateRefreshToken()
   update.email = email if email
   update.password = crypt.hashPassword(pw) if pw

   User.update { _id: user_id }, update, (err, data) ->
      return next(new MongoError(err)) if err

      if data == 0
         next(new InvalidArgumentError("Invalid: user_id"))
      else
         res.json
            status: "success"
            refresh_token: update.refresh_token

createAccessToken = (user, done) ->
   # Create new access_token and store
   access_token = crypt.generateAccessToken()
   redis.setnx access_token, JSON.stringify(user), (err, result) ->
      return done(new RedisError(err)) if err
      
      if result == 0
         createAccessToken(user, done)
      else
         # Set expiration
         redis.expire access_token, 1800

         # If access_token already exsits then try again
         done null, access_token



