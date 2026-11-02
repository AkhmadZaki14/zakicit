-- ========================================================
-- DEBUGGER MAGPLANT DIALOG DUMP (Raw Packet Inspector)
-- ========================================================
local logFile = "mag_dialog_dump.txt"

local function AppendLog(txt)
    local f = io.open(logFile, "a")
    if f then
        f:write(string.format("[%s] %s\n", os.date("%H:%M:%S"), txt))
        f:close()
    end
end

-- Hook semua variant paket masuk
AddCallback("mag_debug_hook", "OnVariant", function(var)
    local k = var[0]:getString()
    local a = var[1] and var[1]:getString() or ""
    local b = var[2] and var[2]:getString() or ""

    if k == "OnDialogRequest" then
        -- Log dialog jika mengandung kata terkait magplant / stock / remote
        if a:find("MAGPLANT", 1, true) or a:find("Stock", 1, true) or a:find("machine", 1, true) or a:find("remote", 1, true) then
            print("================== RAW DIALOG REQUEST ==================")
            print(a)
            print("========================================================")
            AppendLog("RAW DIALOG:\n" .. a .. "\n----------------------------------------")
            
            -- Cetak versi escaped untuk lihat newline, backtick, color code
            local escaped = a:gsub("\n", "\\n"):gsub("\r", "\\r")
            print("ESCAPED: " .. escaped)
            AppendLog("ESCAPED:\n" .. escaped .. "\n----------------------------------------")
        end
    elseif k == "OnTalkBubble" then
        if b:find("empty", 1, true) or b:find("MAGPLANT", 1, true) or b:find("remote", 1, true) then
            print("TALK BUBBLE: " .. b)
            AppendLog("TALK BUBBLE: " .. b)
        end
    elseif k == "OnConsoleMessage" then
        if a:find("MAGPLANT", 1, true) or a:find("Stock", 1, true) then
            print("CONSOLE MSG: " .. a)
            AppendLog("CONSOLE MSG: " .. a)
        end
    end
    return false -- jangan blokir dialog asli biar tetap muncul di layar
end)

print("`2[MagDebugger]`w Hook aktif! Silakan Wrench Magplant sekarang...")
