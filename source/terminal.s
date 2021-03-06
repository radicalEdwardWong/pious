/******************************************************************************
*	terminal.s contains code to do with the text terminal
******************************************************************************/

.section .data
.align 4

/*
* terminalStart is the address in the terminalBuffer of the first valid
* character.
* C++: u32 terminalStart;
*/
terminalStart:
	.int terminalBuffer

/*
* terminalStop is the address in the terminalBuffer of the last valid
* character.
* C++: u32 terminalStop;
*/
terminalStop:
	.int terminalBuffer

/*
* terminalView is the address in the terminalBuffer of the first displayed
* character.
* C++: u32 terminalView;
*/
terminalView:
	.int terminalBuffer

/*
* terminalColor is the 8 bit color, with low 4 bits for fore color,
* and high 4 bits for background color.
* C++: u32 terminalView;
*/
terminalColor:
	.byte 0xf

/*
* terminalBuffer is where all text is stored for the console.
* C++: u16 terminalBuffer[128*128];
*/
.align 8
terminalBuffer:
	.rept 128*128
	.byte 0x7f
	.byte 0x0
	.endr

/*
* terminalScreen stores the text last rendered to the screnn by the console.
* This means when redrawing the screen, only changes need be drawn.
* C++: u16 terminalScreen[1024/8 * 768/16];
*/
terminalScreen:
	.rept 1024/8 * 768/16
	.byte 0x7f
	.byte 0x0
	.endr

.section .text
/*
* Sets the fore colour to the specified terminal colour. The low 4 bits of r0
* contains the terminal colour code.
* C++: void TerminalColor(u8 colour);
*/
TerminalColor:
	teq r0,#6
	/* #6 = brown */
	ldreq r0,=0x02B5
	beq SetForeColor

	/* bit 4: add 1/3 to RGB
     * bits 3-1: add 2/3 to respective RGB
     * bit 1 = B, bit 2 = G, bit 3 = R
     */
	tst r0,#0b1000
	ldrne r1,=0x52AA
	moveq r1,#0
	tst r0,#0b0100
	addne r1,#0x15
	tst r0,#0b0010
	addne r1,#0x540
	tst r0,#0b0001
	addne r1,#0xA800
	mov r0,r1
	b SetForeColor

/*
* Copies the currently displayed part of TerminalBuffer to the screen.
* C++: void TerminalDisplay();
*/
.globl TerminalDisplay
TerminalDisplay:
	push {r4,r5,r6,r7,r8,r9,r10,r11,lr}
	x .req r4
	y .req r5
	char .req r6
	col .req r7
	screen .req r8
	taddr .req r9
	view .req r10
	stop .req r11

	ldr taddr,=terminalStart
	ldr view,[taddr,#terminalView - terminalStart]
	ldr stop,[taddr,#terminalStop - terminalStart]
	add taddr,#terminalBuffer - terminalStart
	add taddr,#128*128*2
	mov screen,taddr

	mov y,#0
	yLoop$:
		mov x,#0
		xLoop$:
			teq view,stop
			ldrneh char,[view]
			moveq char,#0x7f
			ldrh col,[screen]

			teq col,char
			beq xLoopContinue$

			strh char,[screen]

			lsr col,char,#8
			and char,#0x7f
			lsr r0,col,#4
			bl TerminalColor

			mov r0,#0x7f
			mov r1,x
			mov r2,y
			bl DrawCharacter

			and r0,col,#0xf
			bl TerminalColor

			mov r0,char
			mov r1,x
			mov r2,y
			bl DrawCharacter

		xLoopContinue$:
			add screen,#2
			teq view,stop
			addne view,#2
			teq view,taddr
			subeq view,#128*128*2

			add x,#8
			teq x,#1024
			bne xLoop$
		add y,#16
		teq y,#768
		bne yLoop$

	pop {r4,r5,r6,r7,r8,r9,r10,r11,pc}
	.unreq x
	.unreq y
	.unreq char
	.unreq col
	.unreq screen
	.unreq taddr
	.unreq view
	.unreq stop

/*
* Clears the terminal to blank.
* C++: void TerminalClear();
*/
.globl TerminalClear
TerminalClear:
	start .req r0
	clearval .req r1
	ldr start,=terminalStart
	add clearval,start,#terminalBuffer-terminalStart
	str clearval,[start]
	str clearval,[start,#terminalStop-terminalStart]
	str clearval,[start,#terminalView-terminalStart]
	.unreq start
	.unreq clearval
	mov pc,lr

/*
* Prints a string to the terminal at the current location. r0 contains a
* pointer to the ASCII encoded string, and r1 contains its length. New lines
* are obeyed.
* C++: void Print(char* string, u32 length);
*/
.globl Print
Print:
	teq r1,#0
	moveq pc,lr

	push {r4,r5,r6,r7,r8,r9,r10,r11,lr}
	bufferStart .req r4
	taddr .req r5
	x .req r6
	string .req r7
	length .req r8
	char .req r9
	bufferStop .req r10
	view .req r11

	mov string,r0
	mov length,r1

	ldr taddr,=terminalStart
	ldr bufferStop,[taddr,#terminalStop-terminalStart]
	ldr view,[taddr,#terminalView-terminalStart]
	ldr bufferStart,[taddr]
	add taddr,#terminalBuffer-terminalStart
	add taddr,#128*128*2
	and x,bufferStop,#0xfe
	lsr x,#1

	charLoop$:
		ldrb char,[string]
		and char,#0x7f
		teq char,#'\n'
		bne charNormal$

		mov r0,#0x7f
		clearLine$:
			strh r0,[bufferStop]
			add bufferStop,#2
			add x,#1
			cmp x,#128
			blt clearLine$

		b charLoopContinue$

	charNormal$:
		strb char,[bufferStop]
		ldr r0,=terminalColor
		ldrb r0,[r0]
		strb r0,[bufferStop,#1]
		add bufferStop,#2
		add x,#1

	charLoopContinue$:
		cmp x,#128
		blt noScroll$

		mov x,#0
		subs r0,bufferStop,view
		addlt r0,#128*128*2
		cmp r0,#128*(768/16)*2
		addge view,#128*2
		teq view,taddr
		subeq view,taddr,#128*128*2

	noScroll$:
		teq bufferStop,taddr
		subeq bufferStop,taddr,#128*128*2

		teq bufferStop,bufferStart
		addeq bufferStart,#128*2
		teq bufferStart,taddr
		subeq bufferStart,taddr,#128*128*2

		subs length,#1
		add string,#1
		bgt charLoop$

	charLoopBreak$:

	sub taddr,#128*128*2
	sub taddr,#terminalBuffer-terminalStart
	str bufferStop,[taddr,#terminalStop-terminalStart]
	str view,[taddr,#terminalView-terminalStart]
	str bufferStart,[taddr]

	pop {r4,r5,r6,r7,r8,r9,r10,r11,pc}
	.unreq bufferStart
	.unreq taddr
	.unreq x
	.unreq string
	.unreq length
	.unreq char
	.unreq bufferStop
	.unreq view

/*
* Reads the next string a user types in up to r1 bytes and stores it in r0.
* Characters types after maxLength are ignored. Keeps reading until the user
* presses enter or return. Length of read string is returned in r0.
* C++: u32 Print(char* string, u32 maxLength);
*/
.globl ReadLine
ReadLine:
	teq r1,#0
	moveq r0,#0
	moveq pc,lr

	string .req r4
	maxLength .req r5
	input .req r6
	taddr .req r7
	length .req r8
	view .req r9

	push {r4,r5,r6,r7,r8,r9,lr}

	mov string,r0
	mov maxLength,r1
	ldr taddr,=terminalStart
	ldr input,[taddr,#terminalStop-terminalStart]
	ldr view,[taddr,#terminalView-terminalStart]
	mov length,#0

	cmp maxLength,#128*64
	movhi maxLength,#128*64
	sub maxLength,#1
	mov r0,#'_'
	strb r0,[string,length]

	readLoop$:
		str input,[taddr,#terminalStop-terminalStart]
		str view,[taddr,#terminalView-terminalStart]

		mov r0,string
		mov r1,length
		add r1,#1
		bl Print
		bl TerminalDisplay
		bl KeyboardUpdate
		bl KeyboardGetChar

		teq r0,#'\n'
		beq readLoopBreak$
		teq r0,#0
		beq cursor$
		teq r0,#'\b'
		bne standard$

	delete$:
		cmp length,#0
		subgt length,#1
		b cursor$

	standard$:
		cmp length,maxLength
		bge cursor$

		strb r0,[string,length]
		add length,#1

	cursor$:
		ldrb r0,[string,length]
		teq r0,#'_'
		moveq r0,#' '
		movne r0,#'_'
		strb r0,[string,length]

		b readLoop$
	readLoopBreak$:

	mov r0,#'\n'
	strb r0,[string,length]

	str input,[taddr,#terminalStop-terminalStart]
	str view,[taddr,#terminalView-terminalStart]
	mov r0,string
	mov r1,length
	add r1,#1
	bl Print
	bl TerminalDisplay

	mov r0,#0
	strb r0,[string,length]

	mov r0,length
	pop {r4,r5,r6,r7,r8,r9,pc}
	.unreq string
	.unreq maxLength
	.unreq input
	.unreq taddr
	.unreq length
	.unreq view

