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

landed_top_gem:
    .word 0

landed_mid_gem:
    .word 0

landed_bottom_gem:
    .word 0

landed_row:
    .word 0

landed_col:
    .word 0

has_landed:
    .word 0

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
    jal clear_screen
    jal draw_grid
    jal draw_curr_col
  
	# 4. Sleep
    li $v0, 32
    li $a0, 16 # 1000ms / 60 fps = approx. 16ms per frame
    syscall

    # 5. Go back to Step 1
    j game_loop

clear_screen:
    lw $t0, ADDR_DSPL
    lw $t1, BLACK
    li $t2, 4096 # 64 * 64

clear_loop:
    sw $t1, 0($t0)
    addiu $t0, $t0, 4
    addiu $t2, $t2, -1
    bgtz $t2, clear_loop
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

    li $a0, 52 # row
    move $a1, $s1 # col
    move $a2, $s0 # colour
    jal draw_cell

    addiu $s1, $s1, 4
    j bottom_loop

left_border:
    li $s1, 0 # row, starting at 0

left_loop:
    li $s2, 56 # end row
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
    li $s2, 56 # end row
    
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
    addiu $t1, $t1, -1
    sw $t1, col
    jr $ra

respond_to_D:
    lw $t1, col
    li $t2, 5 # max col = 5
    slt $t3, $t1, $t2 # 1 if col < 5
    beq $t3, $zero, input_done # prevent going past right wall
    addiu $t1, $t1, 1
    sw $t1, col
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
    # addiu $sp, $sp, -4
    # sw $ra, 0($sp)
    
    lw $t1, row
    li $t2, 9 # max top row = 9
    slt $t3, $t1, $t2 # 1 if row < 9
    beq $t3, $zero, input_done
    addiu $t1, $t1, 9 # change later
    sw $t1, row
    jr $ra

    # # move current col to the bottom
    # li $t1, 9 #fixed at 9 rn, change later
    # sw $t1, landed_row
    # lw $t1, col
    # sw $t1, landed_col

    # lw $t1, top_gem
    # sw $t1, landed_top_gem
    # lw $t1, mid_gem
    # sw $t1, landed_mid_gem
    # lw $t1, bottom_gem
    # sw $t1, landed_bottom_gem
    # li $t1, 1
    # sw $t1, has_landed

    # # spawn new current col at top middle
    # li $t1, 0
    # sw $t1, row
    # li $t1, 2
    # sw $t1, col

    # jal randomize_gem_colour

    # lw $ra, 0($sp)
    # addiu $sp, $sp, 4
    jr $ra

input_done:
    jr $ra

check_collision:
    jr $ra

update_game:
    jr $ra
