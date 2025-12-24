; =============================================================================
; SEGA MASTER SYSTEM RUBP PROTOCOL MODULE
; =============================================================================

; =============================================================================
; Build Header (A = message type)
; =============================================================================
build_header:
        push    af
        ld      hl, net_buffer_tx

        ; Magic "RACH"
        ld      a, 'R'
        ld      (hl), a
        inc     hl
        ld      a, 'A'
        ld      (hl), a
        inc     hl
        ld      a, 'C'
        ld      (hl), a
        inc     hl
        ld      a, 'H'
        ld      (hl), a
        inc     hl

        ; Version
        ld      a, RUBP_VERSION
        ld      (hl), a
        inc     hl

        ; Message type
        pop     af
        ld      (hl), a
        inc     hl

        ; Sequence
        ld      a, (msg_sequence)
        ld      (hl), a
        inc     a
        ld      (msg_sequence), a
        inc     hl

        ; Flags + reserved (9 bytes)
        xor     a
        ld      b, 9
clear_reserved:
        ld      (hl), a
        inc     hl
        djnz clear_reserved
        ret

; =============================================================================
; Clear Payload
; =============================================================================
clear_payload:
        ld      hl, net_buffer_tx + PAYLOAD_START
        ld      b, PAYLOAD_SIZE
        xor     a
clear_loop_rubp:
        ld      (hl), a
        inc     hl
        djnz    clear_loop_rubp
        ret

; =============================================================================
; Send HELLO
; =============================================================================
send_hello:
        ld      a, MSG_HELLO
        call    build_header
        call    clear_payload

        ; Copy player name
        ld      hl, player_name
        ld      de, net_buffer_tx + PAYLOAD_START
        ld      b, 16
copy_name:
        ld      a, (hl)
        ld      (de), a
        inc     hl
        inc     de
        djnz copy_name

        ; Platform ID
        ld      a, PLATFORM_ID_HI
        ld      (net_buffer_tx + PAYLOAD_START + 16), a
        ld      a, PLATFORM_ID_LO
        ld      (net_buffer_tx + PAYLOAD_START + 17), a

        call    net_send
        ret

; =============================================================================
; Send DRAW
; =============================================================================
send_draw:
        ld      a, MSG_DRAW_CARD
        call    build_header
        call    clear_payload
        call    net_send
        ret

; =============================================================================
; Send PLAY_CARD (A = card)
; =============================================================================
send_play_card:
        push    af
        ld      a, MSG_PLAY_CARD
        call    build_header
        call    clear_payload
        pop     af
        ld      (net_buffer_tx + PAYLOAD_START), a
        call    net_send
        ret

; =============================================================================
; Validate RUBP (returns A=0 if valid)
; =============================================================================
rubp_validate:
        ld      hl, net_buffer_rx
        ld      a, (hl)
        cp      'R'
        jr      nz, invalid
        inc     hl
        ld      a, (hl)
        cp      'A'
        jr      nz, invalid
        inc     hl
        ld      a, (hl)
        cp      'C'
        jr      nz, invalid
        inc     hl
        ld      a, (hl)
        cp      'H'
        jr      nz, invalid
        xor     a
        ret
invalid:
        ld      a, 1
        ret

; =============================================================================
; Get Message Type (returns A)
; =============================================================================
get_message_type:
        ld      a, (net_buffer_rx + 5)
        ret

; =============================================================================
; Data
; =============================================================================
player_name:
        db      "MASTER SYS", 0, 0, 0, 0, 0, 0
