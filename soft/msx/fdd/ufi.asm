; -----------------------------------------------------------------------------
; ASC_TO_ERR: Convert UFI ASC to DSKIO error
; -----------------------------------------------------------------------------
; Input:  A = ASC
; Output: A = Error
;         Cy = 1

ASC_TO_ERR:
    call _ASC_TO_ERR
    ld a,h
    scf
    ret

_ASC_TO_ERR:
    cp 27h      ;Write protected
    ld h,0
    ret z
    cp 3Ah      ;Not ready
    ld h,2
    ret z
    cp 10h      ;CRC error
    ld h,4
    ret z
    cp 21h      ;Invalid logical block
    ld h,6
    ret z
    cp 02h      ;Seek error
    ret z
    cp 03h
    ld h,10
    ret z
    ld h,12     ;Other error
    ret


; -----------------------------------------------------------------------------
; TEST_DISK: Test if disk is present and if it has changed
;
; We need to call this before any attempt to access the disk,
; not only to actually check if it has changed,
; before some drives fail the READ and WRITE commands the first time
; they are executed after a disk change otherwise.
; -----------------------------------------------------------------------------
; Output:	F	Cx set for error
;			Cx reset for ok
;		A	if error, errorcode
;		B	if no error, disk change status
;			01 disk unchanged
;			00 unknown
;			FF disk changed

TEST_DISK:
    call _RUN_TEST_UNIT_READY
    ret c

    ld a,d
    or a
    ld b,1  ;No error: disk unchanged
    ret z

    ld a,d
    cp 28h  ;Disk changed if ASC="Media changed"
    ld b,0FFh
    ret z

    cp 3Ah  ;"Disk not present"
    jp nz,ASC_TO_ERR

    ;Some units report "Disk not present" instead of "medium changed"
    ;the first time TEST UNIT READY is executed after a disk change.
    ;So let's execute it again, and if no error is returned,
    ;report "disk changed".

    call _RUN_TEST_UNIT_READY
    ret c

    ld b,0FFh
    ld a,d
    or a
    ret z
    cp 28h  ;Test "Media changed" ASC again just in case
    ret z
    
    jp ASC_TO_ERR


; Output: Cy=1 and A=12 on USB error
;         Cy=0 and DE=ASC+ASCQ on USB success
_RUN_TEST_UNIT_READY:
    ld b,3  ;Some drives stall on first command after reset so try a few times
TRY_TEST:
    push bc    
    xor a   ;Receive data + don't retry "Media changed"
    ld hl,_UFI_TEST_UNIT_READY_CMD
    ld bc,0
    ld de,0
    call USB_EXECUTE_CBI_WITH_RETRY
    pop bc
    or a
    ret z
    djnz TRY_TEST

    ld a,12
    scf
    ret

_UFI_TEST_UNIT_READY_CMD:
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0