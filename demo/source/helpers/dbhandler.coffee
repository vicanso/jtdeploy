_ = require 'underscore'
async = require 'async'

ysDbClient = require('jtmongodb').getClient 'ys'

dbHandler = 
  updateItemStocks : (type, collection, depots, items) ->
    if type == 'transfer'
      fromDepot = depots[0]
      toDepot = depots[1]
    else
      depot = depots[0]
    async.eachLimit items, 5, (item) ->
      inc = {}
      count = GLOBAL.parseInt item.count
      if type == 'sell'
        count = -count
      if collection == 'draft'
        inc["stocksForecast.#{depot}"] = count
      else
        if type == 'sell'
          inc["stocks.#{depot}"] = count
        else if type == 'transfer'
          inc["stocks.#{toDepot}"] = count
          inc["stocksForecast.#{toDepot}"] = count
          inc["stocks.#{fromDepot}"] = -count
          inc["stocksForecast.#{fromDepot}"] = -count
        else
          inc["stocks.#{depot}"] = count
          inc["stocksForecast.#{depot}"] = count
      ysDbClient.update 'items', {_id : item._id}, {'$inc' : inc}, (err) ->
    , () ->
  getDepots : (cbf) ->
     ysDbClient.find 'depots', {}, cbf
  saveData : (collection, data, cbf) ->
    id = data._id
    delete data._id
    async.auto {
      checkData : (cbf) ->
        if !data
          err = new Error
          err.msg = '提交数据为空'
          cbf err
        else if id
          ysDbClient.findAndRemove 'drafts', {_id : id}, (err, data) ->
            if err
              cbf err
            else if !data
              err = new Error
              err.msg = '删除草稿失败'
              cbf err
            else
              dbHandler.updateItemStocks data.type, 'drafts', [data.depot], data.items
              cbf null
        else
          cbf null
      saveData : ['checkData', (cbf) ->
        data.createdAt = new Date()
        ysDbClient.save collection, data, cbf
      ]
      updateData : ['saveData', (cbf) ->
        if data.type == 'transfer'
          depots = [data.fromDepot, data.toDepot]
        else
          depots = [data.depot]
        dbHandler.updateItemStocks data.type, collection, depots, data.items
        process.nextTick () ->
          cbf null
      ]
    }, (err) ->
      if err
        cbf null, {
          code : -1
          msg : err.msg
        }
      else
        cbf null, {
          code : 0
        }
module.exports = dbHandler