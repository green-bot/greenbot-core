/*global Parse */

var _ = require('underscore')

exports.info = function (req, res) {
  var currentUser = Parse.User.current()
  var Rooms = Parse.Object.extend('Rooms')
  var query = new Parse.Query(Rooms)
  query.get(req.cookies.roomId, {
    success: function (room) {
      res.render('info', {
        username: currentUser.get('username'),
        email: currentUser.get('email'),
        name: room.get('name'),
        desc: room.get('desc'),
        keyword: room.get('keyword')
      })
    },
    error: function (error) {
      console.log('Failed to get room.')
      console.log(error)
    }
  })
}

exports.rooms = function (req, res) {
  var currentUser = Parse.User.current()
  var Rooms = Parse.Object.extend('Rooms')
  var query = new Parse.Query(Rooms)
  query.equalTo('user', currentUser)
  query.find({
    success: function (results) {
      var keywords = []
        // Do something with the returned Parse.Object values
      for (var i = 0; i < results.length; i++) {
        var object = results[i]
        if (object.get('default')) {
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
      res.render('rooms', {
        rooms: keywords
      })
    },
    error: function (error) {
      console.log('Failed to get rooms... hmmmm')
      console.log(error)
    }
  })
}

exports.change_room = function (req, res) {
  var Rooms = Parse.Object.extend('Rooms')
  var query = new Parse.Query(Rooms)
  query.get(req.query.id, {
    success: function (selectedRoom) {
      var selectedKeyword = selectedRoom.get('keyword') || 'default'
      res.cookie('roomId', selectedRoom.id)
      res.cookie('roomName', selectedRoom.get('name'))
      res.cookie('selectedKeyword', selectedKeyword)
      res.redirect('/portal')
    },
    error: function (error) {
      console.log('Failed to get room.')
      console.log(error)
    }
  })
}
exports.settings = function (req, res) {
  var cookies = req.cookies
  res.render('settings', {
    name: cookies.roomName,
    keywords: cookies.keywords,
    keyword: cookies.selectedKeyword
  })
}

exports.list = function (req, res) {
  var Rooms = Parse.Object.extend('Rooms')
  var query = new Parse.Query(Rooms)
  query.get(req.cookies.roomId, {
    success: function (room) {
      var room_settings = room.get('settings')
      var setting_keys = _.keys(room_settings)
      setting_keys.sort()
      var display_settings = []
      _.each(setting_keys, function (element, index, list) {
        var item = {
          key: element,
          v: room_settings[element]
        }
        display_settings.push(item)
      })
      res.renderPjax('config', {
        config: display_settings
      })
    },
    error: function (error) {
      console.log('Failed to get room.')
      console.log(error)
    }
  })
}

exports.edit = function (req, res) {
  var Rooms = Parse.Object.extend('Rooms')
  var query = new Parse.Query(Rooms)
  query.get(req.cookies.roomId, {
    success: function (room) {
      var room_settings = room.get('settings')
      var setting_keys = _.keys(room_settings)
        .sort()
      var display_settings = []
      _.each(setting_keys, function (element, index, list) {
        var item = {
          key: element,
          v: room_settings[element]
        }
        display_settings.push(item)
      })
      res.renderPjax('config_edit', {
        config: display_settings
      })
    },
    error: function (error) {
      console.log('Failed to get room.')
      console.log(error)
    }
  })
}

exports.save = function (req, res) {
  var Rooms = Parse.Object.extend('Rooms')
  var query = new Parse.Query(Rooms)
  query.get(req.cookies.roomId, {
    success: function (room) {
      var room_settings = room.get('settings')
        // This posted form has two kinds of data. Password
        // and room settings. Process the password first
      _.each(room_settings, function (value, key, list) {
        if (_.has(req.body, key)) {
          room_settings[key] = req.body[key]
        }
      })
      room.set('settings', room_settings)
      room.save()
        .then(function (room) {
          res.redirect('/portal/config')
        })
    },
    error: function (error) {
      console.log('Error thrown while saving settings.')
      console.log(error)
    }
  })
}

exports.reset_request = function (req, res) {
  var username = req.body.email.trim()
    .toLowerCase()
  console.log('Resetting the password for ' + username)
  Parse.User.requestPasswordReset(username, {
    success: function () {
      // Password reset request was sent successfully
      console.log('Found it.')
      res.redirect('/portal')
    },
    error: function (error) {
      console.log('I didnt find that user.')
      console.log(error)
        // Password reset request was sent successfully
      res.render('reset_page', {
        error: error.message
      })
    }
  })
}

exports.owners = function (req, res) {
  var Rooms = Parse.Object.extend('Rooms')
  var query = new Parse.Query(Rooms)
  query.get(req.cookies.roomId, {
    success: function (room) {
      var owners = room.get('owners')
      res.render('owners', {
        owners: owners
      })
    },
    error: function (error) {
      console.log('Failed to get owners.')
      console.log(error)
    }
  })
}

exports.owner_delete = function (req, res) {
  var Rooms = Parse.Object.extend('Rooms')
  var query = new Parse.Query(Rooms)
  query.get(req.cookies.roomId, {
    success: function (room) {
      var owners = room.get('owners')
      console.log('Owners has')
      console.log(owners)
      console.log('Removing')
      console.log(req.query.number)

      var new_owners = _.without(owners, req.query.number)
      console.log('Now has')
      console.log(new_owners)
      room.set('owners', new_owners)
      room.save({
        success: function () {
          res.render('owners', {
            owners: new_owners
          })
        },
        error: function () {
          console.log('Could not save room.')
          res.render('owners', {
            owners: owners
          })
        }
      })
    },
    error: function (error) {
      console.log('Failed to get owners.')
      console.log(error)
    }
  })
}
exports.owner_add = function (req, res) {
  var Rooms = Parse.Object.extend('Rooms')
  var query = new Parse.Query(Rooms)
  query.get(req.cookies.roomId, {
    success: function (room) {
      var owners = room.get('owners')
      var owner_number = req.body.new_owner.replace(/\D/g, '')
      owners.push(owner_number)
      room.set('owners', owners)
      room.save({
        success: function () {
          res.render('owners', {
            owners: owners
          })
        },
        error: function () {
          console.log('Could not save room.')
          res.render('owners', {
            owners: owners
          })
        }
      })
    },
    error: function (error) {
      console.log('Failed to get owners.')
      console.log(error)
    }
  })
}

exports.notification_emails = function (req, res) {
  var Rooms = Parse.Object.extend('Rooms')
  var query = new Parse.Query(Rooms)
  query.get(req.cookies.roomId, {
    success: function (room) {
      res.render('notification_emails', {
        notification_emails: room.get('notification_emails'),
        mail_user: room.get('mail_user'),
        mail_pass: room.get('mail_pass'),
        webhook: room.get('webhook_url')
      })
    },
    error: function (error) {
      console.log('Failed to get notification_emails.')
      console.log(error)
    }
  })
}
exports.notification_email_delete = function (req, res) {
  var Rooms = Parse.Object.extend('Rooms')
  var query = new Parse.Query(Rooms)
  query.get(req.cookies.roomId, {
    success: function (room) {
      var notification_emails = room.get('notification_emails')
      console.log('notification_emails has')
      console.log(notification_emails)
      console.log('Removing')
      console.log(req.query.email)

      var new_notification_emails = _.without(notification_emails, req.query.email)
      console.log('Now has')
      console.log(new_notification_emails)
      room.set('notification_emails', new_notification_emails)
      room.save({
        success: function () {
          res.redirect('/portal/config/notification_emails')
        },
        error: function () {
          console.log('Could not save room.')
          res.redirect('/portal/config/notification_emails')
        }
      })
    },
    error: function (error) {
      console.log('Failed to get notification_emails.')
      console.log(error)
    }
  })
}
exports.notification_email_add = function (req, res) {
  var Rooms = Parse.Object.extend('Rooms')
  var query = new Parse.Query(Rooms)
  query.get(req.cookies.roomId, {
    success: function (room) {
      var notification_emails = room.get('notification_emails')
      var notification_email = req.body.email
      notification_emails.push(notification_email)
      room.set('notification_emails', notification_emails)
      room.save({
        success: function () {
          res.redirect('/portal/config/notification_emails')
        },
        error: function () {
          console.log('Could not save room.')
          res.redirect('/portal/config/notification_emails')
        }
      })
    },
    error: function (error) {
      console.log('Failed to get notification_emails.')
      console.log(error)
    }
  })
}
exports.notification_creds_update = function (req, res) {
  var Rooms = Parse.Object.extend('Rooms')
  var query = new Parse.Query(Rooms)
  query.get(req.cookies.roomId, {
    success: function (room) {
      room.set('mail_user', req.body.mail_user)
      room.set('mail_pass', req.body.mail_pass)
      room.set('webhook_url', req.body.webhook)
      room.save({
        success: function () {
          console.log('Saved room successfully')
          res.redirect('/portal/settings')
        },
        error: function () {
          console.log('Could not save room.')
          res.redirect('/portal/config/notification_emails')
        }
      })
    },
    error: function (error) {
      console.log('Failed to get notification_emails.')
      console.log(error)
      res.redirect('/portal/config')
    }
  })
}

exports.type = function (req, res) {
  var Rooms = Parse.Object.extend('Rooms')
  var query = new Parse.Query(Rooms)
  var currentUser = Parse.User.current()
  var default_cmd
  var current_name
  query.get(req.cookies.roomId)
    .then(function (room) {
      default_cmd = room.get('default_cmd')
      var Script = Parse.Object.extend('Scripts')
      var global_query = new Parse.Query(Script)
      global_query.equalTo('global', true)
      var user_query = new Parse.Query(Script)
      user_query.equalTo('user', currentUser)
      var main_query = new Parse.Query.or(global_query, user_query)
      main_query.ascending('name')
      return main_query.find()
    })
    .then(function (elements) {
      var display_settings = []
      _.each(elements, function (element, index, list) {
        if (element.get('global') === true ||
            currentUser.id === element.get('user').id) {
          var item = {
            name: element.get('name'),
            cmd: element.get('default_cmd'),
            id: element.id,
            active: false,
            icon_class: element.get('icon_class'),
            desc: element.get('desc')
          }
          if (default_cmd === item.cmd) {
            item.active = true
            current_name = item.name
          }
          display_settings.push(item)
        }
      })
      res.render('types', {
        scripts: display_settings,
        default_cmd: default_cmd,
        current_name: current_name
      })
    })
}

exports.type_change = function (req, res) {
  var Rooms = Parse.Object.extend('Rooms')
  var query = new Parse.Query(Rooms)
  var room
  query.get(req.cookies.roomId)
    .then(function (foundRoom) {
      room = foundRoom
      var Script = Parse.Object.extend('Scripts')
      var query = new Parse.Query(Script)
      return query.get(req.params.id)
    })
    .then(function (script) {
      var default_cmd = script.get('default_cmd')
      var settings = script.get('default_settings')
      var owner_cmd = script.get('owner_cmd')
      var default_path = script.get('default_path')
      return room.save({
        default_cmd: default_cmd,
        settings: settings,
        owner_cmd: owner_cmd,
        default_path: default_path
      })
    })
    .then(function (room) {
      console.log('New room...')
      console.log(room)
      return res.redirect('/portal/settings/')
    }, function (error) {
      console.log('Fail.')
      console.log(error)
    })
}

exports.networks = function (req, res) {
  var currentUser = Parse.User.current()
  var Integrations = Parse.Object.extend('Integrations')
  var query = new Parse.Query(Integrations)
  var integrations
  var currentNetworkId
  query.equalTo('type', 'network')
  query.equalTo('user', currentUser)
  var network_info = []
  query.find()
    .then(
      function (results) {
        integrations = results
        var Networks = Parse.Object.extend('Networks')
        var query = new Parse.Query(Networks)
        return query.find()
      })
    .then(function (networks) {
      if (integrations.length === 1) {
        currentNetworkId = integrations[0].get('externalId')
      } else {
        var defaultNetwork = _.find(networks, function (network) {
          console.log(network.get('name'))
          return network.get('default') === true
        })
        currentNetworkId = defaultNetwork.id
      }
      _.each(networks, function (element, index, list) {
        var info = {
          name: element.get('name'),
          id: element.id,
          current: element.id === currentNetworkId
        }
        network_info.push(info)
      })
      res.render('networks', {
        networks: network_info
      })
    }, function (error) {
      console.log('Failed to fetch networks')
      console.log(error)
    })
}
exports.network_update = function (req, res) {
  var currentUser = Parse.User.current()
  var Integrations = Parse.Object.extend('Integrations')
  var query = new Parse.Query(Integrations)
  query.equalTo('type', 'network')
  query.equalTo('user', currentUser)
  query.find().then(
    function (integrations) {
      var promises = []
      _.each(integrations, function (integration) {
        promises.push(integration.destroy())
      })
      // Return a new promise that is resolved when all of the deletes are finished.
      return Parse.Promise.when(promises)
    }).then(function () {
      var Networks = Parse.Object.extend('Networks')
      var query = new Parse.Query(Networks)
      query.equalTo('name', req.body.network_name)
      return query.find()
    }).then(function (networks) {
      var existing_network = networks.shift()
      var Integrations = Parse.Object.extend('Integrations')
      var new_network = new Integrations()
      var Rooms = Parse.Object.extend('Rooms')
      var room = new Rooms()
      room.id = req.cookies.roomId
      new_network.set('room', room)
      new_network.set('user', currentUser)
      new_network.set('provider', req.body.network_name)
      new_network.set('type', 'network')
      var auth = {
        'type': 'REST',
        'credentials': {
          api_key: req.body.api_key,
          api_secret: req.body.api_secret
        }
      }
      new_network.set('auth', auth)
      new_network.set('externalId', existing_network.id)
      return new_network.save()
    }).then(function (network) {
      res.redirect('portal/settings')
    }, function (error) {
      console.log('Failed to fetch networks')
      console.log(error)
    })
}
