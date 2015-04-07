// Use this middleware to require that a user is logged in
module.exports = function(req, res, next) {
  console.log("Checking for logged in user");
  if (Parse.User.current()) {
    next();
  } else {
    res.send("You need to be logged in to see this page.");
  }
}
