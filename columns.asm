################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       4
# - Unit height in pixels:      4
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)q
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000

BLACK:
    .word 0x000000

GRID:
    .word 0x555555

COLOURS:
    .word 0xff0000
    .word 0xff8800
    .word 0xffff00
    .word 0x00ff00
    .word 0x0000ff
    .word 0x8800ff

##############################################################################
# Mutable Data
##############################################################################
top_gem:
    .word 0

mid_gem:
    .word 0

bottom_gem:
    .word 0

row:
    .word 0

col:
    .word 2

frame_counter:
    .word 0

board:
    .space 312 # 13 rows * 6 cols * 4 bytes

match_gems:
    .space 312 # same size, used when cl

prev_row:
    .word 0

is_downward_move:
    .word 0 # 1 if the move is downward, 0 if it is not

##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game
main:
    # Initialize the game
    li $t0, 0
    sw $t0, row

    li $t0, 2
    sw $t0, col

    jal clear_whole_screen
    jal clear_board
    jal draw_grid
    jal randomize_gem_colour

game_loop:
    # 1a. Check if key has been pressed
    # 1b. Check which key has been pressed
    jal handle_input
    
    # 2a. Check for collisions
    jal check_collision
    
	# 2b. Update locations (capsules)
    jal update_game
    
	# 3. Draw the screen
    jal draw_screen
  
	# 4. Sleep
    li $v0, 32
    li $a0, 16 # 1000ms / 60 fps = approx. 16ms per frame
    syscall

    # 5. Go back to Step 1
    j game_loop

draw_screen:
    addiu $sp, $sp, -4
    sw $ra, 0($sp)

    jal clear_screen
    jal draw_board
    jal draw_curr_col

    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra

clear_whole_screen:
    lw $t0, ADDR_DSPL
    lw $t1, BLACK
    li $t2, 4096 # 64 * 64

clear_whole_loop:
    sw $t1, 0($t0)
    addiu $t0, $t0, 4
    addiu $t2, $t2, -1
    bgtz $t2, clear_whole_loop
    jr $ra

clear_screen:
    lw $t0, ADDR_DSPL
    lw $t1, BLACK

    li $t2, 4 # y = 4

clear_inside_row_loop:
    li $t3, 56 # stop when y == 56
    beq $t2, $t3, clear_inside_done

    li $t4, 4 # x = 4

clear_inside_col_loop:
    li $t5, 28 # stop when x == 28
    beq $t4, $t5, clear_inside_next_row

    # address = base + y * 256 + x * 4
    sll $t6, $t2, 8
    sll $t7, $t4, 2
    addu $t8, $t6, $t7
    addu $t8, $t8, $t0
    sw $t1, 0($t8)

    addiu $t4, $t4, 1
    j clear_inside_col_loop

clear_inside_next_row:
    addiu $t2, $t2, 1
    j clear_inside_row_loop

clear_inside_done:
    jr $ra

clear_board:
    la $t0, board
    li $t1, 78 # 13 * 6 = 78 cells

clear_board_loop:
    sw $zero, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bgtz $t1, clear_board_loop
    jr $ra

draw_grid:
    addiu $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    sw $s2, 0($sp)
  
    lw $s0, GRID # grid colour

top_border:
    li $s1, 0 # col, starting at 0

top_loop:
    li $s2, 28 # end col
    beq $s1, $s2, bottom_border

    li $a0, 0 # row 
    move $a1, $s1 # col
    move $a2, $s0 # colour
    jal draw_cell

    addiu $s1, $s1, 4
    j top_loop

bottom_border:
    li $s1, 0 # col, reset to 0

bottom_loop:
    li $s2, 28 # end col
    beq $s1, $s2, left_border

    li $a0, 56 # row
    move $a1, $s1 # col
    move $a2, $s0 # colour
    jal draw_cell

    addiu $s1, $s1, 4
    j bottom_loop

left_border:
    li $s1, 0 # row, starting at 0

left_loop:
    li $s2, 60 # end row
    beq $s1, $s2, right_border

    move $a0, $s1
    li $a1, 0
    move $a2, $s0
    jal draw_cell

    addiu $s1, $s1, 4
    j left_loop

right_border:
    li $s1, 0 # row, reset to 0

right_loop:
    li $s2, 60 # end row
    
    beq $s1, $s2, done_grid

    move $a0, $s1
    li $a1, 28
    move $a2, $s0
    jal draw_cell

    addiu $s1, $s1, 4
    j right_loop

done_grid:
    lw $s2, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addiu $sp, $sp, 16
    jr $ra

randomize_gem_colour:
    la $t0, COLOURS

    # top gem
    li $v0, 42
    li $a0, 0
    li $a1, 6
    syscall
    sll $t1, $a0, 2 # convert index to byte offset
    addu $t2, $t0, $t1
    lw $t3, 0($t2)
    sw $t3, top_gem

    # middle gem
    li $v0, 42
    li $a0, 0
    li $a1, 6
    syscall
    sll $t1, $a0, 2 # convert index to byte offset
    addu $t2, $t0, $t1
    lw $t3, 0($t2)
    sw $t3, mid_gem

    # bottom gem
    li $v0, 42
    li $a0, 0
    li $a1, 6
    syscall
    sll $t1, $a0, 2 # convert index to byte offset
    addu $t2, $t0, $t1
    lw $t3, 0($t2)
    sw $t3, bottom_gem

    jr $ra

draw_curr_col:
    addiu $sp, $sp, -12
    sw $ra, 8($sp)
    sw $s0, 4($sp)
    sw $s1, 0($sp)
  
    lw $s0, row
    lw $s1, col

    # top gem
    sll  $a0, $s0, 2 # 4 bitmaps each
    addiu $a0, $a0, 4 # +4 for grid
    sll  $a1, $s1, 2 # 4 bitmaps each
    addiu $a1, $a1, 4 # +4 for grid
    lw $a2, top_gem
    jal draw_cell

    # middle gem
    addiu $t0, $s0, 1
    sll $a0, $t0, 2 # 4 bitmaps each
    addiu $a0, $a0, 4 # +4 for grid
    sll $a1, $s1, 2 # 4 bitmaps each
    addiu $a1, $a1, 4 # +4 for grid
    lw $a2, mid_gem
    jal draw_cell

    # bottom gem
    addiu $t0, $s0, 2
    sll $a0, $t0, 2 # 4 bitmaps each
    addiu $a0, $a0, 4 # +4 for grid
    sll $a1, $s1, 2 # 4 bitmaps each
    addiu $a1, $a1, 4 # +4 for grid
    lw $a2, bottom_gem
    jal draw_cell

    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addiu $sp, $sp, 12
    jr $ra

draw_cell:
    # $a0 = row drawing
    # $a1 = col drawing
    # $a2 = colour

    # start_y = row * 256
    sll $t0, $a0, 8

    # start_x = col * 4
    sll $t1, $a1, 2

    lw $t2, ADDR_DSPL

    # dy, starting at 0
    li $t3, 0

cell_row_loop:
    # end dy
    li $t4, 4
    beq $t3, $t4, done_cell

    # dx, starting at 0
    li $t5, 0

cell_col_loop:
    # end dx
    li $t6, 4
    beq $t5, $t6, next_cell_row

    # dy * 256
    sll $t7, $t3, 8

    # dx * 4
    sll $t8, $t5, 2

    # Draw one bitmap unit
    # Address = base + start_y + dy*256 + start_x + dx*4
    addu $t9, $t0, $t1
    addu $t9, $t9, $t7
    addu $t9, $t9, $t2
    addu $t9, $t9, $t8
    sw $a2, 0($t9)

    addiu $t5, $t5, 1
    j cell_col_loop

next_cell_row:
    addiu $t3, $t3, 1
    j cell_row_loop

done_cell:
    jr $ra

handle_input:
    lw $t0, ADDR_KBRD # $t0 = keyboard base address
    lw $t8, 0($t0) # first word: 1 if key pressed
    beq $t8, 1, keyboard_input # if pressed, handle it
    jr $ra # otherwise return

keyboard_input:
    lw $a0, 4($t0) # second word: ASCII of key

    beq $a0, 0x71, respond_to_Q
    beq $a0, 0x61, respond_to_A
    beq $a0, 0x64, respond_to_D 
    beq $a0, 0x73, respond_to_S  
    beq $a0, 0x77, respond_to_W 
    jr $ra

respond_to_Q:
    li $v0, 10
    syscall

respond_to_A:
    lw $t1, col
    blez $t1, input_done # prevent going past left wall

    addiu $sp, $sp, -4
    sw $ra, 0($sp)
    addiu $a0, $t1, -1 # target col = col - 1
    jal check_side_block
    bne $v0, $zero, respond_A_done

    lw $t1, col
    addiu $t1, $t1, -1
    sw $t1, col
    
respond_A_done:
    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra

respond_to_D:
    lw $t1, col
    li $t2, 5 # max col = 5
    slt $t3, $t1, $t2 # 1 if col < 5
    beq $t3, $zero, input_done # prevent going past right wall

    addiu $sp, $sp, -4
    sw $ra, 0($sp)
    addiu $a0, $t1, 1 # target col = col + 1
    jal check_side_block
    bne $v0, $zero, respond_D_done

    lw $t1, col
    addiu $t1, $t1, 1
    sw $t1, col
    
respond_D_done:
    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra

respond_to_W:
    lw $t1, top_gem
    lw $t2, mid_gem
    lw $t3, bottom_gem

    sw $t3, top_gem
    sw $t1, mid_gem
    sw $t2, bottom_gem
    jr $ra

respond_to_S:
    lw $t1, row
    sw $t1, prev_row
    addiu $t1, $t1, 1
    sw $t1, row

    li $t1, 1
    sw $t1, is_downward_move
    jr $ra

input_done:
    jr $ra

board_addr:
    # $a0 = logical row 0..12
    # $a1 = logical col 0..5
    # returns $v0 = &board[row][col]

    la $t0, board
    sll $t1, $a0, 2 # row * 4
    sll $t2, $a0, 1 # row * 2
    addu $t1, $t1, $t2 # row * 6
    addu $t1, $t1, $a1 # row * 6 + col
    sll $t1, $t1, 2 # bytes
    addu $v0, $t0, $t1
    jr $ra

draw_board:
    addiu $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    sw $s2, 0($sp)

    li $s0, 0 # row, starting at 0

draw_board_row_loop:
    li $t0, 13 # end row
    beq $s0, $t0, draw_board_done

    li $s1, 0 # col, starting at 0

draw_board_col_loop:
    li $t0, 6 # end col
    beq $s1, $t0, draw_board_next_row

    move $a0, $s0
    move $a1, $s1
    jal board_addr
    lw $s2, 0($v0)
    beq $s2, $zero, draw_board_next_col # if cell is empty, skip

    sll $a0, $s0, 2
    addiu $a0, $a0, 4 # $a0 = row * 4 + 4
    sll $a1, $s1, 2
    addiu $a1, $a1, 4 # $a1 = col*4 + 4
    move $a2, $s2
    jal draw_cell

draw_board_next_col:
    addiu $s1, $s1, 1
    j draw_board_col_loop

draw_board_next_row:
    addiu $s0, $s0, 1
    j draw_board_row_loop

draw_board_done:
    lw $s2, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addiu $sp, $sp, 16
    jr $ra

lock_curr_col:
    addiu $sp, $sp, -12
    sw $ra, 8($sp)
    sw $s0, 4($sp)
    sw $s1, 0($sp)

    lw $s0, row
    lw $s1, col

    # top gem
    move $a0, $s0
    move $a1, $s1
    jal board_addr
    lw  $t2, top_gem
    sw  $t2, 0($v0)

    # middle gem
    addiu $a0, $s0, 1
    move $a1, $s1
    jal board_addr
    lw $t2, mid_gem
    sw $t2, 0($v0)

    # bottom gem
    addiu $a0, $s0, 2
    move $a1, $s1
    jal board_addr
    lw $t2, bottom_gem
    sw $t2, 0($v0)

    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addiu $sp, $sp, 12
    jr $ra

spawn_new_col:
    addiu $sp, $sp, -4
    sw $ra, 0($sp)

    li $t0, 0
    sw $t0, row

    li $t0, 2
    sw $t0, col

    jal randomize_gem_colour

    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra

check_side_block:
    # $a0 = target column
    # returns $v0 = 1 if blocked, 0 if free

    addiu $sp, $sp, -12
    sw $ra, 8($sp)
    sw $s0, 4($sp)
    sw $s1, 0($sp)

    move $s0, $a0 # target col
    lw $s1, row # top row of falling column

    # check board[row][target_col]
    move $a0, $s1
    move $a1, $s0
    jal board_addr
    lw   $t0, 0($v0)
    bne  $t0, $zero, side_blocked

    # check board[row+1][target_col]
    addiu $a0, $s1, 1
    move  $a1, $s0
    jal board_addr
    lw   $t0, 0($v0)
    bne  $t0, $zero, side_blocked

    # check board[row+2][target_col]
    addiu $a0, $s1, 2
    move  $a1, $s0
    jal board_addr
    lw   $t0, 0($v0)
    bne  $t0, $zero, side_blocked

    move $v0, $zero
    j side_done

side_blocked:
    li $v0, 1

side_done:
    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addiu $sp, $sp, 12
    jr $ra

check_collision:
    addiu $sp, $sp, -12
    sw $ra, 8($sp)
    sw $s0, 4($sp)
    sw $s1, 0($sp)

    lw $t0, is_downward_move
    li $t1, 1
    bne $t0, $t1, collision_done # only handle downward moves

    # If row > 10, piece hit bottom
    lw $s0, row
    li $t2, 10
    slt $t3, $t2, $s0 # 1 if 10 < row
    bne $t3, $zero, collision_lock

    # Check whether new position overlaps landed gems
    lw $s1, col

    # board[row+2][col]
    addiu $a0, $s0, 2
    move  $a1, $s1
    jal board_addr
    lw $t4, 0($v0)
    bne $t4, $zero, collision_lock

    # move was valid
    sw $zero, is_downward_move
    j collision_done

collision_lock:
    # restore previous valid row
    lw $t5, prev_row
    sw $t5, row

    # lock current column into board
    jal lock_curr_col

    jal resolve_board
    jal check_game_over

    # spawn next piece
    jal spawn_new_col

    sw $zero, is_downward_move

collision_done:
    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addiu $sp, $sp, 12
    jr $ra

update_game:
    jr $ra

check_game_over:
    addiu $sp, $sp, -4
    sw $ra, 0($sp)

    # third row, third col inside the board
    li $a0, 2
    li $a1, 2
    jal board_addr

    lw $t0, 0($v0)
    beq $t0, $zero, not_game_over

    # game over, quit game
    li $v0, 10
    syscall

not_game_over:
    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra

match_addr:
    # $a0 = logical row 0..12
    # $a1 = logical col 0..5
    # returns $v0 = &match_gems[row][col]

    la $t0, match_gems
    sll $t1, $a0, 2 # row * 4
    sll $t2, $a0, 1 # row * 2
    addu $t1, $t1, $t2 # row * 6
    addu $t1, $t1, $a1 # row * 6 + col
    sll $t1, $t1, 2 # bytes
    addu $v0, $t0, $t1
    jr $ra

clear_match:
    la $t0, match_gems
    li $t1, 78 # 13 * 6 cells

clear_match_loop:
    sw $zero, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bgtz $t1, clear_match_loop
    jr $ra

detect_matches:
    addiu $sp, $sp, -28
    sw $ra, 24($sp)
    sw $s0, 20($sp)
    sw $s1, 16($sp)
    sw $s2, 12($sp)
    sw $s3, 8($sp)
    sw $s4, 4($sp)
    sw $s5, 0($sp)

    jal clear_match
    move $s2, $zero # found_any = 0

    # horizontal matches
    
    li $s0, 0 # row
    
detect_h_row:
    li $t0, 13
    beq $s0, $t0, detect_v_setup

    li $s1, 0 # col
    
detect_h_col:
    li $t0, 4 # start cols 0..3
    beq $s1, $t0, detect_h_next_row

    move $a0, $s0
    move $a1, $s1
    jal board_addr
    lw $s3, 0($v0) # $s3 = first cell colour
    beq $s3, $zero, detect_h_next_col

    move $a0, $s0
    addiu $a1, $s1, 1
    jal board_addr
    lw $s4, 0($v0) # $s4 = second cell colour
    bne $s3, $s4, detect_h_next_col

    move $a0, $s0
    addiu $a1, $s1, 2
    jal board_addr
    lw $s5, 0($v0) # $s5 = third cell colour
    bne $s3, $s5, detect_h_next_col

    li $s2, 1

    # store the matches into match_gems array

    move $a0, $s0
    move $a1, $s1
    jal match_addr
    li $t4, 1
    sw $t4, 0($v0)

    move $a0, $s0
    addiu $a1, $s1, 1
    jal match_addr
    li $t4, 1
    sw $t4, 0($v0)

    move $a0, $s0
    addiu $a1, $s1, 2
    jal match_addr
    li $t4, 1
    sw $t4, 0($v0)

detect_h_next_col:
    addiu $s1, $s1, 1
    j detect_h_col

detect_h_next_row:
    addiu $s0, $s0, 1
    j detect_h_row

    # vertical matches

detect_v_setup:
    li $s0, 0
    
detect_v_row:
    li $t0, 11 # start rows 0..10
    beq $s0, $t0, detect_dr_setup

    li $s1, 0 # col
    
detect_v_col:
    li $t0, 6
    beq $s1, $t0, detect_v_next_row

    move $a0, $s0
    move $a1, $s1
    jal board_addr
    lw $s3, 0($v0) # $s3 = first cell colour
    beq $s3, $zero, detect_v_next_col

    addiu $a0, $s0, 1
    move $a1, $s1
    jal board_addr
    lw $s4, 0($v0) # $s4 = second cell colour
    bne $s3, $s4, detect_v_next_col

    addiu $a0, $s0, 2
    move $a1, $s1
    jal board_addr
    lw $s5, 0($v0) # $s5 = third cell colour
    bne $s3, $s5, detect_v_next_col

    li $s2, 1

    move $a0, $s0
    move $a1, $s1
    jal match_addr
    li $t4, 1
    sw $t4, 0($v0)

    addiu $a0, $s0, 1
    move $a1, $s1
    jal match_addr
    li $t4, 1
    sw $t4, 0($v0)

    addiu $a0, $s0, 2
    move $a1, $s1
    jal match_addr
    li $t4, 1
    sw $t4, 0($v0)

detect_v_next_col:
    addiu $s1, $s1, 1
    j detect_v_col

detect_v_next_row:
    addiu $s0, $s0, 1
    j detect_v_row

    # diagonal down-right

detect_dr_setup:
    li $s0, 0
    
detect_dr_row:
    li $t0, 11 # start rows 0..10
    beq $s0, $t0, detect_dl_setup

    li $s1, 0
    
detect_dr_col:
    li $t0, 4 # start cols 0..3
    beq $s1, $t0, detect_dr_next_row

    move $a0, $s0
    move $a1, $s1
    jal board_addr
    lw $s3, 0($v0) # $s3 = first cell colour
    beq $s3, $zero, detect_dr_next_col

    addiu $a0, $s0, 1
    addiu $a1, $s1, 1
    jal board_addr
    lw $s4, 0($v0) # $s4 = second cell colour
    bne $s3, $s4, detect_dr_next_col

    addiu $a0, $s0, 2
    addiu $a1, $s1, 2
    jal board_addr
    lw $s5, 0($v0) # $s5 = third cell colour
    bne $s3, $s5, detect_dr_next_col

    li $s2, 1

    move $a0, $s0
    move $a1, $s1
    jal match_addr
    li $t4, 1
    sw $t4, 0($v0)

    addiu $a0, $s0, 1
    addiu $a1, $s1, 1
    jal match_addr
    li $t4, 1
    sw $t4, 0($v0)

    addiu $a0, $s0, 2
    addiu $a1, $s1, 2
    jal match_addr
    li $t4, 1
    sw $t4, 0($v0)

detect_dr_next_col:
    addiu $s1, $s1, 1
    j detect_dr_col

detect_dr_next_row:
    addiu $s0, $s0, 1
    j detect_dr_row

    # diagonal down-left

detect_dl_setup:
    li $s0, 0
    
detect_dl_row:
    li $t0, 11 # start rows 0..10
    beq $s0, $t0, detect_clear_phase

    li $s1, 2 # start cols 2..5
    
detect_dl_col:
    li $t0, 6
    beq $s1, $t0, detect_dl_next_row

    move $a0, $s0
    move $a1, $s1
    jal board_addr
    lw $s3, 0($v0) # $s3 = first cell colour
    beq $s3, $zero, detect_dl_next_col

    addiu $a0, $s0, 1
    addiu $a1, $s1, -1
    jal board_addr
    lw $s4, 0($v0) # $s4 = second cell colour
    bne $s3, $s4, detect_dl_next_col

    addiu $a0, $s0, 2
    addiu $a1, $s1, -2
    jal board_addr
    lw $s5, 0($v0) # $s5 = third cell colour
    bne $s3, $s5, detect_dl_next_col

    li $s2, 1

    move $a0, $s0
    move $a1, $s1
    jal match_addr
    li $t4, 1
    sw $t4, 0($v0)

    addiu $a0, $s0, 1
    addiu $a1, $s1, -1
    jal match_addr
    li $t4, 1
    sw $t4, 0($v0)

    addiu $a0, $s0, 2
    addiu $a1, $s1, -2
    jal match_addr
    li $t4, 1
    sw $t4, 0($v0)

detect_dl_next_col:
    addiu $s1, $s1, 1
    j detect_dl_col

detect_dl_next_row:
    addiu $s0, $s0, 1
    j detect_dl_row

    # clear all marked cells

detect_clear_phase:
    beq $s2, $zero, detect_none_found

    li $s0, 0
    
detect_clear_row:
    li $t0, 13
    beq $s0, $t0, detect_found_done

    li $s1, 0
    
detect_clear_col:
    li $t0, 6
    beq $s1, $t0, detect_clear_next_row

    move $a0, $s0
    move $a1, $s1
    jal match_addr
    lw $t1, 0($v0)
    beq $t1, $zero, detect_clear_next_col

    move $a0, $s0
    move $a1, $s1
    jal board_addr
    sw $zero, 0($v0) # delete

detect_clear_next_col:
    addiu $s1, $s1, 1
    j detect_clear_col

detect_clear_next_row:
    addiu $s0, $s0, 1
    j detect_clear_row

detect_found_done:
    li $v0, 1
    j detect_done

detect_none_found:
    move $v0, $zero

detect_done:
    lw $s5, 0($sp)
    lw $s4, 4($sp)
    lw $s3, 8($sp)
    lw $s2, 12($sp)
    lw $s1, 16($sp)
    lw $s0, 20($sp)
    lw $ra, 24($sp)
    addiu $sp, $sp, 28
    jr $ra

fall:
    addiu $sp, $sp, -24
    sw $ra, 20($sp)
    sw $s0, 16($sp)
    sw $s1, 12($sp)
    sw $s2, 8($sp)
    sw $s3, 4($sp)
    sw $s4, 0($sp)

    li $s1, 0 # col

fall_col_loop:
    li $t0, 6
    beq $s1, $t0, fall_done

    li $s2, 12 # write_row
    li $s0, 12 # read_row

fall_read_loop:
    bltz $s0, fall_fill_top

    move $a0, $s0
    move $a1, $s1
    jal board_addr
    lw $s3, 0($v0) # $s3 is current cell colour (or 0 if empty)

    # empty cell
    beq $s3, $zero, fall_next_read 

    # non-empty cell but does not need to fall
    beq $s2, $s0, fall_same_spot

    # non-empty cell but needs to fall
    move $a0, $s2
    move $a1, $s1
    jal board_addr
    sw $s3, 0($v0)

    move $a0, $s0
    move $a1, $s1
    jal board_addr
    sw $zero, 0($v0)

fall_same_spot:
    addiu $s2, $s2, -1 # write_row is now one row higher

fall_next_read:
    addiu $s0, $s0, -1 # read the row above
    j fall_read_loop

fall_fill_top:
    move $s4, $s2

fall_fill_loop:
    bltz $s4, fall_next_col

    move $a0, $s4
    move $a1, $s1
    jal board_addr
    sw $zero, 0($v0)

    addiu $s4, $s4, -1
    j fall_fill_loop

fall_next_col:
    addiu $s1, $s1, 1
    j fall_col_loop

fall_done:
    lw $s4, 0($sp)
    lw $s3, 4($sp)
    lw $s2, 8($sp)
    lw $s1, 12($sp)
    lw $s0, 16($sp)
    lw $ra, 20($sp)
    addiu $sp, $sp, 24
    jr $ra

resolve_board:
    addiu $sp, $sp, -4
    sw $ra, 0($sp)

resolve_loop:
    jal detect_matches
    beq $v0, $zero, resolve_done

    jal fall
    j resolve_loop

resolve_done:
    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra
