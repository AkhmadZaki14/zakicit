-- script_clear_pure_state32.lua
-- Pure Teleport TANPA SendVariantList (Bebas error unsuptype variant index 1)

delay = 200

local protected_fg = {
    [6] = true, [8] = true, [14] = true,
    [202] = true, [204] = true, [206] = true,
    [242] = true, [408] = true, [1398] = true, [1399] = true,
    [1796] = true, [4992] = true, [5260] = true, [5638] = true,
    [7188] = true, [11550] = true
}

local function has_bit(val, bit_val)
    if not val or type(val) ~= "number" then return false end
    return (val % (bit_val * 2)) >= bit_val
end

local function is_target_tile(x, y)
    local t = GetTile(x, y)
    if not t then return false end
    if protected_fg[t.fg] then return false end
    if t.locktile and t.locktile ~= 0 then return false end
    if type(t.flags) == "number" and has_bit(t.flags, 1) then return false end

    if t.fg ~= 0 then return true end
    if t.bg ~= 0 and t.bg ~= 14 and not protected_fg[t.bg] then return true end
    return false
end

local function is_water_tile(x, y)
    local t = GetTile(x, y)
    if not t then return false end
    if t.fg == 822 then return true end
    if type(t.flags) == "number" and has_bit(t.flags, 1024) then return true end
    return false
end

-- TELEPORT TANPA SendVariantList (Pake Raw Packet State 32)
local function teleport(tx, ty)
    local me = GetLocal()
    if not me then return end
    local px = tx * 32
    local py = ty * 32

    -- Update posisi lokal client
    SendPacketRaw(true, {
        type = 0,
        state = 32,
        pos_x = px,
        pos_y = py,
        xspeed = 0,
        yspeed = 0,
        netid = me.netid
    })

    -- Sync posisi ke server
    SendPacketRaw(false, {
        type = 0,
        state = 32,
        pos_x = px,
        pos_y = py,
        xspeed = 0,
        yspeed = 0,
        netid = me.netid
    })
    Sleep(15)
end

local w = GetWorld()
local max_w = (w and w.width) or 100
local max_h = (w and w.height) or 60

LogToConsole(string.format("`2[START]`7 Pure State32 Teleport (%dx%d)...", max_w, max_h))

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
                local stand_y = math.max(0, y - 1)
                
                -- Teleport instan
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
            Sleep(50)
        end
    end

    going_right = not going_right
end

LogToConsole("`2[INFO]`7 Clear Island selesai! Lanjut Clear Water...")

for x = 0, max_w - 1 do
    for y = max_h - 2, 0, -1 do
        if is_water_tile(x, y) then
            teleport(x, y)

            local sponge_hits = 0
            while sponge_hits < 10 do
                if not is_water_tile(x, y) then break end
                SendPacketRaw(false, {type = 3, value = 822, px = x, py = y, x = x * 32, y = y * 32})
                sponge_hits = sponge_hits + 1
                Sleep(280)
            end
        end
    end
end

LogToConsole("`2[SELESAI]`7 World 100% Bersih & Tuntas!")
