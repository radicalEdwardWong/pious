
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
	pinFunMask .req r3
	mov pinFunMask,#7
	lsl pinFunMask,pinGroupOffset
	.unreq pinGroupOffset
	pinGroupFunctions .req r2
	ldr pinGroupFunctions,[gpioAddrOffset]

	/* first clear pin function bits, then apply new pin function */
	eor pinGroupFunctions,pinFunMask
	and pinGroupFunctions,pinFunctions
	
	str pinGroupFunctions,[r0]

	.unreq gpioAddrOffset
	.unreq pinFunctions
	.unreq pinGroupFunctions
	
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

