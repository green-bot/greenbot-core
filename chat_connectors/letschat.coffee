Slack = require('slack-node')
Request = require('request')
_ = require('underscore')

module.exports = (robot) ->
  apiToken = "NTRlYzljMzQyZTBmYzFmMTVlNmEyMWVjOmQ1ZDQ1NTQ3MDYyZDNmZmQ3ZjhiMjczZmJjZDlmZTg5ZmE0Y2VlMTQ3YzNmYTk3ZQ=="
  chat_uri = "http://localhost:5000"
  chat_ownerid = null
  announce_slug = "chat_announce"
  THROTTLE_RATE_MS = 1500
  pending_msg_posts = []
  chat_sessions = []
  last_msg_checktime = {}


  # First, get our own ID so we know when it's us chatting
  Request
    .get(chat_uri + "/account",
      (error, response, body) =>
        account_info = JSON.parse(body)
        # Now, let's get the user for this account
        chat_ownerid = account_info.id
    )
    .auth(null, null, true, apiToken)



  create_room = (name) =>
    console.log "Creating room #{name}"
    options =
      name:         name
      slug:         name
    Request.post(chat_uri + "/rooms")
      .auth(null, null, true, apiToken)
      .form(options)
       .on("error", (error) =>
         console.log "Error : " + error
       )



  # Run a one second loop that checks to see if there are messages to be sent
  # to chat. Wait one second after the request is made to avoid
  # rate throttling issues.
  setInterval(
    () =>
      # Check to see if there are messages to send to the chat room.
      request = pending_msg_posts.shift()
      if request?
        options =
          text: request.text
          room: request.slug
        Request.post(chat_uri + "/rooms/#{request.slug}/messages")
          .auth(null, null, true, apiToken)
          .form(options)

      session_keys = _.keys(chat_sessions)
      date = new Date()
      time_now = date.toISOString()
      for key in session_keys
        options =
          uri: chat_uri + "/rooms/#{key}/messages"
          qs:
            from: last_msg_checktime[key]
        last_msg_checktime[key] = time_now
        Request
          .get(
            options,
            (error, response, body) =>
              messages = JSON.parse(body)
              for message in messages
                if message.owner isnt chat_ownerid
                  chat_sessions[key].handle_incoming_msg(message.text)
                  console.log("Handled #{message.text}")
          )
          .auth(null, null, true, apiToken)
      # Now, see if there are any messages we should be sending out.
    ,THROTTLE_RATE_MS)


  robot.on "session:inbound_msg", (session, msg) ->
    request =
      key:    session.session_key
      text:   "#{session.user.name}: #{msg}"
      slug:   session.session_key
    pending_msg_posts.push request


  robot.on "session:outbound_msg", (session, msg) ->
    request =
      key:   session.session_key
      text:  "#{session.room}: #{msg}"
      slug:  session.session_key
    pending_msg_posts.push request

  robot.on "session:start", (session) =>
    key = session.session_key
    create_room(announce_slug)
    create_room(key)
    chat_sessions[key] = session

    request =
      key:      session.session_key
      text:     "#{session.user.name} just started a conversation in #{session.room}, available at slug ##{session.session_key}"
      slug:     announce_slug
    pending_msg_posts.push request

    request =
      key:      session.session_key
      text:     "New session started"
      slug:     session.session_key
    pending_msg_posts.push request


  robot.on "session:end", (session) =>
    key = session.session_key
    delete chat_sessions[key]
    request =
      text:     "Session ended"
      slug:     key
    pending_msg_posts.push request
