#!/usr/bin/env ruby
#
require 'rubygems'
require 'redis'
require 'json'
require "uuidtools"
require 'awesome_print'

redis = Redis.new
room = JSON.parse redis.get "room:#{ARGV[1]}"

settings = room["settings"]
settings["SRC"] = ARGV[0]
settings["DST"] = ARGV[1]
settings["SESSION_ID"] = UUIDTools::UUID.random_create

settings.each {|k,v| ENV[k] = v}
ENV.each {|k,v| "#{k} : #{v}"}

system("ruby #{ARGV[2]}")

