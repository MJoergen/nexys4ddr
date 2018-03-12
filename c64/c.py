#!/usr/bin/env python

from PIL import Image
import BinImagePlugin
import StringIO
import glob

flist = glob.glob('frame_*.bin')
for f in flist:
    im = Image.open(f)
    newf = f[:-3] + "png"
    im.save(newf)

