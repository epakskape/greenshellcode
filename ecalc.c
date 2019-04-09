/*
 * This program executes the final version of the encoded payload.
 *
 * It ensures that the environment is set up per the original rules of the contest:
 *
 *   - The stack is executable.
 *   - The register state is zeroed.
 *
 */
#include <windows.h>
#include <stdio.h>
#include "payload.h" // defines buf

int main(int argc, char **argv)
{
	int counts[256] = { 0 };
	PUCHAR copy;
	int unique = 0;
	int x;

	UNREFERENCED_PARAMETER(argc);
	UNREFERENCED_PARAMETER(argv);

	//
	// Allocate an RWX buffer and copy the encoded payload into it.
	//

	copy = VirtualAlloc(NULL, sizeof(buf), MEM_COMMIT, PAGE_EXECUTE_READWRITE);

	if (copy == NULL)
	{
		wprintf(L"VirtualAlloc failed, %lu\n", GetLastError());
		return 0;
	}

	CopyMemory(copy, buf, sizeof(buf));

	//
	// Make the stack executable as the payload copies into the stack and assumes
	// it is executable, per the rules of the original challenge.
 	//

	PVOID StackBase = (PVOID) __readfsdword(0x4);
	PVOID StackLimit = (PVOID) __readfsdword(0x8);

	MEMORY_BASIC_INFORMATION mbi;
	if (!VirtualQuery(StackLimit, &mbi, sizeof(mbi)))
	{
		wprintf(L"VirtualQuery failed, %lu\n", GetLastError());
		return 0;
	}

	wprintf(L"StackBase=%p StackLimit=%p AllocationBase=%p\n",
		StackBase,
		StackLimit,
		mbi.AllocationBase);

	if (!VirtualAlloc(
		(PVOID) mbi.AllocationBase,
		(ULONG_PTR) StackBase - (ULONG_PTR) mbi.AllocationBase,
		MEM_COMMIT,
		PAGE_EXECUTE_READWRITE))
	{
		wprintf(L"VirtualProtect stack to RWX failed, %lu\n", GetLastError());
		return 0;
	}

	//
	// Count the number of distinct bytes.
	//

	for (x = 0; x < sizeof(buf); x++)
	{
		if (counts[copy[x]] == 0)
		{
			wprintf(L"byte %02x detected\n", copy[x]);
			unique++;
		}

		counts[copy[x]]++;
	}

	printf("%d unique bytes, %d bytes in length\n", unique, sizeof(buf));

	__asm
	{
		mov eax, 0
		mov ebx, 0
		mov ecx, 0
		mov edx, 0
		mov esi, 0
		mov edi, 0
		jmp copy
	}
}
