-- Loader v5: selalu pakai commit hash, tidak pernah kena CDN cache
local apiRes = MakeRequest("https://api.github.com/repos/AkhmadZaki14/zakicit/commits/main", "GET")
local hash = apiRes and apiRes.content and apiRes.content:match('"sha"%s*:%s*"(%x+)"')
if hash then hash = hash:sub(1, 7) end

-- URL utama: raw.githubusercontent.com via commit hash (bypass Fastly cache /main/)
-- URL fallback: jsDelivr via commit hash (bukan @main yang ter-cache lama)
local url
if hash then
    url = "https://raw.githubusercontent.com/AkhmadZaki14/zakicit/" .. hash .. "/zakicit.lua"
    LogToConsole("`2[Loader] Fetch hash: " .. hash)
else
    -- Hardcode hash terakhir yang diketahui valid sebagai darurat
    url = "https://raw.githubusercontent.com/AkhmadZaki14/zakicit/e468550/zakicit.lua"
    LogToConsole("`3[Loader] Hash gagal, pakai fallback hardcode e468550")
end

local res = MakeRequest(url, "GET")
if not res or not res.content or #res.content < 1000 then
    LogToConsole("`4[Loader] Fetch gagal! Size: " .. tostring(res and res.content and #res.content or 0))
    return
end

LogToConsole("`2[Loader] OK: " .. #res.content .. " bytes, build: " .. (res.content:match("BUILD: ([^\n]+)") or "?"))

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
        LogToConsole("`2[Loader] Saved: " .. p)
        dofile(p)
        saved = true
        break
    end
end

if not saved then
    LogToConsole("`4[Loader] Gagal tulis file!")
end
