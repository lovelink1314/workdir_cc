#! /bin/sh

#
# crontab -e
# 0 0 * * * sh userhome/hpccstat.sh -p60 -d1440 > /dev/null 2>&1 
#

hpccstat_version="version: 20171120 1630.rt.channels"
period_second=1
duration_minute=1
output_file_dir="/data/proclog/log/hpccstat"
output_file=$output_file_dir/`hostname`_`date +%Y%m%d%H%M%S`.csv
inc_output_dir="/data/proclog/log/hpccstat/rthpccstat"
inc_output_file="${inc_output_dir}/hpccstat.csv"
ats_access_log="/data/proclog/log/ccts/ccts.log"
hpc_access_log="/data/proclog/log/hpc/access.log"
hpc_access_debug_normal_log="/data/proclog/log/hpc/access_debug.log"
hpc_access_debug_mansubi_log="/data/proclog/log/hpc/flexi_rcpt_mansubi/access_debug.log"
hpc_localcache_path="/tmp/sock/memc.sock"
channels="vhotlx.video.qq.com ltslx.qq.com"

INFO_LIST_HOSTNAME=0
INFO_LIST_DATE=1
INFO_LIST_LOADAVG=2
INFO_LIST_CPU=3
INFO_LIST_MEM=4
INFO_LIST_BAND=5
INFO_LIST_SOCK=6
INFO_LIST_LOCALCACHE=7
INFO_LIST_ATS=8
INFO_LIST_HPC_TIME=9
INFO_LIST_NGINX=10
INFO_LIST_HPC=11
INFO_LIST_TCP=12


function usage()
{
    cat <<-END >&2
USAGE: hpccstat.sh [-h] [-v] [-p seconds] [-d mintues] [-o output]
        -h                          # show usage message
        -v                          # show version
        -p seconds                  # set sampling period, default to 1 second
        -d mintues                  # set sampling mintues, default to 1 mintue
        -o output                   # set output file used to store sample, default to $output_file_dir/*.csv
eg,
    sh hpccstat.sh -p 5 -d 10       # sample once every 5 seconds, for 10 mintues
END
    exit
}

function version()
{
    echo "$hpccstat_version"
    exit
}

function get_hostname_info()
{
    info_hostname=$info_hostname_format

    #echo "info_hostname=$info_hostname"

    info_list[$INFO_LIST_HOSTNAME]=$info_hostname
}

function get_date_info()
{
    info_date_format01=`date +%Y-%m-%d,%H:%M:%S`
    info_date_format02=`echo $info_date_format01 | tr ',' ' '`

    info_date="$info_date_format01,$info_date_format02"

    echo "info_date=$info_date"
    info_list[$INFO_LIST_DATE]=$info_date
    info_date=`date +%Y-%m-%d,%H:%M:%S`
}

function get_loadavg_info()
{
    info_loadavg=`cat /proc/loadavg | awk '{print $1}'`

    info_list[$INFO_LIST_LOADAVG]=$info_loadavg
}

function get_cpu_info_one_cpu()
{
    local sample_index=$1;shift
    local cpu_id=$1
    local cpu_info=`cat /proc/stat | grep cpu | awk '
    BEGIN{
        cpu_total = 0;
        cpu_user = 0;
        cpu_sys = 0;
        cpu_idle = 0;
        cpu_iowait = 0;
        cpu_irq = 0;
        cpu_softirq = 0;
    }
    {
        if ( $1 ~ /cpu'$cpu_id'/)
        {
            cpu_total = $2 + $3 + $4 + $5 + $6 + $7 + $8 + $9
            cpu_user = $2 + $3
            cpu_sys = $4
            cpu_idle = $5
            cpu_iowait = $6
            cpu_irq = $7
            cpu_softirq = $8
        }
    }
    END{printf("%ld %ld %ld %ld %ld %ld %ld\n", cpu_total, cpu_user, cpu_sys, cpu_idle, cpu_iowait, cpu_irq, cpu_softirq);}'`

    local curr_cpu_total=`echo $cpu_info | awk '{print $1}'`
    local curr_cpu_user=`echo $cpu_info | awk '{print $2}'`
    local curr_cpu_sys=`echo $cpu_info | awk '{print $3}'`
    local curr_cpu_idle=`echo $cpu_info | awk '{print $4}'`
    local curr_cpu_iowait=`echo $cpu_info | awk '{print $5}'`
    local curr_cpu_irq=`echo $cpu_info | awk '{print $6}'`
    local curr_cpu_softirq=`echo $cpu_info | awk '{print $7}'`

    if [ "$sample_index" = "0" ]; then
        info_cpu_one="0,0,0,0,0,0"
    else
        if [ ! -z $cpu_id ];then
            prev_cpu_total=prev_cpu_total_array[$cpu_id]
            prev_cpu_user=prev_cpu_user_array[$cpu_id]
            prev_cpu_sys=prev_cpu_sys_array[$cpu_id]
            prev_cpu_idle=prev_cpu_idle_array[$cpu_id]
            prev_cpu_iowait=prev_cpu_iowait_array[$cpu_id]
            prev_cpu_irq=prev_cpu_irq_array[$cpu_id]
            prev_cpu_softirq=prev_cpu_softirq_array[$cpu_id]
        fi
        
        local interval_cpu_total=$[curr_cpu_total-prev_cpu_total]
        local interval_cpu_user=$[curr_cpu_user-prev_cpu_user]
        local interval_cpu_sys=$[curr_cpu_sys-prev_cpu_sys]
        local interval_cpu_idle=$[curr_cpu_idle-prev_cpu_idle]
        local interval_cpu_iowait=$[curr_cpu_iowait-prev_cpu_iowait]
        local interval_cpu_irq=$[curr_cpu_irq-prev_cpu_irq]
        local interval_cpu_softirq=$[curr_cpu_softirq-prev_cpu_softirq]

        local cpu_user=`echo "scale=2; $interval_cpu_user/$interval_cpu_total*100" | bc`
        local cpu_sys=`echo "scale=2; $interval_cpu_sys/$interval_cpu_total*100" | bc`
        local cpu_idle=`echo "scale=2; $interval_cpu_idle/$interval_cpu_total*100" | bc`
        local cpu_iowait=`echo "scale=2; $interval_cpu_iowait/$interval_cpu_total*100" | bc`
        local cpu_irq=`echo "scale=2; $interval_cpu_irq/$interval_cpu_total*100" | bc`
        local cpu_softirq=`echo "scale=2; $interval_cpu_softirq/$interval_cpu_total*100" | bc`

        info_cpu_one=$cpu_user","$cpu_sys","$cpu_idle","$cpu_iowait","$cpu_irq","$cpu_softirq
    fi
    
    if [ -z $cpu_id ];then
        prev_cpu_total=$curr_cpu_total
        prev_cpu_user=$curr_cpu_user
        prev_cpu_sys=$curr_cpu_sys
        prev_cpu_idle=$curr_cpu_idle
        prev_cpu_iowait=$curr_cpu_iowait
        prev_cpu_irq=$curr_cpu_irq
        prev_cpu_softirq=$curr_cpu_softirq
    else
        prev_cpu_total_array[$cpu_id]=$curr_cpu_total
        prev_cpu_user_array[$cpu_id]=$curr_cpu_user
        prev_cpu_sys_array[$cpu_id]=$curr_cpu_sys
        prev_cpu_idle_array[$cpu_id]=$curr_cpu_idle
        prev_cpu_iowait_array[$cpu_id]=$curr_cpu_iowait
        prev_cpu_irq_array[$cpu_id]=$curr_cpu_irq
        prev_cpu_softirq_array[$cpu_id]=$curr_cpu_softirq
    fi
}

function get_cpu_info()
{
    local sample_index=$1;shift
    local cpu_last_id=$[$(cat /proc/stat | grep cpu | wc -l)-2]
    get_cpu_info_one_cpu $sample_index
    info_cpu=$info_cpu_one
    for id in $(seq 0 $cpu_last_id);do
        get_cpu_info_one_cpu $sample_index $id
        info_cpu=$info_cpu","$info_cpu_one
    done
    info_list[$INFO_LIST_CPU]=$info_cpu
}

function get_mem_info()
{
    info_mem=`free | grep Mem | awk '{print $4","$6","$7}'`
    info_list[$INFO_LIST_MEM]=$info_mem
}

function get_band_info()
{
    band_info_start=`date +%s`
    band_info=`cat /proc/net/dev | grep "bond" | tr ':' ' ' | awk '{print $1" "$2" "$10}'`
    #echo "$band_info"
    
    if [ "$net_dev_name" = "bond0" ]; then
        curr_bond0_recv_bytes=`echo $band_info | awk '{print $2}'`
        curr_bond1_recv_bytes=`echo $band_info | awk '{print $5}'`
        curr_bond0_sent_bytes=`echo $band_info | awk '{print $3}'`
        curr_bond1_sent_bytes=`echo $band_info | awk '{print $6}'`
    else
        curr_bond1_recv_bytes=`echo $band_info | awk '{print $2}'`
        curr_bond0_recv_bytes=`echo $band_info | awk '{print $5}'`
        curr_bond1_sent_bytes=`echo $band_info | awk '{print $3}'`
        curr_bond0_sent_bytes=`echo $band_info | awk '{print $6}'`
    fi

    if [ "$1" = "0" ]; then
        info_band="0,0,0,0"
    else
        interval_bond0_recv_bytes=$[curr_bond0_recv_bytes-prev_bond0_recv_bytes]
        interval_bond1_recv_bytes=$[curr_bond1_recv_bytes-prev_bond1_recv_bytes]
        interval_bond0_sent_bytes=$[curr_bond0_sent_bytes-prev_bond0_sent_bytes]
        interval_bond1_sent_bytes=$[curr_bond1_sent_bytes-prev_bond1_sent_bytes]
        band_info_period_second=$[band_info_start-prev_band_info_start]
        #echo "band_info_period_second=$band_info_period_second"
 
        bond0_recv=`echo "scale=2; $interval_bond0_recv_bytes/$band_info_period_second/1024/1024*8" | bc`
        bond1_recv=`echo "scale=2; $interval_bond1_recv_bytes/$band_info_period_second/1024/1024*8" | bc`
        bond0_sent=`echo "scale=2; $interval_bond0_sent_bytes/$band_info_period_second/1024/1024*8" | bc`
        bond1_sent=`echo "scale=2; $interval_bond1_sent_bytes/$band_info_period_second/1024/1024*8" | bc`

        info_band=$bond0_recv","$bond1_recv","$bond0_sent","$bond1_sent
    fi

    prev_band_info_start=$band_info_start
    prev_bond0_recv_bytes=$curr_bond0_recv_bytes
    prev_bond1_recv_bytes=$curr_bond1_recv_bytes
    prev_bond0_sent_bytes=$curr_bond0_sent_bytes
    prev_bond1_sent_bytes=$curr_bond1_sent_bytes
    
    #echo "info_band=$info_band"

    info_list[$INFO_LIST_BAND]=$info_band
}

function get_tcp_info()
{
    tcp_info=`/usr/sbin/nstat -z | egrep "TcpPassiveOpens|TcpActiveOpens|TCPTimeouts|TcpOutSegs|TcpRetransSegs" | 
              awk '{print $1" "$2}'`
    #echo $tcp_info

    info_tcp=`echo $tcp_info | awk '{print $2","$4","$8/($6+$8)*100","$10}'`
    
    #echo "info_tcp=$info_tcp"
    info_list[$INFO_LIST_TCP]=$info_tcp
}

function get_ats_info()
{
    ats_start=`date +%Y-%m-%d" "%H:%M:%S.%N -d "-$period_second second"`
    ats_start_stamp=`date -d "$ats_start" +%s.%N`

    if [ -f "$ats_access_log" ]; then
        info_ats=`tac $ats_access_log | awk -v start="$ats_start_stamp" -v host="$info_hostname_host" -v bond1="$bond1_ip" '
        BEGIN{
          ats_all_count = 0
          ats_head_count = 0
          ats_head_miss_count = 0
          ats_head_hit_count = 0
          ats_head_hit_ssd_count = 0
          ats_head_hit_mem_count = 0
          
          ats_get_count = 0
          ats_get_bytes = 0
          ats_get_times = 0
          ats_get_per_byte = 0
          ats_get_per_time = 0
          ats_get_ssd_count = 0
          ats_get_ssd_bytes = 0
          ats_get_ssd_times = 0
          ats_get_ssd_per_byte = 0
          ats_get_ssd_per_time = 0
          ats_get_mem_count = 0
          ats_get_mem_bytes = 0
          ats_get_mem_times = 0
          ats_get_mem_per_byte = 0
          ats_get_mem_per_time = 0
          ats_get_disk_count = 0
          ats_get_disk_bytes = 0
          ats_get_disk_times = 0
          ats_get_disk_per_byte = 0
          ats_get_disk_per_time = 0
          ats_get_miss_count = 0
          ats_get_miss_bytes = 0
          ats_get_miss_times = 0
          ats_get_miss_per_byte = 0
          ats_get_miss_per_time = 0
          
          ats_get_local_count = 0
          ats_get_local_bytes = 0
          ats_get_local_times = 0
          ats_get_local_per_byte = 0
          ats_get_local_per_time = 0
          ats_get_local_ssd_count = 0
          ats_get_local_ssd_bytes = 0
          ats_get_local_ssd_times = 0
          ats_get_local_ssd_per_byte = 0
          ats_get_local_ssd_per_time = 0
          ats_get_local_mem_count = 0
          ats_get_local_mem_bytes = 0
          ats_get_local_mem_times = 0
          ats_get_local_mem_per_byte = 0
          ats_get_local_mem_per_time = 0
          ats_get_local_disk_count = 0
          ats_get_local_disk_bytes = 0
          ats_get_local_disk_times = 0
          ats_get_local_disk_per_byte = 0
          ats_get_local_disk_per_time = 0
          ats_get_local_miss_count = 0
          ats_get_local_miss_bytes = 0
          ats_get_local_miss_times = 0
          ats_get_local_miss_per_byte = 0
          ats_get_local_miss_per_time = 0
          
          ats_get_remote_count = 0
          ats_get_remote_bytes = 0
          ats_get_remote_times = 0
          ats_get_remote_per_byte = 0
          ats_get_remote_per_time = 0
          ats_get_remote_ssd_count = 0
          ats_get_remote_ssd_bytes = 0
          ats_get_remote_ssd_times = 0
          ats_get_remote_ssd_per_byte = 0
          ats_get_remote_ssd_per_time = 0
          ats_get_remote_mem_count = 0
          ats_get_remote_mem_bytes = 0
          ats_get_remote_mem_times = 0
          ats_get_remote_mem_per_byte = 0
          ats_get_remote_mem_per_time = 0
          ats_get_remote_disk_count = 0
          ats_get_remote_disk_bytes = 0
          ats_get_remote_disk_times = 0
          ats_get_remote_disk_per_byte = 0
          ats_get_remote_disk_per_time = 0
          ats_get_remote_miss_count = 0
          ats_get_remote_miss_bytes = 0
          ats_get_remote_miss_times = 0
          ats_get_remote_miss_per_byte = 0
          ats_get_remote_miss_per_time = 0
          
          ats_put_count = 0
          ats_put_times = 0
          ats_put_per_time = 0
          ats_put_fail_count = 0
          ats_put_fail_times = 0
          ats_put_fail_per_time = 0
          ats_put_local_count = 0
          ats_put_local_times = 0
          ats_put_local_per_time = 0
          ats_put_remote_count = 0
          ats_put_remote_times = 0
          ats_put_remote_per_time = 0
          
          ats_get_timeout_count = 0
          ats_put_timeout_count = 0
        }
        {
          if ($1 > start)
          {
            ats_all_count += 1
            if ($7 ~ /HEAD/)
            {
              ats_head_count += 1
              if ($5 ~ /HIT_SSD/)
              {
                ats_head_hit_ssd_count += 1
              }
              else if ($5 ~ /HIT_RAM/)
              {
                ats_head_hit_mem_count += 1
              }
              else if ($5 ~ /HIT/)
              {
                ats_head_hit_count += 1
              }
              else if ($5 ~ /MISS/)
              {
                ats_head_miss_count += 1
              }
            }
            else if ($7 ~ /GET/)
            {
              ats_get_count += 1
              ats_get_bytes += $6
              ats_get_times += $2
              if ($2 > 2000)
              {
                ats_get_timeout_count += 1
              }
              if ($3 == host || $3 == bond1)
              {
                ats_get_local_count += 1
                ats_get_local_bytes += $6
                ats_get_local_times += $2
                if ($5 ~ /HIT_SSD/)
                {
                  ats_get_ssd_count += 1
                  ats_get_ssd_bytes += $6
                  ats_get_ssd_times += $2
                  
                  ats_get_local_ssd_count += 1
                  ats_get_local_ssd_bytes += $6
                  ats_get_local_ssd_times += $2
                }
                else if ($5 ~ /HIT_RAM/)
                {
                  ats_get_mem_count += 1
                  ats_get_mem_bytes += $6
                  ats_get_mem_times += $2
                  
                  ats_get_local_mem_count += 1
                  ats_get_local_mem_bytes += $6
                  ats_get_local_mem_times += $2
                }
                else if ($5 ~ /HIT/)
                {
                  ats_get_disk_count += 1
                  ats_get_disk_bytes += $6
                  ats_get_disk_times += $2
                  
                  ats_get_local_disk_count += 1
                  ats_get_local_disk_bytes += $6
                  ats_get_local_disk_times += $2
                }
                else if ($5 ~ /MISS/)
                {
                  ats_get_miss_count += 1
                  ats_get_miss_bytes += $6
                  ats_get_miss_times += $2
                  
                  ats_get_local_miss_count += 1
                  ats_get_local_miss_bytes += $6
                  ats_get_local_miss_times += $2
                }
              }
              else
              {
                ats_get_remote_count += 1
                ats_get_remote_bytes += $6
                ats_get_remote_times += $2
                if ($5 ~ /HIT_SSD/)
                {
                  ats_get_ssd_count += 1
                  ats_get_ssd_bytes += $6
                  ats_get_ssd_times += $2
                  
                  ats_get_remote_ssd_count += 1
                  ats_get_remote_ssd_bytes += $6
                  ats_get_remote_ssd_times += $2
                }
                else if ($5 ~ /HIT_RAM/)
                {
                  ats_get_mem_count += 1
                  ats_get_mem_bytes += $6
                  ats_get_mem_times += $2
                  
                  ats_get_remote_mem_count += 1
                  ats_get_remote_mem_bytes += $6
                  ats_get_remote_mem_times += $2
                }
                else if ($5 ~ /HIT/)
                {
                  ats_get_disk_count += 1
                  ats_get_disk_bytes += $6
                  ats_get_disk_times += $2
                  
                  ats_get_remote_disk_count += 1
                  ats_get_remote_disk_bytes += $6
                  ats_get_remote_disk_times += $2
                }
                else if ($5 ~ /MISS/)
                {
                  ats_get_miss_count += 1
                  ats_get_miss_bytes += $6
                  ats_get_miss_times += $2
                  
                  ats_get_remote_miss_count += 1
                  ats_get_remote_miss_bytes += $6
                  ats_get_remote_miss_times += $2
                }
              }
            }
            else if ($7 ~ /PUSH/)
            {
              ats_put_count += 1
              ats_put_times += $2
              if ($2 > 2000)
              {
                ats_put_timeout_count += 1
              }
              if ($3 == host || $3 == bond1)
              {
                if ($5 ~ /MISS/)
                {
                  ats_put_local_count += 1
                  ats_put_local_times += $2
                }
                else if ($5 ~ /MISS_ERROR/)
                {
                  ats_put_fail_count += 1
                  ats_put_fail_times += $2
                }
              }
              else
              {
                if ($5 ~ /MISS/)
                {
                  ats_put_remote_count += 1
                  ats_put_remote_times += $2
                }
                else if ($5 ~ /MISS_ERROR/)
                {
                  ats_put_fail_count += 1
                  ats_put_fail_times += $2
                }
              }
            }
          }
          else
          {
              exit
          }
        }
        END{
          ats_get_per_byte = ats_get_count == 0 ? 0 : ats_get_bytes/ats_get_count
          ats_get_per_time = ats_get_count == 0 ? 0 : ats_get_times/ats_get_count
          
          ats_get_ssd_per_byte = ats_get_ssd_count == 0 ? 0 : ats_get_ssd_bytes/ats_get_ssd_count
          ats_get_ssd_per_time = ats_get_ssd_count == 0 ? 0 : ats_get_ssd_times/ats_get_ssd_count
          
          ats_get_mem_per_byte = ats_get_mem_count == 0 ? 0 : ats_get_mem_bytes/ats_get_mem_count
          ats_get_mem_per_time = ats_get_mem_count == 0 ? 0 : ats_get_mem_times/ats_get_mem_count
          
          ats_get_disk_per_byte = ats_get_disk_count == 0 ? 0 : ats_get_disk_bytes/ats_get_disk_count
          ats_get_disk_per_time = ats_get_disk_count == 0 ? 0 : ats_get_disk_times/ats_get_disk_count
          
          ats_get_miss_per_byte = ats_get_miss_count == 0 ? 0 : ats_get_miss_bytes/ats_get_miss_count
          ats_get_miss_per_time = ats_get_miss_count == 0 ? 0 : ats_get_miss_times/ats_get_miss_count
          
          ats_get_local_per_byte = ats_get_local_count == 0 ? 0 : ats_get_local_bytes/ats_get_local_count
          ats_get_local_per_time = ats_get_local_count == 0 ? 0 : ats_get_local_times/ats_get_local_count
          
          ats_get_local_ssd_per_byte = ats_get_local_ssd_count == 0 ? 0 : ats_get_local_ssd_bytes/ats_get_local_ssd_count
          ats_get_local_ssd_per_time = ats_get_local_ssd_count == 0 ? 0 : ats_get_local_ssd_times/ats_get_local_ssd_count
          
          ats_get_local_mem_per_byte = ats_get_local_mem_count == 0 ? 0 : ats_get_local_mem_bytes/ats_get_local_mem_count
          ats_get_local_mem_per_time = ats_get_local_mem_count == 0 ? 0 : ats_get_local_mem_times/ats_get_local_mem_count
          
          ats_get_local_disk_per_byte = ats_get_local_disk_count == 0 ? 0 : ats_get_local_disk_bytes/ats_get_local_disk_count
          ats_get_local_disk_per_time = ats_get_local_disk_count == 0 ? 0 : ats_get_local_disk_times/ats_get_local_disk_count
          
          ats_get_local_miss_per_byte = ats_get_local_miss_count == 0 ? 0 : ats_get_local_miss_bytes/ats_get_local_miss_count
          ats_get_local_miss_per_time = ats_get_local_miss_count == 0 ? 0 : ats_get_local_miss_times/ats_get_local_miss_count
          
          ats_get_remote_per_byte = ats_get_remote_count == 0 ? 0 : ats_get_remote_bytes/ats_get_remote_count
          ats_get_remote_per_time = ats_get_remote_count == 0 ? 0 : ats_get_remote_times/ats_get_remote_count
          
          ats_get_remote_ssd_per_byte = ats_get_remote_ssd_count == 0 ? 0 : ats_get_remote_ssd_bytes/ats_get_remote_ssd_count
          ats_get_remote_ssd_per_time = ats_get_remote_ssd_count == 0 ? 0 : ats_get_remote_ssd_times/ats_get_remote_ssd_count
          
          ats_get_remote_mem_per_byte = ats_get_remote_mem_count == 0 ? 0 : ats_get_remote_mem_bytes/ats_get_remote_mem_count
          ats_get_remote_mem_per_time = ats_get_remote_mem_count == 0 ? 0 : ats_get_remote_mem_times/ats_get_remote_mem_count
          
          ats_get_remote_disk_per_byte = ats_get_remote_disk_count == 0 ? 0 : ats_get_remote_disk_bytes/ats_get_remote_disk_count
          ats_get_remote_disk_per_time = ats_get_remote_disk_count == 0 ? 0 : ats_get_remote_disk_times/ats_get_remote_disk_count
          
          ats_get_remote_miss_per_byte = ats_get_remote_miss_count == 0 ? 0 : ats_get_remote_miss_bytes/ats_get_remote_miss_count
          ats_get_remote_miss_per_time = ats_get_remote_miss_count == 0 ? 0 : ats_get_remote_miss_times/ats_get_remote_miss_count
          
          ats_get_ssd_hit_rate = ats_get_count == 0 ? 0 : ats_get_ssd_count/ats_get_count*100
          ats_get_mem_hit_rate = ats_get_count == 0 ? 0 : ats_get_mem_count/ats_get_count*100
          ats_get_disk_hit_rate = ats_get_count == 0 ? 0 : ats_get_disk_count/ats_get_count*100
          ats_get_miss_rate = ats_get_count == 0 ? 0 : ats_get_miss_count/ats_get_count*100
          
          ats_get_ssd_hit_byte_rate = ats_get_bytes == 0 ? 0 : ats_get_ssd_bytes/ats_get_bytes*100
          ats_get_mem_hit_byte_rate = ats_get_bytes == 0 ? 0 : ats_get_mem_bytes/ats_get_bytes*100
          ats_get_disk_hit_byte_rate = ats_get_bytes == 0 ? 0 : ats_get_disk_bytes/ats_get_bytes*100
          ats_get_miss_byte_rate = ats_get_bytes == 0 ? 0 : ats_get_miss_bytes/ats_get_bytes*100
          
          ats_put_per_time = ats_put_count == 0 ? 0 : ats_put_times/ats_put_count
          ats_put_fail_per_time = ats_put_fail_count == 0 ? 0 : ats_put_fail_times/ats_put_fail_count
          ats_put_local_per_time = ats_put_local_count == 0 ? 0 : ats_put_local_times/ats_put_local_count
          ats_put_remote_per_time = ats_put_remote_count == 0 ? 0 : ats_put_remote_times/ats_put_remote_count
          
          ats_get_timeout_rate = ats_get_count == 0 ? 0 : ats_get_timeout_count*100/ats_get_count
          ats_put_timeout_rate = ats_put_count == 0 ? 0 : ats_put_timeout_count*100/ats_put_count
          
          printf("%ld,", ats_all_count)
          printf("%ld,%ld,%ld,%ld,%ld,", ats_head_count, ats_head_hit_ssd_count, ats_head_hit_mem_count, ats_head_hit_count, ats_head_miss_count)
          
          printf("%ld,%ld,%f,%f,", ats_get_count, ats_get_bytes/1024/1024, ats_get_per_byte/1024, ats_get_per_time)
          printf("%ld,%ld,%f,%f,", ats_get_ssd_count, ats_get_ssd_bytes/1024/1024, ats_get_ssd_per_byte/1024, ats_get_ssd_per_time)
          printf("%ld,%ld,%f,%f,", ats_get_mem_count, ats_get_mem_bytes/1024/1024, ats_get_mem_per_byte/1024, ats_get_mem_per_time)
          printf("%ld,%ld,%f,%f,", ats_get_disk_count, ats_get_disk_bytes/1024/1024, ats_get_disk_per_byte/1024, ats_get_disk_per_time)
          printf("%ld,%ld,%f,%f,", ats_get_miss_count, ats_get_miss_bytes/1024/1024, ats_get_miss_per_byte/1024, ats_get_miss_per_time)
          
          printf("%f,%f,%f,%f,", ats_get_ssd_hit_rate, ats_get_mem_hit_rate, ats_get_disk_hit_rate, ats_get_miss_rate)
          printf("%f,%f,%f,%f,", ats_get_ssd_hit_byte_rate, ats_get_mem_hit_byte_rate, ats_get_disk_hit_byte_rate, ats_get_miss_byte_rate)
          
          printf("%ld,%ld,%f,%f,", ats_get_local_count, ats_get_local_bytes/1024/1024, ats_get_local_per_byte/1024, ats_get_local_per_time)
          printf("%ld,%ld,%f,%f,", ats_get_local_ssd_count, ats_get_local_ssd_bytes/1024/1024, ats_get_local_ssd_per_byte/1024, ats_get_local_ssd_per_time)
          printf("%ld,%ld,%f,%f,", ats_get_local_mem_count, ats_get_local_mem_bytes/1024/1024, ats_get_local_mem_per_byte/1024, ats_get_local_mem_per_time)
          printf("%ld,%ld,%f,%f,", ats_get_local_disk_count, ats_get_local_disk_bytes/1024/1024, ats_get_local_disk_per_byte/1024, ats_get_local_disk_per_time)
          printf("%ld,%ld,%f,%f,", ats_get_local_miss_count, ats_get_local_miss_bytes/1024/1024, ats_get_local_miss_per_byte/1024, ats_get_local_miss_per_time)
          
          printf("%ld,%ld,%f,%f,", ats_get_remote_count, ats_get_remote_bytes/1024/1024, ats_get_remote_per_byte/1024, ats_get_remote_per_time)
          printf("%ld,%ld,%f,%f,", ats_get_remote_ssd_count, ats_get_remote_ssd_bytes/1024/1024, ats_get_remote_ssd_per_byte/1024, ats_get_remote_ssd_per_time)
          printf("%ld,%ld,%f,%f,", ats_get_remote_mem_count, ats_get_remote_mem_bytes/1024/1024, ats_get_remote_mem_per_byte/1024, ats_get_remote_mem_per_time)
          printf("%ld,%ld,%f,%f,", ats_get_remote_disk_count, ats_get_remote_disk_bytes/1024/1024, ats_get_remote_disk_per_byte/1024, ats_get_remote_disk_per_time)
          printf("%ld,%ld,%f,%f,", ats_get_remote_miss_count, ats_get_remote_miss_bytes/1024/1024, ats_get_remote_miss_per_byte/1024, ats_get_remote_miss_per_time)
          
          printf("%ld,%f,", ats_put_count, ats_put_per_time)
          printf("%ld,%f,", ats_put_fail_count, ats_put_fail_per_time)
          printf("%ld,%f,", ats_put_local_count, ats_put_local_per_time)
          printf("%ld,%f,", ats_put_remote_count, ats_put_remote_per_time)
          
          printf("%ld,%f,", ats_get_timeout_count, ats_get_timeout_rate)
          printf("%ld,%f", ats_put_timeout_count, ats_put_timeout_rate)
          
        }'`
    else
      info_ats="0, 0,0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0"
    fi

    local info_ats_num=`echo $info_ats | tr ',' ' ' | awk '{print NF}'`
    local info_default_ats="0, 0,0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0"
    local info_default_ats_num=`echo $info_default_ats | tr ',' ' ' | awk '{print NF}'`

    if [ "$info_default_ats_num" != "$info_ats_num" ]; then
      info_ats=$info_default_ats
      echo "warning: set info_ats to default"
    fi

    #echo "info_ats=$info_ats"
    info_list[$INFO_LIST_ATS]=$info_ats
}

last_evictions=0
function get_localcache_info(){
  if [ ! -S "$hpc_localcache_path" ]; then
    info_localcache="0,0,0,0,0"
  else
    info_localcache=`echo "stats" | nc -U $hpc_localcache_path | awk '
    BEGIN{
      get_count = 0
      set_count = 0
      get_hits = 0
      get_misses = 0
      curr_items = 0
      evictions = 0
    }
    /.*cmd_get/{
      get_count = $3
    }
    /.*cmd_set/{
      set_count = $3
    }
    /.*get_hits/{
      get_hits = $3
    }
    /.*get_misses/{
      get_misses = $3
    }
    /.*curr_items/{
      curr_items = $3
    }
    /.*evictions/{
      evictions = $3
    }
    END{
      hits_rate = get_count == 0 ? 0 : get_hits*100/get_count
      printf("%ld,%ld,%.3f,%ld,%ld", get_count, get_hits, hits_rate, curr_items, evictions)
    }
    '`
  fi
  evictions=`echo "$info_localcache"|awk -F, '{print $5}'`
  cur_evictions=0
  [ $last_evictions -ne 0 ] && cur_evictions=$[evictions-last_evictions]
  info_localcache=${info_localcache%,*}
  info_localcache=${info_localcache}",$cur_evictions"
  #echo info_localcache $info_localcache
  info_list[$INFO_LIST_LOCALCACHE]=$info_localcache
}

#time_header：记录发送完成响应头时的request_time值；
#time_data_bef：记录开始发响应体的request_time值；
#time_256k：记录hpcc发送完成256k数据的request_time值。
#@##@(time_header=13 time_data=26 time_256k=61)
function get_hpc_time_info(){
  local hpc_start=`date +%Y-%m-%d" "%H:%M:%S.%N -d "-$period_second second"`
  local hpc_time_start_stamp=`date -d "$hpc_start" +%s.%N`

  if [ ! -f "$hpc_access_log" ] || [ "$hpc_access_debug_skip" = "1" ]; then
    hpc_time_info="0,0,0"
  else
    hpc_time_info=`tac $hpc_access_log | awk -v start="$hpc_time_start_stamp" '
    BEGIN{
      hpc_finish_header_time = 0
      hpc_start_body_time = 0
      hpc_finish_256k_time = 0
      hpc_finish_header_time_all = 0
      hpc_start_body_time_all = 0
      hpc_finish_256k_time_all = 0
      hpc_count = 0
    }
    {
      if ($1 > start)
      {
        if($(NF-2) ~ /.*time_header=.*/)
        {
          hpc_count += 1
          split($(NF-2),array,"=")
          hpc_finish_header_time_all += array[2]
        }
        if($(NF-1) ~ /.*time_data=.*/)
        {
          split($(NF-1),array,"=")
          hpc_start_body_time_all += array[2]
        }
        if($NF ~ /.*time_256k=.*/)
        {
          split($NF,array,"=")
          hpc_finish_256k_time_all += array[2]
        }
      }
    }
    END{
      hpc_finish_header_time = hpc_count == 0 ? 0 : hpc_finish_header_time_all/hpc_count
      hpc_start_body_time = hpc_count == 0 ? 0 : hpc_start_body_time_all/hpc_count
      hpc_finish_256k_time = hpc_count == 0 ? 0 : hpc_finish_256k_time_all/hpc_count
      
      printf("%.3f,%.3f,%.3f", 
              hpc_finish_header_time, hpc_start_body_time, 
              hpc_finish_256k_time)
    }'`
  fi
  info_list[$INFO_LIST_HPC_TIME]=$hpc_time_info
}

function get_nginx_info(){
  hpc_pid=`ps -ef | grep "/usr/local/hpc/sbin/nginx" | grep -v grep | awk '{print $2}'`
  if [ `echo "$hpc_pid" | wc -l` -eq 1 ];then
    nginx_info=`ps -eF | grep nginx | awk -v ppid="$hpc_pid" '
    BEGIN{
      hpc_all_worker_count = 0
      hpc_normal_worker_count = 0
      hpc_shutting_down_worker_count = 0
      hpc_all_worker_mem = 0
      hpc_normal_worker_mem = 0
      hpc_shutting_down_worker_mem = 0
    }
    {
      if($3 == ppid){
        hpc_all_worker_count += 1
        hpc_all_worker_mem += $6
        if ($NF ~ /down/)
        {
          hpc_shutting_down_worker_count += 1
          hpc_shutting_down_worker_mem += $6
        }
        else
        {
          hpc_normal_worker_count += 1
          hpc_normal_worker_mem += $6
        }
      }
    }
    END{
      printf("%ld,%ld,%ld,%.3f,%.3f,%.3f",
               hpc_all_worker_count, hpc_normal_worker_count, hpc_shutting_down_worker_count,
               hpc_all_worker_mem/1024., hpc_normal_worker_mem/1024., hpc_shutting_down_worker_mem/1024.);
    }'`
  else
    nginx_info="0,0,0,0,0,0"
  fi
  info_list[$INFO_LIST_NGINX]=$nginx_info
}

function get_hpc_info_channel()
{
  local channel=$1 search_info_hpc
  if [ -z $channel ];then
    search_info_hpc=$org_info_hpc
  else
    search_info_hpc=`echo "$org_info_hpc" | grep $channel`
  fi
  info_hpc_channel=`echo "$search_info_hpc" | awk -v start="$hpc_start_stamp" '
    BEGIN{
        hpc_all_count = 0
        hpc_all_bytes = 0
        hpc_all_request_times = 0
        hpc_all_request_times_avg = 0
        hpc_all_total_times = 0
        hpc_all_total_times_avg = 0
        hpc_all_client_times = 0
        hpc_all_client_times_avg = 0
        hpc_all_internal_times = 0 
        hpc_all_internal_times_avg = 0 
        hpc_all_first_send_times = 0
        hpc_all_first_send_times_avg = 0
        hpc_all_total_rate = 0
        hpc_all_client_rate = 0
        hpc_all_internal_rate = 0
        hpc_all_bytes_per_count = 0

        hpc_2XX_all_count = 0
        hpc_2XX_all_bytes = 0
        hpc_2XX_all_request_times = 0
        hpc_2XX_all_request_times_avg = 0
        hpc_2XX_all_total_times = 0
        hpc_2XX_all_total_times_avg = 0
        hpc_2XX_all_client_times = 0
        hpc_2XX_all_client_times_avg = 0
        hpc_2XX_all_internal_times = 0
        hpc_2XX_all_internal_times_avg = 0
        hpc_2XX_all_first_send_times = 0
        hpc_2XX_all_first_send_times_avg = 0
        hpc_2XX_all_total_rate = 0
        hpc_2XX_all_client_rate = 0
        hpc_2XX_all_internal_rate = 0
        hpc_2XX_all_bytes_per_count = 0

        hpc_2XX_hit_count = 0
        hpc_2XX_hit_bytes = 0
        hpc_2XX_hit_request_times = 0
        hpc_2XX_hit_request_times_avg = 0
        hpc_2XX_hit_total_times = 0
        hpc_2XX_hit_total_times_avg = 0
        hpc_2XX_hit_client_times = 0
        hpc_2XX_hit_client_times_avg = 0
        hpc_2XX_hit_internal_times = 0
        hpc_2XX_hit_internal_times_avg = 0
        hpc_2XX_hit_first_send_times = 0
        hpc_2XX_hit_first_send_times_avg = 0
        hpc_2XX_hit_total_rate = 0
        hpc_2XX_hit_client_rate = 0
        hpc_2XX_hit_internal_rate = 0
        hpc_2XX_hit_bytes_per_count = 0

        hpc_2XX_miss_count = 0
        hpc_2XX_miss_bytes = 0
        hpc_2XX_miss_request_times = 0
        hpc_2XX_miss_request_times_avg = 0
        hpc_2XX_miss_total_times = 0
        hpc_2XX_miss_total_times_avg = 0
        hpc_2XX_miss_client_times = 0
        hpc_2XX_miss_client_times_avg = 0
        hpc_2XX_miss_internal_times = 0
        hpc_2XX_miss_internal_times_avg = 0
        hpc_2XX_miss_first_send_times = 0
        hpc_2XX_miss_first_send_times_avg = 0
        hpc_2XX_miss_total_rate = 0
        hpc_2XX_miss_client_rate = 0
        hpc_2XX_miss_internal_rate = 0
        hpc_2XX_miss_bytes_per_count = 0

        hpc_2XX_pending_count = 0
        hpc_2XX_pending_bytes = 0
        hpc_2XX_pending_request_times = 0
        hpc_2XX_pending_request_times_avg = 0
        hpc_2XX_pending_total_times = 0
        hpc_2XX_pending_total_times_avg = 0
        hpc_2XX_pending_client_times = 0
        hpc_2XX_pending_client_times_avg = 0
        hpc_2XX_pending_internal_times = 0
        hpc_2XX_pending_internal_times_avg = 0
        hpc_2XX_pending_first_send_times = 0
        hpc_2XX_pending_first_send_times_avg = 0
        hpc_2XX_pending_total_rate = 0
        hpc_2XX_pending_client_rate = 0
        hpc_2XX_pending_internal_rate = 0
        hpc_2XX_pending_bytes_per_count = 0

        hpc_2XX_all_0_50KB_count = 0
        hpc_2XX_all_0_50KB_bytes = 0
        hpc_2XX_all_0_50KB_request_times = 0
        hpc_2XX_all_0_50KB_request_times_avg = 0
        hpc_2XX_all_0_50KB_total_times = 0
        hpc_2XX_all_0_50KB_total_times_avg = 0
        hpc_2XX_all_0_50KB_client_times = 0
        hpc_2XX_all_0_50KB_client_times_avg = 0
        hpc_2XX_all_0_50KB_internal_times = 0
        hpc_2XX_all_0_50KB_internal_times_avg = 0
        hpc_2XX_all_0_50KB_first_send_times = 0
        hpc_2XX_all_0_50KB_first_send_times_avg = 0
        hpc_2XX_all_0_50KB_total_rate = 0
        hpc_2XX_all_0_50KB_client_rate = 0
        hpc_2XX_all_0_50KB_internal_rate = 0
        hpc_2XX_all_0_50KB_bytes_per_count = 0

        hpc_2XX_all_50_256KB_count = 0
        hpc_2XX_all_50_256KB_bytes = 0
        hpc_2XX_all_50_256KB_request_times = 0
        hpc_2XX_all_50_256KB_request_times_avg = 0
        hpc_2XX_all_50_256KB_total_times = 0
        hpc_2XX_all_50_256KB_total_times_avg = 0
        hpc_2XX_all_50_256KB_client_times = 0
        hpc_2XX_all_50_256KB_client_times_avg = 0
        hpc_2XX_all_50_256KB_internal_times = 0
        hpc_2XX_all_50_256KB_internal_times_avg = 0
        hpc_2XX_all_50_256KB_first_send_times = 0
        hpc_2XX_all_50_256KB_first_send_times_avg = 0
        hpc_2XX_all_50_256KB_total_rate = 0
        hpc_2XX_all_50_256KB_client_rate = 0
        hpc_2XX_all_50_256KB_internal_rate = 0
        hpc_2XX_all_50_256KB_bytes_per_count = 0
        
        hpc_2XX_all_over_256KB_count = 0
        hpc_2XX_all_over_256KB_bytes = 0
        hpc_2XX_all_over_256KB_request_times = 0
        hpc_2XX_all_over_256KB_request_times_avg = 0
        hpc_2XX_all_over_256KB_total_times = 0
        hpc_2XX_all_over_256KB_total_times_avg = 0
        hpc_2XX_all_over_256KB_client_times = 0
        hpc_2XX_all_over_256KB_client_times_avg = 0
        hpc_2XX_all_over_256KB_internal_times = 0
        hpc_2XX_all_over_256KB_internal_times_avg = 0
        hpc_2XX_all_over_256KB_first_send_times = 0
        hpc_2XX_all_over_256KB_first_send_times_avg = 0
        hpc_2XX_all_over_256KB_total_rate = 0
        hpc_2XX_all_over_256KB_client_rate = 0
        hpc_2XX_all_over_256KB_internal_rate = 0
        hpc_2XX_all_over_256KB_bytes_per_count = 0

        hpc_404_all_count = 0
        hpc_404_all_bytes = 0
        hpc_404_all_request_times = 0

        hpc_other_all_count = 0
        hpc_other_all_bytes = 0
        hpc_other_all_request_times = 0
    }
    {
        if ($1 > start)
        {
            hpc_all_count += 1
            hpc_all_bytes += $5
            hpc_all_request_times += $2
            hpc_all_total_times += $15
            hpc_all_client_times += $14
            hpc_all_first_send_times += $16

            if ($4 ~ /200|206$/)
            {
                hpc_2XX_all_count += 1
                hpc_2XX_all_bytes += $5
                hpc_2XX_all_request_times += $2
                hpc_2XX_all_total_times += $15
                hpc_2XX_all_client_times += $14
                hpc_2XX_all_first_send_times += $16

                if ($4 ~ /TCP_HIT/)
                {
                    hpc_2XX_hit_count += 1
                    hpc_2XX_hit_bytes += $5
                    hpc_2XX_hit_request_times += $2
                    hpc_2XX_hit_total_times += $15
                    hpc_2XX_hit_client_times += $14
                    hpc_2XX_hit_first_send_times += $16
                }
                else if ($4 ~ /TCP_MISS/)
                {
                    hpc_2XX_miss_count += 1
                    hpc_2XX_miss_bytes += $5
                    hpc_2XX_miss_request_times += $2
                    hpc_2XX_miss_total_times += $15
                    hpc_2XX_miss_client_times += $14
                    hpc_2XX_miss_first_send_times += $16
                }
                else if ($4 ~ /TCP_PENDING/)
                {
                    hpc_2XX_pending_count += 1
                    hpc_2XX_pending_bytes += $5
                    hpc_2XX_pending_request_times += $2
                    hpc_2XX_pending_total_times += $15
                    hpc_2XX_pending_client_times += $14
                    hpc_2XX_pending_first_send_times += $16
                }

                if ($5 > 0 && $5 <= 51200)
                {
                    hpc_2XX_all_0_50KB_count += 1
                    hpc_2XX_all_0_50KB_bytes += $5
                    hpc_2XX_all_0_50KB_request_times += $2
                    hpc_2XX_all_0_50KB_total_times += $15
                    hpc_2XX_all_0_50KB_client_times += $14
                    hpc_2XX_all_0_50KB_first_send_times += $16
                }
                else if ($5 > 51200 && $5 <= 262144)
                {
                    hpc_2XX_all_50_256KB_count += 1
                    hpc_2XX_all_50_256KB_bytes += $5
                    hpc_2XX_all_50_256KB_request_times += $2
                    hpc_2XX_all_50_256KB_total_times += $15
                    hpc_2XX_all_50_256KB_client_times += $14
                    hpc_2XX_all_50_256KB_first_send_times += $16
                }
                else if ($5 > 262144)
                {
                    hpc_2XX_all_over_256KB_count += 1
                    hpc_2XX_all_over_256KB_bytes += $5
                    hpc_2XX_all_over_256KB_request_times += $2
                    hpc_2XX_all_over_256KB_total_times += $15
                    hpc_2XX_all_over_256KB_client_times += $14
                    hpc_2XX_all_over_256KB_first_send_times += $16
                }
            }
            else if ($4 ~ /404/)
            {
                hpc_404_all_count += 1
                hpc_404_all_bytes += $5
                hpc_404_all_request_times += $2
            }
            else
            {
                hpc_other_all_count += 1
                hpc_other_all_bytes += $5
                hpc_other_all_request_times += $2
            }
        }
        else
        {
            exit
        }
    }
    END{
        hpc_all_internal_times = hpc_all_total_times - hpc_all_client_times
        hpc_all_request_times_avg = hpc_all_count == 0 ? 0 : hpc_all_request_times/hpc_all_count
        hpc_all_total_times_avg = hpc_all_count == 0 ? 0 : hpc_all_total_times*1000/hpc_all_count
        hpc_all_client_times_avg = hpc_all_count == 0 ? 0 : hpc_all_client_times*1000/hpc_all_count
        hpc_all_internal_times_avg = hpc_all_count == 0 ? 0 : hpc_all_internal_times*1000/hpc_all_count
        hpc_all_first_send_times_avg = hpc_all_count == 0 ? 0 : hpc_all_first_send_times*1000/hpc_all_count
        hpc_all_total_rate = hpc_all_total_times == 0 ? 0 : hpc_all_bytes/hpc_all_total_times/1000
        hpc_all_client_rate = hpc_all_client_times == 0 ? 0 : hpc_all_bytes/hpc_all_client_times/1000
        hpc_all_internal_rate = hpc_all_internal_times == 0 ? 0 : hpc_all_bytes/hpc_all_internal_times/1000
        hpc_all_bytes_per_count = hpc_all_count == 0 ? 0 : hpc_all_bytes/1024/hpc_all_count

        hpc_2XX_all_internal_times = hpc_2XX_all_total_times - hpc_2XX_all_client_times
        hpc_2XX_all_request_times_avg = hpc_2XX_all_count == 0 ? 0 : hpc_2XX_all_request_times/hpc_2XX_all_count
        hpc_2XX_all_total_times_avg = hpc_2XX_all_count == 0 ? 0 : hpc_2XX_all_total_times*1000/hpc_2XX_all_count
        hpc_2XX_all_client_times_avg = hpc_2XX_all_count == 0 ? 0 : hpc_2XX_all_client_times*1000/hpc_2XX_all_count
        hpc_2XX_all_internal_times_avg = hpc_2XX_all_count == 0 ? 0 : hpc_2XX_all_internal_times*1000/hpc_2XX_all_count
        hpc_2XX_all_first_send_times_avg = hpc_2XX_all_count == 0 ? 0 : hpc_2XX_all_first_send_times*1000/hpc_2XX_all_count
        hpc_2XX_all_total_rate = hpc_2XX_all_total_times == 0 ? 0 : hpc_2XX_all_bytes/hpc_2XX_all_total_times/1000
        hpc_2XX_all_client_rate = hpc_2XX_all_client_times == 0 ? 0 : hpc_2XX_all_bytes/hpc_2XX_all_client_times/1000
        hpc_2XX_all_internal_rate = hpc_2XX_all_internal_times == 0 ? 0 : hpc_2XX_all_bytes/hpc_2XX_all_internal_times/1000
        hpc_2XX_all_bytes_per_count = hpc_2XX_all_count == 0 ? 0 : hpc_2XX_all_bytes/1024/hpc_2XX_all_count

        hpc_2XX_hit_internal_times = hpc_2XX_hit_total_times - hpc_2XX_hit_client_times
        hpc_2XX_hit_request_times_avg = hpc_2XX_hit_count == 0 ? 0 : hpc_2XX_hit_request_times/hpc_2XX_hit_count
        hpc_2XX_hit_total_times_avg = hpc_2XX_hit_count == 0 ? 0 : hpc_2XX_hit_total_times*1000/hpc_2XX_hit_count
        hpc_2XX_hit_client_times_avg = hpc_2XX_hit_count == 0 ? 0 : hpc_2XX_hit_client_times*1000/hpc_2XX_hit_count
        hpc_2XX_hit_internal_times_avg = hpc_2XX_hit_count == 0 ? 0 : hpc_2XX_hit_internal_times*1000/hpc_2XX_hit_count
        hpc_2XX_hit_first_send_times_avg = hpc_2XX_hit_count == 0 ? 0 : hpc_2XX_hit_first_send_times*1000/hpc_2XX_hit_count
        hpc_2XX_hit_total_rate = hpc_2XX_hit_total_times == 0 ? 0 : hpc_2XX_hit_bytes/hpc_2XX_hit_total_times/1000
        hpc_2XX_hit_client_rate = hpc_2XX_hit_client_times == 0 ? 0 : hpc_2XX_hit_bytes/hpc_2XX_hit_client_times/1000
        hpc_2XX_hit_internal_rate = hpc_2XX_hit_internal_times == 0 ? 0 : hpc_2XX_hit_bytes/hpc_2XX_hit_internal_times/1000
        hpc_2XX_hit_bytes_per_count = hpc_2XX_hit_count == 0 ? 0 : hpc_2XX_hit_bytes/1024/hpc_2XX_hit_count

        hpc_2XX_miss_internal_times = hpc_2XX_miss_total_times - hpc_2XX_miss_client_times
        hpc_2XX_miss_request_times_avg = hpc_2XX_miss_count == 0 ? 0 : hpc_2XX_miss_request_times/hpc_2XX_miss_count
        hpc_2XX_miss_total_times_avg = hpc_2XX_miss_count == 0 ? 0 : hpc_2XX_miss_total_times*1000/hpc_2XX_miss_count
        hpc_2XX_miss_client_times_avg = hpc_2XX_miss_count == 0 ? 0 : hpc_2XX_miss_client_times*1000/hpc_2XX_miss_count
        hpc_2XX_miss_internal_times_avg = hpc_2XX_miss_count == 0 ? 0 : hpc_2XX_miss_internal_times*1000/hpc_2XX_miss_count
        hpc_2XX_miss_first_send_times_avg = hpc_2XX_miss_count == 0 ? 0 : hpc_2XX_miss_first_send_times*1000/hpc_2XX_miss_count
        hpc_2XX_miss_total_rate = hpc_2XX_miss_total_times == 0 ? 0 : hpc_2XX_miss_bytes/hpc_2XX_miss_total_times/1000
        hpc_2XX_miss_client_rate = hpc_2XX_miss_client_times == 0 ? 0 : hpc_2XX_miss_bytes/hpc_2XX_miss_client_times/1000
        hpc_2XX_miss_internal_rate = hpc_2XX_miss_internal_times == 0 ? 0 : hpc_2XX_miss_bytes/hpc_2XX_miss_internal_times/1000
        hpc_2XX_miss_bytes_per_count = hpc_2XX_miss_count == 0 ? 0 : hpc_2XX_miss_bytes/1024/hpc_2XX_miss_count

        hpc_2XX_pending_internal_times = hpc_2XX_pending_total_times - hpc_2XX_pending_client_times
        hpc_2XX_pending_request_times_avg = hpc_2XX_pending_count == 0 ? 0 : hpc_2XX_pending_request_times/hpc_2XX_pending_count
        hpc_2XX_pending_total_times_avg = hpc_2XX_pending_count == 0 ? 0 : hpc_2XX_pending_total_times*1000/hpc_2XX_pending_count
        hpc_2XX_pending_client_times_avg = hpc_2XX_pending_count == 0 ? 0 : hpc_2XX_pending_client_times*1000/hpc_2XX_pending_count
        hpc_2XX_pending_internal_times_avg = hpc_2XX_pending_count == 0 ? 0 : hpc_2XX_pending_internal_times*1000/hpc_2XX_pending_count
        hpc_2XX_pending_first_send_times_avg = hpc_2XX_pending_count == 0 ? 0 : hpc_2XX_pending_first_send_times*1000/hpc_2XX_pending_count
        hpc_2XX_pending_total_rate = hpc_2XX_pending_total_times == 0 ? 0 : hpc_2XX_pending_bytes/hpc_2XX_pending_total_times/1000
        hpc_2XX_pending_client_rate = hpc_2XX_pending_client_times == 0 ? 0 : hpc_2XX_pending_bytes/hpc_2XX_pending_client_times/1000
        hpc_2XX_pending_internal_rate = hpc_2XX_pending_internal_times == 0 ? 0 : hpc_2XX_pending_bytes/hpc_2XX_pending_internal_times/1000
        hpc_2XX_pending_bytes_per_count = hpc_2XX_pending_count == 0 ? 0 : hpc_2XX_pending_bytes/1024/hpc_2XX_pending_count

        hpc_2XX_all_0_50KB_internal_times = hpc_2XX_all_0_50KB_total_times - hpc_2XX_all_0_50KB_client_times
        hpc_2XX_all_0_50KB_request_times_avg = hpc_2XX_all_0_50KB_count == 0 ? 0 : hpc_2XX_all_0_50KB_request_times/hpc_2XX_all_0_50KB_count
        hpc_2XX_all_0_50KB_total_times_avg = hpc_2XX_all_0_50KB_count == 0 ? 0 : hpc_2XX_all_0_50KB_total_times*1000/hpc_2XX_all_0_50KB_count
        hpc_2XX_all_0_50KB_client_times_avg = hpc_2XX_all_0_50KB_count == 0 ? 0 : hpc_2XX_all_0_50KB_client_times*1000/hpc_2XX_all_0_50KB_count
        hpc_2XX_all_0_50KB_internal_times_avg = hpc_2XX_all_0_50KB_count == 0 ? 0 : hpc_2XX_all_0_50KB_internal_times*1000/hpc_2XX_all_0_50KB_count
        hpc_2XX_all_0_50KB_first_send_times_avg = hpc_2XX_all_0_50KB_count == 0 ? 0 : hpc_2XX_all_0_50KB_first_send_times*1000/hpc_2XX_all_0_50KB_count
        hpc_2XX_all_0_50KB_total_rate = hpc_2XX_all_0_50KB_total_times == 0 ? 0 : hpc_2XX_all_0_50KB_bytes/hpc_2XX_all_0_50KB_total_times/1000
        hpc_2XX_all_0_50KB_client_rate = hpc_2XX_all_0_50KB_client_times == 0 ? 0 : hpc_2XX_all_0_50KB_bytes/hpc_2XX_all_0_50KB_client_times/1000
        hpc_2XX_all_0_50KB_internal_rate = hpc_2XX_all_0_50KB_internal_times == 0 ? 0 : hpc_2XX_all_0_50KB_bytes/hpc_2XX_all_0_50KB_internal_times/1000
        hpc_2XX_all_0_50KB_bytes_per_count = hpc_2XX_all_0_50KB_count == 0 ? 0 : hpc_2XX_all_0_50KB_bytes/1024/hpc_2XX_all_0_50KB_count
                   
        hpc_2XX_all_50_256KB_internal_times = hpc_2XX_all_50_256KB_total_times - hpc_2XX_all_50_256KB_client_times
        hpc_2XX_all_50_256KB_request_times_avg = hpc_2XX_all_50_256KB_count == 0 ? 0 : hpc_2XX_all_50_256KB_request_times/hpc_2XX_all_50_256KB_count
        hpc_2XX_all_50_256KB_total_times_avg = hpc_2XX_all_50_256KB_count == 0 ? 0 : hpc_2XX_all_50_256KB_total_times*1000/hpc_2XX_all_50_256KB_count
        hpc_2XX_all_50_256KB_client_times_avg = hpc_2XX_all_50_256KB_count == 0 ? 0 : hpc_2XX_all_50_256KB_client_times*1000/hpc_2XX_all_50_256KB_count
        hpc_2XX_all_50_256KB_internal_times_avg = hpc_2XX_all_50_256KB_count == 0 ? 0 : hpc_2XX_all_50_256KB_internal_times*1000/hpc_2XX_all_50_256KB_count
        hpc_2XX_all_50_256KB_first_send_times_avg = hpc_2XX_all_50_256KB_count == 0 ? 0 : hpc_2XX_all_50_256KB_first_send_times*1000/hpc_2XX_all_50_256KB_count
        hpc_2XX_all_50_256KB_total_rate = hpc_2XX_all_50_256KB_total_times == 0 ? 0 : hpc_2XX_all_50_256KB_bytes/hpc_2XX_all_50_256KB_total_times/1000
        hpc_2XX_all_50_256KB_client_rate = hpc_2XX_all_50_256KB_client_times == 0 ? 0 : hpc_2XX_all_50_256KB_bytes/hpc_2XX_all_50_256KB_client_times/1000
        hpc_2XX_all_50_256KB_internal_rate = hpc_2XX_all_50_256KB_internal_times == 0 ? 0 : hpc_2XX_all_50_256KB_bytes/hpc_2XX_all_50_256KB_internal_times/1000
        hpc_2XX_all_50_256KB_bytes_per_count = hpc_2XX_all_50_256KB_count == 0 ? 0 : hpc_2XX_all_50_256KB_bytes/1024/hpc_2XX_all_50_256KB_count
       
        hpc_2XX_all_over_256KB_internal_times = hpc_2XX_all_over_256KB_total_times - hpc_2XX_all_over_256KB_client_times
        hpc_2XX_all_over_256KB_request_times_avg = hpc_2XX_all_over_256KB_count == 0 ? 0 : hpc_2XX_all_over_256KB_request_times/hpc_2XX_all_over_256KB_count
        hpc_2XX_all_over_256KB_total_times_avg = hpc_2XX_all_over_256KB_count == 0 ? 0 : hpc_2XX_all_over_256KB_total_times*1000/hpc_2XX_all_over_256KB_count
        hpc_2XX_all_over_256KB_client_times_avg = hpc_2XX_all_over_256KB_count == 0 ? 0 : hpc_2XX_all_over_256KB_client_times*1000/hpc_2XX_all_over_256KB_count
        hpc_2XX_all_over_256KB_internal_times_avg = hpc_2XX_all_over_256KB_count == 0 ? 0 : hpc_2XX_all_over_256KB_internal_times*1000/hpc_2XX_all_over_256KB_count
        hpc_2XX_all_over_256KB_first_send_times_avg = hpc_2XX_all_over_256KB_count == 0 ? 0 : hpc_2XX_all_over_256KB_first_send_times*1000/hpc_2XX_all_over_256KB_count
        hpc_2XX_all_over_256KB_total_rate = hpc_2XX_all_over_256KB_total_times == 0 ? 0 : hpc_2XX_all_over_256KB_bytes/hpc_2XX_all_over_256KB_total_times/1000
        hpc_2XX_all_over_256KB_client_rate = hpc_2XX_all_over_256KB_client_times == 0 ? 0 : hpc_2XX_all_over_256KB_bytes/hpc_2XX_all_over_256KB_client_times/1000
        hpc_2XX_all_over_256KB_internal_rate = hpc_2XX_all_over_256KB_internal_times == 0 ? 0 : hpc_2XX_all_over_256KB_bytes/hpc_2XX_all_over_256KB_internal_times/1000
        hpc_2XX_all_over_256KB_bytes_per_count = hpc_2XX_all_over_256KB_count == 0 ? 0 : hpc_2XX_all_over_256KB_bytes/1024/hpc_2XX_all_over_256KB_count
      
        printf("%ld,%ld,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,", 
              hpc_all_count, hpc_all_bytes, 
              hpc_all_request_times, hpc_all_request_times_avg,
              hpc_all_total_times, hpc_all_total_times_avg,
              hpc_all_client_times, hpc_all_client_times_avg,
              hpc_all_internal_times, hpc_all_internal_times_avg,
              hpc_all_first_send_times, hpc_all_first_send_times_avg,
              hpc_all_total_rate, hpc_all_client_rate, hpc_all_internal_rate,
              hpc_all_bytes_per_count)

        printf("%ld,%ld,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,", 
              hpc_2XX_all_count, hpc_2XX_all_bytes, 
              hpc_2XX_all_request_times, hpc_2XX_all_request_times_avg,
              hpc_2XX_all_total_times, hpc_2XX_all_total_times_avg,
              hpc_2XX_all_client_times, hpc_2XX_all_client_times_avg,
              hpc_2XX_all_internal_times, hpc_2XX_all_internal_times_avg,
              hpc_2XX_all_first_send_times, hpc_2XX_all_first_send_times_avg,
              hpc_2XX_all_total_rate, hpc_2XX_all_client_rate, hpc_2XX_all_internal_rate,
              hpc_2XX_all_bytes_per_count)

        printf("%ld,%ld,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,", 
              hpc_2XX_hit_count, hpc_2XX_hit_bytes, 
              hpc_2XX_hit_request_times, hpc_2XX_hit_request_times_avg,
              hpc_2XX_hit_total_times, hpc_2XX_hit_total_times_avg,
              hpc_2XX_hit_client_times, hpc_2XX_hit_client_times_avg,
              hpc_2XX_hit_internal_times, hpc_2XX_hit_internal_times_avg,
              hpc_2XX_hit_first_send_times, hpc_2XX_hit_first_send_times_avg,
              hpc_2XX_hit_total_rate, hpc_2XX_hit_client_rate, hpc_2XX_hit_internal_rate,
              hpc_2XX_hit_bytes_per_count)

        printf("%ld,%ld,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,", 
              hpc_2XX_miss_count, hpc_2XX_miss_bytes, 
              hpc_2XX_miss_request_times, hpc_2XX_miss_request_times_avg,
              hpc_2XX_miss_total_times, hpc_2XX_miss_total_times_avg,
              hpc_2XX_miss_client_times, hpc_2XX_miss_client_times_avg,
              hpc_2XX_miss_internal_times, hpc_2XX_miss_internal_times_avg,
              hpc_2XX_miss_first_send_times, hpc_2XX_miss_first_send_times_avg,
              hpc_2XX_miss_total_rate, hpc_2XX_miss_client_rate, hpc_2XX_miss_internal_rate,
              hpc_2XX_miss_bytes_per_count)

        printf("%ld,%ld,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,", 
              hpc_2XX_pending_count, hpc_2XX_pending_bytes, 
              hpc_2XX_pending_request_times, hpc_2XX_pending_request_times_avg,
              hpc_2XX_pending_total_times, hpc_2XX_pending_total_times_avg,
              hpc_2XX_pending_client_times, hpc_2XX_pending_client_times_avg,
              hpc_2XX_pending_internal_times, hpc_2XX_pending_internal_times_avg,
              hpc_2XX_pending_first_send_times, hpc_2XX_pending_first_send_times_avg,
              hpc_2XX_pending_total_rate, hpc_2XX_pending_client_rate, hpc_2XX_pending_internal_rate,
              hpc_2XX_pending_bytes_per_count)

        printf("%ld,%ld,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,", 
               hpc_2XX_all_0_50KB_count, hpc_2XX_all_0_50KB_bytes, 
               hpc_2XX_all_0_50KB_request_times, hpc_2XX_all_0_50KB_request_times_avg,
               hpc_2XX_all_0_50KB_total_times, hpc_2XX_all_0_50KB_total_times_avg,
               hpc_2XX_all_0_50KB_client_times, hpc_2XX_all_0_50KB_client_times_avg,
               hpc_2XX_all_0_50KB_internal_times, hpc_2XX_all_0_50KB_internal_times_avg,
               hpc_2XX_all_0_50KB_first_send_times, hpc_2XX_all_0_50KB_first_send_times_avg,
               hpc_2XX_all_0_50KB_total_rate, hpc_2XX_all_0_50KB_client_rate, hpc_2XX_all_0_50KB_internal_rate,
               hpc_2XX_all_0_50KB_bytes_per_count)

        printf("%ld,%ld,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,", 
               hpc_2XX_all_50_256KB_count, hpc_2XX_all_50_256KB_bytes, 
               hpc_2XX_all_50_256KB_request_times, hpc_2XX_all_50_256KB_request_times_avg,
               hpc_2XX_all_50_256KB_total_times, hpc_2XX_all_50_256KB_total_times_avg,
               hpc_2XX_all_50_256KB_client_times, hpc_2XX_all_50_256KB_client_times_avg,
               hpc_2XX_all_50_256KB_internal_times, hpc_2XX_all_50_256KB_internal_times_avg,
               hpc_2XX_all_50_256KB_first_send_times, hpc_2XX_all_50_256KB_first_send_times_avg,
               hpc_2XX_all_50_256KB_total_rate, hpc_2XX_all_50_256KB_client_rate, hpc_2XX_all_50_256KB_internal_rate,
               hpc_2XX_all_50_256KB_bytes_per_count)

        printf("%ld,%ld,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,", 
               hpc_2XX_all_over_256KB_count, hpc_2XX_all_over_256KB_bytes, 
               hpc_2XX_all_over_256KB_request_times, hpc_2XX_all_over_256KB_request_times_avg,
               hpc_2XX_all_over_256KB_total_times, hpc_2XX_all_over_256KB_total_times_avg,
               hpc_2XX_all_over_256KB_client_times, hpc_2XX_all_over_256KB_client_times_avg,
               hpc_2XX_all_over_256KB_internal_times, hpc_2XX_all_over_256KB_internal_times_avg,
               hpc_2XX_all_over_256KB_first_send_times, hpc_2XX_all_over_256KB_first_send_times_avg,
               hpc_2XX_all_over_256KB_total_rate, hpc_2XX_all_over_256KB_client_rate, hpc_2XX_all_over_256KB_internal_rate,
               hpc_2XX_all_over_256KB_bytes_per_count)
        
        printf("%ld,%ld,%f,", hpc_404_all_count, hpc_404_all_bytes, hpc_404_all_request_times)
        printf("%ld,%ld,%f", hpc_other_all_count, hpc_other_all_bytes, hpc_other_all_request_times)
    }'`
}
#
# $14: $time_client    s
# $15: $time_content   s
# $16: $time_sta_first ms
#
function get_hpc_info()
{
    hpc_start=`date +%Y-%m-%d" "%H:%M:%S.%N -d "-$period_second second"`
    hpc_start_stamp=`date -d "$hpc_start" +%s.%N`

    if [ ! -f "$hpc_access_debug_log" ] || [ "$hpc_access_debug_skip" = "1" ]; then
        info_hpc_init="0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                  0,0,0,
                  0,0,0"
        info_hpc=$info_hpc_init
        for ch in $channels;do
            info_hpc=${info_hpc},${info_hpc_init}
        done
    else
        org_info_hpc=`tac $hpc_access_debug_log`
        get_hpc_info_channel
        info_hpc=$info_hpc_channel
        for ch in $channels;do
            get_hpc_info_channel $ch
            info_hpc=${info_hpc},${info_hpc_channel}
        done
    fi
    #echo "hpc info num: `echo $info_hpc | tr ',' ' ' | awk '{print NF}'`"

    #echo "info_hpc=$info_hpc"
    info_list[$INFO_LIST_HPC]=$info_hpc
}

function get_socket_info()
{
    info_socket=`$tools_ss -an | grep -e "ESTAB" -e "TIME-WAIT" | tr ':' ' ' | awk '
    BEGIN{
        all_curr_estab_count = 0;
        hpc_to_client_estab_count = 0;
        hpc_to_original_estab_count = 0;
        hpc_to_ats_estab_count = 0;

        all_curr_tw_count = 0;
        hpc_to_client_tw_count = 0;
        hpc_to_original_tw_count = 0;
        hpc_to_ats_tw_count = 0;
    }
    {
        if ($1 ~ /ESTAB/)
        {
            all_curr_estab_count += 1;
        }
        else if ($1 ~ /TIME-WAIT/)
        {
            all_curr_tw_count += 1;
        }

        if ($4 ~ /^'$vip'$/)
        {
            if ($1 ~ /ESTAB/)
            {
                hpc_to_client_estab_count += 1;
            }
            else if ($1 ~ /TIME-WAIT/)
            {
                hpc_to_client_tw_count += 1;
            }
        }
        else if ($4 ~ /^'$bond0_ip'$/)
        {
            if ($5 !~ /^80$|^22$/)
            {
                if ($1 ~ /ESTAB/)
                {
                    hpc_to_original_estab_count += 1;
                }
                else if ($1 ~ /TIME-WAIT/)
                {
                    hpc_to_original_tw_count += 1;
                }
            }
        }
        else if ($4 ~ /^'$bond1_ip'$/)
        {
            if ($7 ~ /^772$/)
            {
                if ($1 ~ /ESTAB/)
                {
                    hpc_to_ats_estab_count += 1;
                }
                else if ($1 ~ /TIME-WAIT/)
                {
                    hpc_to_ats_tw_count += 1;
                }
            }
        }
    }
    END{
        printf("%ld,%ld,%ld,%ld,",
               all_curr_estab_count, hpc_to_client_estab_count, hpc_to_original_estab_count, hpc_to_ats_estab_count);
        printf("%ld,%ld,%ld,%ld",
               all_curr_tw_count, hpc_to_client_tw_count, hpc_to_original_tw_count, hpc_to_ats_tw_count);
    }'`
    #echo "info_socket=$info_socket"
    info_list[$INFO_LIST_SOCK]="$info_socket"
}

function get_info_title()
{
    info_title_list[$INFO_LIST_HOSTNAME]="HOST_Op,HOST_Prov,HOST_City,HOST_Site,HOST_Hostname,Service_type"
    info_title_list[$INFO_LIST_DATE]="Date_Ymd,Date_HMS,Date"
    info_title_list[$INFO_LIST_LOADAVG]="LoadAVG"
    local cpu_last_id=$[$(cat /proc/stat | grep cpu | wc -l)-2]
    local cpu_title="CPU_User_%,CPU_Sys_%,CPU_Idle_%,CPU_IOWait_%,CPU_Irq_%,CPU_Softirq_%"
    for id in $(seq 0 $cpu_last_id);do
        cpu_title=$cpu_title",CPU${id}_User_%,CPU${id}_Sys_%,CPU${id}_Idle_%,CPU${id}_IOWait_%,CPU${id}_Irq_%,CPU${id}_Softirq_%"
    done
    info_title_list[$INFO_LIST_CPU]=$cpu_title
    info_title_list[$INFO_LIST_MEM]="MemFree_KB,MemBuffers_KB,MemCached_KB"
    info_title_list[$INFO_LIST_BAND]="Bond0_Recv_Mbps,Bond1_Recv_Mbps,Bond0_Sent_Mbps,Bond1_Sent_Mbps"
    info_title_list[$INFO_LIST_SOCK]="ALLCurrEstabConns,HPC2ClientEstabConns,HPC2OriginalEstabConns,HPC2ATSEstabConns,ALLCurrTIME-WAITConns,HPC2ClientTIME-WAITConns,HPC2OriginalTIME-WAITConns,HPC2ATSTIME-WAITConns"
    info_title_list[$INFO_LIST_TCP]="NewActiveConns,NewPassiveConns,TCPRetransRatio_%,TCPTimeouts"                                     
    info_title_list[$INFO_LIST_ATS]="ATS_ALL_COUNT,ATS_HEAD_COUNT,ATS_HEAD_HIT_SSD_COUNT,ATS_HEAD_HIT_MEM_COUNT,ATS_HEAD_HIT_DISK_COUNT,ATS_HEAD_MISS_COUNT,ATS_GET_COUNT,ATS_GET_BYTES_MB,ATS_GET_PER_BYTE_KB,ATS_GET_PER_TIME_MS,ATS_GET_SSD_COUNT,ATS_GET_SSD_BYTES_MB,ATS_GET_SSD_PER_BYTE_KB,ATS_GET_SSD_PER_TIME_MS,ATS_GET_MEM_COUNT,ATS_GET_MEM_BYTES_MB,ATS_GET_MEM_PER_BYTE_KB,ATS_GET_MEM_PER_TIME_MS,ATS_GET_DISK_COUNT,ATS_GET_DISK_BYTES_MB,ATS_GET_DISK_PER_BYTE_KB,ATS_GET_DISK_PER_TIME_MS,ATS_GET_MISS_COUNT,ATS_GET_MISS_BYTES_MB,ATS_GET_MISS_PER_BYTE_KB,ATS_GET_MISS_PER_TIME_MS,ATS_GET_SSD_HitRate_%,ATS_GET_MEM_HitRate_%,ATS_GET_DISK_HitRate_%,ATS_GET_MissRate_%,ATS_GET_SSD_Bytes_HitRate_%,ATS_GET_MEM_Bytes_HitRate_%,ATS_GET_DISK_Bytes_HitRate_%,ATS_GET_Bytes_MissRate_%,ATS_GET_LOCAL_COUNT,ATS_GET_LOCAL_BYTES_MB,ATS_GET_LOCAL_PER_BYTE_KB,ATS_GET_LOCAL_PER_TIME_MS,ATS_GET_LOCAL_SSD_COUNT,ATS_GET_LOCAL_SSD_BYTES_MB,ATS_GET_LOCAL_SSD_PER_BYTE_KB,ATS_GET_LOCAL_SSD_PER_TIME_MS,ATS_GET_LOCAL_MEM_COUNT,ATS_GET_LOCAL_MEM_BYTES_MB,ATS_GET_LOCAL_MEM_PER_BYTE_KB,ATS_GET_LOCAL_MEM_PER_TIME_MS,ATS_GET_LOCAL_DISK_COUNT,ATS_GET_LOCAL_DISK_BYTES_MB,ATS_GET_LOCAL_DISK_PER_BYTE_KB,ATS_GET_LOCAL_DISK_PER_TIME_MS,ATS_GET_LOCAL_MISS_COUNT,ATS_GET_LOCAL_MISS_BYTES_MB,ATS_GET_LOCAL_MISS_PER_BYTE_KB,ATS_GET_LOCAL_MISS_PER_TIME_MS,ATS_GET_REMOTE_COUNT,ATS_GET_REMOTE_BYTES_MB,ATS_GET_REMOTE_PER_BYTE_KB,ATS_GET_REMOTE_PER_TIME_MS,ATS_GET_REMOTE_SSD_COUNT,ATS_GET_REMOTE_SSD_BYTES_MB,ATS_GET_REMOTE_SSD_PER_BYTE_KB,ATS_GET_REMOTE_SSD_PER_TIME_MS,ATS_GET_REMOTE_MEM_COUNT,ATS_GET_REMOTE_MEM_BYTES_MB,ATS_GET_REMOTE_MEM_PER_BYTE_KB,ATS_GET_REMOTE_MEM_PER_TIME_MS,ATS_GET_REMOTE_DISK_COUNT,ATS_GET_REMOTE_DISK_BYTES_MB,ATS_GET_REMOTE_DISK_PER_BYTE_KB,ATS_GET_REMOTE_DISK_PER_TIME_MS,ATS_GET_REMOTE_MISS_COUNT,ATS_GET_REMOTE_MISS_BYTES_MB,ATS_GET_REMOTE_MISS_PER_BYTE_KB,ATS_GET_REMOTE_MISS_PER_TIME_MS,ATS_PUT_COUNT,ATS_PUT_PER_TIME_MS,ATS_PUT_FAIL_COUNT,ATS_PUT_FAIL_PER_TIME_MS,ATS_PUT_LOCAL_COUNT,ATS_PUT_LOCAL_PER_TIME_MS,ATS_PUT_REMOTE_COUNT,ATS_PUT_REMOTE_PER_TIME_MS,ATS_GET_TIMEOUT_COUNT, ATS_GET_TIMEOUT_RATE,ATS_PUT_TIMEOUT_COUNT, ATS_PUT_TIMEOUT_RATE"
    info_title_list[$INFO_LIST_LOCALCACHE]="HPC_LOCAL_CACHE_GET_COUNT, HPC_LOCAL_CACHE_GET_HITS_COUNT, HPC_LOCAL_CACHE_HITS_RATE_%, HPC_LOCAL_CACHE_CURR_ITEMS, HPC_LOCAL_CACHE_CURR_EVICTIONS"
    info_title_list[$INFO_LIST_HPC_TIME]="HPC_FINISH_HEADER_AVG_TIME_MS, HPC_START_BODY_AVG_TIME_MS,HPC_FINISH_256K_AVG_TIME_MS"
    info_title_list[$INFO_LIST_NGINX]="HPC_ALL_WORKER_COUNT, HPC_NORMAL_WORKER_COUNT, HPC_SHUTTING_DOWN_WORKER_COUNT,HPC_ALL_WORKER_MEM_MB, HPC_NORMAL_WORKER_MEM_MB, HPC_SHUTTING_DOWN_WORKER_MEM_MB"
    local hpc_org_title="HPC_All_Count,HPC_All_Bytes,HPC_All_ReqTimes_ms,HPC_All_ReqTimes_AVG_ms,HPC_All_TotalTimes_s,HPC_All_TotalTimes_AVG_ms,HPC_All_ClientTimes_s,HPC_All_ClientTimes_AVG_ms,HPC_All_InternalTimes_s,HPC_All_InternalTimes_AVG_ms,HPC_All_FirstSendTimes_s,HPC_All_FirstSendTimes_AVG_ms,HPC_All_TotalRate_KB/s,HPC_All_ClientRate_KB/s,HPC_All_InternalRate_KB/s,HPC_All_KBPerCount_KB/count,
                                     HPC_2XX_All_Count,HPC_2XX_All_Bytes,HPC_2XX_All_ReqTimes_ms,HPC_2XX_All_ReqTimes_AVG_ms,HPC_2XX_All_TotalTimes_s,HPC_2XX_All_TotalTimes_AVG_ms,HPC_2XX_All_ClientTimes_s,HPC_2XX_All_ClientTimes_AVG_ms,HPC_2XX_All_InternalTimes_s,HPC_2XX_All_InternalTimes_AVG_ms,HPC_2XX_All_FirstSendTimes_s,HPC_2XX_All_FirstSendTimes_AVG_ms,HPC_2XX_All_TotalRate_KB/s,HPC_2XX_All_ClientRate_KB/s,HPC_2XX_All_InternalRate_KB/s,HPC_2XX_All_KBPerCount_KB/count,
                                     HPC_2XX_Hit_Count,HPC_2XX_Hit_Bytes,HPC_2XX_Hit_ReqTimes_ms,HPC_2XX_Hit_ReqTimes_AVG_ms,HPC_2XX_Hit_TotalTimes_s,HPC_2XX_Hit_TotalTimes_AVG_ms,HPC_2XX_Hit_ClientTimes_s,HPC_2XX_Hit_ClientTimes_AVG_ms,HPC_2XX_Hit_InternalTimes_s,HPC_2XX_Hit_InternalTimes_AVG_ms,HPC_2XX_Hit_FirstSendTimes_s,HPC_2XX_Hit_FirstSendTimes_AVG_ms,HPC_2XX_Hit_TotalRate_KB/s,HPC_2XX_Hit_ClientRate_KB/s,HPC_2XX_Hit_InternalRate_KB/s,HPC_2XX_Hit_KBPerCount_KB/count,
                                     HPC_2XX_Miss_Count,HPC_2XX_Miss_Bytes,HPC_2XX_Miss_ReqTimes_ms,HPC_2XX_Miss_ReqTimes_AVG_ms,HPC_2XX_Miss_TotalTimes_s,HPC_2XX_Miss_TotalTimes_AVG_ms,HPC_2XX_Miss_ClientTimes_s,HPC_2XX_Miss_ClientTimes_AVG_ms,HPC_2XX_Miss_InternalTimes_s,HPC_2XX_Miss_InternalTimes_AVG_ms,HPC_2XX_Miss_FirstSendTimes_s,HPC_2XX_Miss_FirstSendTimes_AVG_ms,HPC_2XX_Miss_TotalRate_KB/s,HPC_2XX_Miss_ClientRate_KB/s,HPC_2XX_Miss_InternalRate_KB/s,HPC_2XX_Miss_KBPerCount_KB/count,
                                     HPC_2XX_Pending_Count,HPC_2XX_Pending_Bytes,HPC_2XX_Pending_ReqTimes_ms,HPC_2XX_Pending_ReqTimes_AVG_ms,HPC_2XX_Pending_TotalTimes_s,HPC_2XX_Pending_TotalTimes_AVG_ms,HPC_2XX_Pending_ClientTimes_s,HPC_2XX_Pending_ClientTimes_AVG_ms,HPC_2XX_Pending_InternalTimes_s,HPC_2XX_Pending_InternalTimes_AVG_ms,HPC_2XX_Pending_FirstSendTimes_s,HPC_2XX_Pending_FirstSendTimes_AVG_ms,HPC_2XX_Pending_TotalRate_KB/s,HPC_2XX_Pending_ClientRate_KB/s,HPC_2XX_Pending_InternalRate_KB/s,HPC_2XX_Pending_KBPerCount_KB/count,
                                     HPC_2XX_All_0_50KB_Count,HPC_2XX_All_0_50KB_Bytes,HPC_2XX_All_0_50KB_ReqTimes_ms,HPC_2XX_All_0_50KB_ReqTimes_AVG_ms,HPC_2XX_All_0_50KB_TotalTimes_s,HPC_2XX_All_0_50KB_TotalTimes_AVG_ms,HPC_2XX_All_0_50KB_ClientTimes_s,HPC_2XX_All_0_50KB_ClientTimes_AVG_ms,HPC_2XX_All_0_50KB_InternalTimes_s,HPC_2XX_All_0_50KB_InternalTimes_AVG_ms,HPC_2XX_All_0_50KB_FirstSendTimes_s,HPC_2XX_All_0_50KB_FirstSendTimes_AVG_ms,HPC_2XX_All_0_50KB_TotalRate_KB/s,HPC_2XX_All_0_50KB_ClientRate_KB/s,HPC_2XX_All_0_50KB_InternalRate_KB/s,HPC_2XX_All_0_50KB_KBPerCount_KB/count,
                                     HPC_2XX_All_50_256KB_Count,HPC_2XX_All_50_256KB_Bytes,HPC_2XX_All_50_256KB_ReqTimes_ms,HPC_2XX_All_50_256KB_ReqTimes_AVG_ms,HPC_2XX_All_50_256KB_TotalTimes_s,HPC_2XX_All_50_256KB_TotalTimes_AVG_ms,HPC_2XX_All_50_256KB_ClientTimes_s,HPC_2XX_All_50_256KB_ClientTimes_AVG_ms,HPC_2XX_All_50_256KB_InternalTimes_s,HPC_2XX_All_50_256KB_InternalTimes_AVG_ms,HPC_2XX_All_50_256KB_FirstSendTimes_s,HPC_2XX_All_50_256KB_FirstSendTimes_AVG_ms,HPC_2XX_All_50_256KB_TotalRate_KB/s,HPC_2XX_All_50_256KB_ClientRate_KB/s,HPC_2XX_All_50_256KB_InternalRate_KB/s,HPC_2XX_All_50_256KB_KBPerCount_KB/count,
                                     HPC_2XX_All_over_256KB_Count,HPC_2XX_All_over_256KB_Bytes,HPC_2XX_All_over_256KB_ReqTimes_ms,HPC_2XX_All_over_256KB_ReqTimes_AVG_ms,HPC_2XX_All_over_256KB_TotalTimes_s,HPC_2XX_All_over_256KB_TotalTimes_AVG_ms,HPC_2XX_All_over_256KB_ClientTimes_s,HPC_2XX_All_over_256KB_ClientTimes_AVG_ms,HPC_2XX_All_over_256KB_InternalTimes_s,HPC_2XX_All_over_256KB_InternalTimes_AVG_ms,HPC_2XX_All_over_256KB_FirstSendTimes_s,HPC_2XX_All_over_256KB_FirstSendTimes_AVG_ms,HPC_2XX_All_over_256KB_TotalRate_KB/s,HPC_2XX_All_over_256KB_ClientRate_KB/s,HPC_2XX_All_over_256KB_InternalRate_KB/s,HPC_2XX_All_over_256KB_KBPerCount_KB/count,
                                     HPC_404_All_Count,HPC_404_All_Bytes,HPC_404_All_ReqTimes_ms,HPC_Other_All_Count,HPC_Other_All_Bytes,HPC_Other_All_ReqTimes_ms"
    local hpc_title=$hpc_org_title
    for ch in $channels;do
        local prefix=`echo ${ch:0:5} | tr 'a-z' 'A-Z'`
        local title=`echo $hpc_org_title|awk -F',' -v prefix="$prefix" '{for(i=1;i<NF;i++)printf("%s_%s,",prefix,$i); printf("%s_%s",prefix,$NF)}'`
        hpc_title=${hpc_title},${title}
    done
    info_title_list[$INFO_LIST_HPC]=$hpc_title
    #echo "hpc title num: `echo $hpc_title | tr ',' ' ' | awk '{print NF}'`"

    for title_i in "${!info_title_list[@]}"; do
        info_title+="${info_title_list[$title_i]},"
    done

    echo $info_title > "$output_file"
    echo $info_title > /root/hpccstat/keys
}


function get_info_line()
{
    for line_i in "${!info_list[@]}"; do
        info_line+="${info_list[$line_i]},"
    done

    echo $info_line >> "$output_file"
    echo $info_line >> "$inc_output_file"
    
    info_line=''
}

function get_output()
{
    echo "total sample number: $sample_index"
    exit
}

function get_ready()
{
    if [ ! -d "$output_file_dir" ]; then
        mkdir -p $output_file_dir
    fi
    if [ ! -d "$inc_output_dir" ]; then
        mkdir -p $inc_output_dir
    fi
    >$inc_output_file

    get_info_title

    hpc_mansubi_log=`grep "flexi_rcpt_mansubi" /usr/local/hpc/conf/main.conf | wc -l`
    if [ "$hpc_mansubi_log" = 1 ];then
        hpc_access_debug_log=$hpc_access_debug_mansubi_log
    else
        hpc_access_debug_log=$hpc_access_debug_normal_log
    fi
    #hpc_access_debug_log=""
    #echo "hpc_access_debug_log=$hpc_access_debug_log"

    info_hostname_host=`hostname`
    info_hostname_op=`echo ${info_hostname_host:0:3}`
    info_hostname_city=`echo ${info_hostname_host:4:2}`
    info_hostname_prov=$info_hostname_city
    info_hostname_site=`echo ${info_hostname_host:0:8}`
    info_hostname_type="download"
    info_hostname_format="$info_hostname_op,$info_hostname_prov,$info_hostname_city,$info_hostname_site,$info_hostname_host,$info_hostname_type"
    #echo "info_hostname_format=$info_hostname_format"

    tools_nstat=/usr/sbin/nstat
    tools_ip=/sbin/ip
    tools_ifconfig=/sbin/ifconfig
    tools_ss=/usr/sbin/ss

    bond0_ip=`$tools_ifconfig bond0 | grep "inet addr" | tr ':' ' ' | awk '{print $3}'`
    bond1_ip=`$tools_ifconfig bond1 | grep "inet addr" | tr ':' ' ' | awk '{print $3}'`
    vip_list=`$tools_ip a | grep "lo:dr" | awk '{print $4}'`

    for vip in $vip_list; do
        online=`$tools_ss -an | grep "$vip" | wc -l`
        if [ "$online" -gt "0" ]; then
            break
        fi
    done
    
    net_dev_name=`cat /proc/net/dev | grep "bond" | tr ':' ' ' | awk '{print $1}' | head -n1`

    hpc_access_debug_skip="1"
    hpc_access_debug_version_target=(0 4 9 1)
    hpc_access_debug_version_index=0
    hpc_access_debug_version=`rpm -q HPC-LUA | tr '-' ' ' | awk '{print $3}' | tr '.' ' '`
    for hpc_access_debug_version_num in $hpc_access_debug_version; do
        if [ "$hpc_access_debug_version_num" -gt "${hpc_access_debug_version_target[$index]}" ]; then
            #echo "$hpc_access_debug_version_num, ${hpc_access_debug_version_target[$index]}"
            hpc_access_debug_skip="0"
            break
        elif [ "$hpc_access_debug_version_num" -lt "${hpc_access_debug_version_target[$index]}" ]; then
            hpc_access_debug_skip="1"
            break
        fi
    
        hpc_access_debug_version_index=$[$hpc_access_debug_version_index+1];
    done
    #echo "hpc_access_debug_skip=$hpc_access_debug_skip"

    trap get_output 1 2
    sample_number=$[duration_minute*60/period_second]

    printf "================================================================================\n"
    printf "start time:       %s\n"   "`date +%Y-%m-%d" "%T`"
    printf "period:           %lds\n" "$period_second"
    printf "duration:         %ldm\n" "$duration_minute"
    printf "sample number:    %ld\n"  "$sample_number"
    printf "output file:      %s\n"   "$output_file"
    printf "================================================================================\n"

    $tools_nstat -n
}

# start
while getopts "hvp:d:o:" opt
do
    case $opt in
    h)
        usage
    ;;
    v)
        version
    ;;
    p)
        period_second=$OPTARG
    ;;
    d)
        duration_minute=$OPTARG
    ;;
    o)
        output_file=$OPTARG
    ;;
    ?)
        usage
    ;;
    esac
done
shift $(( $OPTIND - 1 ))

if [ "$#" -gt "0" ]; then
    echo -e "\033[31m[ERROR] Invalid Parameter!\033[0m" 
    usage
    exit
fi

if [ `echo $period_second | bc` -le "0" ] || [ `echo $duration_minute | bc` -le "0" ]; then
    echo -e "\033[31m[ERROR] Invalid Parameter!\033[0m" 
    usage
    exit
fi

get_ready

for  (( sample_index = 0; sample_index < $sample_number; sample_index++ ))
do
    get_hostname_info
    get_date_info
    get_cpu_info $sample_index
    get_loadavg_info
    get_mem_info
    get_band_info $sample_index
    get_socket_info
    get_ats_info
    get_localcache_info
    get_hpc_time_info
    get_nginx_info
    get_hpc_info
    get_tcp_info

    get_info_line

    sleep $period_second
done

get_output
