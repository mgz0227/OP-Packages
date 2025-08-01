#!/bin/bash

# cake-autorate automatically adjusts bandwidth for CAKE in dependence on detected load and RTT

# cake-autorate_config.sh is a script that sets up defaults for cake-autorate

# Author: @Lynx (OpenWrt forum)
# Inspiration taken from: @moeller0 (OpenWrt forum)

INTERFACE=$(basename "$1" | cut -d. -f2)
#cake_autorate_version="2.0.0"

# *** OUTPUT AND LOGGING OPTIONS ***

output_processing_stats=$(uci -q get sqm.${INTERFACE}.output_processing_stats || echo '0')	# enable (1) or disable (0) output monitoring lines showing processing stats
output_load_stats=$(uci -q get sqm.${INTERFACE}.output_load_stats || echo '0')			# enable (1) or disable (0) output monitoring lines showing achieved loads
output_reflector_stats=$(uci -q get sqm.${INTERFACE}.output_reflector_stats || echo '0')	# enable (1) or disable (0) output monitoring lines showing reflector stats
output_summary_stats=1										# enable (1) or disable (0) output monitoring lines showing summary stats
output_cake_changes=$(uci -q get sqm.${INTERFACE}.output_cake_changes || echo '0')		# enable (1) or disable (0) output monitoring lines showing cake bandwidth changes
debug=$(uci -q get sqm.${INTERFACE}.debug || echo '0')						# enable (1) or disable (0) out of debug lines

# This can generate a LOT of records so be careful:
log_DEBUG_messages_to_syslog=0	# enable (1) or disable (0) logging of all DEBUG records into the system log. 

# ** Take care with these settings to ensure you won't run into OOM issues on your router ***
# every write the cumulative write time and bytes associated with each log line are checked
# and if either exceeds the configured values below, the log log file is rotated
log_to_file=1              # enable (1) or disable (0) output logging to file (/tmp/cake-autorate.log)
log_file_max_time_mins=10000  # maximum time between log file rotations
log_file_max_size_KB=2000  # maximum KB (i.e. bytes/1024) worth of log lines between log file rotations

# log file path defaults to /var/log/
# or, if set below, then ${log_file_path_override}
log_file_path_override=""

# *** STANDARD CONFIGURATION OPTIONS ***

### For multihomed setups, it is the responsibility of the user to ensure that the probes 
### sent by this instance of cake-autorate actually travel through these interfaces.
### See ping_extra_args and ping_prefix_string

dl_if=ifb4$(uci -q get sqm.${INTERFACE}.interface)	# download interface
ul_if=$(uci -q get sqm.${INTERFACE}.interface)		# upload interface

# pinger selection can be any of:
# fping - round robin pinging (rtts)
# ping - (iputils-ping) individual pinging (rtts)
# hping3 - individidual pinging (owds)
pinger_binary=$(uci -q get sqm.${INTERFACE}.pinger || echo 'tsping')

# list of reflectors to use and number of pingers to initiate
# pingers will be initiated with reflectors in the order specified in the list 
# additional reflectors will be used to replace any reflectors that go stale
# so e.g. if 6 reflectors are specified and the number of pingers is set to 4, the first 4 reflectors will be used initially
# and the remaining 2 reflectors in the list will be used in the event any of the first 4 go bad
# a bad reflector will go to the back of the queue on reflector rotation
country="$(uci -q get omr-tracker.defaults.country)"
reflectors=( $(uci -q get omr-tracker.${country}.hosts) )
#reflectors=(
#"1.1.1.1" "1.0.0.1"  # Cloudflare
#"8.8.8.8" "8.8.4.4"  # Google
#"9.9.9.9" "9.9.9.10" "9.9.9.11" # Quad9
#"94.140.14.15" "94.140.14.140" "94.140.14.141" "94.140.15.15" "94.140.15.16" # AdGuard
#"64.6.65.6" "156.154.70.1" "156.154.70.2" "156.154.70.3" "156.154.70.4" "156.154.70.5" "156.154.71.1" "156.154.71.2" "156.154.71.3" "156.154.71.4" "156.154.71.5" # Neustar
#"208.67.220.2" "208.67.220.123" "208.67.220.220" "208.67.222.2" "208.67.222.123" # OpenDNS
#"185.228.168.9" "185.228.168.10" # CleanBrowsing
#)

randomize_reflectors=1 # enable (1) or disable (0) randomization of reflectors on startup

# Think carefully about the following settings
# to avoid excessive CPU use (proportional with ping interval / number of pingers)
# and to avoid abusive network activity (excessive ICMP frequency to one reflector)
# The author has found an ICMP rate of 1/(0.2/4) = 20 Hz to give satisfactory performance on 4G
no_pingers=$(uci -q get sqm.${INTERFACE}.no_pingers || echo "4")					# number of pingers to maintain
reflector_ping_interval_s=$(uci -q get sqm.${INTERFACE}.reflector_ping_interval_s || echo "0.5")	# (seconds, e.g. 0.2s or 2s)

# delay threshold in ms is the extent of OWD increase to classify as a delay
# these are automatically adjusted based on maximum on the wire packet size
# (adjustment significant at sub 12Mbit/s rates, else negligible)
#logger -t "sqm-autorate" "ping for ${INTERFACE} (${ul_if}): $(echo $(/sbin/uci -q get sqm.${INTERFACE}.delay_thr_ms || echo '100'))"
#dl_owd_delta_thr_ms=$(echo $(echo $(uci -q get sqm.${INTERFACE}.delay_thr_ms || echo $(echo "$(/usr/bin/ping -B -w 5 -c 5 -I ${ul_if} 1.1.1.1 | cut -d '/' -s -f6 | tr -d '\n' 2>/dev/null)+30" | bc) || echo "100")) + "0.1" | bc)  # (milliseconds)
dl_owd_delta_thr_ms=$(uci -q get sqm.${INTERFACE}.delay_thr_ms || echo "250.0")
ul_owd_delta_thr_ms=${dl_owd_delta_thr_ms}

# average owd delta threshold in ms at which maximum adjust_down_bufferbloat is applied
# set value(s) to 0 to disable and always apply maximum adjust_down_bufferbloat
dl_avg_owd_delta_thr_ms=$(echo "$dl_owd_delta_thr_ms * 2" | bc) # (milliseconds)
ul_avg_owd_delta_thr_ms=$(echo "$ul_owd_delta_thr_ms * 2" | bc) # (milliseconds)

# Set either of the below to 0 to adjust one direction only 
# or alternatively set both to 0 to simply use cake-autorate to monitor a connection
adjust_dl_shaper_rate=1 # enable (1) or disable (0) actually changing the dl shaper rate
adjust_ul_shaper_rate=1 # enable (1) or disable (0) actually changing the ul shaper rate

min_dl_shaper_rate_kbps=$(uci -q get sqm.${INTERFACE}.min_download || echo "5000")	# minimum bandwidth for download (Kbit/s)
base_dl_shaper_rate_kbps=$(uci -q get sqm.${INTERFACE}.download || echo "40000")	# steady state bandwidth for download (Kbit/s)
max_dl_shaper_rate_kbps=$(uci -q get sqm.${INTERFACE}.max_download || echo "80000")	# maximum bandwidth for download (Kbit/s)

min_ul_shaper_rate_kbps=$(uci -q get sqm.${INTERFACE}.min_upload || echo "5000")	# minimum bandwidth for upload (Kbit/s)
base_ul_shaper_rate_kbps=$(uci -q get sqm.${INTERFACE}.upload || echo "20000")		# steady state bandwidth for upload (KBit/s)
max_ul_shaper_rate_kbps=$(uci -q get sqm.${INTERFACE}.max_upload || echo "35000")	# maximum bandwidth for upload (Kbit/s)

# sleep functionality saves unecessary pings and CPU cycles by
# pausing all active pingers when connection is not in active use
enable_sleep_function=$(uci -q get sqm.${INTERFACE}.enable_sleep_functions || echo "1")			# enable (1) or disable (0) sleep functonality 
connection_active_thr_kbps=$(uci -q get sqm.${INTERFACE}.connection_active_thr_kpbs || echo "1000")	# threshold in Kbit/s below which dl/ul is considered idle
sustained_idle_sleep_thr_s=$(uci -q get sqm.${INTERFACE}.sustained_idle_sleep_thr || echo "150.0")	# time threshold to put pingers to sleep on sustained dl/ul achieved rate < idle_thr (seconds)

min_shaper_rates_enforcement=$(uci -q get sqm.${INTERFACE}.min_shaper_rates_enforcement || echo "0")	# enable (1) or disable (0) dropping down to minimum shaper rates on connection idle or stall

startup_wait_s=$(uci -q get sqm.${INTERFACE}.startup_wait_s || echo "0.0")	# number of seconds to wait on startup (e.g. to wait for things to settle on router reboot)

# *** ADVANCED CONFIGURATION OPTIONS ***

log_file_export_compress=1 # compress log file exports using gzip and append .gz to export filename

### In multi-homed setups, it is mandatory to use either ping_extra_args
### or ping_prefix_string to direct the pings through $dl_if and $ul_if.
### No universal recommendation exists, because there are multiple
### policy-routing packages available (e.g. vpn-policy-routing and mwan3).
### Typically they either react to a firewall mark set on the pings, or
### provide a convenient wrapper.
###
### In a traditional single-homed setup, there is usually no need for these parameters.
###
### These arguments can also be used for any other purpose - e.g. for setting a
### particular QoS mark.

# extra arguments for ping or fping
# e.g., here is how you can set the correct outgoing interface and
# the firewall mark for ping:
# ping_extra_args="-I wwan0 -m $((0x300))"
# Unfortunately, fping does not offer a command line switch to set
# the firewall mark.
# WARNING: no error checking so use at own risk!
#ping_extra_args="-B -I ${INTERFACE}"
ping_extra_args="-i ${ul_if} -e"

# a wrapper for ping binary - used as a prefix for the real command
# e.g., when using mwan3, it is recommended to set it like this:
# ping_prefix_string="mwan3 use gpon exec"
# WARNING: the wrapper must exec ping as the final step, not run it as a subprocess.
# Running ping or fping as a subprocess will lead to problems stopping it.
# WARNING: no error checking - so use at own risk!
ping_prefix_string=""
# interval in ms for monitoring achieved rx/tx rates
# this is automatically adjusted based on maximum on the wire packet size
# (adjustment significant at sub 12Mbit/s rates, else negligible)  
monitor_achieved_rates_interval_ms=200 # (milliseconds) 

# bufferbloat is detected when (bufferbloat_detection_thr) samples
# out of the last (bufferbloat detection window) samples are delayed
bufferbloat_detection_window=6   # number of samples to retain in detection window
bufferbloat_detection_thr=3      # number of delayed samples for bufferbloat detection

# OWD baseline against which to measure delays
# the idea is that the baseline is allowed to increase slowly to allow for path changes
# and slowly enough such that bufferbloat will be corrected well before the baseline increases,
# but it will decrease very rapidly to ensure delays are measured against the shortest path
alpha_baseline_increase=0.001  # how rapidly baseline RTT is allowed to increase
alpha_baseline_decrease=0.9  # how rapidly baseline RTT is allowed to decrease

# OWD delta from baseline is tracked using ewma with alpha set below
alpha_delta_ewma=0.095

# rate adjustment parameters 
# bufferbloat adjustment works with the lower of the adjusted achieved rate and adjusted shaper rate
# to exploit that transfer rates during bufferbloat provide an indication of line capacity
# otherwise shaper rate is adjusted up on load high, and down on load idle or low
#shaper_rate_adjust_down_bufferbloat=0.75   # how rapidly to reduce shaper rate upon detection of bufferbloat 
shaper_rate_adjust_up_load_high=1.01      # how rapidly to increase shaper rate upon high load detected 
shaper_rate_adjust_down_load_low=0.99     # how rapidly to return down to base shaper rate upon idle or low load detected 
shaper_rate_adjust_up_load_low=1.01       # how rapidly to return up to base shaper rate upon idle or low load detected 

# the load is categoried as low if < high_load_thr and high if > high_load_thr relative to the current shaper rate
high_load_thr=0.75   # % of currently set bandwidth for detecting high load

# refractory periods between successive bufferbloat/decay rate changes
# the bufferbloat refractory period should be greater than the 
# average time it would take to replace the bufferbloat
# detection window with new samples upon a bufferbloat event
bufferbloat_refractory_period_ms=2000 # (milliseconds)
decay_refractory_period_ms=1000 # (milliseconds)

# interval for checking reflector health
reflector_health_check_interval_s=1.0 # (seconds)
# deadline for reflector response not to be classified as an offence against reflector
reflector_response_deadline_s=2.0 # (seconds)

# reflector misbehaving is detected when $reflector_misbehaving_detection_thr samples
# out of the last (reflector misbehaving detection window) samples are offences
# thus with a 1s interval, window 60 and detection_thr 3, this is tantamount to
# 3 offences within the last 60s 
reflector_misbehaving_detection_window=60
reflector_misbehaving_detection_thr=3

reflector_replacement_interval_mins=60 # how often to replace a random reflector from the present list

reflector_comparison_interval_mins=1       # how often to compare reflectors 
#reflector_sum_owd_baseline_delta_thr_ms=30     # max increase from min sum owd baselines before reflector rotated
reflector_owd_delta_ewma_delta_thr_ms=10.0   # mac increase from min delta ewma before reflector rotated

# stall is detected when the following two conditions are met:
# 1) no reflector responses within $stall_detection_thr*$ping_response_interval_us; and
# 2) either $rx_achieved_rate or $tx_achieved_rate < $connection_stall_thr
stall_detection_thr=5
connection_stall_thr_kbps=10

global_ping_response_timeout_s=${dl_owd_delta_thr_ms} # timeout to set shaper rates to min on no ping response whatsoever (seconds)

if_up_check_interval_s=10.0 # time to wait before re-checking if rx/tx bytes files exist (e.g. from boot state or sleep recovery)

# Starlink satellite switch (sss) compensation options
sss_compensation=$(uci -q get sqm.${INTERFACE}.sss_compensation || echo "0")	# enable (1) or disable (0) Starlink handling
# satellite switch compensation start times in seconds of each minute
sss_times_s=("12.0" "27.0" "42.0" "57.0")
sss_compensation_pre_duration_ms=300
sss_compensation_post_duration_ms=200

config_file_check="cake-autorate"
