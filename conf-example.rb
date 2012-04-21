# encoding: utf-8

require 'rubygems'
require 'twitter'
require 'pp'

$KCODE = 'u'
MultiJson.engine = :ok_json

Twitter.configure do |config|
	config.consumer_key = '223606797749978969640'
	config.consumer_secret = '22360679774997896964091736687312762354406'
	config.oauth_token = '223606797749978969640917366873127623544061835961152'
	config.oauth_token_secret = '2236067977499789696409173668731276235440'
end

def dbfile
	File.expand_path '../data/omchan.db', __FILE__
end
