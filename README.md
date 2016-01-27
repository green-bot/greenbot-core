# greenbot

greenbot is a chat bot server, designed to give your bot a place to live.  If you want to host a variety of kinds of bots, and connect them to messaging networks of all kinds, and stick the results of all of those chats into cloud services, databases and emails, then you would probably appreciate a bot server.  Just like we use web servers to serve up HTML, bot servers start and manage sessions with end users.


# Installation

1. git clone https://github.com/green-bot/greenbot-core.git
2. npm install
3. coffee server/greenbot.coffee


# Environment Variables
* WATSON_USERNAME, WATSON_PASSWORD : Natural language translation
* MONGO_URL : Mongo URL
* DEV_ROOM_NAME : Override normal collection of room names for dev
* SLACK_TOKEN : For live chats and bots.
