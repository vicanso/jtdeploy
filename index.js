(function() {
  var async, convertFileName, copyFile, createDirs, deploy, fs, handleFile, handleFiles, isHandleFile, mkdirp, myUtils, parseHandlers, parser, path, program, _;

  async = require('async');

  _ = require('underscore');

  fs = require('fs');

  mkdirp = require('mkdirp');

  path = require('path');

  program = require('commander');

  parser = require('./lib/parser');

  myUtils = require('./lib/utils');

  program.version('0.0.1').option('-s, --source <n>', 'The Source Path').option('-t, --target <n>', 'The Target Path').option('-m, --min <n>', 'The Javascript In This Path Will Be Minify!').parse(process.argv);

  parseHandlers = {
    '.styl': parser.stylus,
    '.js': parser.js,
    '.coffee': parser.coffee
  };

  deploy = function(source, target, minPath) {
    if (minPath == null) {
      minPath = '';
    }
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
        return handleFiles(source, target, minPath, files);
      }
    ], function(err) {
      if (err) {
        return console.error(err);
      }
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
    fs.createReadStream(file).pipe(fs.createWriteStream(targetFile));
    return process.nextTick(function() {
      return cbf(null);
    });
  };

  handleFiles = function(source, target, minPath, files, cbf) {
    var complete, total;
    total = files.length;
    complete = 0;
    return async.eachLimit(files, 10, function(file, cbf) {
      var targetFile;
      targetFile = target + file.substring(source.length);
      complete++;
      if (isHandleFile(file)) {
        handleFile(file, targetFile, minPath, cbf);
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
        return console.dir('complete all!');
      }
    });
  };

  handleFile = function(file, targetFile, minPath, cbf) {
    var ext, handler, min;
    ext = path.extname(file);
    min = false;
    handler = parseHandlers[ext];
    if (minPath && !file.indexOf(minPath)) {
      min = true;
    }
    return async.waterfall([
      function(cbf) {
        return handler(file, cbf);
      }, function(data, cbf) {
        var mapFile, saveFile;
        saveFile = convertFileName(targetFile);
        if (ext === '.js') {
          mapFile = saveFile.substring(0, saveFile.length - ext.length) + '.map';
          fs.writeFile(saveFile, data.code, 'utf8', cbf);
          return fs.writeFile(mapFile, data.map);
        } else {
          return fs.writeFile(saveFile, data, 'utf8', cbf);
        }
      }
    ], cbf);
  };

  if (program.source && program.target) {
    deploy(program.source, program.target, program.minPath);
  } else {
    console.error("the source path and target path must be set!");
  }

}).call(this);
