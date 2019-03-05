# encoding: utf-8

# 鸚鵡ちゃんが身を置く環境を再現した素晴らしいクラス
class OmchanEnv
	def initialize(omchan)
		@omchan = omchan
		@db = @omchan.db
		@mtime = @omchan.mtime
		@mtime_m = @omchan.mtime_m
		
		@client = Twitter::REST::Client.new do |config|
			config.consumer_key = $account['consumer_key']
			config.consumer_secret = $account['consumer_secret']
			config.access_token = $account['oauth_token']
			config.access_token_secret = $account['oauth_token_secret']
		end
		
		i = 0
		rhy = rand(20)
		fgt = Integer(normRand(30, 42))
		upd = 60
		Thread.start do
			loop do
				hear
				listen if i == 0
				tweetText, replyToId = @omchan.care
				if tweetText
					puts '> ' + tweetText
					begin
						@client.update(tweetText, :in_reply_to_status_id => replyToId)
					end
				end
				
				if rhy == 0
					tweetText = @omchan.chun
					if tweetText
						puts '> ' + tweetText
						begin
							@client.update(tweetText)
						rescue => e
							puts '# error: ' + e.to_s
						end
					end
					rhy = 40 + rand(20)
				end
				rhy -= 1
				
				if fgt == 0
					@omchan.forget
					fgt = Integer(normRand(30, 42))
				end
				fgt -= 1
				
				if upd == 0
					@omchan.updateCache
					upd = 60
				end
				
				i += 1
				i = 0 if i == 1
				
				sleep 60
			end
		end
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
				puts '[eating...] ' + tw.user.screen_name + ': ' + text
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
				puts '[listening...] ' + tw.user.screen_name + ': ' + text
				@omchan.eat(text, 10)
				@omchan.addTask(tw)
			end
			mtime = tw.created_at if mtime < tw.created_at
		end
		@mtime_m = mtime
	end
	
	def chunForce
		tweetText = @omchan.chun
		if tweetText
			puts '> ' + tweetText
			begin
				@client.update(tweetText)
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
