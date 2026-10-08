; =============================================================================
; SEGA MASTER SYSTEM SERIAL MODULE
; =============================================================================

; The SMS has an EXT port that can be used for serial communication
; In practice, a custom adapter would connect to an ESP8266 or similar

; I/O ports for serial (theoretical - would need custom hardware)
SERIAL_DATA     equ     $F0
SERIAL_CTRL     equ     $F1
SERIAL_STATUS   equ     $F2

; =============================================================================
; Initialize Network
; =============================================================================
net_init:
        ; Initialize serial (placeholder)
        ret

; =============================================================================
; Connect to Server
; Returns: A = 0 on success, non-zero on failure
; =============================================================================
net_connect:
        ; Send AT+CIPSTART
        ld      hl, at_cipstart
        call    send_at_string

        ; Send IP
        ld      hl, ip_string
        call    send_at_string

        ; Send port
        ld      hl, at_port
        call    send_at_string

        ; Wait for OK
        call    wait_response
        ret

; =============================================================================
; Send AT String (HL = null-terminated string)
; =============================================================================
send_at_string:
loop:
        ld      a, (hl)
        or      a
        ret     z
        call    serial_write_byte
        inc     hl
        jr loop

; =============================================================================
; Write Byte via Serial (A = byte)
; =============================================================================
serial_write_byte:
        push    af
        ; Wait for TX ready
wait_tx:
        in      a, (SERIAL_STATUS)
        bit     0, a
        jr      z, wait_tx
        pop     af
        out     (SERIAL_DATA), a
        ret

; =============================================================================
; Read Byte via Serial
; Returns: A = byte, carry set on timeout
; =============================================================================
serial_read_byte:
        push    bc              ; Caller owns frame/response loop counters
        ld      bc, 10000
wait_rx:
        in      a, (SERIAL_STATUS)
        bit     1, a
        jr      nz, got_data
        dec     bc
        ld      a, b
        or      c
        jr      nz, wait_rx
        scf                     ; Timeout
        pop     bc              ; POP preserves A and carry
        ret
got_data:
        in      a, (SERIAL_DATA)
        or      a               ; Clear carry
        pop     bc              ; POP preserves A and carry
        ret

; =============================================================================
; Wait for OK Response
; Returns: A = 0 on success, 1 on timeout
; =============================================================================
wait_response:
        ld      b, 200
wait_loop:
        call    serial_read_byte
        jr      c, next_try
        cp      'O'
        jr      nz, next_try
        call    serial_read_byte
        jr      c, next_try
        cp      'K'
        jr      nz, next_try
        xor     a
        ret
next_try:
        djnz wait_loop
        ld      a, 1
        ret

; =============================================================================
; Send 64-byte Buffer
; =============================================================================
net_send:
        ; Send AT+CIPSEND
        ld      hl, at_cipsend
        call    send_at_string

        ; ESP-AT accepts payload only after the send prompt.
wait_send_prompt:
        call    serial_read_byte
        jr      c, wait_send_prompt
        cp      '>'
        jr      nz, wait_send_prompt

        ; Send buffer
        ld      hl, net_buffer_tx
        ld      b, 64
send_loop:
        ld      a, (hl)
        call    serial_write_byte
        inc     hl
        djnz send_loop
        ret

; =============================================================================
; Receive 64-byte Buffer
; Returns: A = 0 on success, 1 on partial, 2 on no data
; =============================================================================
net_recv:
        ; Strip +IPD/status text by synchronising on the RUBP magic.
find_magic_r:
        call    serial_read_byte
        jr      c, recv_no_data
check_magic_r:
        cp      'R'
        jr      nz, find_magic_r
        ld      hl, net_buffer_rx
        ld      (hl), a
        inc     hl
        call    serial_read_byte
        jr      c, recv_no_data
        cp      'A'
        jr      nz, check_magic_r
        ld      (hl), a
        inc     hl
        call    serial_read_byte
        jr      c, recv_no_data
        cp      'C'
        jr      nz, check_magic_r
        ld      (hl), a
        inc     hl
        call    serial_read_byte
        jr      c, recv_no_data
        cp      'H'
        jr      nz, check_magic_r
        ld      (hl), a
        inc     hl

        ld      b, 60
recv_loop:
        call    serial_read_byte
        jr      c, recv_partial
        ld      (hl), a
        inc     hl
        djnz    recv_loop
        xor     a               ; Success
        ret
recv_partial:
        ld      a, 1            ; Partial
        ret
recv_no_data:
        ld      a, 2
        ret

; =============================================================================
; Close Connection
; =============================================================================
net_close:
        ld      hl, at_cipclose
        call    send_at_string
        ret

; =============================================================================
; Data
; =============================================================================
at_cipstart:
        db      "AT+CIPSTART=", $22, "TCP", $22, ",", $22, 0
at_port:
        db      $22, ",6502", 13, 0
at_cipsend:
        db      "AT+CIPSEND=64", 13, 0
at_cipclose:
        db      "AT+CIPCLOSE", 13, 0
ip_string:
        db      "192.168.1.100", 0

; =============================================================================
; RAM Variables (defined as EQU to avoid binary padding)
; =============================================================================
game_state      equ     RAM_START + 0
joypad          equ     RAM_START + 1
joypad_old      equ     RAM_START + 2
joypad_new      equ     RAM_START + 3
cursor_x        equ     RAM_START + 4
cursor_y        equ     RAM_START + 5
msg_sequence    equ     RAM_START + 6     ; 2 bytes
player_id       equ     RAM_START + 8     ; 2 bytes, little-endian in RAM
game_id         equ     RAM_START + 10    ; 2 bytes, little-endian in RAM

; RUBP buffers
net_buffer_tx   equ     RAM_START + 12
net_buffer_rx   equ     RAM_START + 76

; Game state
current_turn    equ     RAM_START + 140
my_index        equ     RAM_START + 141
discard_top     equ     RAM_START + 142
current_suit    equ     RAM_START + 143
draw_count      equ     RAM_START + 144
hand_count      equ     RAM_START + 145
hand_cursor     equ     RAM_START + 146
nominated_suit  equ     RAM_START + 147
selected_count  equ     RAM_START + 148
state_hash_valid equ    RAM_START + 149
state_hash      equ     RAM_START + 150   ; 8 bytes
hand_cards      equ     RAM_START + 158   ; 32 bytes
hand_selected   equ     RAM_START + 190   ; 32 bytes
