/******************************************************************************
*	gpio.s contains code for interacting gpio pins
******************************************************************************/

.globl GetGpioAddress
GetGpioAddress:
	ldr r0,=0x20200000
	mov pc,lr


.globl SetGpioFunction
SetGpioFunction:
	/* validate arguments:
		if (r0 > 53 || r1 > 7) return; */
	cmp r0,#53
	cmpls r1,#7
	movhi pc,lr
	
	gpioAddrOffset .req r0
	pinFunctions .req r1
	pinGroupOffset .req r2

	push {lr}
	mov pinGroupOffset,r0
	bl GetGpioAddress
	
	functionLoop$:
	cmp pinGroupOffset,#9
	subhi pinGroupOffset,#10
	addhi gpioAddrOffset,#4
	bhi functionLoop$
	
	/* r0 = gpio addr offet = 4 x (pin# / 10)
	   r2 = pin# % 10 */
	
	add pinGroupOffset,pinGroupOffset,lsl #1
	lsl pinFunctions,pinGroupOffset
	
	/* r1 = (pin# % 10) x 3 */

	/* preserve settings in this pin group */
	mask .req r3
	mov mask,#7					/* r3 = 111 in binary */
	lsl mask,pinGroupOffset				/* r3 = 11100..00 where the 111 is in the same position as the function in r1 */

	mvn mask,mask				/* r3 = 11..1100011..11 where the 000 is in the same poisiont as the function in r1 */
	oldFunc .req r2
	ldr oldFunc,[gpioAddrOffset]		/* r2 = existing code */
	and oldFunc,mask			/* r2 = existing code with bits for this pin all 0 */
	.unreq mask

	orr pinFunctions,oldFunc			/* r1 = existing code with correct bits set */
	.unreq oldFunc

	str pinFunctions,[r0]
	.unreq gpioAddrOffset
	.unreq pinFunctions
	
	pop {pc}


.globl SetGpio
SetGpio:
	pinNum .req r0
	pinVal .req r1
	
	cmp pinNum,#53
	movhi pc,lr
	push {lr}
	mov r2,pinNum
	.unreq pinNum
	pinNum .req r2
	bl GetGpioAddress
	gpioAddr .req r0
	
	pinBank .req r3
	lsr pinBank,pinNum,#5
	lsl pinBank,#2
	add gpioAddr,pinBank
	.unreq pinBank
	.unreq pinNum

	/* gpioAddr = 0x20200000 if pin# = 0-31
				  0x20200004 if pin# = 32-53 */
	
	pinNumOffset .req r2
	and pinNumOffset,#0b11111
	setBit .req r3
	mov setBit,#1
	lsl setBit,pinNumOffset
	.unreq pinNumOffset
	
	teq pinVal,#0
	.unreq pinVal
	streq setBit,[gpioAddr,#40]
	strne setBit,[gpioAddr,#28]
	.unreq setBit
	.unreq gpioAddr
	pop {pc}


.globl BlinkLed
BlinkLed:
	push {lr}

	mov r0,#16
	mov r1,#1
	bl SetGpioFunction

	mov r0,#16
	mov r1,#0
	bl SetGpio

	mov r0,#1
	lsl r0,#19
	add r0,r0
	bl Wait

	mov r0,#16
	mov r1,#1
	bl SetGpio

	mov r0,#1
	lsl r0,#19
	add r0,r0
	bl Wait

	pop {pc}
