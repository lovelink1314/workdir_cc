#!/bin/bash
#为防止ATS进程被内核oom机制杀掉，导致回源突增，设备宕机，现设备ATS进程的oom_adj值为-17
echo "*/1 * * * * root  pgrep -f /usr/local/CCTS/bin/traffic_server | while read PID;do echo -17 > /proc/\$PID/oom_adj;done" >/etc/cron.d/oom_disable
