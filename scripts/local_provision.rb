#!/usr/bin/env ruby
# The basic usage script from https://github.com/JEG2/highline.git
#
# basic_usage.rb
#
require "./lib/room.rb"
require "timeout"
require 'open3'
require "awesome_print"
require 'parse-ruby-client'
require 'nexmo'


Parse.init(application_id: "y9Bb9ovtjpM4cCgIesS5o2XVINBjHZunRF1Q8AoI", api_key: "C9s58yZZUqkAh1Yzfc2Ly9NKuAklqjAOhHq8G4v7", quiet: true)


# Usage: local_provision new_number template_number
@new_room = ARGV[0]
@template_room_name = ARGV[1] || "template"
@network = ARGV[2] || "tsg"

q = Parse::Query.new("Room")
q.eq("name", @template_room_name)
template_room = q.get.first
template_room = Room.new(@template_room_name)
Room.create(@new_room, template_room.options)


unless @network == "tsg"
  #Now, do the nexmo part
  nexmo = Nexmo::Client.new
  nexmo.update_number( {
    country: "US",
    msisdn: @new_room,
    moHttpUrl: "http://104.236.29.184:8888/nexmo_callback"
    })
end
