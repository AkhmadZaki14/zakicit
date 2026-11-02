-- monitor_state.lua: Cek apa yang terbaca tiap detik

local last_w = ""
local timer = 0

AddHook('OnDraw', 'mon_loop', function(dt)
    timer = timer + (dt or 0.016)
    if timer < 1.0 then return end
    timer = 0

    local w = GetWorld()
    local me = GetLocal()
    local cl = GetClient and GetClient()

    local w_name = (w and w.name) or "NIL"
    local pos_str = (me and me.pos and string.format("(%d, %d)", math.floor(me.pos.x/32), math.floor(me.pos.y/32))) or "NIL"
    local ping_str = (cl and tostring(cl.ping)) or "NIL"

    if w_name ~= last_w then
        LogToConsole(string.format("WORLD BERUBAH: '%s' -> '%s' | Pos: %s | Ping: %s", last_w, w_name, pos_str, ping_str))
        last_w = w_name
    end
end)

LogToConsole("Monitor aktif: ganti world atau /warp exit buat tes")
