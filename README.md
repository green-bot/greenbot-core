# greenbot

greenbot is a chat bot server, designed to give your bot a place to live.  If you want to host a variety of kinds of bots, and connect them to messaging networks of all kinds, and stick the results of all of those chats into cloud services, databases and emails, then you would probably appreciate a bot server.  Just like we use web servers to serve up HTML, bot servers start and manage sessions with end users.


# Standard Installation
Start with a generic Ubuntu image, we normally use Digital Ocean: 2 GB Memory / 40 GB Disk / NYC3 - Ubuntu 14.04.4 x64

    git clone https://github.com/green-bot/greenbot-core.git
    git clone https://github.com/green-bot/greenbot-admin.git
    cd greenbot-core
    export ROOT_URL=http://{your IP}

# Installation using Docker
Start with a generic Ubuntu image, we normally use Digital Ocean: 2 GB Memory / 40 GB Disk / NYC3 - Ubuntu 14.04.4 x64

    wget -qO- https://get.docker.com/ | sh
    sudo usermod -aG docker $(whoami)
    sudo apt-get -y install python-pip
    sudo pip install docker-compose
    git clone https://github.com/green-bot/greenbot-core.git
    git clone https://github.com/green-bot/greenbot-admin.git
    cd greenbot-core
    export ROOT_URL=http://{your IP}
    docker-compose -f docker-compose-portal.yml up



# Configuration Variables

The following environment variables control the configuration of GreenBot

## Greenbot Core
* DEFAULT_LANG: Default human language for watson translation. Defaults to 'en'
* DEV_ROOM_NAME : Override normal collection of room names for dev
* GREENBOT_BOT_SERVER_PORT: Specifies express web server port. Used for network call backs, APIs. Defaults to 3001
* GREENBOT_NPM_PATH: Relative path to NPM installed modules. Defaults to './node_modules/'
* MONGO_URL : Mongo URL. Defaults to 'mongodb://localhost:27017/greenbot'
* REDIS_PORT: Redis server port. Defaults to 6379
* REDIS_HOST: Redis server hostname. Defaults to 'localhost'
* TRACE_MESSAGES: Shows much tracing on the command line. `export TRACE_MESSAGES=YES` to enable, unset `TRACE_MESSAGES` to disable
* WATSON_DIALOG_PASS: Password for watson bot dialogs
* WATSON_DIALOG_USERNAME: Username for watson bot dialogs
* WATSON_DIALOG_ID: Id for watson bot dialogs
* WATSON_USERNAME, WATSON_PASSWORD : BlueMix credentials for human language translation

### Greenbot Core Adapters
* DEV_ROOM_NAME: Default network handle for local telnet testing. Defaults to 'development::telnet'
* GB_SOCKET_PORT: Port for socket.io adapter. Defaults to 3003
* GH_TOKEN: Grasshopper network adapter token
* GH_NUMBER: Grasshopper network number
* GH_WEBHOOK: Grasshopper inbound message webhook. Defaults to '/inbound/gh'
* TSG_CALLBACK_HOST: Host name for TSG inbound webhooks
* TSG_SECRET: Token for sending TSG messages
* TSG_COBRA_KEY: Token for changing postback URL for inbound webhooks
* ZW_NUMBER: Zipwhip number
* ZW_PASS: Zipwhip password

### Greenbot Core Test Tools
* CONSOLE_SRC: default source for tools/test.coffee. Defaults to console.
* GB_SOCKET_URL: URL for GB socket, used by tools/test.coffee. Defaults to 'http://127.0.0.1:3003'
* TSG_COBRA_KEY: Token for changing postback URL for inbound webhook. Used by tools/tsg_webhook_config.coffee

## Greenbot Admin
* GREENBOT_IO_URL: The default address of socket.io interface to GreenBot. Used to support running bots from the admin portal. default:  'http://localhost:3003'
* GREENBOT_BOT_SERVER_PORT: The port that the GB API is listening to on localhost. default: 3001
