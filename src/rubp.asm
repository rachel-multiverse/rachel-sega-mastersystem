; =============================================================================
; SEGA MASTER SYSTEM RUBP PROTOCOL MODULE
; =============================================================================

; =============================================================================
; Build Header (A = message type)
; =============================================================================
build_header:
        push    af
        ld      hl, net_buffer_tx

        ld      b, 64
        xor     a
clear_message_rubp:
        ld      (hl), a
        inc     hl
        djnz    clear_message_rubp
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

        ; Sequence, player ID and game ID are 16-bit big-endian.
        ld      a, (msg_sequence + 1)
        ld      (hl), a
        inc     hl
        ld      a, (msg_sequence)
        ld      (hl), a
        inc     a
        ld      (msg_sequence), a
        jr      nz, no_sequence_carry
        ld      a, (msg_sequence + 1)
        inc     a
        ld      (msg_sequence + 1), a
no_sequence_carry:
        inc     hl
        ld      a, (player_id + 1)
        ld      (hl), a
        inc     hl
        ld      a, (player_id)
        ld      (hl), a
        inc     hl
        ld      a, (game_id + 1)
        ld      (hl), a
        inc     hl
        ld      a, (game_id)
        ld      (hl), a
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

        ; RachelSpec v1
        xor     a
        ld      (net_buffer_tx + PAYLOAD_START + 18), a
        inc     a
        ld      (net_buffer_tx + PAYLOAD_START + 19), a

        call    net_send
        ret

; =============================================================================
; Send DRAW
; =============================================================================
send_draw:
        ld      a, MSG_DRAW_CARD
        call    build_header
        call    clear_payload
        ; reason=0, count=1, RachelSpec v1
        ld      a, 1
        ld      (net_buffer_tx + PAYLOAD_START + 1), a
        ld      (net_buffer_tx + PAYLOAD_START + 3), a
        call    add_hash_to_draw
        call    net_send
        ret

; =============================================================================
; Send PLAY_CARD (A = nominated suit, $FF for none)
; =============================================================================
send_play_card:
        push    af
        ld      a, MSG_PLAY_CARD
        call    build_header
        call    clear_payload
        pop     af
        ld      (net_buffer_tx + PAYLOAD_START + 33), a
        ld      a, 1
        ld      (net_buffer_tx + PAYLOAD_START + 35), a
        call    add_hash_to_play

        xor     a
        ld      (selected_count), a
        ld      c, 0
        ld      a, (hand_count)
        ld      b, a
copy_selected:
        ld      a, b
        or      a
        jr      z, selected_done
        ld      hl, hand_selected
        ld      a, c
        add     a, l
        ld      l, a
        jr      nc, selected_addr_ready
        inc     h
selected_addr_ready:
        ld      a, (hl)
        or      a
        jr      z, next_selected
        ld      hl, hand_cards
        ld      a, c
        add     a, l
        ld      l, a
        jr      nc, source_addr_ready
        inc     h
source_addr_ready:
        ld      a, (hl)
        push    af
        ld      hl, net_buffer_tx + PAYLOAD_START + 1
        ld      a, (selected_count)
        ld      c, a
        add     a, l
        ld      l, a
        jr      nc, dest_addr_ready
        inc     h
dest_addr_ready:
        pop     af
        ld      (hl), a
        ld      a, (selected_count)
        inc     a
        ld      (selected_count), a
next_selected:
        ld      a, (hand_count)
        sub     b
        inc     a
        ld      c, a
        djnz    copy_selected
selected_done:
        ld      a, (selected_count)
        ld      (net_buffer_tx + PAYLOAD_START), a
        call    net_send
        ret

add_hash_to_play:
        ld      a, (state_hash_valid)
        or      a
        ret     z
        ld      a, 1
        ld      (net_buffer_tx + PAYLOAD_START + 36), a
        ld      hl, state_hash
        ld      de, net_buffer_tx + PAYLOAD_START + 37
        jr      copy_state_hash

add_hash_to_draw:
        ld      a, (state_hash_valid)
        or      a
        ret     z
        ld      a, 1
        ld      (net_buffer_tx + PAYLOAD_START + 4), a
        ld      hl, state_hash
        ld      de, net_buffer_tx + PAYLOAD_START + 5
copy_state_hash:
        ld      b, 8
copy_hash_out:
        ld      a, (hl)
        ld      (de), a
        inc     hl
        inc     de
        djnz    copy_hash_out
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
        ld      a, (net_buffer_rx + 4)
        cp      RUBP_VERSION
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
; Incoming payload parsers
; =============================================================================
parse_welcome:
        ld      a, (net_buffer_rx + PAYLOAD_START)
        ld      (player_id + 1), a
        ld      a, (net_buffer_rx + PAYLOAD_START + 1)
        ld      (player_id), a
        ld      (my_index), a
        ld      a, (net_buffer_rx + PAYLOAD_START + 2)
        ld      (game_id + 1), a
        ld      a, (net_buffer_rx + PAYLOAD_START + 3)
        ld      (game_id), a
        ret

parse_game_state:
        ld      a, (net_buffer_rx + PAYLOAD_START)
        ld      (current_turn), a
        ld      a, (net_buffer_rx + PAYLOAD_START + 2)
        ld      (discard_top), a
        ld      a, (net_buffer_rx + PAYLOAD_START + 3)
        ld      (current_suit), a
        ld      a, (net_buffer_rx + PAYLOAD_START + 4)
        ld      (draw_count), a
        xor     a
        ld      (state_hash_valid), a
        ld      a, (net_buffer_rx + PAYLOAD_START + 23)
        and     1
        ret     z
        ld      hl, net_buffer_rx + PAYLOAD_START + 24
        ld      de, state_hash
        ld      b, 8
copy_hash_in:
        ld      a, (hl)
        ld      (de), a
        inc     hl
        inc     de
        djnz    copy_hash_in
        ld      a, 1
        ld      (state_hash_valid), a
        ret

parse_hand_replace:
        xor     a
        ld      (hand_count), a
        ld      (hand_cursor), a
        ld      hl, hand_selected
        ld      b, 32
clear_hand_selection:
        ld      (hl), a
        inc     hl
        djnz    clear_hand_selection
        ; fall through
parse_card_drawn:
        ld      a, (net_buffer_rx + PAYLOAD_START)
        ld      b, a
        ld      hl, net_buffer_rx + PAYLOAD_START + 1
append_card:
        ld      a, b
        or      a
        ret     z
        ld      a, (hand_count)
        cp      32
        ret     nc
        push    hl
        ld      e, a
        ld      d, 0
        ld      hl, hand_cards
        add     hl, de
        ex      de, hl
        pop     hl
        ld      a, (hl)
        ld      (de), a
        inc     hl
        ld      a, (hand_count)
        inc     a
        ld      (hand_count), a
        djnz    append_card
        ret

; =============================================================================
; Data
; =============================================================================
player_name:
        db      "MASTER SYS", 0, 0, 0, 0, 0, 0
