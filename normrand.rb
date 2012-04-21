# encoding: utf-8

def normRand(std = 1.0, mean = 0.0)
	begin
		a1 = 2.0 * rand - 1.0
		a2 = 2.0 * rand - 1.0
		b = a1*a1 + a2*a2;
	end while b >= 1.0
	b = Math::sqrt((-2.0 * Math::log(b)) / b)
	(a1 * b) * std + mean
end
