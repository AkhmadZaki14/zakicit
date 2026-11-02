-- script_clear_island_water_v2.lua
-- Fix: Blacklist Inviso-Block (1398) yang ada di langit + Auto-detect per baris

delay = 200

-- Daftar block yang JANGAN disentuh (Aman dari langit / pintu / lock):
local ignore_fg = {
    [0] = true,     -- Udara kosong
    [6] = true,     -- Main Door
    [8] = true,     -- Bedrock
    [14] = true,    -- Bedrock / Cave BG
    [202] = true,   -- Small Lock
    [204] = true,   -- Big Lock
    [206] = true,   -- Huge Lock
    [242] = true,   -- World Lock
    [1398] = true,  -- Inviso-Block (Blok tak kasat mata di langit!)
    [1399] = true,  -- Inviso-Block Seed
    [1796] = true, [4992] = true, [5260] = true, [5638] = true,
    [7188] = true, [11550] = true
}

local w = GetWorld()
local max_w = (w and w.width) or 100
local max_h = (w and w.height) or 60

LogToConsole(string.format("`2[START]`7 Clear Island World (%dx%d)...", max_w, max_h))

-- Fungsi cek apakah tile ini valid untuk dihancurkan
local function is_target_tile(x, y)
    local t = GetTile(x, y)
    if not t then return false end
    -- Cek foreground bukan blacklist
    if t.fg ~= 0 and not ignore_fg[t.fg] then
        return true
    end
    -- Cek background jika bukan udara / bedrock bg
    if t.bg ~= 0 and t.bg ~= 14 and not ignore_fg[t.bg] then
        return true
    end
    return false
end

-- 1. CLEAR BLOK ISLAND (Per baris Y dengan auto-detect sampai 100% bersih)
for y = 0, max_h - 2 do
    local attempts = 0
    while attempts < 3 do
        attempts = attempts + 1
        local found_block_in_row = false

        for x = 0, max_w - 1 do
            if is_target_tile(x, y) then
                found_block_in_row = true

                -- Langsung teleport/fly pake FindPath pas ke atas tile
                FindPath(x, math.max(0, y - 1), 50)
                Sleep(60)

                local p = GetLocal()
                local px = (p and p.pos and p.pos.x) or (x * 32)
                local py = (p and p.pos and p.pos.y) or ((y - 1) * 32)

                local hits = 0
                while hits < 10 do
                    if not is_target_tile(x, y) then break end
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

        -- Kalau baris ini sudah tidak ada blok sama sekali, lanjut ke baris berikutnya
        if not found_block_in_row then
            break
        end
    end
end

LogToConsole("`2[INFO]`7 Clear Island selesai! Lanjut Clear Water...")

-- 2. CLEAR WATER (Spons air per kolom dengan auto-detect)
for x = 0, max_w - 1 do
    for y = max_h - 2, 0, -1 do
        local tile = GetTile(x, y)
        if tile and tile.flags and tile.flags.water == true then
            FindPath(x, y, 50)
            Sleep(60)

            local sponge_hits = 0
            while sponge_hits < 8 do
                local t = GetTile(x, y)
                if not t or not t.flags or t.flags.water ~= true then
                    break
                end
                SendPacketRaw(false, {type = 3, value = 822, px = x, py = y, x = x * 32, y = y * 32})
                sponge_hits = sponge_hits + 1
                Sleep(300)
            end
        end
    end
end

LogToConsole("`2[SELESAI]`7 Clear Island & Water 100% BERSIH!")
