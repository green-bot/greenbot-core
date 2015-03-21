require('cloud/app.js');

Parse.Cloud.afterSave("Room", function(request) {
  console.log("Running after room save filter.");

  if (request.object.get("allocated") == false) {
    // This room is not allocated. Let's allocate it
    // by kicking off the "allocate room" job
    Parse.Cloud.httpRequest({
      method: 'POST',
      url: 'https://api.parse.com/1/jobs/allocateRoom',
      body: {
        'room_id': request.object.id
      },
      headers: {
              'X-Parse-Application-Id': "y9Bb9ovtjpM4cCgIesS5o2XVINBjHZunRF1Q8AoI",
              'X-Parse-Master-Key': "RwIarCIom4SGBI6S3oXfKIydRdQ0vlti96enEigO",
              'Content-Type': "application/json"
          },
      success: function(httpResponse) {
        console.log("Allocte Request kicked off!!!!");
      },
      error: function(httpResponse) {
        console.error('After save request failed with response code ' + httpResponse.status);
        console.error('Server returned text ' + httpResponse.text);
      }
    });
  } else {
    console.log("Room is already allocated.");
  }
});


Parse.Cloud.job("allocateRoom", function(request, status) {
  room_id = request.params.room_id;
  console.log("Running the room with " + room_id);

  var Room = Parse.Object.extend("Room");
  var query = new Parse.Query(Room);
  var roomPromise = query.get(room_id);
  var configPromise = Parse.Config.get();

  var Did = Parse.Object.extend("dids");
  var query = new Parse.Query(Did);
  query.equalTo("allocated", false);
  var didPromise = query.first();

  Parse.Promise.when(roomPromise, configPromise, didPromise).done(function(room, config, did) {
    console.log("All objects fetched");
    if (room.get("allocated")) {
      status.success("Room already allocated.");
      return;
    }
    room.set("name", did.get("did"));
    room.set("allocated", true);
    var roomSavePromise = room.save();

    did.set("allocated", true);
    var didSavePromise = did.save();

    var helloPromise = Parse.Cloud.httpRequest({
        method: 'POST',
        url: 'http://sms.tsgglobal.com/jsonrpc',
        params: {
          key: config.get("default_tsg_key")
        },
        body: JSON.stringify({
          method: "sms.send",
          id: 0,
          params: [
            room.get("name"),
            room.get("owners")[0],
            config.get("new_bot_announce"),
            1
          ]}),
        json: true,
        success: function(httpResponse) {
          console.log("OK, bot created. Woooooo!!!!");
          console.log(httpResponse);
        },
        error: function(httpResponse) {
          console.error('Send hello message request failed with response code ' + httpResponse.status);
          console.error('Server returned text ' + httpResponse.text);
        }
    });

    Parse.Promise.when(roomSavePromise, didSavePromise, helloPromise).done(function(room, did, hello) {
        console.log("Finished allocating room");
        status.success();
    });
  });
  console.log("Exiting and waiting for callbacks.");
  });
