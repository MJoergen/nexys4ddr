from PIL import Image, ImageFile
import os

class BinImageFile(ImageFile.ImageFile):

    format = "BIN"
    format_description = "Bin raster image"

    def _open(self):
        print "open;", self.fp.name
        # check file length
        l = os.path.getsize(self.fp.name)
        print l
        if l != 640*480:
            err = "Incorrect length " + str(body.len())
            raise SyntaxError, err

        # size in pixels (width, height)
        self.size = 640, 480

        # mode setting
        self.mode = "P"

        # data descriptor
        self.tile = [
            ("raw", (0, 0) + self.size, 0, (self.mode, 0, 1))
        ]

Image.register_open(BinImageFile.format, BinImageFile)
Image.register_extension(BinImageFile.format, ".bin")

