url = require("url")

module.exports = (redis_url) ->
   parsed_url = url.parse(redis_url || process.env.REDIS_URL || "redis://localhost:6379")
   parsed_auth = (parsed_url.auth || "").split(":")

   client = require("redis").createClient(parsed_url.port, parsed_url.hostname)  

   if password = parsed_url[1]
      client.auth password, (err) -> throw err if err

   if database = parsed_auth[0]
      client.select database
      client.on "connect", () ->
         client.send_anyways = true
         client.select database
         client.send_anyways = false

   return client

client = module.exports.client = null
