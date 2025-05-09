
svc wifi disable
sleep 3
svc wifi enable
sleep 8
termux-wake-lock
sshd
am force-stop com.termux
am start -n com.termux/.app.TermuxActivity
