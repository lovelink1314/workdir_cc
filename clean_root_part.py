#!/usr/bin/python

# Script for remove files which may cause rootfs full:
#    1, Storage API nginx temp file -> /usr/local/storage/storage_api/client_body_temp
#    2, Old detectorigin logs -> /var/log/chinacache/detectorigin.log.{4..7}
#    3, Old cms backup file -> /home/cms/bak/HPC

# Written by hao.feng@chinacache.com

import os
import sys
import time
import shutil


######download del################
tempfile_dir = "/data/proclog/hpc/logs/flexi_billing/incomming/"
if os.path.exists(tempfile_dir) and os.path.isdir(tempfile_dir):
    cmd='find /data/proclog/hpc/logs/flexi_billing/incomming/ -type f -ctime +4 -exec rm -rf {} \;'
    os.system(cmd)

######download del################
tempfile_dir = "/tmp/sta"
if os.path.exists(tempfile_dir) and os.path.isdir(tempfile_dir):
    cmd='rm -rf /tmp/sta/*'
    os.system(cmd)


## Delete Storage API Tempfiles ##
tempfile_dir = "/usr/local/storage/storage_api/client_body_temp/"
if os.path.exists(tempfile_dir) and os.path.isdir(tempfile_dir):
    for filename in os.listdir(tempfile_dir):
        filepath = os.path.join(tempfile_dir, filename)
        if os.path.isfile(filepath):
            print("Deleting %s" % filepath)
            os.remove(filepath)

## find /var/log/chinacache/ -ctime +2|grep -v preloader|xargs rm -rf
tempfile_dir = "/var/log/chinacache/"
if os.path.exists(tempfile_dir) and os.path.isdir(tempfile_dir):
    cmd='find /var/log/chinacache/ -ctime +2 -type f|grep -v preloader|xargs rm -rf'
    os.system(cmd)


## Delete detectorigin Logs ##
logdir = "/var/log/chinacache/"
logprefix = "/var/log/chinacache/detectorigin.log."
if os.path.exists(logdir) and os.path.isdir(logdir):
    for append_index in range(3, 8):
        logpath = os.path.join(logdir, logprefix + str(append_index))
        if os.path.isfile(logpath):
            print("Deleting %s" % logpath)
            os.remove(logpath)

## Delete /usr/local/storage/tfs_bin/nameserver/filequeue/oplogsync file ##
tempfile_dir = "/usr/local/storage/tfs_bin/nameserver/filequeue/oplogsync/"
count=0
if os.path.exists(tempfile_dir) and os.path.isdir(tempfile_dir):
    for root,dirs,files in os.walk(tempfile_dir):
        count=len(files)
    if count >= 500:
	cmd='find '+tempfile_dir+' -ctime +6 -type f|grep -v pid|xargs rm -rf'
        os.system(cmd)

##########CMS delete data
# del /opt/cms/data/data >2day data
tempfile_dir = "/opt/cms/data/tmpdata"
if os.path.exists(tempfile_dir) and os.path.isdir(tempfile_dir):
    if os.listdir(tempfile_dir):
        cmd1 = 'find /opt/cms/data/data -type f -ctime +7 |grep -v pid|xargs rm -rf'
        cmd2 = 'find /opt/cms/data/tmpdata/hpcc_chs/message_bak/ -type f -mtime +7 -exec rm -rf {} \;'
        cmd3 = 'find /opt/cms/data/rcv/ -type f -ctime +7 |grep -v pid|xargs rm -rf'
        os.system(cmd1)
        os.system(cmd2)
        os.system(cmd3)
    else:
        dis_list = os.listdir("/opt/cms/data")
        dis_list.remove("tmpdata")
        for dis in dis_list:
            cmd1 = 'find /opt/cms/data/%s/data -type f -ctime +7 |grep -v pid|xargs rm -rf' % dis
            cmd2 = 'find /opt/cms/data/%s/tmpdata/hpcc_chs/message_bak/ -type f -mtime +7 -exec rm -rf {} \;' % dis
            cmd3 = 'find /opt/cms/data/%s/rcv/ -type f -ctime +7 |grep -v pid|xargs rm -rf' % dis
            os.system(cmd1)
            os.system(cmd2)
            os.system(cmd3)
elif os.path.exists("/opt/cms/data"):
    dis_list = os.listdir("/opt/cms/data")
    for dis in dis_list:
        cmd1 = 'find /opt/cms/data/%s/data -type f -ctime +7 |grep -v pid|xargs rm -rf' % dis
        cmd2 = 'find /opt/cms/data/%s/tmpdata/hpcc_chs/message_bak/ -type f -mtime +7 -exec rm -rf {} \;' % dis
        cmd3 = 'find /opt/cms/data/%s/rcv/ -type f -ctime +7 |grep -v pid|xargs rm -rf' % dis
        os.system(cmd1)
        os.system(cmd2)
        os.system(cmd3)

cms3_dir = "/opt/cms3/data"
if os.path.exists(cms3_dir) and os.path.isdir(cms3_dir):
    dis = os.listdir(cms3_dir)
    for d in dis:
        cmd1 = "find %s/%s/bakdata/finaldata -type f -ctime +7 | xargs rm -rf" % (cms3_dir, d)
        cmd2 = "find %s/%s/bakdata/tmpdata -type f -ctime +7 | xargs rm -rf" % (cms3_dir, d)
        cmd3 = "find %s/%s/bakdata/data -type f -ctime +7 | xargs rm -rf" % (cms3_dir, d)
        cmd4 = "find %s/%s/rcvdata -type f -ctime +7 | xargs rm -rf" % (cms3_dir, d)
        os.system(cmd1)
        os.system(cmd2)
        os.system(cmd3)
        os.system(cmd4)

cms3_dispatch_dir = "/opt/cms3/proj/tm_dispatch/"
if os.path.exists(cms3_dispatch_dir) and os.path.isdir(cms3_dispatch_dir):
    dis = os.listdir(cms3_dispatch_dir)
    for d in dis:
        cmd = "find %s/%s/logs -type f -ctime +7 | xargs rm -f" % (cms3_dispatch_dir, d)
        #cmd = "find %s/%s/logs -type f -ctime +7 | xargs ls " % (cms3_dispatch_dir, d)
        os.system(cmd)


# del /usr/local/nginx/html/cms_conf >2day data
tempfile_dir = ["/usr/local/nginx/html/cms_conf", "/var/truck"]
for dir in tempfile_dir:
    if os.path.exists(dir) and os.path.isdir(dir):
        cmd='find %s -type f -ctime +7 | grep -vE "data|tmpdata|pid" | xargs rm -rf' % dir
        os.system(cmd)

# del /data/proclog/log/ >5day data
tempfile_dir = "/data/proclog/log/"
if os.path.exists(tempfile_dir) and os.path.isdir(tempfile_dir):
    cmd='find /data/proclog/log/ -path "/data/proclog/log/hpc/access" -prune -o -path "/data/proclog/log/refreshd" -prune -o -path "/data/proclog/log/hpc/cache" -prune -o -path "/data/proclog/log/hpc/billing" -prune -o -path "/data/proclog/log/hpc/folderflow/incoming/backup" -prune -o -type f -mtime +5 -not -name "*pid*" -not -name "diags.log" -print -exec rm -f {} \;'
    os.system(cmd)

# del /data/proclog/log/refreshd >1day data
tempfile_dir = "/data/proclog/log/refreshd"
if os.path.exists(tempfile_dir) and os.path.isdir(tempfile_dir):
    cmd='find /data/proclog/log/refreshd -name "*.gz" -type f -mtime +1 -exec rm -rf {} \;'
    os.system(cmd)

# del /data/proclog/log/hpc/folderflow/incoming/backup >10day data
tempfile_dir = "/data/proclog/log/hpc/folderflow/incoming/backup"
if os.path.exists(tempfile_dir) and os.path.isdir(tempfile_dir):
    cmd='find /data/proclog/log/hpc/folderflow/incoming/backup -type f -mtime +10 -exec rm -rf {} \;'
    os.system(cmd)

# del /data/proclog/log/hpc/billing >10day data
tempfile_dir = "/data/proclog/log/hpc/billing"
if os.path.exists(tempfile_dir) and os.path.isdir(tempfile_dir):
    cmd='find /data/proclog/log/hpc/billing -type f -mtime +10 -exec rm -rf {} \;'
    os.system(cmd)

# del /home/cms/bak/DETECT/ >10day data
tempfile_dir = "/home/cms/bak/DETECT/"
if os.path.exists(tempfile_dir) and os.path.isdir(tempfile_dir):
    cmd='find /home/cms/bak/DETECT/ -maxdepth 1 -type d -name "DETECT_*" -mtime +10 -exec rm -r {} \;'
    os.system(cmd)

# del /data/proclog/log/hpc/access >10day data
tempfile_dir = "/data/proclog/log/hpc/access"
if os.path.exists(tempfile_dir) and os.path.isdir(tempfile_dir):
    cmd='find /data/proclog/log/hpc/access -type f -mtime +13 -exec rm -rf {} \;'
    os.system(cmd)

# del /data/proclog/log/hpc/flexi_billing >30day data
tempfile_dir = "/data/proclog/log/hpc/flexi_billing"
if os.path.exists(tempfile_dir) and os.path.isdir(tempfile_dir):
    cmd='find /data/proclog/log/hpc/flexi_billing -type f -mtime +30 -exec rm -rf {} \;'
    os.system(cmd)

# del /home/cms/tmp/HPC >10day data
tempfile_dir = "/home/cms/tmp/HPC"
if os.path.exists(tempfile_dir) and os.path.isdir(tempfile_dir):
    cmd='find /home/cms/tmp/HPC -type f -name "*.tar.gz" -mtime +10 -exec rm -rf {} \;'
    os.system(cmd)

# del /home/cms/tmp/DETECT >10day data
tempfile_dir = "/home/cms/tmp/DETECT"
if os.path.exists(tempfile_dir) and os.path.isdir(tempfile_dir):
    cmd='find /home/cms/tmp/DETECT -type f -name "*.tar.gz" -mtime +10 -exec rm -rf {} \;'
    os.system(cmd)

# del /data/proclog/log/hpc/cache >10day data
tempfile_dir = "/data/proclog/log/hpc/cache"
if os.path.exists(tempfile_dir) and os.path.isdir(tempfile_dir):
    cmd='find /data/proclog/log/hpc/cache -type f -mtime +10 -exec rm -rf {} \;'
    os.system(cmd)
	
# del /data/proclog/log/ccts >1day data
tempfile_dir = "/data/proclog/log/ccts"
if os.path.exists(tempfile_dir) and os.path.isdir(tempfile_dir):
    cmd='find /data/proclog/log/ccts -name "*old" -type f -mtime +1 -exec rm -rf  {} \;'
    os.system(cmd)

# del /data/proclog/core_file 10 keep file
tempfile_dir = "/data/proclog/core_file"
if os.path.exists(tempfile_dir) and os.path.isdir(tempfile_dir):
    cmd='ls -tr /data/proclog/core_file/ |head -n -10 |xargs rm -rf'
    os.system(cmd)

## Delete CMS Backup Files ##
saved = {}
saved_list = []

target_dir = "/home/cms/bak/HPC/"

# Target Dir non-exists, just exit.
if not os.path.exists(target_dir) or not os.path.isdir(target_dir):
    print("CMS Backup dir %s not exists." % target_dir)
    sys.exit(1)

# one day is 86400 secs.
today_ts = time.mktime(time.strptime(time.strftime("%Y%m%d"), "%Y%m%d"))
deadline_ts = today_ts - 86400 * 5

# Scan into target dir.
for dirname in os.listdir(target_dir):

    # Filename error, skip them.
    parts = dirname.split("_")
    if len(parts) != 3:
        saved_list.append(dirname)
        continue
    prefix, day, hm = parts
    if prefix != "HPC":
        saved_list.append(dirname)
        continue

    # Newer than today, keep them.
    if time.mktime(time.strptime(day, "%Y%m%d")) == today_ts:
        saved_list.append(dirname)
        continue

    # Older than `deadline_ts`, delete them.
    if time.mktime(time.strptime(day, "%Y%m%d")) <= deadline_ts:
        remove_path = os.path.join(target_dir, dirname)
        print("%s Deleting %s" % (today_ts, remove_path))
        shutil.rmtree(remove_path)
	continue

    # Last 5 days, we keep last one of each day.
    try:
	current = day + saved[day]
	current_ts = time.mktime(time.strptime(current, "%Y%m%d%H%M"))
	if time.mktime(time.strptime(day + hm, "%Y%m%d%H%M")) > current_ts:
	    saved[day] = hm
    except KeyError:
	saved[day] = hm

# Deal with files which belong to last 5 days.
for day, hm in saved.items():
    saved_list.append("HPC_%s_%s" % (day, hm))
for dirname in os.listdir(target_dir):
    if dirname not in saved_list:
        remove_path = os.path.join(target_dir, dirname)
        print("%s Deleting %s" % (today_ts, remove_path))
        shutil.rmtree(remove_path)

#bakup 
cmd='cp -r $(ls -d /home/cms/bak/HPC/HPC_$(date +%Y%m%d)*|sort -r|head -n 1) /pre_ops_hpcc/bakup/HPC'
tempfile_dir = "/pre_ops_hpcc/bakup/HPC"
if not os.path.exists(tempfile_dir) and not os.path.isdir(tempfile_dir):
	os.system('mkdir -p /pre_ops_hpcc/bakup/HPC')
if os.path.exists(tempfile_dir) and os.path.isdir(tempfile_dir):
        os.system('rm -rf /pre_ops_hpcc/bakup/HPC')
os.system(cmd)
# for dirname in saved_list:
#     keep_path = os.path.join(target_dir, dirname)
#     print("Keep -> %s" % keep_path)
