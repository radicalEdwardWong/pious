
.globl GetSystemTimerBase
GetSystemTimerBase: 
	ldr r0,=0x20003000
	mov pc,lr

.globl GetTimeStamp
GetTimeStamp:
	push {lr}
	bl GetSystemTimerBase
	ldrd r0,r1,[r0,#4]
	pop {pc}

/*
* Wait busywaits a specified number of microseconds before returning.
* r0: The duration to wait
* C++: void Wait(u32 delayInMicroSeconds)
*/
.globl Wait
Wait:
	delay .req r2
	mov delay,r0	
	push {lr}
	bl GetTimeStamp
	start .req r3
	mov start,r0

	loop$:
		bl GetTimeStamp
		elapsed .req r1
		sub elapsed,r0,start
		cmp delay,elapsed
		.unreq elapsed
		bhi loop$
		
	.unreq delay
	.unreq start
	pop {pc}
