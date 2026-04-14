## Fix internet
login first using staralpine in this repo
login type root & password 
run command:


```
setup-interfaces
```
Available interfaces: eth0 lo
Which one do you want to initialize? (or 'done') [eth0]
```
eth0
```

Ip address for eth0?
```
dhcp
```

Do you want to do any manual network configuration? (y/n) [n]
```
n
```

Test internet
```
ping -c 3 8.8.8.8
ping google.com
```

## FIX DNS: transient error (try again later)   
run command
  ```
  cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
  ```
  
  
additional
```
chattr +i /etc/resolv.conf 2>/dev/null
```
