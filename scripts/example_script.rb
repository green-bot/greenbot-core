#!/usr/bin/env ruby
# The basic usage script from https://github.com/JEG2/highline.git
#
# basic_usage.rb
#
require "./lib/greenbot.rb"


# basic output
say("Enter a contact:")

# basic input
name  = ask("Name? ")
name.remember(:name)

company = ask("Company?  ") { |q| q.default = "none" }
address = ask("Address?  ")
city = ask("City?  ")
state = ask("State?  ") do |q|
  q.case     = :up
  q.validate = /\A[A-Z]{2}\Z/
end
zip  = ask("Zip?  ") do |q|
  q.validate = /\A\d{5}(?:-?\d{4})?\Z/
end
phone = ask( "Phone?  ",
 lambda { |p| p.delete("^0-9").
              sub(/\A(\d{3})/, '(\1) ').
              sub(/(\d{4})\Z/, '-\1') } ) do |q|
  q.validate = lambda { |p| p.delete("^0-9").length == 10 }
  q.responses[:not_valid] = "Enter a phone numer with area code."
end

age         = ask("Age?  ", Integer) { |q| q.in = 0..105 }
birthday    = ask("Birthday?  ", Date)
interests   = ask( "Interests?  (comma separated list)  ",
                           lambda { |str| str.split(/,\s*/) } )
description = ask("Enter a description for this contact.") do |q|
  q.whitespace = :strip_and_collapse
end

local_variables.each do |v|
  eval(v.to_s).remember(v)
end

