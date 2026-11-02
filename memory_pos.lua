-- memory_pos.lua: Simpan posisi di memori variabel global Lua (tanpa i/o)

-- Jika script di-reload atau world berubah, simpan di tabel global _G
if not _G.saved_positions then
    _G.saved_positions = {}
end

local timer = 0
AddHook('OnDraw', 'mem_tracker', function(dt)
    timer = timer + (dt or 0.016)
    if timer < 1.0 then return end
    timer = 0

    local w = GetWorld()
    local p = GetLocal()
    if w and w.name and w.name ~= "" and p and p.pos then
        local world_name = w.name
        local tx = math.floor(p.pos.x / 32)
        local ty = math.floor(p.pos.y / 32)

        _G.saved_positions[world_name] = {x = tx, y = ty}
    end
end)

-- Fungsi untuk kembali ke posisi terakhir di world ini
function BackToLastPos()
    local w = GetWorld()
    if w and w.name and _G.saved_positions[w.name] then
        local pos = _G.saved_positions[w.name]
        LogToConsole(string.format("`2[BACK]`7 Kembali ke (%d, %d) di world %s", pos.x, pos.y, w.name))
        FindPath(pos.x, pos.y, 100)
    else
        LogToConsole("`4[ERROR]`7 Belum ada data posisi tersimpan untuk world ini.")
    end
end

LogToConsole("`2[MEMORY TRACKER]`7 Aktif. Ketik /back atau panggil BackToLastPos()")
