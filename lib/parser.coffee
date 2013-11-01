
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
      # (css, cbf) ->
      #   convertImageToBase64 css, file, 10 * 1024, cbf
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
  inlineImage : (css, file, limit, cbf) ->
    convertImageToBase64 css, file, limit, cbf


convertImageToBase64 = (data, file, limit, cbf) ->
  imageInlineHandle = base64Handler {
    path : path.dirname file
    limit : limit
  }
  reg = /background(-image)?\s*?:[^;\n\}]*?url\(([\s\S]*?)\)[\s\S]*?[;\n\}]/g
  cssData = []
  result = null
  startIndex = 0
  async.whilst ->
    (result = reg.exec(data)) != null
  , (cbf) ->
    css = result[0]
    replaceImageUrl = result[2]
    if replaceImageUrl.charAt(0) == '\'' || replaceImageUrl.charAt(0) == '"'
      imgUrl = replaceImageUrl.substring 1, replaceImageUrl.length - 1
    else
      imgUrl = replaceImageUrl
    cssData.push data.substring startIndex, result.index
    startIndex = result.index
    if imgUrl.charAt(0) != '/' && imgUrl.indexOf 'data:'
      imageInlineHandle imgUrl, (err, dataUri) ->
        newImgUrl = ''
        if dataUri
          newImgUrl = dataUri
        if newImgUrl
          newCss = css.replace replaceImageUrl, '"' + newImgUrl + '"'
        if newCss && newCss != css
          tmpCss = css.substring 0, css.length - 1
          cssData.push newCss.substring 0, newCss.length - 1
          if dataUri
            cssData.push ";*#{tmpCss};"
          cssData.push newCss.charAt newCss.length - 1
          startIndex += css.length
        cbf err
    else
      cbf null
  , (err) ->
    cssData.push data.substring startIndex
    cbf err, cssData.join ''

base64Handler = (options) ->
  filePath = options.path
  limit = options.limit
  mimes =
    '.gif' : 'image/gif'
    '.png' : 'image/png'
    '.jpg' : 'image/jpeg'
    '.jpeg' : 'image/jpeg'
    '.svg' : 'image/svg+xml'
  (file, cbf) ->
    ext = path.extname file
    mime = mimes[ext]
    if !file.indexOf 'http' || !mime || !limit
      cbf null, ''
      return
    file = path.join filePath, file
    async.waterfall [
      (cbf) ->
        fs.exists file, (exists) ->
          if exists
            fs.readFile file, cbf
          else
            cbf null, ''
      (data, cbf) ->
        if !data || data.length > limit
          cbf null, ''
        else
          cbf null, "data:#{mime};base64,#{data.toString('base64')}"
    ], cbf

module.exports = parser