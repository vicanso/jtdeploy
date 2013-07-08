_ = require 'underscore'
async = require 'async'

appConfig = require '../config'
appPath = appConfig.getAppPath()
webConfig = require "#{appPath}/helpers/webconfig"
ysDbClient = require('jtmongodb').getClient 'ys'
redisClient = require('jtredis').getClient 'vicanso'
dbHandler = require "#{appPath}/helpers/dbhandler"



pageContentHandler =
  index : (req, res, cbf) ->
    viewData =
      header : webConfig.getHeader req.url
    currentPage = Math.floor req.param('page') || 1
    limit = 60
    skip = limit * (currentPage - 1)
    async.parallel [
      (cbf) ->
        ysDbClient.count 'items', {}, cbf
      (cbf) ->
        ysDbClient.find 'items', {}, {limit : limit, skip : skip}, cbf
    ], (err, data) ->
      if err
        cbf err
        return
      else if !data.length
        err = new Error 'the data is empty!'
        cbf err
        return
      items = [[], [], [], []]
      itemsLength = items.length
      total = data[0]
      docs = data[1]
      fixedWidth = 210
      _.each docs, (doc, i) ->
        width = doc.imgSize.width
        doc.imgSize.height = Math.floor 210 / doc.imgSize.width * doc.imgSize.height
        items[i % itemsLength].push doc
      viewData.items = items
      viewData.pageInfo = 
        start : Math.max 1, currentPage - 5
        current : currentPage
        end : Math.ceil total / limit
        urlPrefix : ''
      cbf null, {
        title : '盈盛行'
        viewData : viewData
      }
  management : (req, res, cbf) ->
    viewData =
      header : webConfig.getHeader req.url
    cbf null, {
      title : '管理系统'
      viewData : viewData
    }
  sell : (req, res, cbf) ->
    viewData =
      header : webConfig.getHeader req.url
    id = req.param 'id'
    async.parallel {
      depots : dbHandler.getDepots
      sellData : (cbf) ->
        if id
          ysDbClient.findById 'drafts', id, cbf
        else
          process.nextTick () ->
            cbf null
    }, (err, data) ->
      viewData.depots =  data.depots
      viewData.sellData = data.sellData
      cbf null, {
        title : '销售单'
        viewData : viewData
      }
  buy : (req, res, cbf) ->
    viewData =
      header : webConfig.getHeader req.url
    async.parallel {
      depots : dbHandler.getDepots
    }, (err, data) ->
      viewData.depots =  data.depots
      cbf null, {
        title : '进货单'
        viewData : viewData
      }
  transfer : (req, res, cbf) ->
    viewData =
      header : webConfig.getHeader req.url
    async.parallel {
      depots : dbHandler.getDepots
    }, (err, data) ->
      viewData.depots =  data.depots
      cbf null, {
        title : '转仓单'
        viewData : viewData
      }
  query : (req, res, cbf) ->
    viewData =
      header : webConfig.getHeader req.url
    viewData.date =
      from : Date.yesterday().toFormat 'YYYY-MM-DD'
      to : Date.today().toFormat 'YYYY-MM-DD'
    cbf null, {
      title : '查询功能'
      viewData : viewData
    }
  items : (req, res, cbf) ->
    async.waterfall [
      (cbf) ->
        ysDbClient.find 'items', {}, {limit : 0}, cbf
    ], (err, data) ->
      if err
        cbf null, {
          code : -1
          msg : '获取产品列表失败！'
        }
      else
        cbf null, {
          code : 0
          data : data
        }
  save : (req, res, cbf) ->
    userInfo = req.session.userInfo
    if userInfo.permissions > 1
      req.body.oper = userInfo.name
      dbHandler.saveData 'orders', req.body, cbf
    else
      cbf null, {
        code : -1
        msg : '用户没有权限，保存失败！'
      }
  tempSave : (req, res, cbf) ->
    userInfo = req.session.userInfo
    if userInfo.permissions > 1
      req.body.oper = userInfo.name
      dbHandler.saveData 'drafts', req.body, cbf
    else
      cbf null, {
        code : -1
        msg : '用户没有权限，保存草稿失败！'
      }

  orderNo : (req, res, cbf) ->
    type = req.param 'type'
    if type
      type = type.toUpperCase()
      date = new Date().toFormat 'YYYYMMDD'
      key = "#{type}-#{date}"
      async.waterfall [
        (cbf) ->
          redisClient.INCR key, cbf
        (data, cbf) ->
          orderNo = '0000' + data
          cbf null, orderNo.substring orderNo.length - 4
      ], (err, orderNo) ->
        if err
          cbf null, {
            code : -1
            msg : err
          }
        else
          cbf null, {
            code : 0
            orderNo : "#{key}-#{orderNo}"
          }
    else
      cbf null, {
        code : -1
        msg : 'the param type is null'
      }
  userInfo : (req, res, cbf) ->
    userInfo = req.session?.userInfo || {name : '匿名用户', permissions : -1}
    cbf null, {
      code : 0
      data : userInfo
    }
  logout : (req, res, cbf) ->
    req.session.userInfo = {name : '匿名用户', permissions : -1}
    cbf null, {
      code : 0
      msg : '退出登录成功!'
    }
  login : (req, res, cbf) ->
    sess = req.session
    ysDbClient.findOne 'users', req.body, (err, doc) ->
      if err || !doc
        cbf null, {
          code : -1
          msg : '登录失败'
        }
      else
        sess.userInfo = doc
        cbf null, {
          code : 0
          data : doc
        }
  search : (req, res, cbf) ->
    fromDate = new Date req.param('from') || Date.yesterday
    toDate = new Date req.param('to') || Date.today
    collection = req.param 'collection'
    if fromDate > toDate
      tmpDate = fromDate
      fromDate = toDate
      toDate = tmpDate
    toDate = toDate.addDays 1
    query = 
      createdAt : 
        '$gt' : fromDate
        '$lt' : toDate
    fields = 'type id depot client payType priceTotal profitTotal inputPriceTotal createdAt oper remark'
    ysDbClient.find collection, query, fields, (err, docs) ->
      if err
        docs = []
      _.each docs, (doc) ->
        doc.createdAt = new Date(doc.createdAt).toFormat 'YYYY-MM-DD'
      cbf null, {
        code : 0
        data : docs
      }
  addUser : (req, res, cbf) ->
    user = req.body
    user.permissions = 2
    userInfo = req.session?.userInfo
    async.waterfall [
      (cbf) ->
        if !userInfo || userInfo.permissions < 9
          err = new Error
          err.msg = '该用户没有权限'
          cbf err
        else
          cbf null
      (cbf) ->
        ysDbClient.findOne 'users', {name : user.name}, cbf
      (doc, cbf) ->
        console.dir doc
        if doc
          err = new Error
          err.code = -1
          err.msg = '已存在该用户！'
          cbf err
        else
          console.dir user
          ysDbClient.save 'users', user, cbf
    ], (err) ->
      if err
        cbf null, {
          code : -1
          msg : err.msg || err.toString()
        }
      else
        cbf null, {
          code : 0
          msg : '创建用户成功！'
        }

_.delay () ->
  # ysDbClient.find 'orders', {}, {limit : 0}, (err, docs) ->
  #   console.dir docs.length
  #   _.each docs, (doc) ->
  #     ysDbClient.findAndRemove 'orders', {_id : doc._id}, (err) ->
  # return
  
  # ysDbClient.save 'depots', [
  #   {
  #     name : '进货仓'
  #     key : 'JHC'
  #   }
  #   {
  #     name : '街仓'
  #     key : 'JC'
  #   }
  #   {
  #     name : '公司仓'
  #     key : 'GSC'
  #   }
  #   {
  #     name : '德进仓'
  #     key : 'DJC'
  #   }
  # ]

  i = 0

  # fs = require 'fs'
  # fs.readFile "#{appPath}/helpers/test.txt", 'utf8', (err, data) ->
  #   items = data.split '\n'
  #   items = _.map items, (item) ->
  #     infos = _.compact item.trim().split ' '
  #     name = infos[3]
  #     if infos.length == 9 && name
  #       buyPrice = GLOBAL.parseFloat (_.random(100, 1000) / 10).toFixed 2 
  #       price = GLOBAL.parseFloat (buyPrice * 1.1).toFixed 2
  #       serachText = name
  #       stocks = 
  #         JHC : _.random 100, 1000
  #         JC : _.random 100, 1000
  #         GSC : _.random 100, 1000
  #         DJC : _.random 100, 1000
  #       {
  #         name : name
  #         barcode : infos[7]
  #         size : infos[2]
  #         unit : infos[4]
  #         auxiliaryUnit : infos[5]
  #         unitRelation : infos[6]
  #         serachText : serachText
  #         price : price
  #         buyPrice : buyPrice
  #         stocks : stocks
  #         stocksForecast : stocks
  #       }
  #     else
  #       null
  #   items = _.compact items
  #   _.each items, (item, i) ->
  #     item.id = (i + 1) * 10
  #   ysDbClient.save 'items', items, (err) ->
  #     console.dir "success"
  #     console.dir err
, 1000
module.exports = pageContentHandler