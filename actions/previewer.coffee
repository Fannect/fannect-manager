Team = require "../common/models/Team"
parser = require "../common/utils/xmlParser"
request = require "request"
async = require "async"
log = require "../utils/Log"
sportsML = require "../common/sportsMLParser/sportsMLParser"

url = process.env.XMLTEAM_URL or "http://fannect:k4ns4s@sportscaster.xmlteam.com/gateway/php_ci"

# Colors
red = "\u001b[31m"
green = "\u001b[32m"
white = "\u001b[37m"
reset = "\u001b[0m"

previewer = module.exports =
   
   updateAll: (cb) ->
      log.empty()
      log.write "#{white}Starting previewer... #{green}#{new Date()}#{reset}"

      Team
      .aggregate { $group: { _id: "$league_key" }}
      , (err, leagues) ->
         return cb(err) if err

         errors = []
         count = 0
         for l in leagues
            do (league = l) ->
               count++
               previewer.update league._id, (err) -> 
                  if --count <= 0
                     log.sendErrors("Previewer", cb)

   update: (league_key, cb) ->
      errors = []

      request.get
         url: "#{url}/searchDocuments.php"            
         qs:
            "league-keys": league_key
            "fixture-keys": "pre-event-coverage"
            "max-result-count": 80
            "content-returned": "all-content"
         timeout: 30000
      , (err, resp, body) ->
         if err
            log.error("#{red}Failed: XML Team request failed #{team.team_key}#{reset} \nError:\n#{JSON.stringify(err)}")
            return cb(err)   

         if body.indexOf("<xts:sports-content-set />") > -1
            log.write("In progress: #{team.team_key}")
            return cb()

         sportsML.preview body, (err, preview) ->
            return cb(err) if err
            
            unless preview
               log.write("#{white}No articles: #{league_key}#{reset} (league_key)")
               return cb()   

            unless (preview.articles?.length > 0)
               log.write("#{white}No articles: #{league_key}#{reset} (league_key)")
               return cb() 

            count = 0

            for a in preview.articles
               do (article = a) ->
                  count++

                  if not (article.isValid())
                     return log.error("#{red}Error: Unable to parse for league: #{league_key}#{reset}")
                        
                  previewText = "<p>" + Array.prototype.join.call(article.preview, "</p><p>") + "</p>"

                  Team.update {
                     league_key: league_key
                     "schedule.pregame.event_key": article.event_key 
                  }
                  , { "schedule.pregame.preview": previewText }
                  , { multi: true }
                  , (err, data) ->
                     if err then log.error(err) if err
                     else log.write("#{white}Finished: #{article.event_key} #{reset}(event_key)")

                     if --count <= 0
                        return cb(errors) if errors.length > 0
                        cb()

