RestError = require "./RestError"

class ResourceNotFoundError extends RestError
   constructor: (message) ->
      super(404, "not_found", "Resource not found")

module.exports = ResourceNotFoundError