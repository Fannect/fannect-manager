(function() {
  var Stadium, Team, async, parser, request, scheduler, url;

  Team = require("../common/models/Team");

  Stadium = require("../common/models/Stadium");

  parser = require("../common/utils/xmlParser");

  request = require("request");

  async = require("async");

  url = process.env.XMLTEAM_URL || "http://fannect:k4ns4s@sportscaster.xmlteam.com/gateway/php_ci";

  scheduler = module.exports = {
    update: function(league_key, cb) {
      return Team.find({
        league_key: league_key
      }).select("schedule team_key").lean().exec(function(err, teams) {
        var t, teamsRunning, _i, _len, _results;
        if (err) {
          return cb(err);
        }
        if ((teams != null ? teams.length : void 0) === 0) {
          return cb(new Error("No teams found"));
        }
        teamsRunning = 0;
        _results = [];
        for (_i = 0, _len = teams.length; _i < _len; _i++) {
          t = teams[_i];
          teamsRunning++;
          _results.push((function(team) {
            if (!team.schedule) {
              team.schedule = {};
            }
            team.schedule.season = [];
            return request.get({
              url: "" + url + "/searchDocuments.php",
              qs: {
                "team-keys": team.team_key,
                "fixture-keys": "schedule-single-team",
                "max-result-count": 1,
                "content-returned": "all-content",
                "earliest-date-time": "20130101T010000"
              }
            }, function(err, resp, body) {
              if (err) {
                return cb(err);
              }
              console.log("BEFORE");
              return parser.parse(body, function(err, doc) {
                var g, game, games, gamesRunning, _j, _len1, _results1;
                console.log("AFTER");
                if (err) {
                  return cb(err);
                }
                if (parser.isEmpty(doc)) {
                  return new Error("No XML Team results for: " + team.team_key);
                }
                games = parser.schedule.parseGames(doc);
                gamesRunning = 0;
                _results1 = [];
                for (_j = 0, _len1 = games.length; _j < _len1; _j++) {
                  g = games[_j];
                  game = parser.schedule.parseGameToJson(g);
                  if (game.is_past) {
                    continue;
                  }
                  game.is_home = game.home_key === team.team_key;
                  gamesRunning++;
                  _results1.push(async.parallel({
                    opponent: function(done) {
                      if (game.is_home) {
                        return Team.findOne({
                          team_key: game.away_key
                        }, "full_name", done);
                      } else {
                        return Team.findOne({
                          team_key: game.home_key
                        }, "full_name", done);
                      }
                    },
                    stadium: function(done) {
                      return Stadium.findOne({
                        stadium_key: game.stadium_key
                      }, done);
                    }
                  }, function(err, results) {
                    var id, _ref, _ref1, _ref2, _ref3, _ref4;
                    if (err) {
                      return cb(err);
                    }
                    game.opponent = (_ref = results.opponent) != null ? _ref.full_name : void 0;
                    game.opponent_id = (_ref1 = results.opponent) != null ? _ref1._id : void 0;
                    game.stadium_name = (_ref2 = results.stadium) != null ? _ref2.name : void 0;
                    game.stadium_location = (_ref3 = results.stadium) != null ? _ref3.location : void 0;
                    game.stadium_coords = (_ref4 = results.stadium) != null ? _ref4.coords : void 0;
                    delete game.home_key;
                    delete game.away_key;
                    delete game.stadium_key;
                    team.schedule.season.push(game);
                    if (--gamesRunning <= 0) {
                      id = team._id;
                      delete team._id;
                      return Team.update({
                        _id: id
                      }, team, function(err) {
                        if (err) {
                          return cb(err);
                        }
                        console.log("Finished: " + team.team_key);
                        if (--teamsRunning <= 0) {
                          return cb();
                        }
                      });
                    }
                  }));
                }
                return _results1;
              });
            });
          })(t));
        }
        return _results;
      });
    }
  };

}).call(this);
