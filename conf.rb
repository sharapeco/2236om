# encoding: utf-8

require 'rubygems'
require 'twitter'
require 'pit'
require 'pp'

$account = Pit.get('2236om', :require => {
	'screen_name' => 'Twitter screen name',
	'consumer_key' => 'Twitter application consumer key',
	'consumer_secret' => 'Twitter application consumer secret',
	'oauth_token' => 'OAuth token',
	'oauth_token_secret' => 'OAuth token secret',
})

def dbfile
	File.expand_path '../data/omchan.db', __FILE__
end
