#! /bin/sh

hpccstat_watch_version="version: 20160102 0101"
hpccstat_dir=`dirname $0`
hpccstat="$hpccstat_dir/hpccstat.sh"
period_second=60

function version()
{
    echo "$hpccstat_watch_version"
    exit
}

while getopts "v" opt
do
    case $opt in
        v)
            version
        ;;
    esac
done

hpccstat_status=`ps -ef | grep "$hpccstat" | grep -v grep | wc -l`
if [ "$hpccstat_status" -gt "0" ]; then
    exit
fi

tomorrow=`date +%Y-%m-%d" 00:00:00" -d "1 day"`
now=`date +%Y-%m-%d" "%H:%M:%S`
time_interval=$(($(date -d "$tomorrow" +%s) - $(date -d "$now" +%s)))
duration_minute=$((time_interval/60))

sh $hpccstat -p $period_second -d $duration_minute &  > /dev/null 2>&1
