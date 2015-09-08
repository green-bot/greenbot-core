// Copyright (c) 2015, GreenBot
// These two lines are required to initialize Express in Cloud Code.
/*global Parse*/
var express = require('express')
var parseExpressHttpsRedirect = require('parse-express-https-redirect')
var parseExpressCookieSession = require('parse-express-cookie-session')
var Stripe = require('stripe')

var conversation = require('cloud/routes/conversation')
var config = require('cloud/routes/config')
var network = require('cloud/routes/networks')
var pjax = require('cloud/express-pjax')
var app = express()

app.set('view engine', 'jade')
app.set('views', 'cloud/views') // Specify the folder to find templates
app.use(express.cookieParser('SECRET_SIGNING_KEY'))
app.use(express.bodyParser()) // Middleware for reading request body
app.use(express.methodOverride())
app.use(parseExpressHttpsRedirect()) // Require user to be on HTTPS.
app.use(parseExpressCookieSession({
  fetchUser: true,
  key: 'image.sess',
  cookie: {
    maxAge: 3600000 * 24 * 30
  }
}))
app.use(function (req, res, next) {
  res.locals.roomName = req.cookies.roomName
  res.locals.selectedKeyword = req.cookies.selectedKeyword
  next()
})

app.use('/portal', function (req, res, next) {
  console.log('Checking for logged in user')
  if (Parse.User.current()) {
    next()
  } else {
    res.render('login')
  }
})

app.use(pjax())
app.use(express.urlencoded())
app.use(express.methodOverride())
app.use(app.router)

app.locals.menu = [{
  id: 'dashboard',
  name: 'Home',
  title: 'Home',
  icon: 'fa-home',
  active: false,
  url: '/'
}, {
  id: 'conversations',
  name: 'Conversations',
  title: 'Conversations',
  icon: 'fa-building-o',
  active: false,
  url: '/conversations'
}, {
  id: 'config',
  name: 'Settings',
  title: 'Settings',
  icon: 'fa-gears',
  active: false,
  url: '/config'
}, {
  id: 'help',
  name: 'Help',
  title: 'Help',
  icon: 'fa-question-circle',
  active: false,
  url: 'http://kisst.zendesk.com'
}, {
  id: 'share',
  name: 'Share',
  title: 'Share',
  icon: 'fa-share',
  active: false,
  url: 'http://kisst.zendesk.com'
}, {
  id: 'logout',
  name: 'Logout',
  title: 'Logout',
  icon: 'fa-sign-out',
  active: false,
  url: '/logout'
}]

app.get('/portal', function (req, res) {
  var cookies = req.cookies
  res.render('dashboard', {
    menus: app.locals.menu,
    current_room: cookies.roomName,
    current_keyword: cookies.selectedKeyword
  })
})

// Making a 'login' endpoint is SOOOOOOOO easy.
app.post('/login', function (req, res) {
  var username = req.body.username.trim()
    .toLowerCase()
  var password = req.body.password.trim()
  console.log('Logging in ' + username)
  Parse.User.logIn(username, password)
    .then(function (user) {
      // Login succeeded, redirect to homepage.
      // parseExpressCookieSession will automatically set cookie.
      console.log('Fetching room for the first time')
      var Rooms = Parse.Object.extend('Rooms')
      var query = new Parse.Query(Rooms)
      query.equalTo('user', user)
      query.find({
        success: function (results) {
          var selectedRoom = results[0]
          var keywords = []
            // Do something with the returned Parse.Object values
          for (var i = 0; i < results.length; i++) {
            var object = results[i]
            if (object.get('default')) {
              selectedRoom = object
              keywords.push({
                keyword: 'default',
                name: object.get('name'),
                id: object.id
              })
            } else {
              keywords.push({
                keyword: object.get('keyword') || 'default',
                name: object.get('name'),
                id: object.id
              })
            }
          }
          var selectedKeyword = selectedRoom.get('keyword') || 'default'
          res.cookie('roomId', selectedRoom.id)
          res.cookie('roomName', selectedRoom.get('name'))
          res.cookie('selectedKeyword', selectedKeyword)
          res.cookie('keywords', keywords)
          res.redirect('/portal')
        },
        error: function (error) {
          console.log('Failed to get room.')
          console.log(error)
        }
      })
    }, function (error) {
      console.log('Failed to get room.')
      console.log(error)
      res.redirect('/portal')
    })
})
app.get('/logout', function (req, res) {
  Parse.User.logOut()
  console.log('Logged user out. Redirecting.')
  res.redirect('/portal')
})
app.get('/portal/config/owners', config.owners)
app.get('/portal/config/owner_delete', config.owner_delete)

app.post('/portal/config/owner_add', config.owner_add)
app.get('/portal/config/notification_emails', config.notification_emails)
app.get('/portal/config/notification_email_delete', config.notification_email_delete)
app.post('/portal/config/notification_email_add', config.notification_email_add)
app.post('/portal/config/notification_creds_update', config.notification_creds_update)

app.get('/portal/config/type', config.type)
app.get('/portal/conversations', conversation.list)
app.get('/portal/conversations/download', conversation.download_csv)
app.get('/portal/conversations/:id', conversation.read)

app.get('/portal/config/info', config.info)
app.get('/portal/config', config.list)
app.get('/portal/config/edit', config.edit)
app.post('/portal/config/save', config.save)
app.post('/reset_request', config.reset_request)
app.get('/portal/settings', config.settings)
app.get('/portal/config/rooms', config.rooms)
app.get('/portal/config/change_room', config.change_room)
app.get('/portal/config/type_change/:id', config.type_change)
app.get('/portal/config/networks', network.networks)
app.post('/portal/config/network_update', network.network_update)
app.get('/portal/config/add_number', network.add_number)
app.get('/portal/config/nexmo', function (req, res) {
  res.render('nexmo')
})
app.get('/reset_page', function (req, res) {
  res.render('reset_page')
})
app.get('/register', function (req, res) {
  res.render('register')
})
app.post('/register_request', function (req, res) {
  console.log(req.body)
  var email = req.body['email']
  var id = req.body['token']
  var password = req.body['password']
  var Room = Parse.Object.extend('Room')
  var query = new Parse.Query(Room)
  query.get(id)
    .then(function (room) {
      var user = new Parse.User()
      user.set('username', email)
      user.set('password', password)
      user.set('room', room)
      user.signUp(null, {
        success: function (user) {
          // Hooray! Let them use the app now.
          res.redirect('/portal')
        },
        error: function (user, error) {
          // Show the error message somewhere and let the user try again.
          console.log('Failed to signup user')
          console.log(error)
          res.redirect('/register')
        }
      })
    }, function (error) {
      console.log('Failed to find room with that token')
      console.log(error)
      res.redirect('/register')
    })
})

app.post('/new_order', function (req, res) {
  console.log('Entered new_order function ')
  console.log(req.body)
  var token_info = req.body

  Stripe.initialize('sk_live_CDYuW7Nsp4dtyKXT7ifjZ47q')
  Stripe.Customers.create({
    source: token_info.id,
    plan: token_info.plan_id,
    email: token_info.email,
    metadata: {
      owner_cell: token_info.owner_cell
    }
  }, {
    success: function (httpResponse) {
      console.log('Subscription successfully performed')
      res.send('Success')
    },
    error: function (httpResponse) {
      console.log(JSON.stringify(httpResponse.body, null, 4))
      res.send('Uh oh, something went wrong')
    }
  })
})

app.post('/billing', function (req, res) {
  var req_data = req.body
  console.log('Entered billing function -> ' + req_data.type)
  console.log(req_data)
  Stripe.initialize('sk_live_CDYuW7Nsp4dtyKXT7ifjZ47q')

  if (req_data.type === 'customer.subscription.created') {
    // First things first, get the customer record.
    Stripe.Customers.retrieve(req_data.data.object.customer, {
      success: function (customer) {
        // OK, got the customer and the subscription.
        console.log('customer.subscription.created')
        var Room = Parse.Object.extend('Room')
        var room = new Room()
        var notification_emails = [customer.email]
        room.set('notification_emails', notification_emails)
        var owners = [customer.metadata.owner_cell]
        room.set('owners', owners)
        room.set('owner_cmd', 'ruby owner_settings.rb')
        room.set('desc', customer.email)
        room.set('default_cmd', 'ruby default.rb')
        room.set('default_path', 'scripts')
        room.set('stripe_sub_id', req_data.data.object.id)
        room.set('stripe_cust_id', customer.id)
        room.set('settings', {})
        room.set('test_mode', false)
        room.set('allocated', false)
        room.set('mail_user', 'no-reply@green-bot.com')
        room.set('mail_pass', 'gr33nb0t')
        room.set('qty', 100)
        room.set('reseller', '74906')
        room.save(null, {
          success: function (room) {
            // Created room. Now create user
            console.log('Created room successfully')
            var user = new Parse.User()
            user.set('username', customer.email)
            user.set('room', room)
            user.signUp(null, {
              success: function (user) {
                // Hooray! Let them use the app now.
                console.log('User signed up successfully')
                res.send('User successfully signed up.')
              },
              error: function (user, error) {
                // Show the error message somewhere and let the user try again.
                res.send('Create user error : ' + error.code + ' ' + error.message)
              }
            })

          },
          error: function (room, error) {
            console.log('Room error:')
            console.log(JSON.stringify(error, null, 4))
            res.send('Create room error.')
          }
        })
      },
      error: function (customer) {
        res.send('Could not fetch customer from Stripe.')
      }
    })
  } else {
    res.send('Unhandled')
  }
})
app.post('/server/alive', function (req, res) {
  console.log('Running server alive')
  console.log(req.body)

  var server_info = req.body
    // See if the referenced server exists in our database.
    // If it doesn't, then add it.
    // If it does, update it.

  var Server = Parse.Object.extend('Server')
  var query = new Parse.Query(Server)
  query.equalTo('server_id', server_info.server_id)
  console.log('Querying for ' + server_info.server_id)
  query.find({
    success: function (results) {
      if (results.length === 0) {
        // Nothing of the sort exists. Make one.
        console.log('Did not find a server with the ID ' + server_info.server_id)
        var server = new Server()
        server.set('server_id', server_info.server_id)
        server.set('hostname', server_info.hostname)
        server.set('last_alive_time', new Date()
          .getTime())
        server.set('state', 'alive')
        server.set('networks', server_info.networks)
        server.save(server_info, {
          success: function (Server) {
            // The object was saved successfully.
            console.log('New server has come online: ' + server.hostname + 'with identifier' + server.server_id)
          },
          error: function (Server, error) {
            // The save failed.
            // error is a Parse.Error with an error code and message.
            console.error('Unknown error occured when creating server record.')
          }
        })
      } else {
        // Successfully retrieved the object.
        server = results[0]
        server.set('last_alive_time', new Date()
          .getTime())
        server.set('state', 'alive')
        server.set('networks', server_info.networks)
        server.save()
        console.log('Server ' + JSON.stringify(server, null, 4) + ' updated.')
      }
      res.send('Success')
    },
    error: function (error) {
      console.log('Failed to get room.')
      console.log(error)
    }
  })
})

app.post('/server/offline', function (req, res) {
  console.log('Server offline!')
  var server_info = req.body
  var Server = Parse.Object.extend('Server')
  var query = new Parse.Query(Server)
  query.equalTo('server_id', server_info.server_id)
  console.log('Querying for ' + server_info.server_id)
  query.find({
    success: function (results) {
      if (results.length === 0) {
        // Nothing of the sort exists. Make one.
        console.log('Did not find a server with the ID ' + server_info.server_id)
      } else {
        // Successfully retrieved the object.
        var server = results[0]
        server.set('state', 'offline')
        server.save()
        console.log('Server ' + JSON.stringify(server, null, 4) + ' is now offline.')
      }
      res.send('Success')
    },
    error: function (error) {
      console.log('Query for server failed with error.')
      res.send('Query for server failed with error' + JSON.stringify(error, null, 4))
    }
  })
})

app.post('/server/crashed', function (req, res) {
  console.log('Server crashed!')
  var server_info = req.body
  var Server = Parse.Object.extend('Server')
  var query = new Parse.Query(Server)
  query.equalTo('server_id', server_info.server_id)
  console.log('Querying for ' + server_info.server_id)
  query.find({
    success: function (results) {
      if (results.length === 0) {
        // Nothing of the sort exists. Make one.
        console.log('Did not find a server with the ID ' + server_info.server_id)
      } else {
        // Successfully retrieved the object.
        var server = results[0]
        server.set('state', 'crashed')
        server.save()
        console.log('Server ' + JSON.stringify(server, null, 4) + ' updated.')
      }
      res.send('Success')
    },
    error: function (error) {
      console.log('Query for server failed with error.')
      res.send('Query for server failed with error' + JSON.stringify(error, null, 4))
    }
  })
})

app.put('/room/allocate', function (req, res) {
  console.log(req.body)
  res.send('Success')
})

app.put('/room/return', function (req, res) {
  console.log(req.body)
  res.send('Success')
})

// Attach the Express app to Cloud Code.
app.listen()
