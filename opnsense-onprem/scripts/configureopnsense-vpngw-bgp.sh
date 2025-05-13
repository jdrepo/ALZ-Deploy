#!/bin/sh

# Script Params
# $1 = OPNScriptURI
# $2 = OpnVersion
# $3 = WALinuxVersion
# $4 = Primary/Secondary/TwoNics
# $5 = Trusted Nic subnet prefix - used to get the gw
# $6 = Azure VPN Gateway Public IP 1
# $7 = Azure VPN Gateway Public IP 2
# $8 = opnSense Public IP 1
# $9 = local ASN
# $10 = remote ASN
# $11 = Azure VPN Gateway BGP Peer IP Address 1
# $12 = Azure VPN Gateway BGP Peer IP Address 2




if [ "$4" = "vpngw-bgp" ]; then
    fetch $1config-vpngw-bgp.xml
    fetch $1get_nic_gw.py
    gwip=$(python get_nic_gw.py $5)
    sed -i "" "s/yyy.yyy.yyy.yyy/$gwip/" config-vpngw-bgp.xml
    sed -i "" "s/aaa.aaa.aaa.aaa/$6/" config-vpngw-bgp.xml
    sed -i "" "s/bbb.bbb.bbb.bbb/$7/" config-vpngw-bgp.xml
    sed -i "" "s/ccc.ccc.ccc.ccc/$8/" config-vpngw-bgp.xml
    sed -i "" "s/XXXXX/$9/" config-vpngw-bgp.xml
    sed -i "" "s/YYYYY/${10}/" config-vpngw-bgp.xml
    sed -i "" "s/ddd.ddd.ddd.ddd/${11}/" config-vpngw-bgp.xml
    sed -i "" "s/eee.eee.eee.eee/${12}/" config-vpngw-bgp.xml

    cp config-vpngw-bgp.xml /usr/local/etc/config.xml
fi

#Download OPNSense Bootstrap and Permit Root Remote Login
fetch https://raw.githubusercontent.com/opnsense/update/master/src/bootstrap/opnsense-bootstrap.sh.in
sed -i "" 's/#PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config

#OPNSense
# Due to a recent change in pkg the following commands no longer finish with status code 0
#		pkg unlock -a
#		pkg delete -fa
# This resplace of set -e which force the script to finish in case of non status code 0 has to be inplace
sed -i "" "s/set -e/#set -e/g" opnsense-bootstrap.sh.in
sed -i "" "s/reboot/shutdown -r +2/g" opnsense-bootstrap.sh.in
sh ./opnsense-bootstrap.sh.in -y -r "$2"

# Installing bash - This is a requirement for Azure custom Script extension to run
pkg install -y azure-agent
pkg install -y bash
pkg install -y os-frr
pkg install -y os-ddclient


# Remove wrong route at initialization
cat > /usr/local/etc/rc.syshook.d/start/22-remoteroute <<EOL
#!/bin/sh
route delete 168.63.129.16
EOL
chmod +x /usr/local/etc/rc.syshook.d/start/22-remoteroute

#Adds support to LB probe from IP 168.63.129.16
# Add Azure VIP on Arp table
echo # Add Azure Internal VIP >> /etc/rc.conf
echo static_arp_pairs=\"azvip\" >>  /etc/rc.conf
echo static_arp_azvip=\"168.63.129.16 12:34:56:78:9a:bc\" >> /etc/rc.conf
# Makes arp effective
service static_arp start
# To survive boots adding to OPNsense Autorun/Bootup:
echo service static_arp start >> /usr/local/etc/rc.syshook.d/start/20-freebsd

# Reset WebGUI certificate
echo #\!/bin/sh >> /usr/local/etc/rc.syshook.d/start/94-restartwebgui
echo configctl webgui restart renew >> /usr/local/etc/rc.syshook.d/start/94-restartwebgui
echo rm /usr/local/etc/rc.syshook.d/start/94-restartwebgui >> /usr/local/etc/rc.syshook.d/start/94-restartwebgui
chmod +x /usr/local/etc/rc.syshook.d/start/94-restartwebgui