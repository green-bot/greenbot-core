require 'net/imap'

module GmailXoauth
  class ImapXoauth2Authenticator
    
    def process(data)
      build_oauth2_string(@user, @oauth2_token)
    end
    
  private
    
    # +user+ is an email address: roger@gmail.com
    # +oauth2_token+ is the OAuth2 token
    def initialize(user, oauth2_token)
      @user = user
      @oauth2_token = oauth2_token
    end
    
    include OauthString
    
  end
end

Net::IMAP.add_authenticator('XOAUTH2', GmailXoauth::ImapXoauth2Authenticator)
