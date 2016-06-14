# GreenBot

Greenbot is a middleware server for bots, connecting all kinds of bots to all kinds of networks. If you are a bot developer, Greenbot will make sure that you don't have to integrate all one hundred messaging networks. Messaging networks won't have to on-board one bot at a time.   

Greenbot does all kinds of good stuff:
* **Session Management**: Greenbot keeps track of messaging sessions, when a conversation starts, when it ends, what was said. Errr. Texted
* **Collect Data**: Greenbot supports bots that collect structured data from bots, then saves and webhooks that data to external services. 
* **Routing**: Greenbot connects keywords to bots, and allows bots to transfer to other bots.
* **Language Translation**: Greenbot translates between human languages, so when you text in with French, but the prompts are in English, it will restart the bot conversation with correct language. Slick.
* **All Kinds Bots**: Greenbot currently supports simple script bots, bot-kit bots, and Watson Dialog bots. More kinds of bots coming all the time.
* 

# Standard Installation
Start with a generic Ubuntu image, we normally use Digital Ocean: 2 GB Memory / 40 GB Disk / NYC3 - Ubuntu 14.04.4 x64

## Prerequisites
Greenbot-core requires 
* [mongodb](https://www.mongodb.org)
* [redis](http://redis.io/)
* [ruby 2+](https://www.ruby-lang.org/en/)
* [node](https://www.npmjs.com/) 


## Core install

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


