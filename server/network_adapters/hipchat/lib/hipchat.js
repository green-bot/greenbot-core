var RSVP = require('rsvp');
var http = require('request');
var _ = require('lodash');

module.exports = function(addon) {

  function request(clientInfo, options){

    return new RSVP.Promise(function(resolve, reject){

      function makeRequest(clientInfo) {
        addon.getAccessToken(clientInfo).then(function(token){
          var hipchatBaseUrl = clientInfo.capabilitiesDoc.links.api;
          http({
            method: options.method || 'GET',
            url: hipchatBaseUrl + options.resource,
            qs: _.extend({auth_token: token.access_token}, options.qs),
            body: options.body,
            json: true
          }, function(err, resp, body){
            if (err) {
              reject(err);
              return;
            }
            resolve(resp);
          });
        });
      }

      if (!clientInfo) {
        reject(new Error('clientInfo not available'));
        return;
      }
      if (typeof clientInfo === 'object'){
        makeRequest(clientInfo);
      } else {
        addon.loadClientInfo(clientInfo).then(makeRequest);
      }

    });

  }

  function fail(response, reject) {
    var code = response.statusCode;
    var msg = 'Unexpected response: [' + code + '] ' + require('http').STATUS_CODES[code];
    var err = new Error(msg);
    err.response = response;
    reject(err);
  }

  return {

    sendMessage: function (clientInfo, roomId, msg, opts, card){
      opts = (opts && opts.options) || {};
      return request(clientInfo, {
        method: 'POST',
        resource: '/room/' + roomId + '/notification',
        body: {
          message: msg,
          message_format: (opts.format ? opts.format : 'html'),
          color: (opts.color ? opts.color : 'yellow'),
          notify: (opts.notify ? opts.notify : false),
          card: card
        }
      });
    },

    getRoomWebhooks: function (clientInfo, roomId){
      return new RSVP.Promise(function (resolve, reject) {
        var all = [];
        function getPage(offset) {
          request(clientInfo, {
            method: 'GET',
            resource: '/room/' + roomId + '/webhook',
            qs: {'start-index': offset}
          }).then(function (response) {
            if (response.statusCode === 200) {
              var webhooks = response.body;
              if (webhooks.items.length > 0) {
                all = all.concat(webhooks.items);
                getPage(all.length);
              } else {
                resolve(all);
              }
            } else {
              fail(response, reject);
            }
          }, reject);
        }
        getPage(0);
      });
    },

    addRoomWebhook: function (clientInfo, roomId, webhook) {
      return request(clientInfo, {
        method: 'POST',
        resource: '/room/' + roomId + '/webhook',
        body: webhook
      });
    },

    removeRoomWebhook: function (clientInfo, roomId, webhookId) {
      return request(clientInfo, {
        method: 'DELETE',
        resource: '/room/' + roomId + '/webhook/' + webhookId
      });
    },

    // You can also access this information through the client-side api:
    // https://developer.atlassian.com/hipchat/guide/hipchat-ui-extensions/views/javascript-api#JavascriptAPI-GettingcontextualinformationfromtheHipChatClient
    getRoom: function (clientInfo, roomId) {
      return request(clientInfo, {
        method: 'GET',
        resource: '/room/' + roomId + '?expand=participants'
      });
    },

    // Only usable if you have the view_group scope. The best way to get
    // the current user is either to use the getRoom method above or
    // use the client-side JS helpers: https://developer.atlassian.com/hipchat/guide/hipchat-ui-extensions/views/javascript-api#JavascriptAPI-GettingcontextualinformationfromtheHipChatClient
    getUser: function (clientInfo, userId) {
      return request(clientInfo, {
        method: 'GET',
        resource: '/user/' + userId
      });
    },

    updateGlance: function (clientInfo, roomId, moduleKey, glance) {
      return request(clientInfo, {
        method: 'POST',
        resource: '/addon/ui/room/' + roomId,
        body: {
          "glance": [{
            "key": moduleKey,
            "content": glance
          }]
        }
      });
    }
  };
};
