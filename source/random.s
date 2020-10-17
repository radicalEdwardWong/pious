/*
* Random is a function with an input of the last number it generated, and an 
* output of the next number in a pseduo random number sequence.
* C++: u32 Random(u32 lastValue);
*/
.globl Random
Random:
	ret .req r0
	xnm .req r0
	a .req r1
	
	mov a,#0xef00
	mul a,xnm
	mla a,a,xnm,xnm
	.unreq xnm
	add ret,a,#73
	
	.unreq a
	.unreq ret
	mov pc,lr
