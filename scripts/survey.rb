#!/usr/bin/env ruby
#
#
require "./lib/greenbot.rb"
require "timeout"

HOUR = 60 * 60
timeout = ENV['CONVERSATION_TIMEOUT'].to_i || 4 * HOUR

begin
  Timeout::timeout(timeout) {
    tell ENV['PROMPT_1']
    tell ENV['PROMPT_2']

    name = confirmed_gets(ENV['NAME_PROMPT']) if ENV['NAME_PROMPT']
    prompts = %w( DATA_PROMPT_1 DATA_PROMPT_2 DATA_PROMPT_3 DATA_PROMPT_4 DATA_PROMPT_5 DATA_PROMPT_6 DATA_PROMPT_7 DATA_PROMPT_8 DATA_PROMPT_9 DATA_PROMPT_10 )
    data_prompts = []
    prompts.each do |p|
      unless ENV[p].nil?
        answer = ask(p)
        answer.remember(p)
      end
    end    
    tell ENV['SIGNATURE']
  }
rescue Timeout::Error  => e
  tell "If you want to restart this conversation, text us again!"
end
