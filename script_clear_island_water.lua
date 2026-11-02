-- script_clear_island_water.lua
-- Sebelum run: pastikan kamu sudah aktifkan /ghost atau fly di game!

delay = 250

-- Fungsi jalan/terbang aman bawaan Bothax (menggantikan GoPath yg error di VariantList)
function m(x, y)
    if GetWorld() == nil then return end
    FindPath(x, y, 80)
    Sleep(80)
end

-- Blacklist blok yg gak bisa / gak boleh dihancurkan
local ignore_fg = {
    [0] = true, [6] = true, [8] = true, [242] = true,
    [1796] = true, [4992] = true, [5260] = true, [5638] = true,
    [7188] = true, [11550] = true
}

local w = GetWorld()
local max_w = (w and w.width) or 100
local max_h = (w and w.height) or 60

LogToConsole(string.format("`2[START]`7 Clear Island World (%dx%d)...", max_w, max_h))

-- 1. CLEAR BLOK ISLAND
for y2 = max_h - 2, 0, -10 do
    local y1 = math.max(0, y2 - 9)
    for x = 0, max_w - 1 do
        for y = y1, y2 do
            local tile = GetTile(x, y)
            -- Cek kalau ada foreground/background dan bukan bedrock/lock
            if tile and (not ignore_fg[tile.fg] or (tile.bg ~= 0 and tile.bg ~= 14)) then
                local stand_y = math.max(0, y - 1)
                m(x, stand_y)
                Sleep(10)

                local p = GetLocal()
                local px = (p and p.pos and p.pos.x) or (x * 32)
                local py = (p and p.pos and p.pos.y) or (stand_y * 32)

                local hits = 0
                while hits < 8 do
                    local t = GetTile(x, y)
                    -- Berhenti kalau blok sudah hilang atau tinggal bedrock
                    if not t or (ignore_fg[t.fg] and (t.bg == 0 or t.bg == 14)) then
                        break
                    end
                    SendPacketRaw(false, {
                        type = 3,
                        value = 18, -- Punch
                        px = x,
                        py = y,
                        x = px,
                        y = py
                    })
                    hits = hits + 1
                    Sleep(delay)
                end
            end
        end
    end
end

LogToConsole("`2[INFO]`7 Clear Island selesai! Lanjut Clear Water...")

-- 2. CLEAR WATER
for x = 0, max_w - 1 do
    for y = max_h - 2, 0, -1 do
        local tile = GetTile(x, y)
        if tile and tile.flags and tile.flags.water == true then
            m(x, y)
            Sleep(10)
            local sponge_hits = 0
            while sponge_hits < 8 do
                local t = GetTile(x, y)
                if not t or not t.flags or t.flags.water ~= true then
                    break
                end
                m(x, y)
                SendPacketRaw(false, {type = 3, value = 822, px = x, py = y, x = x * 32, y = y * 32})
                sponge_hits = sponge_hits + 1
                Sleep(350)
            end
        end
    end
end

LogToConsole("`2[SELESAI]`7 Clear Island & Water DONE!")
