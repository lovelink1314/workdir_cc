#!/bin/bash
INFO_FILE="/tmp/gigabit.txt"
MULI_FILE="/tmp/multi_queue.txt"
BOOT_FILE="/etc/init.d/set_irq_affinity"
function is_cluster_or_single()
{
    /sbin/ifconfig bond1 &>/dev/null
    if [ $? -eq 0 ];then
        IP=`awk -F= '$1~/IPADDR/{print $2}' /etc/sysconfig/network-scripts/ifcfg-bond1`
        local_area_network_match $IP && echo "cluster" || echo "single"
    else
        echo "single"
    fi
}

function local_area_network_match()
{
ip=$1
if [[ $ip =~ ^10\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$ ]]
then
        return 0
else
        return 1
fi
}


function is_gigabit_or_tengigabit()
{
    interface_name=$1
    speed=`ethtool $interface_name|awk '/Speed/{print $2}'|grep -o "[0-9]*"`
    if [ $speed = "1000" ];then
        echo "$interface_name gigabit" >> $INFO_FILE
    elif [ $speed = "10000" ];then
        echo "$interface_name ten_gigabit" >> $INFO_FILE
    else
        for i in `cat /proc/net/bonding/$interface_name |awk '/Interface/{print $3}'`
        do
            speed=`ethtool $i|awk '/Speed/{print $2}'|grep -o "[0-9]*"`
            if [ $speed = "1000" ];then
                echo "$i gigabit" >> $INFO_FILE
            elif [ $speed = "10000" ];then
                echo "$i ten_gigabit" >> $INFO_FILE
            else
                echo "$i none" >> $INFO_FILE
            fi
        done
    fi
}

function suppost_multi_queue_or_not()
{
    interface_name=$1
    bus_info=`/sbin/ethtool -i $interface_name|awk -F "0000:" '/bus-info/{print $NF}'`
    if [ `/sbin/lspci|grep -i $bus_info|egrep "I350|82576|10-Gigabit|82580"|wc -l` -eq 1 ];then
        echo "$interface_name suppost" >> $MULI_FILE
    else
        echo "$interface_name unsuppost" >> $MULI_FILE
    fi
}


function type()
{
    if [ $1 = "cluster" ];then
        is_gigabit_or_tengigabit bond0
        is_gigabit_or_tengigabit bond1
    else
        is_gigabit_or_tengigabit bond0
    fi
    for each_interface in `awk '{print $1}' $INFO_FILE`
    do
        suppost_multi_queue_or_not $each_interface
    done
    grep -q unsuppost $MULI_FILE
    if [ $? -eq 0 ];then
        /etc/init.d/irqbalance start &>/dev/null
    else
        for each in `awk '{print $1}' $INFO_FILE`
        do
            echo "bash /usr/local/set_irq_affinity.sh $each" >> $BOOT_FILE
        done
    fi
}


function main()
{
#prepare
    >$INFO_FILE
    >$MULI_FILE
    wget -qO /usr/local/set_irq_affinity.sh  http://223.202.75.127:8001/hpcc.xunjian/script/set_irq_affinity.sh
    echo "#!/bin/bash" > $BOOT_FILE
    echo "# chkconfig:2345 58 71" >> $BOOT_FILE
    echo "# description: set set_irq_affinity 512">> $BOOT_FILE
    chmod +x $BOOT_FILE
    chkconfig --level 3 set_irq_affinity on
##  
    TYPE=`is_cluster_or_single`
    type $TYPE
}

main
