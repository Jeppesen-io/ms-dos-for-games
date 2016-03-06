; Mouse Protocol Analyzer for serial mice
; Copyright (c) 1997-2002 Nagy Daniel <nagyd@users.sourceforge.net>
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program; if not, write to the Free Software
; Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
;
;
; History:
;
; 1.6 - by Arkady V.Belousov <ark@mos.ru>
;	Heavy optimizations
;	Source synchronized with CTMOUSE source
;	Added external assembler library
;	Keystroke now break also PnP input loop
;
; 1.5 - by Arkady V.Belousov <ark@mos.ru>
;	Small bugfixes and optimizations
;	Mouse events bytes printing moved out from IRQ handler
;
; 1.4 - by Arkady V.Belousov <ark@mos.ru>
;	Only first argument (COM port number) now is required
;
; 1.3 - by Arkady V.Belousov <ark@mos.ru>
;	Added parsing and showing PnP data
;
; 1.2 - by Arkady V.Belousov <ark@mos.ru>
;	Source synchronized with CTMOUSE source
;	Added command line option for COM LCR value
;	Added dumping of reset sequence, generated by mouse
;
; 1.1 - Added command line option for COM port selection
;
; 1.0 - First public release
;

%pagesize 255
%noincl
;%macs
%nosyms
;%depth 0
%linum 0
%pcnt 0
;%bin 0
warn
locals

.model use16 tiny

dataref equ <offset @data>	; offset relative data group

include asm.mac
include hll.mac
include code.def
include code.mac
include macro.mac
include BIOS/area0.def
include convert/digit.mac
include convert/count2x.mac
include DOS/io.mac
include DOS/mem.mac
include hard/PIC8259A.def
include hard/UART.def

nl		equ <13,10>
eos		equ <'$'>

say		macro	stroff:vararg
		MOVOFF_	dx,<stroff>
		call	saystr
endm


;���������������������������� DATA SEGMENTS �����������������������������

.data

S_COMinfo	db 'Dump data stream from working mouse. Press ESC to exit...',nl
		db '1200 bps, '
databits	db	     '5 data bits, '
stopbits	db			   '1 stop bit.',nl
		db 'Reset:',eos
S_spaces	db nl,' '
S_bitbyte	db	  '     ',eos
S_byte		db '   ',eos

.const

S_wrongPnP	db 'Wrong PnP data...'
CRLF2		db nl
CRLF		db nl,eos
PnP_OEM		db 'Manufacturer: ',eos
PnP_header	db '  Product ID: ',eos
PnP_hdnext	db '    Serial #: ',eos
		db '       Class: ',eos
		db '   Driver ID: ',eos
		db '   User name: ',eos
PnP_hdend	label

S_notCOM	db 'COM port not found!',nl,eos
Syntax		db 'Syntax: protocol <COM (1-4)> [<bytes in event (3-5)>'
		db			' [<COM LCR value (2-3)>]]',nl,eos

.data?

oldIRQaddr	dd ?		; old IRQ handler address

programend segment virtual	; place at the end of current segment

;!!! this segment placed at the end of .data? segment, which placed after
;!!! other segments, thus in .COM program PnPdata points after program
;!!! end and before stack top

PNPdata		label		; buffer for PnP data

queue		db 32 dup(?)	; queue for incoming serial data
queue_end	label

programend ends


;����������������������������� CODE SEGMENT �����������������������������

.code
.startup
		cld
		mov	si,80h			; offset PSP:cmdline_len
		lodsb
		cbw				; OPTIMIZE: instead MOV AH,0
		movadd	di,si,ax

		call	skipwhite
		jc	HELP
		mov	dx,dataref:S_notCOM
		dec	ax			; OPTIMIZE: AX instead AL
		cmp	al,3
		ja	EXITERRMSG
		call	setCOMport
		;mov	dx,dataref:S_notCOM
		jc	EXITERRMSG

		call	skipwhite
		jc	processmouse
		mov	[limit],al

		call	skipwhite
		jc	processmouse
		mov	[LCRset],al

		call	skipwhite
		jc	processmouse

HELP:		mov	dx,dataref:Syntax
EXITERRMSG:	say
		int	20h

;������������������������������������������������������������������������

skipwhite	proc
		cmp	di,si
	if_ ae					; JB mean CF=1
		lodsb
		cmp	al,' '
		jbe	skipwhite
		sub	al,'0'
		jb	HELP
		;clc
	end_
		ret
skipwhite	endp

;������������������������������������������������������������������������

processmouse	proc
		mov	ax,1Fh			; disable mouse
		call	mousedrv

;----- initialize mouse and dump PnP info

		mov	si,[IO_address]
		call	disableUART
		call	resetmouse

;----- install IRQ handler and enable interrupt

		mov	al,[IRQintnum]
		DOSGetIntr
		saveFAR [oldIRQaddr],es,bx	; save old IRQ handler
		;mov	al,[IRQintnum]
		DOSSetIntr ,,,@code:IRQhandler
		call	enableUART

;===== process mouse data until keystroke

		MOVSEG	es,ds,,@data
		mov	bx,dataref:queue

	loop_
@@mainloop:	hlt
		mov	ah,1
		int	16h			; check for keystroke
	while_ zero
		cmp	bx,[queue@]
		je	@@mainloop

		cmp	bx,dataref:queue_end
	 if_ ae
		mov	bx,dataref:queue
	 end_
		mov	ah,[bx]
		inc	bx

		mov	di,dataref:S_bitbyte+1
	 countloop_ 8				; 8 bits
		mov	al,'0' shr 1
		rol	ax,1
		stosb
	 end_
		say	@data:S_bitbyte

	CODE_	MOV_AL	IOdone,<db 0>		; processed bytes counter
		inc	ax			; OPTIMIZE: AX instead AL
	CODE_	CMP_AL	limit,<db 3>
	 if_ ae
		say	@data:CRLF
		mov	al,0			; restart counter of bytes
	 end_
		mov	[IOdone],al
	end_ loop

;===== final: flush keystroke, deinstall handler and exit

		mov	ah,0
		int	16h			; get keystroke

		call	disableUART
	CODE_	MOV_AX	IRQintnum,<db ?,25h>	; INT number of selected IRQ
		lds	dx,[oldIRQaddr]
		assume	ds:nothing
		int	21h			; set INT in DS:DX

;----- reset mouse and exit through RET

		xor	ax,ax			; reset mouse
		;j	mousedrv
processmouse	endp
		assume	ds:@data

;������������������������������������������������������������������������

mousedrv	proc
		push	ax bx es
		DOSGetIntr 33h
		mov	ax,es
		test	ax,ax
		pop	es bx ax
	if_ nz
		int	33h
	end_
		ret
mousedrv	endp

;������������������������������������������������������������������������

setCOMport	proc
		MOVSEG	es,0,bx,BIOS
		mov	bl,al
		shl	bx,1
		mov	cx,COM_base[bx]
		stc
	if_ ncxz
		mov	[IO_address],cx

		inc	ax			; OPTIMIZE: AX instead AL
		and	al,1			; 1=COM1/3, 0=COM2/4
		add	al,3			; IRQ4 for COM1/3
		mov	cl,al			; IRQ3 for COM2/4
		add	al,8			; INT=IRQ+8
		mov	[IRQintnum],al
		mov	al,1
		shl	al,cl			; convert IRQ into bit mask
		mov	[PIC1state],al		; PIC interrupt disabler
		not	al
		mov	[notPIC1state],al	; PIC interrupt enabler
		;clc
	end_ if
		ret
setCOMport	endp


;���������������������������� COMM ROUTINES �����������������������������

disableUART	proc
		in	al,PIC1_IMR		; {21h} get IMR
	CODE_	OR_AL	PIC1state,<db ?>		; set bit to disable interrupt
		out	PIC1_IMR,al		; {21h} disable serial interrupts
;-----
		movidx	dx,LCR_index,si		; {3FBh} LCR: DLAB off
		 out_	dx,%LCR<>,%MCR<>	; {3FCh} MCR: DTR/RTS/OUT2 off
		movidx	dx,IER_index,si,LCR_index
		 ;mov	ax,(FCR<> shl 8)+IER<>	; {3F9h} IER: interrupts off
		 out	dx,ax			; {3FAh} FCR: disable FIFO
		ret
disableUART	endp

;������������������������������������������������������������������������

enableUART	proc
		movidx	dx,MCR_index,si
		 out_	dx,%MCR<,,,1,1,1,1>	; {3FCh} MCR: DTR/RTS/OUTx on
		movidx	dx,IER_index,si,MCR_index
		 out_	dx,%IER{IER_DR=1}	; {3F9h} IER: enable DR intr
;-----
		in	al,PIC1_IMR		; {21h} get IMR
	CODE_	AND_AL	notPIC1state,<db ?>	; clear bit to enable interrupt
		out	PIC1_IMR,al		; {21h} enable serial interrupts
		ret
enableUART	endp

;������������������������������������������������������������������������

resetmouse	proc
		mov	al,[LCRset]
		maskflag al,mask LCR_stop+mask LCR_wordlen
		mov	cl,8-LCR_stop
		shl	ax,cl			; LCR_stop
		shr	al,cl			;  > LCR_wordlen
		add	[stopbits],ah
		add	[databits],al
		say	@data:S_COMinfo

;----- set communication parameters

		movidx	dx,LCR_index,si
		 out_	dx,%LCR{LCR_DLAB=1}	; {3FBh} LCR: DLAB on
		xchg	dx,si			; 1200 baud rate
		 outw	dx,96			; {3F8h},{3F9h} divisor latch
		xchg	dx,si
	CODE_	 MOV_AL	LCRset,<LCR <0,,LCR_noparity,0,2>>
		 out	dx,al			; {3FBh} LCR: DLAB off, 7/8N1

;----- wait current+next timer tick and then raise RTS line

		MOVSEG	es,0,ax,BIOS
	loop_
		mov	ah,byte ptr [BIOS_timer]
	 loop_
		cmp	ah,byte ptr [BIOS_timer]
	 until_ ne				; loop until next timer tick
		xor	al,1
	until_ zero				; loop until end of 2nd tick

		movidx	dx,MCR_index,si,LCR_index
		 out_	dx,%MCR<,,,0,,1,1>	; {3FCh} MCR: DTR/RTS on, OUT2 off

;----- read and show reset sequence, generated by mouse

		mov	bx,20+1			; output counter
		mov	di,dataref:PnPdata
	loop_
	 countloop_ 2+1				; length of silence in ticks
						; (include rest of curr tick)
		mov	ah,byte ptr [BIOS_timer]
	  loop_
		movidx	dx,LSR_index,si
		 in	al,dx			; {3FDh} LSR (line status reg)
		testflag al,mask LSR_RBF
		 jnz	@@newbyte		; jump if data ready
		cmp	ah,byte ptr [BIOS_timer]
	  until_ ne				; loop until next timer tick
	 end_ countloop				; loop until end of 2nd tick
		j	@@parsePnP		; stream terminated by silence

;----- save and show next byte

@@newbyte:	dec	bx
	 if_ zero
		say	@data:S_spaces		; out spaces after
		mov	bl,20			;  right margin
	 end_
		movidx	dx,RBR_index,si
		 in	al,dx			; {3F8h} receive byte

		mov	cx,sp
		sub	cx,di
		test	ch,ch			; ZF=1 if CX<256
	 if_ nz
		mov	[di],al			; store if space enough
		inc	di
	 end_
		call	byte2hexa
		mov	word ptr S_byte[1],ax
		say	@data:S_byte

		mov	ah,1
		int	16h
	until_ nz				; loop until keystroke
		j	@@resetdone		; then exit

;----- parse and show PnP data

@@parsePnP:	mov	cx,di
		mov	di,dataref:PnPdata

	loop_					; find PnP data start '('
		cmp	di,cx
		jae	@@resetdone
		inc	di
		cmp	byte ptr [di-1],'('-20h
	until_ eq

		say	@data:CRLF2
		mov	dx,dataref:S_wrongPnP

		movadd	di,,2-1			; skip "(!D"
		mov	bx,di
		inc	bx			; BX=start of PnP data
		mov	al,')'-20h+3*20h	; count checksum in AL
	loop_
		inc	di
		cmp	di,cx
		jae	saystr
		add	al,[di-3]
		sub	al,20h
		add	byte ptr [di],20h	; ...and decode PnP data
		cmp	byte ptr [di],')'	; ...until PnP data end ')'
	until_ eq

		movsub	di,,2			; verify checksum
		call	byte2hexa		; convert checksum to ASCII
		cmp	ax,[di]
		jne	saystr

		say	@data:PnP_OEM		; show "Manufacturer" field
	countloop_ 3
		mov	dl,[bx]
		inc	bx
		DosWriteC
	end_

		mov	cx,dataref:PnP_header
	loop_
		say	@data:CRLF		; show other PnP fields
		say	cx

	 loop_
		cmp	bx,di
	 while_ below
		mov	dl,[bx]
		inc	bx
		cmp	dl,'\'
	  breakif_ eq
		DosWriteC
	 end_ loop

		add	cx,PnP_hdnext-PnP_header
		cmp	cx,dataref:PnP_hdend
	until_ ae

@@resetdone:	mov	dx,dataref:CRLF2
		;j	saystr
resetmouse	endp

;������������������������������������������������������������������������

saystr		proc
		DOSWriteS
		ret
saystr		endp

;������������������������������������������������������������������������

byte2hexa	proc
		mov	cl,4
		_byte_hex_AX ,,cl
		ret
byte2hexa	endp


;����������������������������� IRQ HANDLER ������������������������������

IRQhandler	proc
		assume	ds:nothing,es:nothing,ss:nothing
		push	ax dx bx
	CODE_	MOV_DX	IO_address,<dw ?>	; UART IO address
		push	dx
		movidx	dx,LSR_index
		 in	al,dx			; {3FDh} LSR: clear error bits
		xchg	bx,ax			; OPTIMIZE: instead MOV BL,AL
		pop	dx
		movidx	dx,RBR_index
		 in	al,dx			; {3F8h} flush receive buffer

		shr	bl,LSR_RBF+1
	if_ carry				; process data if data ready
	CODE_	MOV_BX	queue@,<dw dataref:queue>
		cmp	bx,dataref:queue_end
	 if_ ae
		mov	bx,dataref:queue
	 end_
		mov	cs:[bx],al
		inc	bx
		mov	[queue@],bx
	end_
		out_	PIC1_OCW2,%OCW2<OCW2_EOI> ; {20h} end of interrupt
		pop	bx dx ax
		iret
IRQhandler	endp
		assume	ds:@data

;������������������������������������������������������������������������

end