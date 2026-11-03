-- ZAKICIT LOADER v3 — raw GitHub commit hash, no cache
local URL = "https://raw.githubusercontent.com/AkhmadZaki14/zakicit/7497d1c8814e8029e02b34b90be1cc1feb653828/zakicit.lua"

LogToConsole("`0[`4LOADER`0] Fetching zakicit...")

local ok, resp = pcall(MakeRequest, URL, "GET", { ["User-Agent"] = "ZakicitLoader/3.0" }, "")
if not ok then LogToConsole("`4[LOADER] Error: " .. tostring(resp)); return end

local content = type(resp) == "table" and (resp.content or "") or tostring(resp or "")
if content == "" or content:find("<!DOCTYPE", 1, true) or content:find("<html", 1, true) then
    LogToConsole("`4[LOADER] Gagal fetch."); return
end

local fn, err = load(content)
if not fn then LogToConsole("`4[LOADER] Compile error: " .. tostring(err)); return end

LogToConsole("`2[LOADER] OK! Menjalankan zakicit...")
local ok2, err2 = pcall(fn)
if not ok2 then LogToConsole("`4[LOADER] Runtime error: " .. tostring(err2)) end
