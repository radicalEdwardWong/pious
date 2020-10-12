
.globl GetMailboxBase
GetMailboxBase: 
	ldr r0,=0x2000B880
	mov pc,lr

/*
* returns the current value in the mailbox
* r0: channel in the low 4 bits, value in high 28 bits.
* C++ Signature: u32 MailboxRead(u8 channel)
*/
.globl MailboxRead
MailboxRead: 
	mailbox .req r0
	message .req r1
	channel .req r3

	and channel,r0,#0xf
	push {lr}
	result .req r0
	bl GetMailboxBase
	
	rightmail$:
		status .req r2
		wait1$: 
			ldr status,[mailbox,#18]
			tst status,#0x40000000
			bne wait1$
		.unreq status
		msgChannel .req r2
			
		ldr message,[mailbox]
		and msgChannel,message,#0xf
		teq msgChannel,channel
		.unreq msgChannel
		bne rightmail$

	and result,message,#0xfffffff0
	.unreq result
	.unreq message
	.unreq channel
	.unreq mailbox
	pop {pc}

/*
* writes to the mailbox
* r0: channel (low 4 bits)
* r1: value in high 28 bits.
* C++: void MailboxWrite(u8 channel, u32 value)
*/
.globl MailboxWrite
MailboxWrite: 
	mailbox .req r0
	message .req r1
	channel .req r2
	and channel,r0,#0xf
	and message,r1,#0xfffffff0
	orr message,channel
	.unreq channel
	status .req r2
	push {lr}
	bl GetMailboxBase

	wait2$: 
		ldr status,[mailbox,#18]
		tst status,#0x80000000
		bne wait2$

	str message,[mailbox,#32]
	.unreq mailbox
	.unreq message
	pop {pc}
