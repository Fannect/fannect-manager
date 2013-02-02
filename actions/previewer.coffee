Team = require "../common/models/Team"
parser = require "../common/utils/xmlParser"
request = require "request"
async = require "async"

url = process.env.XMLTEAM_URL or "http://sportscaster.xmlteam.com/gateway/php_ci"
username = process.env.XMLTEAM_USERNAME or "fannect"
password = process.env.XMLTEAM_PASSWORD or "k4ns4s"

previewer = module.exports =

   update: (league_key, cb) ->
      request.get
         url: "#{url}/searchDocuments.php"            
         qs:
            "league-keys": league_key
            "fixture-keys": "pre-event-coverage"
            "max-result-count": 40
            "content-returned": "all-content"
         auth:
            user: username
            pass: password
            sendImmediately: true
      , (err, resp, body) ->
         return cb(err) if err   
         parser.parse body, (err, doc) ->
            return cb(err) if err
            articles = parser.preview.parseArticles(doc)

            return cb(null ,"No articles") unless (articles?.length > 0)
            count = 0

            for article in articles
               count++

               articleObj = parser.preview.parseArticleToJson(article)
               if not (articleObj.preview and articleObj.event_key)
                  return cb(new Error("Unable to parse for league: #{league_key}")) unless articleObj
               
               Team.update {
                  league_key: league_key
                  "schedule.pregame.event_key": articleObj.event_key 
               }
               , { $set: {"schedule.pregame.preview": articleObj.preview }}
               , (err, data) ->
                  return cb(err) if err
                  if --count <= 0
                     cb()

