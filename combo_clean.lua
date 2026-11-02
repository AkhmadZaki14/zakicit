-- combo_clean.lua: Fixed OnSetPos VariantList structure

ItemIDs = {1058, 1096, 1098, 1094, 1828, 3870, 7058, 11286, 10146, 10136, 10138, 10134, 10140, 10150, 10164}
delay = 300

function inv(id)
    for _, itm in pairs(GetInventory()) do
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
    for _, targetID in pairs(ItemIDs) do
        if inv(targetID) < 250 then
            for _, obj in pairs(GetObjectList()) do
                if obj.id == targetID then
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

-- Gerak aman pake FindPath bawaan Bothax (bebas error variantlist & speedhack)
function m(x, y)
    if GetWorld() == nil then return end
    FindPath(x, y, 80)
    Sleep(80)
end

-- Deteksi ukuran world dinamis
local w = GetWorld()
local max_w = (w and w.width) or 100
local max_h = (w and w.height) or 60

LogToConsole(string.format("`2[COMBO]`7 Mulai Clear Island (World: %dx%d)...", max_w, max_h))

for y2 = max_h - 1, 0, -10 do
    local y1 = math.max(0, y2 - 9)
    for x = 0, max_w - 1 do
        for y = y1, y2 do
            local tile = GetTile(x, y)
            if tile and (tile.fg ~= 0 or tile.bg ~= 0) and tile.fg ~= 6 and tile.fg ~= 8 and tile.fg ~= 242 and tile.fg ~= 5638 and tile.fg ~= 1796 and tile.fg ~= 5260 and tile.fg ~= 11550 and tile.fg ~= 4992 and tile.fg ~= 7188 then
                local stand_y = math.max(0, y - 1)
                m(x, stand_y)
                Sleep(1)
                while true do
                    local t = GetTile(x, y)
                    if not t or (t.fg == 0 and t.bg == 0) then break end
                    SendPacketRaw(false, {type = 3, value = 18, px = x, py = y, x = x * 32, y = y * 32})
                    Sleep(delay)
                end
            end
        end
    end
    takeitems()
    trashitems()
end

LogToConsole("`2[COMBO]`7 Clear Island selesai! Lanjut Clear Water...")
for x = 0, max_w - 1 do
    for y = max_h - 1, 0, -1 do
        local tile = GetTile(x, y)
        if tile and tile.flags and tile.flags.water == true then
            m(x, y)
            SendPacketRaw(false, {state = 32, x = x * 32, y = y * 32})
            Sleep(1)
            while true do
                local t = GetTile(x, y)
                if not t or not t.flags or t.flags.water ~= true then break end
                m(x, y) 
                SendPacketRaw(false, {type = 3, value = 822, px = x, py = y, x = x * 32, y = y * 32})
                Sleep(400)
            end
        end
    end
end

takeitems()
trashitems()
LogToConsole("`2[COMBO]`7 Selesai!")
