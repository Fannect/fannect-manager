class RestError
   constructor: (code, reason, message) ->  
      @code = code or 400
      @reason = reason
      @message = message

   toResObject: () =>
      return {
         status: "fail"
         reason: @reason
         message: @message
      }

module.exports = RestError