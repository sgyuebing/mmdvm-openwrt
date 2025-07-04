#!/usr/bin/lua
-- Copyright 2019 BD7MQB (bd7mqb@qq.com)
-- This is free software, licensed under the GNU GENERAL PUBLIC LICENSE, Version 2
-- a DmdIds service via ubus

require "ubus" -- opkg install libubus-lua
require "uloop" -- opkg install libubox-lua
local io = io
local os = os
local coroutine = coroutine
local util  = require "luci.util"

local conn = ubus.connect()
if not conn then
    error("Failed to connect to ubus")
end

local function shell(command)
    local handle = io.popen(command)
    local result = handle:read("*a")
    handle:close()
    return result
end



local pid = tonumber(shell("cat /proc/self/stat | awk '{print $1}'")) or 0
local function log(msg)
    msg = string.format("dmrid[%d]: %s", pid, msg)
    print(msg)
    conn:call("log", "write", {event = msg})
end


uloop.init()

local mmdvm = require("mmdvm")
local dmrid_file = "/etc/mmdvm/DMRIds.dat"
local dmrid_file1 = "/tmp/DMRIds.dat"
mmdvm.init(dmrid_file, dmrid_file1)

-- Check if a file exists
local function file_exists(file)
    local f = io.open(file, "r")
    if f then f:close() end
    return f ~= nil
end

-- Get the tail line in logfile
local function get_tail_line(logfile)
    return util.trim(util.exec("tail -n1 %s" % {logfile}))
end

-- Current log file name
local current_logfile = nil
-- Read line
local last_lines = {}
-- cmd for read log
local cmdlines = {}

-- Log watcher coroutine function
local function log_watcher(logfile)
    local cmd = string.format("tail -n2000 -f %s", logfile)
    local handle = io.popen(cmd, "r")
    if not handle then
        error("failed call io.popen()")
    end
    if logfile ~= current_logfile then
        coroutine.yield()
    end
    cmdlines[logfile] = cmd
    while true do
        local tail_line = get_tail_line(logfile)
        local lines = {}
        local read_line = last_lines[logfile]
        while tail_line ~= read_line do
            read_line = handle:read("*line")
            if read_line then
                -- Apply the filter rule
                if read_line:match("from") or read_line:match("end") or read_line:match("watchdog") or read_line:match("lost") then
                    -- Yield the new line to the waiting coroutine
                    table.insert(lines, 1, read_line)
                end
            end
        end
        last_lines[logfile] = read_line
        coroutine.yield(lines)
    end
    handle:close()
end

-- Log watching coroutine
local log_coroutines = {}

-- Initialize or update the log watcher coroutine
local function update_log_watcher()
    local new_logfile = string.format("/var/log/mmdvm/MMDVM-%s.log", os.date("%Y-%m-%d"))
    -- If the log file name has changed, restart the coroutine
    if new_logfile ~= current_logfile then
        if file_exists(new_logfile) then
            if current_logfile then
                local cmdline = cmdlines[current_logfile]
                if cmdline then
                    -- Kill the tail -f command
                    local cmd = "ps|grep \"" .. cmdline .. "\"|grep -v grep|awk '{print $1}'|xargs kill"
                    util.exec(cmd)
                    cmdlines[current_logfile] = nil
                end
                current_logfile = nil
            end
            local log_coroutine = coroutine.create(log_watcher)
            local status, err = coroutine.resume(log_coroutine, new_logfile)
            if status then
                log_coroutines[new_logfile] = log_coroutine
                current_logfile = new_logfile
            end
        end
    end
end

-- Function to get the MMDVM log
local function get_mmdvm_log()
    -- Table to hold the log lines
    local log_lines = {}
    -- Update the log watcher if the date has changed
    update_log_watcher()
    if current_logfile  then
        local log_coroutine = log_coroutines[current_logfile]
        -- Check if the coroutine has a new log line
        if log_coroutine and coroutine.status(log_coroutine) == "suspended" then
            local status, lines = coroutine.resume(log_coroutine)
            if status and #lines > 0 then
                -- Insert the new lines into the log lines table
                for _, line in ipairs(lines) do
                    table.insert(log_lines, 1, line)
                end
            end
        end
        table.sort(log_lines, function(a,b) return a>b end)
    end
    return log_lines
end

local function get_hearlist(log_lines)
    local headlist = {}
    -- local ts1duration, ts1loss, ts1ber, ts1rssi
    -- local ts2duration, ts2loss, ts2ber, ts2rssi
    -- local ysfduration, ysfloss, ysfber, ysfrssi
    -- local p25duration, p25loss, p25ber, p25rssi

    for i = 1, #log_lines do
        local logline = log_lines[i]
        local duration, loss, ber, rssi
        -- remoing invaild lines
        repeat
            if string.find(logline, "BS_Dwn_Act") or
                string.find(logline, "invalid access") or
                string.find(logline, "received RF header for wrong repeater") or
                string.find(logline, "Error returned") or
                string.find(logline, "unable to decode the network CSBK") or
                string.find(logline, "overflow in the DMR slot RF queue") or
                string.find(logline, "non repeater RF header received") or
                string.find(logline, "Embedded Talker Alias") or
                string.find(logline, "DMR Talker Alias") or
                string.find(logline, "CSBK Preamble") or
                string.find(logline, "Preamble CSBK") or
                string.find(logline, "Preamble VSBK") or
                string.find(logline, "Downlink Activate received") or
                string.find(logline, "Received a NAK") or
                string.find(logline, "late entry")
            then
                break
            end

            local mode = string.sub(logline, 28, (string.find(logline, ",") or 0)-1)

            if string.find(logline, "end of")
                or string.find(logline, "watchdog has expired")
                or string.find(logline, "ended RF data")
                or string.find(logline, "ended network")
                or string.find(logline, "RF user has timed out")
                or string.find(logline, "transmission lost")
                or string.find(logline, "D-Star")
                or string.find(logline, "POCSAG")
            then
                local linetokens = logline:split(", ")
                local count_tokens = (linetokens and #linetokens) or 0

                if string.find(logline, "RF user has timed out") then
                    duration = "-1"
                    ber = "-1"
                else
                    if count_tokens >= 3 then
                        duration = string.trim(string.sub(linetokens[3], 1, string.find(linetokens[3], " ")))
                    end
                    if count_tokens >= 4 then
                        loss = linetokens[4]
                    end
                end

                -- if RF-Packet, no LOSS would be reported, so BER is in LOSS position
                if string.find(loss or "", "BER") == 1 then
                    ber = string.trim(string.sub(loss, 6, 8))

                    loss = "0"
                    -- TODO: RSSI
                else
                    loss = string.trim(string.sub(loss or "", 1, -14))
                    if count_tokens >= 5 then
                        ber = string.trim(string.sub(linetokens[5] or "", 6, -2))

                    end
                end

            end

            local timestamp = string.sub(logline, 4, 22)
            local callsign, target
            local source = "RF"

            if mode ~= 'POCSAG' then
                if string.find(logline, "from") and string.find(logline, "to") then
                    callsign = string.gsub(string.trim(string.sub(logline, string.find(logline, "from")+5, string.find(logline, "to") - 2)), " ", "")
                    target = string.sub(logline, string.find(logline, "to") + 3)
                    target = string.gsub(string.trim(string.sub(target, 0, string.find(target, ","))), ",", "")
                end
                if string.find(logline, "network") then
                    source = "Net"
                end
            end
            -- if mode then
                -- switch selection of mode
                local switch = {
                    ["DMR Slot 1"] = function()
                        if string.find(logline, "ended RF data") or string.find(logline, "ended network") then
                            duration = "SMS"
                        end
                    end,
                    ["DMR Slot 2"] = function()
                        if string.find(logline, "ended RF data") or string.find(logline, "ended network") then
                            duration = "SMS"
                        end
                    end,
                    ["YSF"] = function()
                        if target and target:find('at') then
                            target = string.trim(string.sub(target, 14))
                        end
                    end,
                    ["P25"] = function()
                        if source == "Net" then
                            if target == "TG 10" then
                                callsign = "PARROT"
                            end
                            if callsign == "10999" then
                                callsign = "MMDVM"
                            end
                        end
                    end,
                    ["NXDN"] = function()
                        if source == "Net" then
                            if target == "TG 10" then
                                callsign = "PARROT"
                            end
                        end
                    end,
                    ["D-Star"] = function()

                    end,
                    ["POCSAG"] = function()
                        callsign = 'DAPNET'
                        source = "Net"
                        target = 'ALL'
                        duration = '0.0'
                        loss = '0'
                        ber = '0.0'
                    end,
                }
                local f = switch[mode]
                if(f) then f() end
                -- end of switch
            -- end

            -- Callsign or ID should be less than 11 chars long, otherwise it could be errorneous
            if callsign and #callsign:trim() <= 11 then
                table.insert(headlist,
                    {
                        timestamp = timestamp,
                        mode = mode,
                        callsign = callsign,
                        target = target,
                        source = source,
                        duration = duration,
                        loss = tonumber(loss) or 0,
                        ber = tonumber(ber) or 0,
                        rssi = rssi
                    }
                )
            end

        until true -- end repeat
    end -- end loop

    -- table.insert(headlist,
    --  {
    --      timestamp = "timestamp",
    --      mode = "mode",
    --      callsign = "callsign",
    --      target = "target",
    --      source = "RF",
    --      duration = "duration",
    --      loss = tonumber(loss) or 0,
    --      ber = tonumber(ber) or 0,
    --      rssi = rssi
    --  }
    -- )
    return headlist
end

-- Last heard list
local lh = {}

local function table_clear(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

local function get_lastheard()
    local calls = {}
    local log_lines = get_mmdvm_log()
    local headlist = get_hearlist(log_lines)
    for i = 1, #lh, 1 do
        table.insert(headlist, lh[i])
    end
    table_clear(lh)
    for i = 1, #headlist, 1 do
        if #lh >= 100 then
            break
        end
        local key = headlist[i].callsign .. "@" .. headlist[i].mode
        if calls[key] == nil then
            calls[key] = true
            table.insert(lh, headlist[i])
        end
    end
    return lh
end

local function get_lh(req, msg)
   local result = {}
   result.lh = get_lastheard()
   result.limit = 25
   conn:reply(req, result)
end

local function get_callsign_by_uid(req, msg)
   local result = {}
   if msg.uid then
        result.callsign = mmdvm.get_callsign_by_uid(msg.uid) or msg.uid
   end
   conn:reply(req, result)
end


local function get_user_by_uid(req, msg)
    local result = {}

    if msg.uid then
        result = mmdvm.get_user_by_uid(msg.uid) or {}
    end

    conn:reply(req, result)
end

local dmr_api = {
    dmrid = {
        get_callsign_by_uid = { get_callsign_by_uid, {} },
        get_user_by_uid = { get_user_by_uid, {} },
        get_lastheard = { get_lh, {} },
    }
}

conn:add(dmr_api)

-- local my_event = {
--     test = function(msg)
--         print("Call to test event")
--         for k, v in pairs(msg) do
--             print("key=" .. k .. " value=" .. tostring(v))
--         end
--     end,
-- }

-- conn:listen(my_event)

uloop.run()
