RestError = require "./RestError"

class NotAuthorizedError extends RestError
   constructor: (message) ->
      super(401, "not_authorized", message)

module.exports = NotAuthorizedError