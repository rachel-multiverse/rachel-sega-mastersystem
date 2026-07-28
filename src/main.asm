; =============================================================================
; SEGA MASTER SYSTEM RACHEL CLIENT
; Main entry point
; =============================================================================

; Platform ID: 0x0013 (19)
PLATFORM_ID_HI  equ     $00
PLATFORM_ID_LO  equ     $13

; =============================================================================
; Memory Map
; =============================================================================
; $0000-$BFFF  ROM (48KB max without banking)
; $C000-$DFFF  RAM (8KB)
; $E000-$FFFF  RAM mirror

RAM_START       equ     $C000

; =============================================================================
; VDP Ports
; =============================================================================
VDP_DATA        equ     $BE
VDP_CTRL        equ     $BF
VDP_STATUS      equ     $BF

; =============================================================================
; I/O Ports
; =============================================================================
IO_CTRL1        equ     $DC
IO_CTRL2        equ     $DD
IO_MEM_CTRL     equ     $3E

; =============================================================================
; Joypad bits (active low)
; =============================================================================
JOY_UP          equ     0
JOY_DOWN        equ     1
JOY_LEFT        equ     2
JOY_RIGHT       equ     3
JOY_BTN1        equ     4
JOY_BTN2        equ     5

; =============================================================================
; RUBP Constants
; =============================================================================
RUBP_VERSION    equ     1
MSG_HELLO       equ     $01
MSG_GAME_STATE  equ     $10
MSG_PLAY_CARD   equ     $20
MSG_DRAW_CARD   equ     $21
HEADER_SIZE     equ     16
PAYLOAD_START   equ     16
PAYLOAD_SIZE    equ     48

; =============================================================================
; Game States
; =============================================================================
STATE_TITLE     equ     0
STATE_CONNECT   equ     1
STATE_GAME      equ     2

; =============================================================================
; ROM Header at $0000
; =============================================================================
        org     $0000

; RST $00 - Reset
        di
        im      1
        jp      start

        org     $0008
; RST $08
        ret

        org     $0010
; RST $10
        ret

        org     $0018
; RST $18
        ret

        org     $0020
; RST $20
        ret

        org     $0028
; RST $28
        ret

        org     $0030
; RST $30
        ret

; NMI at $0066 (pause button on SMS)
        org     $0066
nmi_handler:
        retn

; =============================================================================
; Main Entry Point
; =============================================================================
        org     $0100

start:
        ; Disable interrupts
        di

        ; Set up stack
        ld      sp, $DFF0

        ; Initialize memory control
        ld      a, %10100000    ; Enable ROM, disable BIOS
        out     (IO_MEM_CTRL), a

        ; Initialize VDP
        call    vdp_init

        ; Initialize variables
        call    init_vars

        ; Initialize network
        call    net_init

        ; Show title
        call    show_title

        ; Set initial state
        ld      a, STATE_TITLE
        ld      (game_state), a

        ; Enable interrupts
        ei

; =============================================================================
; Main Loop
; =============================================================================
main_loop:
        ; Wait for VBlank
        call    wait_vblank

        ; Read joypad
        call    read_joypad

        ; Process current state
        ld      a, (game_state)
        cp      STATE_TITLE
        jp      z, handle_title
        cp      STATE_CONNECT
        jp      z, handle_connect
        cp      STATE_GAME
        jp      z, handle_game

        jp      main_loop

; =============================================================================
; State Handlers
; =============================================================================
handle_title:
        ; Check for button 1 press
        ld      a, (joypad_new)
        bit     JOY_BTN1, a
        jp      z, main_loop

        ; Start connection
        call    show_connecting
        ld      a, STATE_CONNECT
        ld      (game_state), a
        jp      main_loop

handle_connect:
        call    net_connect
        or      a
        jr      nz, fail

        call    send_hello
        ld      a, STATE_GAME
        ld      (game_state), a
        jp      main_loop

fail:
        call    show_title
        ld      a, STATE_TITLE
        ld      (game_state), a
        jp      main_loop

handle_game:
        call    net_recv
        or      a
        jr      nz, no_data

        call    rubp_validate
        or      a
        jr      nz, no_data

        call    get_message_type
        cp      MSG_GAME_STATE
        jr      nz, no_data

        call    process_game_state
        call    render_game

no_data:
        call    handle_game_input
        jp      main_loop

; =============================================================================
; Initialize Variables
; =============================================================================
init_vars:
        ; Clear RAM variables
        ld      hl, RAM_START
        ld      bc, 512
        xor     a
clear_loop_main:
        ld      (hl), a
        inc     hl
        dec     bc
        ld      a, b
        or      c
        jr      nz, clear_loop_main
        ret

; =============================================================================
; Wait for VBlank
; =============================================================================
wait_vblank:
        in      a, (VDP_STATUS)
        and     $80
        jr      z, wait_vblank
        ret

; =============================================================================
; Include other modules
; =============================================================================
        include "vdp.asm"
        include "input.asm"
        include "game.asm"
        include "rubp.asm"
        include "net/serial.asm"

; =============================================================================
; SMS ROM Header (at $7FF0 for 8KB, $3FF0 for 16KB, $1FF0 for 32KB)
; We'll use 32KB, so header at $7FF0
; =============================================================================
        org     $7FF0

; TMR SEGA header
        db      "TMR SEGA"      ; Magic string
        db      $00, $00        ; Reserved
        db      $00, $00        ; Checksum (filled by tool)
        db      $00             ; Product code (low)
        db      $00             ; Product code (high) / version
        db      $4C             ; Region/ROM size (4=SMS Export, C=32KB)
        db      $00             ; Unused

        end     start
