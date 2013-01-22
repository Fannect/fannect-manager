
module.exports = (err, req, res, next) ->
   
   if err
      console.error err.stack
      return res.json
         status: "fail"
         message: err
   else 
      next()