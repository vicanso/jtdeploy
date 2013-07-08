async = require 'async'
_ = require 'underscore'
fs = require 'fs'
mkdirp = require 'mkdirp'
path = require 'path'
program = require 'commander'
cleanCSS = require 'clean-css'
parser = require './lib/parser'
myUtils = require './lib/utils'
program
  .version('0.0.1')
  .option('-s, --source <n>', 'The Source Path')
  .option('-t, --target <n>', 'The Target Path')
  .option('-m, --min <n>', 'The Javascript In This Path Will Be Minify!')
  .parse(process.argv)
parseHandlers = 
  '.styl' : parser.stylus
  '.js' : parser.js
  '.coffee' : parser.coffee

deploy = (source, target, minPath = '') ->
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
      handleFiles source, target, minPath, files, cbf
  ], (err) ->
    if err
      console.error err

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

handleFiles = (source, target, minPath, files, cbf) ->
  total = files.length
  complete = 0
  async.eachLimit files, 10, (file, cbf) ->
    targetFile = target + file.substring source.length
    ext = path.extname file
    complete++
    if isHandleFile file
      handleFile file, targetFile, minPath, cbf
    else if ext == '.css'
      minifyCss file, targetFile, cbf
    else
      copyFile file, targetFile, cbf
    if !(complete % 10)
      console.dir "complete:#{complete}/#{total}"
  , (err) ->
    if err
      cbf err
    else
      console.dir 'complete all!'
      cbf null
minifyCss = (file, targetFile, cbf) ->
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
      fs.writeFile targetFile, data, cbf
  ], cbf

handleFile = (file, targetFile, minPath, cbf) ->
  ext = path.extname file
  min = false
  handler = parseHandlers[ext]
  if minPath && !file.indexOf minPath
    min = true
  async.waterfall [
    (cbf) ->
      handler file, cbf
    (data, cbf) ->
      if min && ext == '.coffee'
        parser.js data, {fromString : true}, cbf
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

if program.source && program.target
  deploy program.source, program.target, program.min

else
  console.error "the source path and target path must be set!"


