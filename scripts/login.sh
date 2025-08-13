#!/bin/bash
# Login to ATV if username and password are the same
# Entry in the format "login xxxxxxx"
# where xxxxxxx is the username/password

login() {
  text="$1"
  adb shell "input keyevent 23" # Enter
  adb shell "input keyevent 22" # Arrow Right

  sleep 0.1
  for ((i=0; i<${#text}; i++)); do
    char="${text:$i:1}"
    adb shell "input text '$char'"
    sleep 0.1  
  done

  adb shell "input keyevent 23"
  sleep 0.1
  for ((i=0; i<${#text}; i++)); do
    char="${text:$i:1}"
    adb shell "input text '$char'"
    sleep 0.1
  done

  adb shell "input keyevent 23"
}