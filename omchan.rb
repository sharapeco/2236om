# encoding: utf-8

require 'bundler/setup'
require 'sqlite3'
require_relative 'conf'
require_relative 'normrand'

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
		unilen * (Math.log(@m[mo] - @forgotten) - unilen/5)
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
		if @tasks.length == 0
			return [nil, nil]
		end
		
		tw = @tasks.shift
		@mtime_m = tw.created_at
		puts '[doing...] ' + tw.id.to_s + ' ' + tw.text
		text = chun
		return ['@' + tw.user.screen_name + ' ' + text, tw.id]
	end
	
	def eat(text, x = 1)
		@learned = Hash::new
		
		atext = text.split(//u)
		(atext.length).downto(1) do |len|
			mogmog(atext, len, x)
		end
		
		# どうやら単語らしい部分文字列を見つける
		oishi = []
		text.split(/\s+/u).each do |subtext|
			ret = taste(subtext.split(//u))
			oishi.concat(ret) if ret.length > 0
		end
		
		# どうやら単語らしい部分文字列を過剰に学習する
		puts oishi.join('|')
		oishi.each do |mo|
			val = evaluate(mo)
			amo = mo.split(//u)
			if amo.length >= 2 and val > 8
				puts '++ ' + mo + ' ' + val.to_s
				@m[mo] += x * 2
				@learned[mo] = @m[mo]
			end
			
			# 単語の部分文字列は捨てていく
			if amo.length >= 3 and val > 8
				for sublen in 2..(amo.length - 1)
					for i in 0..(amo.length - sublen)
						mos = amo[i, sublen].join
						@m[mos] -= x
						@learned[mos] = @m[mos]
						puts '-- ' + mos
					end
				end
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
			next if /\s/u =~ mo
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
			val = evaluate(subs)
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
				score += 2.236 / (@m[mo] - @forgotten)
			end
			score -= negi.join.split(//u).length - negi.length
			
			if score < bestScore
				best = negi
				bestScore = score
			end
		end
		best
	end
	
	def chun
		words_i = Array.new(1 + rand(5)).map{
			begin
				i = Integer(normRand(50, 0))
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
		return nil if text.length == 0
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
