Slack = require('slack-node')
WebSocketClient = require('websocket').client

module.exports = (robot) ->
  apiToken = "xoxp-2481386799-2817341451-3814901862-edb983"
  announce_channel = "#chat_announce"
  slack = new Slack(apiToken)
  THROTTLE_RATE_MS = 1500
  pending_msg_posts = []

  client = new WebSocketClient
  client.on 'connectFailed', (error) ->
    console.log 'Connect Error!: ' + error.toString()
    return
  client.on 'connect', (connection) ->
    console.log 'WebSocket Client Connected'
    connection.on 'error', (error) ->
      console.log 'Connection Error: ' + error.toString()
      return
    connection.on 'close', ->
      console.log 'echo-protocol Connection Closed'
      return
    connection.on 'message', (message) ->
      if message.type == 'utf8'
        console.log 'Received: \'' + message.utf8Data + '\''
        return

  slack.api('rtm.start',{},
    (err, response) =>
      console.log "Attempting connection to #{response.url}"
      client.connect(response.url, 'slack-protocol');
    )

  # Run a one second loop that checks to see if there are messages to be sent
  # to chat. Wait one second after the request is made to avoid
  # rate throttling issues.
  setInterval(
    () ->
      # Check to see if there are messages to send to the chat room.
      request = pending_msg_posts.shift()
      if request?
        slack.api(
          'chat.postMessage',
          {
            text:   request.text
            channel: request.channel
            link_names: 1

          })
    ,THROTTLE_RATE_MS)


  robot.on "session:inbound_msg", (session, msg) ->
    console.log "Just received inbound message for #{session.session_key}:#{msg}"
    request =
      text:     "#{session.user.name}: #{msg}"
      channel:  "#" + session.session_key
    pending_msg_posts.push request


  robot.on "session:outbound_msg", (session, msg) ->
    console.log "Just received outbound message for #{session.session_key}:#{msg}"
    request =
      text:     "#{session.room}: #{msg}"
      channel:  "#" + session.session_key
    pending_msg_posts.push request

  robot.on "session:start", (session) =>
    console.log "New session just started #{session.session_key}:#{session.session_id}"
    slack.api(
      'channels.create',
      {
        name: session.session_key
      })

    request =
      text:     "#{session.user.name} just started a conversation in #{session.room}, available at channel ##{session.session_key}"
      channel:  announce_channel
    pending_msg_posts.push request

    request =
      text:     "New session started"
      channel:  "#" + session.session_key
    pending_msg_posts.push request


  robot.on "session:end", (session) ->
    console.log "Session just started #{session.session_key}:#{session.session_id}"
    request =
      text:     "Session ended"
      channel:  "#" + session.session_key
    pending_msg_posts.push request
