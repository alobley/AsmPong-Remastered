; Pong Game in 16 bit x86 Assembly Language
; Creator: xWatexx
; Date: April 3, 2025
;
; This program is a simple Pong game written in 16-bit x86 assembly language.
; This software is currently unlicensed.
ORG 0
CPU 8086
BITS 16


; Screen output definitions
%define VGA_TEXT_SEGMENT 0xB800
%define VGA_PIXEL_SEGMENT 0xA000

%define VGA_SCREEN_WIDTH 320
%define VGA_SCREEN_HEIGHT 200
%define VGA_SIZE 64000
%define VGA_WHITE 15

; PIT definitions
%define PIT_CH0 0x40
%define PIT_CH1 0x41
%define PIT_CH2 0x42
%define PIT_CMD 0x43
%define PIT_HZ 1193182
%define PIT_IRQ 0
%define PIT_SET 0x36
%define PIC_EOI 0x20
%define CURRENT_CS 0x1000

; Keyboard definitions
%define KB_STATUS 0x64
%define KB_DATA 0x60

%define KEYUP 0x80              ; NOT this bit away if to get a released scancode, or AND it with a scancode to detect if a key is up

%define KEY_W 0x11
%define KEY_S 0x1F

%define KEY_UP 0x48
%define KEY_DOWN 0x50

%define PADDLE_WIDTH 10
%define PADDLE_HEIGHT 30

%define LEFTPADDLE_X 0
%define RIGHTPADDLE_X 310

%define BALL_WIDTH 10
%define BALL_HEIGHT 10
%define BALL_STARTX 155
%define BALL_STARTY 95

; Gets a byte value from a given I/O port
; Clobbers DX and AL
%macro inb 1
    mov dx, %1
    in al, dx
%endmacro

; Sends a byte value to an I/O port
; Clobbers DX and AL
%macro outb 2
    mov dx, %1
    mov al, %2
    out dx, al
%endmacro


_start:
    mov si, loadmsg
    mov ah, 0x07
    call printl

    mov ah, 0x00
    mov al, 0x13
    int 0x10

.loop:
    call Check_Left
    call Check_Right

    call Wait_Time

    call Move_Ball

    call Clear_Screen

    mov ax, 0
    mov bx, 0
    mov cx, VGA_SCREEN_WIDTH
    mov dx, VGA_SCREEN_HEIGHT
    mov di, 0
    call Draw_Rect

    ; Test - draw the paddle on the left side
    mov ax, LEFTPADDLE_X
    mov bx, word [leftY]
    mov cx, PADDLE_WIDTH
    mov dx, PADDLE_HEIGHT
    mov di, VGA_WHITE
    call Draw_Rect

    ; Draw the paddle on the right side
    mov ax, RIGHTPADDLE_X
    mov bx, word [rightY]
    mov cx, PADDLE_WIDTH
    mov dx, PADDLE_HEIGHT
    mov di, VGA_WHITE
    call Draw_Rect

    ; Draw the ball
    mov ax, word [ballX]
    mov bx, word [ballY]
    mov cx, BALL_WIDTH
    mov dx, BALL_HEIGHT
    mov di, VGA_WHITE
    call Draw_Rect

    cmp byte [done], 1
    jne .loop

    cli
    hlt

left_score: db 0
right_score: db 0

left_up:
    cmp word [leftY], 0
    je .done

    sub word [leftY], 5
.done:
    ret
left_down:
    cmp word [leftY], 170
    jge .done

    add word [leftY], 5
.done:
    ret

right_up:
    cmp word [rightY], 0
    jle .done

    sub word [rightY], 5
.done:
    ret
right_down:
    cmp word [rightY], 170
    jge .done

    add word [rightY], 5
.done:
    ret

leftY: dw 85
rightY: dw 85
done: db 0

ballX: dw BALL_STARTX
ballY: dw BALL_STARTY
ballXSpeed: dw 5
ballYSpeed: dw 5

Move_Ball:
    push ax
    mov ax, word [ballXSpeed]
    add word [ballX], ax
    mov ax, word [ballYSpeed]
    add word [ballY], ax
    pop ax

    ; Check for right paddle collision
    cmp word [ballX], (VGA_SCREEN_WIDTH - BALL_WIDTH - PADDLE_WIDTH)
    je .CheckRight

    ; Check for left paddle collision
    cmp word [ballX], PADDLE_WIDTH
    je .CheckLeft

.NoBounce:
    ; Check if ball passed right boundary
    cmp word [ballX], (VGA_SCREEN_WIDTH - BALL_WIDTH)
    jg .leftScore
    ; Check if ball passed left boundary
    cmp word [ballX], 0
    jl .rightScore

.after:
    ; Check top and bottom bounds
    cmp word [ballY], (VGA_SCREEN_HEIGHT - BALL_HEIGHT)
    jge .invY
    cmp word [ballY], 0
    jle .invY

    jmp .done

.leftScore:
    neg word [ballXSpeed]
    mov word [ballX], BALL_STARTX
    mov word [ballY], BALL_STARTY
    inc byte [left_score]
    jmp .after

.rightScore:
    neg word [ballXSpeed]
    mov word [ballX], BALL_STARTX
    mov word [ballY], BALL_STARTY
    inc byte [right_score]
    jmp .after

.invY:
    neg word [ballYSpeed]
    jmp .done

.CheckRight:
    ; Check if ball is within right paddle's vertical range
    push ax
    ; Check lower bound of paddle
    mov ax, word [rightY]
    cmp word [ballY], ax
    jl .CheckRightFail     ; Ball is above paddle
    ; Check upper bound of paddle
    mov ax, word [rightY]
    add ax, PADDLE_HEIGHT
    cmp word [ballY], ax
    jge .CheckRightFail    ; Ball is below paddle
    ; Ball hit the paddle
    pop ax
    neg word [ballXSpeed]
    jmp .after
.CheckRightFail:
    pop ax
    jmp .NoBounce

.CheckLeft:
    ; Check if ball is within left paddle's vertical range
    push ax
    ; Check lower bound of paddle
    mov ax, word [leftY]
    cmp word [ballY], ax
    jl .CheckLeftFail      ; Ball is above paddle
    ; Check upper bound of paddle
    mov ax, word [leftY]
    add ax, PADDLE_HEIGHT
    cmp word [ballY], ax
    jge .CheckLeftFail     ; Ball is below paddle
    ; Ball hit the paddle
    pop ax
    neg word [ballXSpeed]
    jmp .after
.CheckLeftFail:
    pop ax
    jmp .NoBounce

.done:
    ret

Wait_Time:
    mov ah, 0x00
    int 0x1A

    mov word [.lastread], dx
.wait_loop:
    mov ah, 0x00
    int 0x1A

    sub dx, word [.lastread]
    cmp dx, word [.toWait]
    jne .wait_loop

    ret
.lastread: dw 0
.toWait: dw 1

Check_Left:
    call Get_Key

    cmp al, KEY_W
    je .lu

    cmp al, KEY_S
    je .ld

    jmp .done
.lu:
    call left_up
    jmp .done
.ld:
    call left_down
    jmp .done
.done:
    ret

Check_Right:
    call Get_Key
    cmp al, KEY_UP
    je .ru

    cmp al, KEY_DOWN
    je .rd

    jmp .done
.ru:
    call right_up
    jmp .done
.rd:
    call right_down
    jmp .done
.done:
    ret


; AH: Scancode
; AL: ASCII value (if applicable)
Get_Key:
    mov dx, KB_DATA
    in al, dx

    ret

; Draw a rectangle to the framebuffer
; AX: X position
; BX: Y position
; CX: Width
; DX: Height
; DI: Color
Draw_Rect:
    push ax
    push bx
    push cx
    push dx
    push es
    push si
    push di

    push ax
    mov ax, VGA_PIXEL_SEGMENT
    mov es, ax
    pop ax

    mov word [.startX], ax
    mov word [.currentY], bx
    mov word [.endY], bx
    add word [.endY], dx

.loopY:
    mov ax, [.startX]
    mov bx, [.currentY]
    cmp bx, word [.endY]
    je .done

    ; Calculate the offset
    push ax
    mov ax, bx
    mov bx, VGA_SCREEN_WIDTH
    mul bx
    pop bx
    add ax, bx

    ; Offset is now in AX
    mov si, ax

    push cx
.loopX:
    mov ax, di
    mov byte [es:si], al
    inc si
    loop .loopX
    pop cx
    inc word [.currentY]
    jmp .loopY

.done:
    pop di
    pop si
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret
.startX: dw 0
.currentY: dw 0
.endY: dw 0

Clear_Screen:
    push ax
    push cx
    push es
    push si

    mov ax, VGA_PIXEL_SEGMENT
    mov es, ax

    mov si, 0
.clear_loop:
    mov byte [si], 0
    inc si
    cmp si, 64000
    jl .clear_loop

    pop si
    pop es
    pop cx
    pop ax
    ret
    

; DS:SI = the pointer to the string
; AH = Attribute
printl:
    push ax
    push es
    push si
    push di

    push ax
    mov ax, VGA_TEXT_SEGMENT
    mov es, ax
    pop ax

    mov di, word [screen_offset]
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

    add word [screen_offset], 160
    ret

; Clears the screen
text_clear:
    push es
    push si

    push ax
    mov ax, VGA_TEXT_SEGMENT
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

screen_offset: dw 160

loadmsg: db "The rest of the game has loaded!", 0
key_pressed: db "W key pressed!", 0