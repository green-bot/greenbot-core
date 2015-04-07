var requireUser = require('cloud/require-user');

module.exports = function() {
  var express = require('express');
  var app = express();

  // Creates a new image
  app.get('/dashboard', function(req, res) {
    var Room = Parse.Object.extend("Room");
    var queryObject = new Parse.Query(Room);

    console.log("Fetching dashboard");
    queryObject.find().then(function(rooms) {
      res.render('dashboard',
        {  title: 'Hey',
           rooms: rooms
        });
    });
  });

  return app;
}();
