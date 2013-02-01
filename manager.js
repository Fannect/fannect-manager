#! /usr/bin/env node
/*
Environmental variables
 - PORT
 - MONGO_URL
 - REDIS_URL
*/

require("coffee-script")
var program = require("commander");

// var load = require("./utils/loader");

// var build_action = require("./actions/build");
// var watch_action = require("./actions/watch");

// var CommandRunner = require("./utils/commandRunner");

// program
//    .option("-o, --output <path>", "change the output directory, defaults to '/bin'")
//    .option("-c, --chdir <path>", "change the working directory")
//    .option("-e, --empty", "empties output directory (excluding .git and .gitignore)", false)
//    .option("-r, --run <command>", "runs command after successful run")
//    .option("-d, --debug", "does not minify JS and CSS", false)
//    .option("-s, --silent", "suppresses console.logs", false);

var xml = require("./xml")

program
   .command("run")
   .description("run command")
   .action(function (cmd) {
      xml()
      config = load(program);
      // build_action(config);
   });

program.parse(process.argv);
