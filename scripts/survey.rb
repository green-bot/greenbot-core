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
    data_prompts['DATA_PROMPT_1'] = ENV['DATA_PROMPT_1'] if ENV['DATA_PROMPT_1']
    data_prompts['DATA_PROMPT_2'] = ENV['DATA_PROMPT_2'] if ENV['DATA_PROMPT_2']
    data_prompts['DATA_PROMPT_3'] = ENV['DATA_PROMPT_3'] if ENV['DATA_PROMPT_3']
    data_prompts['DATA_PROMPT_4'] = ENV['DATA_PROMPT_4'] if ENV['DATA_PROMPT_4']
    data_prompts['DATA_PROMPT_5'] = ENV['DATA_PROMPT_5'] if ENV['DATA_PROMPT_5']
    data_prompts['DATA_PROMPT_6'] = ENV['DATA_PROMPT_6'] if ENV['DATA_PROMPT_6']
    data_prompts['DATA_PROMPT_7'] = ENV['DATA_PROMPT_7'] if ENV['DATA_PROMPT_7']
    data_prompts['DATA_PROMPT_8'] = ENV['DATA_PROMPT_8'] if ENV['DATA_PROMPT_8']
    data_prompts['DATA_PROMPT_9'] = ENV['DATA_PROMPT_9'] if ENV['DATA_PROMPT_9']
    data_prompts['DATA_PROMPT_10'] = ENV['DATA_PROMPT_10'] if ENV['DATA_PROMPT_10']

    data_prompts.each do |k,v|
      answer = confirmed_gets(v)
      answer.remember(k)
    end
  }
rescue Timeout::Error  => e
  tell "If you want to restart this conversation, text us again!"
end
tell ENV['SIGNATURE']
