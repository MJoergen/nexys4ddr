#ifndef _CURSES_H_
#define _CURSES_H_

#include <stdint.h>

struct _win_st
{
   uint8_t _curx, _cury;
   uint8_t flags;
};

typedef struct _win_st WINDOW;

WINDOW *stdscr;

WINDOW * initscr(void);
uint8_t cbreak(void);
uint8_t nocbreak(void);
uint8_t echo(void);
uint8_t noecho(void);
uint8_t nl(void);
uint8_t nonl(void);

uint8_t  clear(void);
uint16_t getch(void);
uint8_t  refresh(void);
uint8_t  move(uint8_t, uint8_t);
uint8_t  keypad(WINDOW *, uint8_t);
uint8_t  wprintw(WINDOW *, const char *, ...);
uint8_t  mvwaddch(WINDOW *, uint8_t, uint8_t, char);
uint8_t  endwin(void);

#define mvaddch(y,x,ch)       mvwaddch(stdscr,(y),(x),(ch))

#define KEY_DOWN        0x0102   /* down-arrow key */
#define KEY_UP          0x0103   /* up-arrow key */
#define KEY_LEFT        0x0104   /* left-arrow key */
#define KEY_RIGHT       0x0105   /* right-arrow key */
#define KEY_HOME        0x0106   /* home key */
#define KEY_BACKSPACE   0x0107   /* backspace key */


#endif // _CURSES_H_

