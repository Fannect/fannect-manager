/*
Environmental variables
 - PORT
 - MONGO_URL
 - REDIS_URL
*/

require("coffee-script");
app = require("./controllers/host.coffee");
server = process.env.NODE_ENV == "production" ? require("https") : require("http");
port = process.env.PORT || 2200;

server.createServer(app).listen(port, function () {
   console.log("Fannect Login API listening on " + port);
});