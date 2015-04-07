// Copyright (c) 2015, GreenBot
// These two lines are required to initialize Express in Cloud Code.
var express = require('express');
var parseExpressHttpsRedirect = require('parse-express-https-redirect');
var parseExpressCookieSession = require('parse-express-cookie-session');
var Stripe = require('stripe');

//routes
var conversation 	= require('./routes/conversation');
var connection 		= require('./routes/connection');
var media 		= require('./routes/media');
var config 	= require('./routes/config');
var dashboard 	= require('./routes/dashboard');
var snippets 	= require('./routes/docs');
var pjson = require('./package.json');		//read the package.json file to get the current version

var bc 			= require('./bootcards-functions');		//bootcards functions
var http 	= require('http');
var path 	= require('path');			//work with paths
var pjax 	= require('express-pjax');	//express pjax (partial reloads)
var hbs 	= require('express-hbs');	//express handlebars
var moment	= require('moment');		//moment date formatting lib


var app = express();


app.engine( 'html', hbs.express3({
	partialsDir : __dirname + '/views'
}));
app.set('view engine', 'html');
app.set('views', 'cloud/views');  // Specify the folder to find templates
app.use(express.cookieParser('SECRET_SIGNING_KEY'));
app.use(express.bodyParser());    // Middleware for reading request body
app.use(express.methodOverride());
app.use(parseExpressHttpsRedirect());  // Require user to be on HTTPS.
app.use(parseExpressCookieSession({
  fetchUser: true,
  key: 'image.sess',
  cookie: {
    maxAge: 3600000 * 24 * 30
  }
}));
//pjax middleware for partials
app.use(pjax());

//send session info to handlebars, check OS used to send correct stylesheet
app.use(function(req, res, next){

	var ua = req.headers['user-agent'];
	req.session.isAndroid = (ua.match(/Android/i) != null);
	req.session.isIos = (ua.match(/iPhone|iPad|iPod/i) != null);
	req.session.isDev = (process.env.NODE_ENV !='production');
	req.session.test = (process.env.NODE_ENV);

	res.locals.session = req.session;

	next();
});

app.use(express.favicon("public/favicon.ico"));
app.use(express.urlencoded());
app.use(express.methodOverride());
app.use(app.router);

var fiveDays = 5*86400000;

//register a helper for date formatting using handlebars
hbs.registerHelper("formatDate", function(datetime, format) {
  if (moment) {
    f = "ddd DD MMM YYYY HH:mm"
    return moment(datetime).format(f);
  }
  else {
    return datetime;
  }
});

//helper to get the icon for a item type
hbs.registerHelper("getIconForType", function(type) {
	return bc.getIconForType(type);
});

//helper to get the number of data elements
hbs.registerHelper('count', function(type) {
	switch (type) {
		case 'conversations':
			return collected_data.length;
		case 'contacts':
			return contacts.length;
		case 'connections':
			return connections.length;
		case 'data':
			return 4;
	}

	return 0;
});

//helper to get the stylesheet for the current user agent
hbs.registerHelper("getCSSforOS", function(session) {
	var bootCardsBase = "/bower_components/bootcards/";
	if (session.isAndroid) {
		return '<link href="' + bootCardsBase + 'dist/css/bootcards-android.min.css" rel="stylesheet" type="text/css" />';
	} else if (session.isIos) {
		return '<link href="' + bootCardsBase + 'dist/css/bootcards-ios.min.css" rel="stylesheet" type="text/css" />';
	} else {
		return '<link href="' + bootCardsBase + 'dist/css/bootcards-desktop.min.css" rel="stylesheet" type="text/css" />';
	}
});

hbs.registerHelper("isMobile", function(session) {
	return '<script>var isDesktop = ' + (!session.isIos && !session.isAndroid) + ';</script>';
});

//helper to get the app version
hbs.registerHelper("getAppVersion", function() {
	return pjson.version;
});

//read sample data
collected_data = [];
connections = [];
contacts = [];

sampleData.read();

//setup menu
menu = [
	{ id : 'dashboard', name : "Home", title : 'Home', icon : "fa-home", active : false, url : '/'},
	{ id : 'conversations', name : "Conversations", title : 'Conversations', icon : "fa-building-o", active : false, url : '/conversations'},
	{ id : 'config', name : "Settings", title : 'Settings', icon : "fa-gears", active : false, url : '/config'},
	{ id : 'help', name : "Help", title : 'Help', icon : "fa-question-circle", active : false, url : 'http://kisst.zendesk.com'},
	{ id : 'share', name : "Share", title : 'Share', icon : "fa-share", active : false, url : 'http://kisst.zendesk.com'},
	{ id : 'logout', name : "Logout", title : 'Logout', icon : "fa-sign-out", active : false, url : '/logout'}
];

// development only
if ('development' == app.get('env')) {
  app.use(express.errorHandler());
	console.log("In development mode");
}

//routes
app.get('/', dashboard.list);
app.get('/dashboard', dashboard.list);
app.get('/conversations', conversation.list);
app.get('/conversations/:id', conversation.read);
app.get('/config', config.list);
app.get('/config/edit', config.edit);



// Portal routing section
app.use('/portal', require('cloud/portal'));


app.post('/billing', function(req, res) {
  req_data = req.body
  console.log("Entered billing function -> " + req_data.type);
  console.log(req_data);
  Stripe.initialize('sk_live_CDYuW7Nsp4dtyKXT7ifjZ47q');

  if(req_data.type == "customer.subscription.created"){
    // First things first, get the customer record.
    customer = Stripe.Customers.retrieve(req_data.data.object.customer,
      {
        success: function(customer) {
          // OK, got the customer and the subscription.
          console.log("customer.subscription.created");
          console.log(JSON.stringify(customer, null, 4));
          var Room = Parse.Object.extend("Room");
          var room = new Room();
          var notification_emails = [customer.email]
          room.set("notification_emails", notification_emails);
          var owners = [customer.metadata.owner_cell]
          room.set("owners", owners);
          room.set("owner_cmd", "ruby owner_settings.rb");
          room.set("default_cmd", "ruby information.rb");
          room.set("default_path", "scripts");
          room.set("stripe_sub_id", req_data.data.object.id);
          room.set("stripe_cust_id", customer.id);
          room.set("settings",
          {
           "AWAY": "false",
           "HOURS": "8am to 4pm",
           "PROMPT_1": "Thank you for texting us! We love having you as a customer",
           "PROMPT_2": "Heres a link to todays specials : http://bit.ly/15GmEEr ",
           "SIGNATURE": "Thank you! Visit us on the web at www.google.com",
           "SPECIALS": "Our prime rib dinner on Thursdays is to die for. $13.99 includes salad, and three sides.",
           "ADDRESS": "3010 Main St, Barnstable, MA 02630"
          });
          room.set("allocated", false);
          room.save(null, {
            success: function(room) {
              console.log(JSON.stringify(room, null, 4));
              res.send("Success");
            },
            error: function(room, error) {
              console.log("Room error:");
              console.log(JSON.stringify(error, null, 4));
              res.send("Subscription error.");
            }
          });
        },
        error: function(customer) {
          console.log(JSON.stringify(customer, null, 4));
          res.error("Uh oh, something went wrong");
        }
      });
  } else {
    res.send("Unhandled");
  }
})

app.post('/new_order', function(req, res) {
  console.log("Entered new_order function ");
  console.log(req.body);
  token_info = req.body;

  Stripe.initialize('sk_live_CDYuW7Nsp4dtyKXT7ifjZ47q');
  Stripe.Customers.create({
    source: token_info.id,
    plan: token_info.plan_id,
    email: token_info.email,
    metadata: {
      owner_cell: token_info.owner_cell
    }
  },{
    success: function(httpResponse) {
      console.log("Subscription successfully performed");
      res.send("Success");
    },
    error: function(httpResponse) {
      console.log(JSON.stringify(httpResponse.body, null, 4));
      res.error("Uh oh, something went wrong");
    }
  });
})

app.post('/server/alive', function(req, res) {
  console.log("Running server alive");
  console.log(req.body);

  var server_info = req.body
  // See if the referenced server exists in our database.
  // If it doesn't, then add it.
  // If it does, update it.

  var Server = Parse.Object.extend("Server");
  var query = new Parse.Query(Server);
  query.equalTo("server_id", server_info.server_id);
  console.log("Querying for " + server_info.server_id);
  query.find({
    success: function(results) {
      if (results.length == 0) {
        // Nothing of the sort exists. Make one.
        console.log("Did not find a server with the ID " + server_info.server_id);
        var server = new Server();
        server.set("server_id", server_info.server_id);
        server.set("hostname", server_info.hostname);
        server.set("last_alive_time", new Date().getTime());
        server.set("state", "alive");
        server.set("networks", server_info.networks);
        server.save(server_info
            , {
            success: function(Server) {
              // The object was saved successfully.
              console.log("New server has come online: " + server.hostname + "with identifier" + server.server_id);
            },
            error: function(Server, error) {
              // The save failed.
              // error is a Parse.Error with an error code and message.
              console.error("Unknown error occured when creating server record.");
            }
        });
      } else {
        // Successfully retrieved the object.
        var server = results[0];
        server.set("last_alive_time", new Date().getTime());
        server.set("state", "alive");
        server.set("networks", server_info.networks);
        server.save();
        console.log("Server " + JSON.stringify(server,null,4) + " updated.");
      }
      res.send("Success");
    },
    error: function(error) {
      console.log("Query for server failed with error.");
    }
  });
})

app.post('/server/offline', function(req, res) {
  console.log("Server offline!");
  var server_info = req.body
  var Server = Parse.Object.extend("Server");
  var query = new Parse.Query(Server);
  query.equalTo("server_id", server_info.server_id);
  console.log("Querying for " + server_info.server_id);
  query.find({
    success: function(results) {
      if (results.length == 0) {
        // Nothing of the sort exists. Make one.
        console.log("Did not find a server with the ID " + server_info.server_id);
      } else {
        // Successfully retrieved the object.
        var server = results[0];
        server.set("state", "offline");
        server.save();
        console.log("Server " + JSON.stringify(server,null,4) + " is now offline.");
      }
      res.send("Success");
    },
    error: function(error) {
      console.log("Query for server failed with error.");
      res.send("Query for server failed with error" + JSON.stringify(error, null, 4));
    }
  });
})

app.post('/server/crashed', function(req, res) {
  console.log("Server crashed!");
  var server_info = req.body
  var Server = Parse.Object.extend("Server");
  var query = new Parse.Query(Server);
  query.equalTo("server_id", server_info.server_id);
  console.log("Querying for " + server_info.server_id);
  query.find({
    success: function(results) {
      if (results.length == 0) {
        // Nothing of the sort exists. Make one.
        console.log("Did not find a server with the ID " + server_info.server_id);
      } else {
        // Successfully retrieved the object.
        var server = results[0];
        server.set("state", "crashed");
        server.save();
        console.log("Server " + JSON.stringify(server,null,4) + " updated.");
      }
      res.send("Success");
    },
    error: function(error) {
      console.log("Query for server failed with error.");
      res.send("Query for server failed with error" + JSON.stringify(error, null, 4));
    }
  });
})

app.put('/room/allocate', function(req, res) {
  console.log(req.body);
  res.send("Success");
})

app.put('/room/return', function(req, res) {
  console.log(req.body);
  res.send("Success");
})

// Attach the Express app to Cloud Code.
app.listen();
