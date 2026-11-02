-- probe_tiles.lua: Cek blok apa yang ada di y = 0 sampai 10

LogToConsole("--- PROBE START ---")
local found = 0
for y = 0, 20 do
    for x = 0, 99 do
        local t = GetTile(x, y)
        if t and (t.fg ~= 0 or t.bg ~= 0) then
            LogToConsole(string.format("Tile ada isi di (%d, %d): fg=%d, bg=%d", x, y, t.fg, t.bg))
            found = found + 1
            if found >= 5 then break end
        end
    end
    if found >= 5 then break end
end
if found == 0 then
    LogToConsole("Y = 0 sampai 20 KOSONG SEMUA (fg=0, bg=0)")
end
LogToConsole("--- PROBE END ---")
