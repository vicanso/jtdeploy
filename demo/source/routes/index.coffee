config = require '../config'
appPath = config.getAppPath()
pageContentHandler = require "#{appPath}/helpers/pagecontenthandler"
sessionParser = config.sessionParser()
staticsHost = config.getStaticsHost()

routeInfos = [
  {
    route : ['/ys', '/ys/page/:page']
    template : 'ys/index'
    staticsHost : staticsHost
    handler : pageContentHandler.index
  }
  {
    route : '/ys/management'
    template : 'ys/management'
    staticsHost : staticsHost
    handler : pageContentHandler.management
  }
  {
    route : ['/ys/sell', '/ys/sell/:id']
    template : 'ys/sell'
    staticsHost : staticsHost
    handler : pageContentHandler.sell
  }
  {
    route : '/ys/buy'
    template : 'ys/buy'
    staticsHost : staticsHost
    handler : pageContentHandler.buy
  }
  {
    route : '/ys/transfer'
    template : 'ys/transfer'
    staticsHost : staticsHost
    handler : pageContentHandler.transfer
  }
  {
    route : '/ys/query'
    template : 'ys/query'
    staticsHost : staticsHost
    handler : pageContentHandler.query
  }
  {
    route : '/ys/items'
    handler : pageContentHandler.items
  }
  {
    route : '/ys/userinfo'
    middleware : [sessionParser]
    handler : pageContentHandler.userInfo
  }
  {
    route : '/ys/adduser'
    type : 'post'
    middleware : [sessionParser]
    handler : pageContentHandler.addUser
  }
  {
    route : '/ys/login'
    type : 'post'
    middleware : [sessionParser]
    handler : pageContentHandler.login
  }
  {
    route : '/ys/logout'
    middleware : [sessionParser]
    handler : pageContentHandler.logout
  }
  {
    route : '/ys/orderno'
    handler : pageContentHandler.orderNo
  }
  {
    route : '/ys/search'
    handler : pageContentHandler.search
  }
  {
    route : '/ys/save'
    middleware : [sessionParser]
    type : 'post'
    handler : pageContentHandler.save
  }
  {
    route : '/ys/tempsave'
    middleware : [sessionParser]
    type : 'post'
    handler : pageContentHandler.tempSave
  }
]
module.exports = routeInfos