#
# This script encodes the raw payload as a sequence of 8 bytes (one byte per
# bit), where a bit being set is 0xfd and a bit being clear is 0xfe.
#
# Example output below:
#
# db 0xfc, 0xfd, 0xfd, 0xfd, 0xfd, 0xfd, 0xfe, 0xfe,  ; fc
# db 0xfd, 0xfd, 0xfd, 0xfe, 0xfd, 0xfe, 0xfe, 0xfe,  ; e8
# db 0xfd, 0xfe, 0xfe, 0xfe, 0xfe, 0xfe, 0xfd, 0xfe,  ; 82
# db 0xfe, 0xfe, 0xfe, 0xfe, 0xfe, 0xfe, 0xfe, 0xfe,  ; 00
#

first = true

str = ''

if ARGV[0].nil?
	puts "bit_enc.rb [raw payload file]"
	exit
end

fd = File.open(ARGV[0], "rb")

fd.read.each_byte { |byte|

	str << "\tdb "

	7.downto(0) { |bit|

		val = (((byte & (1 << (bit))) != 0) ? 0xfd : 0xfe)
		val -= 1 if first

		str << "0x%.2x, " % val
		first = false
	}

	str << " ; %.2x\n" % byte
}

str << "\tdb 0xfc\n"

puts str
