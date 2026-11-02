-- ZAKICIT LOADER — selalu narik versi paling baru, bypass CDN cache
local url = "https://raw.githubusercontent.com/AkhmadZaki14/zakicit/main/zakicit.lua?v=" .. tostring(os.time())
LogToConsole("`9Fetching zakicit.lua dari GitHub...")

local res = MakeRequest(url, "GET")
if not res or not res.content or #res.content < 1000 then
    LogToConsole("`4Fetch gagal! Size: " .. tostring(res and res.content and #res.content or 0))
    return
end

LogToConsole("`2Fetch OK: " .. #res.content .. " bytes")

local paths = {
    "/storage/emulated/0/zakicit.lua",
    "/storage/emulated/0/Download/zakicit.lua",
    (os.getenv("APPDATA") or "") .. "\\Growtopia\\scripts\\zakicit.lua",
    "zakicit.lua"
}

local saved = false
for _, p in ipairs(paths) do
    local f = io.open(p, "wb")
    if f then
        f:write(res.content)
        f:close()
        LogToConsole("`2Saved: " .. p .. " (" .. #res.content .. " bytes) — jalankan!")
        dofile(p)
        saved = true
        break
    end
end

if not saved then
    LogToConsole("`4Gagal tulis file di semua path!")
end
