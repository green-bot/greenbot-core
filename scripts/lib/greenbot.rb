require "rubygems"
require "highline/import"
require "yaml"
require "json"



class SessionData

  attr_accessor :collected_data

  def initialize(session_id = nil)
    session_data_path = "./session_data/"
    session_base_filname = (session_id || "session_data") + ".json"
    @filename = session_data_path + session_base_filname
    @filename = timestamp_filename(@filename) if session_id.nil?
    Dir.mkdir(session_data_path) unless Dir.exists?(session_data_path)
    @collected_data = {}
  end

  def timestamp_filename(file)
    dir  = File.dirname(file)
    base = File.basename(file, ".*")
    time = Time.now.to_i
    ext  = File.extname(file)
    File.join(dir, "#{base}_#{time}#{ext}")
  end

  def remember(key, value)
    return if key.empty?
    collected_data[key] = value
    update_record
  end

  def forget(key)
    @collected_data.delete(key) if @collected_data.keys.include?(key)
    update_record
  end

  def update_record
    File.open(@filename, "w") { |file| file.write(@collected_data.to_json) }
    puts @collected_data.to_json
  end
end

class Object
  def remember(label)
    $session.remember(label, self)
  end
  def forget(label)
    $session.forget(label)
  end
end

$session = SessionData.new(ENV['SESSION_ID'])
%w(SRC DST SESSION_ID).each do |s|
  $session.remember(s,ENV[s])
end
if ENV["RECORD_ENV"]
  ENV.keys.each do |s|
    $session.remember(s, ENV[s])
  end
end
