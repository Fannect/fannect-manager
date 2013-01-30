express = require "express"
path = require "path"
mongoose = require "mongoose"
mongooseTypes = require "mongoose-types"
redis = (require "../common/utils/redis")(process.env.REDIS_URL or "redis://redistogo:f74caf74a1f7df625aa879bf817be6d1@perch.redistogo.com:9203")
ResourceNotFoundError = require "../common/errors/ResourceNotFoundError"

app = module.exports = express()

# Settings
app.configure "development", () ->
   app.use express.logger "dev"
   app.use express.errorHandler { dumpExceptions: true, showStack: true }

app.configure "production", () ->
   app.use express.errorHandler()

# Middleware
app.use express.query()
app.use express.bodyParser()
app.use express.static path.join __dirname, "../public"

# Set up mongoose
mongoose.connect process.env.MONGO_URL or "mongodb://admin:testing@linus.mongohq.com:10064/fannect"
mongooseTypes.loadTypes mongoose

# Controllers
app.use require "./v1"

app.all "*", (req, res, next) ->
   next(new ResourceNotFoundError())

# Error handling
app.use require "../common/middleware/handleErrors"
