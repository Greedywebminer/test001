
svc wifi disable
sleep 2
svc wifi enable
termux-wake-lock
sshd
am force-stop com.termux
am start -n com.termux/.app.TermuxActivity
