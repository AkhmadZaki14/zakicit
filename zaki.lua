-- zaki.lua: FindPath dengan delay parameter + Sleep top-level

local me = GetLocal()
if not me then
    LogToConsole("GetLocal nil")
    return
end

local tx = math.floor(me.pos.x / 32)
local ty = math.floor(me.pos.y / 32)

-- Kanan (delay 100ms per tile biar anti-cheat aman)
FindPath(tx + 2, ty, 100)
Sleep(500)

-- Kiri (balik)
FindPath(tx, ty, 100)
Sleep(500)

-- Lompat (ke atas 2 tile)
FindPath(tx, ty - 2, 100)
Sleep(400)

-- Balik ke tanah
FindPath(tx, ty, 100)
Sleep(300)

LogToConsole("zaki")
