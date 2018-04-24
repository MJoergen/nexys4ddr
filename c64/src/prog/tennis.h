#define COL_WHITE       0xFFU  // 111_111_11
#define COL_RED         0xE0U  // 111_000_00
#define COL_LIGHT       0x6E   // 011_011_10
#define COL_DARK        0x24   // 001_001_00
#define COL_BLACK       0x00   // 000_000_00

#define SIZE_X          (320U)
#define WALL_XPOS       (160U-8)
#define WALL_YPOS       218U

#define GRAVITY         1
#define PLAYER_VEL      1
#define PLAYER_LEFT_MARGIN   0
#define PLAYER_RIGHT_MARGIN  WALL_XPOS+6
#define AI_VEL          1
#define AI_LEFT_MARGIN   WALL_XPOS+10
#define AI_RIGHT_MARGIN  WALL_XPOS*2

