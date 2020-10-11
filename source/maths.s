
.globl DivideU32
DivideU32:

result .req r0
remainder .req r1
shift .req r2
multiple .req r3

dividend .req r0
divisor .req r1
dividendLeadZeros .req r3
clz shift,divisor
clz dividendLeadZeros,dividend
subs shift,dividendLeadZeros
.unreq dividendLeadZeros
lsl multiple,divisor,shift
mov remainder,dividend
mov result,#0
.unreq dividend
.unreq divisor
blt divideU32Return$

divideU32Loop$:
	cmp remainder,multiple
	blt divideU32LoopContinue$

	add result,result,#1
	subs remainder,multiple
	lsleq result,shift
	beq divideU32Return$
divideU32LoopContinue$:
	subs shift,#1
	lsrge multiple,#1
	lslge result,#1
	bge divideU32Loop$

divideU32Return$:
.unreq result
.unreq remainder
.unreq shift
.unreq multiple
mov pc, lr

