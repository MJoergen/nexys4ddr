// This contains all the zero-page variables used in the program.

#define ZP_SCREEN_POS_LO   0x00
#define ZP_SCREEN_POS_HI   0x01
#define ZP_STOP            0x02
#define ZP_TEMP            0x03
#define ZP_CURSOR_CHAR     0x04  // Character at cursor
#define ZP_XSCROLL         0x05
#define ZP_CNT             0x06

#define ZP_XLO             0x10
#define ZP_XHI             0x11
#define ZP_YLO             0x12
#define ZP_YHI             0x13
#define ZP_XYLO            0x14
#define ZP_XYHI            0x15

#define ZP_SMULT_A         0x20
#define ZP_SMULT_X         0x21
#define ZP_SMULT_T1        0x22
#define ZP_SMULT_T2        0x23

#define ZP_UMULT_A         0x30
#define ZP_UMULT_X         0x31
#define ZP_UMULT_C         0x32

#define ZP_SRC_LO          0x40
#define ZP_SRC_HI          0x41
#define ZP_DST_LO          0x42
#define ZP_DST_HI          0x43
