/******************************************************************************************
*	drawing.s contains code for drawing lines and pixels with color to the GPU framebuffer
******************************************************************************************/

/*
* The foreColour is the colour which all our methods will draw shapes in.
* C++: short foreColour;
*/
.section .data
.align 1
foreColour:
	.hword 0xFFFF

/*
* graphicsAddress stores the address of the frame buffer info structure. 
* C++: FrameBuferDescription* graphicsAddress;
*/
.align 2
graphicsAddress:
	.int 0

/* 
* Font stores the bitmap images for the first 128 characters.
*/
.align 4
font:
	.incbin "font.bin"

/*
k SetForeColor changes the current drawing colour to the 16 bit colour in r0.
* C++: void SetForeColor(u16 colour);
*/
.section .text
.globl SetForeColor
SetForeColor:
	cmp r0,#0x10000
	movhis pc,lr

	ldr r1,=foreColour
	strh r0,[r1]
	mov pc,lr


/*
* SetGraphicsAddress changes the current frame buffer information to 
* graphicsAddress;
* C++: void SetGraphicsAddress(FrameBuferDescription* value);
*/
.globl SetGraphicsAddress
SetGraphicsAddress:
	ldr r1,=graphicsAddress
	str r0,[r1]
	mov pc,lr
	
/*
* DrawPixel draws a single pixel to the screen at the point in (r0,r1).
* C: void DrawPixel(u32 x, u32 y);
*/
.globl DrawPixel
DrawPixel:
	px .req r0
	py .req r1

	fbInfoAddr .req r2
	ldr fbInfoAddr,=graphicsAddress
	ldr fbInfoAddr,[fbInfoAddr]

	height .req r3
	ldr height,[fbInfoAddr,#4]
	cmp py,height
	movhs pc,lr
	.unreq height

	width .req r3
	ldr width,[fbInfoAddr]
	cmp px,width
	movhs pc,lr

	framebuffer .req r2
	ldr framebuffer,[fbInfoAddr,#32]
	.unreq fbInfoAddr

	/* x-byte = (y * width) + x-pos */
	mla px,py,width,px
	.unreq width
	.unreq py
	/* 16-bit depth (hi-color) */
	add framebuffer, px,lsl #1
	.unreq px

	fore .req r3
	ldr fore,=foreColour
	ldrh fore,[fore]

	strh fore,[framebuffer]
	.unreq fore
	.unreq framebuffer
	mov pc,lr

/*
* DrawLine draws a line between two points given in (r0,r1) and (r2,r3).
* Uses Bresenham's Line Algortihm
* C++: void DrawLine(u32x2 p1, u32x2 p2);
*/
.globl DrawLine
DrawLine:
	push {r4,r5,r6,r7,r8,r9,r10,r11,r12,lr}
	x0 .req r9
	x1 .req r10
	y0 .req r11
	y1 .req r12

	mov x0,r0
	mov x1,r2
	mov y0,r1
	mov y1,r3

	dx .req r4
	dyn .req r5 /* Note that we only ever use -deltay, so I store its negative for speed. (hence dyn) */
	sx .req r6
	sy .req r7
	err .req r8

	cmp x0,x1
	subgt dx,x0,x1
	movgt sx,#-1
	suble dx,x1,x0
	movle sx,#1

	cmp y0,y1
	subgt dyn,y1,y0
	movgt sy,#-1
	suble dyn,y0,y1
	movle sy,#1

	add err,dx,dyn
	add x1,sx
	add y1,sy

	pixelLoop$:
		teq x0,x1
		teqne y0,y1
		popeq {r4,r5,r6,r7,r8,r9,r10,r11,r12,pc}

		mov r0,x0
		mov r1,y0
		bl DrawPixel

		cmp dyn, err,lsl #1
		addle err,dyn
		addle x0,sx

		cmp dx, err,lsl #1
		addge err,dx
		addge y0,sy

		b pixelLoop$

	.unreq x0
	.unreq x1
	.unreq y0
	.unreq y1
	.unreq dx
	.unreq dyn
	.unreq sx
	.unreq sy
	.unreq err

/* 
* DrawCharacter renders the image for a single character given in r0 to the
* screen, with to left corner given by (r1,r2), and returns the width of the 
* printed character in r0, and the height in r1.
* C++: u32x2 DrawCharacter(char character, u32 x, u32 y);
*/
.globl DrawCharacter
DrawCharacter:
	x .req r4
	y .req r5
	charAddr .req r6

	/* if char > 127 return: width = 0, height = 0 */
	cmp r0,#0x7F
	movhi r0,#0
	movhi r1,#0
	movhi pc,lr

	mov x,r1
	mov y,r2

	push {r4,r5,r6,r7,r8,lr}
	ldr charAddr,=font
	/* char address = font + (char * 16) */
	add charAddr, r0,lsl #4
	
	lineLoop$:
		bits .req r7
		bit .req r8
		ldrb bits,[charAddr]
		mov bit,#8

		charPixelLoop$:
			subs bit,#1
			blt charPixelLoopEnd$
			lsl bits,#1
			tst bits,#0x100
			beq charPixelLoop$

			add r0,x,bit
			mov r1,y
			bl DrawPixel

			b charPixelLoop$
		charPixelLoopEnd$:

		.unreq bit
		.unreq bits
		add y,#1
		add charAddr,#1
		tst charAddr,#0b1111
		bne lineLoop$

	.unreq x
	.unreq y
	.unreq charAddr

	width .req r0
	height .req r1
	mov width,#8
	mov height,#16

	pop {r4,r5,r6,r7,r8,pc}
	.unreq width
	.unreq height


/* 
* DrawString renders the image for a string of characters given in r0 (length
* in r1) to the screen, with the left corner given by (r2,r3). Obeys new line
* and horizontal tab characters.
* r0: string of characters
* r1: length of string
* r2: x position of top-left corner
* r3: y position of top-left corner
* C++: void DrawString(char* string, u32 length, u32 x, u32 y);
*/
.globl DrawString
DrawString:
	x .req r4
	y .req r5
	x0 .req r6
	string .req r7
	length .req r8
	char .req r9
	
	push {r4,r5,r6,r7,r8,r9,lr}

	mov string,r0
	mov length,r1
	mov x,r2
	mov y,r3
	mov x0,x

	stringLoop$:
		subs length,#1
		blt stringLoopEnd$

		ldrb char,[string]
		add string,#1

		mov r0,char
		mov r1,x
		mov r2,y
		bl DrawCharacter
		cwidth .req r0
		cheight .req r1

		teq char,#'\n'
		/* newline condition: */
		moveq x,x0
		addeq y,cheight
		beq stringLoop$

		teq char,#'\t'
		/* char is not a newline or tab;
		 * so increment x by char width */
		addne x,cwidth
		bne stringLoop$

		/* tab condition: 
		 * tabwidth = 4 chars */
		lsl cwidth,#2
		x1 .req r1
		mov x1,x0
		
		stringLoopTab$:
			add x1,cwidth
			cmp x,x1
			bge stringLoopTab$
		mov x,x1
		.unreq x1	
		b stringLoop$
	stringLoopEnd$:
	.unreq cwidth
	.unreq cheight

	pop {r4,r5,r6,r7,r8,r9,pc}
	.unreq x
	.unreq y
	.unreq x0
	.unreq string
	.unreq length

/*
* DrawLongString renders the image for a string of characters given in r0 to the screen,
* with the left corner given by (r2,r3). Obeys new line and horizontal tab characters.
* It will continue until a null character is found, at which point it will return the
* final length of the rendered string, excluding the null terminating character.
* Warning: this function will behave unexpectedly for non-null terminated strings.
* r0: string of characters, followed by a null character
* r1: x position of top-left corner
* r2: y position of top-left corner
* returns: length of string minus the null character
* C++: u32 DrawString(char* string, u32 x, u32 y);
*/
.globl DrawLongString
DrawLongString:
	x .req r4
	y .req r5
	x0 .req r6
	string .req r7
	char .req r8
	length .req r9

	push {r4,r5,r6,r7,r8,r9,lr}

	mov string,r0
	mov x,r1
	mov y,r2
	mov x0,x
	mov length,#0

	longStringLoop$:
		ldrb char,[string]

		/* end of string: */
		teq char,#'\0'
		moveq r0,length
		beq longStringLoopEnd$

		/* end not reached, increment string pointer: */
		add length,#1
		add string,#1

		mov r0,char
		mov r1,x
		mov r2,y
		bl DrawCharacter
		cwidth .req r0
		cheight .req r1

		teq char,#'\n'
		/* newline condition: */
		moveq x,x0
		addeq y,cheight
		beq longStringLoop$

		teq char,#'\t'
		/* char is not a newline or tab;
		 * so increment x by char width */
		addne x,cwidth
		bne longStringLoop$

		/* tab condition:
		 * tabwidth = 4 chars */
		lsl cwidth,#2
		x1 .req r1
		mov x1,x0

		longStringLoopTab$:
			add x1,cwidth
			cmp x,x1
			bge longStringLoopTab$
		mov x,x1
		.unreq x1
		b longStringLoop$
	longStringLoopEnd$:
	.unreq cwidth
	.unreq cheight

	pop {r4,r5,r6,r7,r8,r9,pc}
	.unreq x
	.unreq y
	.unreq x0
	.unreq string
	.unreq length

