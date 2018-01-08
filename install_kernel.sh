#!/bin/bash
function kernel_version()
{
    local version=$1
    case $version in
        1)
        #kernel-3.10.0-cc.1.0.4.el6.x86_64.rpm
            package="http://hpcc:CChpcc@223.202.201.176/kernel/cckernel/v1.0.4/kernel-3.10.0-cc.1.0.4.el6.x86_64.rpm"
            config="http://hpcc:CChpcc@223.202.201.176/kernel/cckernel/v1.0.4/sysctl-cckernel-v1.0.4-cfg.conf"
            rpm_name=${package##*/}
            kernel_name=${rpm_name#*-}
            conf_filename=${config##*/}
            ;;
        2)
        #kernel-3.10.0-cc.1.0.5.debug1.el6.x86_64.rpm
            package="http://hpcc:CChpcc@223.202.201.176/kernel/cckernel/v1.0.5/kernel-3.10.0-cc.1.0.5.debug1.el6.x86_64.rpm"
            config="http://hpcc:CChpcc@223.202.201.176/kernel/cckernel/v1.0.5/sysctl-cckernel-v1.0.5-cfg.conf"
            rpm_name=${package##*/}
            kernel_name=${rpm_name#*-}
            conf_filename=${config##*/}
            ;;
        3)
        #kernel-3.10.0-cc.1.0.5.debug3.el6.x86_64.rpm
            package="http://hpcc:CChpcc@223.202.201.176/kernel/cckernel/v1.0.5/kernel-3.10.0-cc.1.0.5.debug3.el6.x86_64.rpm"
            config="http://hpcc:CChpcc@223.202.201.176/kernel/cckernel/v1.0.5/sysctl-cckernel-v1.0.5-debug3-cfg.conf"
            rpm_name=${package##*/}
            kernel_name=${rpm_name#*-}
            conf_filename=${config##*/}
            ;;
        *)
            echo "The kernel version can not find!Please check!"
            exit 1
    esac
}

function modify_boot_kernel_grub_conf()
{
    check_grub_conf
    /bin/rm -f /etc/modprobe.d/igb.conf
    /bin/rm -f /etc/modprobe.d/set_irq_affinity
    KERNEL_NUM=`grep  title /boot/grub/grub.conf |cat -n|grep "$grub_kernel_name"|awk '{print $1}'`
    DEFAULT_NUM=`grep default /boot/grub/grub.conf |awk -F= '{print $2}'`
    CORRECT_KERNEL_NUM=` expr $KERNEL_NUM - 1 `
    if [ $CORRECT_KERNEL_NUM -ne $DEFAULT_NUM ];then
        sed -i "s/default=$DEFAULT_NUM/default=$CORRECT_KERNEL_NUM/" /boot/grub/grub.conf
    fi
}

function install_cckernel()
{
    wget -qO- http://223.202.75.127:8001/hpcc.xunjian/ATS/fstab_dev2uuid.sh|bash
    /bin/rm -f /etc/modprobe.d/igb.conf
    /bin/rm -f /etc/modprobe.d/set_irq_affinity
    rpm -i $package --force
    if [ $? -ne 0 ];then
        echo "Install Kernel $rpm_name fail!"
        exit 1
    fi
    wget -qO /etc/$conf_filename  $config
    sed -i '/sysctl-cckernel/d' /etc/rc.local
    echo "sysctl -p /etc/${conf_filename}">> /etc/rc.local
}

function check_grub_conf()
{
    grub_kernel_name=${kernel_name%.*}
    grep -q "$grub_kernel_name" /boot/grub/grub.conf
    if [ $? -ne 0 ];then
        grep -q "$grub_kernel_name" /etc/grub.conf && /bin/cp -f /etc/grub.conf /boot/grub/grub.conf || echo "grub.conf have not cckernel"
    fi
}

function check_kernel()
{
     uname -r|grep -q $kernel_name
     if [ $? -ne 0 ];then
        rpm -q $rpm_name
        if [ $? -ne 0 ];then
            install_cckernel
            echo "install kernel successful"
            modify_boot_kernel_grub_conf
        fi
        modify_boot_kernel_grub_conf
        echo "install kernel successful"
    fi
}

function main()
{
PROMPT="Kernel Version:\n
\t1:kernel-3.10.0-cc.1.0.4.el6.x86_64.rpm\n
\t2:kernel-3.10.0-cc.1.0.5.debug1.el6.x86_64.rpm\n
\t3:kernel-3.10.0-cc.1.0.5.debug3.el6.x86_64.rpm\n
\t......\n
\tPlease choose kernel version!
"

    if [[ "$1" != [1-9] ]]; then
        echo -e "\\033[35mUsage: sh $0 [1-9]\\033[0m"
        echo -e  $PROMPT
        exit 1
    fi
    kernel_version  $1
    check_kernel
}
main $1
