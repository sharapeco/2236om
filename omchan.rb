# encoding: utf-8

require File.expand_path '../conf', __FILE__
require File.expand_path '../normrand', __FILE__
require 'sqlite3'

# 鸚鵡ちゃんが身を置く環境を再現した素晴らしいクラス
class OmchanEnv
	def initialize(omchan)
		@omchan = omchan
		@db = @omchan.db
		@mtime = @omchan.mtime
		@mtime_m = @omchan.mtime_m
		
		i = 0
		rhy = rand(20)
		fgt = Integer(normRand(30, 30))
		upd = 60
		Thread.start do
			loop do
				hear
				listen if i == 0
				@omchan.care
				
				if rhy == 0
					@omchan.chun
					rhy = 40 + rand(20)
				end
				rhy -= 1
				
				if fgt == 0
					@omchan.forget
					fgt = Integer(normRand(30, 30))
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
			tl = Twitter.home_timeline
		rescue => e
			puts '# error: ' + e.to_s
			return
		end
		
		tl.reverse.each do |tw|
			next if tw.created_at <= @mtime
			if text = procTweet(tw)
				puts '[eating...] ' + text
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
			tl = Twitter.mentions
		rescue => e
			puts '# error: ' + e.to_s
			return
		end
		
		tl.reverse.each do |tw|
			next if tw.created_at <= @mtime_m
			if text = procTweet(tw)
				puts '[listening...] ' + text
				@omchan.eat(text, 5)
				@omchan.addTask(tw)
			end
			mtime = tw.created_at if mtime < tw.created_at
		end
		@mtime_m = mtime
	end
	
	def procTweet(tw)
		# ignore my tweets
		return false if tw.user.screen_name == '2236om'
		
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

# 鸚鵡ちゃん
class Omchan
	attr_accessor :mtime, :mtime_m
	attr_reader :db

	def initialize
		@db = SQLite3::Database.new(dbfile)
		
		@mtime = Time.at(0)
		@mtime_m = Time.at(0)
		
		@m = Hash::new
		@learnCount = 0
		@forgotten = 0
		
		@tasks = []
		
		initdb
		@m.default = @forgotten
		updateCache
	end
	
	def updateCache
		puts '# updating mcache'
		
		begin
			@db.execute('DELETE FROM memory WHERE count <= ?', @forgotten)
		rescue => e
			puts '# error: ' + e.to_s
		end
		
		@m.reject! {|mo, count| count <= @forgotten}
		max_i = 2236
		max_i = @m.length if @m.length < max_i
		@mcache = @m.sort{|x, y|
			y[1] <=> x[1]
		}[0, max_i].sort{|x, y|
			evaluate(y[0], y[1]) <=> evaluate(x[0], x[1])
		}
	end
	
	def evaluate(mo, count)
		unilen = 0
		a = mo.split(//u)
		for i in 0..(a.length - 2)
			unilen += 1 if a[i] != a[i+1]
		end
		unilen * ((count - @forgotten) - unilen/5)
	end
	
	def forget
		puts '# forgetting...'
		@forgotten += 1
		begin
			@db.execute('UPDATE meta SET forgotten = ?', @forgotten)
		rescue => e
			puts '# error: ' + e.to_s
		end
	end
	
	def addTask(tw)
		@tasks << tw
	end
	
	def care
		if @tasks.length != 0
			tw = @tasks.shift
			@mtime_m = tw.created_at
			puts '[doing...] ' + tw.id.to_s + ' ' + tw.text
			text = chun(false)
			begin
				@db.execute('UPDATE meta SET mtime_m = ?', @mtime_m.to_f)
				Twitter.update('@' + tw.user.screen_name + ' ' + text, :in_reply_to_status_id => tw.id)
			rescue => e
				puts '# error: ' + e.to_s
			end
		end
	end
	
	def eat(text, x = 1)
		atext = text.split(//u)
		(atext.length).downto(1) do |len|
			learned = mogmog(atext, len, x)
			@learnCount += learned * x
		end
		
		if @learnCount > 2236
			@learnCount = 0
		end
	end
	
	def mogmog(atext, len, x = 1)
		learned = Hash::new
		for i  in 0..(atext.length - len - 2)
			mo = atext[i, len].join
			next if /.\s./ =~ mo
			if len == 1
				@m[mo] += x if /\s/ !~ mo
				@m[mo] = @forgotten + 223 if @m[mo] > @forgotten + 223
				learned[mo] = @m[mo]
			else
				moprev = atext[i, len - 1].join
				if len == 2 or @m[moprev] > @forgotten
					@m[mo] += x
					learned[mo] = @m[mo]
				end
			end
		end
		
		learned.each do |mo, count|
			begin
				@db.execute('insert into memory values(?, ?)', mo, count)
			rescue => e
				@db.execute('update memory set count = ? where mo = ?', count, mo) if e.to_s ==  'column mo is not unique'
			end
		end
		learned.length
	end
	
	def chun(tweet = true)
		words_i = Array.new(1 + rand(5)).map{
			begin
				i = Integer(normRand(42, 0))
			end while i >= @mcache.length
			i < 0 ? -i : i
		}.uniq
		pp words_i
		i = -1
		atext = []
		length = 0
		@mcache.each do |mo, count|
			i += 1
			break if words_i.length == 0
			next if i != words_i[0]
			words_i.shift
			
			r = 1 + rand(4)
			text = (mo + ' ') * r
			atext << text
			length += text.split(//u).length
			break if length >= 100
		end
		
		text = atext.sort_by{rand}.join
		text = text.gsub(/^\s+|\s+$/, '').split(//u)[0, 100].join
		puts '> ' + text
		begin
			Twitter.update(text) if text.length != 0 and tweet
		rescue => e
			puts '# error: ' + e.to_s
		end
		text
	end
	
	def initdb
		sql = "SELECT * FROM sqlite_master WHERE type='table' AND name='meta';"
		if @db.execute(sql).length == 0
			@db.execute('CREATE TABLE meta (mtime real, mtime_m real, forgotten int)')
			@db.execute('INSERT INTO meta VALUES (0, 0, 0)')
		else
			@db.execute('SELECT * FROM meta').each do |row|
				@mtime = Time.at(row[0])
				@mtime_m = Time.at(row[1])
				@forgotten = row[2]
			end
		end
		
		sql = "SELECT * FROM sqlite_master WHERE type='table' AND name='memory';"
		if @db.execute(sql).length == 0
			@db.execute('CREATE TABLE memory (mo text unique, count integer)')
		else
			@db.execute('SELECT mo, count FROM memory WHERE count > ?', @forgotten).each do |mo, count|
				@m[mo] = count
			end
		end
	end
	
	def view(threshold = 0, len = 1)
		@m.sort{|x, y|
			x[1] <=> y[1]
		}.each do |mo, count|
			count -= @forgotten
			puts "#{count}\t#{mo}" if count > threshold and mo.split(//u).length >= len
		end
	end
	
	def viewCache
		i = 1
		@mcache[0, 128].each do |mo, count|
			printf "%3d. %5d  %s\n", i, evaluate(mo, count), mo
			i += 1
		end
	end
	
	def viewTasks
		t = []
		@tasks.each do |tw|
			t << '@' + tw.user.screen_name + ': ' + tw.text
		end
		pp t
	end
end

# 鳥かご
class OmchanApp
	def initialize
		@omchan = Omchan.new
		@env = OmchanEnv.new(@omchan)
		len = 2
		a = 5
		
		system "stty cbreak -echo"
		begin
			loop do
				c = STDIN.getc
				break if c == ?q
				@omchan.chun(false) if c == ?t # only print
				@omchan.chun if c == ?u
				@omchan.viewTasks if c == ?v
				@omchan.viewCache if c == ?c
				@omchan.view(10*a, len) if c == ?1
				@omchan.view(20*a, len) if c == ?2
				@omchan.view(30*a, len) if c == ?3
				@omchan.view(40*a, len) if c == ?4
				@omchan.view(50*a, len) if c == ?5
				len = 1 if c == ?a
				len = 2 if c == ?s
			end
		ensure
			system "stty cooked echo"
		end
	end
end

OmchanApp.new
