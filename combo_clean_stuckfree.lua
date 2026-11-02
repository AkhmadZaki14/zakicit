-- combo_clean_stuckfree.lua: Full Safe Wrapper (Check function existence)

ItemIDs = {1058, 1096, 1098, 1094, 1828, 3870, 7058, 11286, 10146, 10136, 10138, 10134, 10140, 10150, 10164}
delay = 250

function inv(id)
    if not GetInventory then return 0 end
    local inv_list = GetInventory()
    if not inv_list then return 0 end
    for _, itm in pairs(inv_list) do
        if itm.id == id then return itm.amount end    
    end
    return 0
end

function trashitems()
    for _, trashID in pairs(ItemIDs) do
        local amount = inv(trashID)
        if amount >= 250 then
            LogToConsole("Trashing item " .. trashID .. " amount " .. amount)
            SendPacket(2, "action|dialog_return\ndialog_name|trash\nitem_trash|" .. trashID .. "|\nitem_count|" .. amount)
            Sleep(200)
        end
    end
end

function takeitems()
    -- Cek berbagai kemungkinan nama fungsi object list di client ini
    local get_objs = GetObjectList or getObjectList or GetObjects or getObjects or GetWorldObjects
    if not get_objs then
        -- Jika fungsi memang tidak ada di build mod ini, skip tanpa error
        return
    end

    local obj_list = get_objs()
    if not obj_list then return end

    for _, targetID in pairs(ItemIDs) do
        if inv(targetID) < 250 then
            for _, obj in pairs(obj_list) do
                if obj and obj.id == targetID and obj.pos then
                    local x = math.floor(obj.pos.x / 32)
                    local y = math.floor(obj.pos.y / 32)
                    FindPath(x, y, 100)
                    Sleep(100)  
                    if inv(targetID) >= 250 then break end
                end
            end
            Sleep(50)
        end
    end
end

function m(x, y)
    if GetWorld() == nil then return end
    FindPath(x, y, 80)
    Sleep(80)
end

local ignore_blocks = {
    [0] = true, [6] = true, [8] = true, [14] = true, [242] = true,
    [1796] = true, [4992] = true, [5260] = true, [5638] = true,
    [7188] = true, [11550] = true
}

local w = GetWorld()
local max_w = (w and w.width) or 100
local max_h = (w and w.height) or 60

LogToConsole(string.format("`2[COMBO]`7 Mulai Clear Island (%dx%d)...", max_w, max_h))

for y = 0, max_h - 2 do
    for x = 0, max_w - 1 do
        local tile = GetTile(x, y)
        if tile and (not ignore_blocks[tile.fg] or not ignore_blocks[tile.bg]) then
            local stand_y = math.max(0, y - 1)
            m(x, stand_y)
            Sleep(10)

            local p = GetLocal()
            local px = (p and p.pos and p.pos.x) or (x * 32)
            local py = (p and p.pos and p.pos.y) or (stand_y * 32)

            local retries = 0
            while retries < 8 do
                local t = GetTile(x, y)
                if not t or (ignore_blocks[t.fg] and (t.bg == 0 or ignore_blocks[t.bg])) then
                    break 
                end

                SendPacketRaw(false, {
                    type = 3,
                    value = 18,
                    px = x,
                    py = y,
                    x = px,
                    y = py
                })
                retries = retries + 1
                Sleep(delay)
            end
        end
    end

    if y % 3 == 0 then
        takeitems()
        trashitems()
    end
end

LogToConsole("`2[COMBO]`7 Clear Island selesai! Lanjut Clear Water...")
for x = 0, max_w - 1 do
    for y = max_h - 2, 0, -1 do
        local tile = GetTile(x, y)
        if tile and tile.flags and tile.flags.water == true then
            m(x, y)
            Sleep(10)
            local retries = 0
            while retries < 10 do
                local t = GetTile(x, y)
                if not t or not t.flags or t.flags.water ~= true then break end
                m(x, y) 
                SendPacketRaw(false, {type = 3, value = 822, px = x, py = y, x = x * 32, y = y * 32})
                retries = retries + 1
                Sleep(350)
            end
        end
    end
end

takeitems()
trashitems()
LogToConsole("`2[COMBO]`7 Semua proses selesai!")
