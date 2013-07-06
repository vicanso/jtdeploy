(function() {
  var UTILS, async, fs, noop, path, _;

  _ = require('underscore');

  fs = require('fs');

  async = require('async');

  path = require('path');

  noop = function() {};

  UTILS = {
    getFiles: function(searchPaths, recursion, cbf) {
      var handles, resultInfos;
      if (!_.isArray(searchPaths)) {
        searchPaths = [searchPaths];
      } else {
        searchPaths = _.clone(searchPaths);
      }
      if (_.isFunction(recursion)) {
        cbf = recursion;
        recursion = false;
      }
      resultInfos = {
        files: [],
        dirs: []
      };
      handles = [
        function(cbf) {
          return GLOBAL.setImmediate(function() {
            return cbf(null, searchPaths);
          });
        }, function(paths, cbf) {
          var _files;
          _files = [];
          return async.eachLimit(paths, 10, function(_path, cbf) {
            return fs.readdir(_path, function(err, files) {
              if (err) {
                return cbf(err);
              } else {
                _files = _files.concat(_.map(files, function(file) {
                  if (file.charAt(0) === '.') {
                    return null;
                  } else {
                    return path.join(_path, file);
                  }
                }));
                return cbf(null);
              }
            });
          }, function(err) {
            return cbf(err, _.compact(_files));
          });
        }, function(files, cbf) {
          var _dirs, _files;
          _files = [];
          _dirs = [];
          return async.eachLimit(files, 10, function(file, cbf) {
            return fs.stat(file, function(err, stats) {
              if (!err && stats) {
                if (stats.isDirectory()) {
                  _dirs.push(file);
                } else {
                  _files.push(file);
                }
              }
              return cbf(err);
            });
          }, function(err) {
            return cbf(err, {
              files: _files,
              dirs: _dirs
            });
          });
        }
      ];
      async.whilst(function() {
        return searchPaths.length > 0;
      }, function(cbf) {
        return async.waterfall(handles, function(err, result) {
          if (recursion && result) {
            searchPaths = result.dirs;
          } else {
            searchPaths = [];
          }
          if (result) {
            resultInfos.files = resultInfos.files.concat(result.files);
            resultInfos.dirs = resultInfos.dirs.concat(result.dirs);
          }
          return cbf(err);
        });
      }, function(err) {
        return cbf(err, resultInfos);
      });
      return this;
    }
  };

  module.exports = UTILS;

}).call(this);
