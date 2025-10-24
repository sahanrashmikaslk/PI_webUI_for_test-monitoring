#!/bin/bash
cd /usr/local/lib/mjpg-streamer
exec /usr/local/bin/mjpg_streamer \
  -i "/usr/local/lib/mjpg-streamer/input_uvc.so -d /dev/video0 -r 1920x1080 -f 15 -y" \
  -o "/usr/local/lib/mjpg-streamer/output_http.so -p 8081 -w /usr/local/share/mjpg-streamer/www"
