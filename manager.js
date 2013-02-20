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
// mongoose.connect(process.env.MONGO_URL || "mongodb://halloffamer:krzj2blW7674QGk3R1ll967LO41FG1gL2Kil@fannect-production.member0.mongolayer.com:27017/fannect-production");
mongooseTypes.loadTypes(mongoose);

var Team = require("./common/models/Team");

var scheduler = require("./actions/scheduler");
var previewer = require("./actions/previewer");
var postgame = require("./actions/postgame");
var bookie = require("./actions/bookie");
var commissioner = require("./actions/commissioner");

program
.command("schedules")
.description("Updates the schedule for a league")
.option("-l, --league <league_key>", "league key to update schedules")
.option("-t, --team <team_key>", "team key to update schedules")
.action(function (cmd) {
   start = new Date() / 1;

   if (cmd.league) {
      scheduler.update(cmd.league, function (err) {
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
   } else if (cmd.team) {
      Team.findOne({ team_key: cmd.team }, "schedule team_key", function (err, team) {
         if (err) {
            console.error("Completed (" + (((new Date() / 1) - start) / 1000.0) + ") with errors");
            console.error(err.stack || err);
            process.exit(1);
            return;
         }
         scheduler.updateTeam(team, function (err) {
            end = (((new Date() / 1) - start) / 1000.0)
            if (err) {
               console.error("Completed (" + end + ") with errors");
               console.error(err.stack || err);
               process.exit(1);
            } else {
               console.log("Completed (" + end + "s)");
               process.exit(0);
            }
         });
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
            console.error("Completed (" + end + ") with errors:");
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
.option("-b, --bookie", "run bookie after postgame finished")
.action(function (cmd) {
   start = new Date() / 1;
   postgame.update(cmd.bookie || false, function (err) {
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

program
.command("commissioner")
.description("Updates all events")
.action(function (cmd) {
   start = new Date() / 1;
   commissioner.processAll(function (err) {
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

program
.command("list")
.description("Lists all league keys")
.action(function (cmd) {
   Team.aggregate({ "$group": { _id: "$league_key" }}, function (err, leagues) {
      if (err) {
         console.error(err);
      } else {
         for (var i = leagues.length - 1; i >= 0; i--) {
            console.log(leagues[i]._id);
         }
      }
      process.exit();
   });
});

program
.command("bookie")
.description("Processes all scores and team's that require it")
.action(function (cmd) {
   start = new Date() / 1;
   bookie.updateAll(function (err) {
      end = (((new Date() / 1) - start) / 1000.0)
      if (err) {
         console.error("Completed (" + end + ") with errors:");
         console.error(err.stack);
         process.exit(1);
      } else {
         console.log("Completed (" + end + "s)");
         process.exit();
      }
   });
});

program
.command("rank")
.description("Updates the schedule for a league")
.option("-t, --team <team_key>", "team key to update rank")
.action(function (cmd) {
   start = new Date() / 1;

   if (!cmd.team) {
      console.log("team_key is required!");
      process.exit(1);
      return;
   }

   Team.findOne({ team_key: cmd.team }, "schedule.postgame sport_key needs_processing is_processing points", function (err, team) {
      if (err) {
         console.error("Completed (" + (((new Date() / 1) - start) / 1000.0) + ") with errors");
         console.error(err.stack || err);
         process.exit(1);
         return;
      }
      else if (!team) {
         console.error("Completed (" + (((new Date() / 1) - start) / 1000.0) + ") invalid team_key");
         process.exit(1);
         return;
      }
      bookie.rankTeam(team, function (err) {
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
   });
});

program.parse(process.argv);
