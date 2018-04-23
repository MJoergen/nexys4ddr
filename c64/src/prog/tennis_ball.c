#include "memorymap.h"
#include "tennis.h"
#include "smult.h"
#include "zeropage.h"

/* Coordinates and velocities are stored in 16 bit numbers in fixed-point
 * representation, where the upper 9 bits are before the fixed-point, and the
 * lower 7 bits are after the fixed-point
 */
char ball_x_lo;
char ball_x_hi;
char ball_y_lo;
char ball_y_hi;
char ball_vx_lo;
char ball_vx_hi;
char ball_vy_lo;
char ball_vy_hi;

// These two arrays contain the matrix ((A11, A12), (A12, -A11)),
// where A11 = ((y*y-x*x)*128)/(x*x+y*y)
// and   A12 = ((-2*x*y)*128)/(x*x+y*y)
// The values are stored as signed 8-bit numbers, i.e. in the range -128 to 127.
// The index into the arrays is 16x+y, where x and y are signed 4-bit
// numbers, i.e. -8<=x,y<=7.
static const unsigned char a11[256] = {
   0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f,
   0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f,
   0x80, 0x00, 0x4c, 0x66, 0x70, 0x75, 0x78, 0x7a,
   0x7b, 0x7a, 0x78, 0x75, 0x70, 0x66, 0x4c, 0x00,
   0x80, 0xb3, 0x00, 0x31, 0x4c, 0x5c, 0x66, 0x6c,
   0x70, 0x6c, 0x66, 0x5c, 0x4c, 0x31, 0x00, 0xb3,
   0x80, 0x9a, 0xcf, 0x00, 0x23, 0x3c, 0x4c, 0x57,
   0x60, 0x57, 0x4c, 0x3c, 0x23, 0x00, 0xcf, 0x9a,
   0x80, 0x8f, 0xb3, 0xdc, 0x00, 0x1b, 0x31, 0x40,
   0x4c, 0x40, 0x31, 0x1b, 0x00, 0xdc, 0xb3, 0x8f,
   0x80, 0x8a, 0xa4, 0xc4, 0xe4, 0x00, 0x16, 0x29,
   0x37, 0x29, 0x16, 0x00, 0xe4, 0xc4, 0xa4, 0x8a,
   0x80, 0x87, 0x9a, 0xb3, 0xcf, 0xe9, 0x00, 0x13,
   0x23, 0x13, 0x00, 0xe9, 0xcf, 0xb3, 0x9a, 0x87,
   0x80, 0x86, 0x94, 0xa8, 0xbf, 0xd7, 0xec, 0x00,
   0x10, 0x00, 0xec, 0xd7, 0xbf, 0xa8, 0x94, 0x86,
   0x80, 0x84, 0x8f, 0xa0, 0xb3, 0xc8, 0xdc, 0xef,
   0x00, 0xef, 0xdc, 0xc8, 0xb3, 0xa0, 0x8f, 0x84,
   0x80, 0x86, 0x94, 0xa8, 0xbf, 0xd7, 0xec, 0x00,
   0x10, 0x00, 0xec, 0xd7, 0xbf, 0xa8, 0x94, 0x86,
   0x80, 0x87, 0x9a, 0xb3, 0xcf, 0xe9, 0x00, 0x13,
   0x23, 0x13, 0x00, 0xe9, 0xcf, 0xb3, 0x9a, 0x87,
   0x80, 0x8a, 0xa4, 0xc4, 0xe4, 0x00, 0x16, 0x29,
   0x37, 0x29, 0x16, 0x00, 0xe4, 0xc4, 0xa4, 0x8a,
   0x80, 0x8f, 0xb3, 0xdc, 0x00, 0x1b, 0x31, 0x40,
   0x4c, 0x40, 0x31, 0x1b, 0x00, 0xdc, 0xb3, 0x8f,
   0x80, 0x9a, 0xcf, 0x00, 0x23, 0x3c, 0x4c, 0x57,
   0x60, 0x57, 0x4c, 0x3c, 0x23, 0x00, 0xcf, 0x9a,
   0x80, 0xb3, 0x00, 0x31, 0x4c, 0x5c, 0x66, 0x6c,
   0x70, 0x6c, 0x66, 0x5c, 0x4c, 0x31, 0x00, 0xb3,
   0x80, 0x00, 0x4c, 0x66, 0x70, 0x75, 0x78, 0x7a,
   0x7b, 0x7a, 0x78, 0x75, 0x70, 0x66, 0x4c, 0x00};

static const unsigned char a12[256] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x80, 0x9a, 0xb3, 0xc4, 0xcf, 0xd7, 0xdc,
   0x1f, 0x23, 0x29, 0x31, 0x3c, 0x4c, 0x66, 0x7f,
   0x00, 0x9a, 0x80, 0x8a, 0x9a, 0xa8, 0xb3, 0xbd,
   0x3c, 0x43, 0x4c, 0x57, 0x66, 0x75, 0x7f, 0x66,
   0x00, 0xb3, 0x8a, 0x80, 0x86, 0x8f, 0x9a, 0xa4,
   0x53, 0x5c, 0x66, 0x70, 0x7a, 0x7f, 0x75, 0x4c,
   0x00, 0xc4, 0x9a, 0x86, 0x80, 0x84, 0x8a, 0x92,
   0x66, 0x6d, 0x75, 0x7c, 0x7f, 0x7a, 0x66, 0x3c,
   0x00, 0xcf, 0xa8, 0x8f, 0x84, 0x80, 0x83, 0x87,
   0x72, 0x78, 0x7d, 0x7f, 0x7c, 0x70, 0x57, 0x31,
   0x00, 0xd7, 0xb3, 0x9a, 0x8a, 0x83, 0x80, 0x82,
   0x7a, 0x7e, 0x7f, 0x7d, 0x75, 0x66, 0x4c, 0x29,
   0x00, 0xdc, 0xbd, 0xa4, 0x92, 0x87, 0x82, 0x80,
   0x7e, 0x7f, 0x7e, 0x78, 0x6d, 0x5c, 0x43, 0x23,
   0x00, 0x1f, 0x3c, 0x53, 0x66, 0x72, 0x7a, 0x7e,
   0x80, 0x82, 0x86, 0x8d, 0x9a, 0xac, 0xc4, 0xe1,
   0x00, 0x23, 0x43, 0x5c, 0x6d, 0x78, 0x7e, 0x7f,
   0x82, 0x80, 0x82, 0x87, 0x92, 0xa4, 0xbd, 0xdc,
   0x00, 0x29, 0x4c, 0x66, 0x75, 0x7d, 0x7f, 0x7e,
   0x86, 0x82, 0x80, 0x83, 0x8a, 0x9a, 0xb3, 0xd7,
   0x00, 0x31, 0x57, 0x70, 0x7c, 0x7f, 0x7d, 0x78,
   0x8d, 0x87, 0x83, 0x80, 0x84, 0x8f, 0xa8, 0xcf,
   0x00, 0x3c, 0x66, 0x7a, 0x7f, 0x7c, 0x75, 0x6d,
   0x9a, 0x92, 0x8a, 0x84, 0x80, 0x86, 0x9a, 0xc4,
   0x00, 0x4c, 0x75, 0x7f, 0x7a, 0x70, 0x66, 0x5c,
   0xac, 0xa4, 0x9a, 0x8f, 0x86, 0x80, 0x8a, 0xb3,
   0x00, 0x66, 0x7f, 0x75, 0x66, 0x57, 0x4c, 0x43,
   0xc4, 0xbd, 0xb3, 0xa8, 0x9a, 0x8a, 0x80, 0x9a,
   0x00, 0x7f, 0x66, 0x4c, 0x3c, 0x31, 0x29, 0x23,
   0xe1, 0xdc, 0xd7, 0xcf, 0xc4, 0xb3, 0x9a, 0x80};

void __fastcall__ ball_reset(void)
{
   ball_x_hi  = WALL_XPOS/4-3;
   ball_x_lo  = 0;
   ball_y_hi  = WALL_YPOS/4;
   ball_y_lo  = 0;
   ball_vx_hi = 0;
   ball_vx_lo = 0;
   ball_vy_hi = 0;
   ball_vy_lo = 0;
} // end of ball_reset

// This function calculates w = A*v, i.e.
// wx = A11*vx + A12*vy and
// wy = A12*vx - A11*vy
//
// Input to this function is the matrix A, where
// A11 = -A22 and A12 = A21.
// So we must have A11 in 'A' and A12 in 'X'.
// A11 and A12 are signed 8-bit numbers, with seven bits after the fixed-point.
// vx and vy are signed 16-bit number, with 9 bits before the fixed-point.
// We assume that |vx| and |vy| are both less than 2.
void __fastcall__ ball_rotate(void)
{
   __asm__("STA %b", ZP_BALL_T2);
   __asm__("TXA");
   __asm__("STA %b", ZP_BALL_T3);

   // Convert velocity to signed 8-bit (fraction of 128)
   __asm__("LDA %v", ball_vx_hi);
   __asm__("ROL A");    // Move sign into carry
   __asm__("LDA %v", ball_vx_lo);
   __asm__("ROR A");
   __asm__("STA %b", ZP_BALL_T0);
   __asm__("LDA %v", ball_vy_hi);
   __asm__("ROL A");    // Move sign into carry
   __asm__("LDA %v", ball_vy_lo);
   __asm__("ROR A");
   __asm__("STA %b", ZP_BALL_T1);

   // Move A12 to 'X' and Vy to 'A'
   __asm__("LDA %b", ZP_BALL_T3);
   __asm__("TAX");
   __asm__("LDA %b", ZP_BALL_T1);
   smult();
   __asm__("STA %b", ZP_BALL_T4);
   __asm__("TXA");
   __asm__("STA %b", ZP_BALL_T5);

   // Move A11 to 'X' and Vx to 'A'
   __asm__("LDA %b", ZP_BALL_T2);
   __asm__("TAX");
   __asm__("LDA %b", ZP_BALL_T0);
   smult();
   __asm__("ADC %b", ZP_BALL_T4);
   __asm__("STA %b", ZP_BALL_T4);
   __asm__("TXA");
   __asm__("ADC %b", ZP_BALL_T5);
   __asm__("STA %b", ZP_BALL_T5);

   // Move A11 to 'X' and Vy to 'A'
   __asm__("LDA %b", ZP_BALL_T2);
   __asm__("TAX");
   __asm__("LDA %b", ZP_BALL_T1);
   smult();
   __asm__("STA %b", ZP_BALL_T6);
   __asm__("TXA");
   __asm__("STA %b", ZP_BALL_T7);

   // Move A12 to 'X' and Vx to 'A'
   __asm__("LDA %b", ZP_BALL_T3);
   __asm__("TAX");
   __asm__("LDA %b", ZP_BALL_T0);
   smult();
   __asm__("SBC %b", ZP_BALL_T6);
   __asm__("STA %b", ZP_BALL_T6);
   __asm__("TXA");
   __asm__("SBC %b", ZP_BALL_T7);
   __asm__("STA %b", ZP_BALL_T7);

   // Convert to 9.7 bit representation
   __asm__("LDA %b", ZP_BALL_T7);
   __asm__("ROL A");  // Copy MSB to carry
   __asm__("LDA #$00");
   __asm__("SBC #$00");
   __asm__("EOR #$FF"); // If carry was 1, then result is 0xFF, else 0x00

   // At this point we expect the ball to bounce up-ward now, so we
   // expect vy to be negative.
   // It can happen, (during multiple collisions), that vy is positive.
   // In this case, we just don't update anything.
   __asm__("BEQ %g", skip);

   __asm__("STA %v", ball_vy_hi);
   __asm__("LDA %b", ZP_BALL_T6);
   __asm__("ROL A");
   __asm__("LDA %b", ZP_BALL_T7);
   __asm__("ROL A");

   // Multiply Vy by 2
   __asm__("ROL A");
   __asm__("STA %v", ball_vy_lo);
   __asm__("LDA %v", ball_vy_hi);
   __asm__("ROL A");
   __asm__("STA %v", ball_vy_hi);

   __asm__("LDA %b", ZP_BALL_T5);
   __asm__("ROL A");  // Copy MSB to carry
   __asm__("LDA #$00");
   __asm__("SBC #$00");
   __asm__("EOR #$FF"); // If carry was 1, then result is 0xFF, else 0x00
   __asm__("STA %v", ball_vx_hi);
   __asm__("LDA %b", ZP_BALL_T4);
   __asm__("ROL A");
   __asm__("LDA %b", ZP_BALL_T5);
   __asm__("ROL A");

   // Multiply Vx by 2
   __asm__("ROL A");
   __asm__("STA %v", ball_vx_lo);
   __asm__("LDA %v", ball_vx_hi);
   __asm__("ROL A");
   __asm__("STA %v", ball_vx_hi);

skip:
   __asm__("RTS");
} // end of ball_rotate

// ball_bounce: Adjust the ball's velocity upon bouncing off a player.
// Let CB be the centre of the ball, and
// let CP be the centre of the player, and
//
// Let v be the velocity vector of the ball, and
// let dv be the change (acceleration) in this velocity vector.
//
// Some algebra gives the following equation
// dv = (-2v*PB)/|PB|^2 * PB
//
// Note that v*PB must be negative, indicating that the ball
// is travelling into the player. If v*PB is positive, then
// no need to update v.
//
// One way to organize the calculations is as follows:
// Let w be the new velocity, i.e. w = v+dv. Then
// w = A*v, where A = I - 2*(PBx,PBy)^T*(PBx,PBy)/|PB|^2
//
// It is useful to rewrite the matrix A as:
// A11=-A22=(PBy^2-PBx^2)/(PBy^2+PBx^2) and A12=A21=(-2*PBx*PBy)/(PBy^2+PBx^2).
// The matrix A is a rotation matrix with determinant -1, i.e. it does a reflection too.
// The matrix A is found by table lookup.
//
// Example:
// CB = (0x4A, 0xD5)
// CP = (0x50, 0xE2)
// v  = vertical = (0, +1.625)
// We calculate PB = (-6, -13), and PB/2 = (-3, -7).
// We look up the matrix A, and find A11 = 0.69 (0x58) and A12 = -0.73 (0xA3).
// We then calculate w = A*v = (-1.186, -1.12)
// So wx = -1.186 (0xFF68)
// and wy = -1.12 (0xFF71)

// This functions bounces the ball on a player.
// Input is the players coordinates divided by two,
// i.e. 'X' = Px/2 and 'A' = Py/2
void __fastcall__ ball_bounce(void)
{
   // First we must calculate PB/2
   // We divide by two, so that the coordinates of PB/2 can be represented in
   // two 4-bit signed numbers. This is because |PB/2| < 8.

   __asm__("SEC");
   __asm__("EOR #$FF");
   __asm__("ADC %v", ball_y_hi); // This contains By/2.
// __asm__("STA %b", ZP_BALL_T0);   // Debug
   __asm__("AND #$0F");
   __asm__("STA %b", ZP_BALL_T1);

   __asm__("TXA");
   __asm__("SEC");
   __asm__("EOR #$FF");
   __asm__("ADC %v", ball_x_hi); // This contains Bx/2.

   __asm__("ASL A");
   __asm__("ASL A");
   __asm__("ASL A");
   __asm__("ASL A");
   __asm__("CLC");
   __asm__("ADC %b", ZP_BALL_T1);

// __asm__("STA %b", ZP_BALL_T1);   // Debug

   // Now look up the matrix elements A11 and A12
   __asm__("TAX");
   __asm__("LDA %v,X", a11);
// __asm__("STA %b", ZP_BALL_T2); // Debug
   __asm__("TAY");
   __asm__("LDA %v,X", a12);
// __asm__("STA %b", ZP_BALL_T3); // Debug
   __asm__("TAX");
   __asm__("TYA");

// __asm__("RTS");   // Debug

   // Now we have A11 in 'A' and A12 in 'X'.
   ball_rotate();

} // end of ball_bounce

void __fastcall__ ball_move(void)
{
   // Update velocity
   __asm__("LDA %v", ball_vy_lo);
   __asm__("CLC");
   __asm__("ADC #%b", GRAVITY);
   __asm__("STA %v", ball_vy_lo);
   __asm__("LDA %v", ball_vy_hi);
   __asm__("ADC #$00");
   __asm__("STA %v", ball_vy_hi);

   // Update position
   __asm__("LDA %v", ball_y_lo);
   __asm__("CLC");
   __asm__("ADC %v", ball_vy_lo);
   __asm__("STA %v", ball_y_lo);
   __asm__("LDA %v", ball_y_hi);
   __asm__("ADC %v", ball_vy_hi);
   __asm__("STA %v", ball_y_hi);

   __asm__("LDA %v", ball_x_lo);
   __asm__("CLC");
   __asm__("ADC %v", ball_vx_lo);
   __asm__("STA %v", ball_x_lo);
   __asm__("LDA %v", ball_x_hi);
   __asm__("ADC %v", ball_vx_hi);
   __asm__("STA %v", ball_x_hi);

   // Update VGA
   __asm__("LDA %v", ball_x_lo);
   __asm__("ROL A");
   __asm__("LDA %v", ball_x_hi);
   __asm__("ROL A");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_X);
   __asm__("LDA #$00");
   __asm__("ROL A");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_X_MSB);

   __asm__("LDA %v", ball_y_lo);
   __asm__("ROL A");
   __asm__("LDA %v", ball_y_hi);
   __asm__("ROL A");
   __asm__("STA %w", VGA_ADDR_SPRITE_0_Y);
} // end of ball_move

