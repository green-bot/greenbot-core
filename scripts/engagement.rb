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

    data_prompts = {}
    data_prompts['DATA_PROMPT_1'] = ENV['DATA_PROMPT_1'] unless ENV['DATA_PROMPT_1'].empty?
    data_prompts['DATA_PROMPT_2'] = ENV['DATA_PROMPT_2'] unless ENV['DATA_PROMPT_2'].empty?
    data_prompts['DATA_PROMPT_3'] = ENV['DATA_PROMPT_3'] unless ENV['DATA_PROMPT_3'].empty?

    data_prompts.each do |k,v|
      answer = confirmed_gets(v)
      answer.remember(k)
    end

    answer = confirm(ENV['QUESTION_PROMPT'])
    answer.remember("ANSWER")
    if answer
      tell ENV['YES_ANSWER']
    else
      tell ENV['NO_ANSWER']
    end

  }
rescue Timeout::Error  => e
  tell "If you want to restart this conversation, text us again!"
end
tell ENV['SIGNATURE']
