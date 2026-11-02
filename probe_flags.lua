-- probe_flags.lua: Cek struktur tile.flags di client ini

local t = GetTile(0, 0)
if t then
    LogToConsole("Type of flags: " .. type(t.flags))
    LogToConsole("flags value: " .. tostring(t.flags))
    LogToConsole("fg: " .. tostring(t.fg))
    LogToConsole("bg: " .. tostring(t.bg))
else
    LogToConsole("Tile (0,0) nil")
end
