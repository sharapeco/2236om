# encoding: utf-8

require 'rubygems'
require 'twitter'
require 'pit'
require 'pp'

$KCODE = 'u'
MultiJson.engine = :ok_json

$account = Pit.get('2236om', :require => {
	'screen_name' => 'Twitter screen name',
	'consumer_key' => 'Twitter application consumer key',
	'consumer_secret' => 'Twitter application consumer secret',
	'oauth_token' => 'OAuth token',
	'oauth_token_secret' => 'OAuth token secret',
})

Twitter.configure do |config|
	config.consumer_key = $account['consumer_key']
	config.consumer_secret = $account['consumer_secret']
	config.oauth_token = $account['oauth_token']
	config.oauth_token_secret = $account['oauth_token_secret']
end

def dbfile
	File.expand_path '../data/omchan.db', __FILE__
end
