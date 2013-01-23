RestError = require "./RestError"

class InvalidArgumentError extends RestError
   constructor: (message) ->
      super(400, "invalid_argument", message)

module.exports = InvalidArgumentError