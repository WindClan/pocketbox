#!/usr/bin/env bash
for i in (*.flac) do ffmpeg -i "$i" -f s16le -c:a pcm_s16le -ar 44100 -ac 2 "${i%.*}.cdda";