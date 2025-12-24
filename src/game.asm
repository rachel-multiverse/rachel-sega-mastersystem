; =============================================================================
; SEGA MASTER SYSTEM GAME MODULE
; =============================================================================

; =============================================================================
; Process Game State from Network
; =============================================================================
process_game_state:
        ld      hl, net_buffer_rx + PAYLOAD_START
        ld      a, (hl)
        ld      (current_turn), a
        inc     hl
        ld      a, (hl)
        ld      (my_index), a
        inc     hl
        ld      a, (hl)
        ld      (discard_top), a
        inc     hl
        ld      a, (hl)
        ld      (current_suit), a
        inc     hl
        ld      a, (hl)
        ld      (draw_count), a
        inc     hl
        ld      a, (hl)
        ld      (hand_count), a
        inc     hl

        ; Copy hand cards
        ld      de, hand_cards
        ld      b, 20
copy_hand:
        ld      a, (hl)
        ld      (de), a
        inc     hl
        inc     de
        djnz copy_hand

        ; Clear selection
        ld      hl, hand_selected
        ld      b, 20
        xor     a
clear_sel:
        ld      (hl), a
        inc     hl
        djnz clear_sel

        xor     a
        ld      (hand_cursor), a
        ret

; =============================================================================
; Render Game
; =============================================================================
render_game:
        call    clear_screen

        ; Discard pile
        ld      b, 1
        ld      c, 2
        call    set_cursor
        ld      hl, lbl_discard
        call    print_string
        ld      a, (discard_top)
        call    print_card

        ; Current suit
        ld      b, 1
        ld      c, 4
        call    set_cursor
        ld      hl, lbl_suit
        call    print_string
        ld      a, (current_suit)
        call    print_suit

        ; Draw count
        ld      a, (draw_count)
        or      a
        jr      z, no_draw_count
        ld      b, 1
        ld      c, 6
        call    set_cursor
        ld      hl, lbl_draw
        call    print_string
        ld      a, (draw_count)
        call    print_decimal

no_draw_count:
        ; Render hand
        call    render_hand

        ; Status
        ld      b, 0
        ld      c, 20
        call    set_cursor
        ld      a, (current_turn)
        ld      b, a
        ld      a, (my_index)
        cp      b
        jr      nz, show_waiting
        ld      hl, lbl_your_turn
        jr show_status
show_waiting:
        ld      hl, lbl_waiting
show_status:
        call    print_string
        ret

; =============================================================================
; Render Hand
; =============================================================================
render_hand:
        ld      b, 0
        ld      c, 14
        call    set_cursor

        ld      a, (hand_count)
        or      a
        ret     z

        push    af
        ld      de, hand_cards
        ld      hl, hand_selected
        xor     a
        ld      c, a            ; Index

render_loop:
        push    bc
        push    hl
        push    de

        ; Cursor indicator
        ld      a, (hand_cursor)
        cp      c
        jr      nz, no_cursor
        ld      a, '['
        call    print_char
        jr show_card
no_cursor:
        ld      a, ' '
        call    print_char

show_card:
        pop     de
        push    de
        ld      a, (de)
        call    print_card

        ; Selected indicator
        pop     de
        pop     hl
        push    hl
        push    de
        ld      a, (hl)
        or      a
        jr      z, not_sel
        ld      a, '*'
        call    print_char
        jr next_card
not_sel:
        ld      a, ' '
        call    print_char

next_card:
        pop     de
        inc     de
        pop     hl
        inc     hl
        pop     bc
        inc     c
        dec     b
        jr      nz, render_loop
        pop     af
        ret

; =============================================================================
; Print Card (A = card byte)
; =============================================================================
print_card:
        push    af
        srl     a
        srl     a               ; Divide by 4 for rank
        ld      hl, ranks
        add     a, l
        ld      l, a
        ld      a, (hl)
        call    print_char
        pop     af
        and     $03
        call    print_suit
        ret

; =============================================================================
; Print Suit (A = 0-3)
; =============================================================================
print_suit:
        ld      hl, suits
        add     a, l
        ld      l, a
        ld      a, (hl)
        call    print_char
        ret

; =============================================================================
; Print Decimal (A = 0-99)
; =============================================================================
print_decimal:
        ld      b, 0
tens:
        cp      10
        jr      c, print_ones
        sub     10
        inc     b
        jr tens
print_ones:
        push    af
        ld      a, b
        or      a
        jr      z, skip_tens
        add     a, '0'
        call    print_char
skip_tens:
        pop     af
        add     a, '0'
        call    print_char
        ret

; =============================================================================
; Handle Game Input
; =============================================================================
handle_game_input:
        ; Left
        ld      a, (joypad_new)
        bit     JOY_LEFT, a
        jr      z, not_left
        ld      a, (hand_cursor)
        or      a
        jr      z, not_left
        dec     a
        ld      (hand_cursor), a
        call    render_game
not_left:

        ; Right
        ld      a, (joypad_new)
        bit     JOY_RIGHT, a
        jr      z, not_right
        ld      a, (hand_cursor)
        ld      b, a
        ld      a, (hand_count)
        dec     a
        cp      b
        jr      z, not_right
        jr      c, not_right
        ld      a, (hand_cursor)
        inc     a
        ld      (hand_cursor), a
        call    render_game
not_right:

        ; Button 1 = select
        ld      a, (joypad_new)
        bit     JOY_BTN1, a
        jr      z, not_select
        ld      a, (hand_cursor)
        ld      hl, hand_selected
        add     a, l
        ld      l, a
        ld      a, (hl)
        xor     $FF
        ld      (hl), a
        call    render_game
not_select:

        ; Button 2 = play
        ld      a, (joypad_new)
        bit     JOY_BTN2, a
        jr      z, not_play
        call    play_selected_cards
not_play:

        ; Up = draw
        ld      a, (joypad_new)
        bit     JOY_UP, a
        jr      z, not_draw
        call    send_draw
not_draw:
        ret

; =============================================================================
; Play Selected Cards
; =============================================================================
play_selected_cards:
        ld      hl, hand_selected
        ld      de, hand_cards
        ld      a, (hand_count)
        or      a
        ret     z
        ld      b, a
find_sel:
        ld      a, (hl)
        or      a
        jr      nz, found_sel
        inc     hl
        inc     de
        djnz find_sel
        ret
found_sel:
        ld      a, (de)
        call    send_play_card
        ret

; =============================================================================
; Data
; =============================================================================
ranks:
        db      "A23456789TJQK"
suits:
        db      "HDCS"

lbl_discard:
        db      "DISC:", 0
lbl_suit:
        db      "SUIT:", 0
lbl_draw:
        db      "DRAW:", 0
lbl_your_turn:
        db      "YOUR TURN 1/2/UP", 0
lbl_waiting:
        db      "WAITING...", 0
