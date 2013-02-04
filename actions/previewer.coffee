Team = require "../common/models/Team"
parser = require "../common/utils/xmlParser"
request = require "request"
async = require "async"

url = process.env.XMLTEAM_URL or "http://fannect:k4ns4s@sportscaster.xmlteam.com/gateway/php_ci"

# Colors
red = "\u001b[31m"
green = "\u001b[32m"
white = "\u001b[37m"
reset = "\u001b[0m"

previewer = module.exports =
   
   updateAll: (cb) ->
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
                  errors.push(err) if err

                  if --count <= 0
                     cb(if errors.length > 0 then errors else null)

   update: (league_key, cb) ->
      errors = []

      request.get
         url: "#{url}/searchDocuments.php"            
         qs:
            "league-keys": league_key
            "fixture-keys": "pre-event-coverage"
            "max-result-count": 40
            "content-returned": "all-content"
         timeout: 30000
      , (err, resp, body) ->
         return cb(err) if err   
         parser.parse body, (err, doc) ->
            return cb(err) if err

            if parser.isEmpty(doc)
               console.log("#{white}No articles: #{league_key}#{reset} (league_key)")
               return cb()   

            articles = parser.preview.parseArticles(doc)

            unless (articles?.length > 0)
               console.log("#{white}No articles: #{league_key}#{reset} (league_key)")
               return cb() 

            count = 0

            for a in articles
               do (article = a) ->
                  count++

                  articleObj = parser.preview.parseArticleToJson(article)
                  if not (articleObj.preview and articleObj.event_key)
                     return cb(new Error("#{red}Error: Unable to parse for league: #{league_key}#{reset}")) unless articleObj
                  
                  preview = "<p>" + Array.prototype.join.call(articleObj.preview, "</p><p>") + "</p>"

                  Team.update {
                     league_key: league_key
                     "schedule.pregame.event_key": articleObj.event_key 
                  }
                  , { "schedule.pregame.preview": preview }
                  , { multi: true }
                  , (err, data) ->
                     if err then errors.push(data)
                     else console.log("#{white}Finished: #{articleObj.event_key} #{reset}(event_key)")

                     if --count <= 0
                        return cb(errors) if errors.length > 0
                        cb()

