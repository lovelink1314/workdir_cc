#!/bin/bash
#
#---------------------------------------------------------------|
#  @Program : start_dispatch.sh                                 |
#  @Company : chinacache                                        |
#  @Dep.    : HPCC                                              |
#  @Writer  : na.gan <na.gan@chinacache.com>                    |
#  @Date    : 2016-06-13                                        |
#  @Modify  : 2016-09-26                                        |
#             add log, rm back.tmp                              |
#             2016-10-12                                        |
#             add auto start for single dispatch                |
#             2017-03-01                                        | 
#             add auto start for multi_dispatch                 |
#             2017-04-11                                        | 
#             add auto start for cms3_dispatch                  |
#             2017-08-24                                        | 
#             can restart a designated tm_dispatch              |  
#             2017-09-26                                        | 
#             doesn't restart truck nginx for single            |  
#---------------------------------------------------------------|

restartLog="/data/proclog/monitor/check_dispatch.log"
if [ ! -f $restartLog ];then
    touch $restartLog
fi

#自动拉起truck nginx for cluster, not Single
if [ ! -d /opt/cms/proj/cms_dispatch/Signal_* ];then
    dtruck=`ps -ef | grep -E '/usr/local/nginx-1.6.0/sbin/nginx' | grep -v grep | wc -l`
    if [ $dtruck != '1' ];then
        /usr/local/nginx-1.6.0/sbin/nginx > /dev/null 2>&1
        if [ "$?" -ne 0 ]; then
            echo 1
            exit 0 
        fi
    fi
fi

#自动拉起cms_dispatch进程
#clusterAry=(`ls /opt/cms/proj/cms_dispatch  | grep -E "HPCC_[0-9]+$|DownLoad_[0-9]+$|Signal_[0-9]+$|HATS_[0-9]+$"`)
clusterAry=(`ls /opt/cms/proj/cms_dispatch | grep -E "*_[0-9]+$"`) 
for clusterNum in ${clusterAry[@]}
do
    #单机版的cms_dispatch不用启动,取消自动拉起
    if [[ "$clusterNum" =~ "Signal" ]];then
        continue
    fi

    #启动集群的cms_dispatch
    djava=`ps -ef | grep java | grep "/opt/cms/proj/cms_dispatch/$clusterNum" | wc -l`
    if [ $djava -ne 1 ];then
        datestamp=`date +"%F %T"`
        ps -ef | grep "/opt/cms/proj/cms_dispatch/$clusterNum"  | grep -v grep | awk '{print $2}' | xargs kill -9 > /dev/null 2>&1
        sleep 1
        cd /opt/cms/proj/cms_dispatch/$clusterNum/bin > /dev/null 2>&1
        /bin/sh start.sh $clusterNum > /dev/null 2>&1 
        sleep 3
    
        djava=`ps -ef | grep java | grep "/opt/cms/proj/cms_dispatch/$clusterNum" | wc -l`
        if [ $djava != '1' ];then
            echo "$datestamp failed cms $clusterNum" >> $restartLog
            echo 2
            exit 0
        else 
            echo "$datestamp success cms $clusterNum " >> $restartLog
        fi
    fi
done

#该if判断用于自动kill某个或所有集群的tm_dispatch程序，并自动拉起
if [ ! -z "$1" -a ! -z "$2" ];then
    if [ "$1" == "-d" ];then
        if [ "$2" == "all" ];then
            ps -ef | grep tm_dispatch | grep -v grep | awk '{print $2}' | xargs kill -9 > /dev/null 2>&1
        else
            ps -ef | grep tm_dispatch | grep $2 | grep -v grep | awk '{print $2}' | xargs kill -9 > /dev/null 2>&1 
        fi
    fi
fi

#自动拉起tm_dispatch进程
cms3Ary=(`ls /opt/cms3/proj/tm_dispatch | grep -E "*_[0-9]+$"`)
for cr in ${cms3Ary[@]}
do
    process_log="/opt/cms3/proj/tm_dispatch/$cr/logs/process.log"
    tail -n 1 $process_log|grep -q "last backup Exception"
    if [ $? -eq 0 ];then
        echo 3
        exit 0
    else
        djava=`ps -ef | grep java | grep "/opt/cms3/proj/tm_dispatch/$cr" | wc -l`
        if [ $djava -ne 1 ];then
            datestamp=`date +"%F %T"` 
            ps -ef | grep "/opt/cms3/proj/tm_dispatch/$cr" | grep -v grep | awk '{print $2}' | xargs kill -9 > /dev/null 2>&1
            cd /opt/cms3/proj/tm_dispatch/$cr/bin > /dev/null 2>&1 
            rm -f /opt/cms3/proj/tm_dispatch/$cr/channel_dealing.tmp
            rm -f /opt/cms3/data/$cr/bakdata/tmpdata/backup.tmp
            sh start.sh $cr > /dev/null 2>&1
            sleep 3
            cjava=`ps -ef | grep java | grep "/opt/cms3/proj/tm_dispatch/$cr" | wc -l`
            if [ $cjava -ne 1 ];then
                echo "$datestamp failed cms3 $cr" >> $restartLog
                echo 2
                exit 0
            else 
                echo "$datestamp success cms3 $cr " >> $restartLog
            fi
        fi
    fi
done

echo 0
exit 0
