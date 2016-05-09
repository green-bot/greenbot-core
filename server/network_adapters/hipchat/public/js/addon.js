/* add-on script */

$(document).ready(function () {

  // The following functions use the HipChat Javascript API
  // https://developer.atlassian.com/hipchat/guide/javascript-api

  //To send a message to the HipChat room, you need to send a request to the add-on back-end
  function sayHello(callback) {
    //Ask HipChat for a JWT token
    HipChat.auth.withToken(function (err, token) {
      if (!err) {
        //Then, make an AJAX call to the add-on backend, including the JWT token
        //Server-side, the JWT token is validated using the middleware function addon.authenticate()
        $.ajax(
            {
              type: 'POST',
              url: '/send_notification',
              headers: {'Authorization': 'JWT ' + token},
              dataType: 'json',
              data: {messageTitle: 'Hello World!'},
              success: function () {
                callback(false);
              },
              error: function () {
                callback(true);
              }
            });
      }
    });
  }

  /* Functions used by sidebar.hbs */

  $('#say_hello').on('click', function () {
    sayHello(function (error) {
      if (error)
        console.log('Could not send message');
    });
  });

  $('#room').on('click', function () {
    HipChat.room.getRoomDetails(function (err, data) {
      if (!err) {
        $('#details-title').html('Room details');
        $('#details').html(JSON.stringify(data, null, 2));
      }
    });
  });

  $('#participants').on('click', function () {

    HipChat.room.getParticipants(function (err, data) {
      if (!err) {
        $('#details-title').html('Room participants');
        $('#details').html(JSON.stringify(data, null, 2));
      }
    });
  });

  $('#user').on('click', function () {

    HipChat.user.getCurrentUser(function (err, data) {
      if (!err) {
        $('#details-title').html('User details');
        $('#details').html(JSON.stringify(data, null, 2));
      }
    });
  });


  /* Functions used by dialog.hbs */

  //Register a listener for the dialog button - primary action "say Hello"
  HipChat.register({
    "dialog-button-click": function (event, closeDialog) {
      if (event.action === "sample.dialog.action") {
        //If the user clicked on the primary dialog action declared in the atlassian-connect.json descriptor:
        sayHello(function (error) {
          if (!error)
            closeDialog(true);
          else
            console.log('Could not send message');
        });
      } else {
        //Otherwise, close the dialog
        closeDialog(true);
      }
    }
  });

});