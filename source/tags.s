/******************************************************************************
*	tags.s contains code to do with reading the ARM Linux boot tags.
******************************************************************************/

/* 
* The following values are the addresses of all tags detected, with 0
* representing an undetected tag.
*/
.align 2
.section .data
TagAddressLookup:
tag_core: .int 0
tag_mem: .int 0
tag_videotext: .int 0
tag_ramdisk: .int 0
tag_initrd2: .int 0
tag_serial: .int 0
tag_revision: .int 0
tag_videolfb: .int 0
tag_cmdline: .int 0

.align 2
.section .text

.globl GetTagAddress
GetTagAddress:
	mov r0,#0x100
	mov pc,lr

/*
* FindTag finds the address of all the tags if necessary, and returns the
* address of the tag who's number is given in r0.
* C++: void* FindTag(u16 tagNumber)
*/
.globl FindTag
FindTag:
	tag .req r0
	tagLookup .req r1
	tagAddr .req r2
	push {lr}
	sub tag,#1
	cmp tag,#8
	/* validate that: 0 < tag <= 9 */
	movhi r0,#0
	pophi {pc}

	ldr tagLookup,=TagAddressLookup
	tagReturn$:
		/* get tag address from tag list */
		add tagAddr,tagLookup, tag,lsl #2
		ldr tagAddr,[tagAddr]

		/* return tag address if we have it */
		teq tagAddr,#0
		movne r0,tagAddr
		popne {pc}

		/* check if tag list was loaded */
		ldr tagAddr,[tagLookup]
		teq tagAddr,#0
		/* tag not found, return 0 */
		movne r0,#0
		popne {pc}

		/* tag list not loaded...so begin searching for
		 * tag while populating the list along the way */
		mov tagAddr,#0x100
		push {r4}
		tagIndex .req r3
		oldAddr .req r4
	tagLoop$:
		/* get tag index from 1st half-word of 2nd word in tag block */
		ldrh tagIndex,[tagAddr,#4]
		subs tagIndex,#1
		/* if tagIndex = 0, we're at the end of the tags, return */
		poplt {r4}
		blt tagReturn$

		/* check if already have address for this tag index, and save it if not */
		savedTagAddr .req r3
		add savedTagAddr,tagLookup, tagIndex,lsl #2
		ldr oldAddr,[savedTagAddr]
		teq oldAddr,#0
		.unreq oldAddr
		streq tagAddr,[savedTagAddr]
		.unreq savedTagAddr

		tagWordSize .req r3
		ldr tagWordSize,[tagAddr]
		/* advance tag address forward the size of the current tag, and continue search */
		add tagAddr, tagWordSize,lsl #2
		b tagLoop$

    .unreq tagLookup
    .unreq tagAddr
    .unreq tagIndex

