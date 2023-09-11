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
    cli                              # BIOS enabled interrupts; disable

    # Zero data segment registers DS, ES, and SS.
    xorw    %ax, %ax                 # Set %ax to zero
    movw    %ax, %ds                 # -> Data Segment
    movw    %ax, %es                 # -> Extra Segment
    movw    %ax, %ss                 # -> Stack Segment
    movw    $0, %sp                  # Set the stack to the top of the segment

    movb    %dl, (boot_device) # Boot device number is passed in DL from BIOS. Save it here since DL might get trashed

    movw    $boot_message, %si       # Display our boot message
    call    cons_writeline

    movw    $disk_address_packet, %si # Move address of the disk address packet into SI
    movw    $7, 2(%si)                # Set the number of blocks to read to be 7
    movw    $0x9000, 4(%si)           # Set the adddress to read into to be 0x9000
    movw    $1, 8(%si)                # Set the first block to read to be block 1
    movb    $0x42, %ah                # 0x42 is the int 13h BIOS function to read the disk using LBA addressing
	movb	(boot_device), %dl        # Retrieve the ID of our boot device and put in DL	
    int     $0x13                     # Read the disk
    jc      read_failed	              # The carry flag will be set if an error occured

    movb    (0x9000), %al             # Check that what we loaded is not empty
    cmpb    $0, %al
    je      read_failed

	movb	(boot_device), %dl	      # Pass boot device ID to second stage
    movw    $0x9000, %ax              # Jump to stage 2
    jmp     *%ax

read_failed:	                      # Display error messages
	movw 	$read_failed_msg, %si
    call    cons_writeline
	
	mov 	$cannot_continue, %si	
    call    cons_writeline
	
endless_loop:                         # Loop forever more
    jmp     endless_loop    

# Program data

boot_device:
    .byte   0

# Format of disk address packet
#
# Offset	Size	Description
#  0          1     size of packet (16 bytes)
#  1          1     always 0
#  2          2     number of sectors to transfer (max 127 on some BIOSes)
#  4          4     transfer buffer (first 2 bytes is 16-bit offset, next 2 bytes is 16 bit segment)
#  8          4     lower 32-bits of 48-bit starting LBA (starting from 0)
#  12         4     upper 16-bits of 48-bit starting LBA (will always be 0 for us)

disk_address_packet:
    .byte   0x10
    .byte   0
    .word   0
    .long   0
    .long   0
    .long   0

boot_message:     
    .string "Boot Loader V1.0"             
read_failed_msg:
    .string "Unable to read stage 2 of the boot process"
cannot_continue:
    .string "Cannot continue boot process"

