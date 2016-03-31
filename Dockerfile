FROM ubuntu:latest
MAINTAINER Thomas Howe <ghostofbasho@gmail.com>

# Set the locale
RUN locale-gen en_US.UTF-8  
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en  
ENV LC_ALL en_US.UTF-8  
ENV MONGO_URL mongodb://db:27017/greenbot
ENV REDIS_URL redis://redis:6379

# Environment variables
ENV HOME /root
ENV DEBIAN_FRONTEND noninteractive

# Directory Structure
RUN mkdir -p /root/code
WORKDIR /root/code


# Install node
RUN apt-get update
RUN apt-get install -y gcc libc-dev build-essential curl git python libicu-dev
RUN curl -sL https://deb.nodesource.com/setup_5.x | bash -
RUN apt-get install -y nodejs

# Install greenbot core
RUN git clone https://github.com/green-bot/greenbot-core.git


# Install dependencies
WORKDIR /root/code/greenbot-core
RUN npm install
EXPOSE 3001
CMD ["npm", "start"]

