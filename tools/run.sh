#!/bin/bash
# Dev helper: run a scene under xvfb with software GL and print only errors.
# usage: tools/run.sh res://scenes/foo.tscn -- --shot=/tmp/x.png
cd "$(dirname "$0")/.."
timeout ${RUN_TIMEOUT:-90} xvfb-run -a -s "-screen 0 1200x2000x24" ${GODOT:-/tmp/godot/godot} --rendering-driver opengl3 --resolution ${RES:-1080x1920} --path . "$@" 2>&1 | grep -vE "ALSA|status < 0|dummy driver|V-Sync|set_use_vsync|audio_driver|^\s*$|OpenGL API|Godot Engine v" | head -${LINES_MAX:-40}
