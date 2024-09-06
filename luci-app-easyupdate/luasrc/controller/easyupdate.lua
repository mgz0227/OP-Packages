module("luci.controller.easyupdate",package.seeall)

function index()
	if not nixio.fs.access("/etc/config/easyupdate") then
		return
	end
	local c = luci.model.uci.cursor()
	local r = 0
	if not c:get("easyupdate", "main", "mirror") then
	    r = 1
	    c:set("easyupdate", "main", "mirror", "")
	end
	if not c:get("easyupdate", "main", "keepconfig") then
	    r = 1
	    c:set("easyupdate", "main", "keepconfig", "1")
	end
	if not c:get("easyupdate", "main", "github") then
	    r = 1
	    local pcall, dofile, _G = pcall, dofile, _G
	    pcall(dofile, "/etc/openwrt_version")  -- Update this line to use 'openwrt_version'
	    c:set("easyupdate", "main", "github", _G.DISTRIB_GITHUB)
	end
	if r then
	    c:commit("easyupdate")
	end
	entry({"admin", "system", "easyupdate"}, cbi("easyupdate"), _("EasyUpdate"), 99).dependent = true
	entry({"admin", "system", "easyupdate", "getver"}, call("getver")).leaf = true
	entry({"admin", "system", "easyupdate", "download"}, call("download")).leaf = true
	entry({"admin", "system", "easyupdate", "getlog"}, call("getlog")).leaf = true
	entry({"admin", "system", "easyupdate", "check"}, call("check")).leaf = true
	entry({"admin", "system", "easyupdate", "flash"}, call("flash")).leaf = true
end

function Split(str, delim, maxNb)  
    -- Eliminate bad cases...  
    if string.find(str, delim) == nil then 
        return { str } 
    end 
    if maxNb == nil or maxNb < 1 then 
        maxNb = 0    -- No limit  
    end 
    local result = {} 
    local pat = "(.-)" .. delim .. "()"  
    local nb = 0 
    local lastPos  
    for part, pos in string.gmatch(str, pat) do 
        nb = nb + 1 
        result[nb] = part  
        lastPos = pos  
        if nb == maxNb then break end 
    end 
    -- Handle the last field  
    if nb ~= maxNb then 
        result[nb + 1] = string.sub(str, lastPos)  
    end 
    return result  
end 

function getver()
	local e={}
    -- 获取云端版本号
    e.newver = luci.sys.exec("/usr/bin/easyupdate.sh -c")
    e.newver = e.newver:sub(1,10)  -- 假设日期格式是 "dd.mm.yyyy"
    
    -- 转换为时间戳
    local day = tonumber(e.newver:sub(1,2))
    local month = tonumber(e.newver:sub(4,5))
    local year = tonumber(e.newver:sub(7,10))
    e.newverint = os.time({day=day, month=month, year=year, hour=0, min=0, sec=0})

	-- 本地版本时间戳
	local localver = luci.sys.exec("cat /etc/openwrt_version")
	local localmonth = tonumber(localver:sub(1,2))
	local localday = tonumber(localver:sub(4,5))
	local localyear = tonumber(localver:sub(7,10))
	local nowverint = os.time({day=localday, month=localmonth, year=localyear, hour=0, min=0, sec=0})

    -- 返回结果
    e.localverint = nowverint
	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end

function download()
	local e={}
	ret=luci.sys.exec("/usr/bin/easyupdate.sh -d")
	e.data=ret:match("MeowWrt.+%.img%.gz")
	e.code=1
	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end

function getlog()
	local e = {}
	e.code=1
	e.data=nixio.fs.readfile ("/tmp/easyupdate.log")
	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end

function check()
	local e = {}
	local f = luci.http.formvalue('file')
	e.code=1
	e.data=luci.sys.exec("/usr/bin/easyupdate.sh -k " .. f)
	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end

function flash()
	local e={}
	local f = luci.http.formvalue('file')
    luci.sys.exec("/usr/bin/easyupdate.sh -f /tmp/" .. f)
    e.code=1
	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end