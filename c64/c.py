#!/usr/bin/env python

from PIL import Image
import BinImagePlugin
import StringIO

im = Image.open("frame_0070.bin")
im.show()
