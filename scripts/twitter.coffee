# Description:
#   Handles logging.
#
# Dependencies:
#   Winston, Papertrail
#
# Configuration:
#   Done through ports
#
#
# Author:
#   Thomas Howe
#

shortId = require 'shortid'

module.exports = (robot) ->
  my_profile = undefined

  console_display= (obj, title) ->
    console.log(title) if title?
    console.log "#{key} = #{value}" for key, value of obj

  should_reply= (tweet) ->
    console.log "Discarding tweet, not from a user." unless tweet.user?
    return false unless tweet.user?
    console.log "Discarding tweet, my profile is not set." unless my_profile?
    return false unless my_profile?
    console.log "Discarding tweet, I apparently sent this message." if tweet.user.screen_name == my_profile.screen_name
    return false if tweet.user.screen_name == my_profile.screen_name

    wordList = robot.brain.get("wordList") or  ["sucks", "help"]
    mentioned = false
    return false unless tweet.text?
    tweet_array = tweet.text.split(" ")
    for tweet_text in tweet_array
      tweet_text = tweet_text.toLowerCase()
    for word in wordList
      mentioned = true if word in tweet_array
    mentioned

  robot.on "twitter_profile", (profile) =>
    my_profile = profile
    console_display(my_profile, "Twitter Profile")

  robot.on "tweet", (tweet) ->
    console.log "Tweet: #{tweet.text}"
    if should_reply(tweet)
      console_display(tweet.user)
      followers=robot.brain.get('twitterFollowers')
      if tweet.user.id in followers
        reply_text = process.env.TWITTER_REPLY_FOLLOWER or "Sorry you are having troubles. DM me if you think I can help"
      else
        reply_text = process.env.TWITTER_REPLY_NOT_FOLLOWER or "We can help you right away. Please follow me to start conversation"
      robot.emit("update_status", "@#{tweet.user.screen_name}:#{reply_text}. #{shortId.generate()}")

  console.log "Twitter script running."
