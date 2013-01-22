express = require "express"

app = module.exports = express()

express = require "express"
mongoose = require "mongoose"
User = require "../models/User"
crypt = require "../utils/crypt"
redis = require("../utils/redis").client

app = module.exports = express()

# Retrieve access_token and refresh_token (login)
app.post "/v1/token", (req, res, next) ->
   # Validate before querying
   if not req.body?.email or not req.body?.password
      next("Required: email, password")
   
   email = req.body.email?.toLowerCase()
   password = crypt.hashPassword(req.body.password)

   User
   .findOne({ "email": email, "password", password })
   .exec (err, user) ->
      return next(err) if err
      return next("Invalid credentials") if not user
      
      refresh_token = user.refresh_token
      createAccessToken user, (err, access_token) ->
         return next(err) if err
   
         res.json
            user: user
            auth: 
               access_token: access_token
               refresh_token: refresh_token

# Refresh access_token with refresh_token
app.put "/v1/token", (req, res, next) ->
   if not req.body?.refresh_token then next("Required: refresh_token")
   
   User
   .findOne({ "refresh_token": req.body.refresh_token })
   .exec (err, user) ->
      return next(err) if err
      return next("Invalid access_token") if not user
      
      createAccessToken user, (err, access_token) ->
         return next(err) if err
         
         res.json
            access_token: access_token
         
app.post "/v1/users", (req, res, next) ->
   if not body = req.body then next(new Error("Missing body"))

   User.create
      email: body.email
      password: crypt.hashPassword body.password
      first_name: body.first_name
      last_name: body.last_name
      refresh_token: crypt.generateRefreshToken()
   , (err, user) ->
      return next(err) if err

      refresh_token = user.refresh_token
      createAccessToken user, (err, access_token) ->
         return next(err) if err
   
         res.json
            user: user
            auth: 
               access_token: access_token
               refresh_token: refresh_token

createAccessToken = (user, done) ->
   # Clean user object
   delete user.password
   delete user.refresh_token

   # Create new access_token and store
   access_token = crypt.generateAccessToken()
   redis.set access_token, JSON.stringify(user), (err) ->
      if err then done err
      else done null, access_token



