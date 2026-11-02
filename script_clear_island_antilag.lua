-- script_clear_island_antilag.lua
-- Fix: Anti-Hancurin WL & Anti-Lag (Verifikasi sampai blok benar-benar pecah)

delay = 240 -- Delay punch kompensasi lag ping

-- DAFTAR ITEM YANG DILINDUNGI (HARAM DISENTUH):
local protected_fg = {
    [6] = true,     -- White Door (Pintu Utama)
    [8] = true,     -- Bedrock
    [14] = true,    -- Bedrock / Cave BG
    [202] = true,   -- Small Lock
    [204] = true,   -- Big Lock
    [206] = true,   -- Huge Lock
    [242] = true,   -- World Lock (WL)
    [408] = true,   -- Heart Monitor
    [1398] = true,  -- Inviso-Block (Langit)
    [1399] = true,  -- Inviso-Block Seed
    [1796] = true,  -- Diamond Lock (DL)
    [4992] = true, [5260] = true, [5638] = true,
    [7188] = true,  -- Blue Gem Lock (BGL)
    [11550] = true
}

-- FUNGSI FILTER: Cek apakah blok aman untuk dihancurkan
local function is_target_tile(x, y)
    local t = GetTile(x, y)
    if not t then return false end

    -- 1. PROTEKSI MUTLAK: Kalau ini WL, Lock, Pintu, Bedrock -> JANGAN SENTUH!
    if protected_fg[t.fg] then return false end
    if t.locktile and t.locktile ~= 0 then return false end
    if t.flags and t.flags.locked then return false end

    -- 2. Targetkan foreground yang bukan udara dan bukan blacklist
    if t.fg ~= 0 then
        return true
    end

    -- 3. Kalau foreground sudah 0, cek background (selain bedrock bg 14)
    if t.bg ~= 0 and t.bg ~= 14 and not protected_fg[t.bg] then
        return true
    end

    return false
end

local w = GetWorld()
local max_w = (w and w.width) or 100
local max_h = (w and w.height) or 60

LogToConsole(string.format("`2[START]`7 Anti-Lag Clear Island (%dx%d)...", max_w, max_h))

-- 1. SAPU BLOK PER BARIS DENGAN VERIFIKASI ANTI-LAG
for y = 0, max_h - 2 do
    local max_row_retries = 8
    local row_done = false

    for attempt = 1, max_row_retries do
        local remaining = 0

        for x = 0, max_w - 1 do
            if is_target_tile(x, y) then
                remaining = remaining + 1

                -- Pindah ke atas/samping tile
                local stand_y = math.max(0, y - 1)
                FindPath(x, stand_y, 60)
                Sleep(120) -- Tunggu server sinkronisasi posisi biar punch gak missed

                local p = GetLocal()
                local px = (p and p.pos and p.pos.x) or (x * 32)
                local py = (p and p.pos and p.pos.y) or (stand_y * 32)

                -- Pukul terus sampai SERVER KONFIRMASI bloknya sudah hilang
                local hits = 0
                while is_target_tile(x, y) and hits < 15 do
                    SendPacketRaw(false, {
                        type = 3,
                        value = 18, -- Fist/Punch
                        px = x,
                        py = y,
                        x = px,
                        y = py
                    })
                    hits = hits + 1
                    Sleep(delay) -- Jeda antar punch
                end
                Sleep(50) -- Jeda nunggu paket server masuk
            end
        end

        -- Kalau baris ini sudah benar-benar 0 blok sisa, lanjut ke baris berikutnya
        if remaining == 0 then
            row_done = true
            break
        else
            LogToConsole(string.format("`e[VERIFIKASI]`7 Baris %d masih sisa %d blok (efek lag). Menyapu ulang...", y, remaining))
            Sleep(150)
        end
    end
end

LogToConsole("`2[INFO]`7 Clear Island selesai! Lanjut Clear Water...")

-- 2. CLEAR WATER DENGAN VERIFIKASI AIR BERSIH
for x = 0, max_w - 1 do
    for y = max_h - 2, 0, -1 do
        local tile = GetTile(x, y)
        if tile and tile.flags and tile.flags.water == true then
            FindPath(x, y, 60)
            Sleep(100)

            local sponge_hits = 0
            while sponge_hits < 12 do
                local t = GetTile(x, y)
                if not t or not t.flags or t.flags.water ~= true then
                    break
                end
                SendPacketRaw(false, {type = 3, value = 822, px = x, py = y, x = x * 32, y = y * 32})
                sponge_hits = sponge_hits + 1
                Sleep(320)
            end
        end
    end
end

LogToConsole("`2[SELESAI]`7 World 100% Bersih & Aman!")
