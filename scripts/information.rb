#!/usr/bin/env ruby
# The basic usage script from https://github.com/JEG2/highline.git
#
# basic_usage.rb
#
require "./lib/greenbot.rb"

say("Thanks for texting us. You can download your information here: http://www.yahoo.com")

local_variables.each do |v|
  eval(v.to_s).remember(v)
end

