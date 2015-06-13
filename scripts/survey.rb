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

    data_prompts = {}
    data_prompts['DATA_PROMPT_1'] = ENV['DATA_PROMPT_1'] unless ENV['DATA_PROMPT_1'].nil?
    data_prompts['DATA_PROMPT_2'] = ENV['DATA_PROMPT_2'] unless ENV['DATA_PROMPT_2'].nil?
    data_prompts['DATA_PROMPT_3'] = ENV['DATA_PROMPT_3'] unless ENV['DATA_PROMPT_3'].nil?
    data_prompts['DATA_PROMPT_4'] = ENV['DATA_PROMPT_4'] unless ENV['DATA_PROMPT_4'].nil?
    data_prompts['DATA_PROMPT_5'] = ENV['DATA_PROMPT_5'] unless ENV['DATA_PROMPT_5'].nil?
    data_prompts['DATA_PROMPT_6'] = ENV['DATA_PROMPT_6'] unless ENV['DATA_PROMPT_6'].nil?
    data_prompts['DATA_PROMPT_7'] = ENV['DATA_PROMPT_7'] unless ENV['DATA_PROMPT_7'].nil?
    data_prompts['DATA_PROMPT_8'] = ENV['DATA_PROMPT_8'] unless ENV['DATA_PROMPT_8'].nil?
    data_prompts['DATA_PROMPT_9'] = ENV['DATA_PROMPT_9'] unless ENV['DATA_PROMPT_9'].nil?
    data_prompts['DATA_PROMPT_10'] = ENV['DATA_PROMPT_10'] unless ENV['DATA_PROMPT_10'].nil?

    data_prompts.each do |k,v|
      answer = ask(v)
      answer.remember(k)
    end
    tell ENV['SIGNATURE']
  }
rescue Timeout::Error  => e
  tell "If you want to restart this conversation, text us again!"
end
