include gd32vf103.asm
RAM = 0x20000000
MEM_SIZE = 0x8000
STACK = 0x20008000
seqWaddress = 0x20
seqRaddress = 0x21
randomWaddress = 0x22
randomRaddress = 0x23
RDAinit_length = 12
fclk = 8000000
OLEDaddress = 0x78
command = 0x00
data_cmd = 0x40
OLED_INIT_LEN = 15    
font_length = 16

# a0 is used to transmit data i I2C
# channel = (<desired freq in MHz> - 87.0) / 0.1 
#     * which is the same as:
#     * <10 x desired freq in MHz> - 870

buffer  = 0x20000008
buffer1 = 0x2000000C
buffer2 = 0x20000010
buffer3 = 0x20000014
tthousand = 0x20000018
thousand = 0x2000001C
hundred = 0x20000020
ten = 0x20000024
point = 0x20000028
one = 0x2000002C
#push:
#addi sp,sp,-4
#sw ra,0(sp)

#pop:
#lw ra,0(sp)
#addi sp,sp,4

#==============================================
sp_init:
    li sp, STACK			# initialize stack pointer
        
#==============================================    
#I2C0_SCL = PB6				# I2C0  clock on pb6 (reccomended external pullup 4.7k)
#I2C0_SDA = PB7				# I2C0  data on pb7  (reccomended external pullup 4.7k)
#=================================================

I2C_INIT:

#Enable portA and portb clocks
        
    #RCU->APB2EN |= RCU_APB2EN_PAEN | RCU_APB2EN_PBEN;
    	li s0, RCU_BASE_ADDR
    	lw a5, RCU_APB2EN_OFFSET(s0)
    	ori a5, a5, ( (1<<RCU_APB2EN_PAEN_BIT) | (1<<RCU_APB2EN_PBEN_BIT))
    	sw a5, RCU_APB2EN_OFFSET(s0)

#Enable alternate function clock in APB2 register
    
    #RCU->APB2EN |= RCU_APB2EN_AFEN ;
    	lw a4, RCU_APB2EN_OFFSET(s0)
    	li a5, (1<<RCU_APB2EN_AFEN_BIT) 
    	or a4, a4, a5
    	sw a4, RCU_APB2EN_OFFSET(s0)

#Enable I2C0 periphral clock in APB1 register
    
    #RCU->APB1EN |=  RCU_APB1EN_I2C0EN;
    	lw a4, RCU_APB1EN_OFFSET(s0)
    	li a5, (1<<21)        						#(1<<RCU_APB1EN_I2C0EN_BIT)   #(1<<21)
    	or a4, a4, a5
    	sw a4, RCU_APB1EN_OFFSET(s0) 
  
#enable PA1 & PA2 for debugging with led
#	li a0,GPIO_BASE_ADDR_A						# for debugging with led
#	li a1,((GPIO_MODE_PP_50MHZ << 4 | GPIO_MODE_PP_50MHZ << 8)) 	# 
#	sw a1,GPIO_CTL0_OFFSET(a0)
#	li a1,(1 << 2 | 1 << 1)						# 
#	sw a1,GPIO_BOP_OFFSET(a0) 

#enable PA0,PA3-PA8 for button press & PA1,PA2 for LED
	li a0,GPIO_BASE_ADDR_A				
	li a1,( GPIO_MODE_IN_PULLUP << 24 | GPIO_MODE_IN_PULLUP << 20 | GPIO_MODE_IN_PULLUP << 16 | GPIO_MODE_IN_PULLUP << 12 | GPIO_MODE_PP_50MHZ << 4 | GPIO_MODE_PP_50MHZ << 8 )  
	sw a1,GPIO_CTL1_OFFSET(a0)
	li a1,(1 << 2 | 1 << 1)						# 
	sw a1,GPIO_BOP_OFFSET(a0)



    
# GPIOB PB7 & PB6 configuring as  AF open drain	
    	li s2, GPIO_BASE_ADDR_B
    	li a1,((1 << 7) | (1 << 6))
    	sw a1,GPIO_BOP_OFFSET(s2)			
    	li a1, ((GPIO_MODE_AF_OD_50MHZ << 28) | (GPIO_MODE_AF_OD_50MHZ << 24))
    	sw a1, GPIO_CTL0_OFFSET(s2)
    

#I2C0 configuration  
    	li a5, I2C0_BASE_ADDRESS
    	lw a3, I2C_CTL0_OFFSET(a5)
    	li a2,(1<<SRESET)		# reset I2C
    	or a3,a3, a2
    	sw a3, I2C_CTL0_OFFSET(a5)
    	not a2,a2
    	and a3,a3,a2			# set I2C to normal
    	sw a3, I2C_CTL0_OFFSET(a5)  
    	li a5, I2C0_BASE_ADDRESS
    	lw a3, I2C_CTL1_OFFSET(a5)
    	ori a3,a3,(8<<0)		# input clock PCLK1 = 8mhz
    	sw a3, I2C_CTL1_OFFSET(a5)
    	lw a3, I2C_CKCFG_OFFSET(a5)
    	ori a3,a3,(40<<0)		#CCLK = 4000ns + 1000ns/ (1/8000000) =40  CCLK = Trise(SCL) + Twidth(SCL)/ Tpclk1
    	sw a3, I2C_CKCFG_OFFSET(a5) 
    	lw a3, I2C_RT_OFFSET(a5)
    	ori a3,a3,(9<<0)		#TRISE = ((1000ns/125ns)+1) = 9  TRISE = ((Tr(SCL)/Tpclk1) + 1)
    	sw a3, I2C_RT_OFFSET(a5)
    	lw a3, I2C_CTL0_OFFSET(a5)
    	ori a3,a3,(1<<I2CEN)		#enable I2C
    	sw a3, I2C_CTL0_OFFSET(a5)
    	lw a3, I2C_CTL0_OFFSET(a5)
    	ori a3,a3, (1<<ACKEN)	
    	sw a3, I2C_CTL0_OFFSET(a5)

		
	
main_loop:
	li a2,point		# sram address point is loaded in a2
	li t1,'.'		# load ASCII period in t1
	sb t1,0(a2)		# store period in sram register "period"pointed by a2

	call I2C_BUSY		# check weather I2C is busy ,wait till free
	call I2C_START		# send start condition on I2C bus
	li a0,OLEDaddress
	call SEND_ADDRESS	# call subroutine to send address
	li a0, command	        # load register a0 with slave address (write), data to be sent is loaded in a0
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
	li t0,OLED_INIT_BYTES	# load address of O_LED init values
	li t1,OLED_INIT_LEN	# load number of init bytes in the array
initloop0:
	lbu  t4,0(t0)		# lsb loaded in t4 , t0 has the array address and used as pointer
	addi t0,t0,1		# increase pointer 1 byte
	lbu t5,0(t0)		# msb loaded in t5
	addi t0,t0,1		# increase pointer 1 byte
	mv a0,t5		# move value in t5 to a0,msb
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
	addi t1,t1,-1		# decrease message/array counter
	beqz t1,loopexit0	# if init length becomes 0 exit loop by jumping to label "loopexit0"
	mv a0,t4		# move value in t4 to a0,lsb
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
	addi t1,t1,-1		# decrease message/array counter
	bnez t1,initloop0	# loop till t1 is 0 , all bytes will be transmitted when 0
loopexit0:
	call I2C_TX_COMPLETE	# call subroutine that checks all transmission is completed
	call I2C_STOP		# call subroutine to terminate I2C operation
	call delay250		# approx 1 second delay


	

	call I2C_BUSY		# check weather I2C is busy ,wait till free
	call I2C_START		# send start condition on I2C bus
	li a0,seqWaddress	# RDA sequential write address
	call SEND_ADDRESS	# call subroutine to send address
	li t0,init_RDA  	# address of array containing RDA5807 radio initialize value array
	li t1,RDAinit_length	# number of bytes/words
initloop1:
	lb t4,0(t0)		# lsb loaded in t4 , t0 has the array address and used as pointer
	addi t0,t0,1		# increase pointer 1 byte
	lb t5,0(t0)		# msb loaded in t5
	addi t0,t0,1		# increase pointer 1 byte
	mv a0,t5		# move value in t5 to a0
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
	addi t1,t1,-1		# decrease message/array counter
	beqz t1,loopexit1	# if init length becomes 0 exit loop by jumping to label "loopexit0"
	mv a0,t4		# move value in t4 to a0
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
	addi t1,t1,-1		# decrease message/array counter
	bnez t1,initloop1	# loop till t1 is 0 , all bytes will be transmitted when 0
loopexit1:
	call I2C_TX_COMPLETE	# call subroutine that checks all transmission is completed
	call I2C_STOP		# call subroutine to terminate I2C operation
	call delay250		# approx 1 second delay

	
	call I2C_BUSY		# check weather I2C is busy ,wait till free
	call I2C_START		# send start condition on I2C bus
	li a0,randomWaddress	# RDA sequential write address
	call SEND_ADDRESS	# call subroutine to send address
	li a0,0x02		# RDA5807 register 0x02
	call I2C_WRITE
	li a0,0xC1		# load high byte of 0x02 RDA5807 register in  data register
	call I2C_WRITE
	li a0,0x01		# (enable radio) load low byte of 0x02 RDA5807 register in  data register
	call I2C_WRITE
	call I2C_TX_COMPLETE	# call subroutine that checks all transmission is completed
	call I2C_STOP		# call subroutine to terminate I2C operation


	call I2C_BUSY		# check weather I2C is busy ,wait till free
	call I2C_START		# send start condition on I2C bus
	li a0,randomWaddress	# RDA sequential write address
	call SEND_ADDRESS	# call subroutine to send address
	li a0,0x03		# set pointer to RDA5807 0x03 register , chanel/freuency value is written there
	call I2C_WRITE
	li a0,0x2B		# set channel to 87Mhz = 0 ,0-20 = 87Mhz to 108 MHZ
	call I2C_WRITE
	li a0,0x10		# set tune bit in same register
	call I2C_WRITE
	call I2C_TX_COMPLETE	# call subroutine that checks all transmission is completed
	call I2C_STOP		# call subroutine to terminate I2C operation
	
	call delay		# 1 second delay
	call delay		# 1 second delay
	call delay		# 1 second delay
	call delay		# 1 second delay
	call delay		# 1 second delay
		
	call clear_OLED		# clear OLED screen
	call tune_up		# doing this initialiases the radio
	call tune_dn		# tune back to correct station by reducing 100Khz
	

here:
	
	
c1:
	li a4,GPIO_BASE_ADDR_A			# load a4 with PortA base address
	lw a3,GPIO_ISTAT_OFFSET(a4)		# load a3 with contents of portA Istatus
	andi a3,a3,0x00000008			# and with 0x08 to isolate PA4 status
	beqz a3,tuneup				# if 0 branch to label tuneup
c2:
	li a4,GPIO_BASE_ADDR_A			# load a4 with PortA base address
	lw a3,GPIO_ISTAT_OFFSET(a4)		# load a3 with contents of portA Istatus
	andi a3,a3,0x00000010			# and with 0x08 to isolate PA5 status
	beqz a3,tunedn				# if 0 branch to label tunedn
c3:
	li a4,GPIO_BASE_ADDR_A			# load a4 with PortA base address
	lw a3,GPIO_ISTAT_OFFSET(a4)		# load a3 with contents of portA Istatus
	andi a3,a3,0x00000020			# and with 0x08 to isolate PA6 status
	beqz a3,seekup				# if 0 branch to label seekup
c4:
	li a4,GPIO_BASE_ADDR_A			# load a4 with PortA base address
	lw a3,GPIO_ISTAT_OFFSET(a4)		# load a3 with contents of portA Istatus
	andi a3,a3,0x00000040			# and with 0x08 to isolate PA7 status
	beqz a3,seekdn				# if 0 branch to label seekdn
c5:
	
	j here


tuneup:
	call tune_up
	j c1
tunedn:
	call tune_dn
	j c2
seekup:
	call seek_up
	j c3
seekdn:
	call seek_dn
	j c4







####----I2C--FUNCTIONS-----------------------------------------------------------------------------

I2C_START:

	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_CTL0_OFFSET(a5)
    	ori a3,a3, (1<<ACKEN) | (1<<START)	
    	sw a3, I2C_CTL0_OFFSET(a5)
	ret

I2C_WRITE:
	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_STAT0_OFFSET(a5)
	andi a3,a3,(1<<TBE)
	beqz a3, I2C_WRITE
	sw a0, I2C_DATA_OFFSET(a5)		# data to be loaded in a0
W1:
	lw a3, I2C_STAT0_OFFSET(a5)
	andi a3,a3,(1<<BTC)
	beqz a3, W1
	ret

SEND_ADDRESS:
	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_STAT0_OFFSET(a5)
	andi a3,a3,(1<<SBSEND)
	beqz a3, SEND_ADDRESS
A1:
	sw a0, I2C_DATA_OFFSET(a5)
A2:
	lw a3, I2C_STAT0_OFFSET(a5)
	andi a3,a3,(1<<ADDSEND)
	beqz a3, A2
CLEAR_ADDSEND:
	lw a3, I2C_STAT0_OFFSET(a5)
	lw a3, I2C_STAT1_OFFSET(a5)
	ret

CLEAR_ACKEN:
	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_CTL0_OFFSET(a5)
	andi a3,a3,~(1<<ACKEN)
	sw a3, I2C_CTL0_OFFSET(a5)
	ret

I2C_TX_COMPLETE:
	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_STAT0_OFFSET(a5)
	andi a3,a3,(1<<TBE)
	beqz a3, I2C_TX_COMPLETE
	ret

I2C_STOP:
	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_CTL0_OFFSET(a5)
	ori a3,a3,(1<<STOP)
	sw a3, I2C_CTL0_OFFSET(a5)
	ret

I2C_READ:  				#(single byte)
	li a2,buffer
	call SEND_ADDRESS     		#(slave address + read)
	call CLEAR_ACKEN
	call CLEAR_ADDSEND
	call I2C_STOP
R1:
	lw a3, I2C_STAT0_OFFSET(a5)
	andi a3,a3,(1<<RBNE)
	beqz a3,R1
	lw a0, I2C_DATA_OFFSET(a5) 	# read data byte from I2C data register
	sw a0, 0(a2)		 	# store byte in a0 to memory location buffer
	ret	
I2C_BUSY:
	li a5, I2C0_BASE_ADDRESS
	lw a3, I2C_STAT1_OFFSET(a5)
	andi a3,a3, (1<<1) 		# 1<<I2CBUSY
	bnez a3,I2C_BUSY
	ret

#=================================================
I2C_READ_TWO:
#	li a2,buffer			# address of location buffer in SRAM
	addi sp,sp,-4			# PUSH
	sw ra,0(sp)
	call SEND_ADDRESS     		# (slave address + read)
BYTES2:
	lw a3, I2C_STAT0_OFFSET(a5)
	andi a3,a3,(1<<RBNE)
	beqz a3,BYTES2
	addi a2,a2,1			# increase buffer address + 1 to store incoming hi byte in litte endian order in buffer
	lw a0, I2C_DATA_OFFSET(a5) 	# read data byte from I2C data register
	sb a0, 0(a2)			# store byte in a0 to memory location buffer
	addi a2,a2,-1			# increase buffer address + 1
	call CLEAR_ACKEN
	call I2C_STOP
BYTES1:
	lw a3, I2C_STAT0_OFFSET(a5)
	andi a3,a3,(1<<RBNE)
	beqz a3,BYTES1
	lw a0, I2C_DATA_OFFSET(a5) 	# read data byte from I2C data register
	sb a0, 0(a2)			# store byte in a0 to memory location buffer
	lw ra,0(sp)			# POP
	addi sp,sp,4
	ret

#==========================================
delay:					# delay routine
	addi sp,sp,-4
	sw t1,0(sp)			# PUSH t1
	li t1,2677376			# t1 register has	2,677,376 for 999.999 ms or 1 sec	
loop:
	addi t1,t1,-1			# subtract 1 from t1
	bne t1,zero,loop		# if t1 not equal to 0 branch to label loop
	sw t1,0(sp)			# POP t1
	addi sp,sp,4
	ret	
#-----------------------------------------------
#delay50:
#	addi sp,sp,-4
#	sw t1,0(sp)			# PUSH t1
#	li t1,133869			# 2677376/20 t1 register for 50ms		
#loop1a:
#	addi t1,t1,-1			# subtract 1 from t1
#	bne t1,zero,loop1a		# if t1 not equal to 0 branch to label loop
#	sw t1,0(sp)			# POP t1
#	addi sp,sp,4
#	ret	
#----------------------------------------------
delay250:					# delay routine
	addi sp,sp,-4
	sw t1,0(sp)			# PUSH t1
	li t1,669344			# 2677376/4 to t1 register  for 250ms		
loop1b:
	addi t1,t1,-1			# subtract 1 from t1
	bne t1,zero,loop1b		# if t1 not equal to 0 branch to label loop
	sw t1,0(sp)			# POP t1
	addi sp,sp,4
	ret	
#-----------------------------------------------
delay10:
	addi sp,sp,-4
	sw t1,0(sp)			# PUSH t1
	li t1,26773			# 2677376/100 to t1 register	for 10ms	
loop1a:
	addi t1,t1,-1			# subtract 1 from t1
	bne t1,zero,loop1a		# if t1 not equal to 0 branch to label loop
	sw t1,0(sp)			# POP t1
	addi sp,sp,4
	ret	
#----------------------------------------------

random_read:
	addi sp,sp,-4		# push RA
	sw ra,0(sp)		# push RA
	li a2,buffer		# address of location buffer in SRAM
	call I2C_START		# send start condition on I2C bus
	li a0, randomRaddress	# load register a0 with slave address (read), data to be sent is loaded in a0
	call I2C_READ_TWO	# reads 2 bytes from RDA5807 and stores in buffer in litteendian format
	lw ra,0(sp)		# POP RA
	addi sp,sp,4		# pop RA
	ret


random_write:		# data in buffer and address in a1
	addi sp,sp,-4		# push RA
	sw ra,0(sp)		# push RA
	call I2C_BUSY
	call I2C_START		# send start condition on I2C bus
	li a0, randomWaddress	# load register a0 with slave address (write), data to be sent is loaded in a0
	call SEND_ADDRESS	# call subroutine to send address
	mv a0,a1		# move address of RDA to be written from a1 to a0
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
	li a2,buffer		# load sram buffer address
	addi,a2,a2,1		# point to hi address
	lbu a0,0(a2)		# load 1 byte(MSB)
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
	addi a2,a2,-1		# decrease buffer address
	lbu a0,0(a2)		# load 1 byte(LSB)
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
	call I2C_TX_COMPLETE	# call subroutine that checks all transmission is completed
	call I2C_STOP		# call subroutine to terminate I2C operation
	lw ra,0(sp)		# POP RA
	addi sp,sp,4		# pop RA
	ret

seek_up:
	addi sp,sp,-4		# push RA
	sw ra,0(sp)		# push RA
	call delay10		# 10 ms for switch debounce
	call I2C_START		# send start condition on I2C bus
	li a0,randomWaddress	# radio random read address
	call SEND_ADDRESS	# call subroutine to send address
	li a0,0x02		# radio register 0x02 is set as pointer
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
	call random_read	# reads 2 bytes from 0x02 register in radio
	li a2,buffer		# load sram buffer address
	lw a4,0(a2)		# copy contents of buffer (value from 0x02)
	ori a4,a4,0x0300	# bit 8 and bit 9 of 0x02 RDA register,to seek upwards
	sw a4,0(a2)		# store back modified values in buffer
	li a1,0x02		# set radio pointer to 0x02 register
	call random_write	# write back modified value to 0x02 register
	call delay250		# 250ms delay
	call read_freq		# call read_freq to display the current frequency on OLED
	lw ra,0(sp)		# POP RA
	addi sp,sp,4		# pop RA
	ret


seek_dn:
	addi sp,sp,-4		# push RA
	sw ra,0(sp)		# push RA
	call delay10
	call I2C_START		# send start condition on I2C bus
	li a0,randomWaddress
	call SEND_ADDRESS	# call subroutine to send address
	li a0,0x02
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
	call random_read
	li a2,buffer		# load sram buffer address
	lw a4,0(a2)		# load 1 byte(MSB)
	ori a4,a4,0x100		# bit 8 and bit 9 of 0x02 RDA register
	sw a4,0(a2)
	li a1,0x02
	call random_write
	call delay250
	call read_freq
	lw ra,0(sp)		# POP RA
	addi sp,sp,4		# pop RA
	ret



tune_up:
	addi sp,sp,-4		# push RA
	sw ra,0(sp)		# push RA
	call delay10		# 10ms delay for switch debounce
	call I2C_START		# send start condition on I2C bus
	li a0,randomWaddress	# load radio address
	call SEND_ADDRESS	# call subroutine to send address
	li a0,0x0A		# current channel address of radio
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
	call random_read	# reads 2 bytes from radio, 1st high byte and then low byte, stored in buffer
	li a2,buffer		# load sram buffer address
	lw a4,0(a2)		# load buffer contents to a4
	andi a4,a4,0x03ff	# top 6 bits are stripped
	sw a4,0(a2)		# store back
	lw a4,0(a2)		# load word from buffer to a0
	addi a4,a4,0x01		# increase a0 value by 1 
	li a1,211		# 211+870 = 108.1Mhz which is above max channel 108mhz allowed in this band	211
	bge a4,a1,warp_to_0	# if channel is greater or equal to 108.1Mhz branch to label "warp_to_0" , channel is reset to 87.0Mhz

enter0:
	slli a4,a4,6		# shift logically left 6 register a4 so that channel aligns to top 10 bits to be loaded in RDA8057 0x03 register
	li a2,buffer1		# load address of buffer1
	sw a4,0(a2)		# a4 is stored in buffer1 , to be loaded in radio register 0x03
	call I2C_START		# send start condition on I2C bus
	li a0,randomWaddress	# load random write address of radio
	call SEND_ADDRESS	# call subroutine to send address
	li a0,0x03		# set radio address pointer to register 0x03
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
	call random_read	# call random read routine to read current values of 0x03 radio register
	li a2,buffer		# load address of sram buffer
	lw a4,0(a2)		# copy contents of buffer read from radio 0x03 register
	li a1,0x003F		# load a1 with channel mask 0x3f00, clears high 10 bits and keeps only low 6 bits, channel value cleared
	and a4,a4,a1		# and a4 with channel mask in a1 to clear channel data
	li a2,buffer1		# load address of buffer1 in a2
	lw a1,0(a2)		# copy contents of buffer1 which is new channel value (old value +100khz)
	addi,a1,a1,0x10		# enable tune bit by setting 5th bit
	or a4,a4,a1		# or buffer1 to buffer , new channel data with tune enable bit in a4
eee0:
	li a2,buffer		# load address of buffer in a2
	sw a4,0(a2)		# store new channel data in buffer
	li a1,0x03		# load a1 with radio regiater address 0x03 where new channel data is to be written
	call random_write	# call radom write subroutine that loads high byte and then low byte from buffer
	call delay250		# 250ms delay
	call read_freq		# subroutine to read and display the current channel value on OLED display
	lw ra,0(sp)		# POP RA
	addi sp,sp,4		# pop RA
	ret

warp_to_0:
	li a4,0x0010		# jump to enter0 label to transmit the values (0 = 87Mhz ,210 = 108Mhz)
	j eee0


tune_dn:
	addi sp,sp,-4		# push RA
	sw ra,0(sp)		# push RA
	call delay10		# 10ms delay for switch debounce
	call I2C_START		# send start condition on I2C bus
	li a0,randomWaddress	# radio address
	call SEND_ADDRESS	# call subroutine to send address
	li a0,0x0A		# pointer to radio register 0x0A
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
	call random_read	# read contents of radio register 0X0A
	li a2,buffer		# load sram buffer address
	lw a4,0(a2)		# load buffer contents to a4
	andi a4,a4,0x03ff	# top 6 bits are stripped
	sw a4,0(a2)		# store back
	lw a4,0(a2)		# load word from buffer to a0
	addi a4,a4,-1		# increase a0 value by 1 
	li a1,0			# 211+870 = 108.1Mhz which is above max channel 108mhz allowed in this band	211
	blt a4,a1,warp_to_210	# if less than 0 (0=870Khz) branch to "warp_to_210"label

enter0:
	slli a4,a4,6		# shift logically left 6 so that channel values that were in 0x0A will align in top 10 as needed by 0x03 later
	li a2,buffer1		# load address of buffer1
	sw a4,0(a2)		# a4 is stored in buffer1
	call I2C_START		# send start condition on I2C bus
	li a0,randomWaddress	# radio i2c address
	call SEND_ADDRESS	# call subroutine to send address
	li a0,0x03		# set pointer to radio 0x03 register
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
	call random_read	# read contents of 0x03 radio register
	li a2,buffer		# load address of buffer
	lw a4,0(a2)		# copy contents of buffer to a4
	li a1,0x003F		# load a1 with channel mask 0x3f00, clears high 10 bits and keeps only low 6 bits, channel value cleared
	and a4,a4,a1		# upper 10 chanel bits are cleared
	li a2,buffer1		# load buffer1 address 
	lw a1,0(a2)		# copy contents of buffer1 in a1
	or a4,a4,a1		# or buffer1 to buffer, previously right shifted value in buffer 1 is ORed in a4
	ori a4,a4,0x10		# enable tune bit
	li a2,buffer		# load buffer address
	sw a4,0(a2)		# store contents of a4 in buffer
	li a1,0x03		# load a1 with radio register value 0x03
	call random_write	# subroutine random write will write contents of buffer to 0x03
	call delay250		# delay 250ms
	call read_freq		# cal routine to dispaly channel on OLED
	lw ra,0(sp)		# POP RA
	addi sp,sp,4		# pop RA
	ret

warp_to_210:
	andi a4,a4,0		# clear a0
	addi a4,a4,210		# 210 = 108.0 Mhz  , 210+870 = 1080Khz
	j enter0		# jump to enter0 label to transmit the values (0 = 87Mhz ,210 = 108Mhz)

read_freq:
	addi sp,sp,-4		# push RA
	sw ra,0(sp)		# push RA
#	call delay50
	call I2C_START		# send start condition on I2C bus
	li a0,randomWaddress
	call SEND_ADDRESS	# call subroutine to send address
	li a0,0x0A
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
	call random_read	# received data in lower bytes of buffer
	li a2,buffer		# set index to buffer
	lw a4,0(a2)		# load word from buffer
	li a1,0x03ff		# strip upper 6 bits of the halfword from RDA
	and a4,a4,a1
	li a1,870		# 870 khz
	add a4,a4,a1		# channel + 870 = current MHz
	sw a4,0(a2)		# store word in buffer
	call bin2ascii16	# subroutine to convert binary in buffer to ASCII
	call set_cursor
	li s0,6			# 10000,1000,100,10,.,1 - total 6 ascii
	li s1,tthousand		# point index register to tthousand
printfreq:
	call printchar
	addi s1,s1,4		# increase address to next word in SRAM
	addi s0,s0,-1		# decrease char counter 1
	bnez s0,printfreq	# loop till cahr counter is 0
	call I2C_TX_COMPLETE	# call subroutine that checks all transmission is completed
	call I2C_STOP		# call subroutine to terminate I2C operation
	lw ra,0(sp)		# POP RA
	addi sp,sp,4		# pop RA
	ret



set_cursor:
	addi sp,sp,-4		# push RA
	sw ra,0(sp)		# push RA
	call oled_command_write
	li a0,0x22
	call I2C_WRITE
	mv a0,0		 	#position y
	call I2C_WRITE
	li a0,3
	call I2C_WRITE

	li a0,0x21
	call I2C_WRITE
	mv a0,0		 	#position x
	call I2C_WRITE
	li a0,0x7f
	call I2C_WRITE
	call I2C_TX_COMPLETE
	call I2C_STOP
	lw ra,0(sp)		# POP RA
	addi sp,sp,4		# pop RA
	ret


bin2ascii16:			# subroutine to convert binary to ASCII values to be printed on display, binary value in buffer
	addi sp,sp,-4		# push RA
	sw ra,0(sp)		# push RA
	li a2,buffer		# load buffer address
	lw a3,0(a2)		# copy contents of buffer to a3
	li a4,10000		# load a4 with 10000
	divu a5,a3,a4		# divide binary val with 10000 and store qoutient in a5
	addi,a5,a5,0x30		# convert qutient to ASCII by adding 0x30
	li a2,tthousand		# load address of tthousand in sram where we will store 10000th position ascii value
	sw a5,0(a2)		# store ascii
	remu a3,a3,a4		# find remainder of bin/10000 and store in a3
	li a4,1000		# load a4 1000
	divu a5,a3,a4		# bin/1000
	addi,a5,a5,0x30		# convert qoutient of bin/1000 to ascii value
	li a2,thousand		# load address of sram thousand
	sw a5,0(a2)		# store ascii
	remu a3,a3,a4		# find remainder of bin/1000 and store in a3
	li a4,100		# load a4 100
	divu a5,a3,a4		# bin/100
	addi,a5,a5,0x30		# convert qoutient of bin/100 to ascii value
	li a2,hundred		# load address of sram hundred
	sw a5,0(a2)		# store ascii
	remu a3,a3,a4		# find remainder of bin/100 and store in a3
	li a4,10		# load a4 10
	divu a5,a3,a4		# bin/10
	addi,a5,a5,0x30		# convert qoutient of bin/10 to ascii value
	li a2,ten		# load a4 10
	sw a5,0(a2)		# load address of sram ten	
	remu a3,a3,a4		# find remainder of bin/10 and store in a3
	addi a3,a3,0x30		# convert the remainder to ascii as it has reached the onse's position
	li a2,one		# load sram adress of one
	sw a3,0(a2)		# store ascii
	lw ra,0(sp)		# POP RA
	addi sp,sp,4		# pop RA
	ret




clear_OLED:
	addi sp,sp,-4		# push RA
	sw ra,0(sp)		# push RA
	li t2,4			# page OLED
#	call oled_datacmd_write
	call I2C_BUSY		# check weather I2C is busy ,wait till free
	call I2C_START		# send start condition on I2C bus
	li a0,OLEDaddress
	call SEND_ADDRESS	# call subroutine to send address
	li a0,data_cmd	        # load register a0 with slave address (write), data to be sent is loaded in a0
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
loop3:
	li t3,128		# length OLED
loop4:
	andi a0,a0,0		# clear a0
	call I2C_WRITE
	addi t3,t3,-1		# decrease oled length
	bnez t3,loop4		# if t3 not 0 continue to loop4
loop5:
	addi t2,t2,-1		# decrease page counter
	bnez t2,loop3
	call I2C_TX_COMPLETE
	call I2C_STOP
	lw ra,0(sp)		# POP RA
	addi sp,sp,4		# pop RA
	ret
	
printchar:
	addi sp,sp,-4		# push RA
	sw ra,0(sp)		# push RA
	lbu t2,0(s1)
	li t1,'.'
	beq t2,t1,decimal1
	li t1,' '
	beq t2,t1,space
	j print
decimal1:
	li a2,fontdecimal
	j ASCII0
space:
	li a2,fontspace
	j ASCII0	
	
print:
	li a2,font0
	li t1,0x30
	sub t2,t2,t1		# subtract ascii val in t2 with 0x30 in t1
	beqz t2,ASCII0
	andi t3,t3,0		# clear t3 for counting
multiply:
	addi a2,a2,16		# increase address by 16 , one char array
	addi t3,t3,1		# increase t3 counter 1
	bne t2,t3,multiply	# if t2 is not equal to t3 loop
ASCII0:
	call I2C_BUSY		# check weather I2C is busy ,wait till free
	call I2C_START		# send start condition on I2C bus
	li a0,OLEDaddress
	call SEND_ADDRESS	# call subroutine to send address
	li a0,data_cmd	        # load register a0 with slave address (write), data to be sent is loaded in a0
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
				# call oled_datacmd_write
	li t3,16		# length of character font array
	call array_read2
	call I2C_TX_COMPLETE	# call subroutine that checks all transmission is completed
	call I2C_STOP		# call subroutine to terminate I2C operation
	lw ra,0(sp)		# POP RA
	addi sp,sp,4		# pop RA
	ret

array_read2:
	addi sp,sp,-4		# push RA
	sw ra,0(sp)		# push RA
ar2loop:
	lbu t2,0(a2)		# a2 points to font array set in printchar routine
	addi a2,a2,1		# increase address pointer
	call double
	mv a0,t4		# copy stretched value to a0
	andi a0,a0,0xff		# keep only lsb
	call I2C_WRITE
	mv a0,t4
	srli a0,a0,8
	call I2C_WRITE
	addi t3,t3,-1		# array length counter is decreased
	bnez t3,ar2loop
	lw ra,0(sp)		# POP RA
	addi sp,sp,4		# pop RA
	ret


double:
	andi t4,t4,0		# stretched value will be in t4
	li t5,8			# number of bits to be doubled
	#mov t6,t2
	add t6,t2,zero
	#slli t6,t6,24		# shift byte to left for bit test
shiftloop:	
	andi t0,t6,0x80		# 7th bit is tested
	bnez t0,bit1
	slli t4,t4,2		# shift 2 0 in t4
	slli t6,t6,1		# shift t6 by 1 position to left
	addi t5,t5,-1		# decrease counter
	bnez t5,shiftloop
	ret
bit1:
	slli t4,t4,2		# shift left 2 current value to make space for 2 1s
	li t0,3			# load 00000011 in t0
	or t4,t4,t0		# or t4 wit to to place 2 bits at lsb
	slli t6,t6,1		# shift t6 by 1 position to left
	addi t5,t5,-1		# decrease counter
	bnez t5,shiftloop	# if counter not 0 repeat
	ret
		


oled_command_write:
	addi sp,sp,-4		# push RA
	sw ra,0(sp)		# push RA
	call I2C_BUSY		# check weather I2C is busy ,wait till free
	call I2C_START		# send start condition on I2C bus
	li a0,OLEDaddress
	call SEND_ADDRESS	# call subroutine to send address
	li a0, command	        # load register a0 with slave address (write), data to be sent is loaded in a0
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
	lw ra,0(sp)		# POP RA
	addi sp,sp,4		# pop RA
	ret
oled_datacmd_write:
	addi sp,sp,-4		# push RA
	sw ra,0(sp)		# push RA
	call I2C_BUSY		# check weather I2C is busy ,wait till free
	call I2C_START		# send start condition on I2C bus
	li a0,OLEDaddress
	call SEND_ADDRESS	# call subroutine to send address
	li a0,data_cmd	        # load register a0 with slave address (write), data to be sent is loaded in a0
	call I2C_WRITE		# call subroutine to transmit value loaded in a0
	lw ra,0(sp)		# POP RA
	addi sp,sp,4		# pop RA
	ret

init_RDA:		# bronzebeard assembler method for arrays, GCC/GNU arrays differ
shorts 0xC103,
shorts 0x0000
shorts 0x0A00
shorts 0x880F
shorts 0x0000
shorts 0x4202
 


OLED_INIT_BYTES:
shorts 0xA81f
shorts 0x2001
shorts 0x2100
shorts 0x7F22
shorts 0x0003
shorts 0xDA02
shorts 0x8D14
shorts 0xAF00


#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#;FONTS   fonts below 5bytes ,assembler will add one byte of padding with 0. hence array lenth =6
#;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

font0:
bytes 0x00,0x00, 0xE0,0x0f, 0x10,0x10, 0x08,0x20, 0x08,0x20, 0x10,0x10, 0xE0,0x0f, 0x00,0x00 
font1:
bytes 0x00,0x00, 0x10,0x20, 0x10,0x20, 0xF8,0x3F, 0x00,0x20, 0x00,0x20, 0x00,0x00, 0x00,0x00
font2:
bytes 0x00,0X00, 0x70,0X30, 0x08,0X28, 0x08,0X24, 0x08,0X22, 0x88,0X21, 0x70,0X30, 0x00,0X0
font3:
bytes 0x00,0X00, 0x30,0X18, 0x08,0X20, 0x88,0X20, 0x88,0X20, 0x48,0X11, 0x30,0X0E, 0x00,0X00 
font4:
bytes 0x00,0X00, 0x00,0X07, 0xC0,0X04, 0x20,0X24, 0x10,0X24, 0xF8,0X3F, 0x00,0X24, 0x00,0X00
font5:
bytes 0x00,0x00, 0xF8,0x19, 0x08,0x21, 0x88,0x20, 0x88,0x20, 0x08,0x11, 0x08,0x0e, 0x00,0x00
font6:
bytes 0x00,0x00, 0xE0,0x0f, 0x10,0x11, 0x88,0x20, 0x88,0x20, 0x18,0x11, 0x00,0x0e, 0x00,0x00
font7:
bytes 0x00,0x00, 0x38,0x00, 0x08,0x00, 0x08,0x3f, 0xC8,0x00, 0x38,0x00, 0x08,0x00, 0x00,0x00 
font8:
bytes 0x00,0x00, 0x70,0x1c, 0x88,0x22, 0x08,0x21, 0x08,0x21, 0x88,0x22, 0x70,0x1c, 0x00,0x00
font9:
bytes 0x00,0x00, 0xE0,0x00, 0x10,0x31, 0x08,0x22, 0x08,0x22, 0x10,0x11, 0xE0,0x0f, 0x00,0x00
fontdecimal:
bytes 0x00,0x00, 0x00,0x30, 0x00,0x30, 0x00,0x00, 0x00,0x00, 0x00,0x00, 0x00,0x00, 0x00,0x00
fontspace:
bytes 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00                    


