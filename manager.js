#! /usr/bin/env node

require("coffee-script")
var program = require("commander");

var mongoose = require("mongoose");
var mongooseTypes = require("mongoose-types");
mongoose.connect(process.env.MONGO_URL || "mongodb://halloffamer:krzj2blW7674QGk3R1ll967LO41FG1gL2Kil@linus.mongohq.com:10045/fannect-dev");
// console.log("RUNNING IN PRODUCTION");
// mongoose.connect(process.env.MONGO_URL || "mongodb://halloffamer:krzj2blW7674QGk3R1ll967LO41FG1gL2Kil@mars.mongohq.com:10029/fannect-prod");
mongooseTypes.loadTypes(mongoose);

var redis = require("./common/utils/redis");
queue = redis(process.env.REDIS_QUEUE_URL || "redis://redistogo:f74caf74a1f7df625aa879bf817be6d1@perch.redistogo.com:9203", "queue");

var Team = require("./common/models/Team");

var scheduler = require("./actions/scheduler");
var previewer = require("./actions/previewer");
var postgame = require("./actions/postgame");
var bookie = require("./actions/bookie");
var commissioner = require("./actions/commissioner");
var judge = require("./actions/judge");
var notifier = require("./actions/notifier");

var TeamRankUpdateJob = require("./common/jobs/TeamRankUpdateJob")

program
.command("schedules")
.description("Updates the schedule for a league")
.option("-l, --league <league_key>", "league key to update schedules")
.option("-t, --team <team_key>", "team key to update schedules")
.option("-f, --file <file_path>", "file to use from schedule information")
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
         
         if (!team) {
            console.log("Team not found:", cmd.team)
            process.exit(1);
            return;
         }

         done = function (err) {
            end = (((new Date() / 1) - start) / 1000.0)
            if (err) {
               console.error("Completed (" + end + ") with errors");
               console.error(err.stack || err);
               process.exit(1);
            } else {
               console.log("Completed (" + end + "s)");
               process.exit(0);
            }
         };

         if (cmd.file) scheduler.updateTeamWithFile(team, cmd.file, done);
         else scheduler.updateTeam(team, done);
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
.description("Updates the rank of TeamProfiles")
.option("-t, --team <team_id>", "team key to update rank")
.action(function (cmd) {
   start = new Date() / 1;

   if (!cmd.team) {
      console.log("team_id is required!");
      process.exit(1);
      return;
   }

   job = new TeamRankUpdateJob({ team_id: cmd.team })
   job.run(function (err) {
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

program
.command("judge")
.description("Judges fan highlights")
.option("-t, --team <team_key>", "only judge for specified team")
.option("-d, --day <day_of_the_week>", "day of the week to run on")
.action(function (cmd) {
   start = new Date() / 1;

   if (cmd.day) {
      curr_day = new Date().getDay()
      days = [ "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday" ]
      wanted_day = days.indexOf(cmd.day.toLowerCase())
      if (curr_day != wanted_day) {
         console.log("Judge postponed, not '" + cmd.day + "'");
         process.exit();
         return;
      }
   }

   if (cmd.team) {
      judge.processTeam(cmd.team, function (err) {
         end = (((new Date() / 1) - start) / 1000.0)
         if (err) {
            console.error("Completed (" + end + "s) with errors:");
            console.error(err.stack);
            process.exit(1);
         } else {
            console.log("Completed (" + end + "s)");
            process.exit();
         }
      });
   } else {
      judge.processAll(function (errs) {
         end = (((new Date() / 1) - start) / 1000.0)
         if (errs) {
            console.error("Completed (" + end + "s) with errors");
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
.command("notify")
.description("Send gameday notification")
.option("-h, --hours <hours>", "hours out to send notification for")
.action(function (cmd) {
   start = new Date() / 1;

   cmd.hours = cmd.hours || 22

   notifier.sendAll(cmd.hours, function (err) {
      end = (((new Date() / 1) - start) / 1000.0)
      if (err) {
         console.error("Completed (" + end + ") with errors");
         console.error(err.stack || err);
         process.exit(1);
         return;
      } else {
         console.log("Completed (" + end + "s)");
         process.exit(0);
      }
   });
});

program.parse(process.argv);
