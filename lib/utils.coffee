_ = require 'underscore'
fs = require 'fs'
async = require 'async'
path = require 'path'
noop = () ->

UTILS = 
	getFiles : (searchPaths, recursion, cbf) ->
    if !_.isArray searchPaths
      searchPaths = [searchPaths]
    else
      searchPaths = _.clone searchPaths
    if _.isFunction recursion
      cbf = recursion
      recursion = false
    resultInfos = 
      files : []
      dirs : []
    handles = [
      (cbf) ->
        GLOBAL.setImmediate () ->
          cbf null, searchPaths
      (paths, cbf) ->
        _files = []
        async.eachLimit paths, 10, (_path, cbf) ->
          fs.readdir _path, (err, files) ->
            if err
              cbf err
            else
              _files = _files.concat _.map files, (file) ->
                if file.charAt(0) == '.'
                  null
                else
                  path.join _path, file
              cbf null
        , (err) ->
          cbf err, _.compact _files
      (files, cbf) ->
        _files = []
        _dirs = []
        async.eachLimit files, 10, (file, cbf) ->
          fs.stat file, (err, stats) ->
            if !err && stats
              if stats.isDirectory()
                _dirs.push file
              else
                _files.push file
            cbf err
        , (err) ->
          cbf err, {
            files : _files
            dirs : _dirs
          }
    ]
    async.whilst () ->
      searchPaths.length > 0
    , (cbf) ->
      async.waterfall handles, (err, result) ->
        if recursion && result
          searchPaths = result.dirs
        else
          searchPaths = []
        if result
          resultInfos.files = resultInfos.files.concat result.files
          resultInfos.dirs = resultInfos.dirs.concat result.dirs
        cbf err
    , (err) ->
      cbf err, resultInfos
    @

module.exports = UTILS