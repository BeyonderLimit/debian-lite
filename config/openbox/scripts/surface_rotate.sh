#!/bin/bash
# Target variables for Surface Pro 5 hardware
DISPLAY_OUTPUT="eDP-1"
TOUCH_DEVICE="Intel Precise Touch Screen"

# Empty old logs to prevent disk clutter
> /tmp/sensor.log
monitor-sensor >> /tmp/sensor.log 2>&1 &

# Infinite monitor loop utilizing inotify watches
while inotifywait -e modify /tmp/sensor.log >/dev/null 2>&1; do
    ORIENTATION=$(tail -n 5 /tmp/sensor.log | grep 'orientation' | tail -n 1 | grep -oE '[^ ]+$')
    
    case "$ORIENTATION" in
        normal)
            xrandr --output "$DISPLAY_OUTPUT" --rotate normal
            xinput set-prop "$TOUCH_DEVICE" "Coordinate Transformation Matrix" 1 0 0 0 1 0 0 0 1
            ;;
        bottom-up)
            xrandr --output "$DISPLAY_OUTPUT" --rotate inverted
            xinput set-prop "$TOUCH_DEVICE" "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1
            ;;
        right-up)
            xrandr --output "$DISPLAY_OUTPUT" --rotate right
            xinput set-prop "$TOUCH_DEVICE" "Coordinate Transformation Matrix" 0 1 0 -1 0 1 0 0 1
            ;;
        left-up)
            xrandr --output "$DISPLAY_OUTPUT" --rotate left
            xinput set-prop "$TOUCH_DEVICE" "Coordinate Transformation Matrix" 0 -1 1 1 0 0 0 0 1
            ;;
    esac
done
