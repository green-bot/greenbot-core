require 'rubygems'
require 'bundler/setup'
require 'mongoid'
require 'highline/import'
require 'yaml'
require 'json'
require 'redis'
require 'uuidtools'
require 'airbrake'
require 'timeout'

Mongo::Logger.logger.level = Logger::WARN
Mongoid.load!('lib/mongoid.yml', :production)

# Handles the Script collection in Mongo
class Script
  include Mongoid::Document
  field :default_cmd, type: String
  field :default_settings, type: Hash
  field :owner_cmd, type: String
  field :default_path, type: String
end

# Handles the Room collection in Mongo
class Room
  include Mongoid::Document
  store_in collection: 'Rooms'
  field :name, type: String
  field :settings, type: Hash
  field :qty, type: Integer
  field :test_mode, type: Boolean
  field :owners, type: Array
  field :notification_emails, type: Array
  field :default_cmd, type: String
  field :default_path, type: String
  field :owner_cmd, type: String
  field :mail_user, type: String
  field :mail_pass, type: String

  def valid?
    settings ? true : false
  end

  def assign(script)
    update_attributes!(
      default_cmd: script.default_cmd,
      settings: script.default_settings,
      owner_cmd: script.owner_cmd,
      default_path: script.default_path
    )
  end

  def not_setup?
    default_cmd == 'ruby default.rb'
  end

  def retarget(new_room_name)
    update_attributes(
      name: new_room_name.downcase
    )
  end

  def add_qty(amount)
    new_qty = qty + amount
    update_attributes(
      qty: new_qty
    )
  end

  def subtract_qty(amount)
    new_qty = qty - amount
    update_attributes(
      qty: new_qty
    )
  end

  def set_test_mode
    update_attributes(
      test_mode: true
    )
  end

  def env_settings
    settings.reject { |k, _v| %w(AWAY AUTO_CHARGE auto_charge).include?(k) }
  end

  def update_setting(key, value)
    new_settings = settings
    new_settings[key] = value
    update_attributes(
      settings: new_settings
    )
  end

  def get_setting(key)
    settings[key]
  end

  def set_environment
    env_settings.each { |k, v| ENV[k] = v }
  end
end
