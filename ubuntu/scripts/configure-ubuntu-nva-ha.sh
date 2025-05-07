#!/bin/sh
# Enable IPv4 and IPv6 forwarding / disable ICMP redirect
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1
sudo sysctl -w net.ipv4.conf.all.accept_redirects=0
sudo sysctl -w net.ipv6.conf.all.accept_redirects=0
sudo sed -i "/net.ipv4.ip_forward=1/ s/# *//" /etc/sysctl.conf
sudo sed -i "/net.ipv6.conf.all.forwarding=1/ s/# *//" /etc/sysctl.conf
sudo sed -i "/net.ipv4.conf.all.accept_redirects = 0/ s/# *//" /etc/sysctl.conf
sudo sed -i "/net.ipv6.conf.all.accept_redirects = 0/ s/# *//" /etc/sysctl.conf

 
echo '[Unit]
 Description=/etc/rc.local Compatibility
 ConditionPathExists=/etc/rc.local

[Service]
 Type=forking
 ExecStart=/etc/rc.local start
 TimeoutSec=0
 StandardOutput=tty
 RemainAfterExit=yes
 SysVStartPriority=99

[Install]
 WantedBy=multi-user.target' | sudo tee /etc/systemd/system/rc-local.service

sudo systemctl enable rc-local


# Install Apache for LB Probe
sudo apt-get update
sudo apt-get install apache2 -y
sudo apt-get install php libapache2-mod-php -y
sudo systemctl restart apache2

# Delete default web site and download a new one
#sudo rm /var/www/html/index.html
#sudo apt-get install wget -you
#sudo wget https://raw.githubusercontent.com/jdrepo/ALZ-Deploy/refs/heads/main/ubuntu/scripts/index.php -P /var/www/html/

#############
#  Routing  #
#############
# eth0: Untrusted
# eth1: Trusted

echo "Updating repositories"
sudo apt-get update -y --fix-missing
echo "Installing IPTables-Persistent"
echo iptables-persistent iptables-persistent/autosave_v4 boolean false | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean false | sudo debconf-set-selections
sudo apt-get -y install iptables-persistent

echo "Installing net-tools"
sudo apt-get -y install net-tools

# Get IP addresses
ipaddint=`ip a | grep 10.10.248 | awk '{print $2}' | awk -F '/' '{print $1}'`   # either 10.10.248.12 or .13
ipaddext=`ip a | grep 10.10.249 | awk '{print $2}' | awk -F '/' '{print $1}'`   # either 10.10.249.12 or .13

# Create a custom routing table for internal LB probes
sudo sed -i '$a201 slbint' /etc/iproute2/rt_tables # an easier echo command would be denied by selinux
sudo ip rule add from $ipaddint to 168.63.129.16 lookup slbint  # Note that this depends on the nva number!
sudo ip route add 168.63.129.16 via 10.10.248.1 dev eth1 table slbint

# Create a custom routing table for external LB probes
sudo sed -i '$a202 slbext' /etc/iproute2/rt_tables # an easier echo command would be denied by selinux
sudo ip rule add from $ipaddext to 168.63.129.16 lookup slbext
sudo ip route add 168.63.129.16 via 10.10.249.1 dev eth0 table slbext

# Set up a better routing metric on eth0 (external, 10.10.249.0/24)
# Note that this is not persistent, so you will have to rerun it if you reboot the VM
sudo apt-get install -y ifmetric
#sudo ifmetric eth0 100
# sudo ifmetric eth1 10  # This breaks the ILB!!!!
#sudo ifmetric eth1 200

###########################
#  Firewall config rules  #
###########################
# eth0: Untrusted
# eth1: Trusted

# Allow RELATED and ESTABLISHED traffic
sudo iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Allow ICMP traffic
sudo iptables -A INPUT -p icmp -j ACCEPT

# Allow all traffic on lo
sudo iptables -A INPUT -i lo -j ACCEPT

# Deny all other traffic from internet
sudo iptables -A INPUT -i eth0 -j DROP


#####################


# Deny forwarded ICMP
#sudo iptables -A FORWARD -p icmp -j DROP


# Forwarding rules on eth1(trusted)-new and eth0 (untrusted)-established
sudo iptables -A FORWARD -i eth1 -p icmp -j ACCEPT
sudo iptables -A FORWARD -i eth1 -p tcp --dport ssh -j ACCEPT 
sudo iptables -A FORWARD -i eth1 -p tcp --dport 80 -j ACCEPT 
sudo iptables -A FORWARD -i eth1 -p tcp --dport 443 -j ACCEPT 
sudo iptables -A FORWARD -i eth0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 
sudo iptables -A FORWARD -i eth -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 

# Default forwarding deny
sudo iptables -A FORWARD -j DROP


# SNAT for traffic going to the vnets
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
# SNAT for traffic going to the Internet
sudo iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE

# Log All Dropped Input and Output Packets
#sudo iptables -N LOGGING
#sudo iptables -A INPUT -j LOGGING
#sudo iptables -A OUTPUT -j LOGGING
#sudo iptables -A LOGGING -m limit --limit 2/min -j LOG --log-prefix "IPTables-Dropped: " --log-level 4

# Save to IPTables file for persistence on reboot
sudo iptables-save | sudo tee /etc/iptables/rules.v4

## startup scripts
#printf '%s\n' '#!/bin/bash' 'while true; do nc -lk -p 1138; done &' 'while true; do nc -lk -p 1138; done &' 'exit 0' | sudo tee -a /etc/rc.local
echo '#!/bin/bash 
while true; do nc -lk -p 1138; done & 
while true; do nc -lk -p 1139; done &
#sudo route add -host 168.63.129.16 gw 10.10.248.1 dev eth1
exit 0' | sudo tee -a /etc/rc.local

sudo chmod +x /etc/rc.local

while true; do nc -lk -p 1138; done & 
while true; do nc -lk -p 1139; done &