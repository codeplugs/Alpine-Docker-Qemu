#!/bin/bash
set -e

# === CONFIG ===
export ALPINE_ISO_URL="https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/x86_64/alpine-virt-3.17.9-x86_64.iso"
export IMG_FILE="alpine.img"
export IMG_SIZE="3G"
export ROOT_PASSWORD="ga#£&26GZv16352525"
export PREFIX=/usr

# === PREPARE ===
[ ! -f alpine.iso ] && curl -L -o alpine.iso "$ALPINE_ISO_URL"

rm -f ./qemukey ./qemukey.pub
ssh-keygen -b 2048 -t rsa -N "" -f ./qemukey

rm -f "$IMG_FILE"
qemu-img create -f raw "$IMG_FILE" "$IMG_SIZE"

# === EXPECT SCRIPT: INSTALL ===
expect <<'EOT'
set timeout -1

set qemukey [exec cat ./qemukey.pub]
set answerfile [exec cat ./answerfile]

spawn qemu-system-x86_64 -machine q35 -m 1024 -smp cpus=2 -cpu qemu64 \
  -drive if=pflash,format=raw,read-only=on,file=$env(PREFIX)/share/qemu/edk2-x86_64-code.fd \
  -netdev user,id=n1,hostfwd=tcp::2222-:22 -device virtio-net,netdev=n1 \
  -cdrom alpine.iso \
  -drive file=alpine.img,format=raw \
  -nographic

# LOGIN
expect "login:"
send "root\r"

expect "localhost:~#"
send "setup-interfaces\r"

expect "\[eth0\]"
send "\r"

expect "\[dhcp\]"
send "\r"

expect "\[no\]"
send "\r"

expect "localhost:~#"
send "ifup eth0\r"

# FIX CONSOLE
expect "#"
send "sed -i -E 's/(local kernel_opts)=.*/\\1=\"console=ttyS0\"/' /sbin/setup-disk\r"

# === WRITE ANSWERFILE (FIXED) ===
expect "#"
send "cat > /root/answerfile <<'EOL'\r"
send -- "$answerfile\r"
send "EOL\r"

# VERIFY
expect "#"
send "cat /root/answerfile\r"

# RUN SETUP
expect "#"
send "echo nameserver 8.8.8.8 > /etc/resolv.conf\r"

expect "#"
send "apk update\r"

expect "#"
send "apk upgrade\r"

expect "#"
send "apk add dosfstools e2fsprogs syslinux\r"

expect "#"
send "setup-alpine -f /root/answerfile\r"

expect "password:"
send "$::env(ROOT_PASSWORD)\r"

expect "password:"
send "$::env(ROOT_PASSWORD)\r"

expect "user?"
send "no\r"

expect "Erase the above disk"
sleep 5
send "y\r"

expect "Please reboot"
send "halt\r"

sleep 5
send "\x01"
send "x"

expect eof
EOT

# === EXPECT SCRIPT: REBOOT ===
expect <<'EOT'
set timeout -1

set qemukey [exec cat ./qemukey.pub]

spawn qemu-system-x86_64 -machine q35 -m 1024 -smp cpus=2 -cpu qemu64 \
  -drive if=pflash,format=raw,read-only=on,file=/data/data/com.termux/files/usr/share/qemu/edk2-x86_64-code.fd \
  -drive file=alpine.img,format=raw,if=virtio \
  -netdev user,id=n1,hostfwd=tcp::2222-:22,net=192.168.50.0/24 \
  -device virtio-net,netdev=n1 \
  -nographic

expect "login:"
send "root\r"

expect "Password:"
send "$env(ROOT_PASSWORD)\r"

expect "#"
send "apk update && apk add docker ip6tables\r"

expect "#"
send "service docker start\r"

expect "#"
send "rc-update add docker\r"

expect "#"
send "apk add zram-init\r"

expect "#"
send "sed -i -E 's/num_devices=2/num_devices=1/' /etc/conf.d/zram-init\r"

expect "#"
send "service zram-init start\r"

expect "#"
send "rc-update add zram-init\r"

expect "#"
send "mkdir -p /root/.ssh\r"

expect "#"
send "chmod 700 /root/.ssh\r"

expect "#"
send "echo \"$qemukey\" >> /root/.ssh/authorized_keys\r"

expect "#"
send "chmod 600 /root/.ssh/authorized_keys\r"

expect "#"
send "halt\r"

sleep 5
send "\x01"
send "x"

expect eof
EOT

echo "[+] Alpine Linux installed successfully"