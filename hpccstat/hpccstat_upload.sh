#! /bin/bash

#
# crontab -e
# * */1 * * * sh userhome/hpccstat_upload.sh > /dev/null 2>&1
#

ps -ef | grep hpccstat_upload.sh | grep -v grep | awk '{print $2}' | grep -v "$$" | xargs kill -9 > /dev/null 2>&1
ps -ef | grep "/usr/bin/ftp -v -n 163.53.89.111 21" | grep -v grep | awk '{print $2}' | xargs kill -9 > /dev/null 2>&1

hpccstat_upload_version="version: 20160325 1555.download"

hpccstat_log_path="/data/proclog/log/hpccstat"
hpccstat_log_local="$hpccstat_log_path/upload"
hpccstat_log_dir=`hostname`
hpccstat_log_remote="/home/ngx_dir/hpccstat/download"

ftp_server_ip="163.53.89.111"
ftp_server_port=21

function version()
{
    echo "$hpccstat_upload_version"
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

hpccstat_log_files=`find $hpccstat_log_path -maxdepth 1 -name "*.csv" | wc -l`
if [ "$hpccstat_log_files" = "0" ]; then
    exit
fi

if [ ! -d "$hpccstat_log_local" ]; then
    mkdir -p $hpccstat_log_local
fi

hpccstat_log_file=`ls -l $hpccstat_log_path/*.csv | tail -n1 | awk '{print $NF}'`
rm -rf $hpccstat_log_local/*
cp $hpccstat_log_file $hpccstat_log_local

/usr/bin/ftp -v -n $ftp_server_ip $ftp_server_port << END
user hpccstat hpccstat
passive
cd $hpccstat_log_remote
mk $hpccstat_log_dir
cd $hpccstat_log_dir
lcd $hpccstat_log_local
prompt
mput *
close
bye
END
