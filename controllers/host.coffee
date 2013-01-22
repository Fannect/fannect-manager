express = require "express"
path = require "path"
mongoose = require "mongoose"
mongooseTypes = require "mongoose-types"
redis = (require "../utils/redis")(process.env.REDIS_URL or "redis://none:625147d76e1a1383ee5410886458e5c6dcf55705@ec2-107-21-80-75.compute-1.amazonaws.com:2014")

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
app.use express.cookieParser process.env.COOKIE_SECRET or "super duper secret"
app.use express.static path.join __dirname, "../public"

# Set up mongoose
mongoose.connect process.env.MONGO_URL or "mongodb://admin:testing@linus.mongohq.com:10064/fannect"
mongooseTypes.loadTypes mongoose

# Controllers
app.use require "./v1"

# Error handling
app.use require "../middleware/handleErrors"

app.all "*", (req, res) ->
   res.json 404,
      status: "fail"
      message: "Resource not found."