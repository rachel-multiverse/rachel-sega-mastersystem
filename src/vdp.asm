; =============================================================================
; SEGA MASTER SYSTEM VDP MODULE
; =============================================================================

; VDP register values
; Mode Control 1: No external sync, mode 4
; Mode Control 2: Display on, no sprites, VBlank IRQ
; Name table at $3800
; Sprite table at $3F00
; Sprite patterns at $0000
; Background color: 0
; H scroll: 0
; V scroll: 0

VDP_REG_DATA:
        db      $04             ; R0: Mode Control 1
        db      $E0             ; R1: display on, VBlank IRQ enabled
        db      $FF             ; R2: Name Table at $3800 (>>10 | $F1)
        db      $FF             ; R3: Color table (not used in mode 4)
        db      $FF             ; R4: Pattern generator (not used in mode 4)
        db      $FF             ; R5: Sprite attribute table at $3F00
        db      $FB             ; R6: Sprite pattern generator
        db      $00             ; R7: Border color (palette entry 0)
        db      $00             ; R8: H scroll
        db      $00             ; R9: V scroll
        db      $FF             ; R10: Line counter (disable)
VDP_REG_COUNT   equ     11

; Screen dimensions
SCREEN_COLS     equ     32
SCREEN_ROWS     equ     24

; Name table address
NAME_TABLE      equ     $3800

; =============================================================================
; Initialize VDP
; =============================================================================
vdp_init:
        ; Write VDP registers
        ld      hl, VDP_REG_DATA
        ld      b, VDP_REG_COUNT
        ld      c, 0            ; Register number
reg_loop:
        ld      a, (hl)
        out     (VDP_CTRL), a
        ld      a, c
        or      $80             ; Set register write bit
        out     (VDP_CTRL), a
        inc     hl
        inc     c
        djnz reg_loop

        ; Load font to VRAM
        call    load_font

        ; Clear name table
        call    clear_screen

        ; Set up palette
        call    init_palette
        ret

; =============================================================================
; Initialize Palette
; =============================================================================
init_palette:
        ; Set CRAM address 0
        xor     a
        out     (VDP_CTRL), a
        ld      a, $C0          ; CRAM write
        out     (VDP_CTRL), a

        ; Write palette (16 colors for background)
        ld      hl, palette_data
        ld      b, 16
pal_loop:
        ld      a, (hl)
        out     (VDP_DATA), a
        inc     hl
        djnz pal_loop
        ret

palette_data:
        db      $00             ; 0: Black (background)
        db      $3F             ; 1: White (text)
        db      $03             ; 2: Red
        db      $30             ; 3: Green
        db      $0C             ; 4: Blue
        db      $33             ; 5: Yellow
        db      $0F             ; 6: Cyan
        db      $3C             ; 7: Magenta
        db      $15             ; 8: Gray
        db      $00, $00, $00, $00, $00, $00, $00  ; 9-15: unused

; =============================================================================
; Load Font
; =============================================================================
load_font:
        ; Set VRAM address for tile patterns
        ; Tiles start at $0000 in mode 4
        ; Each tile is 32 bytes (8x8, 4bpp)
        ; We put our font at tile 32 (space = $20)
        ; Address = 32 * 32 = $0400
        ld      a, $00
        out     (VDP_CTRL), a
        ld      a, $44          ; $0400 with write bit
        out     (VDP_CTRL), a

        ; Copy font data (convert 1bpp to 4bpp)
        ld      hl, font_data
        ld      de, 96          ; 96 characters (32-127)
char_loop:
        ld      b, 8            ; 8 rows per character
row_loop:
        ld      a, (hl)
        ; Use colour index 1: glyph in plane 0, remaining planes clear.
        out     (VDP_DATA), a
        xor     a
        out     (VDP_DATA), a
        out     (VDP_DATA), a
        out     (VDP_DATA), a
        inc     hl
        djnz row_loop
        dec     de
        ld      a, d
        or      e
        jr      nz, char_loop
        ret

; =============================================================================
; Clear Screen
; =============================================================================
clear_screen:
        ; Set VRAM address for name table ($3800)
        ; Low byte = $00
        ld      a, $00
        out     (VDP_CTRL), a
        ; High byte = $38 AND $3F OR $40 = $78
        ld      a, $78
        out     (VDP_CTRL), a

        ; Fill with space tile (tile 32)
        ld      bc, SCREEN_COLS * SCREEN_ROWS * 2  ; 2 bytes per tile
        ld      a, 32           ; Space tile
clear_loop_vdp:
        out     (VDP_DATA), a
        xor     a               ; Attribute byte
        out     (VDP_DATA), a
        ld      a, 32
        dec     bc
        dec     bc
        ld      a, b
        or      c
        ld      a, 32
        jr      nz, clear_loop_vdp
        ret

; =============================================================================
; Set Cursor Position (B=X, C=Y)
; =============================================================================
set_cursor:
        ld      a, b
        ld      (cursor_x), a
        ld      a, c
        ld      (cursor_y), a
        ret

; =============================================================================
; Print String (HL = string address, null-terminated)
; =============================================================================
print_string:
        ; Calculate VRAM address: NAME_TABLE + (Y*32 + X) * 2
        push    hl
        ld      a, (cursor_y)
        ld      h, 0
        ld      l, a
        add     hl, hl          ; *2
        add     hl, hl          ; *4
        add     hl, hl          ; *8
        add     hl, hl          ; *16
        add     hl, hl          ; *32
        ld      a, (cursor_x)
        add     a, l
        ld      l, a
        add     hl, hl          ; *2 for 2 bytes per tile
        ld      bc, NAME_TABLE
        add     hl, bc

        ; Set VRAM address
        ld      a, l
        out     (VDP_CTRL), a
        ld      a, h
        and     $3F
        or      $40
        out     (VDP_CTRL), a
        pop     hl

print_loop:
        ld      a, (hl)
        or      a
        ret     z
        out     (VDP_DATA), a
        xor     a               ; Attribute
        out     (VDP_DATA), a
        inc     hl
        jr print_loop

; =============================================================================
; Print Character (A = char)
; =============================================================================
print_char:
        push    af
        push    hl
        push    bc

        ; Calculate VRAM address
        ld      a, (cursor_y)
        ld      h, 0
        ld      l, a
        add     hl, hl
        add     hl, hl
        add     hl, hl
        add     hl, hl
        add     hl, hl
        ld      a, (cursor_x)
        add     a, l
        ld      l, a
        add     hl, hl
        ld      bc, NAME_TABLE
        add     hl, bc

        ; Set VRAM address
        ld      a, l
        out     (VDP_CTRL), a
        ld      a, h
        and     $3F
        or      $40
        out     (VDP_CTRL), a

        pop     bc
        pop     hl
        pop     af
        out     (VDP_DATA), a
        xor     a
        out     (VDP_DATA), a

        ; Advance cursor
        ld      a, (cursor_x)
        inc     a
        ld      (cursor_x), a
        ret

; =============================================================================
; Show Title Screen
; =============================================================================
show_title:
        call    clear_screen

        ld      b, 6
        ld      c, 10
        call    set_cursor
        ld      hl, msg_title
        call    print_string

        ld      b, 6
        ld      c, 14
        call    set_cursor
        ld      hl, msg_press_start
        call    print_string
        ret

; =============================================================================
; Show Connecting Message
; =============================================================================
show_connecting:
        call    clear_screen

        ld      b, 8
        ld      c, 11
        call    set_cursor
        ld      hl, msg_connecting
        call    print_string
        ret

; =============================================================================
; Messages
; =============================================================================
msg_title:
        db      "RACHEL - SMS", 0

msg_press_start:
        db      "PRESS BUTTON 1", 0

msg_connecting:
        db      "CONNECTING...", 0

; =============================================================================
; Font Data (1bpp, 8x8, ASCII 32-127)
; =============================================================================
font_data:
; Space
        db      $00,$00,$00,$00,$00,$00,$00,$00
; !
        db      $18,$18,$18,$18,$18,$00,$18,$00
; "
        db      $6C,$6C,$00,$00,$00,$00,$00,$00
; #
        db      $6C,$FE,$6C,$6C,$FE,$6C,$00,$00
; $
        db      $18,$7E,$C0,$7C,$06,$FC,$18,$00
; %
        db      $C6,$CC,$18,$30,$66,$C6,$00,$00
; &
        db      $38,$6C,$38,$76,$DC,$76,$00,$00
; '
        db      $18,$18,$30,$00,$00,$00,$00,$00
; (
        db      $0C,$18,$30,$30,$30,$18,$0C,$00
; )
        db      $30,$18,$0C,$0C,$0C,$18,$30,$00
; *
        db      $00,$66,$3C,$FF,$3C,$66,$00,$00
; +
        db      $00,$18,$18,$7E,$18,$18,$00,$00
; ,
        db      $00,$00,$00,$00,$18,$18,$30,$00
; -
        db      $00,$00,$00,$7E,$00,$00,$00,$00
; .
        db      $00,$00,$00,$00,$00,$18,$18,$00
; /
        db      $06,$0C,$18,$30,$60,$C0,$00,$00
; 0
        db      $7C,$C6,$CE,$D6,$E6,$C6,$7C,$00
; 1
        db      $18,$38,$18,$18,$18,$18,$7E,$00
; 2
        db      $7C,$C6,$06,$1C,$30,$60,$FE,$00
; 3
        db      $7C,$C6,$06,$3C,$06,$C6,$7C,$00
; 4
        db      $1C,$3C,$6C,$CC,$FE,$0C,$0C,$00
; 5
        db      $FE,$C0,$FC,$06,$06,$C6,$7C,$00
; 6
        db      $3C,$60,$C0,$FC,$C6,$C6,$7C,$00
; 7
        db      $FE,$C6,$0C,$18,$30,$30,$30,$00
; 8
        db      $7C,$C6,$C6,$7C,$C6,$C6,$7C,$00
; 9
        db      $7C,$C6,$C6,$7E,$06,$0C,$78,$00
; :
        db      $00,$18,$18,$00,$18,$18,$00,$00
; ;
        db      $00,$18,$18,$00,$18,$18,$30,$00
; <
        db      $0C,$18,$30,$60,$30,$18,$0C,$00
; =
        db      $00,$00,$7E,$00,$7E,$00,$00,$00
; >
        db      $30,$18,$0C,$06,$0C,$18,$30,$00
; ?
        db      $7C,$C6,$0C,$18,$18,$00,$18,$00
; @
        db      $7C,$C6,$DE,$DE,$DC,$C0,$7C,$00
; A
        db      $38,$6C,$C6,$C6,$FE,$C6,$C6,$00
; B
        db      $FC,$C6,$C6,$FC,$C6,$C6,$FC,$00
; C
        db      $7C,$C6,$C0,$C0,$C0,$C6,$7C,$00
; D
        db      $F8,$CC,$C6,$C6,$C6,$CC,$F8,$00
; E
        db      $FE,$C0,$C0,$F8,$C0,$C0,$FE,$00
; F
        db      $FE,$C0,$C0,$F8,$C0,$C0,$C0,$00
; G
        db      $7C,$C6,$C0,$CE,$C6,$C6,$7C,$00
; H
        db      $C6,$C6,$C6,$FE,$C6,$C6,$C6,$00
; I
        db      $7E,$18,$18,$18,$18,$18,$7E,$00
; J
        db      $1E,$06,$06,$06,$C6,$C6,$7C,$00
; K
        db      $C6,$CC,$D8,$F0,$D8,$CC,$C6,$00
; L
        db      $C0,$C0,$C0,$C0,$C0,$C0,$FE,$00
; M
        db      $C6,$EE,$FE,$D6,$C6,$C6,$C6,$00
; N
        db      $C6,$E6,$F6,$DE,$CE,$C6,$C6,$00
; O
        db      $7C,$C6,$C6,$C6,$C6,$C6,$7C,$00
; P
        db      $FC,$C6,$C6,$FC,$C0,$C0,$C0,$00
; Q
        db      $7C,$C6,$C6,$C6,$D6,$CC,$76,$00
; R
        db      $FC,$C6,$C6,$FC,$D8,$CC,$C6,$00
; S
        db      $7C,$C6,$C0,$7C,$06,$C6,$7C,$00
; T
        db      $7E,$18,$18,$18,$18,$18,$18,$00
; U
        db      $C6,$C6,$C6,$C6,$C6,$C6,$7C,$00
; V
        db      $C6,$C6,$C6,$C6,$6C,$38,$10,$00
; W
        db      $C6,$C6,$C6,$D6,$FE,$EE,$C6,$00
; X
        db      $C6,$6C,$38,$38,$38,$6C,$C6,$00
; Y
        db      $66,$66,$66,$3C,$18,$18,$18,$00
; Z
        db      $FE,$0C,$18,$30,$60,$C0,$FE,$00
; [
        db      $3C,$30,$30,$30,$30,$30,$3C,$00
; \
        db      $C0,$60,$30,$18,$0C,$06,$00,$00
; ]
        db      $3C,$0C,$0C,$0C,$0C,$0C,$3C,$00
; ^
        db      $10,$38,$6C,$C6,$00,$00,$00,$00
; _
        db      $00,$00,$00,$00,$00,$00,$FE,$00
; `
        db      $30,$18,$0C,$00,$00,$00,$00,$00
; a-z (lowercase - just use uppercase patterns)
        db      $00,$00,$78,$0C,$7C,$CC,$76,$00
        db      $C0,$C0,$FC,$C6,$C6,$C6,$FC,$00
        db      $00,$00,$7C,$C6,$C0,$C6,$7C,$00
        db      $06,$06,$7E,$C6,$C6,$C6,$7E,$00
        db      $00,$00,$7C,$C6,$FE,$C0,$7C,$00
        db      $1C,$30,$7C,$30,$30,$30,$30,$00
        db      $00,$00,$7E,$C6,$C6,$7E,$06,$7C
        db      $C0,$C0,$FC,$C6,$C6,$C6,$C6,$00
        db      $18,$00,$38,$18,$18,$18,$3C,$00
        db      $0C,$00,$0C,$0C,$0C,$0C,$CC,$78
        db      $C0,$C0,$CC,$D8,$F0,$D8,$CC,$00
        db      $38,$18,$18,$18,$18,$18,$3C,$00
        db      $00,$00,$EC,$FE,$D6,$C6,$C6,$00
        db      $00,$00,$FC,$C6,$C6,$C6,$C6,$00
        db      $00,$00,$7C,$C6,$C6,$C6,$7C,$00
        db      $00,$00,$FC,$C6,$C6,$FC,$C0,$C0
        db      $00,$00,$7E,$C6,$C6,$7E,$06,$06
        db      $00,$00,$DC,$E6,$C0,$C0,$C0,$00
        db      $00,$00,$7C,$C0,$7C,$06,$7C,$00
        db      $30,$30,$7C,$30,$30,$30,$1C,$00
        db      $00,$00,$C6,$C6,$C6,$C6,$7E,$00
        db      $00,$00,$C6,$C6,$6C,$38,$10,$00
        db      $00,$00,$C6,$C6,$D6,$FE,$6C,$00
        db      $00,$00,$C6,$6C,$38,$6C,$C6,$00
        db      $00,$00,$C6,$C6,$C6,$7E,$06,$7C
        db      $00,$00,$FE,$0C,$38,$60,$FE,$00
; { | } ~ DEL
        db      $0E,$18,$18,$70,$18,$18,$0E,$00
        db      $18,$18,$18,$18,$18,$18,$18,$00
        db      $70,$18,$18,$0E,$18,$18,$70,$00
        db      $76,$DC,$00,$00,$00,$00,$00,$00
        db      $00,$00,$00,$00,$00,$00,$00,$00
