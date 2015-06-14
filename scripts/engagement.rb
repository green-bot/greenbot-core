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
    name.remember("name")
    prompts = %w( DATA_PROMPT_1 DATA_PROMPT_2 DATA_PROMPT_3)
    data_prompts = []
    prompts.each do |p|
      if ENV[p].size > 0
        answer = ask(ENV[p])
        answer.remember(p)
      end
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
