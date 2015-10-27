#!/usr/bin/env ruby
# The basic usage script from https://github.com/JEG2/highline.git
#
# basic_usage.rb
#
require 'timeout'
require 'open3'
require 'awesome_print'
require 'parse-ruby-client'
require 'uuidtools'
require 'table_print'

abort 'Please export PARSE_APP_ID' unless ENV['PARSE_APP_ID']
abort 'Please export PARSE_API_KEY' unless ENV['PARSE_API_KEY']

SRC = ARGV[0] || 'developer'
DST = ARGV[1] || ENV['DEV_ROOM_NAME']
KEYWORD = ARGV[2] || ENV['DEV_KEYWORD'] || nil

Parse.init(
  application_id: ENV['PARSE_APP_ID'],
  api_key: ENV['PARSE_API_KEY'],
  quiet: true)
q = Parse::Query.new('Rooms')
q.eq('name', DST)
rooms = q.get
room = rooms.find { |r| r['keyword'] == KEYWORD } if KEYWORD
room = rooms.find { |r| r['default'] } if room.nil?
if room.nil?
  puts "Can't find room #{DST}"
  exit
else
  puts 'Using room'
  ap room
end

CMD = room['default_cmd']
settings = room['settings']
settings['SRC'] = SRC
settings['DST'] = DST
settings['SESSION_ID'] = UUIDTools::UUID.random_create
settings['ROOM_OBJECT_ID'] = room['objectId']
system(settings, CMD)
