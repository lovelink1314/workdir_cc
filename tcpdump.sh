#!/bin/bash
sed -i '/tcpdump/d' /var/spool/cron/root
#echo "0 21 * * * nohup bash /usr/local/aotutcpdump.sh &"  >> /var/spool/cron/root
#wget -SO /usr/local/aotutcpdump.sh  http://223.202.75.127:8001/hpcc.xunjian/script/aotutcpdump.sh &>/dev/null
#md5sum /usr/local/aotutcpdump.sh
#chmod +x /usr/local/aotutcpdump.sh
