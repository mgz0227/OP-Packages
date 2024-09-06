#!/bin/bash
# https://github.com/sundaqiang/openwrt-packages
# EasyUpdate for Openwrt

function checkEnv() {
	if !type sysupgrade >/dev/null 2>&1; then
		writeLog 'Your firmware does not contain sysupgrade and does not support automatic updates(您的固件未包含sysupgrade,暂不支持自动更新)'
		exit
	fi
}

function writeLog() {
	now_time='['$(date +"%Y-%m-%d %H:%M:%S")']'
	echo ${now_time} $1 | tee -a '/tmp/easyupdatemain.log'
}

function shellHelp() {
	checkEnv
	cat <<EOF
Openwrt-EasyUpdate Script by sundaqiang
Your firmware already includes Sysupgrade and supports automatic updates(您的固件已包含sysupgrade,支持自动更新)
参数:
    -c                     Get the cloud firmware version(获取云端固件版本)
    -d                     Download cloud Firmware(下载云端固件)
    -f filename                Flash firmware(刷写固件)
    -u                     One-click firmware update(一键更新固件)
EOF
}

function getCloudVer() {
    checkEnv
    github=$(uci get easyupdate.main.github)
    
    if [ -z "$github" ]; then
        writeLog "Error: No GitHub address configured."
        return 1
    fi
    
    writeLog "Fetching latest release from GitHub for: $github"
    github=(${github//// })
    
    version=$(curl -s --fail "https://api.github.com/repos/${github[2]}/${github[3]}/releases/latest" | jsonfilter -e '@.tag_name')
    
    if [ -z "$version" ]; then
        writeLog "Error: Failed to fetch version information from GitHub."
        return 1
    fi
    
    writeLog "Cloud version found: $version"
    echo "$version" | sed -e 's/^([0-9]{2}\.[0-9]{2}\.[0-9]{4}).*/\1/'
}

function downCloudVer() {
    checkEnv
    writeLog 'Get GitHub project address(读取github项目地址)'
    
    github=$(uci get easyupdate.main.github)
    if [ -z "$github" ]; then
        writeLog "Error: GitHub address not found in UCI configuration."
        return 1
    fi
    
    writeLog "GitHub project address(github项目地址): $github"
    github=(${github//// })
    
    # 检查是否 EFI 固件
    writeLog 'Check whether EFI firmware is available(判断是否EFI固件)'
    if [ -d "/sys/firmware/efi/" ]; then
        suffix="combined-efi.img.gz"
    else
        suffix="combined.img.gz"
    fi
    writeLog "Whether EFI firmware is available(是否EFI固件): $suffix"

    # 获取最新发布版本信息
    writeLog 'Fetching release information from GitHub(从GitHub获取发布信息)'
    response=$(curl -s --fail "https://api.github.com/repos/${github[2]}/${github[3]}/releases/latest")
    if [ $? -ne 0 ] || [ -z "$response" ]; then
        writeLog "Error: Failed to fetch release information from GitHub."
        return 1
    fi
    
    # 提取固件下载链接
    writeLog 'Extracting firmware download URL(提取固件下载链接)'
    url=$(echo "$response" | jsonfilter -e '@.assets[*].browser_download_url' | sed -n "/$suffix/p")
    
    if [ -z "$url" ]; then
        writeLog "Error: No matching firmware found for suffix $suffix."
        return 1
    fi
    
    writeLog "Firmware download URL: $url"
    
    # 提取文件名
    fileName=(${url//// })
    if [ -z "${fileName[7]}" ]; then
        writeLog "Error: Failed to extract file name from URL."
        return 1
    fi

    # 下载 SHA256 校验文件
    writeLog "Downloading SHA256 checksum file(下载SHA256校验文件)."
    curl -s --fail -o "/tmp/${fileName[7]}-sha256" -L "$mirror${url/${fileName[7]}/sha256sums}"
    if [ $? -ne 0 ]; then
        writeLog "Error: Failed to download SHA256 checksum file."
        return 1
    fi

    # 下载固件文件并将日志记录到 easyupdate.log
    writeLog "Downloading firmware file(下载固件文件)."
    curl -s --fail -o "/tmp/${fileName[7]}" -L "$mirror$url" >/tmp/easyupdate.log 2>&1 &
    if [ $? -ne 0 ]; then
        writeLog "Error: Failed to download firmware file."
        return 1
    fi

    writeLog "Firmware and checksum files downloaded successfully(固件和校验文件下载成功)."
}



function flashFirmware() {
	checkEnv
	if [[ -z "$file" ]]; then
		writeLog 'Please specify the file name(请指定文件名)'
	else
		writeLog 'Get whether to save the configuration(读取是否保存配置)'
		keepconfig=$(uci get easyupdate.main.keepconfig)
		if [ $keepconfig -eq 1 ]; then
			keepconfig=' '
			res='yes'
		else
			keepconfig='-n '
			res='no'
		fi
		writeLog "Whether to save the configuration(读取是否保存配置):$res"
		writeLog 'Start flash firmware, log output in /tmp/easyupdate.log(开始刷写固件，日志输出在/tmp/easyupdate.log)'
		sysupgrade $keepconfig$file >/tmp/easyupdate.log 2>&1 &
	fi
}

function checkSha() {
	if [[ -z "$file" ]]; then
		for filename in $(ls /tmp)
		do
			if [[ "${filename#*.}" = "img.gz" && "${filename:0:7}" = "meowwrt" ]]; then
				file=$filename
			fi
		done
	fi
	cd /tmp && sha256sum -c <(grep $file $file-sha256)
}

function updateCloud() {
	checkEnv
	writeLog 'Get the local firmware version(获取本地固件版本)'
	lFirVer=$(cat /etc/openwrt_release)
	writeLog "Local firmware version(本地固件版本):$lFirVer"
	writeLog 'Get the cloud firmware version(获取云端固件版本)'
	cFirVer=$(getCloudVer)
	writeLog "Cloud firmware version(云端固件版本):$cFirVer"
	lFirVer=$(date -d "$lFirVer" +%s)
	cFirVer=$(date -d "$cFirVer" +%s)
	if [ $cFirVer -gt $lFirVer ]; then
		writeLog 'Need to be updated(需要更新)'
		checkShaRet=$(checkSha)
		if [[ $checkShaRet =~ 'OK' ]]; then
			writeLog 'Check completes(检查完成)'
			file=${checkShaRet:0:-4}
			flashFirmware
		else
			downCloudVer
			i=0
			while [ $i -le 100 ]; do
				log=$(cat /tmp/easyupdate.log)
				str='transfer closed'
				if [[ $log =~ $str ]]; then
					writeLog 'Download error(下载出错)'
					i=101
					break
				else
					str='Could not resolve host'
					if [[ $log =~ $str ]]; then
						writeLog 'Download error(下载出错)'
						i=101
						break
					else
						str='100\s.+M\s+100.+--:--:--'
						if [[ $log =~ $str ]]; then
							writeLog 'Download completes(下载完成)'
							i=100
							break
						else
							echo $log | sed -n '$p'
							if [[ $i -eq 99 ]]; then
								writeLog 'Download the timeout(下载超时)'
								break
							fi
						fi
					fi
				fi
				let i++
				sleep 3
			done
			if [[ $i -eq 100 ]]; then
				writeLog 'Prepare flash firmware(准备刷写固件)'
				checkShaRet=$(checkSha)
				if [[ $checkShaRet =~ 'OK' ]]; then
					writeLog 'Check completes(检查完成)'
					file=${checkShaRet:0:-4}
					flashFirmware
				else
					writeLog 'Check error(检查出错)'
				fi
			fi
		fi
	else
		writeLog "Is the latest(已是最新)"
	fi
}

if [[ -z "$1" ]]; then
	shellHelp
else
	case $1 in
	-c)
		getCloudVer
		;;
	-d)
		downCloudVer
		;;
	-f)
		file=$2
		flashFirmware
		;;
	-k)
		file=$2
		checkSha
		;;
	-u)
		updateCloud
		;;
	*)
		shellHelp
		;;
	esac
fi