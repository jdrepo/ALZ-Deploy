#!/bin/sh

# Script Params
# $1 = OPNScriptURI
# $2 = OpnVersion
# $3 = WALinuxVersion
# $4 = Primary/Secondary/TwoNics
# $5 = Trusted Nic subnet prefix - used to get the gw
# $6 = Azure VPN Gateway Public IP 1
# $7 = Azure VPN Gateway Public IP 2


if [ "$4" = "vpngw-bgp" ]; then
    fetch $1config-vpngw-bgp.xml
    fetch $1get_nic_gw.py
    gwip=$(python get_nic_gw.py $5)
    sed -i "" "s/yyy.yyy.yyy.yyy/$gwip/" config-vpngw-bgp.xml
    sed -i "" "s/aaa.aaa.aaa.aaa/$6/" config-vpngw-bgp.xml
    cp config-vpngw-bgp.xml /usr/local/etc/config.xml
fi


