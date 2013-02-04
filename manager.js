#! /usr/bin/env node
/*
Environmental variables
 - MONGO_URL
 - XMLTEAM_URL
*/
require("coffee-script")
var program = require("commander");

var mongoose = require("mongoose");
var mongooseTypes = require("mongoose-types");
mongoose.connect(process.env.MONGO_URL || "mongodb://admin:testing@linus.mongohq.com:10064/fannect");
mongooseTypes.loadTypes(mongoose);

var scheduler = require("./actions/scheduler");
var previewer = require("./actions/previewer");
var postgame = require("./actions/postgame");

program
   .command("schedules")
   .description("Updates the schedule for a league")
   .option("-l, --league <league_key>", "league key to update schedules")
   .action(function (cmd) {
      if (cmd.league) {
         start = new Date() / 1;
         scheduler.update(cmd.league, function (err, done) {
            end = (((new Date() / 1) - start) / 1000.0)
            if (err) {
               console.error("Completed (" + end + ") with errors");
               console.error(err.stack);
               process.exit(1);
            } else {
               console.log("Completed (" + end + "s)");
               process.exit(0);
            }
         });
      } else {
         console.error("'league_key' is required!")
         process.exit(1);
      }
   });

program
   .command("previews")
   .description("Updates today's game previews")
   .option("-l, --league <league_key>", "only update for a single league")
   .action(function (cmd) {
      start = new Date() / 1;
      if (cmd.league) {
         previewer.update(cmd.league, function (err) {
            end = (((new Date() / 1) - start) / 1000.0)
            if (err) {
               console.error("Completed (" + end + ") with errors");
               console.error(err.stack);
               process.exit(1);
            } else {
               console.log("Completed (" + end + "s)");
               process.exit();
            }
         });
      } else {
         previewer.updateAll(function (errs) {
            end = (((new Date() / 1) - start) / 1000.0)
            if (errs) {
               console.error("Completed (" + end + ") with errors");
               for (var i = errs.length - 1; i >= 0; i--) {
                  console.error(errs[i].stack);
               };
               process.exit(1);
            } else {
               console.log("Completed (" + end + "s)");
               process.exit();
            }
         });
      }
   });

program
   .command("postgame")
   .description("Updates all postgames")
   .action(function (cmd) {
      start = new Date() / 1;
      postgame.update(function (err) {
         end = (((new Date() / 1) - start) / 1000.0)
         if (err) {
            console.error("Completed (" + end + ") with errors");
            console.error(err.stack);
            process.exit(1);
         } else {
            console.log("Completed (" + end + "s)");
            process.exit();
         }
      });
   });


program.parse(process.argv);
