/* 
* .align 12 = page width alignment.
* C++:
* struct FrameBuferDescription {
*  u32 width; u32 height; u32 vWidth; u32 vHeight; u32 pitch; u32 bitDepth;
*  u32 x; u32 y; void* pointer; u32 size;
* };
* FrameBuferDescription FrameBufferInfo =
*		{ 1024, 768, 1024, 768, 0, 24, 0, 0, 0, 0 };
*/
.section .data
.align 12 
.globl FrameBufferInfo 
FrameBufferInfo:
	.int 1024	/* #0 Physical Width */
	.int 768	/* #4 Physical Height */
	.int 1024	/* #8 virtual Width */
	.int 768	/* #12 Virtual Height */
	.int 0		/* #16 GPU - Pitch */
	.int 16		/* #16 Bit Depth */
	.int 0		/* #24 X */
	.int 0		/* #28 Y */
	.int 0		/* #32 GPU - Pointer */
	.int 0		/* #36 GPU - Size */

/* 
* InitializeFrameBuffer creates a frame buffer of specified width and height.
* This procedure blocks until a frame buffer can be created, and so is inapropriate
* on real time systems. While blocking, this procedure causes the OK LED to flash.
* If the frame buffer cannot be created, this procedure returns 0.
* r0: width
* r1: height
* r2: bit depth specified
* returns: FrameBuferDescription on success, or 0 on failure
* C++: FrameBuferDescription* InitializeFrameBuffer(u32 width,
*		u32 height, u32 bitDepth)
*/
.section .text
.globl InitializeFrameBuffer
InitializeFrameBuffer:
	width .req r0
	height .req r1
	bitDepth .req r2
	cmp width,#4096
	cmpls height,#4096
	cmpls bitDepth,#32
	result .req r0
	movhi result,#0
	movhi pc,lr

	push {r4,lr}			
	fbInfoAddr .req r4
	ldr fbInfoAddr,=FrameBufferInfo
	str width,[fbInfoAddr,#0]
	str height,[fbInfoAddr,#4]
	str width,[fbInfoAddr,#8]
	str height,[fbInfoAddr,#12]
	str bitDepth,[fbInfoAddr,#20]
	.unreq width
	.unreq height
	.unreq bitDepth

	channel .req r0
	fbRequest .req r1
	mov channel,#1
	/* set bit 31 to flush GPU cache */
	add fbRequest,fbInfoAddr,#0x40000000
	bl MailboxWrite

	mov channel,#1
	bl MailboxRead
	.unreq channel
		
	teq result,#0
	/* GPU response != 0 is failure */
	movne result,#0
	popne {r4,pc}

	mov result,fbInfoAddr
	pop {r4,pc}
	.unreq result
	.unreq fbInfoAddr
