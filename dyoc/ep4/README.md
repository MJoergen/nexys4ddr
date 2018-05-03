# Design Your Own Computer - Episode 4 : "Adding hexadecimal output to VGA"

Welcome to the fourth episode of "Design Your Own Computer". In this
episode we will be accomplishing several tasks:
* Adding a complete ASCII font to the system.
* Changing the VGA output to show data using hexadecimal digits.

The font is taken from <https://github.com/dhepper/font8x8>
In order for the synthesis tool to be able to correctly interpret
the contents of the file, all the formatting has been removed.
Essentially, you need to have each array element on a separate line.
The command hread() in line 52 read a single hexadecimal digit.

## Learnings:
Initializing memory directly from a separate text file.

