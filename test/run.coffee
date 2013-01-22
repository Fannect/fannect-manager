require "mocha"
should = require "should"
http = require "http"
path = require "path"
checkForErrors = require "./checkForErrors"
viewRender = require "../middleware/viewRender"
fs = require "fs-extra"
Browser = require "zombie"

process.env.NODE_ENV = "production"
app = require "../controllers/host"

describe "Fannect Mobile Web", () ->
   before (done) ->
      context = @
      server = http.createServer(app).listen 0, () ->
         context.host = "http://localhost:#{this.address().port}" 
         done()

   after () ->
      # Clean up connect-assets folder created because we are running in production
      fs.removeSync path.join process.cwd(), "builtAssets"

   describe "page errors", () ->
      # views = viewRender.findViews path.resolve(__dirname, "../views")
      # for page, filename of views
      #    it "should not exist for: #{page}", (done) ->
      #       checkForErrors page, "#{@host}#{page}", done
