sendgrid = new (require("sendgrid-web"))({ 
   user: process.env.SENDGRID_USER or "fannect", 
   key: process.env.SENDGRID_PASSWORD or "1Billion!" 
})

messages = []
errors = []

log =
   write: (text) ->
      messages.push text
      console.log text

   error: (text) ->
      errors.push text
      console.log text

   sendErrors: (appName, cb) ->
      if errors?.length > 0
         log.send(appName, cb)
      else
         cb()

   empty: () =>
      errors.length = 0
      messages.length = 0
      
   send: (appName, cb) =>
      html = "<h2>Date: #{new Date()}</h2><br/><br/>"
      html += "<h2>Errors: #{errors.length}</h2>"
      html += "#{errors.join('<br/>')}<br/>"
      html += "<h2>Messages: #{messages.length}</h2>"
      html += "#{messages.join('<br/>')}<br/>"

      log.empty()

      if process.env.NODE_ENV == "production"
         sendgrid.send
            to: process.env.EMAIL_TO or "blake@fannect.me"
            from: "logger@fannect.me"
            subject: "Manager Errors: #{appName}"
            html: html
         , cb
      else
         console.log "This would be emailed..."
         console.log html
         cb() if cb
         
module.exports = log