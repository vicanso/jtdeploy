async = require 'async'
_ = require 'underscore'
fs = require 'fs'
mkdirp = require 'mkdirp'
path = require 'path'
_ = require 'underscore'
program = require 'commander'
cleanCSS = require 'clean-css'
parser = require './lib/parser'
myUtils = require './lib/utils'
noop = ->

parseHandlers = 
  '.styl' : parser.stylus
  '.js' : parser.js
  '.coffee' : parser.coffee

convertLimitSize = (limitSize) ->
  return 0 if !limitSize
  limitSize = limitSize.toUpperCase()
  lastChar = limitSize.charAt limitSize.length - 1
  limitSize = GLOBAL.parseInt limitSize
  if 'K' == lastChar
    limitSize *= 1024
  limitSize

deploy = (program, cbf = noop) ->
  source = program.source
  target = program.target
  minPath = program.min
  limitSize = convertLimitSize program.size

  source = path.normalize source
  target = path.normalize target
  minPath = path.normalize minPath
  async.waterfall [
    (cbf) ->
      myUtils.getFiles source, true, cbf
    (infos, cbf) ->
      sourceLength = source.length
      dirs = _.map infos.dirs, (dir) ->
        target + dir.substring sourceLength
      createDirs dirs, (err) ->
        if err
          cbf err
        else
          cbf null, infos.files
    (files, cbf) ->
      handleFiles source, target, minPath, limitSize, files, cbf
  ], (err) ->
    if err
      console.error err
    cbf err

createDirs = (dirs, cbf) ->
  async.eachLimit dirs, 10, (dir, cbf) ->
    mkdirp dir, cbf
  , cbf

isHandleFile = (file) ->
  handleFileExts = ['.coffee', '.styl', '.js']
  ext = path.extname file
  if !~_.indexOf(handleFileExts, ext) || ~file.indexOf '.min.js'
    false
  else
    true

convertFileName = (file) ->
  nexExt = ext = path.extname file
  if ext == '.coffee'
    nexExt = '.js'
  else if ext == '.styl'
    nexExt = '.css'
  file.substring(0, file.length - ext.length) + nexExt

copyFile = (file, targetFile, cbf) ->
  async.waterfall [
    (cbf) ->
      fs.readFile file, cbf
    (data, cbf) ->
      fs.writeFile targetFile, data, cbf
  ], cbf
  # fs.createReadStream(file).pipe fs.createWriteStream targetFile
  # process.nextTick ->
  #   cbf null

handleFiles = (source, target, minPath, limitSize, files, cbf) ->
  total = files.length
  complete = 0
  async.eachLimit files, 10, (file, cbf) ->
    targetFile = target + file.substring source.length
    ext = path.extname file
    complete++
    min = false
    if minPath && !file.indexOf minPath
      min = true
    if ext == '.js' && !min
      copyFile file, targetFile, cbf
    else if isHandleFile file
      handleFile file, targetFile, min, limitSize, cbf
    else if ext == '.css'
      minifyCss file, targetFile, limitSize, cbf
    else
      copyFile file, targetFile, cbf
    if !(complete % 10)
      console.dir "complete:#{complete}/#{total}"
  , (err) ->
    if err
      cbf err
    else
      fs.writeFile "#{target}/version", Date.now()
      console.dir 'complete all!'
      cbf null
minifyCss = (file, targetFile, limitSize, cbf) ->
  async.waterfall [
    (cbf) ->
      fs.readFile file, 'utf8', cbf
    (data, cbf) ->
      css = cleanCSS.process data, {
        keepSpecialComments : 1
        removeEmpty : true
      }
      cbf null, css
    (data, cbf) ->
      if limitSize
        parser.inlineImage data, file, limitSize, cbf
      else
        cbf null, data
    (data, cbf) ->
      fs.writeFile targetFile, data, cbf
  ], cbf

handleFile = (file, targetFile, min, limitSize, cbf) ->
  ext = path.extname file
  handler = parseHandlers[ext]
  async.waterfall [
    (cbf) ->
      handler file, cbf
    (data, cbf) ->
      if min && ext == '.coffee'
        parser.js data, {fromString : true}, cbf
      else if ext == '.styl' && limitSize
        parser.inlineImage data, file, limitSize, cbf
      else
        cbf null, data
    (data, cbf) ->
      saveFile = convertFileName targetFile
      fs.writeFile saveFile, data, 'utf8', cbf
  ], cbf
  # handler file, (err, data) ->
  #   if err
  #     cbf err
  #   else if ext == '.coffee'
  #     fs.writeFile convertFileName(targetFile), data, 'utf8', cbf

module.exports = deploy

if require.main == module
  program
    .version('0.0.1')
    .option('-s, --source <n>', 'The Source Path')
    .option('-t, --target <n>', 'The Target Path')
    .option('-m, --min <n>', 'The Javascript In This Path Will Be Minify!')
    .option('--size <n>', 'Inline Image\'s limit size, eg. 10k')
    .parse(process.argv)

  if program.source && program.target
    deploy program

  else
    console.error "the source path and target path must be set!"


