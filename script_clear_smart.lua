-- script_clear_smart.lua
-- Auto-detect per baris (scan ulang sampai benar-benar bersih 0 block), pakai FindPath langsung.

delay = 200

local ignore_fg = {
    [0] = true, [6] = true, [8] = true, [242] = true,
    [1796] = true, [4992] = true, [5260] = true, [5638] = true,
    [7188] = true, [11550] = true
}

local w = GetWorld()
local max_w = (w and w.width) or 100
local max_h = (w and w.height) or 60

LogToConsole(string.format("`2[START]`7 Smart Clear Island (%dx%d)...", max_w, max_h))

-- Scan per baris Y dari atas ke bawah. Ulangi baris tersebut sampai 100% bersih.
for y = 0, max_h - 2 do
    local row_clean = false
    local attempts = 0

    while not row_clean and attempts < 5 do
        row_clean = true
        attempts = attempts + 1

        for x = 0, max_w - 1 do
            local tile = GetTile(x, y)
            if tile and (not ignore_fg[tile.fg] or (tile.bg ~= 0 and tile.bg ~= 14)) then
                row_clean = false -- Masih ada block yang belum hancur di baris ini!

                -- Langsung FindPath ke koordinat tile tersebut (posisi berdiri pas di atasnya atau sejajar)
                FindPath(x, math.max(0, y - 1), 50)
                Sleep(80)

                local p = GetLocal()
                local px = (p and p.pos and p.pos.x) or (x * 32)
                local py = (p and p.pos and p.pos.y) or ((y - 1) * 32)

                -- Hancurkan sampai benar-benar 0 (fg == 0 dan bg == 0/bedrock)
                local hits = 0
                while hits < 15 do
                    local t = GetTile(x, y)
                    if not t or (t.fg == 0 and (t.bg == 0 or t.bg == 14)) then
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

LogToConsole("`2[INFO]`7 Clear Island selesai! Lanjut Clear Water (Smart Scan)...")

-- CLEAR WATER DENGAN AUTO-DETECT PER KOLOM
for x = 0, max_w - 1 do
    for y = max_h - 2, 0, -1 do
        local tile = GetTile(x, y)
        if tile and tile.flags and tile.flags.water == true then
            FindPath(x, y, 50)
            Sleep(80)

            local sponge_hits = 0
            while sponge_hits < 10 do
                local t = GetTile(x, y)
                if not t or not t.flags or t.flags.water ~= true then
                    break
                end
                FindPath(x, y, 50)
                SendPacketRaw(false, {type = 3, value = 822, px = x, py = y, x = x * 32, y = y * 32})
                sponge_hits = sponge_hits + 1
                Sleep(350)
            end
        end
    end
end

LogToConsole("`2[SELESAI]`7 Clear Island & Water 100% Bersih!")
