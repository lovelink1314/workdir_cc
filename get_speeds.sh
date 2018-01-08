#!/bin/bash
get_speed()
{
dev=$1
Status=`/sbin/ethtool $dev|awk '/detected/{print$3}'`
Speed=`/sbin/ethtool $dev |awk -F"[ M]" '/Speed/{print $2}'`
if [[ "x$Status" != "xyes" ]];then
    speed_list="$speed_list $dev,down"
elif [[ "x$Speed" != "x$standard" ]] ;then
    speed_list="$speed_list $dev,$Speed"
fi
}

function fun_nic_name()
{
    local nic=$1
    grep -i bridge /etc/sysconfig/network-scripts/ifcfg-$nic|grep -vE "br0|br1" &>/dev/null
    if [ $? -eq 0 ];then
        nic_name=`grep -i "bridge=" /etc/sysconfig/network-scripts/ifcfg-eth* /etc/sysconfig/network-scripts/ifcfg-bond*|grep $nic|awk -F ":" '{print $1}'|awk -F- '{print $NF}'`
        echo ${nic_name}
    else
        echo $nic
    fi
}

cat /etc/issue|grep -q "5.8"
if [[ $? != 0 ]];then
    bond0=`fun_nic_name bond0`
    bond1=`fun_nic_name bond1`
    NIC_MODE=`/sbin/ethtool $bond0 |grep "Port"|awk '{print $NF}'`
    NIC_SPEED=`/sbin/ethtool $bond0|grep Speed|egrep -o "[0-9]+"`
    BOND0_SPEED=`/sbin/ethtool $bond0 |awk -F"[ M]" '/Speed/{print $2}'`
    BOND1_SPEED=`/sbin/ethtool $bond1 2>/dev/null |awk -F"[ M]" '/Speed/{print $2}'`
    BOND0_SPEEDS=${BOND0_SPEED:-0}
    BOND1_SPEEDS=${BOND1_SPEED:-0}
    SPEED=`expr $BOND0_SPEEDS + $BOND1_SPEEDS`
    if [[  $NIC_MODE == "FIBRE" ]] || [[ $NIC_SPEED -eq 10000  ]];then
        case $SPEED in
        20000)
            echo PERFECT
            exit
            ;;
        *)
            dev_list="$bond0 $bond1"
            standard="10000"
            for i in ${dev_list}
            do
                get_speed $i
            done
            if [[ $speed_list =~ "bond" ]];then
                echo $speed_list
            else
                echo PERFECT
            fi
        esac
    else
        case $SPEED in
        4000)
            echo PERFECT
            exit
            ;;
        *)
            dev_list="eth0 eth1 eth2 eth3"
            standard="1000"
            for i in ${dev_list}
            do
                get_speed $i
            done
            if [[ $speed_list =~ "eth" ]];then
                echo $speed_list
            else
                echo PERFECT
            fi
        esac
    fi
else
    dev_list=`/sbin/ifconfig |grep Link|egrep "eth[0-9]"|awk '{print $1}'`
    dev_num=`/sbin/ifconfig |grep Link|egrep "eth[0-9]"|wc -l`
    if [[ $dev_num -eq 4 ]];then
        standard="1000"
        for i in ${dev_list}
        do
            get_speed $i
        done
        if [[ $speed_list =~ "eth" ]];then
            echo $speed_list
        else
            echo PERFECT
        fi
    else
        standard="10000"
        for i in ${dev_list}
        do
            get_speed $i
        done
        if [[ $speed_list =~ "eth" ]];then
            echo $speed_list
        else
            echo PERFECT
        fi
    fi
fi
