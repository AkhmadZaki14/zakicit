-- auto_reconnect.lua: Simpan pos akhir + auto masuk world & balik ke koordinat lama

local last_world = ""
local last_x = 0
local last_y = 0

local is_disconnected = false
local need_reposition = false
local timer = 0
local wait_spawn_timer = 0

-- Hook variant untuk deteksi DC / menu
AddHook('OnVariant', 'dc_detector', function(var, netid, delay)
    if var[0] == 'OnRequestWorldSelectMenu' then
        is_disconnected = true
        LogToConsole("`4[DC]`7 Kena DC ke World Select!")
    elseif var[0] == 'OnConsoleMessage' and type(var[1]) == 'string' then
        if var[1]:find("Disconnected") or var[1]:find("Connection lost") or var[1]:find("Unable to log on") then
            is_disconnected = true
            LogToConsole("`4[DC]`7 " .. var[1])
        end
    end
end)

-- Main loop via OnDraw
AddHook('OnDraw', 'reconnect_loop', function(dt)
    timer = timer + (dt or 0.016)
    if timer < 0.5 then return end
    timer = 0

    local world = GetWorld()
    local me = GetLocal()

    -- 1. Kondisi di dalam world normal: catat terus posisi & world
    if world and world.name and world.name ~= "" and world.name ~= "EXIT" and me and me.pos then
        -- Jika baru masuk kembali setelah DC
        if need_reposition then
            wait_spawn_timer = wait_spawn_timer + 0.5
            if wait_spawn_timer >= 2.0 then -- tunggu 2 detik world selesai render
                LogToConsole(string.format("`2[RECONNECT]`7 Otw balik ke koordinat: (%d, %d)", last_x, last_y))
                FindPath(last_x, last_y, 100)
                need_reposition = false
                wait_spawn_timer = 0
            end
        else
            -- Catat posisi saat ini
            last_world = world.name
            last_x = math.floor(me.pos.x / 32)
            last_y = math.floor(me.pos.y / 32)
        end
    else
        -- Di luar world (lobby / login screen)
        is_disconnected = true
    end

    -- 2. Kondisi DC: coba join balik ke last_world
    if is_disconnected and last_world ~= "" then
        LogToConsole("`e[RECONNECT]`7 Mencoba join balik ke: " .. last_world)
        RequestJoinWorld(last_world)
        is_disconnected = false
        need_reposition = true
        wait_spawn_timer = 0
    end
end)

LogToConsole("`2[AUTO-RECONNECT]`7 Script aktif. Monitoring posisi...")
