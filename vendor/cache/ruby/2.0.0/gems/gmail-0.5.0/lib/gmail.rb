require 'net/imap'
require 'net/smtp'
require 'mail'
require 'date'
require 'time'

if RUBY_VERSION < "1.8.7"
  require "smtp_tls"
end

class Object
  def to_imap_date
    date = respond_to?(:utc) ? utc.to_s : to_s
    Date.parse(date).strftime("%d-%B-%Y")
  end
end

module Gmail
  autoload :Version, "gmail/version"
  autoload :Client,  "gmail/client"
  autoload :Labels,  "gmail/labels"
  autoload :Mailbox, "gmail/mailbox"
  autoload :Message, "gmail/message"

  class << self
    # Creates new Gmail connection using given authorization options.
    #
    # ==== Examples
    #
    #   Gmail.new(:plain, "foo@gmail.com", "password")
    #   Gmail.new(:xoauth, "foo@gmail.com",
    #     :consumer_key => "",
    #     :consumer_secret => "",
    #     :token => "",
    #     :secret => "")
    #
    # To use plain authentication mehod you can also call:
    #
    #   Gmail.new("foo@gmail.com", "password")
    #
    # You can also use block-style call:
    #
    #   Gmail.new("foo@gmail.com", "password") do |client|
    #     # ...
    #   end
    #

    def new(*args, &block)
      args.unshift(:plain) unless args.first.is_a?(Symbol)
      client = Gmail::Client.new(*args)
      client.connect
      client.login

      if block_given?
        yield client
        client.logout
      end

      client
    end
    alias_method :connect, :new

    def new!(*args, &block)
      args.unshift(:plain) unless args.first.is_a?(Symbol)
      client = Gmail::Client.new(*args)
      client.connect!
      client.login!

      if block_given?
        yield client
        client.logout
      end

      client
    end
    alias_method :connect!, :new!
  end # << self
end # Gmail
