#!/bin/bash
#
TXT_FILE="xj-$(date --date '1 day ago' +"%Y%m%d").txt"
HTML_FILE="xj-$(date --date '1 day ago' +"%Y%m%d").html"
FUFFIX="$(date --date '1 day ago' +"%Y%m%d")c.txt"

######
BASE_DIR="/data/cache1/hpcc.xunjian/check_result"
CURL_URL="http://223.202.75.127:8001/hpcc.xunjian/check_result"
######
SERVICE_SUM="NicSpeed"
VERSION_SUM="P D V S_P S_D S_V"
#巡检日报admin邮箱
adminmail="rong.chen@chinacache.com"
#巡检日报收件人邮箱
noticemail="CPRD-HPCC-OM@chinacache.com yang.liu@chinacache.com jian.lan@chinacache.com jun.gao@chinacache.com zehong.xue@chinacache.com yunfeng.zhang@chinacache.com longjun.zhao@chinacache.com"
#noticemail="rong.chen@chinacache.com"



main(){
#if [[ -f ${BASE_DIR}/tfs/nodetop20-P-tfsuag-version-${FUFFIX} ]]
#then
#	echo "ok,nodetop20-P-tfsuag uploaded"
#else
#	echo "Pls check"|mail -s "$(echo -e "ERROR,HPCC daily report \nContent-Type: text/html")" ${adminmail} -- -f xunjian@rong.chen.hpcc
#	exit 0
#fi

cd ${BASE_DIR}/html
rm -f ${TXT_FILE} ${HTML_FILE}
echo "在单台主机上执行如下命令进行check.检查内容与巡检日报类似" >>${TXT_FILE}
echo "curl -s http://223.202.75.127:8001/hpcc.xunjian/script/xj.sh|bash" >>${TXT_FILE}
echo "============================" >> ${TXT_FILE}
echo "" >> ${TXT_FILE}

billing_file >> ${TXT_FILE}

cmsfile_one >> ${TXT_FILE}
cmsfile_two >> ${TXT_FILE}
cmsfile_three >> ${TXT_FILE}


#NG版本
ng_version  >> ${TXT_FILE}
saltenv-sonar_version >> ${TXT_FILE}
salt-minion-sonar_version >> ${TXT_FILE}


#服务
for ser in ${SERVICE_SUM}
do
	check_service_pro ${ser} >>${TXT_FILE}
done
echo "<br />" >>${TXT_FILE}

#版本
for ver in ${VERSION_SUM}
do
	check_version_pro ${ver}  >> ${TXT_FILE}
done
#TFS 磁盘空间
#tfs_disk_usage >> ${TXT_FILE}


#将txt文件转换成html文件
translate_txt_to_html
}


#整理各服务巡检结果
#			  服务名
#check_service_pro  ${1}
function check_service_pro(){
echo_service_title ${1}
num=$(cat ${BASE_DIR}/${1}/running-${1}-${FUFFIX}|wc -l)
if [[ ${num} -ge 1 ]]
then
	echo "<b><div style='color:red'>"
	echo_service_expection ${1}
	echo "</div></b>"
else
	echo "服务${1}正常"
fi
echo "============================="
echo ""
}

function echo_service_title(){
case ${1} in
	ssh)
		echo "HPCC所有设备ssh登陆扫描   负责人：每日值班人员"
		;;
	vnc)
		echo "VNC 扫描 负责人：每日值班人员"
		;;
	puppet)
		echo "Puppet 扫描 负责人：每日值班人员"
		;;
	NicSpeed)
		echo "NicSpeed速率检查 负责人：每日值班人员"
		;;
	localdns)
		echo "LocalDNS 扫描  负责人：每日值班人员"
		;;
	crond)
		echo "Crond服务状态扫描 负责人：每日值班人员"
		;;
	cms_parameter_check)
		echo "CMS配置参数should_delete_chsfinal值为false  负责人：甘娜"
		;;
	*)
		echo "UNKNOWN SERVICE!"
		exit 1
esac
}


function echo_service_expection(){
case ${1} in
	ssh)
		echo "以下设备ssh登录异常！"
		egrep ' 9$| 255$' ${BASE_DIR}/${1}/running-${1}-${FUFFIX}|awk '{print $4}'
		;;
	vnc)
		echo "以下主机VNC处于开启状态！"
		cat ${BASE_DIR}/${1}/running-${1}-${FUFFIX}|awk '{print $1}'
		;;
	puppet)
		echo "以下主机Puppet服务异常！"
		cat ${BASE_DIR}/${1}/running-${1}-${FUFFIX}|awk '{print $1}'
		;;
	NicSpeed)
		echo "以下主机网卡速率异常！"
		cat ${BASE_DIR}/${1}/running-${1}-${FUFFIX}
		;;
	localdns)
		echo "请检查以下主机LocalDNS状态！"
		cat ${BASE_DIR}/${1}/running-${1}-${FUFFIX}|awk '{print $1}'
		;;
	crond)
		echo "以下主机crond服务处于停止状态！"
		cat ${BASE_DIR}/${1}/running-${1}-${FUFFIX}
		;;
	cms_parameter_check)
		echo "以下主机CMS配置参数should_delete_chsfinal异常！"
		cat ${BASE_DIR}/${1}/running-${1}-${FUFFIX}		
		;;
	*)
		echo "UNKNOWN SERVICE!"
		exit 1
esac
}

function check_version_pro(){
case ${1} in
	P)
		echo "页面节点组件版本统计"
		MODULE="${1}-KERNEL ${1}-HPC ${1}-HPC-LUA  ${1}-HPC-CONF ${1}-HPC-MONITOR-${1} ${1}-CMS_RELOAD ${1}-STA ${1}-HPO ${1}-BILLD ${1}SSD-${1}SSD ${1}RFRD-RFRD ${1}RFRD-CMS_RELOAD ${1}-TAIR-DS ${1}-TFS-DS ${1}META-CMS_RELOAD_META ${1}META-TAIR-CS ${1}META-TFS-NS  ${1}META-DETECT ${1}-openssl ${1}-lvs"
		check_version_module_pro "${MODULE}"
		;;
	D)
		echo "下载节点组件版本统计"
MODULE="${1}-KERNEL ${1}-HPC ${1}-HPC-ZK ${1}-HPC-LUA ${1}-HPC-MONITOR-${1} ${1}-CMS_RELOAD_DV ${1}-STA ${1}-BILLD ${1}RFRD-RFRD ${1}RFRD-CMS_RELOAD_DV ${1}-TAIR-DS  ${1}-CCTS  ${1}META-CMS_RELOAD_META  ${1}META-CMS_RELOAD_DV ${1}META-TAIR-CS  ${1}META-CCTS ${1}META-DETECT ${1}-openssl ${1}-glibc ${1}-lvs"
		check_version_module_pro "${MODULE}"
		;;
	V)
		echo "视频节点组件版本统计"
MODULE="${1}-KERNEL ${1}-HPC ${1}-HPC-ZK ${1}-HPC-LUA ${1}-HPC-MONITOR-${1} ${1}-CMS_RELOAD_DV ${1}-STA ${1}-BILLD ${1}RFRD-RFRD ${1}RFRD-CMS_RELOAD_DV ${1}-TAIR-DS ${1}-CCTS ${1}META-CMS_RELOAD_META ${1}META-CMS_RELOAD_DV ${1}META-TAIR-CS  ${1}META-CCTS ${1}META-DETECT ${1}-openssl ${1}-glibc ${1}-lvs"
		check_version_module_pro "${MODULE}"
		;;
	LVS)
		echo "LVS版本统计"
MODULE="${1}-LVS_IPVS"
		check_version_module_pro "${MODULE}"
		;;
	S_P)
		echo "页面单机组件版本统计"
		MODULE="${1}-KERNEL ${1}-HPC ${1}-HPC-LUA ${1}-HPC-CONF  ${1}-RFRD ${1}-jemalloc"
		check_version_module_pro "${MODULE}"
		;;
	S_D)
		echo "下载单机组件版本统计"
MODULE="${1}-KERNEL ${1}-HPC  ${1}-HPC-LUA ${1}-RFRD ${1}-jemalloc"
		check_version_module_pro "${MODULE}"
		;;
	S_V)
		echo "视频单机组件版本统计"
MODULE="${1}-KERNEL ${1}-HPC ${1}-HPC-LUA ${1}-RFRD ${1}-jemalloc"
		check_version_module_pro "${MODULE}"
		;;
	*)
		exit 1
esac
}

function check_version_module_pro(){
for module in ${1}
do
	filename="res-${module}-version"
	person_in_charge ${module}
#	echo "${module}版本统计"
	awk '
	BEGIN{
		print"<table border="1" cellspacing="0" cellpadding="5"><tr><th>数量</th><th>版本号</th></tr>"}{print"<tr><td>"$1"</td><td>"$2"</td></tr>"
	}
	END{
		print"</table>"
	}' ${BASE_DIR}/version/${filename}-${FUFFIX}
	for i in $(awk '{if (NR >1) print $2}' ${BASE_DIR}/version/${filename}-${FUFFIX});
	do
		grep "\<${i}\>$" ${BASE_DIR}/version/${module}-version-${FUFFIX} |sort;
	done > ${BASE_DIR}/version/difftest-${module}-${FUFFIX}      

#####################################################
	echo "<a href="${CURL_URL}/version/difftest-${module}-${FUFFIX}">查看异常${module}版本列表</a> &nbsp;&nbsp; <a href="${CURL_URL}/version/${module}-version-${FUFFIX}">查看所有${module}版本列表</a>"
	echo "============================"
	echo ""
done
}

function person_in_charge(){
case $1 in
	P-KERNEL|D-KERNEL|V-KERNEL|S_P-KERNEL|S_D-KERNEL|S_V-KERNEL|S_P-RFRD|S_D-RFRD|S_V-RFRD|PRFRD-RFRD|DRFRD-RFRD|VRFRD-RFRD|PSSD-PSSD|P-STA|D-STA|V-STA|P-lvs|D-lvs)
		echo "${1}版本统计 责任人：张帅"
		;;
	P-HPC|D-HPC|V-HPC|P-HPC-LUA|S_P-HPC|S_D-HPC|S_V-HPC|D-HPC-LUA|V-HPC-LUA|S_P-HPC-LUA|S_P-HPC-CONF|S_D-HPC-LUA|S_V-HPC-LUA|S_P-jemalloc|S_D-jemalloc|S_V-jemalloc|P-HPC-CONF|D-HPC-ZK|V-HPC-ZK)
		echo "${1}版本统计 责任人：高晓峰"
		;;
	P-HPC-MONITOR-P|D-HPC-MONITOR-D|V-HPC-MONITOR-V|D-glibc|V-glibc|V-lvs|P-openssl|D-openssl|V-openssl)
		echo "${1}版本统计 责任人：张帅"
		;;
	P-BILLD|D-BILLD|V-BILLD)
		echo "${1}版本统计 责任人：高晓峰"
		;;
	PMETA-CMS_RELOAD_META|DMETA-CMS_RELOAD_META|VMETA-CMS_RELOAD_META|DMETA-CMS_RELOAD_DV|VMETA-CMS_RELOAD_DV|PRFRD-CMS_RELOAD|DRFRD-CMS_RELOAD_DV|VRFRD-CMS_RELOAD_DV|D-CMS_RELOAD_DV|V-CMS_RELOAD_DV|P-CMS_RELOAD)
		echo "${1}版本统计 责任人：甘娜"
		;;
	P-HPO)
		echo "${1}版本统计 责任人：甘娜"
		;;		
	PMETA-TFS-NS|PMETA-TAIR-CS|DMETA-TAIR-CS|VMETA-TAIR-CS|PMETA-DETECT|DMETA-DETECT|VMETA-DETECT|P-TFS-DS|P-TAIR-DS|D-TAIR-DS|V-TAIR-DS)
		echo "${1}版本统计 责任人：张帅"
		;;
	DMETA-CCTS|VMETA-CCTS|D-CCTS|V-CCTS)
		echo "${1}版本统计 责任人：周睿"
		;;
	*)
		echo "${1} no person in charge!"
		exit 2
esac
}

#TFS space usage
function tfs_disk_usage(){
echo "TFS 使用量统计 责任人：张永福"
echo "使用量最高节点top 20"
awk 'BEGIN{print"<table border="1" cellspacing="0" cellpadding="5"><tr><th>节点</th><th>空间使用率(%)</th></tr>"}{print"<tr><td>"$1"</td><td>"$2"</td></tr>"}END{print"</table>"}'  ${BASE_DIR}/tfs/nodetop20-P-tfsuag-version-${FUFFIX}
echo "============================"
}


#NG版本检查
function ng_version(){
echo "NG版本统计 责任人：甘娜"
	awk '
	BEGIN{
		print"<table border="1" cellspacing="0" cellpadding="5"><tr><th>节点</th><th>版本号</th></tr>"}{print"<tr><td>"$1"</td><td>"$2"</td></tr>"
	}
	END{
		print"</table>"
	}' ${BASE_DIR}/version/res-ng-${FUFFIX}
	for i in $(awk '{if (NR >1) print $2}' ${BASE_DIR}/version/res-ng-${FUFFIX});
	do
		grep "\<${i}\>$" ${BASE_DIR}/version/ng-${FUFFIX} |sort;
	done > ${BASE_DIR}/version/difftest-ng-${FUFFIX}
	echo "<a href="${CURL_URL}/version/difftest-ng-${FUFFIX}">查看异常${module}版本列表</a> &nbsp;&nbsp; <a href="${CURL_URL}/version/ng-${FUFFIX}">查看所有${module}版本列表</a>"
	echo "============================"
	echo ""
}


function saltenv-sonar_version(){
echo "saltenv-sonar版本统计 责任人：刘会琛"
	awk '
	BEGIN{
		print"<table border="1" cellspacing="0" cellpadding="5"><tr><th>节点</th><th>版本号</th></tr>"}{print"<tr><td>"$1"</td><td>"$2"</td></tr>"
	}
	END{
		print"</table>"
	}' ${BASE_DIR}/version/res-saltenv-sonar-${FUFFIX}
	for i in $(awk '{if (NR >1) print $2}' ${BASE_DIR}/version/res-saltenv-sonar-${FUFFIX});
	do
		grep "\<${i}\>$" ${BASE_DIR}/version/res-saltenv-sonar-${FUFFIX} |sort;
	done > ${BASE_DIR}/version/difftest-saltenv-sonar-${FUFFIX}
	echo "<a href="${CURL_URL}/version/difftest-saltenv-sonar-${FUFFIX}">查看异常${module}版本列表</a> &nbsp;&nbsp; <a href="${CURL_URL}/version/saltenv-sonar-${FUFFIX}">查看所有${module}版本列表</a>"
	echo "============================"
	echo ""
}


function salt-minion-sonar_version(){
echo "salt-minion-sonar版本统计 责任人：刘会琛"
	awk '
	BEGIN{
		print"<table border="1" cellspacing="0" cellpadding="5"><tr><th>节点</th><th>版本号</th></tr>"}{print"<tr><td>"$1"</td><td>"$2"</td></tr>"
	}
	END{
		print"</table>"
	}' ${BASE_DIR}/version/res-salt-minion-sonar-${FUFFIX}
	for i in $(awk '{if (NR >1) print $2}' ${BASE_DIR}/version/res-salt-minion-sonar-${FUFFIX});
	do
		grep "\<${i}\>$" ${BASE_DIR}/version/salt-minion-sonar-${FUFFIX} |sort;
	done > ${BASE_DIR}/version/difftest-salt-minion-sonar-${FUFFIX}
	echo "<a href="${CURL_URL}/version/difftest-salt-minion-sonar-${FUFFIX}">查看异常${module}版本列表</a> &nbsp;&nbsp; <a href="${CURL_URL}/version/salt-minion-sonar-${FUFFIX}">查看所有${module}版本列表</a>"
	echo "============================"
	echo ""
}





#billing_file space usage
function billing_file(){
echo "分目录计费文件MD5值  负责人: 张永福"
filename="res-billing_file"
awk '
BEGIN{
	print"<table border="1" cellspacing="0" cellpadding="5"><tr><th>数量</th><th>计费文件MD5值</th></tr>"}{print"<tr><td>"$1"</td><td>"$2"</td></tr>"
}
END{
	print"</table>"
}' ${BASE_DIR}/version/${filename}-${FUFFIX}
for i in $(awk '{if (NR >1) print $2}' ${BASE_DIR}/version/${filename}-${FUFFIX});
do
	grep "\<${i}\>" ${BASE_DIR}/version/billing_file-${FUFFIX} |sort;
done > ${BASE_DIR}/version/difftest-billing_file-${FUFFIX}
echo "<a href="${CURL_URL}/version/difftest-billing_file-${FUFFIX}">查看异常主机计费文件MD5值列表</a> &nbsp;&nbsp; <a href="${CURL_URL}/version/billing_file-${FUFFIX}">查看所有计费文件MD5值列表</a>"
echo "============================"
}

function cmsfile_one(){
echo "文件MD5值  负责人: 甘娜"
filename="res-cmsfile_MD5_one"
awk '
BEGIN{
	print"<table border="1" cellspacing="0" cellpadding="5"><tr><th>数量</th><th>集群CMS1.0 disptach文件MD5值</th></tr>"}{print"<tr><td>"$1"</td><td>"$2"</td></tr>"
}
END{
	print"</table>"
}' ${BASE_DIR}/version/${filename}-${FUFFIX}
for i in $(awk '{if (NR >1) print $2}' ${BASE_DIR}/version/${filename}-${FUFFIX});
do
	grep "\<${i}\>" ${BASE_DIR}/version/cmsfile_MD5_one-${FUFFIX} |sort;
done > ${BASE_DIR}/version/difftest-cmsfile_MD5_one-${FUFFIX}
echo "<a href="${CURL_URL}/version/difftest-cmsfile_MD5_one-${FUFFIX}">查看异常集群CMS1.0 disptach文件MD5值列表</a> &nbsp;&nbsp; <a href="${CURL_URL}/version/cmsfile_MD5_one-${FUFFIX}">查看所有集群CMS1.0 disptach文件MD5值列表</a>"
echo "============================"
}


function cmsfile_two(){
echo "文件MD5值  负责人: 甘娜"
filename="res-cmsfile_MD5_two"
awk '
BEGIN{
	print"<table border="1" cellspacing="0" cellpadding="5"><tr><th>数量</th><th>集群CMS3.0 tm_dispatch文件MD5值</th></tr>"}{print"<tr><td>"$1"</td><td>"$2"</td></tr>"
}
END{
	print"</table>"
}' ${BASE_DIR}/version/${filename}-${FUFFIX}
for i in $(awk '{if (NR >1) print $2}' ${BASE_DIR}/version/${filename}-${FUFFIX});
do
	grep "\<${i}\>" ${BASE_DIR}/version/cmsfile_MD5_two-${FUFFIX} |sort;
done > ${BASE_DIR}/version/difftest-cmsfile_MD5_two-${FUFFIX}
echo "<a href="${CURL_URL}/version/difftest-cmsfile_MD5_two-${FUFFIX}">查看异常集群CMS3.0 tm_dispatch文件MD5值列表</a> &nbsp;&nbsp; <a href="${CURL_URL}/version/cmsfile_MD5_two-${FUFFIX}">查看所有集群CMS3.0 tm_dispatch文件MD5值列表</a>"
echo "============================"
}


function cmsfile_three(){
echo "文件MD5值  负责人: 甘娜"
filename="res-cmsfile_MD5_three"
awk '
BEGIN{
	print"<table border="1" cellspacing="0" cellpadding="5"><tr><th>数量</th><th>单机CMS1.0 tm_dispatch文件MD5值</th></tr>"}{print"<tr><td>"$1"</td><td>"$2"</td></tr>"
}
END{
	print"</table>"
}' ${BASE_DIR}/version/${filename}-${FUFFIX}
for i in $(awk '{if (NR >1) print $2}' ${BASE_DIR}/version/${filename}-${FUFFIX});
do
	grep "\<${i}\>" ${BASE_DIR}/version/cmsfile_MD5_three-${FUFFIX} |sort;
done > ${BASE_DIR}/version/difftest-cmsfile_MD5_three-${FUFFIX}
echo "<a href="${CURL_URL}/version/difftest-cmsfile_MD5_three-${FUFFIX}">查看异常单机CMS1.0 tm_dispatch文件MD5值列表</a> &nbsp;&nbsp; <a href="${CURL_URL}/version/cmsfile_MD5_three-${FUFFIX}">查看所有单机CMS1.0 tm_dispatch文件MD5值列表</a>"
echo "============================"
}



#translate txt to html
function translate_txt_to_html(){
cd ${BASE_DIR}/html
sed 's/$/<br \/>/g' ${TXT_FILE} >${HTML_FILE}
sed -i 's/<\/tr><br \/>/<\/tr>/g' ${HTML_FILE}
echo "<style type=\"\"text/css>body {  font-size: 12px;  font-family: \"Microsoft YaHei\";}</style>" >> ${HTML_FILE}
mail -s "$(echo -e "HPCC daily report $(date +"%Y-%m-%d")\nContent-Type: text/html")" ${noticemail} -- -f xunjian@rong.chen.hpcc < ${HTML_FILE}
echo "=====END.$(date +"%Y-%m-%d %H:%M")====="
}

main
