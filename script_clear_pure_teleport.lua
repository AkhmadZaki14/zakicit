-- script_clear_pure_teleport.lua
-- ZERO WALKING: Pure Teleportation (FindPath delay = 0), Snake Pattern, Anti-WL, Anti-Lag

delay = 200

local protected_fg = {
    [6] = true,     -- White Door
    [8] = true,     -- Bedrock
    [14] = true,    -- Bedrock / Cave BG
    [202] = true, [204] = true, [206] = true,
    [242] = true,   -- World Lock
    [408] = true,   -- Heart Monitor
    [1398] = true,  -- Inviso-Block
    [1399] = true,
    [1796] = true,  -- Diamond Lock
    [4992] = true, [5260] = true, [5638] = true,
    [7188] = true,  -- Blue Gem Lock
    [11550] = true
}

local function is_target_tile(x, y)
    local t = GetTile(x, y)
    if not t then return false end
    if protected_fg[t.fg] then return false end
    if t.locktile and t.locktile ~= 0 then return false end
    if t.flags and t.flags.locked then return false end

    if t.fg ~= 0 then return true end
    if t.bg ~= 0 and t.bg ~= 14 and not protected_fg[t.bg] then return true end
    return false
end

-- Teleport instan 0 milidetik (tidak ada animasi jalan setapak kaki)
local function teleport(tx, ty)
    FindPath(tx, ty, 0)
    Sleep(20)
end

local w = GetWorld()
local max_w = (w and w.width) or 100
local max_h = (w and w.height) or 60

LogToConsole(string.format("`2[START]`7 Pure Teleport Clear Island (%dx%d)...", max_w, max_h))

local going_right = true

for y = 0, max_h - 2 do
    local max_retries = 5
    for attempt = 1, max_retries do
        local remaining = 0

        local x_start, x_end, x_step
        if going_right then
            x_start, x_end, x_step = 0, max_w - 1, 1
        else
            x_start, x_end, x_step = max_w - 1, 0, -1
        end

        for x = x_start, x_end, x_step do
            if is_target_tile(x, y) then
                remaining = remaining + 1

                -- INSTANT TELEPORT: Langsung muncul di titik target tanpa jalan kaki
                local stand_y = math.max(0, y - 1)
                teleport(x, stand_y)

                local p = GetLocal()
                local px = (p and p.pos and p.pos.x) or (x * 32)
                local py = (p and p.pos and p.pos.y) or (stand_y * 32)

                local hits = 0
                while is_target_tile(x, y) and hits < 12 do
                    SendPacketRaw(false, {
                        type = 3,
                        value = 18,
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

        if remaining == 0 then
            break
        else
            LogToConsole(string.format("`e[VERIFIKASI]`7 Sisa %d blok di Y=%d karena lag, sweep ulang...", remaining, y))
            Sleep(50)
        end
    end

    going_right = not going_right
end

LogToConsole("`2[INFO]`7 Clear Island selesai! Lanjut Clear Water (Teleport)...")

-- WATER: PURE TELEPORT
for x = 0, max_w - 1 do
    for y = max_h - 2, 0, -1 do
        local tile = GetTile(x, y)
        if tile and tile.flags and tile.flags.water == true then
            teleport(x, y)

            local sponge_hits = 0
            while sponge_hits < 10 do
                local t = GetTile(x, y)
                if not t or not t.flags or t.flags.water ~= true then break end
                SendPacketRaw(false, {type = 3, value = 822, px = x, py = y, x = x * 32, y = y * 32})
                sponge_hits = sponge_hits + 1
                Sleep(280)
            end
        end
    end
end

LogToConsole("`2[SELESAI]`7 Semua pulau & air bersih total!")
