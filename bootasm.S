# When the PC starts, the processor is essentially emulating an 8086 processor, i.e. 
# a 16-bit processor.  So our initial boot loader code is 16-bit code that will 
# eventually switch the processor into 32-bit mode.

# This code is linked to assume a starting address of 0x7C00 which is where the BIOS
# will load a boot segment.

.code16                         # Assemble for 16-bit mode
.globl start
start:
    jmp     real_start

# Write to the console using BIOS.
# 
# Input: SI contains the address of the null-terminated string to be displayed

cons_write:
    movb    $0x0e, %ah           # 0x0e is the INT 10h BIOS call to output the value contained in AL to screen

cons_write_rpt:
    movb    (%si), %al          # Load the byte at the location contained in the SI register into AL   
    inc     %si                 # Add 1 to the value in SI
    cmp     $0, %al             # Compare the value in AL with 0
    jz      cons_write_done     # If it is zero, then we are done
    int     $0x10               # Output the character in AL to the screen
    jmp     cons_write_rpt      # and continue

cons_write_done:                # Something that is called will never return 
    ret                         # until a 'ret' instruction is encountered.  Labels do 
                                # not give a program any structure.  They just give a 
                                # memory location a name that we can use in our code. 

cons_write_crlf:
    movb    $0x0e, %ah          # Output CR
    movb    $0x0d, %al
    int     $0x10
    movb    $0x0a, %al          # Output LF
    int     $0x10
    ret

cons_writeline:
    call    cons_write
    call    cons_write_crlf
    ret    

real_start:
    cli                         # BIOS enabled interrupts; disable

    # Zero data segment registers DS, ES, and SS.
    xorw    %ax, %ax            # Set %ax to zero
    movw    %ax, %ds            # -> Data Segment
    movw    %ax, %es            # -> Extra Segment
    movw    %ax, %ss            # -> Stack Segment
    movw    $0, %sp             # Set the stack to the top of the segment

    movb    %dl, (boot_device) # Boot device number is passed in DL from BIOS. Save it hear since DL might get trashed

    movw    $boot_message, %si  # Display our boot message
    call    cons_writeline

	movb	$2, %ah				# BIOS function 13h, sub-function 2 is read sectors
	movb	$7, %al				# Number of sectors to read = 7
	movw	$0x9000, %bx		# The 7 sectors will be loaded into memory at ES:BX (0000:9000h)
	movb	$0, %ch				# Use cylinder 0
	movb 	$0, %dh 			# Use head 0
	movb	(boot_device), %dl  # Retrieve the ID of our boot device			
	movb 	$2, %cl				# Start reading at sector 2 (i.e. one after the boot sector)
	int 	$0x13
	cmpb	$7, %al				# AL returns the number of sectors read.  If this is not 7, report an error
	jne		read_failed

 	movb	(boot_device), %dl	# Pass boot device ID to second stage
    movw    $0x9000, %ax        # Jump to stage 2
    jmp     *%ax

read_failed:	                # Display error messages
	movw 	$read_failed_msg, %si
    call    cons_writeline
	
	mov 	$cannot_continue, %si	
    call    cons_writeline
	
endless_loop:                   # Loop forever more
    jmp     endless_loop    

# Program data

boot_device:
    .byte   0

boot_message:     
    .string "Boot Loader V1.0"             
read_failed_msg:
    .string "Unable to read stage 2 of the boot process"
cannot_continue:
    .string "Cannot continue boot process"

