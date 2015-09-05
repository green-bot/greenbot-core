#!/usr/bin/env ruby
#
#
require "./lib/greenbot.rb"
tell ENV['PROMPT_1']
tell ENV['PROMPT_2']

name = confirmed_gets(ENV['NAME_PROMPT']) if ENV['NAME_PROMPT']
prompts = %w( DATA_PROMPT_1 DATA_PROMPT_2 DATA_PROMPT_3 DATA_PROMPT_4 DATA_PROMPT_5 DATA_PROMPT_6 DATA_PROMPT_7 DATA_PROMPT_8 DATA_PROMPT_9 DATA_PROMPT_10 )
data_prompts = []
prompts.each do |p|
  if ENV[p].size > 0
    answer = ask(ENV[p])
    answer.remember(p)
  end
end
tell ENV['SIGNATURE']
