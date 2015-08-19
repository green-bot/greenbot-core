/*global Parse */

var _ = require('underscore')

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
exports.add_number = function (req, res) {
  var currentUser = Parse.User.current()
  var Integrations = Parse.Object.extend('Integrations')
  var query = new Parse.Query(Integrations)
  var auth
  query.equalTo('type', 'network')
  query.equalTo('user', currentUser)
  query.find().then(
    function (integrations) {
      // If there aren't any integrations, assume we are on the home
      // network, TSG
      var activeNetwork
      var integration
      console.log(integrations)
      if (integrations.length === 0) {
        activeNetwork = 'tsg'
      } else {
        integration = integrations.shift()
        console.log(integration)
        activeNetwork = integration.get('provider')
        auth = integration.get('auth')
        console.log(activeNetwork)
        console.log(auth)
      }
      // Now get some numbers to add.
      switch (activeNetwork) {
        case 'nexmo':
          return Parse.Cloud.httpRequest({url: 'https://rest.nexmo.com/number/search',
            params: {
              api_key: auth.credentials.api_key,
              api_secret: auth.credentials.api_secret,
              country: 'US'
            }
          })
        default:
          console.log('No active network. Bad. Bad. Bad.')
          break
      }
    }).then(function (httpResponse) {
      console.log(httpResponse.text)
    }, function (httpResponse) {
      console.error('Request failed with response code ' + httpResponse.status)
    })
}
