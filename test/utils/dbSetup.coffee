User = require "../../common/models/User"
redis = require "../../common/utils/redis"

module.exports =

   load: (users, cb) -> User.create(users, cb)
   unload: (cb) -> User.remove({ last_name: "Tester" }, cb)


