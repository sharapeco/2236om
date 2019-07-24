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
		
		# Mentions があれば1件のみ聞き、返信する
		listen
		
		# 自発的にしゃべる
		chun if rand(180) < 3
			
		# 聞いた内容を忘れる
		@omchan.forget if rand(42) < 1
	end
	
	def hear
		begin
			tl = @client.home_timeline
		rescue => e
			puts '# error: ' + e.to_s
			return
		end
		
		mtime = @mtime
		tl.select {|tw| tw.created_at > @mtime}
		.select {|tw| !tw.retweeted_status}
		.reverse
		.select {|tw| tw.text.index('@' + $account['screen_name']).nil?}
		.map {|tw| [tw, procTweet(tw)]}
		.each {|tw, text|
			@omchan.eat(text)
			mtime = tw.created_at if mtime < tw.created_at
		}

		@mtime = mtime
		begin
			@db.execute('UPDATE meta SET mtime = ?', @mtime.to_f)
		rescue => e
			puts '# error: ' + e.to_s
			return
		end
	end
	
	def listen
		begin
			tl = @client.mentions_timeline
		rescue => e
			puts '# error: ' + e.to_s
			return
		end
		
		mtime = @mtime_m
		tl.select {|tw| tw.created_at > @mtime_m}
		.reverse
		.map {|tw| [tw, procTweet(tw)]}
		.slice(0, 1)
		.each {|tw, text|
			@omchan.eat(text, 10)
			@omchan.addTask(tw)
			reply
			mtime = tw.created_at if mtime < tw.created_at
		}

		@mtime_m = mtime
		begin
			@db.execute('UPDATE meta SET mtime_m = ?', @mtime_m.to_f)
		rescue => e
			puts '# error: ' + e.to_s
		end
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
			gsub(/\s*https?:\/\/t\.co\/\w+\s*/, '')
		# ひらがなかカタカナを含む
#		if /#{"[#{[0x3040].pack('U')}-#{[0x30ff].pack('U')}]"}/u =~ text
#			return text
#		end
#		return false
		return text
	end
end

ScheduledOmchan.new
