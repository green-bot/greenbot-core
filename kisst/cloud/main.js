require('cloud/app.js');

Parse.Cloud.afterSave("Room", function(request) {
  console.log("Running after room filter.");

  // Kick off the allocation process in the background.
  // OK, buy it, then send a text out to the new owner.
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
      console.log("Request kicked off!!!!");
    },
    error: function(httpResponse) {
      console.error('After save request failed with response code ' + httpResponse.status);
      console.error('Server returned text ' + httpResponse.text);
    }
  });
});

Parse.Cloud.job("allocateRoom", function(request, status) {
  room_id = request.params.room_id;
  console.log("Running the room with " + room_id);

  var Room = Parse.Object.extend("Room");
  var query = new Parse.Query(Room);
  query.get(room_id, {
    success: function(room) {
      console.log("Fetched room");
      if(room.get("allocated") == false) {
        // Allocate the room and send the information.
        console.log("Allocating room");
        Parse.Config.get().then(function(config) {
          console.log("Making request to Nexmo for numbers");
          Parse.Cloud.httpRequest({
            method: 'GET',
            url: 'https://rest.nexmo.com/number/search',
            params: {
              country: "US",
              api_key: config.get("default_nexmo_key"),
              api_secret: config.get("default_nexmo_secret"),
              features: "SMS,VOICE"
            },
            success: function(httpResponse) {
              json_result = JSON.parse(httpResponse.text);
              console.log("Successful request for numbers");
              console.log(httpResponse.text);
              console.log("Purchasing number " + json_result.numbers[0].msisdn);
              
              // OK, buy it, then send a text out to the new owner.
              Parse.Cloud.httpRequest({
                method: 'POST',
                url: 'https://rest.nexmo.com/number/buy',
                params: {
                  country: "US",
                  api_key: config.get("default_nexmo_key"),
                  api_secret: config.get("default_nexmo_secret"),
                  msisdn: json_result.numbers[0].msisdn
                },
                success: function(httpResponse) {
                  console.log("Successfully purchased number" + json_result.numbers[0].msisdn);
                  room.set("name", json_result.numbers[0].msisdn);
                  room.set("allocated", true);
                  room.save();

                  var Server = Parse.Object.extend("Server");
                  var serverQuery = new Parse.Query(Server);
                  serverQuery.first().then(function(server) {
                    Parse.Cloud.httpRequest({
                      method: 'POST',
                      url: 'https://rest.nexmo.com/number/update',
                      params: {
                        country: "US",
                        msisdn: room.get("name"),
                        moHttpUrl: server.get("callback_url"),
                        api_key: config.get("default_nexmo_key"),
                        api_secret: config.get("default_nexmo_secret")
                      },
                      success: function(httpResponse) {
                        console.log("Successfully updated number" + room.get("name"));
                        room.set("server", server);
                        room.save();
                        // OK, buy it, then send a text out to the new owner.
                        Parse.Cloud.httpRequest({
                          method: 'GET',
                          url: 'https://rest.nexmo.com/sms/json',
                          params: {
                            api_key: config.get("default_nexmo_key"),
                            api_secret: config.get("default_nexmo_secret"),
                            from: room.get("name"),
                            to: room.get("owners")[0],
                            text: "Hi! I'm your new bot. Configuring me is easy. But first, send me a single message telling me your name."
                          },
                          success: function(httpResponse) {
                            console.log("OK, bot created. Woooooo!!!!");
                            status.success();
                          },
                          error: function(httpResponse) {
                            console.error('Send hello message request failed with response code ' + httpResponse.status);
                            console.error('Server returned text ' + httpResponse.text);
                          }
                        });
                      },
                      error: function(error) {
                        console.error('Send hello message request failed with response code ' + httpResponse.status);
                        status.error("Send hello message request failed.");
                      }
                    });
                  });
                },
                error: function(httpResponse) {
                  console.error('Purchase number request failed with response code ' + httpResponse.status);
                  console.error('Server returned text ' + httpResponse.text);
                  status.error("Purchase number request failed.");
                }
              });
            },
            error: function(httpResponse) {
              console.error('Retrieve numbers failed with response code ' + httpResponse.status);
              console.error('Server returned text ' + httpResponse.text);
              status.error("Retrieve numbers failed.");
            }
          });
        }, function(error) {
          console.log("Failed to fetch config. Using Cached Config.");
          status.error("Failed to fetch config.");
        });
      } else {
        console.log("It was allocated???");
        status.success();
      }
    },
    error: function(object, error) {
      console.log('Query room request failed ' + error);
      status.error("Query room request failed.");
    }
  });
  console.log("Exiting and waiting for callbacks");
});
