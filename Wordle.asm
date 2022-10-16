%define BOARD_FILE   'media/board.txt'
%define HEIGHT       28
%define WIDTH        52

segment .data
    board_file          db  BOARD_FILE, 0
    mode_r              db  "r", 0
    mode_w              db  "w", 0
    raw_mode_on_cmd     db  "stty raw -echo", 0
    raw_mode_off_cmd    db  "stty -raw echo", 0
    initSys             db  "stty -echo -icanon", 0 
    initMouse           db  "echo '",0x1b,"[?1003h",0x1b,"[?1015h",0x1b,"[?1006h'",0x1b,"[?25l",0
    resSys              db  "stty echo icanon", 0 
    resMouse            db  "echo '",0x1b,"[?1003l",0x1b,"[?1015l",0x1b,"[?1006l'",0x1b,"[?25h",0
    clear_screen_cmd    db  "clear", 0

    color_normal     db  0x1b, "[0;24m", 0
    fg_unused        db  0x1b, "[38;5;249m", 0, 0,0,0,0
    fg_within        db  0x1b, "[38;5;3m",0,0,0,0,0,0,0
    fg_exact         db  0x1b, "[38;5;28m",0,0, 0,0,0,0
    bg_unused        db  0x1b, "[48;5;249m", 0, 0,0,0,0
    bg_within        db  0x1b, "[48;5;3m",0,0,0,0,0,0,0
    bg_exact         db  0x1b, "[48;5;28m",0,0, 0,0,0,0

    box0                dw  __utf32__("▗"), 0, 0
    box1                dw  __utf32__("▐"), 0, 0
    box2                dw  __utf32__("▝"), 0, 0
    box3                dw  __utf32__("▄"), 0, 0
    box4                dw  __utf32__("█"), 0, 0
    box5                dw  __utf32__("▌"), 0, 0
    box6                dw  __utf32__("▖"), 0, 0
    box7                dw  __utf32__("▀"), 0, 0
    box8                dw  __utf32__("▘"), 0, 0
    box9                dw  __utf32__("⮑"), 0, 0
    box10               dw  __utf32__("⌫"), 0, 0

    frmt_unic           db  "%ls", 0
    frmt_reg            db  "%s", 0
    newline             db  10, 0
    frmt_locale         db  "", 0
    frmt_delim          db  ";", 0
    frmt_Mm             db  "Mm", 0

segment .bss
    board       resb    (HEIGHT*WIDTH)
    userin      resb    4
    guesses     resb    58
    guess_stat  resb    58
    line        resd    1

segment .text
	global  main
    extern  system
    extern  putchar
    extern  getchar
    extern  printf
    extern  scanf
    extern  fopen
    extern  fread
    extern  fwrite
    extern  fclose
    extern  fgetc
    extern  fscanf
    extern  setlocale
    extern  malloc
    extern  free
    extern  strtok
    extern  atoi
    extern  fcntl
    extern  usleep

; main()
main:
    enter   0, 0
    pusha
	; ********** CODE STARTS HERE **********

    mov     BYTE[guess_stat + 4], 1

    ; scans in all of the files, sets up unicode, and defaults
    ; prepares the terminal for mouse input
    push    frmt_locale
    push    0x6
    call    setlocale
    add     esp, 8

    push    initSys
    call    system
    add     esp, 4

    push    initMouse
    call    system
    add     esp, 4

    call    seed_start

    game_loop:
        call    render
        call    getUserIn

        mov     al, BYTE[userin]
        cmp     al, 'q'
        je      game_end

        jmp     game_loop

    game_end:
    push    resSys
    call    system
    add     esp, 4

    push    resMouse
    call    system
    add     esp, 4

	; *********** CODE ENDS HERE ***********
    popa
    mov     eax, 0
    leave
	ret

; void seed_start()
seed_start:
    push    ebp
    mov     ebp, esp
    sub     esp, 8

    lea     esi, [board_file]
    lea     edi, [board]

    ; open the board file
    push    mode_r
    push    esi
    call    fopen
    add     esp, 8
    mov     DWORD[ebp-4], eax
    mov     DWORD[ebp-8], 0

    ; read the entire board into memory
    read_board:
    cmp     DWORD[ebp-8], HEIGHT
    je      read_board_end
        mov     eax, WIDTH
        mul     DWORD [ebp-8]
        lea     ebx, [edi+eax] 

        push    DWORD[ebp-4]
        push    WIDTH
        push    1
        push    ebx
        call    fread
        add     esp, 16

        push    DWORD[ebp-4]
        call    fgetc
        add     esp, 4

    inc     DWORD[ebp-8]
    jmp     read_board
    read_board_end:

    mov     esp, ebp
    pop     ebp
    ret

; void render()
render:
    push    ebp
    mov     ebp, esp
    sub     esp, 16
    ; ebp-4: y counter
    ; ebp-8: x counter
    ; ebp-12: y cell counter
    ; ebp-16: x cell counter

    ; clears the command line screen so nothing is left on it
    push    clear_screen_cmd
    call    system
    add     esp, 4

    ; goes into a double for loop that traverses the entire board array while printing it
    mov     DWORD[ebp-4], 0
    mov     DWORD[ebp-12], 0
    mov     DWORD[ebp-16], 0
    y_loop_start:
    cmp     DWORD[ebp-4], HEIGHT
    je      y_loop_end
        mov     DWORD[ebp-8], 0
        x_loop_start:
        cmp     DWORD[ebp-8], WIDTH
        je      y_loop_bottom
            ; Grabs the current board piece
            mov     eax, [ebp-4]
            mov     ebx, WIDTH
            mul     ebx
            add     eax, [ebp-8]
            xor     ebx, ebx
            mov     bl, BYTE[board+eax]

            cmp     bl, 60
            je      color_reset

            cmp     bl, 62
            jne     test_unicode
                mov     eax, DWORD[ebp-16]
                add     DWORD[ebp-12], eax
                jmp     color_reset

            ; test for trading unicode characters
            test_unicode:
            cmp     bl, 58
            jg      normal_char
            cmp     bl, 48
            jl      normal_char
                cmp     bl, 50
                jg      print_unicode
                    mov     eax, DWORD[ebp-12]
                    add     eax, DWORD[ebp-16]
                    mov     al, BYTE[guess_stat + eax]
                    shl     eax, 4
                    lea     eax, [fg_unused + eax]

                    push    eax
                    call    printf
                    add     esp, 4

                    inc     DWORD[ebp-16]
                print_unicode:

                sub     ebx, 48
                lea     ecx, [box0 + 8*ebx]

                push    ecx
                push    frmt_unic
                call    printf
                add     esp, 8
                jmp     x_loop_bottom

            color_reset:
            lea     eax, [color_normal]
            push    eax
            call    printf
            add     esp, 4
            jmp     x_loop_bottom

            normal_char:
            push    ebx     
            call    putchar
            add     esp, 4

            x_loop_bottom:
            inc     DWORD[ebp-8]
            jmp     x_loop_start

        y_loop_bottom:
        mov     DWORD[ebp-16], 0
        push    0x0a
        call    putchar
        add     esp, 4

		push	0x0d
		call 	putchar
		add		esp, 4

        inc     DWORD[ebp-4]
        jmp     y_loop_start
    y_loop_end:

    mov     esp, ebp
    pop     ebp
    ret

; char nonblockgetchar ()
nonblockgetchar:
    push    ebp
    mov     ebp, esp

	sub		esp, 8

	push	0
	push	4
	push	0
	call	fcntl
	add		esp, 12
	mov		DWORD [ebp-4], eax

	or		DWORD [ebp-4], 2048
	push	DWORD [ebp-4]
	push	4
	push    0
	call	fcntl
	add		esp, 12

	call	getchar
	mov		DWORD [ebp-8], eax

	xor		DWORD [ebp-4], 2048
	push	DWORD [ebp-4]
	push	4
	push	0
	call	fcntl
	add		esp, 12

	mov		eax, DWORD [ebp-8]

    mov     esp, ebp
    pop     ebp
    ret

; int processgetchar (char* array)
processgetchar:
    push    ebp
    mov     ebp, esp

    sub     esp, 8
    mov     DWORD[ebp-4], 0
    
    topGetCharLoop:
    call    nonblockgetchar
    mov     DWORD[ebp-8], eax  

    xor     eax, eax
    mov     ebx, DWORD[ebp-8]
    cmp     bl, -1
    je      endGetCharLoop

    mov     ecx, DWORD[ebp+8]
    mov     edx, DWORD[ebp-4]
    mov     BYTE[ecx+edx], bl
    inc     DWORD[ebp-4]

    cmp     bl, 'M'
    je      returnGetChar
    cmp     bl, 'a'
    jl      topGetCharLoop
    cmp     bl, 'z'
    jg      topGetCharLoop
    returnGetChar:
        mov     eax, edx
        inc     eax
    endGetCharLoop:
    mov     esp, ebp
    pop     ebp
    ret

; void getUserIn ()
getUserIn:
    push    ebp
    mov     ebp, esp

    sub     esp, 32
    push    17
    call    malloc
    add     esp, 4

    mov     DWORD[ebp-4], eax
    mov     DWORD[ebp-8], eax
    add     DWORD[ebp-8], 3

    topScanLoop:
    push    500
    call    usleep
    add     esp, 4
    push    DWORD[ebp-4]
    call    processgetchar
    add     esp, 4
    mov     DWORD[ebp-16], eax
    cmp     eax, 0
    je      topScanLoop
    cmp     eax, 1
    jne     processMouse
        mov     ebx, DWORD[ebp-4]
        mov     al, BYTE[ebx]
        mov     BYTE[userin], al
        jmp     endScanLoop
    processMouse:
    mov     ebx, DWORD[ebp-4]
    xor     ecx, ecx
    mov     cl, BYTE[ebx+eax-1]
    mov     DWORD[ebp-32], ecx

    push    frmt_delim
    push    DWORD[ebp-8]
    call    strtok
    add     esp, 8
    push    eax
    call    atoi
    add     esp, 4
    mov     DWORD[ebp-20], eax

    push    frmt_delim
    push    0
    call    strtok
    add     esp, 8
    push    eax
    call    atoi
    add     esp, 4
    mov     DWORD[ebp-24], eax

    push    frmt_Mm
    push    0
    call    strtok
    add     esp, 8
    push    eax
    call    atoi
    add     esp, 4
    mov     DWORD[ebp-28], eax

    cmp     DWORD[ebp-20], 2
    jne     contMouseIf
        mov     BYTE[userin], 'z'
        jmp     endScanLoop
    contMouseIf:
    cmp     DWORD[ebp-20], 0
    jne     topScanLoop
    cmp     DWORD[ebp-32], "M"
    jne     topScanLoop
    cmp     DWORD[ebp-24], 21
    jl      topScanLoop
    cmp     DWORD[ebp-24], 36
    jg      topScanLoop
    cmp     DWORD[ebp-28], 5
    jl      topScanLoop
    cmp     DWORD[ebp-28], 12
    jg      topScanLoop
        mov     eax, DWORD[ebp-28]
        sub     eax, 5
        mov     ebx, 8
        sub     ebx, eax
        add     ebx, "0"
        mov     BYTE[userin+1], bl
        mov     eax, DWORD[ebp-24]
        sub     eax, 21
        shr     eax, 1
        add     eax, "a"
        mov     BYTE[userin], al
        mov     BYTE[userin+2], 0
    endScanLoop:
    push    DWORD[ebp-4]
    call    free
    add     esp, 4

    mov     esp, ebp
    pop     ebp
    ret
; void getUserIn2 ()
getUserIn2:
    push    ebp
    mov     ebp, esp

    sub     esp, 32
    push    17
    call    malloc
    add     esp, 4

    mov     DWORD[ebp-4], eax
    mov     DWORD[ebp-8], eax
    add     DWORD[ebp-8], 3

    topScanLoop2:
    push    500
    call    usleep
    add     esp, 4
    mov     BYTE[userin], 0
    push    DWORD[ebp-4]
    call    processgetchar
    add     esp, 4
    mov     DWORD[ebp-16], eax
    cmp     eax, 0
    je      topScanLoop2
    cmp     eax, 1
    jne     processMouse2
        mov     ebx, DWORD[ebp-4]
        mov     al, BYTE[ebx]
        mov     BYTE[userin], al
        jmp     endScanLoop2
    processMouse2:
    mov     ebx, DWORD[ebp-4]
    xor     ecx, ecx
    mov     cl, BYTE[ebx+eax-1]
    mov     DWORD[ebp-32], ecx

    push    frmt_delim
    push    DWORD[ebp-8]
    call    strtok
    add     esp, 8
    push    eax
    call    atoi
    add     esp, 4
    mov     DWORD[ebp-20], eax

    push    frmt_delim
    push    0
    call    strtok
    add     esp, 8
    push    eax
    call    atoi
    add     esp, 4
    mov     DWORD[ebp-24], eax

    push    frmt_Mm
    push    0
    call    strtok
    add     esp, 8
    push    eax
    call    atoi
    add     esp, 4
    mov     DWORD[ebp-28], eax

    cmp     DWORD[ebp-28], 9
    jle     endScanLoop2 
    cmp     DWORD[ebp-28], 14
    jge     endScanLoop2
    cmp     DWORD[ebp-24], 32
    jl      endScanLoop2
    cmp     DWORD[ebp-24], 43
    jg      endScanLoop2

    cmp     DWORD[ebp-20], 0
    je      clickIntro
    cmp     DWORD[ebp-20], 35
    je      hoverIntro
    jmp     topScanLoop2

    clickIntro:
    mov     eax, DWORD[ebp-28]
    sub     eax, 5
    mov     BYTE[userin], al
    jmp     endScanLoop2

    hoverIntro:
    mov     eax, DWORD[ebp-28]
    sub     eax, 9
    mov     BYTE[userin], al

    endScanLoop2:
    push    DWORD[ebp-4]
    call    free
    add     esp, 4

    mov     esp, ebp
    pop     ebp
    ret
; vim:ft=nasm
