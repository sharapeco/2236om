# encoding: utf-8

require File.expand_path '../conf', __FILE__
require File.expand_path '../omchanenv', __FILE__
require File.expand_path '../normrand', __FILE__
require 'sqlite3'

# 鸚鵡ちゃん
class Omchan
	attr_accessor :mtime, :mtime_m
	attr_reader :db

	def initialize
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
			evaluate(y[0]) <=> evaluate(x[0])
		}
		puts '# update done'
	end
	
	def evaluate(mo)
		unilen = 0
		a = mo.split(//u)
		for i in 0..(a.length - 2)
			unilen += 1 if a[i] != a[i+1]
		end
		unilen * ((@m[mo] - @forgotten) - unilen/5)
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
		@learned = Hash::new
		atext = text.split(//u)
		(atext.length).downto(1) do |len|
			mogmog(atext, len, x)
		end
		
		oishi = taste(atext)
		puts oishi.join('|')
		# eachだとなぜか上手くいかない
		for i in 0..(oishi.length - 1)
			mo = oishi[i]
			val = evaluate(mo)
			if mo.split(//u).length >= 2 and val > 42
				puts '++ ' + mo + ' ' + val.to_s
				@m[mo] += x
				@learned[mo] = @m[mo]
			end
		end
		
		@learned.each do |mo, count|
			memorize(mo, count)
		end
		
		@learnCount += @learned.length * x
		if @learnCount > 2236
			updateCache
			@learnCount = 0
		end
	end
	
	def mogmog(atext, len, x = 1)
		for i  in 0..(atext.length - len - 2)
			mo = atext[i, len].join
			next if /.\s./ =~ mo
			if len == 1
				@m[mo] += x if /\s/ !~ mo
				@m[mo] = @forgotten + 223 if @m[mo] > @forgotten + 223
				@learned[mo] = @m[mo]
			else
				moprev = atext[i, len - 1].join
				if len == 2 or @m[moprev] > @forgotten
					@m[mo] += x
					@learned[mo] = @m[mo]
				end
			end
		end
	end
	
	def taste(atext)
		p = 0
		psize = 20
		koreda = []
		begin
			sub = atext[p, psize]
			@kamo = []
			tasteSub(sub, [])
			res = tasteEval
			if res.length > 0
				res.pop if p < atext.length - psize
				koreda.concat(res)
				p += res.join.split(//u).length
			else
				p += psize
			end
		end while p < atext.length
		
		koreda
	end
	
	def tasteSub(a, parsed)
		hit = 0
		(a.length).downto(1) do |len|
			sub = a[0, len]
			rest = a[len..-1]
			subs = sub.join
			count = @m[subs] - @forgotten
			val = sub.length * @m[sub]
			next if val < 0.8 * hit
			if count > 0
				hit = val if hit < val
				parsed1 = parsed.clone.push(subs)
				if rest.length > 0
					tasteSub(a[len..-1], parsed1)
				else
					@kamo.push(parsed1)
				end
			end
		end
	end
	
	def tasteEval
		best = []
		bestScore = 1/0.0
		@kamo.each do |negi|
			score = 0.0
			negi.each do |mo|
				score += 1.0 / (@m[mo] - @forgotten)
			end
			score -= negi.join.split(//u).length - negi.length
			
			if score < bestScore
				best = negi
				bestScore = score
			end
		end
		best
	end
	
	def chun(tweet = true)
		words_i = Array.new(1 + rand(5)).map{
			begin
				i = Integer(normRand(42, 0)) #人生、宇宙、すべての答え
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
			
			r = 1 + rand(Integer(8 / mo.split(//u).length))
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
		@db = SQLite3::Database.new(dbfile)
		
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
	
	def memorize(mo, count)
		begin
			@db.execute('insert into memory values(?, ?)', mo, count)
		rescue => e
			@db.execute('update memory set count = ? where mo = ?', count, mo) if e.to_s ==  'column mo is not unique'
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
			printf "%3d. %5d  %s\n", i, evaluate(mo), mo
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
