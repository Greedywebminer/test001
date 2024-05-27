#!/bin/bash

adb shell "input text 'cd .termux'"
adb shell input keyevent 66

adb shell "input text 'mkdir boot'"
adb shell input keyevent 66

adb shell "input text 'cd boot/'"
adb shell input keyevent 66

adb shell "input text 'pwd'"
adb shell input keyevent 66

adb shell "input text 'nano termux-boot.sh'"
adb shell input keyevent 66
