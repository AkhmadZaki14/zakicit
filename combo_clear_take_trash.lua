-- combo_clear_take_trash.lua: Clear Island & Water + Take/Trash (Tanpa ChangeValue)

-- 1. CONFIG ITEM & MOONCAKE TRASH
ItemIDs = {1058, 1096, 1098, 1094, 1828, 3870, 7058, 11286, 10146, 10136, 10138, 10134, 10140, 10150, 10164}
delay = 300

-- 2. HELPER FUNGSI
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

function GoPath(t, s, v, x, y) 
    if GetWorld() == nil then return end 
    SendPacketRaw(false, {type = t, state = s, value = v, px = x, py = y, x = x * 32, y = y * 32}) 
    if t == nil then 
        SendVariantList({[0] = "OnSetPos",[1] = {x = x*32, y = y*32}}, GetLocal().netid) 
    end 
end

function m(x, y) 
    if GetWorld() == nil then return end 
    local iX, iY = math.floor(GetLocal().pos.x / 32), math.floor(GetLocal().pos.y / 32) 
    local DistX = x - iX 
    local DistY = y - iY 
    if DistY > 1 then 
        for i = 1, math.floor(DistY) do iY = iY + 1 GoPath(3, 1, 0, iX, iY) GoPath(nil, nil, nil, iX, iY) Sleep(50) end 
    elseif DistY < -1 then 
        for i = 1, math.floor(-DistY) do iY = iY - 1 GoPath(3, 1, 0, iX, iY) GoPath(nil, nil, nil, iX, iY) Sleep(50) end 
    end 
    if DistX > 1 then 
        for i = 1, math.floor(DistX) do iX = iX + 1 GoPath(3, 1, 0, iX, iY) GoPath(nil, nil, nil, iX, iY) Sleep(50) end 
    elseif DistX < -1 then 
        for i = 1, math.floor(-DistX) do iX = iX - 1 GoPath(3, 1, 0, iX, iY) GoPath(nil, nil, nil, iX, iY) Sleep(50) end 
    end 
    GoPath(3, 1, 0, x, y) 
    GoPath(nil, nil, nil, x, y) 
    Sleep(50) 
end

-- 3. EKSEKUSI
LogToConsole("`2[COMBO]`7 Mulai Clear Island...")
for y2 = 193, 0, -10 do
    local y1 = y2 - 9
    for x = 0, 199 do
        for y = y1, y2 do
            local tile = nil
            if y >= 0 then tile = GetTile(x, y) end
            if tile and (tile.fg ~= 0 or tile.bg ~= 0) and tile.fg ~= 6 and tile.fg ~= 8 and tile.fg ~= 242 and tile.fg ~= 5638 and tile.fg ~= 1796 and tile.fg ~= 5260 and tile.fg ~= 11550 and tile.fg ~= 4992 and tile.fg ~= 7188 then
                m(x, y - 1)
                Sleep(1)
                while GetTile(x, y).fg ~= 0 or GetTile(x, y).bg ~= 0 do
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
for x = 0, 199 do
    for y = 199, 0, -1 do
        local tile = GetTile(x, y)
        if tile and tile.flags and tile.flags.water == true then
            m(x, y)
            SendPacketRaw(false, {state = 32, x = x * 32, y = y * 32})
            Sleep(1)
            while GetTile(x, y).flags and GetTile(x, y).flags.water == true do
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
