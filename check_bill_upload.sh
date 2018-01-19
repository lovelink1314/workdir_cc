#!/bin/bash
# Desc  : Check Billingd dm upload 
# Author: gang.wang@chinacache.com
# Date  : 2016-03-02
folder_dir=/data/proclog/log/hpc/folderflow/incoming/
mvod_dir=/data/proclog/log/mvodms/billing/incoming/
pno_dir=/data/proclog/log/hpc/pno_billing/incoming/
tencent_dir=/data/proclog/log/mvodms/billing/newmvodmsbilling/
qqmusic_dir=/data/proclog/log/hpc/billing/.upload/
num=$1

function shanghai_or_shoumi()
{
	local sh=$1
	local sm=$2
	local threshold=$3
	if [ $sh -lt  $threshold -a $sm -lt $threshold ];then
		echo 0
	elif [ $sh -gt $threshold -a $sm -lt $threshold ];then
		echo 1	#上海计费堆积
	elif [ $sh -lt $threshold -a $sm -gt $threshold ];then
		echo 2	#首鸣计费堆积
	else
		echo 3	#首鸣与上海计费堆积
	fi
}

function folder()
{	
	if [ -d "$folder_dir.ShanghaiBillingCenter/" ];then
		floder_num_S=`ls -l $folder_dir.ShanghaiBillingCenter/ |wc -l`
		floder_num_S_M=`ls -l $folder_dir.ShouMillingCenter/ |wc -l`
		shanghai_or_shoumi $floder_num_S  $floder_num_S_M  $num
	else
		echo 0
	fi		
}


function mvod()
{
	if [ -d "$mvod_dir.ShanghaiBillingCenter/" ];then
		mvod_num_S=`ls -l $mvod_dir.ShanghaiBillingCenter/ |wc -l`
        mvod_num_S_M=`ls -l $mvod_dir.ShouMillingCenter/|wc -l`
		shanghai_or_shoumi $mvod_num_S  $mvod_num_S_M  $num
	else
		echo 0
	fi
}

function pno()
{
	if [ -d "$pno_dir.ShanghaiBillingCenter/" ];then
		pno_num_S=`ls -l $pno_dir.ShanghaiBillingCenter/ |wc -l`
		pno_num_S_M=`ls -l $pno_dir.ShouMillingCenter/ |wc -l`
		shanghai_or_shoumi $pno_num_S  $pno_num_S_M  $num
	else
		echo 0
	fi
} 


function tencent()
{
	if [ -d "$tencent_dir.ShanghaiBillingCenter/" ];then
		tencent_num_S=`ls -l $tencent_dir.ShanghaiBillingCenter/ |wc -l`
		tencent_num_S_M=`ls -l $tencent_dir.ShouMillingCenter/|wc -l`
		shanghai_or_shoumi $tencent_num_S  $tencent_num_S_M  $num
	else
		echo 0
	fi
}

function qqmusic()
{
	if [ -d "$qqmusic_dir.ShanghaiBillingCenter/" ];then
		qqmusic_num_S=`ls -l $qqmusic_dir.ShanghaiBillingCenter/ |wc -l`
		qqmusic_num_S_M=`ls -l $qqmusic_dir.ShouMingCenter/ |wc -l`
		shanghai_or_shoumi $qqmusic_num_S  $qqmusic_num_S_M  $num
	else
        echo 0
	fi
}


if [ $(folder) -eq 0  -a  $(mvod) -eq 0  -a  $(pno) -eq 0  -a  $(tencent) -eq 0 -a  $(qqmusic) -eq 0 ];then
	echo 0
elif [ $(folder) -eq 2  -o  $(mvod) -eq 2  -o  $(pno) -eq 2  -o  $(tencent) -eq 2 -o  $(qqmusic) -eq 2 ];then
	echo 2	#首鸣计费堆积
elif [ $(folder) -eq 1  -o  $(mvod) -eq 1  -o  $(pno) -eq 1  -o  $(tencent) -eq 1 -o  $(qqmusic) -eq 1 ];then 
	echo 1	#上海计费堆积
else
	echo 3 #上海与首鸣计费堆积
fi
