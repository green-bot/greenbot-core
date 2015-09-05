#!/usr/bin/env ruby
# The basic usage script from https://github.com/JEG2/highline.git
#
# basic_usage.rb
#
require "timeout"
require 'open3'
require "awesome_print"
require 'parse-ruby-client'
require 'uuidtools'
require 'table_print'


abort "Please export PARSE_APP_ID" unless ENV['PARSE_APP_ID']
abort "Please export PARSE_API_KEY" unless ENV['PARSE_API_KEY']

SRC = ARGV[0] || 'developer'


Parse.init(application_id: ENV['PARSE_APP_ID'], api_key: ENV['PARSE_API_KEY'], quiet: true)
q = Parse::Query.new("Rooms")
if ARGV[1]
  DST = ARGV[1]
  q.eq("name", DST)
  room = q.get.first
else
  rooms = q.get
  objectIds = rooms.map {|r| r['objectId']}
  tp rooms, :objectId, :name, :keyword, :default_cmd
  begin
    puts "What object ID room do you want to use?"
    objectId = gets().chomp!
    found = objectIds.include? objectId
    puts "That is not a valid choice" unless found
  end while not found
  room = rooms.detect{|r| r['objectId'] == objectId}
  DST = room['name']
  puts "Using #{DST} : #{room['keyword']}"
end

if ARGV[2]
  CMD = "ruby #{ARGV[2]}"
else
  CMD = room["default_cmd"]
end


settings = room["settings"]
settings["SRC"] = SRC
settings["DST"] = DST
settings["SESSION_ID"] = UUIDTools::UUID.random_create
settings["ROOM_OBJECT_ID"] = room['objectId']
system(settings, CMD)
