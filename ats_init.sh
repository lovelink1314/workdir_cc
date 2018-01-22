#!/bin/bash
export PS4='+ [\D{%F %T}] [$BASH_SOURCE:$LINENO] [FUNC:${FUNCNAME[0]}] - '
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

function my_pause(){
        local k=""
        echo "$* press y to continue, press n to exit"
        while read k;do
                echo "$k" | grep -q '^[yYnN]' && break
                echo "input error, press y to continue, press n to exit"
        done

        echo "$k" | grep -q "^[nN]" && exit 1
}

function my_error(){
        echo -e "ERROR: $*"
        exit 1
}


function green_echo(){
    echo -e  "\033[32m $* \033[0m"
}

export procdir=$(dirname $(readlink -f $0))

rsakey=$procdir/id_rsa
[ -f "$rsakey" ] || my_error "failed to found $rsakey"
export myssh="ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o ConnectTimeout=3 -o LogLevel=error -i $rsakey"
export myscp="scp -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o ConnectTimeout=3 -o LogLevel=error -i $rsakey"

export remote_mutt_dir=/data/cache1/genzhen.yu/mutt
export remote_rms_dir=/data/cache1/huichen.liu/rms
export remote_ims_dir=/data/cache1/huichen.liu/ims
export remote_cms_dir=/data/cache1/genzhen.yu/cms
export remote_cms_dir_bak=/data/cache1/zhourui/cms_bak
export remote_wikitable_dir=/data/cache1/genzhen.yu/wiki_table
export remote_download_dir=/data/cache1/downloadcache

# initial variables

if [ ! -f $procdir/node_name ];then
    while true
    do
            echo "please input node name"
            read name
            echo "input node_name: $name, please check. press y to continue, press enter to reinput"
            read p
            echo "$p" | grep -q "^[Yy]" && break

    done
else
    name=`cat $procdir/node_name`
    while true
    do
            echo "The node_name is $name, please check. press y to continue, press enter to reinput"
            read p
            echo "$p" | grep -q "^[Yy]" && break
                read  -p "please input node name:" name
                echo "input node_name: $name, please check. press y to continue, press enter to reinput"
                read p
                echo "$p" | grep -q "^[Yy]" && break
    done    
fi
echo $name > $procdir/node_name
export node_name="$name"

export flags=$procdir/$node_name/flags
export data=$procdir/$node_name/data
mkdir -p $flags $data


export password=`cat $procdir/info|awk '$1~/sudo_password/{print $2}'`

##################
flag="$flags/hostlist"
if [ ! -f "$flag" ];then
    cat <<EOF

please input file name of hostlist.txt, like this:

format of hostlist.txt (charset:utf-8) :
主机名,管理IP bond0,内网IP bond1,服务类型
CHN-CC-b-3S1,36.104.135.45,10.22.98.10,LVS主
CHN-CC-b-3W2,36.104.135.11,10.22.98.11,LVS备
CHN-CC-b-3W3,36.104.135.12,10.22.98.12,LVS备
CHN-CC-b-3W4,36.104.135.13,10.22.98.13,dispatch
CHN-CC-b-3H1,36.104.135.39,10.22.98.39,刷新备+ats+cache
CHN-CC-b-3H2,36.104.135.40,10.22.98.40,刷新主+ats+cache
CHN-CC-b-3H1,36.104.135.39,10.22.98.39,元信息+ats+cache
CHN-CC-b-3H2,36.104.135.40,10.22.98.40,元信息+ats+cache
CHN-CC-b-3H5,36.104.135.43,10.22.98.43,ats+cache
......

EOF
    while true
    do
        read file
        if [ -f "$file" ];then
            echo -e "input hostlist: $file, content:\n"
            cat $file 2>&1
            echo
            echo "please check. press y to continue, press enter to re-input"
            read p
            echo "$p" | grep -q "^[Yy]" && break
            echo "please re-input hostlist.txt: "
        else
            echo "file not exist, please re-input hostlist.txt: "
        fi
    done

    sed -i 's/[[:space:]]//g' $file
    cp $file $data/hostlist
    touch $flag
fi

flag="$flags/ospf_vip"
if [ ! -f "$flag" ];then
    cat <<EOF

please input file name of ospf_vip.txt, like this:

format of ospf_vip.txt (charset:utf-8) :
CHN-CC-b-3S4 10.11.30.10/30 0.0.0.0 36.104.135.173
CHN-CC-b-3W2 10.11.30.14/30 0.0.0.0 36.104.135.173
CHN-CC-b-3W3 10.11.30.18/30 0.0.0.0 36.104.135.173
......

EOF
    while true
    do
        read file
        if [ -f "$file" ];then
            echo -e "input ospf_vip: $file, content:\n"
            cat $file 2>&1
            echo
            echo "please check. press y to continue, press enter to re-input"
            read p
            echo "$p" | grep -q "^[Yy]" && break
            echo "please re-input ospf_vip.txt: "
        else
            echo "file not exist, please re-input ospf_vip.txt: "
        fi
    done
    sed -i '/^$/d' $file
    cp $file $data/ospf_vip
    touch $flag
fi


flag="$flags/node_type"
if [ ! -f "$flag" ];then
#    while true;do
#        echo "please input node type, may be: cache, apple, download or video"
#        read type
#        echo "input node_type: $type, please check. press y to continue, press enter to reinput"
#        read p
#        echo "$p" | grep -q "^[Yy]" && break
#    done
    echo "cache" >$data/node_type
    touch  $flag
fi

flag="$flags/cluster_name"
if [ ! -f "$flag" ];then
    while true;do
        echo "please input cluster_name(HPCC_CHN_DU_b_1)"
        read cluster_name
        echo "input cluster_name: $cluster_name, please check. press y to continue, press enter to reinput"
        read p
        echo "$p" | grep -q "^[Yy]" && break
    done
    echo "$cluster_name" >$data/cluster_name
    touch $flag
fi

flag="$flags/cluster_id"
if [ ! -f "$flag" ];then
    while true;do
        echo "please input cluster_id(HPCC:2283)"
        read cluster_id
        echo "input cluster_id: $cluster_id, please check. press y to continue, press enter to reinput"
        read p
        echo "$p" | grep -q "^[Yy]" && break
    done
    echo "$cluster_id" >$data/cluster_id
    touch $flag
fi

flag="$flags/meta_vip"
if [ ! -f "$flag" ];then
    while true;do
        echo "please input meta_vip"
        read meta_vip
        echo "input meta_vip: $meta_vip, please check. press y to continue, press enter to reinput"
        read p
        echo "$p" | grep -q "^[Yy]" && break
    done
    echo "$meta_vip" >$data/meta_vip
    touch $flag
fi

flag="$flags/remove_device"
if [ ! -f "$flag" ];then
    while true;do
        echo "please input the removed device,separate by comma!"
        read remove_device
        echo "input remove_device: $remove_device, please check. press y to continue, press enter to reinput"
        read p
        echo "$p" | grep -q "^[Yy]" && break
    done
    echo "$remove_device"|tr "," "\n" >$data/remove_device
    touch $flag
fi

##################



exec 2>> $procdir/$node_name/log.debug
set -x

cat >&2 << EOF 
==================================================================

start new process $(date "+%F %T")

==================================================================
EOF


export node_type=$(cat $data/node_type)
[ -n "$node_type" ] || my_error "failed to get node_type"


flag="$flags/flag_remove_device"
if [ ! -f "$flag" ];then
    echo "start to remove device"
    cmd='yum erase -y monitor_tfsns ecryptfs-utils monitor_tfsds monitor_tfsns_imp monitor_tfsds_imp monitor_taircs_imp monitor_taircs \
        HPC HPC-LUA STA BILLD cms_dispatch monitor_ghpc  CMS_RELOAD TAIR-mem  TAIR-cs  TFS-ns TFS-ds  CMS_RELOAD_META DETECT RFRD-G RFRD \
        PRELOADER RFRD-D  CMS_RELOAD_DV ipvsadm  LVS_IPVS LVS_RS  Monitor_HPCCB Monitor_RFRD DETECT Monitor_KAD KAD HOT COS CCTS  HPC-ZK && reboot'
    muls -l="$data/remove_device" -P=$password -t=300 -c="sudo bash -c '$cmd'" -sudo -v &> $data/log.remove_device
    [ -f "$data/log.remove_device" ] || my_error "failed to exec batRun"
    grep -i 'error' CHN-DJ-b/data/log.remove_device|grep -v hpc_error_log_check && my_error "error found while remove device package,please check $data/log.remove_device!"
    touch "$flag"
fi


flag="$flags/flag_cluser_backup"
if [ ! -f "$flag" ];then
#   echo "开始移除运维机上$node_name集群，请确认运维机上$remote_cms_dir/$node_name/data/hostlist中的设备是你要操作的集群设备，如果不是，请找到你要操作的集群并修改目录路径为$remote_cms_dir/$node_name！"
#   echo "并确认运维机上$remote_cms_dir/$node_name/data/[hostlist,node_type,ospf_vip,cluster_name,cluster_id,meta_vip]文件是你要操作的集群设备信息(如果有故障设备或者被替换设备请手动进行修改)"
#   my_pause
    $myssh root@223.202.75.127 "mv $remote_cms_dir/$node_name  $remote_cms_dir/${node_name}_bak" &>/dev/null 
    sed -i "s/\ ssd//g"  $data/hostlist
    sed -i "s/\+ceph//g"  $data/hostlist
    cat $data/hostlist|awk -F "," '/ats/{print $1}'|sort -u > $data/tsis.cache
    cat $data/hostlist|awk -F "," '/元信息/{print $1}' > $data/tsis.meta
    cat $data/hostlist|awk -F "," '/刷新/{print $1}' > $data/tsis.refresh
    cat $data/hostlist|awk -F "," '/dispatch/{print $1}' > $data/tsis.cms_dispatch
    echo "请确认跳板机设备有上$data/[tsis.cache、tsis.meta、tsis.refresh、tsis.cms_dispatch]文件正确无误"
    my_pause
    touch "$flag"
fi



flag="$flags/flag_install_ats"
if [ ! -f "$flag" ];then
        case "$node_type" in
        "video")
                cmd='wget -q -O - http://223.202.75.127:8001/zhourui/ats/cms_ats_video.sh | bash 2>&1'
                echo "start to install video ats"
        ;;
        "apple")
                cmd='wget -q -O - http://223.202.75.127:8001/zhourui/ats/cms_ats_download.sh | bash 2>&1'
                echo "start to install apple ats"
        ;;
        "download")
                cmd='wget -q -O - http://223.202.75.127:8001/zhourui/ats/cms_ats_download.sh | bash 2>&1' 
                echo "start to install download ats"
        ;;
        "cache")
                cmd='wget -q -O - http://223.202.75.127:8001/zhourui/ats/cms_ats_page.sh | bash 2>&1'
                echo "start to install page ats"            
        ;;
        * )
            cmd='wget -q -O - http://223.202.75.127:8001/zhourui/ats/cms_ats_download.sh | bash 2>&1'
            echo "start to install ats"
                ;;
        esac
    muls -l="$data/tsis.cache" -P=$password -t=1200 -c="sudo bash -c '$cmd'" -sudo -v &> $data/log.install_ats
    [ -f "$data/log.install_ats" ] || my_error "failed to exec muls"
    grep  -iE 'ERROR|FAIL' $data/log.install_ats && my_error "please check ats you can touch [ $flag ] to skip this step"
    touch "$flag"

fi

flag="$flags/flag_install_meta"
if [ ! -f "$flag" ];then
    echo "start to install meta"
    # remove TAIR-mem for cache+meta mixed host
#   awk '(ARGIND==1){cache[$2];}(ARGIND==2 && $2 in cache){print $0;}' $data/tsis.cache $data/tsis.meta | \
        batRun --cmd "rpm -e TAIR-mem" --output $data/log.rm_tair_mem --child 10 &>/dev/null
#   [ -f "$data/log.rm_tair_mem" ] || my_error "failed to exec batRun"

    cmd='echo; wget -q -O - http://hpcc:CChpcc@223.202.201.176/install/centos6/install_metadata.sh | bash 2>&1'
    muls -l="$data/tsis.meta" -P=$password -t=300 -c="sudo bash -c '$cmd'" -sudo -v &> $data/log.install_meta
    [ -f "$data/log.install_meta" ] || my_error "failed to exec batRun"
    grep -P '^[0-9]+%|Install all packages successfully!' $data/log.install_meta | awk -v RS=[0-9]*% '(NR>1){gsub("\n"," ",$0);print $0;}' | \
        grep -v 'Install all packages successfully!' && my_error "error found while installing meta"
    touch "$flag"
fi


flag="$flags/flag_update_rfrd"
if [ ! -f "$flag" ];then
    echo "start to update rfrd"
    cmd='echo; rpm -Uvh http://hpcc:CChpcc@223.202.201.176/tmp/refreshd/RFRD-0.1-33.x86_64.rpm 2>&1'
    muls -l="$data/tsis.refresh" -P=$password -t=300 -c="sudo bash -c '$cmd'" -sudo -v &> $data/log.update_rfrd
    [ -f "$data/log.update_rfrd" ] || my_error "failed to exec batRun"
    grep -iE 'fail|err' $data/log.update_rfrd  && my_error "error found while update rfrd"
    touch "$flag"
fi



flag="$flags/flag_install_ats_disptach"
if [ ! -f "$flag" ];then
        echo "start to install dispatch ats"
        cmd='wget -q -O - http://223.202.75.127:8001/zhourui/ats/cms_ats_dispatch.sh | bash 2>&1'
        muls -l="$data/tsis.cms_dispatch" -P=$password -t=1200 -c="sudo bash -c '$cmd'" -sudo -v &>$data/log.install_ats_dispatch
        [ -f "$data/log.install_ats_dispatch" ] || my_error "failed to exec muls"
        grep  -iE 'ERROR|FAIL' $data/log.install_ats_dispatch && my_error "failed to check ats you can touch [ $flag ] to skip tish step" || echo "install dispatch  ats successful"
        touch "$flag"
fi

#install dispatch
flag="$flags/flag_install_dispatch"
if [ ! -f "$flag" ];then
    cluster_id=$(sed -e 's/:/_/g' $data/cluster_id) ;[ -n "$cluster_id" ] || my_error "failed to get cluster id,check $data/cluster_id"
    out_ip=$(cat $data/hostlist|awk -F "," '/dispatch/{print $2}')
    in_ip=$(cat $data/hostlist|awk -F "," '/dispatch/{print $3}')
    [ -n "$out_ip" -a -n "$in_ip" ] || my_error "failed to get out/in ip for refresh_backup"
    cluster_name=$(cat $data/cluster_name) ;[ -n "$cluster_name" ] || my_error "failed to get cluster id,check $data/cluster_name"
    echo "start to delete old cluster:$cluster_name"
    wget -q -O $procdir/delete_hpcc.sh http://223.202.75.127:8001/zhourui/ats/delete_hpcc.sh && bash delete_hpcc.sh $cluster_name &> $data/log.delete_hpcc
    grep -q success $data/log.delete_hpcc ||  my_error "failed to delete cluster!"
    
    echo "start to install new dispatch"
    cmd="wget -q -O /root/install_cms.sh http://223.202.75.127:8001/zhourui/ats/install_cms.sh && bash /root/install_cms.sh $cluster_id $out_ip $in_ip"
    muls -l="$data/tsis.cms_dispatch" -P=$password -t=1200 -c="sudo bash -c '$cmd'" -sudo -v &> $data/log.install_dispatch
    [ -f "$data/log.install_dispatch" ] || my_error "failed to exec batRun"
    grep OUTPUT: $data/log.install_dispatch | grep -q FAILED && my_error "failed to install dispatch"

    echo "start to restart cms_agent"
    cmd="wget -q -O /root/restart_java.sh http://223.202.75.127:8001/zhourui/ats/restart_java.sh &&  bash /root/restart_java.sh $out_ip"
    muls -l="$data/tsis.cms_dispatch" -P=$password -t=1200 -c="sudo bash -c '$cmd'" -sudo -v &>  $data/log.restart_java
    [ `awk '/^100/{print $4}' $data/log.restart_java` -eq 0 ] || my_error "failed to restart cms_agent"
    touch "$flag"

fi

flag="$flags/flag_update_lvs"
if [ ! -f "$flag" ];then
    cluster_id=$(awk -F ":" '{print $2}' $data/cluster_id) ;[ -n "$cluster_id" ] || my_error "failed to get cluster id,check $data/cluster_id"
    cat $data/hostlist|awk -F "," '/LVS/{print $1}' > $data/tsis.lvs
    echo "start to update lvs"
    cmd="wget -qO /root/upgrade_lvs.sh http://223.202.75.127:8001/zhourui/ats/upgrade_lvs.sh && bash /root/upgrade_lvs.sh $cluster_id"
    muls -l="$data/tsis.lvs" -P=$password -t=1200 -c="sudo bash -c '$cmd'" -sudo -v &> $data/log.update_lvs
    [ -f "$data/log.update_lvs" ] || my_error "failed to exec batRun"
    touch "$flag"
fi


flag="$flags/flag_create_cms_cluster"
if [ ! -f "$flag" ];then        
    echo "start to create cluster on http://cms.chinacache.net:8080"

    $myssh root@223.202.75.127 "mkdir -p $remote_cms_dir/$node_name/data" || my_error "failed to create node_name dir on cms host"
    $myscp $data/hostlist root@223.202.75.127:$remote_cms_dir/$node_name/data/hostlist || my_error "failed to scp hostlist"
    $myscp $data/node_type root@223.202.75.127:$remote_cms_dir/$node_name/data || my_error "failed to scp node_type"
    $myscp $data/ospf_vip root@223.202.75.127:$remote_cms_dir/$node_name/data || my_error "failed to scp ospf_vip"
    $myscp $data/meta_vip root@223.202.75.127:$remote_cms_dir/$node_name/data || my_error "failed to scp meta_vip"

    $myssh root@223.202.75.127 "cd $remote_cms_dir && sh ./create_cluster.sh $node_name" || \
            my_error "failed to create cluster $node_name on cms"

    touch "$flag"
fi

sleep 10
# get cluster id
export cluster_id=""
flag="$flags/flag_get_cluster_id"
if [ ! -f "$flag" ];then
        cluster_id=""
        for((try=0;try<5;try++));do
                echo "start to get cluster_id"
                cmd="wget -qO - http://223.202.75.127:8001/huichen.liu/hpcc/get_cluster_id.sh | bash "
                muls -l="$data/tsis.cms_dispatch" -P=$password -t=1200 -c="sudo bash -c '$cmd'" -sudo -v &> $data/log.get_cluster_id
                [ -f "$data/log.get_cluster_id" ] || my_error "failed to get cluster id"

                cluster_id=$(grep OUTPUT: $data/log.get_cluster_id | cut -d: -f2|grep H)
                [ -n "$cluster_id" ] && break
                echo "failed to get cluster_id, will retry after 60s"
                sleep 60
        done
        [ -n "$cluster_id" ] || my_error "failed to get cluster id"

        echo "$cluster_id" > $data/cluster_id

        touch "$flag"
fi

cluster_id=$(cat $data/cluster_id)
[ -n "$cluster_id" ] || my_error "failed to get cluster id"

flag="$flags/flag_start_java"
if [ ! -f "$flag" ];then
        echo "start to start java on dispatch"
        cluster_id=$(cat $data/cluster_id)
        [ -n "$cluster_id" ] || my_error "failed to get cluster id,check $data/cluster_id"
        cmd="wget -q -O /root/restart_dispatch.sh http://223.202.75.127:8001/zhourui/ats/restart_dispatch.sh && bash /root/restart_dispatch.sh $cluster_id"
        muls -l="$data/tsis.cms_dispatch" -P=$password -t=1200 -c="sudo bash -c '$cmd'" -sudo -v &> $data/log.start_java
        [ -f $data/log.start_java ] || my_error "failed to exec batRun"

        grep -q Success $data/log.start_java || my_error "failed to start java"

        touch $flag
fi


if [ ! -f "$data/area" ];then
        area=$(awk '{print $3;}' $data/ospf_vip | sort -u | head -1)
        [ -n "$area" ] || my_error "failed to get area from $data/ospf_vip"
        echo $area > $data/area
fi

area=$(cat $data/area)
[ -n "$area" ] || my_error "failed to load area"

flag="$flags/flag_modify_cms"
if [ ! -f "$flag" ];then
    node_type=$(cat $data/node_type)
    cluster_id=$(cat $data/cluster_id) ;[ -n "$cluster_id" ] || my_error "failed to get cluster id,check $data/cluster_id"
    cmd="wget -q -O /root/modi_cms_tep.sh http://223.202.75.127:8001/zhourui/ats/modi_cms_tep.sh && bash /root/modi_cms_tep.sh $area $node_type $cluster_id"
    muls -l="$data/tsis.cms_dispatch" -P=$password -t=1200 -c="sudo bash -c '$cmd'" -sudo -v &> $data/log.modify_cms
    [ -f $data/log.modify_cms ] || my_error "failed to exec muls"
    grep -q SUCCESS $data/log.modify_cms || my_error "failed to modify keepalived vrrp."
    touch $flag
fi


flag="$flags/flag_config_cms_cluster"
if [ ! -f "$flag" ];then
        echo "start to config cluster modules on http://cms.chinacache.net:8080/"
        $myssh root@223.202.75.127 "cd $remote_cms_dir && sh ./config_cluster.sh $node_name" || my_error "failed to config cluster $node_name on cms"
        touch "$flag"
fi

echo "请在CMS该集群配置界面，Zookeeper栏将端口1配置手动修改成6889,配置完成后，请下发！"
echo "下发完成之后再点继续。若已下发，请直接继续"
my_pause

flag="$flags/flag_check_ats"
if [ ! -f "$flag" ];then
    echo "start to check ats"
    cluster_id=$(cat $data/cluster_id) ;[ -n "$cluster_id" ] || my_error "failed to get cluster id,check $data/cluster_id"
    cmd='wget -q -O - http://223.202.75.127:8001/zhourui/ats/check_ats.sh | bash 2>&1'
    muls -l="$data/tsis.cache" -P=$password -t=1200 -c="sudo bash -c '$cmd'" -sudo -v &> $data/log.check_ats
    [ -f "$data/log.check_ats" ] || my_error "failed to exec muls"
    grep  -E 'fail|err|ERR|FAIL' $data/log.check_ats && my_error "failed to check ats you can touch [ $flag ] to skip tish step"
    
    cmd="wget -q -O /root/check_cos.sh http://223.202.75.127:8001/zhourui/ats/check_cos.sh && bash /root/check_cos.sh $cluster_id"
    muls -l="$data/tsis.cms_dispatch" -P=$password -t=1200 -c="sudo bash -c '$cmd'" -sudo -v &> $data/log.check_cos
    [ -f "$data/log.check_cos" ] || my_error "failed to exec muls"
    grep -q "COS dump is ok" $data/log.check_cos || my_error "failed to check ats you can touch [ $flag ] to skip tish step"
    touch "$flag"
fi

flag="$flags/flag_install_cms3"
if [ ! -f "$flag" ];then
    echo "start to install cms3"
    cluster_id=$(cat $data/cluster_id) ;[ -n "$cluster_id" ] || my_error "failed to get cluster id,check $data/cluster_id"
    cmd="wget -q -O /root/installCMS3.sh http://223.202.75.127:8001/ganna/cms3/installCMS3.sh && bash /root/installCMS3.sh $cluster_id"
    muls -l="$data/tsis.cms_dispatch" -P=$password -t=1200 -c="sudo bash -c '$cmd'" -sudo -v &> $data/log.install_cms3
    [ -f "$data/log.install_cms3" ] || my_error "failed to exec muls"
    grep  -q 'cms3_installed_successfully' $data/log.install_cms3 || my_error "failed to check ats you can touch [ $flag ] to skip tish step"
    touch "$flag"
fi


flag="$flags/flag_modify_role"
if [ ! -f "$flag" ];then
    echo "start to modify device role!"
    wget -qO - http://223.202.75.127:8001/gaoxing/scripts/change_role.sh | bash
    cd ~/modify
    if [ `grep -E "刷新|元信息"  $data/hostlist|awk -F "," '{print $1}'|sort -u|wc -l` -eq 2 ];then
        for each in `grep -E "刷新|元信息"  $data/hostlist|awk -F "," '{print $1}'|sort -u`
        do
            bash modify_role.sh $each ATSCacheMetaRefresh &>/dev/null
        done
    fi
    atscache=`sed -n '$p' $data/hostlist`
    bash modify_role.sh $atscache ATSCache
    touch "$flag"
fi


lvs_master=`cat $data/hostlist|awk -F "," '/LVS主/{print $1}'`
echo
echo "请更新该集群wiki信息"
echo
echo "请将踢除的设备记录到wiki：http://wiki.dev.chinacache.com/pages/viewpage.action?pageId=46400894"
echo
echo "注意：请在下一个整点时刻过后，对集群进行初始化 $lvs_master"
echo END

