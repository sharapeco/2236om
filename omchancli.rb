# encoding: utf-8

require File.expand_path '../omchan', __FILE__
require File.expand_path '../omchanenv', __FILE__

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
				puts '> ' + @omchan.chun if c == ?t # only print
				@env.chunForce if c == ?u
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
