Team = require "./common/models/Team"
parser = require "./common/utils/xmlParser"
request = require "request"


url = process.env.XMLTEAM_URL or "http://sportscaster.xmlteam.com/gateway/php_ci"
username = process.env.XMLTEAM_USERNAME or "fannect"
password = process.env.XMLTEAM_PASSWORD or "k4ns4s"

request.auth(username, password, true)

someFunction = () ->
   league_key


   # Get schedules for league
   Team.find { league_key: league_key }, "schedule", (err, teams) ->
      for t in teams
         do (team = t) ->
            request
               url: "#{url}/searchDocuments.php"            
               qs:
                  "team-keys": team.team_key
                  "fixture-keys": "schedule-single-team"
                  "max-result-count": 1
                  "content-returned": "all-content"
            , (err, resp, body) ->
               parser.parse body, (err, doc) ->
               games = parser.parseGames(doc)

               for game in games
                  obj = parser.schedule.parseGameToJson(game)
                  

               


