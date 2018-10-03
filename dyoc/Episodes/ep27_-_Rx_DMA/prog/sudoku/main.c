/******************************************************************************
 *
 * Sudoku solver
 *
 * Copyright (C) 2007 by Juergen Buchmueller <pullmoll@t-online.de>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 * $Id: sudoku.c,v 1.1.1.1 2007/10/21 17:38:24 pullmoll Exp $
 ******************************************************************************/
#include <conio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef struct sudoku_s {
        struct  sudoku_s *next;
        int f[9][9];
        int p[9][9];
}       sudoku_t;

#define SETP(s,x,y,n) do { s->p[y][x] |= (1 << (n)); } while (0)
#define CLRP(s,x,y,n) do { s->p[y][x] &= ~(1 << (n)); } while (0)
#define ISP(s,x,y,n) (s->p[y][x] & (1 << (n)))

/**
 * @brief return number of 1 bits in a 32 bit value
 *
 * 32-bit recursive reduction using SWAR,
 * but first step is mapping 2-bit values
 * into sum of 2 1-bit values in sneaky way.
 */
static int ones(long val)
{
        val -= ((val >> 1) & 0x55555555);
        val = (((val >> 2) & 0x33333333) + (val & 0x33333333));
        val = (((val >> 4) + val) & 0x0f0f0f0f);
        val += (val >> 8);
        val += (val >> 16);
        return (val & 0x3f);
}

/**
 * @brief solve one step
 *
 * find the crossing with the lowest number of possibilities
 * and try all possible numbers on it, recursively calling
 * solve_step() until the puzzle is solved.
 */
static int solve_step(sudoku_t *s)
{
        int min_x, min_y, min_n;
        int x, y, n, rc;

        /* find the crossing with the lowest number of possibilities */
        for (y = 0, min_n = 10, min_x = 0, min_y = 0; y < 9; y++) {
                for (x = 0; x < 9; x++) {
                        if (s->f[y][x])
                                continue;
                        n = ones(s->p[y][x]);
                        if (n > min_n)
                                continue;
                        min_n = n;
                        min_x = x;
                        min_y = y;
                }
        }

        /* solved? */
        if (10 == min_n) {
                cprintf("solved");
                return 1;
        }

        x = min_x;
        y = min_y;
        if (0 == min_n) {
                cprintf("%d,%d: impossible, backing up ", x, y);
                return 0;
        }

        cprintf("%d,%d: %d possible: ", x, y, min_n);
        for (n = 1; n <= 9; n++) {
                if (ISP(s, x, y, n))
                        cprintf(" %d", n);
        }
        cprintf("\n");

        s->next = calloc(1, sizeof(sudoku_t));
        for (n = 1; n <= 9; n++) {
                memcpy(s->next, s, sizeof(*s));
                s->next->next = NULL;
                if (ISP(s, x, y, n)) {
                        CLRP(s->next,0,y,n);
                        CLRP(s->next,1,y,n);
                        CLRP(s->next,2,y,n);
                        CLRP(s->next,3,y,n);
                        CLRP(s->next,4,y,n);
                        CLRP(s->next,5,y,n);
                        CLRP(s->next,6,y,n);
                        CLRP(s->next,7,y,n);
                        CLRP(s->next,8,y,n);
                        CLRP(s->next,x,0,n);
                        CLRP(s->next,x,1,n);
                        CLRP(s->next,x,2,n);
                        CLRP(s->next,x,3,n);
                        CLRP(s->next,x,4,n);
                        CLRP(s->next,x,5,n);
                        CLRP(s->next,x,6,n);
                        CLRP(s->next,x,7,n);
                        CLRP(s->next,x,8,n);
                        s->next->f[y][x] = n;
                        cprintf("trying %d,%d = %d\n", x, y, n);
                        rc = solve_step(s->next);
                        if (rc)
                                return rc;
                }
        }
        /* it did not solve, so discard this branch */
        free(s->next);
        s->next = NULL;
        return 0;
}

static int sudoku_read(sudoku_t *s, const char *src)
{
        int x, y, n;

        x = 0;
        y = 0;
        while (*src) {
                while (isspace(*src))
                        src++;
                n = 0;
                while (isdigit(*src)) {
                        n = n * 10 + *src - '0';
                        src++;
                }
                s->f[y][x] = n;
                while (isspace(*src))
                        src++;
                if (*src == ',' || *src == '\n')
                        src++;
                x++;
                if (x == 9) {
                        x = 0;
                        y++;
                        if (y == 9)
                                break;
                }
        }

        for (y = 0; y < 9; y++) {
                for (x = 0; x < 9; x++) {
                        for (n = 1; n <= 9; n++)
                                SETP(s,x,y,n);
                }
        }

        for (y = 0; y < 9; y++) {
                for (x = 0; x < 9; x++) {
                        n = s->f[y][x];
                        if (0 == n)
                                continue;
                        CLRP(s,0,y,n);
                        CLRP(s,1,y,n);
                        CLRP(s,2,y,n);
                        CLRP(s,3,y,n);
                        CLRP(s,4,y,n);
                        CLRP(s,5,y,n);
                        CLRP(s,6,y,n);
                        CLRP(s,7,y,n);
                        CLRP(s,8,y,n);
                        CLRP(s,x,0,n);
                        CLRP(s,x,1,n);
                        CLRP(s,x,2,n);
                        CLRP(s,x,3,n);
                        CLRP(s,x,4,n);
                        CLRP(s,x,5,n);
                        CLRP(s,x,6,n);
                        CLRP(s,x,7,n);
                        CLRP(s,x,8,n);
                }
        }

        return 0;
}

static const char *sudoku_row(sudoku_t *s, int y)
{
        static char buff[2*9+1];
        int x;

        for (x = 0; x < 9; x++) {
                buff[2*x+0] = s->f[y][x] ? s->f[y][x] + '0' : '-';
                buff[2*x+1] = ',';
        }
        buff[2*9 - 1] = '\0';
        return buff;
}

int main(void)
{
        sudoku_t *s, *s0;
        const char *src =
                "0,2,0,0,3,0,0,6,5\n"
                "0,0,3,2,6,8,7,0,0\n"
                "8,0,4,0,0,0,0,0,0\n"
                "2,0,0,0,0,6,1,8,7\n"
                "1,0,0,8,0,7,0,9,2\n"
                "9,0,7,3,0,0,0,0,4\n"
                "0,0,8,0,0,0,9,0,0\n"
                "0,0,0,6,9,3,5,0,0\n"
                "3,5,0,0,8,0,0,1,0\n";

/* The solution for this one is:
 *              "7,2,1,4,3,9,8,6,5\n"
 *              "5,9,3,2,6,8,7,4,1\n"
 *              "8,6,4,1,7,5,2,3,9\n"
 *              "2,3,5,9,4,6,1,8,7\n"
 *              "1,4,6,8,5,7,3,9,2\n"
 *              "9,8,7,3,2,1,6,5,4\n"
 *              "6,7,8,5,1,4,9,2,3\n"
 *              "4,1,2,6,9,3,5,7,8\n"
 *              "3,5,9,7,8,2,4,1,6\n";
 */
        s0 = s = calloc(1, sizeof(sudoku_t));
        sudoku_read(s, src);
        cprintf("\n");
        cprintf(sudoku_row(s, 0));
        cprintf(sudoku_row(s, 1));
        cprintf(sudoku_row(s, 2));
        cprintf(sudoku_row(s, 3));
        cprintf(sudoku_row(s, 4));
        cprintf(sudoku_row(s, 5));
        cprintf(sudoku_row(s, 6));
        cprintf(sudoku_row(s, 7));
        cprintf(sudoku_row(s, 8));
        cprintf("\n");

        solve_step(s);
        while (s->next)
                s = s->next;

        cprintf("\n");
        cprintf(sudoku_row(s, 0));
        cprintf(sudoku_row(s, 1));
        cprintf(sudoku_row(s, 2));
        cprintf(sudoku_row(s, 3));
        cprintf(sudoku_row(s, 4));
        cprintf(sudoku_row(s, 5));
        cprintf(sudoku_row(s, 6));
        cprintf(sudoku_row(s, 7));
        cprintf(sudoku_row(s, 8));
        cprintf("\n");

        return 0;
}
