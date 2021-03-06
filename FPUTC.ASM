;_ FPUTC.ASM   Modified by Joe Huffman August 16, 1990
; Copyright (C) 1985-1989 by Walter Bright
; All Rights Reserved
; Written by Walter Bright

;CAUTION!  This code is highly optimized.  It does not fully utilize the
;macros 'uses' and 'unuse' for register preservation.  If registers other than
;EBX, ESI, and EDI (and of course EBP, DS, and ES) must be preserved examine 
;this module carefully.

	include macros.asm
	include stdio.asm

	extrn	__flushbu:near
	extrn	__fillbuf:near
	extrn	_fflush:near

    ifdef _MT
	extrn	___fp_lock:near,___fp_unlock:near
    endif

	begcode fputc

	public	_fputc

;;;;;;;;;;;;;;;;;;;;;;;;;
;	fputc(c,fp);

_fputc	proc	near

    ifdef _MT
	;The idea with the multi-threaded version is to lock the
	;stream, call the locked version of fputc, and then
	;unlock the stream.

	push	EBP
	mov	EBP,ESP
	sub	ESP,4
	push	P+4[EBP]
	call	___fp_lock
	push	P+0[EBP]
	call	near ptr _fputc_nlock
	add	SP,4			;clean off c, but not fp
	mov	-4[EBP],EAX		;save return value
	call	___fp_unlock
	mov	EAX,-4[EBP]
	mov	ESP,EBP
	pop	EBP
	ret
    endif

	public	__fputc_nlock
__fputc_nlock:

	movzx	EAX,byte ptr PS[ESP]	;get c (don't let c sign-extend to
        				; produce wrong EOF)
	mov	ECX,PS+4[ESP]		;get fp
ifdef DOS386
	_ifs	AL e 10, L4	;if LF
endif

; Input:
;	AL = c
;	ECX = fp
; Output:
;	EAX = c & 0xFF
;	ECX = fp

L1:
_putit:
	dec	dword ptr _cnt[ECX]
	js	short L2
L5:
	mov	EDX,_ptr[ECX]
	mov	[EDX],AL
        inc	EDX
	mov	_ptr[ECX],EDX
	ret

ifdef DOS386
L4:	test	byte ptr _flag+1[ECX],_IOTRAN/256
	jz	short L3	;if not translated mode
	mov	AL,13		;CR first
	call	_putit
	mov	AL,10		;Reload LF into AL.
endif

L3:	test	byte ptr _flag[ECX],_IOLBF	;line buffered?
	jz	short L1			;no

	call	_putit
	push	EAX
	push	ECX		;offset of fp
	call	_fflush
	add	ESP,SIZEPTR
	tst	EAX		;did fflush succeed?
	pop	EAX		;EAX = c & 0xFF
	jz	short L6	;it succeeded
	mov	EAX,-1		;fflush failed, return EOF
L6:	ret

L2:
	push	ECX		;Save a copy of fp.
	push	ECX		;push fp, for use by _flushbu
	push	EAX		;push c
	call	__flushbu
	add	ESP,4+SIZEPTR
	pop	ECX		;pop fp, copy needed if called by putit.

	ret
_fputc	endp

;;;;;;;;;;;;;;;;;;;;;;;;;;
; fgetc(fp);

	public	_fgetc

	_align
_fgetc	proc	near

    ifdef _MT
	;The idea with the multi-threaded version is to lock the
	;stream, call the locked version of fgetc, and then
	;unlock the stream.

	push	EBP
	mov	EBP,ESP
	sub	ESP,4
	push	P+0[EBP]
	call	___fp_lock
	call	near ptr _fgetc_nlock
	mov	-4[EBP],EAX		;save return value
	call	___fp_unlock
	mov	EAX,-4[EBP]
	mov	ESP,EBP
	pop	EBP
	ret
    endif

	public	__fgetc_nlock
__fgetc_nlock:
 
G4:	mov	ECX,PS[ESP]
G1:	dec	dword ptr _cnt[ECX]
	js	short G2	;if out of chars in buffer

G6:
	mov	EDX,_ptr[ECX]
	movzx	EAX,byte ptr [EDX]	;get char from buffer
	inc	EDX
	mov	_ptr[ECX],EDX		;updated pointer

ifdef DOS386
	test	byte ptr _flag+1[ECX],_IOTRAN/256	;translated mode?
	je	short G3			;no
	_ifs	AL e 13, G1			;ignore CRs
	_ifs	AL e 26, G5			;^Z marks end of file
endif
G3:	ret

G2:
	_ifs	<dword ptr _cnt[ECX]> ne -1, G6
	push	ECX
	call	__fillbuf		;fill buffer (_fillbuf(fp))
	add	ESP,4
	tst	EAX			;EOF?
	jz	short G4		;no
	ret				;return EOF

G5:	mov	EAX,EOF
	or	byte ptr _flag[ECX],_IOEOF	;set EOF flag bit
	mov	dword ptr _cnt[ECX],0		;0 chars left in buffer
	ret

_fgetc	endp

	endcode fputc
	end

