-- ZAKICIT LOADER v2 — fetch via commit hash agar bypass CDN Fastly GitHub
-- GitHub CDN ignore query string ?v=, harus pakai commit hash di URL path

-- Step 1: Ambil commit hash terbaru via GitHub API
local apiRes = MakeRequest("https://api.github.com/repos/AkhmadZaki14/zakicit/commits/main", "GET")
local hash = nil
if apiRes and apiRes.content then
    hash = apiRes.content:match('"sha":"(%x+)"')
    if hash then hash = hash:sub(1, 7) end
end

-- Step 2: Build URL pakai hash (bypass CDN) atau fallback ke main
local url
if hash then
    url = "https://raw.githubusercontent.com/AkhmadZaki14/zakicit/" .. hash .. "/zakicit.lua"
    LogToConsole("`2[Loader] Fetch pakai commit hash: " .. hash)
else
    url = "https://raw.githubusercontent.com/AkhmadZaki14/zakicit/main/zakicit.lua"
    LogToConsole("`3[Loader] Fallback ke main/ (API gagal)")
end

-- Step 3: Fetch script
local res = MakeRequest(url, "GET")
if not res or not res.content or #res.content < 1000 then
    LogToConsole("`4[Loader] Fetch gagal! Size: " .. tostring(res and res.content and #res.content or 0))
    return
end
LogToConsole("`2[Loader] Fetch OK: " .. #res.content .. " bytes")

-- Step 4: Tulis ke disk dan jalankan
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
        LogToConsole("`2[Loader] Saved: " .. p .. " (" .. #res.content .. " bytes) -> dofile")
        dofile(p)
        saved = true
        break
    end
end

if not saved then
    LogToConsole("`4[Loader] Gagal tulis file di semua path!")
end
