#!/usr/bin/env ruby
# The basic usage script from https://github.com/JEG2/highline.git
#
# basic_usage.rb
#
require 'timeout'
require 'open3'
require 'awesome_print'
require 'uuidtools'
require 'table_print'
require './lib/room.rb'
require 'byebug'

SRC = ARGV[0] || 'developer'
DST = ARGV[1]
KEYWORD = ARGV[2]

q = Room.where(name: DST)
if KEYWORD
  q = q.where(keyword: KEYWORD)
else
  q = q.where(default: true)
end

if q.count == 0
  puts 'Cant find a room with those settings.'
  exit
end

room = q.first

CMD = room['default_cmd']
settings = room.settings.merge(
  SRC: SRC,
  DST: DST,
  SESSION_ID: UUIDTools::UUID.random_create,
  ROOM_OBJECT_ID: room.id
)
system(settings, CMD)
