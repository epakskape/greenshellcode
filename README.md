This repository contains a shellcode encoder for 32-bit x86 that uses only 3 unique bytes: `0x4c`, `0xe4`, and `0xff`. It was originally implemented as part of [@JohnLaTwC](https://twitter.com/JohnLaTwC/)'s [Green Shellcode challenge](https://twitter.com/JohnLaTwC/status/1107380892467490816) that he ran in 2008.

The checked in example encodes a [`windows/exec`](https://github.com/rapid7/metasploit-framework/blob/master/modules/payloads/singles/windows/exec.rb) payload from Metasploit that will execute calc.exe. The encoded version is `36062` bytes in length.

Smaller 3 unique byte versions of this payload are possible. The [winning entry](https://gist.github.com/JohnLaTwC/d2c3e7f54e256aa2fd5ce4b86a1d6d54) from the original contest, which was independently created by another team, was smaller than this one. If you come up with a smaller approach, let me know and I'll link to your repo :)

# How it works

The three unique bytes used by this encoder can be used to compose the following instructions:

```asm
 4C                dec esp
 FF4CE4FF          dec dword [esp-0x1]
 FFE4              jmp esp
```

The `dec esp` instruction is useful because it can be used to move the stack pointer into a region of the stack that has not yet been used, and thus is expected to contain a known state: zero bytes. By default, the encoder assumes that decrementing the stack pointer by 4 pages is sufficient to reach this regoin.

The `dec dword [esp-0x1]` instruction can then be used to generate arbitrary byte values on the stack. For example, if the dword value at `esp-0x1` is zero and `0x1a` subtractions are performed, then the dword value will become `0xffffffe6`. If the stack pointer is then decremented by `dec esp`, the dword value at `esp-0x1` will become `0xffffe600`. If `0x15` subtractions are then performed, the dword value becomes `0xffffe5eb`, which corresponds to a `jmp short` instruction if disassembled:

```
EBE5              jmp short 0xffffffe7
```

After all of the bytes of the encoded payload have been decoded in this way, they can be executed by the `jmp esp` instruction. This is because the payload has been decoded in place on the stack such that the stack pointer refers to the first byte of the decoded payload when it finishes.

## Extra tricks

While the above approach is sufficient to encode any payload, it can result in large payloads. This is because generating decoded byte values requires the `dec dword [esp-0x1]` instruction, e.g. one for each decrement required to generate a decoded byte value. This can be costly because `dec dword [esp-0x1]` is 4 bytes.

To reduce this cost, this encoder also contains a second level of encoding. This encoding transforms each byte of the [raw payload](https://github.com/epakskape/greenshellcode/blob/master/raw_payload_enc.asm) into a sequence of 8 encoded bytes for each raw byte (representing one raw bit per encoded byte), where a bit being set is 0xfd and a bit being clear is 0xfe. Some examples of this encoding can be seen below:

```
0xe8 = 0xfd, 0xfd, 0xfd, 0xfe, 0xfd, 0xfe, 0xfe, 0xfe
0x82 = 0xfd, 0xfe, 0xfe, 0xfe, 0xfe, 0xfe, 0xfd, 0xfe
0x00 = 0xfe, 0xfe, 0xfe, 0xfe, 0xfe, 0xfe, 0xfe, 0xfe
```

A [decoder stub](https://github.com/epakskape/greenshellcode/blob/master/decode.asm) is prepended to this sequence which is responsible for performing the inverse operation at runtime. This decoder stub is relatively small and uses some tricks to minimize the number of low value bytes which helps reduce the number of `dec dword [esp-0x1]` required:

```
00000000  EB7F              jmp short 0x81
00000002  5E                pop esi
00000003  89F7              mov edi,esi
00000005  B1F7              mov cl,0xf7
00000007  F6D1              not cl
00000009  D1E3              shl ebx,1
0000000B  AC                lodsb
0000000C  FEC0              inc al
0000000E  FEC0              inc al
00000010  7408              jz 0x1a
00000012  FEC0              inc al
00000014  FEC0              inc al
00000016  746E              jz 0x86
00000018  FFC3              inc ebx
0000001A  E2ED              loop 0x9
0000001C  93                xchg eax,ebx
0000001D  AA                stosb
0000001E  EBE5              jmp short 0x5
...
00000081  E87CFFFFFF        call dword 0x2
```

# How the encoded payload is generated

The following steps are taken to generate the encoded payload:

1. The [bit_enc.rb](https://github.com/epakskape/greenshellcode/blob/master/bit_enc.rb) script is used to transform the [raw_payload.bin](https://github.com/epakskape/greenshellcode/blob/master/raw_payload.bin) into its encoded form which is stored in [raw_payload_enc.asm](https://github.com/epakskape/greenshellcode/blob/master/raw_payload_enc.asm).

2. The second level decoder in [decode.asm](https://github.com/epakskape/greenshellcode/blob/master/decode.asm) is built with [nasm](https://nasm.us/) and stored in `decode.o`. The [decode.asm](https://github.com/epakskape/greenshellcode/blob/master/decode.asm) includes [raw_payload_enc.asm](https://github.com/epakskape/greenshellcode/blob/master/raw_payload_enc.asm) from step 1.

3. The [enc.rb](https://github.com/epakskape/greenshellcode/blob/master/enc.rb) script is used to generate the 3 unique byte encoded version of `decode.o`. The encoded version is stored in [ecalc.asm](https://github.com/epakskape/greenshellcode/blob/master/ecalc.asm).

4. The encoded version in [ecalc.asm](https://github.com/epakskape/greenshellcode/blob/master/ecalc.asm) is then built and its byte values are converted into [payload.h](https://github.com/epakskape/greenshellcode/blob/master/payload.h).

The [payload.h](https://github.com/epakskape/greenshellcode/blob/master/payload.h) file is then included by [ecalc.c](https://github.com/epakskape/greenshellcode/blob/master/ecalc.c) which is used as a harness to execute the encoded payload.

# Build and run

From a Linux command shell:

```
sudo apt-get install nasm
make
```

From a Windows command shell:

```
cl /W4 ecalc.c /link /out:ecalc.exe
```

Then execute `ecalc.exe` from the command shell. You should see calc.exe execute.

# Is this actually useful?

Not really, but it was a fun challenge :) This encoder assumes that the stack is executable which is no longer the case on modern operating systems. It also assumes that it is possible to reliably find a portion of the stack that is zero initialized (e.g. not yet been used by the application) which may not work reliably in real-world cases.