# Gmail Gem Changelog

## Unreleased

* Your change here


## 0.5.0 - 2015-01-26

* Migrate primary repo to https://github.com/gmailgem/gmail with new project governance (@johnnyshields, @bootstraponline)
* Create logo for project (@johnnyshields)
* Implement IMAP recorder for specs and get all specs passing (@jcarbo)
* Add Rubocop to porject and fix offenses (@jcarbo)
* Fix: #connect method not invoking a block (@jcarbo)
* Support X-GM-RAW (raw Gmail search syntax) in filter query (@bootstraponline)
* Bugfix: Improperly processing labels containing parentheses (@ryanlchan #82)
* Add support for localizing labels (@ryanlchan #83)
* Support for XOAuth2 Client (@KieranP)
* Improve support for non-english labels and mailboxes (@KieranP)
* Fix IMAP library patch on Ruby 2 (@bootstraponline, @johnnyshields,  @awakia)
* Ability to search emails by a UID filter (@KieranP)
* Add a way to disconnect the IMAP socket (@KieranP)
* Better support for timezones (@KieranP)
* Add `emails_in_batches` method (@KieranP)
* Gmail Message class: Include X-GM-THRID which is the thread id (@jcarbo)
* Gmail Message class: Include X-GM-MSGID which is a unique, non-changing email identifier (@KieranP)
* Gmail Message class: Fetch values in bulk and cache them (performance) (@KieranP)
* Gmail Message class: Pull FLAGS to make #read? and #starred? methods work (@KieranP)
* Gmail Message class: Don't mark an email as read when accessing the message (@KieranP)
* Gmail Message class: Reorganisation and cleanup of method definitions (@KieranP)
* Bugfix: Fix for XOAuth SMTP settings (@molsder #24)
* Implement Travis CI (@johnnyshields)
* Remove legacy dependency on MIME gem (@johnnyshields)
* Upgrade to RSpec 3.1 and remove Mocha dependency (@johnnyshields, @jcarbo #156)


## 0.4.2

* Fix issue related to Mail gem version lock (@johnnyshields)


## 0.4.1

* n/a


## 0.4.0

* Added XOAuth authentication method (Stefano Bernardi, Nicolas Fouché)
* Separated clients
* Fixed specs


## 0.3.4

* Fixes in mailbox filters shortcuts (Benjamin Bock)


## 0.3.3

* Added #expunge to Mailbox (Benjamin Bock)
* Added more mailbox filters (Benjamin Bock)
* Added shortcuts for mailbox filters
* Minor bugfixes


## 0.3.2

* Added envelope fetching
* Minor bugfixes


## 0.3.0

* Refactoring
* Fixed bugs
* API improvements
* Better documentation
* Code cleanup
* RSpec for everything


## 0.1.1 - 2010-05-11

* Added explicit tmail dependency in gemspec
* Added better README tutorial content


## 0.0.9 - 2010-04-17

* Fixed content-transfer-encoding when sending email


## 0.0.8 - 2009-12-23

* Fixed attaching a file to an empty message


## 0.0.7 - 2009-12-23

* Improved multipart message parsing reliability


## 0.0.6 - 2009-12-21

* Fixed multipart parsing for when the boundary is marked in quotes.


## 0.0.5 - 2009-12-16

* Fixed IMAP initializer to work with Ruby 1.9's net/imap
* Better logout depending on the IMAP connection itself
* Added MIME::Message#text and MIME::Message#html for easier access to an email body
* Improved the MIME-parsing API slightly
* Added some tests


## 0.0.4 - 2009-11-30

* Added label creation (@justinperkins)
* Made the gem login automatically when first needed
* Added an optional block on the Gmail.new object that will login and logout for you
* Added several search options (@mikker)


## 0.0.3 - 2009-11-19

* Fixed MIME::Message#content= for messages without an encoding
* Added Gmail#new_message


## 0.0.2 - 2009-11-18

* Made all of the examples in the README possible


## 0.0.1 - 2009-11-18

* Birthday!
