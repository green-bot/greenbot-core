#!/usr/bin/env ruby
# The basic usage script from https://github.com/JEG2/highline.git
#
# basic_usage.rb
#
require "timeout"
require 'open3'
require "awesome_print"
require 'parse-ruby-client'
require 'nexmo'
require 'uuidtools'


Parse.init(application_id: "y9Bb9ovtjpM4cCgIesS5o2XVINBjHZunRF1Q8AoI", api_key: "C9s58yZZUqkAh1Yzfc2Ly9NKuAklqjAOhHq8G4v7", quiet: true)


# Usage: local_provision new_number template_number

q = Parse::Query.new("Room")
q.eq("name", ARGV[1])
room = q.get.first

settings = room["settings"]
settings["SRC"] = ARGV[0]
settings["DST"] = ARGV[1]
settings["SESSION_ID"] = UUIDTools::UUID.random_create

settings.each {|k,v| ENV[k] = v}
ENV.each {|k,v| "#{k} : #{v}"}

system("ruby #{ARGV[2]}")
