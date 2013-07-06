
async = require 'async'
_ = require 'underscore'
fs = require 'fs'
path = require 'path'
mkdirp = require 'mkdirp'
less = require 'less'
coffeeScript = require 'coffee-script'
uglifyJS = require 'uglify-js'
stylus = require 'stylus'

parser =
  stylus : (file, cbf) ->
    async.waterfall [
      (cbf) ->
        fs.readFile file, 'utf8', cbf
      (data, cbf) ->
        paths = [path.dirname file]
        filename = path.basename file
        stylus.render data, {paths : paths, filename : filename, compress : true}, cbf
    ], cbf
  coffee : (file, cbf) ->
    # if _.isFunction options
    #   cbf = options
    #   options = null
    async.waterfall [
      (cbf) ->
        fs.readFile file, 'utf8', cbf
      (data, cbf) ->
        try
          jsStr = coffeeScript.compile data
        catch err
          cbf err
          return
        cbf null, jsStr
      # (jsStr, cbf) =>
      #   if options?.minify
      #     @js jsStr, {fromString : true}, cbf
      #   else
      #     cbf null, jsStr
    ], cbf
  js : (file, options, cbf) ->
    if _.isFunction options
      cbf = options
      options = null
    defaults = 
      fromString : true
      # warnings : true
      outSourceMap : true
    async.waterfall [
      (cbf) ->
        if options?.fromString
          cbf null, file
        else
          fs.readFile file, 'utf8', cbf
      (data, cbf) ->
        options = _.extend defaults, options
        try
          data = uglifyJS.minify data, options
        catch err
          cbf err
          return
        if data?.code
          cbf null, data.code
        else
          cbf new Error "#{file} minify is fail!"
    ], cbf

module.exports = parser