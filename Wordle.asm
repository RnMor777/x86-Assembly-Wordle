%define HEIGHT       28
%define WIDTH        52
%define NUMB_WORDS   14856
%define MAX_RAND     2315

segment .data
    board_file          db  "media/board.txt", 0
    word_file           db  "media/words.txt", 0
    bank_file           db  "media/bank.txt", 0
    mode_r              db  "r", 0
    raw_mode_on_cmd     db  "stty raw -echo", 0
    raw_mode_off_cmd    db  "stty -raw echo", 0
    initSys             db  "stty -echo -icanon", 0 
    initMouse           db  "echo '",0x1b,"[?1003h",0x1b,"[?1015h",0x1b,"[?1006h'",0x1b,"[?25l",0
    resSys              db  "stty echo icanon", 0 
    resMouse            db  "echo '",0x1b,"[?1003l",0x1b,"[?1015l",0x1b,"[?1006l'",0x1b,"[?25h",0
    clear_screen_cmd    db  "clear", 0

    color_normal        db  0x1b, "[0;24m", 0
    fg_black            db  0x1b, "[30m", 0
    fg_unused           db  0x1b, "[38;5;250m", 0, 0,0,0,0
    fg_within           db  0x1b, "[38;5;3m",0,0,0,0,0,0,0
    fg_exact            db  0x1b, "[38;5;35m",0,0, 0,0,0,0
    fg_fail             db  0x1b, "[38;5;243m", 0, 0,0,0,0
    bg_default          db  0x1b, "[49m", 0
    bg_unused           db  0x1b, "[48;5;250m", 0, 0,0,0,0
    bg_within           db  0x1b, "[48;5;3m",0,0,0,0,0,0,0
    bg_exact            db  0x1b, "[48;5;35m",0,0, 0,0,0,0
    bg_fail             db  0x1b, "[48;5;243m", 0, 0,0,0,0

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
    frmt_unic2          db  0x1b,"[48;5;250m",0x1b,"[30m"," %ls ", 0x1b, "[49m", 0x1b, "[38;5;250m", 0
    frmt_locale         db  "", 0
    frmt_delim          db  ";", 0
    frmt_Mm             db  "Mm", 0

    guesses             db  "                              QWERTYUIOPASDFGHJKL ZXCVBNM", 0
    jump_letter         dd  10, 24, 22, 12, 2, 13, 14, 15, 7, 16, 17, 18, 26, 25, 8, 9, 0, 3, 11, 4, 6, 23, 1, 21, 5, 20

    lose_text           db  " Unfortunate! The word was: %s. Again (y/n)?", 0
    win_text            db  "Congratulations! You found: %s. Again (y/n)?", 0
    error_text          db  "              Not in the wordlist", 0
    text_array          dd  lose_text, win_text, error_text

    mouse_map           db  "QQQQQWWWWWEEEEERRRRRTTTTTYYYYYUUUUUIIIIIOOOOOPPPPP"
    mouse_map2          db  "   AAAAASSSSSDDDDDFFFFFGGGGGHHHHHJJJJJKKKKKLLLLL  " 
    mouse_map3          db  "   11111ZZZZZXXXXXCCCCCVVVVVBBBBBNNNNNMMMMM22222  "
    mouse_array         dd  mouse_map, mouse_map2, mouse_map3

segment .bss
    board       resb    (HEIGHT*WIDTH)
    word_list   resb    (NUMB_WORDS * 6 + 1)
    userin      resb    4
    guess_stat  resb    59
    line        resd    1
    position    resd    1
    read_word   resb    7
    chosen_word resb    6
    error_tag   resd    1
    block_mouse resd    1

segment .text
	global  main
    extern  system
    extern  putchar
    extern  getchar
    extern  printf
    extern  fopen
    extern  fread
    extern  fclose
    extern  fgetc
    extern  setlocale
    extern  malloc
    extern  free
    extern  strtok
    extern  atoi
    extern  fcntl
    extern  usleep
    extern  toupper
    extern  strncmp
    extern  time
    extern  srand
    extern  rand
    extern  fseek
    extern  signal
    extern  exit

; main()
main:
    enter   0, 0
    pusha
	; ********** CODE STARTS HERE **********

    ; format all game setup things
    call    seed_start

    ; reset variables and everything to defaults
    game_start:
    call    restart_game

    game_loop:
        call    render
        call    getUserIn
        mov     al, BYTE[userin]
        mov     DWORD[error_tag], 0

        mov     ebx, DWORD[line]
        shl     ebx, 2
        add     ebx, DWORD[line]
        add     ebx, DWORD[position]

        ; if enter was pressed then process the word
        cmp     al, 10
        jne     back_compare
            cmp     DWORD[position], 5
            jne     skip_entry
                ; Verify that the input is valid word
                lea     ecx, [guesses + ebx - 5]
                push    ebx
                push    ecx
                call    valid_word
                add     esp, 4
                pop     ebx

                ; test if the response was a valid word
                cmp     eax, 1
                je      correct_word
                    ; if invalid we through error message and continue loop
                    mov     DWORD[error_tag], 3
                    jmp     skip_entry

                    correct_word:
                    ; if valid, color word and check for winning
                    sub     ebx, 5
                    lea     ecx, [guesses + ebx]
                    push    ebx
                    push    ecx
                    call    color_word
                    add     esp, 8

                    ; increment for next word entered
                    inc     DWORD[line]
                    mov     DWORD[position], 0

                    ; if the user won
                    cmp     eax, 5
                    je      game_win

                    ; go to next loop
                    jmp     skip_entry

        ; if backspace was pressed, then delete current char
        back_compare:
        cmp     al, 127
        jne     main_compare
            cmp     DWORD[position], 0
            jle     skip_entry
                mov     BYTE[guesses + ebx - 1], " "
                dec     DWORD[position]
                jmp     skip_entry
            
        ; enter the newly pressed key if there is room in the word
        main_compare:
        cmp     DWORD[position], 5
        jge     skip_entry
            mov     BYTE[guesses + ebx], al
            inc     DWORD[position]
    
    skip_entry:
    cmp     DWORD[line], 6
    jne     game_loop

    ; if the player lost
    mov     DWORD[error_tag], 1
    jmp     game_end

    ; if the player won
    game_win:
    mov     DWORD[error_tag], 2

    game_end:
    call    render

    ; if the user wants to play another round
    call    getUserIn
    mov     al, BYTE[userin]
    cmp     al, "Y"
    je      game_start

    game_quit:
    push    resSys
    call    system
    add     esp, 4
    push    resMouse
    call    system
    add     esp, 4

    call    exit

	; *********** CODE ENDS HERE ***********
    popa
    mov     eax, 0
    leave
	ret

; void seed_start()
    ; ebp-4: board file pointer
    ; ebp-8: y counter
seed_start:
    push    ebp
    mov     ebp, esp
    sub     esp, 8

    ; set up ctrl-c handler
    push    game_quit
    push    0x2
    call    signal
    add     esp, 8

    ; sets up unicode, prepares the terminal for mouse input
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

    ; open the board file to read
    push    mode_r
    push    board_file 
    call    fopen
    add     esp, 8
    mov     DWORD[ebp-4], eax
    mov     DWORD[ebp-8], 0

    ; read the entire board into memory
    read_board:
    cmp     DWORD[ebp-8], HEIGHT
    je      read_board_end
        ; load the proper spot to store values
        mov     eax, WIDTH
        mul     DWORD [ebp-8]
        lea     ebx, [board+eax] 

        ; read the row of characters
        push    DWORD[ebp-4]
        push    WIDTH
        push    1
        push    ebx
        call    fread
        add     esp, 16

        ; clean up the \n character
        push    DWORD[ebp-4]
        call    fgetc
        add     esp, 4

    inc     DWORD[ebp-8]
    jmp     read_board
    read_board_end:

    ; close the file
    push    DWORD[ebp-4]
    call    fclose
    add     esp, 4

    ; open the valid word file to read
    push    mode_r
    push    word_file
    call    fopen
    add     esp, 8
    mov     DWORD[ebp-4], eax

    ; read the entire wordlist into memory
    mov     DWORD[ebp-8], 0
    read_wordlist:
    cmp     DWORD[ebp-8], NUMB_WORDS
    je      read_wordlist_end
        ; load up the spot to store the word
        mov     eax, 6
        mul     DWORD [ebp-8]
        lea     ebx, [word_list+eax] 

        ; read the word
        push    DWORD[ebp-4]
        push    6
        push    1
        push    ebx
        call    fread
        add     esp, 16
    inc     DWORD[ebp-8]
    jmp     read_wordlist
    read_wordlist_end:

    mov     eax, 6
    mov     ebx, NUMB_WORDS
    mul     ebx
    mov     BYTE[word_list + eax + 1], 0

    ; close the file
    push    DWORD[ebp-4]
    call    fclose
    add     esp, 4

    ; generate a random number to find the word used
    ; srand(time(null))
    push    0
    call    time
    add     esp, 4
    push    eax
    call    srand
    add     esp, 4

    mov     esp, ebp
    pop     ebp
    ret

; void restart_game ()
restart_game:
    push    ebp
    mov     ebp, esp
    sub     esp, 4

    ; set variables
    mov     DWORD[line], 0
    mov     DWORD[position], 0
    mov     DWORD[error_tag], 0

    ; reset all guesses
    xor     ecx, ecx
    top_reset_loop1:
    cmp     ecx, 30
    je      end_reset_loop1
        mov BYTE[guesses + ecx], " "
    inc     ecx
    jmp     top_reset_loop1
    end_reset_loop1:

    ; reset all guess stats
    xor     ecx, ecx
    top_reset_loop2:
    cmp     ecx, 59
    je      end_reset_loop2
        mov BYTE[guess_stat + ecx], 0
    inc     ecx
    jmp     top_reset_loop2
    end_reset_loop2:

    ; open possible word choices file
    push    mode_r
    push    bank_file 
    call    fopen
    add     esp, 8
    mov     DWORD[ebp-4], eax

    ; generate random number 0 < x < # of words
    call    rand
    cdq
    mov     ebx, MAX_RAND
    div     ebx
    lea     ecx, [edx*4 + edx]
    add     ecx, edx

    ; jump to that word in the file
    push    0
    push    ecx 
    push    DWORD[ebp-4]
    call    fseek
    add     esp, 12

    ; read the word and store as chosen_word
    push    DWORD[ebp-4]
    push    6
    push    1
    push    chosen_word
    call    fread
    add     esp, 16
    mov     BYTE[chosen_word + 5], 0

    ; close the file
    push    DWORD[ebp-4]
    call    fclose
    add     esp, 4

    mov     esp, ebp
    pop     ebp
    ret

; bool valid_word (char *word)
    ; ebp-4: start
    ; ebp-8: mid
    ; ebp-12: end
    ; ebp-16: return value
valid_word:
    push    ebp,
    mov     ebp, esp
    sub     esp, 16

    ; set variables
    mov     DWORD[ebp-4], 0
    mov     DWORD[ebp-12], NUMB_WORDS
    mov     DWORD[ebp-16], 0

    ; runs a binary search to find if the word is valid
    read_words:
    mov     eax, DWORD[ebp-4]
    cmp     eax, DWORD[ebp-12]
    je      read_words_end
        ; calculate mid
        add     eax, DWORD[ebp-12]
        shr     eax, 1
        mov     DWORD[ebp-8], eax

        ; load arr[mid]
        mov     ebx, 6
        mul     ebx
        lea     eax, [word_list + eax]
        
        ; compare the read word to the user entered word
        push    5
        push    eax
        push    DWORD[ebp+8]
        call    strncmp
        add     esp, 12

        ; test for match
        test    eax, eax
        je      found_word

        ; update the start or end values
        mov     edx, DWORD[ebp-8]
        mov     ebx, -4
        mov     ecx, -12
        cmp     eax, 0
        cmovl   ebx, ecx
        mov     DWORD[ebp + ebx], edx

        ; add 1 if less than
        shr     eax, 31
        xor     eax, 1
        add     DWORD[ebp + ebx], eax
    jmp     read_words

    found_word:
    mov     DWORD[ebp-16], 1
    read_words_end:

    ; return value
    mov     eax, DWORD[ebp-16]

    mov     esp, ebp
    pop     ebp
    ret

; int color_word (char *word, int loc)
    ; ebp-4: the amount of direct matched letters
color_word:
    push    ebp
    mov     ebp, esp
    sub     esp, 4

    mov     DWORD[ebp-4], 0
    mov     eax, DWORD[ebp+8]
    xor     ecx, ecx
    xor     edx, edx
    top_color_loop:
    cmp     ecx, 5
    je      end_color_loop
        mov     bl, BYTE[chosen_word + ecx]
        mov     dl, BYTE[eax + ecx]

        ; test if the characters are a direct match then green
        cmp     bl, dl
        jne     test_yellow
            ; color the letter in the entered word
            mov     esi, DWORD[ebp+12]
            add     esi, ecx
            mov     BYTE[guess_stat + esi], 2
            inc     DWORD[ebp-4]

            ; color the letter in the keyboard
            lea     esi, [guess_stat+30]
            sub     dl, 'A'
            add     esi, DWORD[jump_letter + 4*edx]
            mov     BYTE[esi], 2

            jmp     bot_color_loop

        ; test if the colors appear in the string
        test_yellow:
        xor     esi, esi
        xor     edi, edi

        ; determine how many appearances are in the chosen word
        top_yellow_loop:
        cmp     edi, 5
        je      end_yellow_loop
            mov     bl, BYTE[chosen_word + edi]
            cmp     bl, dl
            jne     bot_yellow_loop
                inc     esi
        bot_yellow_loop:
        inc     edi
        jmp     top_yellow_loop
        end_yellow_loop:
        
        ; determine how many appearances are in the entered word
        xor     edi, edi
        top_yellow_loop2:
        cmp     edi, ecx
        je      end_yellow_loop2
            mov     bl, BYTE[eax + edi]
            cmp     bl, dl
            jne     bot_yellow_loop2
                dec     esi
        bot_yellow_loop2:
        inc     edi
        jmp     top_yellow_loop2
        end_yellow_loop2:

        ; check positions after letter to see if direct match so decrement
        inc     edi
        top_yellow_loop3:
        cmp     edi, 5
        jge     end_yellow_loop3
            mov     bl, BYTE[eax + edi]
            cmp     bl, dl
            jne     bot_yellow_loop3
                cmp     BYTE[chosen_word + edi], bl
                jne     bot_yellow_loop3
                    dec     esi
        bot_yellow_loop3:
        inc     edi
        jmp     top_yellow_loop3
        end_yellow_loop3:

        ; if there is room to put yellow then do it
        cmp     esi, 0
        jle     color_none
            ; color the word letter yellow
            mov     esi, DWORD[ebp+12]
            add     esi, ecx
            mov     BYTE[guess_stat + esi], 1

            ; color the keyboard yellow
            lea     esi, [guess_stat+30]
            sub     dl, 'A'
            add     esi, DWORD[jump_letter + 4*edx]
            cmp     BYTE[esi], 0
            jne     bot_color_loop
                mov     BYTE[esi], 1
                jmp     bot_color_loop

        ; nothing gets colored
        color_none:
            ; color the word letter dark grey
            mov     esi, DWORD[ebp+12]
            add     esi, ecx
            mov     BYTE[guess_stat + esi], 3

            ; color the keyboard dark grey
            lea     esi, [guess_stat+30]
            sub     dl, 'A'
            add     esi, DWORD[jump_letter + 4*edx]
            mov     BYTE[esi], 3

    bot_color_loop:
    inc     ecx
    jmp     top_color_loop
    end_color_loop:

    mov     eax, DWORD[ebp-4]

    mov     esp, ebp
    pop     ebp
    ret

; void render()
    ; ebp-4: y counter
    ; ebp-8: x counter
    ; ebp-12: y cell counter
    ; ebp-16: x cell counter
    ; ebp-20: tmp storage
render:
    push    ebp
    mov     ebp, esp
    sub     esp, 20

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

            ; case where we want to insert a letter
            cmp     bl, 59
            jne     test_endings
                ; get and set the background color for the space
                mov     eax, DWORD[ebp-12]
                add     eax, DWORD[ebp-16]
                mov     al, BYTE[guess_stat + eax - 1]
                shl     eax, 4
                mov     DWORD[ebp-20], eax
                lea     eax, [bg_unused + eax]
                push    eax
                call    printf
                add     esp, 4

                ; make the character appear black
                push    fg_black
                call    printf
                add     esp, 4

                ; grab the corresponding letter guess and print it
                mov     eax, DWORD[ebp-12]
                add     eax, DWORD[ebp-16]
                mov     al, BYTE[guesses + eax - 1]
                push    eax
                call    putchar
                add     esp, 4

                ; restore the box forground color 
                mov     eax, DWORD[ebp-20]
                lea     eax, [fg_unused + eax]
                push    eax
                call    printf
                add     esp, 4
             
                ; restore the background color to default
                push    bg_default
                call    printf
                add     esp, 4
            
                jmp     x_loop_bottom

            ; case to reset the coloring at the end of a line
            test_endings:
            cmp     bl, 60
            je      color_reset

            ; case to print messages if they exist
            cmp     bl, 61
            jne     test_reset
            mov     eax, DWORD[error_tag]
            cmp     eax, 0
            je      y_loop_bottom
                dec     eax
                mov     eax, [text_array + 4*eax]
                push    chosen_word
                push    eax
                call    printf
                add     esp, 8
                jmp     y_loop_bottom

            ; case to reset and increment to next set of boxes
            test_reset:
            cmp     bl, 62
            jne     test_enter
                mov     eax, DWORD[ebp-16]
                add     DWORD[ebp-12], eax
                jmp     color_reset

            ; test for enter symbol to print properly
            test_enter:
            cmp     bl, 57
            jne     test_backspace
                push    box9
                push    frmt_unic2
                call    printf 
                add     esp, 4

                add     DWORD[ebp-8], 2
                jmp     x_loop_bottom

            ; test for the backspace symbol and print properly
            test_backspace:
            cmp     bl, 58
            jne     test_unicode
                push    box10
                push    frmt_unic2
                call    printf 
                add     esp, 4

                add     DWORD[ebp-8], 2
                jmp     x_loop_bottom

            ; inserting unicode characters
            test_unicode:
            cmp     bl, 56
            jg      normal_char
            cmp     bl, 48
            jl      normal_char
                ; if we find the left side of box, update the color scheme
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

                ; print the unicode that is substituted for what was found
                print_unicode:
                sub     ebx, 48
                lea     ecx, [box0 + 8*ebx]

                push    ecx
                push    frmt_unic
                call    printf
                add     esp, 8
                jmp     x_loop_bottom

            ; reset the color to normal
            color_reset:
            lea     eax, [color_normal]
            push    eax
            call    printf
            add     esp, 4
            jmp     x_loop_bottom

            ; print a normal alpha-numeric character
            normal_char:
            push    ebx     
            call    putchar
            add     esp, 4

            ; bottom of x loop, so will go to next x position
            x_loop_bottom:
            inc     DWORD[ebp-8]
            jmp     x_loop_start

        ; goes to the next line of the board and does some cleanup
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
    ; ebp-4: counter 
processgetchar:
    push    ebp
    mov     ebp, esp
    sub     esp, 4

    mov     DWORD[ebp-4], 0
    
    topGetCharLoop:
    ; get a character and cast to upper case if applicable
    call    nonblockgetchar
    push    eax
    call    toupper
    add     esp, 4

    ; decide if a character was returned
    mov     ebx, eax
    xor     eax, eax
    cmp     bl, -1
    je      endGetCharLoop

        mov     ecx, DWORD[ebp+8]
        mov     edx, DWORD[ebp-4]
        mov     BYTE[ecx+edx], bl
        inc     DWORD[ebp-4]

        ; special input that will allowed to be handled
        cmp     bl, 127
        je      returnGetChar
        cmp     bl, 10
        je      returnGetChar

        ; otherwise we are looking for a capital letter
        cmp     bl, 'A'
        jl      topGetCharLoop
        cmp     bl, 'Z'
        jg      topGetCharLoop

        returnGetChar:
        mov     eax, edx
        inc     eax
    endGetCharLoop:

    mov     esp, ebp
    pop     ebp
    ret

; void getUserIn ()
    ; ebp-4: start of malloc memory
    ; ebp-8: malloc memory addr + 3
    ; ebp-12:
    ; ebp-16: bool mouse return or keyboard
    ; ebp-20: mouse op-code
    ; ebp-24: column
    ; ebp-28: row
getUserIn:
    push    ebp
    mov     ebp, esp
    sub     esp, 28

    ; malloc a space to store the returned memory
    push    17
    call    malloc
    add     esp, 4

    mov     DWORD[ebp-4], eax
    mov     DWORD[ebp-8], eax
    add     DWORD[ebp-8], 3

    topScanLoop:
    ; sleep to relax cpu constant usage
    push    500
    call    usleep
    add     esp, 4

    ; store the returned char in the malloc memory
    push    DWORD[ebp-4]
    call    processgetchar
    add     esp, 4

    ; compare return value to mouse or keyboard input
    mov     DWORD[ebp-16], eax
    cmp     eax, 0
    je      topScanLoop
    cmp     eax, 1
    jne     processMouse
        mov     ebx, DWORD[ebp-4]
        mov     al, BYTE[ebx]
        mov     BYTE[userin], al
        jmp     endScanLoop

    ; if the user did anything with the mouse
    processMouse:
    ; store the opcode related to the mouse event in ebp-20
    push    frmt_delim
    push    DWORD[ebp-8]
    call    strtok
    add     esp, 8
    push    eax
    call    atoi
    add     esp, 4
    mov     DWORD[ebp-20], eax

    ; store the column of the mouse event in ebp-24
    push    frmt_delim
    push    0
    call    strtok
    add     esp, 8
    push    eax
    call    atoi
    add     esp, 4
    mov     DWORD[ebp-24], eax

    ; store the row of the mouse event in ebp-28
    push    frmt_Mm
    push    0
    call    strtok
    add     esp, 8
    push    eax
    call    atoi
    add     esp, 4
    mov     DWORD[ebp-28], eax

    ; conditions to not accept mouse input
    cmp     DWORD[ebp-20], 0
    jne     topScanLoop
    xor     DWORD[block_mouse], 1
    cmp     DWORD[block_mouse], 0
    je      topScanLoop
    cmp     DWORD[ebp-28], 20
    jl      topScanLoop
    cmp     DWORD[ebp-28], 28
    jg      topScanLoop
    cmp     DWORD[ebp-24], 51
    jg      topScanLoop
    cmp     DWORD[ebp-24], 1
    je      topScanLoop

    ; get the location of the mouse click
    mov     eax, DWORD[ebp-28]
    sub     eax, 20
    mov     ebx, 3
    cdq
    div     ebx
    mov     ebx, DWORD[ebp-24]
    sub     ebx, 2

    ; loads the key map and replaces enter/del chars
    mov     ecx, DWORD[mouse_array + 4*eax]
    mov     al, BYTE[ecx + ebx]
    cmp     al, " "
    je      topScanLoop
    mov     ebx, 10
    mov     ecx, 127
    cmp     al, '1'
    cmove   eax, ebx
    cmp     al, '2'
    cmove   eax, ecx
    mov     BYTE[userin], al
    endScanLoop:

    ; clears memory
    push    DWORD[ebp-4]
    call    free
    add     esp, 4

    mov     esp, ebp
    pop     ebp
    ret

; vim:ft=nasm
