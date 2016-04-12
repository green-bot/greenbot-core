# greenbot

greenbot is a chat bot server, designed to give your bot a place to live.  If you want to host a variety of kinds of bots, and connect them to messaging networks of all kinds, and stick the results of all of those chats into cloud services, databases and emails, then you would probably appreciate a bot server.  Just like we use web servers to serve up HTML, bot servers start and manage sessions with end users.


# Installation using Docker
Start with a generic Ubuntu image, we normally use Digital Ocean: 2 GB Memory / 40 GB Disk / NYC3 - Ubuntu 14.04.4 x64

    1  wget -qO- https://get.docker.com/ | sh
    2  sudo usermod -aG docker $(whoami)
    3  sudo apt-get -y install python-pip
    4  sudo pip install docker-compose
    5  git clone https://github.com/green-bot/greenbot-core.git
    6  git clone https://github.com/green-bot/greenbot-admin.git
    7  cd ../greenbot-core/
    8  export ROOT_URL=http://104.131.120.192
    9  docker-compose -f docker-compose-portal.yml up



# Environment Variables
* WATSON_USERNAME, WATSON_PASSWORD : Natural language translation
* MONGO_URL : Mongo URL
* DEV_ROOM_NAME : Override normal collection of room names for dev
* SLACK_TOKEN : For live chats and bots.
