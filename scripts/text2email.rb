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
SESSION_EXPIRE=60*60*24*4 #Sessions last for four days

SESSION_TAG="\nDo not delete below this line\n----------------------------------\n#{ENV['SESSION_ID']}"
MSG_BODY_DELIMITER="###"

def fetch_session(string)
  # Match the session from the string.
  # Sessions are kept between square brackets.
  m = /\[(.*)\]/.match(string)

  return m if m.nil?
  # Return the match,if any. Nil means no match
  m[1]
end

def send_email(msg, email_recip, src, dst, key, label)
  email = {}
  email["RECIPIENT"] = email_recip
  email['SUBJECT'] = "Conversation : #{src} <=> #{dst} : #{label} : [#{key}]"
  email["BODY"] = "###:" + msg
  $r.lpush("OUTBOUND_EMAILS", email.to_json)
end

s = Redis::Semaphore.new(
  :gmail_poll,
  :host => "localhost",
  :stale_client_timeout => POLLING_INTERVAL*2
)

#
# Start of the main script
#

tell ENV['PROMPT_1']
tell ENV['PROMPT_2']

data_prompts = {}
data_prompts['DATA_PROMPT_1'] = ENV['DATA_PROMPT_1'] unless ENV['DATA_PROMPT_1'].empty?
data_prompts['DATA_PROMPT_2'] = ENV['DATA_PROMPT_2'] unless ENV['DATA_PROMPT_2'].empty?

labels = []
answers = {}
data_prompts.each do |k,v|
  answer = ask(v)
  answer.remember(k)
  answers[k] = answer
end


destinations = ENV['CHOICE_DEST'].gsub(",","").split
choices = ENV['CHOICES'].gsub(",","").split
choice = select(ENV['CHOICES_PROMPT'], choices)
master_script = false
gmail = nil
session_key = "TEXT2EMAIL_SESSION:#{ENV['SESSION_ID']}"

tell "Thank you! Please wait as your request is forwarded to a live agent."

recipient = destinations[choices.index(choice)]
new_conversation_message = %{

Hello!

You have a new conversation!

Source: #{ENV['SRC']}
Destination: #{ENV['DST']}
#{ENV['DATA_PROMPT_1']}: #{answers['DATA_PROMPT_1']}
#{ENV['DATA_PROMPT_2']}: #{answers['DATA_PROMPT_2']}
#{ENV['CHOICES_PROMPT']} : #{choice}

You can respond by simply responding to this message. This email will be converted to
a text message, which has size and length restrictions. For a better experience for
the other party in this conversation, please keep your emails short and to the point.
Also, we will look for three hash or pound signs (###) to mark the end of the message
that will be converted to messaging.

}

send_email(
  new_conversation_message,
  recipient,
  ENV['SRC'],
  ENV['DST'],
  ENV['SESSION_ID'],
  choice
  )

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
      gmail = Gmail.connect!("xxxxx@gmail.com", "xxxxx") if gmail.nil?

      # Check for inbound emails.
      begin
        gmail.inbox.emails.each do |e|
          print_and_flush "Checking email: #{e.subject}"
          session_id = fetch_session(e.subject)
          print_and_flush(e.inspect)
          if session_id
            if e.multipart?
              print_and_flush("multipart email")
              text = ""
              e.parts.each do |p|
                text << p.body.decoded
              end
            else
              text = e.body.decoded
            end
            new_message = {
              body:       text,
              subject:    e.subject,
              from:       e.from,
              to:         e.to
            }

            $r.lpush(session_key, new_message.to_json)
            $r.expire(session_key, SESSION_EXPIRE)
          else
            print_and_flush "Failed to find session ID : #{e.subject}"
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
            body    new_email['BODY']
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
        send_email(msg,
          recipient,
          ENV['SRC'],
          ENV['DST'],
          ENV['SESSION_ID'],
          choice)
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
          print_and_flush "Looks like we've got one!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
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
