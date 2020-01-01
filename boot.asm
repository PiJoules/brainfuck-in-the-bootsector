;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Prompt Layout (80x25)
;
; The first line of the prompt is dedicated to output from the BF code.
; The rest of the prompt starting from the second row to the last row
; (25th / row 24), will be dedicated to BF code to be interpretted. This means
; the maximum number of characters that our BF code can be is 79x25-1 = 1974
; characters. (We don't check the very bottom right one to save code space.)
; Anything more than that will not be interpretted in the program.
;
; WARNING: Do not excede the character limit bc I did not bounds-check it to
; save space.
;
; ----------------------------------------------------------------------------------
; |Output>                                                                         |
; |*BF code starts here* Hello world example:                                      |
; |++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.++|
; |+.------.--------.>>+.>++.                                                      |
; |                                                                                |
; |                                                                                |
; |                                                                                |
; |                                                                                |
; |                                                                                |
; |                                                                                |
; |                                                                                |
; |                                                                                |
; |                                                                                |
; |                                                                                |
; |                                                                                |
; |                                                                                |
; |                                                                                |
; |                                                                                |
; |                                                                                |
; |                                                                                |
; |                                                                                |
; |                                                                                |
; |                                                                                |
; |                                                                                |
; |                                                                                |
; ----------------------------------------------------------------------------------
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

[bits 16]
[org 0x7c00]

%define NEWLINE 0x0a
%define CARRIAGE_RETURN 0xd
%define BACKSPACE 0x8
%define SPACE ' '
%define TILDA '~'

%define WIDTH 80
%define HEIGHT 25
%define INPUT_ROW 1
%define UPPERLEFT_OUTPUT_WINDOW_COORD 0x0000  ; row 0, col 0
%define BOTTOMRIGHT_INPUT_WINDOW_COORD 0x184f  ; row 24, col 79
%define WHITE_ON_BLACK 0x0f
%define PROMPT_LENGTH 8

  jmp entry

; Uncomment these for debugging
;%include "debugging/print_hex.asm"
;%include "debugging/pause.asm"

; Args: None
; Ret:
; - dh: row
; - dl: col
get_cursor_pos:
  mov bh, 0
  mov ah, 3
  int 0x10
  ret

; Args:
; - dh: row
; - dl: col
; Ret: None
set_cursor_pos:
  mov bh, 0
  mov ah, 2
  int 0x10
  ret

; Args: None
; Ret: None
move_cursor_back:
  ; Move back 1 char
  call get_cursor_pos

  cmp dl, 0
  je move_back_one_row

  dec dl
  jmp move_cursor_back_set_pos

move_back_one_row:
  ; If we are on the first row, then we don't need to do anything.
  cmp dh, INPUT_ROW
  jle move_cursor_back_end

  dec dh
  mov dl, WIDTH-1

move_cursor_back_set_pos:
  call set_cursor_pos
move_cursor_back_end:
  ret

; Args: None
; Ret:
; - ah: Scan code of the key pressed down
; - al: Character ascii
read_char:
  mov ah, 0
  int 0x16
  ret

; Args: None
; Ret:
; - ah: Character attributes
; - al: Character ascii
read_char_at_cursor:
  mov ah, 8
  mov bh, 0
  int 0x10
  ret

; Args: None
; Ret:
; - ah: Character attributes
; - al: Character ascii
get_next_instr_and_move_cursor:
  call get_cursor_pos

  cmp dl, WIDTH-1
  je move_to_next_row
  inc dl
  jmp final_set_cursor

move_to_next_row:
  mov dl, 0
  inc dh

final_set_cursor:
  call set_cursor_pos

  ; Read the new instruction
  call read_char_at_cursor
  ret

; Args: None
; Ret:
; - ah: Character attributes
; - al: Character ascii
get_prev_instr_and_move_cursor:
  call move_cursor_back
  call read_char_at_cursor
  ret

interpret:
  ; We will only be using the lower halves of these, but zero them out anyway.
  mov edx, 0
  mov eax, 0

  mov dh, INPUT_ROW
  call set_cursor_pos
  call read_char_at_cursor
.condition:
  ; Stop on the end of the screen
  call get_cursor_pos
  cmp dh, HEIGHT-1
  jne .loop  ; Not on the last row
  cmp dl, WIDTH-1
  je .exit   ; Are on the last row and col

.loop:
  ; Initial load of the tape pointer
  mov dx, word[tape_ptr]

.PLUS:
  cmp al, '+'
  jne .MINUS
  inc byte[edx]
  jmp .doneRecognizingChar

.MINUS:
  cmp al, '-'
  jne .LEFT_POINTY_BRACKET
  dec byte[edx]
  jmp .doneRecognizingChar

.LEFT_POINTY_BRACKET:
  cmp al, '<'
  jne .RIGHT_POINTY_BRACKET
  dec word[tape_ptr]
  jmp .doneRecognizingChar

.RIGHT_POINTY_BRACKET:
  cmp al, '>'
  jne .LEFT_BRACKET
  inc word[tape_ptr]
  jmp .doneRecognizingChar

.LEFT_BRACKET:
; if (*tape_ptr == 0) {
;   int *level = new int; *level = 0;
;   while (true) {
;     c++;
;     if (*c == '[') level++;
;     else if (*c == ']') {
;       if (*level == 0) break;
;       else *level--;
;     }
;   }
;   free level;
; }
  cmp al, '['
  jne .RIGHT_BRACKET
  mov dx, word[tape_ptr]
  cmp byte[edx], 0
  jnz .doneRecognizingChar;
  mov si, 0
.searchRBLoop:
  call get_next_instr_and_move_cursor
  cmp al, '['
  jne .searchRB_notLB
  inc si
.searchRB_notLB:
  cmp al, ']'
  jne .searchRB_nothing
  cmp si, 0
  jne .searchRB_levelNotZero
  jmp .searchRB_end
.searchRB_levelNotZero:
  dec si
.searchRB_nothing:
  jmp .searchRBLoop
.searchRB_end:
  jmp .doneRecognizingChar

.RIGHT_BRACKET:
; if (*tape_ptr != 0) {
;   int *level = new int; *level = 0;
;   while (true) {
;     c--;
;     if (*c == ']') level++;
;     else if (*c == '[') {
;       if (*level == 0) break;
;       else *level--;
;     }
;   }
;   free level;
; }
  cmp al, ']'
  jne .DOT
  mov dx, word[tape_ptr]
  cmp byte[edx], 0
  jz .doneRecognizingChar;
  mov si, 0
.searchLBLoop:
  call get_prev_instr_and_move_cursor
  cmp al, ']'
  jne .searchLB_notRB
  inc si
.searchLB_notRB:
  cmp al, '['
  jne .searchLB_nothing
  cmp si, 0
  jne .searchLB_levelNotZero
  jmp .searchLB_end ; done
.searchLB_levelNotZero:
  dec si
.searchLB_nothing:
  jmp .searchLBLoop
.searchLB_end:
  jmp .doneRecognizingChar

.DOT:
  cmp al, '.'
  jne .COMMA

  mov al, byte[edx]
  call print_char_at_output
  jmp .doneRecognizingChar

.COMMA:
  cmp al, ','
  jne .doneRecognizingChar
  call read_char
  mov [edx], al

.doneRecognizingChar:
  call get_next_instr_and_move_cursor
  jmp .condition

.exit:
  ret

print_char_at_output:
  ; Go to the output cursor position, write, then go back to the previous
  ; cursor position.
  call get_cursor_pos
  push dx

  ; If the output reached the end of the line, rewrite back to the start of
  ; the line. This will overwrite any previous text.
  mov dh, 0
  mov dl, [output_cursor_pos]

  cmp dl, WIDTH-1
  jne handle_char
  mov dl, PROMPT_LENGTH

handle_char:
  ; To prevent manipulation of the cursor from moving in a direction other than
  ; right, only print characters from 32 (space) to 126 (~).
  cmp al, SPACE
  jl print_space
  cmp al, TILDA
  jg print_space

  jmp move_to_output_start

print_space:
  mov al, SPACE  ; Just print space as a substitute.

  ; Move to output pos
move_to_output_start:
  call set_cursor_pos

  ; Print
  call print_char

  ; Save output cursor position
  call get_cursor_pos
  mov [output_cursor_pos], dl

  ; Restore the old cursor position
  pop dx
  call set_cursor_pos
  ret

print_char:
  mov ah, 0x0e

  ; Carriage return is found on hitting 'ENTER'
  cmp al, CARRIAGE_RETURN
  jne print_char_end

  int 0x10
  mov al, NEWLINE

print_char_end:
  int 0x10
  ret

;;;;;;;;; print ;;;;;;;;;;
print:
  ; the comparison for string end (null byte)
print_start:
  mov al, [edx] ; 'edx' is the base address for the string
  cmp al, 0
  je print_done

  call print_char

  ; increment pointer and do next loop
  inc dx
  jmp print_start
print_done:
  ret

;;;;; entry ;;;;;
entry:
  ; Clear screen
  ; See https://en.wikipedia.org/wiki/INT_10H for args
  mov dx, BOTTOMRIGHT_INPUT_WINDOW_COORD
  mov cx, UPPERLEFT_OUTPUT_WINDOW_COORD
  mov bh, WHITE_ON_BLACK
  mov ax, 0x0600
  int 0x10

  ; Move cursor to top left window
  mov dx, 0
  call set_cursor_pos

  mov dx, prompt
  call print

  ; Remember the location of the output cursor
  call get_cursor_pos
  mov [output_cursor_pos], dl

  ; Move to 2nd row
  mov dx, 0x0100
  call set_cursor_pos

entry_read_key:
  ; Read the character and store it in AL
  call read_char

  ; ASCII character stored in al. If it is a carriage return (ENTER key), then
  ; evaluate the instructions on the screen before the key was hit and after
  ; the prompt start.
  cmp al, CARRIAGE_RETURN
  je entry_newline
  cmp al, BACKSPACE
  je entry_backspace

  ; Continue to print the character
  call print_char
  jmp entry_read_key

entry_newline:
  ; Save cursor position
  call get_cursor_pos
  push dx

  ; Run the intepretter
  call interpret

  ; Move back to previous position
  pop dx
  call set_cursor_pos

  jmp entry_read_key

entry_backspace:
  call move_cursor_back

  ; Delete the char
  mov cx, 1  ; Print once
  mov ah, 0x09
  mov al, SPACE
  int 0x10

  jmp entry_read_key

;;;;; MEMORY ;;;;;
prompt: db "Output> ", 0
output_cursor_pos: db 0

; Current tape pointer.
; NOTE: If this changes size, all accesses this will need to be changed to match it.
tape_ptr: dw tape
tape: times 64 db 0    ; bf tape

times 510-($-$$) db 0 ; 2 bytes less now
db 0x55
db 0xAA
