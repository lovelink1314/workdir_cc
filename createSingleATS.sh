#!/bin/bash
createdir="/root/createSingleATS"
datadir=$createdir"/data"
logdir=$createdir"/log"
flagdir=$createdir"/flag"
BASE_DATA=$datadir"/precheck"
CHECK_RES="$datadir/precheck_Res"

function greenEcho()
{
  item=$1
  echo -e "\\033[32m$item\\033[0m"
}

function redEcho()
{
  item=$1
  echo -e "\\033[31m$item\\033[0m"
}

function my_pause(){
  local k=""
  echo -e "\\033[33m$*\\033[0m\n\\033[34mpress y to continue, press n to exit.\\033[0m"
  while read k;do
          echo "$k" | grep -q '^[yYnN]' && break
          echo "input error, press y to continue, press n to exit"
  done
  
  echo "$k" | grep -q "^[nN]" && exit 1
}

function checkAfterInstall()
{
  logfile=$1
  role=$2
  cmd=$3
  flag=$4

  grep -o "Install all packages successfully" $logfile > /dev/null 2>&1

  sucRES=`echo $?`
  grep -o "Error: failed" $logfile > /dev/null 2>&1
  failRES=`echo $?`
  if [ $sucRES -eq 0 -a $failRES -eq 1 ]; then
    greenEcho "done"
  else
    redEcho "install $role failed!" 
    echo -e "\n错误详情见日志：$logfile\n可手动安装跳过此步骤，执行以下命令：\n1.$cmd\n2.touch $flag"
    exit 0
  fi
}

function writeCheckRes()
{
  res=$1
  echo -e "$1" >> $CHECK_RES
}

function setDNS()
{
  chattr -ai /etc/resolv.conf
  if [ $1 -eq 0 ]; then
    echo "nameserver 127.0.0.1" > /etc/resolv.conf
  elif [ $1 -eq 1 ]; then
    echo "nameserver 114.114.114.114" > /etc/resolv.conf
  fi
  chattr +ai /etc/resolv.conf
}

function setHosts()
{
    FLAG="$flagdir/setHosts"
    if [ ! -f $FLAG ]; then
        sed -i '/puppetmaster.chinacache.com/d' /etc/hosts
        sed -i '/puppetfile.chinacache.com/d' /etc/hosts
        sed -i '/puppetca.chinacache.com/d' /etc/hosts
        sed -i '/cms.chinacache.net/d' /etc/hosts
        sed -i '/mq.cms.chinacache.net/d' /etc/hosts
        sed -i '/cms3-mq.chinacache.com/d' /etc/hosts
        sed -i '/www.springframework.org/d' /etc/hosts
        cat >> /etc/hosts << EOF
180.97.185.134 puppetmaster.chinacache.com
180.97.185.133 puppetfile.chinacache.com
180.97.185.132 puppetca.chinacache.com
223.202.75.69 cms.chinacache.net
223.202.202.122 cms3-mq.chinacache.com
104.16.119.250 www.springframework.org
EOF
        wget -qO- http://223.202.75.127:8001/zhengbin/close_gso_tso_gro.sh|bash &>/dev/null
    touch $FLAG
    fi
}


#***********************************前期检查函数*****************************************

function preCheck()
{
  FLAG="$flagdir/precheck"

  if [ ! -f $FLAG ]; then
   
    greenEcho "开始检查设备.........."
    /bin/rm -f $CHECK_RES 
    #一、获取基本数据
    #1.系统版本：Centos5.8
    sys_version="version:"`cat /etc/redhat-release`
    echo $sys_version > $BASE_DATA 

	#2.仅挂载cache1 cache2 proclog和根盘
	disk_deal
	if [ $? -ne 0 ];then
		writeCheckRes "磁盘挂载异常，请检查！"
	fi
	
    #4.
    #只需用外网
    ifconfig bond0|grep "inet addr" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        bond0_ip="bond0_ip:"`ifconfig  bond0 | grep "inet addr" | awk '{print $2}' | awk -F':' '{print $2}'`
        echo "hpc_lua:bond0" >> $BASE_DATA
    else
        ifconfig eth0|grep "inet addr" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            bond0_ip="bond0_ip:"`ifconfig eth0 | grep "inet addr" | awk '{print $2}' | awk -F':' '{print $2}'`
            echo "hpc_lua:eth0" >> $BASE_DATA
        else
			read -p "Please input the interface name:  " interface_name
			ifconfig $interface_name|grep "inet addr" > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				bond0_ip="bond0_ip:"`ifconfig  $interface_name | grep "inet addr" | awk '{print $2}' | awk -F':' '{print $2}'`
				echo "hpc_lua:$interface_name" >> $BASE_DATA
			else
				echo "interface name error!"
				exit 1
			fi
        fi
    fi
    echo $bond0_ip >> $BASE_DATA

    #5.测试能否下载文件，需要从发布机下载安装包
	wget -qO /root/stest http://hpcc:CChpcc@223.202.201.176/single/stest

    if [ $? -eq 0 ]; then
      echo "isConnectRelease:ok" >> $BASE_DATA
    else
      echo "isConnectRelease:error" >> $BASE_DATA
    fi

    
    #****************************************************************************************

    #二、对数据判断: 有内外网、磁盘个数、能否ping通发布机、磁盘挂载情况
    sysVersion=`grep version $BASE_DATA | awk -F ':' '{print $2}'`
    bond0=`grep bond0 $BASE_DATA | awk -F ':' '{print $2}'`
    #bond1=`grep bond1 $BASE_DATA | awk -F ':' '{print $2}'`
    #disk_cnt=`grep disk_num $BASE_DATA | awk -F ':' '{print $2}'` 
    isConnect=`grep isConnectRelease $BASE_DATA | awk -F ':' '{print $2}'`
    isSYS=`grep isSYSmounted $BASE_DATA | awk -F ':' '{print $2}'`
    #sysDiskSize=`grep root_size $BASE_DATA | awk -F ':' '{print $2}'`
    #procDiskSize=`grep proclog_size $BASE_DATA | awk -F ':' '{print $2}'`


    #当再次检查时，需要移除上一次的检查结果
    if [ "$sysVersion" != "CentOS release 5.8 (Final)" -a "$sysVersion" != "CentOS release 6.5 (Final)" ]; then
      writeCheckRes "系统版本: 检测到$sysVersion, 应该为CentOS 5.8或者CentOS 6.5"
    fi
    
    if [ -z "$bond0" ]; then
      writeCheckRes "网络设置：请检查外网ip"
    fi
    if [ "$isConnect" == "error" ]; then
      writeCheckRes "网络连接：无法从223.202.201.176下载文件"
      writeCheckRes "          测试链接：wget -O /root/stest http://hpcc:CChpcc@223.202.201.176/single/stest"
    fi

    
    if [ -f $CHECK_RES ]; then
      redEcho "\n发现错误："
      cat $CHECK_RES
      greenEcho "\n可执行 touch $FLAG 跳过设备检查"
      exit 0
    else
      touch $FLAG
      greenEcho "检查完毕，设备符合条件。接下来将安装服务组件......\n"
    fi
  fi
}


#***********************************安装函数*****************************************

#升级igb驱动
function igbUpt()
{
  mylog="$logdir/igbUpt"
  FLAG="$flagdir/igbUpt"

  if [ ! -f $FLAG ]; then
    #my_pause "Begin to upgrade igb driver? "

    igbversion=`ethtool -i eth0 | grep -E 'driver|version: 5.2.9.4'`
    if [ "$igbversion" != "driver: igb version: 5.2.9.4" ]; then
        greenEcho "begin to update igb driver."
        wget -O /tmp/igb-5.2.9.4.tar.gz http://58.68.224.134/igb-5.2.9.4.tar.gz > $mylog 2>&1
        tar zvxf /tmp/igb-5.2.9.4.tar.gz -C /tmp >> $mylog
        cd /tmp/igb-5.2.9.4/src
        echo -e "\n\n************ make install ************\n" >> $mylog 2>&1
        make install >> $mylog 2>&1
        rm -rf /tmp/igb-5.2.9.4.tar.gz /tmp/igb-5.2.9.4
        greenEcho "done.\n\n"
    else
      greenEcho "Nothing need to update igb driver."
    fi  

    touch $FLAG
  fi
}



#安装基础环境
function installBaseEnv()
{
  mylog="$logdir/installBaseEnv"
  mydata="$datadir/installBaseEnv"
  FLAG_install="$flagdir/installBaseEnv"
  FLAG_check="$flagdir/checkBaseEnv"
  wget -qO /root/checkHPCCBasicServicesForSingleATS.sh http://hpcc:CChpcc@223.202.201.176/single/base/checkHPCCBasicServicesForSingleATS.sh > /dev/null 2>&1
  /bin/bash /root/checkHPCCBasicServicesForSingleATS.sh > $mydata 2>&1
  checkRes=`grep Failure $mydata`
  if [ -n "$checkRes" ]; then
          if [ ! -f $FLAG_install ]; then
                #my_pause "Begin to install base environment?"

                greenEcho "begin to install HPCC Basic Services."
                touch $FLAG_install
                wget -O /root/installHPCCBasicServices_single_webATS.sh http://hpcc:CChpcc@223.202.201.176/HPCCBasicServices/installHPCCBasicServices_single_webATS.sh> $mylog 2>&1
                /bin/bash /root/installHPCCBasicServices_single_webATS.sh >> $mylog 2>&1
                grep -q "install kernel successful" $mylog && reboot
          fi

          #如果检测到Failure,需要退出脚本
          if [ ! -f $FLAG_check ]; then
                wget -qO /root/checkHPCCBasicServicesForSingleATS.sh http://hpcc:CChpcc@223.202.201.176/single/base/checkHPCCBasicServicesForSingleATS.sh >> $mylog 2>&1
                /bin/bash /root/checkHPCCBasicServicesForSingleATS.sh > $mydata 2>&1
                checkRes=`grep Failure $mydata`
                if [ -n "$checkRes" ]; then
                  rm -f $FLAG_install
                  cat $mydata
                  CMDForInstall="/bin/bash /root/installHPCCBasicServices_single_webATS.sh"
                  CMDForCheck="/bin/bash /root/checkHPCCBasicServicesForSingleATS.sh"
                  echo -e "\n错误详情见日志：$mylog\n可手动安装跳过此步骤：\n1.安装：$CMDForInstall\n2.检查：$CMDForCheck\n3.跳过脚装: touch $FLAG_install $FLAG_check"
                  exit 0
                else
                  touch $FLAG_check
                fi
        fi
  fi
}

#安装cache组件
function installCache()
{
  mylog="$logdir/installCache"
  mydata="$datadir/installCache"
  FLAG="$flagdir/installCache"	

  if [ ! -f $FLAG ]; then
    #my_pause "Begin to install Cache?"
    greenEcho "begin to install cache."
	type=`cat $BussiTypeFile`
	if [ $type = "page" ];then
		wget -O /root/install_generalcache.sh http://hpcc:CChpcc@223.202.201.176/general_test/general/install_generalcache_ats_web.sh > $mylog 2>&1
	elif [ $type = "video" ];then
		wget -O /root/install_generalcache.sh http://hpcc:CChpcc@223.202.201.176/general_test/general/install_generalcache_ats_video.sh > $mylog 2>&1 
		sed -i '/install_OP/s/^/#/' /root/install_generalcache.sh
		sed -i '/install_TAIR_mem/s/^/#/' /root/install_generalcache.sh
	else
		wget -O /root/install_generalcache.sh http://hpcc:CChpcc@223.202.201.176/general_test/general/install_generalcache_ats_download.sh > $mylog 2>&1 
		sed -i '/install_OP/s/^/#/' /root/install_generalcache.sh
		sed -i '/install_TAIR_mem/s/^/#/' /root/install_generalcache.sh
	fi
	echo -e "\n********** /bin/bash /root/install_generalcache.sh **********\n\n" >> $mylog 2>&1
	/bin/bash /root/install_generalcache.sh >> $mylog 2>&1
	CMD="/bin/bash /root/install_generalcache.sh"
	checkAfterInstall $mylog cache "$CMD" $FLAG
    touch $FLAG
  fi
}

#安装元信息组件
function installMeta()
{
  mylog="$logdir/installMeta"
  mydata="$datadir/installMeta"
  FLAG="$flagdir/installMeta"

  if [ ! -f $FLAG ]; then
    #my_pause "Begin to install Meta?"
    greenEcho "begin to install meta."

    rpm -e TAIR-mem > /dev/null 2>&1
    wget -O /root/install_metadata.sh http://hpcc:CChpcc@223.202.201.176/general_test/general/install_metadata_ats_single.sh > $mylog 2>&1
    echo "\n********** /bin/bash /root/install_metadata.sh **********\n\n" >> $mylog 2>&1
    /bin/bash /root/install_metadata.sh >> $mylog 2>&1
    CMD="/bin/bash /root/install_metadata.sh"
    checkAfterInstall $mylog meta "$CMD" $FLAG
    touch $FLAG
  fi
}

#安装刷新组件
function installRfrd()
{
  mylog="$logdir/installRfrd"
  mydata="$datadir/installRfrd"
  FLAG="$flagdir/installRfrd"

  if [ ! -f $FLAG ]; then
    #my_pause "Begin to install Rfrd?"

    greenEcho "begin to install refresh."
    wget -O /root/install_rfrd.sh http://hpcc:CChpcc@223.202.201.176/general_test/general/install_rfrd_single.sh > $mylog 2>&1
    echo "\n********** /bin/bash /root/install_rfrd.sh **********\n\n" >> $mylog 2>&1
    /bin/bash /root/install_rfrd.sh >> $mylog 2>&1
    CMD="/bin/bash /root/install_rfrd.sh"
    checkAfterInstall $mylog refresh "$CMD" $FLAG
    touch $FLAG
  fi
}

#修改ZK配置文件参数
configZK(){
	mylog="$logdir/configZK"
	FLAG="$flagdir/configZK"
	if [ ! -f $FLAG ]; then
		echo -e "\e[1;34m[ZK]>>>>>Start to config ZK.......\e[0m"  > $mylog 2>&1
			. /etc/profile > /dev/null 2>&1
		cfg=$ZK_HOME/conf/zoo.cfg
		mkdir -p $ZK_HOME/data
		cat <<END > $cfg
tickTime=2000
initLimit=10
syncLimit=5
dataDir=$ZK_HOME/data
dataLogDir=$ZK_HOME/log
clientPort=2181
maxClientCnxns=0
END
		echo -e "\e[1;34m[ZK]>>>>>Start ZK process.......\e[0m"  >> $mylog 2>&1
		cos.sh zk start > /dev/null
		wget -qO /etc/cron.d/zk http://223.202.75.127:8001/bowen/crond/zk  >> $mylog 2>&1
		wget -qO /etc/cron.d/ccts http://223.202.75.127:8001/bowen/crond/ccts  >> $mylog 2>&1
		service crond reload  >> $mylog 2>&1
		touch $FLAG
	fi
}

#修改COS配置文件参数
config_cos(){
	mylog="$logdir/config_cos"
	FLAG="$flagdir/config_cos"
	if [ ! -f $FLAG ]; then
		echo -e "\e[1;34m[CONFIG_COS]>>>>>Start to config cos.......\e[0m"   > $mylog 2>&1
        /bin/cp -f /home/cos/cos/conf/env /home/cos/cos/conf/env_1
		echo "127.0.0.1" > /home/cos/cos/hosts.conf
		cos.sh init 1  >> $mylog 2>&1
	touch $FLAG
	fi

}



#修改HPC配置文件参数
function modHPC() 
{
  mylog="$logdir/modHPC"
  mydata="$datadir/modHPC"
  FLAG="$flagdir/modHPC"

  if [ ! -f $FLAG ]; then
    #my_pause "Begin to modify HPC configure?"

    greenEcho "begin to modify hpc configure file."
    wget -qO /usr/local/hpc/conf/lua/init_phase/ghr/get_vip.lua http://223.202.75.127:8001/ganna/single/hpc/get_vip.lua
    netType=`grep hpc_lua $BASE_DATA | awk -F ':' '{print $2}'`
    /bin/sed -i "s/bond0/$netType/g" /usr/local/hpc/conf/lua/init_phase/ghr/get_vip.lua  
 
    greenEcho "begin to modify /usr/local/hpc/conf/nginx.conf"
    /bin/sed -i  "/refresh_address/s/\(.*\)/\ \ \ \ refresh_address $BOND0_IP:21108\;/g" /usr/local/hpc/conf/nginx.conf
    /bin/sed -i -e "s/mem,ceph/mem,disk/g" /usr/local/hpc/conf/custom/vhost/for_dollar.conf

    touch $FLAG
    greenEcho "done."
  fi
}

#修改STA配置文件参数
function modSTA() 
{
  mylog="$logdir/modSTA"
  mydata="$datadir/modSTA"
  FLAG="$flagdir/modSTA"

  if [ ! -f $FLAG ]; then
    #my_pause "Begin to modify STA configure?"
    greenEcho "begin to modify storage_api configure file."
    wget http://hpcc:CChpcc@223.202.201.176/cos/storage_steven.conf  -qO /usr/local/storage/storage_api/conf/servers/storage.conf
    /bin/sed -i -r "/tair_cs_ip/s/[0-9]+.[0-9]+.[0-9]+.[0-9]+/$BOND0_IP/g" /usr/local/storage/storage_api/conf/servers/storage.conf 
    /bin/sed -i -e "s/use_ceph .*;/use_ceph 0;/g" /usr/local/storage/storage_api/conf/servers/storage.conf
    /bin/sed -i -e "s/server.*:600/server $BOND0_IP:600/" /usr/local/storage/storage_api/conf/servers/tfs.conf
    grep "seg_suffix_type" -r /usr/local/storage/storage_api/conf/servers/storage.conf &>/dev/null
    if [ $? -ne 0 ]; then
        /bin/sed -i -e '32a \ \ \ \ set $seg_suffix_type "1"; ' /usr/local/storage/storage_api/conf/servers/storage.conf
    fi
    touch $FLAG
    greenEcho "done."
  fi
}


#修改tair配置参数
function modTair() 
{
  mylog="$logdir/modTair"
  FLAG="$flagdir/modTair"

  if [ ! -f $FLAG ]; then
    #my_pause "Begin to mod Tair configure?"
    greenEcho "begin to modify tair configure file."

    #mkdir dir
    mkdir -p /data/proclog/log/storage/memcache

    #change conf
	wget -qO /usr/local/storage/tair_bin/etc/configserver.conf http://223.202.75.127:8001/ganna/single/tair/configserver.conf
    wget -qO /usr/local/storage/tair_bin/etc/group.conf http://223.202.75.127:8001/ganna/single/tair/group.conf.page
	wget -qO /usr/local/storage/tair_bin/etc/dataserver.conf.mem http://223.202.75.127:8001/ganna/single/tair/dataserver.conf.mem
	sed -i "s/127.0.0.1/$BOND0_IP/g" /usr/local/storage/tair_bin/etc/configserver.conf
    sed -i "s/127.0.0.1/$BOND0_IP/g" /usr/local/storage/tair_bin/etc/group.conf
	sed -i "s/127.0.0.1/$BOND0_IP/g" /usr/local/storage/tair_bin/etc/dataserver.conf.mem

    TAIR_NET=`grep hpc_lua $BASE_DATA | awk -F ':' '{print $2}'`
    if [ "$TAIR_NET" != "bond0" ];then
        sed -i "s/bond0/$TAIR_NET/g" /usr/local/storage/tair_bin/etc/configserver.conf
        sed -i "s/bond0/$TAIR_NET/g" /usr/local/storage/tair_bin/etc/group.conf
        sed -i "s/bond0/$TAIR_NET/g" /usr/local/storage/tair_bin/etc/dataserver.conf.mem

    fi
   
    tairMem=`grep tair_mem $BASE_DATA | awk -F ':' '{print $2}'`
    /bin/sed -i "s/slab_mem_size=.*/slab_mem_size=1024/g" /usr/local/storage/tair_bin/etc/dataserver.conf.mem

    touch $FLAG
    greenEcho "done."
  fi
}



#修改refresh配置文件参数
function modRfrd() 
{
  mylog="$logdir/modRfrd"
  FLAG="$flagdir/modRfrd"

  if [ ! -f $FLAG ]; then
    #my_pause "Begin to add RFRD configure?"
    greenEcho "begin to modify refresh configure file."

    cp -fr /usr/local/refreshd/conf/vhost/refreshd.conf.demo /usr/local/refreshd/conf/vhost/refreshd.conf
    cp -fr /usr/local/refreshd/conf/vhost/storage_upstream.conf.demo /usr/local/refreshd/conf/vhost/storage_upstream.conf
    sed -i '/10002/d' /usr/local/refreshd/conf/vhost/storage_upstream.conf
    sed -i "s/10001/770/" /usr/local/refreshd/conf/vhost/storage_upstream.conf

    mkdir -p /usr/local/refreshd/conf/ssdb
    wget -qO /usr/local/refreshd/conf/ssdb/1.conf http://223.202.75.127:8001/ganna/single/ssdb/1.conf
    wget -qO /usr/local/refreshd/conf/ssdb/2.conf http://223.202.75.127:8001/ganna/single/ssdb/2.conf
    wget -SO /usr/local/refreshd/conf/vhost/refreshd.conf http://223.202.75.127:8001/hpcc.xunjian/download/refreshd.conf &>/dev/null

    sed -i "s#cache1/db#cache1/db1#g" /usr/local/refreshd/conf/ssdb/1.conf
    sed -i "s#cache2/db#cache2/db2#g" /usr/local/refreshd/conf/ssdb/2.conf
    mkdir -p /data/cache1/db1
    mkdir -p /data/cache2/db2
    touch $FLAG
    greenEcho "done."
  fi
}

#修改Named配置文件
function modNamed() 
{
  mylog="$logdir/modNamed"
  mydata="$datadir/modNamed"
  FLAG="$flagdir/modNamed"

  #my_pause "Begin to modify Named configure?"
  if [ ! -f $FLAG ]; then
    greenEcho "begin to modify named configure file."
    touch $FLAG
    sed -i 's/#//' /etc/cron.d/hpcc_detector
    touch /var/named/chroot/var/named/anyhost
    grep check-names /var/named/chroot/etc/named.conf > /dev/null || /bin/sed -i -e "/allow-query/a\        check-names master ignore;" /var/named/chroot/etc/named.conf
    greenEcho "done."
  fi
}


#格式化并挂载SSDB盘(刷新)
function mkfsSSDB()
{
  mylog="$logdir/mkfsSSDB"
  FLAG="$flagdir/mkfsSSDB"

  if [ ! -f $FLAG ]; then
    #my_pause "Begin to format the SSDB disk and mkfs it?"
    greenEcho "begin to format the SSDB disk."

    umount -l /data/cache1 > /dev/null 2>&1
    umount -l /data/cache2 > /dev/null 2>&1
    mkdir -p /data/cache1
    mkdir -p /data/cache2

    wget -qO /root/format_ssdb_entire.sh http://223.202.75.127:8001/huichen.liu/hpcc/format_ssdb_entire.sh >> $mylog 2>&1
    diskes=`grep ssdb_disk $BASE_DATA | awk -F ':' '{print $2}'`
    /bin/bash /root/format_ssdb_entire.sh $diskes >> $mylog 2>&1

    df -h | grep /data/cache1 > /dev/null 2>&1
    cache1=`echo $?`
    df -h | grep /data/cache2 > /dev/null 2>&1
    cache2=`echo $?`
    if [ $cache1 -eq 0 -a $cache2 -eq 0 ]; then
      touch $FLAG
      greenEcho "done."
    else
      redEcho "failed!"
      CMD="/bin/bash /root/format_ssdb_entire.sh $diskes"
      echo -e "\n错误详情见日志：$mylog\n可手动安装跳过此步骤，执行以下步骤：\n1.$CMD\n2.touch $FLAG"
      exit 0
    fi
  fi
}


#安装truck
function installTruck()
{
  mylog="$logdir/installTruck"
  mydata="$datadir/installTruck"
  FLAG="$flagdir/installTruck"

  if [ ! -f $FLAG ]; then
	#my_pause "Begin to install Truck?"
	greenEcho "begin to install truck."
	rm -fr /root/truck
	killall /usr/local/nginx-1.6.0/sbin/nginx > /dev/null 2>&1
	wget -O /root/truck-dis-6.5.tar.gz http://hpcc:CChpcc@223.202.201.176/tmp/jinchao.chen/truck-dis-6.5.tar.gz > $mylog 2>&1
	tar -zxf /root/truck-dis-6.5.tar.gz -C /root
	cd /root/truck
	echo "\n\n********** to run install_truck.sh $BOND0_IP $BOND0_IP **********" >> $mylog
	./install_truck_server.sh $BOND0_IP $BOND0_IP >> $mylog 2>&1
	echo "\n\n********** to run install_truck_server.sh $BOND0_IP $BOND0_IP **********" >> $mylog
	./install_truck.sh $BOND0_IP $BOND0_IP >> $mylog 2>&1
	CMD1="bash /root/truck/install_truck.sh $BOND0_IP $BOND0_IP"
	CMD2="bash /root/truck/install_truck_server.sh $BOND0_IP $BOND0_IP"
	/usr/local/nagios/libexec/check_nrpe -H $BOND0_IP > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      greenEcho "done."
      touch $FLAG
    else
      redEcho "failed!"
      rm -f $FLAG
      echo -e "\n错误详情见日志：$mylog\n可手动安装跳过此步骤：\n1.$CMD1\n2.$CMD2\n3.touch $FLAG"
      exit 0
    fi
  fi
}

function tellStartProcess()
{
  res=$1
  logfile="$logdir/startProcess"
  if [ $res -eq 0 ];then
    echo "success!" >> $logfile
  else
    echo "failed!" >> $logfile
  fi
}

function startProcess() 
{
  mylog="$logdir/startProcess"
  FLAG="$flagdir/startProcess"
  rpm -e ELR &>/dev/null
  if [ ! -f $FLAG ]; then
    service named restart > $mylog
    if [ $? -eq 0 ]; then
      touch $FLAG
      greenEcho "done."
    else
      rm -f $FLAG
      redEcho "failed!"
      CMD="service named restart"
      echo -e "\n错误详情见日志：$mylog\n可手动安装跳过此步骤，执行以下步骤：\n1.$CMD\n2.touch $FLAG"
      exit 0
    fi

    killall nginx > /dev/null 2>&1
    sleep 2
    #my_pause "Begin to start process?"
    greenEcho "start process: HPC nginx; STA nginx; refresh nginx; SSDB; Tair......"

    echo -e "\n\n********** start /usr/local/hpc/sbin/nginx **********" > $mylog
    /usr/local/hpc/sbin/nginx -s stop > /dev/null 2>&1
    touch /usr/local/hpc/conf/billing_tencent_domain_with_sdtfrom.txt
    /usr/local/hpc/sbin/nginx -c /usr/local/hpc/conf/nginx.conf >> $mylog 2>&1
    hpcRes=`echo $?`
    tellStartProcess $hpcRes



    echo -e "\n\n********** start /usr/local/refreshd/sbin/nginx **********" >> $mylog 
    /usr/local/refreshd/sbin/nginx -s stop > /dev/null 2>&1
    /usr/local/refreshd/sbin/nginx -c /usr/local/refreshd/conf/nginx.conf >> $mylog 2>&1
    rfrdRes=`echo $?`
    tellStartProcess $rfrdRes

    echo -e "\n\n********** start ssdb process **********" >> $mylog 2>&1
    /usr/local/refreshd/sbin/ssdb -p stop >> $mylog 2>&1
    sleep 2
    /usr/local/refreshd/sbin/ssdb-server -d /usr/local/refreshd/conf/ssdb/1.conf >> $mylog 2>&1 
    /usr/local/refreshd/sbin/ssdb-server -d /usr/local/refreshd/conf/ssdb/2.conf >> $mylog 2>&1 
    ssdbRes=`ps -ef | grep ssdb-server | grep -v grep | wc -l`
    if [ $ssdbRes -eq 2 ];then
        echo "success!" >> $mylog
    else
        echo "failed!" >> $mylog
    fi

    echo -e "\n\n********** start tair process **********" >> $mylog 2>&1
    tair_pid=`ps -ef | grep tair | grep -v grep | awk '{print $2}'`
    kill -9 $tair_pid > /dev/null 2>&1
    rm -rf /data/cache1/storage/diskcacheindex/
    sleep 2
    /usr/local/storage/tair_bin/sbin/tair_server -f /usr/local/storage/tair_bin/etc/dataserver.conf.mem >> $mylog 2>&1
    /usr/local/storage/tair_bin/sbin/tair_cfg_svr -f /usr/local/storage/tair_bin/etc/configserver.conf >> $mylog 2>&1
    tair_process=`ps -ef | grep -E 'dataserver.conf|configserver.conf' | grep -v grep | wc -l`
    if [ $tair_process -eq 2 ];then
      echo "success!" >> $mylog
    else
      echo "failed!" >> $mylog
    fi

    echo -e "\n\n********** start tfs process **********" >> $mylog 2>&1
    killall /usr/local/storage/tfs_bin/bin/nameserver > /dev/null 2>&1
    killall /usr/local/storage/tfs_bin/bin/dataserver > /dev/null 2>&1
    sleep 2
    
    ats_process=`ps axu|grep traffic|grep -v grep|wc -l`
    if [ $ats_process -eq 3 ];then
      echo "success!" >> $mylog
    else
      echo "failed!" >> $mylog
    fi
	
    if [ $hpcRes -ne 0 -o $rfrdRes -ne 0 -o $ssdbRes -ne 2 -o $tair_process -ne 2 -o $ats_process -ne 3 ]; then
      redEcho "failed."
      echo -e "\n错误详情见日志：$mylog\n可建立安装flag跳过脚本里的步骤: touch $FLAG"
      exit 0
    else
      touch $FLAG
      greenEcho "done."
    fi
  fi
}


#修改调优参数
function tuningParameters() 
{
  mylog="$logdir/tuningParameters"
  FLAG="$flagdir/tuningParameters"

  if [ ! -f $FLAG ]; then
    #my_pause "Begin to deploy tuning parameters?"

    greenEcho "begin to deploy tune parameters."
    #hot_analysis热度模块关闭部署
    echo "\nhot_analysis热度模块关闭部署" >> $mylog
    ps ax |grep python2.7|grep hot_analysis.py | awk '{print $1}' | xargs kill -9 > /dev/null 2>&1
    wget -O /usr/local/storage/hot_analysis/hot_analysis.sh http://223.202.75.127:8001/bowen/hot/hot_analysis.sh > $mylog 2>&1
    wget -O /etc/cron.d/hot_analysis http://223.202.75.127:8001/ganna/single/crond/hot_analysis >> $mylog 2>&1
    /etc/init.d/crond restart > /dev/null 2>&1

    #修改内网参数
    echo "\n修改内网参数" >> $mylog
    /sbin/ethtool -G eth0 rx 4096 tx 4096 >> $mylog 2>&1
    /sbin/ethtool -G eth1 rx 4096 tx 4096 >> $mylog 2>&1
    greenEcho "done."

    touch $FLAG
  fi
}

#部署DM
function deployNGandDM()
{
  mylog="$logdir/deployDM"
  FLAG="$flagdir/deployDM"

  if [ ! -f $FLAG ]; then
#my_pause "Begin to deploy DM?"
    greenEcho "begin to deploy NG & DM."
    wget -O /root/update_ng_dm.sh http://223.202.75.127:8001/huichen.liu/scripts/update_ng_dm.sh >> $mylog 2>&1
    echo "\n********** to run /bin/bash /root/update_ng_dm.sh **********\n\n" >> $mylog 2>&1
    /bin/bash /root/update_ng_dm.sh >> $mylog 2>&1
#NG更新
	wget -SO /tmp/ngManager.sh  https://101.251.97.136/static/ngManager.sh --no-check-certificate >$mylog 2>&1
    bash /tmp/ngManager.sh upgrade_short > $mylog 2>&1
	grep -q "NG upgrade success" $mylog
	if [ $? -ne 0 ];then
		bash ngManager.sh rollback_short >$mylog 2>&1
	fi
#DM配置文件更新
	wget -qO-  http://223.202.197.223/dm/hpccsingle_updatedm.sh|bash &>/dev/null
    greenEcho "done."
    touch $FLAG
  fi
}

##创建单机版集群
#function createSingleDispatch()
#{
#  mylog="$logdir/createSingleDispatch"
#  FLAG="$flagdir/createSingleDispatch"
#
#  if [ ! -f $FLAG ]; then
#    #my_pause "Begin to create Single Dispatch ?"
#    greenEcho "begin to create Single Dispatch."
#    singalNum=`cat $SingalNumFile` 
#    if [ "$singalNum" == "no_signal_number" ]; then
#      redEcho "没有cms编号，请获得编号后再次执行该脚本！"
#    else
#      wget -qO /root/cms_signal_install.sh http://223.202.75.127:8001/hpcc.xunjian/ATS/cms_signal_install.sh
#      sh /root/cms_signal_install.sh $singalNum $BOND0_IP > $mylog 2>&1
#      echo -e "\n\n********** check signal java **********\n\n" >> $mylog 2>&1
#      ps -ef | grep /opt/cms/proj/cms_dispatch/Signal | grep -v grep >> $mylog 2>&1
#      if [ $? -eq 0 ]; then
#        touch $FLAG
#        type=`cat $BussiTypeFile`
#        singleDir=`cat $SingalNumFile | sed 's/:/_/'`
#        if [ "$type" == "video" ];then
#            touch /opt/cms/proj/cms_dispatch/$singleDir/flag_not_delete_BRE_MSO
#        elif [ "$type" == "download" ];then
#            touch /opt/cms/proj/cms_dispatch/$singleDir/flag_not_delete_BRE_DL
#        else
#            touch /opt/cms/proj/cms_dispatch/$singleDir/flag_not_delete_BRE_WEB
#        fi
#        greenEcho "done."
#      else
#        redEcho "create Single Dispatch failed!"
#        echo "错误详情见日志：$mylog"
#        exit 0
#      fi
#    fi
#    #cms1.0安装完成后，不需要启动java进程。因为不通过cms管理系统下发.
#    ps -ef | grep cms_dispatch | grep -v grep | awk '{print $2}' | xargs kill -9 >/dev/null 2>&1
#  fi
#}

#创建单机版集群
function createSingleDispatch()
{
  mylog="$logdir/createSingleDispatch"
  FLAG="$flagdir/createSingleDispatch"

  if [ ! -f $FLAG ]; then
    greenEcho "begin to create Single Dispatch."
    singalNum=`cat $SingalNumFile`
    if [ "$singalNum" == "no_signal_number" ]; then
      redEcho "没有cms编号，请获得编号后再次执行该脚本！"
      exit 0
    else
        touch $FLAG
        singleDir=`cat $SingalNumFile | sed 's/:/_/'`
        mkdir -p /opt/cms/data/tmpdata/$singleDir/HPC/$BOND0_IP
        mkdir -p /opt/cms/data/tmpdata/$singleDir/StorageDiskCacheIndexMeta/$BOND0_IP
        mkdir -p /opt/cms/data/tmpdata/$singleDir/OpDevices/$BOND0_IP
        mkdir -p /opt/cms/proj/cms_dispatch/$singleDir
        type=`cat $BussiTypeFile`
        if [ "$type" == "video" ];then
            touch /opt/cms/proj/cms_dispatch/$singleDir/flag_not_delete_BRE_MSO
        elif [ "$type" == "download" ];then
            touch /opt/cms/proj/cms_dispatch/$singleDir/flag_not_delete_BRE_DL
        else
            touch /opt/cms/proj/cms_dispatch/$singleDir/flag_not_delete_BRE_WEB
        fi
        greenEcho "done."
    fi
  fi
}

function createCMS3()
{
    mylog="$logdir/createCMS3"
    FLAG="$flagdir/createCMS3"
    if [ ! -f $FLAG ];then
        singalNum=`cat $SingalNumFile | sed 's/:/_/'`
        devicename=`hostname`
        greenEcho "begin to install CMS3"
        ps -ef | grep tm_dispatch | grep -v grep | awk '{print $2}' | xargs kill -9 > /dev/null 2>&1
        wget -qO /tmp/installCMS3.sh http://223.202.75.127:8001/ganna/cms3/installCMS3.sh > $mylog 2>&1
        sh /tmp/installCMS3.sh $singalNum  >> $mylog 2>&1
        if [ $? -ne 0 ];then
            echo "手动执行命令,安装CMS3:"
			echo -e "1.wget -qO /tmp/installCMS3.sh http://223.202.75.127:8001/ganna/cms3/installCMS3.sh\n2.sh /tmp/installCMS3.sh $singalNum\n3.ps -ef | grep tm_dispatch\n4.touch $FLAG"
			exit 0
        fi
        #sed -i -e "s/CONF_IP_LAN =.*/CONF_IP_LAN = '$BOND0_IP'/" /root/truck/truck_dln.py
        sleep 3
        isCMS3On=`ps -ef | grep tm_dispatch | grep -v grep | wc -l`
        if [ $isCMS3On -eq 1 ];then
            touch $FLAG
            greenEcho "end"
        else
            echo "start cms3 by hand!"   >> $mylog 2>&1
            isCMS3On=`ps -ef | grep tm_dispatch | grep -v grep | wc -l` && ( touch $FLAG; greenEcho "end" ) || ( redEcho "failed!";echo "手动执行命令,安装CMS3:";echo -e "1.wget -qO /tmp/installCMS3.sh http://223.202.75.127:8001/ganna/cms3/installCMS3.sh\n2.sh /tmp/installCMS3.sh $singalNum\n3.ps -ef | grep tm_dispatch\n4.touch $FLAG"; exit 0 )
        fi
    fi
}



#视频才有的配置：关闭压缩备份和打开码率
function videoOnly()
{
  mylog="$logdir/videoOnly"
  FLAG="$flagdir/videoOnly"

  type=`cat $BussiTypeFile`
  wget -qO- http://223.202.75.127:8001/hpcc.xunjian/ATS/tencent_device.sh|bash >> $mylog 2>&1
  if [ "$type" == "video" ]; then
    if [ ! -f $FLAG ]; then
      #my_pause "Begin to run for video?"
      greenEcho "begin to run some special configure for video."
      echo -e "\n关闭压缩备和打开码率" >> $mylog 2>&1
      wget -qO - http://hpcc:CChpcc@223.202.201.176/scripts/for_video-1.sh | bash >> $mylog 2>&1
      if [ $? -eq 0 ]; then
        touch $FLAG
        greenEcho "done."
      else
        redEcho "failed!"
        CMD="wget -qO - http://hpcc:CChpcc@223.202.201.176/scripts/for_video-1.sh | bash"
        echo -e "\n错误详情见日志：$mylog\n可手动安装跳过此步骤，执行以下命令：\n1.$CMD\n2.to $FLAG"
        exit 0  
      fi
    fi
  fi
}


#*********************************** 检查磁盘 ****************************************
function disk_deal()
{
	cache_list=`df -h|grep cache|grep -Ev "cache1$|cache2$"|awk -F "/" '{print $NF}'`
	for disk in `echo $cache_list`
	do
		umount -l /data/$disk
		sed -i "/$disk/d" /etc/fstab
	done
	disk_not_umount_sum=`df -h|egrep -E "/data/cache|/data/proclog"|wc -l`
	if [ $disk_not_umount_sum -ne 3 ];then
		return 1
	fi
}
#*************************************************************************************

#****************************************安装完成之后的检查************************************************

function lastCheck() 
{
  mylog="$logdir/lastCheck"
  FLAG="$flagdir/lastCheck"

  if [ ! -f $FLAG ]; then
    #my_pause "Begin to last check?"

    echo "wait......"

    touch $FLAG
  fi
}

                                                                                                                                                                                                                           
function getSignalNum() 
{        
  mylog="$logdir/getSignalNum"                                                                                         
  FLAG="$flagdir/getSignalNum"     
                                                                                                                       
  if [ ! -f $FLAG ];then                                             
    greenEcho "begin to get cms number."                                                                               
    echo "put your username (tip:name before '@' at mail:username@chinacache.com)"                                     
    read username                                                                                                      
    echo "put your password (tip:your mail password)"                                                                  
    read password                                                                                                      
    devicename=`hostname`                                                                                              
    result=$(curl -s "http://cms.chinacache.net/channel/getSignalIdByDeviceName/${username}/${password}/${devicename}" | awk '{print $4}')           
    if [[ "$result" =~ "Signal" ]];then
        echo $result > $SingalNumFile                                              
        touch $FLAG      
        greenEcho "done."
    else  
        redEcho "failed!" 
        CMD="wget -O /root/query_signal_num.sh http://223.202.75.68:8080/upload/query_signal_num.sh;sh /root/query_signal_num.sh"  
        echo -e "\n手动执行以下步骤：1.$CMD\n2.touch $FLAG"
        exit 0
    fi   
  fi                                                                                                         
}                                                                                                                                                                                                                          


#*********************************** OP配置 ******************************************
function config_op()
{
	greenEcho "Start to config op!"
	[ -d /opt/cms/data/tmpdata ] || exit 1
	NUMBER=`cat $SingalNumFile|awk -F ":" '{print $2}'`
	mkdir -p /opt/cms/data/tmpdata/Signal_${NUMBER}/OpDevices/$BOND0_IP	|| exit 1
	wget -SO /opt/cms/data/tmpdata/Signal_${NUMBER}/OpDevices/${BOND0_IP}/localhost.conf http://223.202.75.127:8001/hpcc.xunjian/download/localhost.conf &> /dev/null || exit 1
	sed -i "s/127.0.0.1/${BOND0_IP}/" /opt/cms/data/tmpdata/Signal_${NUMBER}/OpDevices/${BOND0_IP}/localhost.conf || exit 1
	/bin/cp -f  /opt/cms/data/tmpdata/Signal_${NUMBER}/OpDevices/${BOND0_IP}/localhost.conf  /usr/local/hpc/conf/custom/vhost/localhost.conf || exit 1
        mkdir -p /opt/cms/data/tmpdata/Signal_${NUMBER}/StorageDiskCacheIndexMeta/${BOND0_IP}
	greenEcho "done"
}
#*************************************************************************************

#*********************************** 激活tair *****************************************
function start_tair()
{
	sed -i 's/server_down_time=1800/server_down_time=1/' /usr/local/storage/tair_bin/etc/group.conf
	ps aux|grep /usr/local/storage/tair_bin/etc/configserver.conf |grep -v grep|awk '{print $2}'|xargs kill -9 &>/dev/null
	sleep 1
	/usr/local/storage/tair_bin/sbin/tair_cfg_svr -f /usr/local/storage/tair_bin/etc/configserver.conf &>/dev/null
	sleep 60
	sed -i 's/server_down_time=1/server_down_time=1800/' /usr/local/storage/tair_bin/etc/group.conf
	sleep 1
	ps aux|grep /usr/local/storage/tair_bin/etc/configserver.conf |grep -v grep|awk '{print $2}'|xargs kill -9 &>/dev/null
	sleep 1
	/usr/local/storage/tair_bin/sbin/tair_cfg_svr -f /usr/local/storage/tair_bin/etc/configserver.conf &>/dev/null
}
#**************************************************************************************


#***********************************  升级NG  *****************************************
function upt_NG()
{
        rpm -q NG | grep "NG-4.6-6.i386" &>/dev/null
        if [ $? -ne 0 ];then
            wget -qO /tmp/NG-4.6-6.rpm https://101.251.97.136/static/NG-4.6-6.rpm --no-check-certificate
            rpm -e NG --allmatches --nodeps &>/dev/null
            rpm -ivh /tmp/NG-4.6-6.rpm --force &>/dev/null
            if [ $? -eq 0 ];then
                amr restart amr; sleep 1; amr restart ng &>/dev/null
                greenEcho "update NG successfully!"
            else
                echo "fail to update NG. Please execute: rpm -ivh /tmp/NG-4.6-6.rpm"
                exit 0
            fi
        fi
}
#**************************************************************************************


#********************************** 安装GHR和feedback ********************************
function installGHR()
{
  mylog="$logdir/installGHR"
  FLAG="$flagdir/installGHR"
  if [ ! -f $FLAG ];then
      type=`cat $BussiTypeFile`
      if [ "$type" == "video" ]; then
	    wget -qO -  http://223.202.75.127:8001/gaoxing/scripts/install_ghr_v.sh |bash > $mylog 2>&1
      elif [ "$type" == "download" ];then
	    wget -qO -  http://223.202.75.127:8001/gaoxing/scripts/install_ghr_d.sh |bash > $mylog 2>&1
      fi
  touch $FLAG
  fi
}

#**************************************************************************************


#*********************************** 安装开始 *****************************************

if [[ "$1" != "page" && "$1" != "download" && "$1" != "video" ]]; then 
  echo -e "\\033[35mUsage: sh $0 [page|download|video]\\033[0m"
  exit 0
fi

mkdir -p $datadir
mkdir -p $logdir
mkdir -p $flagdir

SingalNumFile=$datadir"/SingalNum"
BussiTypeFile=$datadir"/BussiType"
echo $1 > $BussiTypeFile

#检查设备是否符合要求
preCheck
BOND0_IP=`grep bond0_ip $BASE_DATA | awk -F ':' '{print $2}'`
cat /etc/redhat-release  | grep "CentOS release 6.5 (Final)" > /dev/null
if [ $? -eq 0 ];then
  release=0
else
  echo "Linux OS is not CentOS 6.5!Please Check!"
  exit
fi

setHosts
setDNS 1

#获取cms编号
getSignalNum

#安装基础环境及组件
installBaseEnv
installCache
installMeta
installRfrd
#cms3 dispatch单机版不调用truck
#installTruck
installGHR

#修改配置
configZK
config_cos
modHPC
modSTA
modTair
modRfrd
modNamed

#创建dispatch
createSingleDispatch
createCMS3

#部署调优参数、NG和DM; 启动进程;部署视频hpc参数
tuningParameters
deployNGandDM
startProcess
videoOnly
start_tair
config_op
upt_NG
#安装完毕之后的检查
#lastCheck
if [[ -f /home/cms/tmp/Control/is_detect.dat ]];then
	echo "1" > /home/cms/tmp/Control/is_detect.dat
else
	mkdir -p /home/cms/tmp/Control
	touch /home/cms/tmp/Control/is_detect.dat
	echo "1" > /home/cms/tmp/Control/is_detect.dat 
fi
rm -rf /etc/cron.d/clear_tfs
rm -rf /etc/cron.d/tfs
chmod 755 /var/named
wget -qO- http://223.202.75.127:8001/huichen.liu/ipmi/change_ipmi.sh|bash &>/dev/null
wget -qO- http://223.202.75.127:8001/yongfu/ssr/echo.sh|bash &>/dev/null
wget -qO- http://223.202.75.127:8001/hpcc.xunjian/TFS/cms_nginx.sh|bash &>/dev/null

greenEcho "脚本运行完毕，请进行后续HOPE页面操作"
