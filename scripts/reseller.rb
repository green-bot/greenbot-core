
#!/usr/bin/env ruby
# The script for resellers, allowing outsiders to order new services.
#
# reseller.rb
#
require "./lib/greenbot.rb"
require "timeout"
require "redis"
require "awesome_print"
require 'json'

HOUR = 60 * 60
timeout = ENV['CONVERSATION_TIMEOUT'].to_i || 4 * HOUR
$r = Redis.new

class User
  attr_accessor :roles
  attr_accessor :network_id
  attr_accessor :name
  attr_accessor :opt_in

  def initialize(redis_client)
    if redis_client then
      @redis_client = redis_client
    else
      @redis_client = Redis.new
    end
  end

  def self.fetch(network_identifier)
    unless $r
      redis_client = Redis.new
    else
      redis_client = $r
    end
    user = $r.get("user:#{network_identifier}")
    return nil if user.nil?
    JSON.parse user
  end

  def user?
    roles.include?("user")
  end
  def dealer?
    roles.include?("dealer")
  end
  def distributor?
    roles.include?("distributor")
  end
  def store
    if valid?
      serialized_self = self.to_json
      @redis_client.set("user:#{@network_id}", serialized_self)
      @roles.each do |r| 
        @redis_client.sadd(role, @network_id)
      end
    else
      raise "Cannot store user. Not valid"
    end
  end
  def remove
    if valid?
      @roles.each do |r|
        @redis_client.srem r, @network_id
      end
    end
  end
  def valid?
    @network_id.present? && @roles.present?
  end
end


# The setup, Noah texts into Steve the distributor.
# Distributor signs up dealers, dealers sign up customers
# You can be a distributor and dealer at the same time.
#
# Search the database for this src number. 
user = User.fetch(ENV['SRC'])

if user && (user.distributor?)
  puts "Sorry, this number is for users only. Distributors should text into their own number."
end

# If Noah is not found in the system, he can sign up to be a dealer or a customer.
unless user
  script_keys = $r.keys "scripts:*"
  scripts = []
  script_keys.each do |k|
    scripts << k.gsub("scripts:","")
  end

  unless confirm "Thank you for texting us. We didn't find your account on our system. Would you like to set one up?"
    puts "OK! Talk to you next time!"
    exit
  end

  select("Please select which bot you would like to set up?", scripts)

end

#   Ask noah: would you like to order a new service, or become a dealer?
#   if new service
#     Script: Please select script - information, leadgen, text2email, complaint, etc.
#     Customer: information
#     
#     Script: May I please have a four digit passcode. You'll need it to configure your system.
#     Customer: 1234
#     
#     Script. Please take a look at our terms and conditions : http://lawyers.com
#     Script: Do you accept these terms? (y/n)
#     User: Y
#
#     Script: May we please have a credit card to pay for this account?  Please click this link to add it.
#     Script: Heres your link: stripe.com/pay/1234afasfd
#     Customer: clicks link, pays for account.
#     Script: Thank you! your number: 212-555-1212
#
#     (Note that we might be able to get email from merchant)     
#     Script: Can we please have an email address to send results to?
#     Customer: Noah@tsgglobal.com
#     Script. Conversations will be mailed to noah@tsgglobal.com. Correct? (y/n)
#     User: Y
#
#     Script:  If you don't have experience with this script, you can try our demo script at 212-121-1222 to see what it looks like.
#
#
#     Script: Please give us what you'd like for your first prompt. 
#     User: Thank you for texting us at Longfellows!
#     Script: Thank you. PROMPT1 is now  set to be: "Thank you for texting us at Longfellows". Correct? (y/n)
#     User: Y
#     Script: Please give us what you'd like for your second prompt. 
#     User: Longfellows have long fellows.
#     Script: Thank you. PROMPT2 is now  set to be: "Longfellows have long fellows". Correct? (y/n)
#     User: N
#     Script: Please give us what you'd like for your second prompt. 
#     User: Longfellows have very long fellows.
#     Script: Thank you. PROMPT2 is now  set to be: "Longfellows have very long fellows". Correct? (y/n)
#     User: Y
#     
#     Ad nauseum...
#     
#     Script: Your script is now setup for use.
#    
#     Thanks!
#     Script: emails notification to user with instructions for new account, same for distributor
#
# else if Noah is already a customer, he can sign up for new numbers, or to become a dealer.
#  
#     Script: May I please have your four digit passcode. You'll need it to configure your system.
#     Customer: 1234
#
#     Script: Please select script - information, leadgen, text2email, complaint, etc.
#     Customer: information
#     
#     Script: Thank you! your number: 212-555-1212
#
#     Script: We are currently sending emails to noah@. Is there a different one you want to use?
#     Customer : N
#
#     Script:  If you don't have experience with this script, you can try our demo script at 212-121-1222 to see what it looks like.
#
#     Script: Please give us what you'd like for your first prompt. 
#     User: Thank you for texting us at Longfellows!
#     Script: Thank you. PROMPT1 is now  set to be: "Thank you for texting us at Longfellows". Correct? (y/n)
#     User: Y
#     Script: Please give us what you'd like for your second prompt. 
#     User: Longfellows have long fellows.
#     Script: Thank you. PROMPT2 is now  set to be: "Longfellows have long fellows". Correct? (y/n)
#     User: N
#     Script: Please give us what you'd like for your second prompt. 
#     User: Longfellows have very long fellows.
#     Script: Thank you. PROMPT2 is now  set to be: "Longfellows have very long fellows". Correct? (y/n)
#     User: Y
#     
#     Ad nauseum...
#     
#     Script: Your script is now setup for use.
#     Thanks!
#
#     Script: emails notification to user with instructions for new account, same for distributor
#
# Noah wants to be a dealer:
#     Script: Welcome to the Kisst Family!
#     Script: May we please have your email addrss?
#     User: noah@
#     Script: May we please have your full name?
#     User: Noah Rafalko
#     Script: May we please have your mailing address?
#     User: 77 Barnhill, W barn, 02668
#
#     Script. Please take a look at our terms and conditions : http://lawyers.com
#     Script: Do you accept these terms? (y/n)
#     User: Y
#
#     Script: Dealers commit to a minimum of "8" paid accounts, at "$20" a month each. We need a credit card to guarantee this.
#     Script: Heres your link: stripe.com/pay/1234afasfd
#     Customer: clicks link, pays for dealer monthly.
#     Script: Thank you! your number: 212-555-1212. Please have your customers use that number to order new services.
#     Script: WHen they do, they will be part of your customer base.
# 
#     if not passcode, collect it.
#
#     Script: Would you like to setup your own script on a different number?
#     User: Y
# 
#    <Start the number ordering process, don't collect credit card.>
#     Script: emails notification to user for new account, same for distributor
#
#
#













































begin
  Timeout::timeout(timeout) {
    puts ENV['PROMPT_1']
    puts ENV['PROMPT_2']

    puts("How can I help? (Hours, Specials, Address, Contact, Quit)")
    choice = gets
    choice.downcase!
    choice.remember("choice")

    case choice.each_char.first
    when "h"
      puts ENV['HOURS']
    when "s"
      puts ENV['SPECIALS']
    when "a"
      puts ENV['ADDRESS']
    when "c"
        if agree("Would you like someone to contact you?", false)
          contact_me = true
          contact_me.remember("remember_me")
          name = ask("When we call, who should we ask for?")
          name.remember("who_to_ask_for")
          if agree("Is there another number we should try?", false)
            better_number = ask("Please enter that number with an area code", 
                                 lambda { |p| p.delete("^0-9").
                                                sub(/\A(\d{3})/, '(\1) ').
                                                sub(/(\d{4})\Z/, '-\1') } ) do |q|
                              q.validate = lambda { |p| p.delete("^0-9").length == 10 }
                              q.responses[:not_valid] = "Enter a phone numer with area code."
                            end
             better_number.remember("better_number")
          end
        else
          puts("No problem at all.")
        end
    end
    puts ENV['SIGNATURE']
  }
rescue Timeout::Error  => e
  puts "If you want to restart this conversation, text us again!"
  puts ENV['SIGNATURE']
end

 
