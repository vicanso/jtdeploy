(function() {
  var async, cleanCSS, convertFileName, convertLimitSize, copyFile, createDirs, deploy, fs, handleFile, handleFiles, isHandleFile, minifyCss, mkdirp, myUtils, noop, parseHandlers, parser, path, program, _;

  async = require('async');

  _ = require('underscore');

  fs = require('fs');

  mkdirp = require('mkdirp');

  path = require('path');

  _ = require('underscore');

  program = require('commander');

  cleanCSS = require('clean-css');

  parser = require('./lib/parser');

  myUtils = require('./lib/utils');

  noop = function() {};

  parseHandlers = {
    '.styl': parser.stylus,
    '.js': parser.js,
    '.coffee': parser.coffee
  };

  convertLimitSize = function(limitSize) {
    var lastChar;
    if (!limitSize) {
      return 0;
    }
    limitSize = limitSize.toUpperCase();
    lastChar = limitSize.charAt(limitSize.length - 1);
    limitSize = GLOBAL.parseInt(limitSize);
    if ('K' === lastChar) {
      limitSize *= 1024;
    }
    return limitSize;
  };

  deploy = function(program, cbf) {
    var limitSize, minPath, source, target;
    if (cbf == null) {
      cbf = noop;
    }
    source = program.source;
    target = program.target;
    minPath = program.min;
    limitSize = convertLimitSize(program.size);
    source = path.normalize(source);
    target = path.normalize(target);
    minPath = path.normalize(minPath);
    return async.waterfall([
      function(cbf) {
        return myUtils.getFiles(source, true, cbf);
      }, function(infos, cbf) {
        var dirs, sourceLength;
        sourceLength = source.length;
        dirs = _.map(infos.dirs, function(dir) {
          return target + dir.substring(sourceLength);
        });
        return createDirs(dirs, function(err) {
          if (err) {
            return cbf(err);
          } else {
            return cbf(null, infos.files);
          }
        });
      }, function(files, cbf) {
        return handleFiles(source, target, minPath, limitSize, files, cbf);
      }
    ], function(err) {
      if (err) {
        console.error(err);
      }
      return cbf(err);
    });
  };

  createDirs = function(dirs, cbf) {
    return async.eachLimit(dirs, 10, function(dir, cbf) {
      return mkdirp(dir, cbf);
    }, cbf);
  };

  isHandleFile = function(file) {
    var ext, handleFileExts;
    handleFileExts = ['.coffee', '.styl', '.js'];
    ext = path.extname(file);
    if (!~_.indexOf(handleFileExts, ext) || ~file.indexOf('.min.js')) {
      return false;
    } else {
      return true;
    }
  };

  convertFileName = function(file) {
    var ext, nexExt;
    nexExt = ext = path.extname(file);
    if (ext === '.coffee') {
      nexExt = '.js';
    } else if (ext === '.styl') {
      nexExt = '.css';
    }
    return file.substring(0, file.length - ext.length) + nexExt;
  };

  copyFile = function(file, targetFile, cbf) {
    return async.waterfall([
      function(cbf) {
        return fs.readFile(file, cbf);
      }, function(data, cbf) {
        return fs.writeFile(targetFile, data, cbf);
      }
    ], cbf);
  };

  handleFiles = function(source, target, minPath, limitSize, files, cbf) {
    var complete, total;
    total = files.length;
    complete = 0;
    return async.eachLimit(files, 10, function(file, cbf) {
      var ext, min, targetFile;
      targetFile = target + file.substring(source.length);
      ext = path.extname(file);
      complete++;
      min = false;
      if (minPath && !file.indexOf(minPath)) {
        min = true;
      }
      if (ext === '.js' && !min) {
        copyFile(file, targetFile, cbf);
      } else if (isHandleFile(file)) {
        handleFile(file, targetFile, min, limitSize, cbf);
      } else if (ext === '.css') {
        minifyCss(file, targetFile, limitSize, cbf);
      } else {
        copyFile(file, targetFile, cbf);
      }
      if (!(complete % 10)) {
        return console.dir("complete:" + complete + "/" + total);
      }
    }, function(err) {
      if (err) {
        return cbf(err);
      } else {
        fs.writeFile("" + target + "/version", Date.now());
        console.dir('complete all!');
        return cbf(null);
      }
    });
  };

  minifyCss = function(file, targetFile, limitSize, cbf) {
    return async.waterfall([
      function(cbf) {
        return fs.readFile(file, 'utf8', cbf);
      }, function(data, cbf) {
        var css;
        css = cleanCSS.process(data, {
          keepSpecialComments: 1,
          removeEmpty: true
        });
        return cbf(null, css);
      }, function(data, cbf) {
        if (limitSize) {
          return parser.inlineImage(data, file, limitSize, cbf);
        } else {
          return cbf(null, data);
        }
      }, function(data, cbf) {
        return fs.writeFile(targetFile, data, cbf);
      }
    ], cbf);
  };

  handleFile = function(file, targetFile, min, limitSize, cbf) {
    var ext, handler;
    ext = path.extname(file);
    handler = parseHandlers[ext];
    return async.waterfall([
      function(cbf) {
        return handler(file, cbf);
      }, function(data, cbf) {
        if (min && ext === '.coffee') {
          return parser.js(data, {
            fromString: true
          }, cbf);
        } else if (ext === '.styl' && limitSize) {
          return parser.inlineImage(data, file, limitSize, cbf);
        } else {
          return cbf(null, data);
        }
      }, function(data, cbf) {
        var saveFile;
        saveFile = convertFileName(targetFile);
        return fs.writeFile(saveFile, data, 'utf8', cbf);
      }
    ], cbf);
  };

  module.exports = deploy;

  if (require.main === module) {
    program.version('0.0.1').option('-s, --source <n>', 'The Source Path').option('-t, --target <n>', 'The Target Path').option('-m, --min <n>', 'The Javascript In This Path Will Be Minify!').option('--size <n>', 'Inline Image\'s limit size, eg. 10k').parse(process.argv);
    if (program.source && program.target) {
      deploy(program);
    } else {
      console.error("the source path and target path must be set!");
    }
  }

}).call(this);
