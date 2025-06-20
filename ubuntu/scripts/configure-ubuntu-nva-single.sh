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



# Install Apache for LB Probe
sudo apt-get update
sudo apt-get install apache2 -y
sudo systemctl restart apache2

# Delete default web site and download a new one
#sudo rm /var/www/html/index.html
#sudo apt-get install wget -you
#sudo wget https://raw.githubusercontent.com/erjosito/azure-networking-lab/master/arm/index.php -P /var/www/html/

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
# sudo iptables -A FORWARD -i eth1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 

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