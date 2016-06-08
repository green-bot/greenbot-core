var MongoClient = require('mongodb').MongoClient

//the MongoDB connection
var connectionInstance;

if (!process.env.MONGO_URL) {
  throw new Error("process.env.MONGO_URL not defined") 
 }
 
 var CONNECTION_STRING = process.env.MONGO_URL

module.exports = function() {
  //if already we have a connection, don't connect to database again
  if (connectionInstance) {
    return Promise.resolve(connectionInstance);
  }

  return MongoClient.connect(CONNECTION_STRING, { server: {auto_reconnect: true}}).then(function(db){
    connectionInstance = db;
    return connectionInstance;
  }).catch(function(error){
    throw new Error(error);
  });
};

//db = undefined
//getDb = ->
  //Logger.info "Returning cached db connection" if db
  //return Promise.resolve(db) if db
  //MongoClient.connect(MONGO_URL)
  //.then (database) ->
    //Logger.info "Package connection to db established"
    //db = database

