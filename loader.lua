-- Ambil hash commit terbaru dulu via GitHub API
local apiRes = MakeRequest("https://api.github.com/repos/AkhmadZaki14/zakicit/commits/main", "GET")
local hash = nil
if apiRes and apiRes.content then
    hash = apiRes.content:match('"sha"%s*:%s*"(%x+)"')
    if hash then hash = hash:sub(1, 7) end
end

local url
if hash then
    url = "https://raw.githubusercontent.com/AkhmadZaki14/zakicit/" .. hash .. "/zakicit.lua"
    LogToConsole("`2Fetch pakai commit hash: " .. hash)
else
    -- Fallback ke jsDelivr (bisa di-purge, bukan Fastly GitHub)
    url = "https://cdn.jsdelivr.net/gh/AkhmadZaki14/zakicit@main/zakicit.lua?t=" .. tostring(os.time())
    LogToConsole("`3Hash gagal, fallback ke jsDelivr")
end

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
        LogToConsole("`2Saved: " .. p .. " (" .. #res.content .. " bytes)")
        dofile(p)
        saved = true
        break
    end
end

if not saved then
    LogToConsole("`4Gagal tulis file!")
end
