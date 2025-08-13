#!/bin/bash
# Creates a screenshot and saves it to the folder I am currently in

screenshot() {
    local screenshot_name="${1:-screenshot}"
    adb shell screencap -p > "${screenshot_name}.png"
}