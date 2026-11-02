-- auto_reposition_on_rejoin.lua: Tidak overwrite pintu & otomatis balik pas masuk world

local saved = {
    world = nil,
    x = nil,
    y = nil,
    locked = false -- jangan timpa koordinat saat proses balik ke pos lama
}

local timer = 0
local rejoin_timer = 0
local was_in_world = false

AddHook('OnDraw', 'auto_reposition', function(dt)
    local step = dt or 0.016
    timer = timer + step

    local w = GetWorld()
    local p = GetLocal()
    local currently_in_world = (w and w.name and w.name ~= "" and w.name ~= "EXIT" and p and p.pos)

    -- 1. DETEKSI BARU MASUK WORLD (Setelah DC / Relogin)
    if currently_in_world and not was_in_world then
        was_in_world = true
        -- Kalau ada koordinat tersimpan di world ini, kunci checkpoint & siap balik
        if saved.world == w.name and saved.x and saved.y then
            saved.locked = true
            rejoin_timer = 0
            LogToConsole(string.format("`2[REJOIN]`7 Masuk %s! Menunggu render 2 detik...", w.name))
        end
    elseif not currently_in_world then
        was_in_world = false
        return
    end

    -- 2. EKSEKUSI JALAN BALIK OTOMATIS (Beri jeda 2 detik setelah spawn)
    if saved.locked then
        rejoin_timer = rejoin_timer + step
        if rejoin_timer >= 2.0 then
            LogToConsole(string.format("`2[REJOIN]`7 Auto FindPath balik ke: (%d, %d)", saved.x, saved.y))
            FindPath(saved.x, saved.y, 100)
            saved.locked = false -- buka kunci setelah perintah jalan dikirim
        end
        return -- Jangan simpan koordinat pintu selama proses balik!
    end

    -- 3. SIMPAN POSISI SECARA BERKALA (Hanya jika tidak sedang locked)
    if timer >= 1.0 then
        timer = 0
        local tx = math.floor(p.pos.x / 32)
        local ty = math.floor(p.pos.y / 32)

        -- Simpan world & koordinat sekarang
        saved.world = w.name
        saved.x = tx
        saved.y = ty
    end
end)

-- Command manual backup jika ingin paksa balik
AddHook('OnSendPacket', 'cmd_back', function(type, packet)
    if packet:find('/back') then
        if saved.x and saved.y then
            LogToConsole(string.format("`2[MANUAL]`7 Jalan ke (%d, %d)", saved.x, saved.y))
            FindPath(saved.x, saved.y, 100)
            return true
        end
    end
end)

LogToConsole("`2[AUTOBACK]`7 Script aktif. Posisi pintu TIDAK AKAN menimpa checkpoint.")
