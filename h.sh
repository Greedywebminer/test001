adb shell "input text 'nano \$HOME/.bashrc'"
adb shell input keyevent 66  # Press Enter to open nano

adb shell "input text 'termux-wake-lock'"
adb shell input keyevent 66  # Press Enter to enter the command

adb shell "input text 'sshd'"
adb shell input keyevent 66  # Press Enter to enter the command

adb shell "input text 'cd ccminer && ./start.sh'"
adb shell input keyevent 66  # Press Enter to enter the command
