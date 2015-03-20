#!/usr/bin/env ruby
# The basic usage script from https://github.com/JEG2/highline.git
#
# basic_usage.rb
#
require "timeout"
require 'gmail'
require 'redis-semaphore'
require 'redis'
require 'json'
require 'eventmachine'
require "./lib/greenbot.rb"
require 'syslog/logger'

log = Syslog::Logger.new 'text2email'
$r = Redis.new


POLLING_INTERVAL=10 #seconds
MESSAGE_LENGTH=140 #characters
SESSION_TAG="\nDo not delete below this line\n----------------------------------\n#{ENV['SESSION_ID']}"
MSG_BODY_DELIMITER="###"

def fetch_session(string)
  active_sessions = $r.smembers("STARTED_SESSION")
  ended_sessions = $r.smembers("ENDED_SESSION")
  active_sessions = active_sessions - ended_sessions
  return active_sessions.find { |key| string.include?(key)}
end

def send_email(msg)
  email = {}
  email["RECIPIENT"] = ENV['RECIPIENT']
  email['SUBJECT'] = "Greenbot Testing"
  email["BODY"] = msg
  $r.lpush("OUTBOUND_EMAILS", email.to_json)
end

s = Redis::Semaphore.new(
  :gmail_poll,
  :host => "localhost",
  :stale_client_timeout => POLLING_INTERVAL*2
)


master_script = false
gmail = nil
session_key = "email:#{ENV['SESSION_ID']}"
send_email(ENV['INITIAL_MESSAGE'])

# There's a chance the "MASTER_TEXT2EMAIL_SESSION" won't expire.
# Let's expire that in a bit just to make sure it gets refreshed.
time_to_live = $r.ttl("MASTER_TEXT2EMAIL_SESSION")
if time_to_live == -1
  # Theres's no expires here. Expire it.
  $r.expire("MASTER_TEXT2EMAIL_SESSION", POLLING_INTERVAL * 2)
end

def print_and_flush(prompt)
  if ENV['DEVELOPER'] == "true"
    puts prompt
    $stdout.flush
  end
end


# This is the event loop.

EventMachine.run do
  EM.add_periodic_timer(POLLING_INTERVAL) do
    print_and_flush("text2email: #{ENV['SESSION_ID']} : Starting main loop")
    master_session = $r.get("MASTER_TEXT2EMAIL_SESSION")
    case master_session
    when ENV["SESSION_ID"]
      # We are the master sessionator.  Go get email and stick it someplace.
      # Refresh the expires on the key.
      $r.expire("MASTER_TEXT2EMAIL_SESSION", POLLING_INTERVAL * 2)
      master_script = true
    when nil
      # No one is owning this, let's own it.
      s.lock do
        # There's a chance that another script has registered itself as the
        # master script. Check for that.
        if $r.get("MASTER_TEXT2EMAIL_SESSION").nil?
          # This belongs to us now.
          $r.set("MASTER_TEXT2EMAIL_SESSION", ENV['SESSION_ID'])
          master_script = true
        else
          # We really aren't the master.
          master_script = false
        end
      end
    else
      master_script = false
    end

    # If we are the master, go get some email.
    if master_script
      print_and_flush "Apparently, I'm the master!"
      gmail = Gmail.connect!("text2email@green-bot.com", "gr33nb0t") if gmail.nil?

      # Check for inbound emails.
      begin
        gmail.inbox.emails.each do |e|
          print_and_flush "Checking email: #{e.body.decoded}"
          session_id = fetch_session(e.body.decoded)
          if session_id
            new_message = {
              body:       e.parts.first.decoded,
              subject:    e.subject,
              from:       e.from,
              to:         e.to
            }
            $r.lpush(session_key, new_message.to_json)
          else
            print_and_flush "Failed to find session ID : #{e.body.decoded}"
          end
          e.delete!
        end
      rescue => e
        # Swallow that error, send it to syslog
        print_and_flush("text2email: #{ENV['SESSION_ID']} : Mail threw error when reading from google.")
        print_and_flush("text2email: #{ENV['SESSION_ID']} : #{e.message}")
        print_and_flush("text2email: #{ENV['SESSION_ID']} : #{e.backtrace.join("\n")}")
      end

      # Check for outbound emails.
      # Only the master script can do this.
      if $r.llen("OUTBOUND_EMAILS") > 0
        print_and_flush "Looks like there's an email. Wooooo."
        while new_email = $r.lpop("OUTBOUND_EMAILS")
          new_email = JSON.parse(new_email)
          new_email = gmail.compose do
            to      new_email["RECIPIENT"]
            subject new_email["SUBJECT"]
            body    new_email['BODY'] + SESSION_TAG
          end
          new_email.deliver!
        end
      end
    end


    # See if there's inbound messages for us to send here. If so, push it on the list to be sent.
    while (true)
      print_and_flush "Checking for inbound messages from console"
      ready_readers = IO::select([$stdin], nil, nil, 1.0)
      if ready_readers
        msg = listen
        send_email(msg)
        print_and_flush("text2email: #{ENV['SESSION_ID']} just received #{msg} from stdin. Send as an email to recipient.")
      else
        print_and_flush "And not so much."
        break
      end
    end

    # See if there's any inbound emails that we have to send as messages
    while true
      print_and_flush "Checking the session key: #{session_key}"
      if $r.llen(session_key) > 0
        inbound_message = $r.lpop(session_key)
        if inbound_message
          print_and_flush "Looks like we've got one!"
          email = JSON.parse(inbound_message)
          text = email["body"]
          if text.include?(MSG_BODY_DELIMITER)
            text = text.split(MSG_BODY_DELIMITER).first
            tell text
          else
            tell text[0..MESSAGE_LENGTH].delete("\n")
          end
        end
      else
        print_and_flush "And we are done with that."
        break
      end
    end
  end
end
