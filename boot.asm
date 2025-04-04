ORG 0x7C00
CPU 8086
BITS 16


%define VGA_SEGMENT 0xB800

; Load the game at linear address 0x10000
%define LOAD_CS 0x1000

; The stack segment will be right after it
%define FINAL_SS 0x2000

    jmp 0:boot
boot:
    cli
    mov byte [driveno], dl

    cld

    ; Reset all the segment registers
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; Set the stack
    mov sp, 0x7C00
    mov bp, 0x7BFF

    sti

    ; Clear the screen
    call clear

    ; Print a boot message
    mov si, bootmsg
    mov ah, 0x07
    mov di, 0
    call print

    ; Load the game at a proper memory segment
    mov ax, LOAD_CS
    mov es, ax
    xor bx, bx

    ; Load the game from the disk
    mov ax, 0x02
    mov al, 128
    mov ch, 0
    mov cl, 2
    mov dh, 0
    call load_sectors
    jc error

    ; Set the new stack segment
    mov ax, FINAL_SS
    mov ss, ax

    ; Set the new stack
    mov sp, 0xFFFF
    mov bp, 0
    
    mov ax, LOAD_CS
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; Jump to the actual program code
    jmp LOAD_CS:0

error:
    mov si, failmsg
    mov ah, 0x07
    mov di, 160
    call print

    cli
    hlt


; ES:BX = Pointer to the load buffer
; CH = Low 8 bits of cylinder number
; CL = Bits 0-5 of the sector number and high 2 bits of the cylinder number
; DH = Head number
load_sectors:
    push ax
    push bx
    push cx
    push dx
.retry:
    mov ah, 0x02
    mov dl, byte [driveno]
    int 0x13
    jc .err
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    mov byte [.retries], 4
    ret
.err:
    pop dx
    pop cx
    pop bx
    pop ax
    push ax
    push bx
    push cx
    push dx

    dec byte [.retries]
    cmp byte [.retries], 0
    jg .retry

    jmp error
.retries: db 4


; DS:SI = the pointer to the string
; AH = Attribute
; DI = offset in VGA memory
print:
    push ax
    push es
    push si
    push di

    push ax
    mov ax, VGA_SEGMENT
    mov es, ax
    pop ax
.loop:
    mov al, byte [ds:si]
    cmp al, 0
    je .done
    mov word [es:di], ax

    add di, 2
    inc si

    jmp .loop
.done:
    pop di
    pop si
    pop es
    pop ax
    ret

; Clears the screen
clear:
    push es
    push si

    push ax
    mov ax, VGA_SEGMENT
    mov es, ax
    pop ax

    mov si, 0
.loop:
    mov word [es:si], 0
    add si, 2
    cmp si, 4000
    je .done
    jmp .loop
.done:
    pop si
    pop es
    ret


bootmsg: db "Booting...", 0
failmsg: db "Failed to load from the disk!", 0

driveno: db 0

times 510 - ($ - $$) db 0
dw 0xAA55