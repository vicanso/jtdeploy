(function() {
  var async, coffeeScript, fs, less, mkdirp, parser, path, stylus, uglifyJS, _;

  async = require('async');

  _ = require('underscore');

  fs = require('fs');

  path = require('path');

  mkdirp = require('mkdirp');

  less = require('less');

  coffeeScript = require('coffee-script');

  uglifyJS = require('uglify-js');

  stylus = require('stylus');

  parser = {
    stylus: function(file, cbf) {
      return async.waterfall([
        function(cbf) {
          return fs.readFile(file, 'utf8', cbf);
        }, function(data, cbf) {
          var filename, paths;
          paths = [path.dirname(file)];
          filename = path.basename(file);
          return stylus.render(data, {
            paths: paths,
            filename: filename,
            compress: true
          }, cbf);
        }
      ], cbf);
    },
    coffee: function(file, cbf) {
      return async.waterfall([
        function(cbf) {
          return fs.readFile(file, 'utf8', cbf);
        }, function(data, cbf) {
          var jsStr;
          try {
            jsStr = coffeeScript.compile(data);
          } catch (err) {
            cbf(err);
            return;
          }
          return cbf(null, jsStr);
        }
      ], cbf);
    },
    js: function(file, options, cbf) {
      var defaults;
      if (_.isFunction(options)) {
        cbf = options;
        options = null;
      }
      defaults = {
        fromString: true,
        outSourceMap: true
      };
      return async.waterfall([
        function(cbf) {
          if (options != null ? options.fromString : void 0) {
            return cbf(null, file);
          } else {
            return fs.readFile(file, 'utf8', cbf);
          }
        }, function(data, cbf) {
          options = _.extend(defaults, options);
          try {
            data = uglifyJS.minify(data, options);
          } catch (err) {
            cbf(err);
            return;
          }
          if (data != null ? data.code : void 0) {
            return cbf(null, data.code);
          } else {
            return cbf(new Error("" + file + " minify is fail!"));
          }
        }
      ], cbf);
    }
  };

  module.exports = parser;

}).call(this);
