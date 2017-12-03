# 2017-11-11 
Initial checkin. The purpose is to setup the project and get a display on the
VGA port.

The board is clocked by an external crystal of 100 MHz. The VGA port is
configured for a 1280x1024 display, and requires a clock of 108 MHz. This is
easily done by using the MMCM clock wizard.

# 2017-11-23
Reorganized the code, and added a small amount of graphics: Now it can display
a single binary digit, reflecting the input of the rightmost switch.

# 2017-11-25
Focused on the VGA display so far.

# 2017-12-02
I completely reworked the VGA part, making it into a proper 5-stage pipeline. The image
is much clearer, at the code is simpler too, I believe.

# 2017-12-03
I've implemented the ALU, and written a separate test bench for this module. I will
be writing test benches for most of the modules individually, in order to speed up
testing.
