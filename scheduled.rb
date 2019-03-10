# encoding: utf-8
#
# Cron などスケジュールされた環境で活動する鸚鵡ちゃん
# ========================================
#
# 2分ごとに起動することを想定。
# hear / 3 min
# listen / 1 min → 古い tweet 順に care
# chun / 40–61 min
# forget / 42±15 min
# updateCache / 60 min
#
# 起動中は data/omchan.lock ファイルを生成する

require 'bundler/setup'
require 'twitter'
require_relative 'omchan'

class ScheduledOmchan
	def initialize()
		lock_file_path = File.expand_path '../data/omchan.lock', __FILE__
		File.open(lock_file_path, 'w') do |lock_file|
			if lock_file.flock(File::LOCK_EX|File::LOCK_NB)
				start
			else
				puts 'Other omchan is live.'
			end
		end
	end
	
	def start()
		@omchan = Omchan.new
		@db = @omchan.db
		@mtime = @omchan.mtime
		@mtime_m = @omchan.mtime_m
		
		@client = Twitter::REST::Client.new do |config|
			config.consumer_key = $account['consumer_key']
			config.consumer_secret = $account['consumer_secret']
			config.access_token = $account['oauth_token']
			config.access_token_secret = $account['oauth_token_secret']
		end
		
		now = Time.new
		
		# 活動時間の制限
		hour = 60 * now.hour + now.min
		beginHour = 60 * 5 + rand(60)
		endHour = 60 * 22 + 30 + rand(90)
		return if hour < beginHour || hour > endHour
		
		# キャッシュ更新
		if now.min == 0
			@omchan.updateCache
			return
		end
		
		# Home timeline を聞く
		hear if now.min % 3 == 2
		
		# Mentions を聞く
		listen
		
		# Reply を1件する
		reply
		
		# 自発的にしゃべる
		chun if rand(60) >= 40
			
		# 聞いた内容を忘れる
		@omchan.forget if rand(42) >= 41
	end
	
	def hear
		mtime = @mtime
		begin
			tl = @client.home_timeline
		rescue => e
			puts '# error: ' + e.to_s
			return
		end
		
		tl.reverse.each do |tw|
			next if tw.created_at <= @mtime
			next if tw.retweeted_status
			if tw.text.index('@' + $account['screen_name']).nil? and text = procTweet(tw)
				# puts '[eating...] ' + tw.user.screen_name + ': ' + text
				@omchan.eat(text)
			end
			mtime = tw.created_at if mtime < tw.created_at
		end
		@mtime = mtime
		@db.execute('UPDATE meta SET mtime = ?', @mtime.to_f)
	end
	
	def listen
		mtime = @mtime_m
		begin
			tl = @client.mentions_timeline
		rescue => e
			puts '# error: ' + e.to_s
			return
		end
		
		tl.reverse.each do |tw|
			next if tw.created_at <= @mtime_m
			if text = procTweet(tw)
				# puts '[listening...] ' + tw.user.screen_name + ': ' + text
				@omchan.eat(text, 10)
				@omchan.addTask(tw)
			end
			mtime = tw.created_at if mtime < tw.created_at
		end
		@mtime_m = mtime
	end
	
	def chun
		tweetText = @omchan.chun
		if tweetText
			# puts '> ' + tweetText
			begin
				@client.update(tweetText)
			rescue => e
				puts '# error: ' + e.to_s
			end
		end
	end
	
	def reply
		tweetText, replyToId = @omchan.care
		if tweetText
			begin
				@client.update(tweetText, :in_reply_to_status_id => replyToId)
			rescue => e
				puts '# error: ' + e.to_s
			end
		end
	end
	
	def procTweet(tw)
		# ignore my tweets
		return false if tw.user.screen_name == $account['screen_name']
		
		text = tw.text.
			gsub(/[\r\n]+/, ' ').
			gsub(/　/u, ' ').
			sub(/^RT @\w+:\s*/, '').
			gsub(/@\w+\s*/, '').
			gsub(/\s*http:\/\/t\.co\/\w+\s*/, '')
		# ひらがなかカタカナを含む
#		if /#{"[#{[0x3040].pack('U')}-#{[0x30ff].pack('U')}]"}/u =~ text
#			return text
#		end
#		return false
		return text
	end
end

ScheduledOmchan.new
