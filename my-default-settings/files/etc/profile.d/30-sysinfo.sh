#!/bin/bash

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LANG=zh_CN.UTF-8

THIS_SCRIPT="sysinfo"
MOTD_DISABLE=""

SHOW_IP_PATTERN="^[ewr].*|^br.*|^lt.*|^umts.*"

DATA_STORAGE=/userdisk/data
MEDIA_STORAGE=/userdisk/snail


# don't edit below here
function display()
{
	# $1=name $2=value $3=red_limit $4=minimal_show_limit $5=unit $6=after $7=acs/desc{
	# battery red color is opposite, lower number
	if [[ "$1" == "Battery" ]]; then
		local great="<";
	else
		local great=">";
	fi
	if [[ -n "$2" && "$2" > "0" && (( "${2%.*}" -ge "$4" )) ]]; then
		printf "%-14s%s" "$1:"
		if awk "BEGIN{exit ! ($2 $great $3)}"; then
			echo -ne "\e[0;91m $2";
		else
			echo -ne "\e[0;92m $2";
		fi
		printf "%-1s%s\x1B[0m" "$5"
		printf "%-11s%s\t" "$6"
		return 1
	fi
} # display


function get_ip_addresses()
{
	local ips=()
	for f in /sys/class/net/*; do
		local intf
		intf=$(basename "$f")

		# match only interface names starting with e, br, w, r, lt, umts
		if [[ $intf =~ $SHOW_IP_PATTERN ]]; then
			local tmp
			tmp=$(ip -4 addr show dev "$intf" 2>/dev/null | awk '/inet/ {print $2}' | cut -d'/' -f1)

			# add IP only
			[[ -n $tmp ]] && ips+=("$tmp")
		fi
	done
	echo "${ips[@]}"
} # get_ip_addresses


function storage_info()
{
	# storage info
	RootInfo=$(df -h /)
	root_usage=$(awk '/\// {print $(NF-1)}' <<< "${RootInfo}" | sed 's/%//g')
	root_total=$(awk '/\// {print $(NF-4)}' <<< "${RootInfo}")
} # storage_info


function get_cpu_info()
{
	local info

	info=$(awk -F': ' '
		/model name/ {print $2; exit}
		/Hardware/ {print $2; exit}
		/Processor/ {print $2; exit}
	' /proc/cpuinfo 2>/dev/null | cut -d ' ' -f -4)

	[[ -z "$info" ]] && info="未知"

	echo "$info"
}


# query various systems
storage_info
critical_load=$(( 1 + $(grep -c processor /proc/cpuinfo 2>/dev/null) / 2 ))

# get uptime, logged in users and load in one take
UptimeString=$(uptime | tr -d ',')
time=$(awk -F" " '{print $3" "$4}' <<< "${UptimeString}")
load="$(awk -F"average: " '{print $2}' <<< "${UptimeString}")"

case ${time} in
	1:*) # 1-2 hours
		time=$(awk -F" " '{print $3" 小时"}' <<< "${UptimeString}")
		;;
	*:*) # 2-24 hours
		time=$(awk -F" " '{print $3" 小时"}' <<< "${UptimeString}")
		;;
	*day) # days
		days=$(awk -F" " '{print $3"天"}' <<< "${UptimeString}")
		time=$(awk -F" " '{print $5}' <<< "${UptimeString}")
		time="$days "$(awk -F":" '{print $1"小时 "$2"分钟"}' <<< "${time}")
		;;
esac


# memory and swap
mem_info=$(LC_ALL=C free -w 2>/dev/null | grep "^Mem" || LC_ALL=C free | grep "^Mem")
memory_usage=$(awk '{printf("%.0f", (($2-($4+$6))/$2) * 100)}' <<< "$mem_info")
memory_total=$(awk '{printf("%d", $2/1024)}' <<< "$mem_info")

swap_info=$(LC_ALL=C free | awk '/^Swap:/')
swap_total_kb=$(awk '{print $2}' <<< "$swap_info")
swap_used_kb=$(awk '{print $3}' <<< "$swap_info")

if [[ -n "$swap_total_kb" && "$swap_total_kb" -gt 0 ]] 2>/dev/null; then
	swap_total=$(awk -v v="$swap_total_kb" 'BEGIN{printf("%d", v/1024)}')
	swap_usage=$(awk -v used="$swap_used_kb" -v total="$swap_total_kb" 'BEGIN{printf("%.0f", used/total*100)}')
else
	swap_total=0
	swap_usage=0
fi

c=0
while [ ! -n "$(get_ip_addresses)" ]; do
	[ "$c" -eq 3 ] && break || let c++
	sleep 1
done

ip_address="$(get_ip_addresses)"

printf "\n"

LEFT_VALUE_WIDTH=18

cpu_info="$(get_cpu_info)"

# 先生成“纯文本行”，用于计算最长宽度
line1=$(printf "%-12s %-18s    %-10s %s" \
	"系统负载 :" "$load" \
	"运行时间 :" "$time")

line2=$(printf "%-12s %-18s    %-10s %s" \
	"内存已用 :" "${memory_usage}% of ${memory_total}MB" \
	"IP 地址 :" "$ip_address")

line4=$(printf "%-12s %-18s    %-10s %s" \
	"系统存储 :" "${root_usage}% of ${root_total}" \
	"CPU 信息 :" "$cpu_info")

if [[ -n "$swap_total" && "$swap_total" != "0" ]]; then
	line3=$(printf "%-12s %-18s" \
		"交换内存 :" "${swap_usage}% of ${swap_total}MB")
else
	line3=""
fi

# 计算最长行长度
max_len=0
for line in "$line1" "$line2" "$line3" "$line4"; do
	[ -z "$line" ] && continue
	len=$(printf "%s" "$line" | awk '{print length}')
	[ "$len" -gt "$max_len" ] && max_len="$len"
done

max_len=$((max_len + 2))

# 生成横线
separator=""
i=1
while [ "$i" -le "$max_len" ]; do
	separator="${separator}─"
	i=$((i + 1))
done

# 正式输出，带颜色
printf "%-12s \e[92m%-18s\e[0m    %-10s \e[92m%s\e[0m\n" \
	"系统负载 :" "$load" \
	"运行时间 :" "$time"

printf "%-12s \e[92m%-18s\e[0m    %-10s \e[92m%s\e[0m\n" \
	"内存已用 :" "${memory_usage}% of ${memory_total}MB" \
	"IP 地址 :" "$ip_address"

if [[ -n "$swap_total" && "$swap_total" != "0" ]]; then
	printf "%-12s \e[92m%-18s\e[0m\n" \
		"交换内存 :" "${swap_usage}% of ${swap_total}MB"
fi

printf "%-12s \e[92m%-18s\e[0m    %-10s \e[92m%s\e[0m\n" \
	"系统存储 :" "${root_usage}% of ${root_total}" \
	"CPU 信息 :" "$cpu_info"

printf "%s\n" "$separator"