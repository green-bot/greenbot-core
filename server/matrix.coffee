Sdk = require("matrix-js-sdk")

myUserId = process.env.MATRIX_USER_ID
myAccessToken = process.env.MATRIX_ACCESS_TOKEN

matrixClient = Sdk.createClient
  baseUrl: "http://matrix.org",
  accessToken: myAccessToken,
  userId: myUserId


matrixClient.on "RoomMember.membership", (event, member) ->
  if (member.membership is "invite" and member.userId is myUserId)
    matrixClient.joinRoom(member.roomId).done () ->
      console.log("Auto-joined %s", member.roomId)

matrixClient.on "Room.timeline", (event, room, toStartOfTimeline) ->
  if toStartOfTimeline
    return
  if event.getType() isnt "m.room.message"
    return
  console.log "(#{room.name}) #{event.getSender()}::#{event.getContent().body}"

 matrixClient.startClient()
