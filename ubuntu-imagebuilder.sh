#!/bin/bash
sudo apt update && sudo apt upgrade -y && sudo apt install -y cloud-init
sudo apt install -y qemu-guest-agent
sudo systemctl status qemu-guest-agent.service
sudo systemctl start qemu-guest-agent.service 



sudo sh -c 'cat > /etc/ssh/banner <<\EOF
         _      _                 _   _       
  ___ __| | ___| | ___  _   _  __| | (_) ___  
 / __/ _` |/ __| |/ _ \| | | |/ _` | | |/ _ \ 
| (_| (_| | (__| | (_) | |_| | (_| |_| | (_) |
 \___\__,_|\___|_|\___/ \__,_|\__,_(_)_|\___/ 
                                              

cdcloud.io
Ubuntu 22.04

*********************************************************************
UNAUTHORIZED ACCESS TO THIS DEVICE IS PROHIBITED

You must have explicit, authorized permission to access or configure 
this device. Unauthorized attempts and actions to access or use this
system may result in civil and/or criminal penalties. All activities
performed on this device are logged and monitored.
*********************************************************************

EOF'

sudo sed -i -e 's/GSSAPIAuthentication yes.*/GSSAPIAuthentication no/g' /etc/ssh/sshd_config
sudo sed -i -e 's/#UseDNS.*/UseDNS no/g' /etc/ssh/sshd_config
echo "Banner /etc/ssh/banner" | sudo tee -a /etc/ssh/sshd_config
sudo systemctl restart sshd
sudo systemctl stop sshd
# sudo apt clean
sudo apt clean
sudo apt autoremove

# STEP 00: Stop logging services OK
sudo /sbin/service rsyslog stop
sudo /sbin/service auditd stop


# STEP 03: Force logrotate to shrink logspace and remove old logs as well as truncate logs OK
sudo /usr/sbin/logrotate -f /etc/logrotate.conf 
sudo rm -rf /var/log/*.gz /var/log/*.[0-9] /var/log/*-???????? /var/log/dmesg.*

sudo truncate -s 0 /var/log/wtmp
sudo truncate -s 0 /var/log/lastlog


# Remove machine-id OK
cat /etc/machine-id
sudo truncate -s 0 /etc/machine-id
sudo truncate -s 0 /var/lib/dbus/machine-id

ls /var/lib/dbus/machine-id
cat /etc/machine-id

if exist /var/lib/dbus/machine-id
	cat /var/lib/dbus/machine-id
	sudo rm /var/lib/dbus/machine-id
	sudo ln -s /etc/machine-id /var/lib/dbus/machine-id

# Clean tmp directories
sudo /bin/rm -rf /tmp/*
sudo /bin/rm -rf /var/tmp/*

# Remove SSH host keys
sudo /bin/rm -f /etc/ssh/ssh_host_*

unset HISTFILE


