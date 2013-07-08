_ = require 'underscore'


webConfig = 
  getHeader : (requestUrl) ->
    navData = [
      {
        url : '/'
        title : '盈盛行'
      }
      # {
      #   url : '/management'
      #   title : '管理系统'
      # }
      # {
      #   url : '/sell'
      #   title : '销售单'
      # }
      # {
      #   url : '/buy'
      #   title : '进货单'
      # }
      # {
      #   url : '/transfer'
      #   title : '转仓单'
      # }
    ]
    
    urlList = _.pluck navData, 'url'
    sortUrlList = _.sortBy urlList, (url) ->
      return -url.length
    baseUrl = ''
    if requestUrl == '/'
      baseUrl = requestUrl
    else
      _.each sortUrlList, (url, i) ->
        if !baseUrl && url != '/'
          if ~requestUrl.indexOf url
            baseUrl = url
    return {
      selectedIndex : _.indexOf urlList, baseUrl
      navData : navData
    }

module.exports = webConfig