window.TIME_LINE.timeEnd 'loadjs'
window.TIME_LINE.time 'execjs'
jQuery ($) ->
  _ = window._
  async = window.async

  archorHandle = () ->
    $(document).on 'click', 'a[href^="http"]', () ->
      @target = '_blank'
      data = 
        url : @href
        type : 'outsideChain'
      $.post '/statistics', data
  hideBaiduIcon = () ->
    $('a[href^="http://tongji.baidu.com"]').hide()

  addModifyBtn = () ->
    $('.article').each () ->
      obj = $ @
      id = obj.attr 'data-id'
      obj.find('.behaviorBtns').append "<a class='btn', href='/savearticle/#{id}?cache=false', target='_blank'>修改</a>"
  postUserInfo = (userInfo) ->
    $.post '/userinfo?cache=false', userInfo

  appendWeiboLogin = (id, cbf) ->
    async.waterfall [
      (cbf) ->
        $.getScript('http://tjs.sjs.sinajs.cn/open/api/js/wb.js?appkey=4276143701').success () ->
            cbf null
      (cbf) ->
        WB2.anyWhere (W) ->
          cbf null, W
      (W, cbf) ->
        W.widget.connectButton {
          id : 'weiboLogin'
          type : '4,2'
          callback : 
            login : (o) ->
              userInfo = 
                name : o.name
                profilePic : o.profile_image_url.replace '/50/', '/30/'
                id : "sinaweibo_#{o.id}"
                location : o.location
                profileUrl : "http://weibo.com/#{o.profile_url}"
              cbf null, userInfo

        }
    ], cbf


  do () ->
    $('#goToTop').click () ->
      $('html, body').animate {
        scrollTop : 0
      }, 200

    $('.article .behaviorBtns').on 'click', '.like', () ->
      obj = $ @
      if obj.hasClass 'liked'
        return
      obj.addClass('liked').text '已喜欢'
      id = obj.closest('.article').attr 'data-id'
      data = 
        type : 'like'
        id : id
      $.post '/statistics', data

    $.get('/userinfo?test=1&cache=false').success (userInfo) ->
      if !userInfo.id
        appendWeiboLogin 'weiboLogin', (err, userInfo) ->
          if !err && userInfo
            postUserInfo userInfo
            $(document).trigger 'login', userInfo
      else
        $('#weiboLogin').html "<div class='userInfoContainer'><a href='#{userInfo.profileUrl}'>#{userInfo.name}</a>(已登录)</div>"
        if userInfo.level == 9
          addModifyBtn()
        $(document).trigger 'login', userInfo


    hideBaiduIcon()
    archorHandle()

  window.TIME_LINE.timeEnd 'all', 'html'
  setTimeout () ->
    data = window.TIME_LINE.getLogs()
    data.type = 'timeline'
    $.post '/statistics', data
  , 0



# window.TIME_LINE = 
#   logs : {}
#   startTimes : {}
#   time : (tag) ->
#     @startTimes[tag] = new Date().getTime();
#     @
#   timeEnd : (tag, startTag) ->
#     startTimes = @startTimes
#     start = startTimes[tag] || startTimes[startTag]
#     if start
#       @logs[tag] = new Date().getTime() - start
#     @
#   getLogs : () ->
#     @logs
