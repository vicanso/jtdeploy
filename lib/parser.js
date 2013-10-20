(function() {
  var async, base64Handler, coffeeScript, convertImageToBase64, fs, less, mkdirp, parser, path, stylus, uglifyJS, _;

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
          var err, jsStr;
          try {
            jsStr = coffeeScript.compile(data);
          } catch (_error) {
            err = _error;
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
          var err;
          options = _.extend(defaults, options);
          try {
            data = uglifyJS.minify(data, options);
          } catch (_error) {
            err = _error;
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
    },
    inlineImage: function(css, file, limit, cbf) {
      return convertImageToBase64(css, file, limit, cbf);
    }
  };

  convertImageToBase64 = function(data, file, limit, cbf) {
    var cssData, imageInlineHandle, reg, result, startIndex;
    imageInlineHandle = base64Handler({
      path: path.dirname(file),
      limit: limit
    });
    reg = /background(-image)?\s*?:[^;\n\}]*?url\(([\s\S]*?)\)[\s\S]*?[;\n\}]/g;
    cssData = [];
    result = null;
    startIndex = 0;
    return async.whilst(function() {
      return (result = reg.exec(data)) !== null;
    }, function(cbf) {
      var css, imgUrl, replaceImageUrl;
      css = result[0];
      replaceImageUrl = result[2];
      if (replaceImageUrl.charAt(0) === '\'' || replaceImageUrl.charAt(0) === '"') {
        imgUrl = replaceImageUrl.substring(1, replaceImageUrl.length - 1);
      } else {
        imgUrl = replaceImageUrl;
      }
      cssData.push(data.substring(startIndex, result.index));
      startIndex = result.index;
      if (imgUrl.charAt(0) !== '/' && imgUrl.indexOf('data:')) {
        return imageInlineHandle(imgUrl, function(err, dataUri) {
          var newCss, newImgUrl, tmpCss;
          newImgUrl = '';
          if (dataUri) {
            newImgUrl = dataUri;
          }
          if (newImgUrl) {
            newCss = css.replace(replaceImageUrl, '"' + newImgUrl + '"');
          }
          if (newCss && newCss !== css) {
            tmpCss = css.substring(0, css.length - 1);
            if (dataUri) {
              cssData.push(";*" + tmpCss + ";");
            }
            cssData.push(newCss);
            startIndex += css.length;
          }
          return cbf(err);
        });
      } else {
        return cbf(null);
      }
    }, function(err) {
      cssData.push(data.substring(startIndex));
      return cbf(err, cssData.join(''));
    });
  };

  base64Handler = function(options) {
    var filePath, limit, mimes;
    filePath = options.path;
    limit = options.limit;
    mimes = {
      '.gif': 'image/gif',
      '.png': 'image/png',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.svg': 'image/svg+xml'
    };
    return function(file, cbf) {
      var ext, mime;
      ext = path.extname(file);
      mime = mimes[ext];
      if (!file.indexOf('http' || !mime || !limit)) {
        cbf(null, '');
        return;
      }
      file = path.join(filePath, file);
      return async.waterfall([
        function(cbf) {
          return fs.exists(file, function(exists) {
            if (exists) {
              return fs.readFile(file, cbf);
            } else {
              return cbf(null, '');
            }
          });
        }, function(data, cbf) {
          if (!data || data.length > limit) {
            return cbf(null, '');
          } else {
            return cbf(null, "data:" + mime + ";base64," + (data.toString('base64')));
          }
        }
      ], cbf);
    };
  };

  module.exports = parser;

}).call(this);
