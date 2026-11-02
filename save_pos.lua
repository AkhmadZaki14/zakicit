-- save_pos_on_move.lua: Simpan koordinat ke file disk biar tahan banting saat DC

local file_path = "last_pos.txt"

-- Fungsi simpan posisi ke disk
local function save_pos(world, x, y)
    local f = io.open(file_path, "w")
    if f then
        f:write(string.format("%s,%d,%d", world, x, y))
        f:close()
    end
end

-- Fungsi baca posisi terakhir dari disk
local function load_pos()
    local f = io.open(file_path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    if not content or content == "" then return nil end
    local w, x, y = content:match("([^,]+),(%d+),(%d+)")
    if w and x and y then
        return w, tonumber(x), tonumber(y)
    end
    return nil
end

-- Cek apakah ada posisi tersimpan saat script baru di-load (setelah login/masuk world)
local me = GetLocal()
local world = GetWorld()

if world and world.name and world.name ~= "" and me and me.pos then
    local saved_w, saved_x, saved_y = load_pos()
    if saved_w == world.name then
        LogToConsole(string.format("`2[RELOAD]`7 Menemukan checkpoint: (%d, %d). Otw!", saved_x, saved_y))
        Sleep(1000)
        FindPath(saved_x, saved_y, 100)
    else
        LogToConsole("`e[START]`7 World baru: " .. world.name)
    end
end

-- Loop catat posisi tiap 1 detik
local timer = 0
AddHook('OnDraw', 'tracker', function(dt)
    timer = timer + (dt or 0.016)
    if timer < 1.0 then return end
    timer = 0

    local w = GetWorld()
    local p = GetLocal()
    if w and w.name and w.name ~= "" and p and p.pos then
        local tx = math.floor(p.pos.x / 32)
        local ty = math.floor(p.pos.y / 32)
        save_pos(w.name, tx, ty)
    end
end)

LogToConsole("Tracker posisi aktif. Koordinat otomatis tersimpan di last_pos.txt")
