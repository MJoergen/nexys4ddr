#!/usr/bin/env bash

ffmpeg -r 60 -f image2 -s 640x480 -i frame_%04d.png -vcodec libx264 -crf 25  -pix_fmt yuv420p test.mp4
