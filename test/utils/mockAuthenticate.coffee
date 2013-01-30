auth = require "../../common/middleware/authenticate"

passthrough = (req, res, next) ->
   req.user = {
      "_id": "5102b17168a0c8f70c000002",
      "email": "testing1@fannect.me",
      "password": "hi",
      "first_name": "Mike",
      "last_name": "Testing",
      "refresh_token": "testingtoken",
      "friends": ["5102b17168a0c8f70c000004"]
   }
   next()

auth.rookieStatus = passthrough
auth.subStatus = passthrough
auth.starterStatus = passthrough
auth.allstarStatus = passthrough
auth.mvpStatus = passthrough
auth.hofStatus = passthrough