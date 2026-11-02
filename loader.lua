-- ============================================================
--  ZAKICIT LOADER v4 (jsDelivr — auto-purge, no CDN cache issue)
-- ============================================================

local function RunLoader()
    LogToConsole("`2[Loader] Mengambil script dari jsDelivr...")

    -- jsDelivr: bisa di-purge, tidak ada Fastly cache lock seperti raw.githubusercontent.com
    -- ?t= timestamp agar tidak kena cache browser/proxy lokal
    local url = "https://cdn.jsdelivr.net/gh/AkhmadZaki14/zakicit@main/zakicit.lua?t=" .. tostring(os.time())

    local res = MakeRequest(url, "GET")
    if not res or not res.content or #res.content < 1000 then
        -- Fallback: raw.githubusercontent.com pakai commit hash
        LogToConsole("`3[Loader] jsDelivr gagal, fallback ke GitHub raw...")
        local headers = { ["User-Agent"] = "BothaxClient/1.0" }
        local apiRes = MakeRequest("https://api.github.com/repos/AkhmadZaki14/zakicit/commits/main", "GET", headers)
        local hash = nil
        if apiRes and apiRes.content then
            local sha = apiRes.content:match('"sha"%s*:%s*"([%x]+)"')
            if sha then hash = sha:sub(1, 7) end
        end
        local rawUrl = hash
            and ("https://raw.githubusercontent.com/AkhmadZaki14/zakicit/" .. hash .. "/zakicit.lua")
            or  ("https://raw.githubusercontent.com/AkhmadZaki14/zakicit/main/zakicit.lua")
        LogToConsole("`3[Loader] Fallback URL: " .. rawUrl)
        res = MakeRequest(rawUrl, "GET")
    end

    if not res or not res.content or #res.content < 1000 then
        LogToConsole("`4[Loader] GAGAL total! Size: " .. tostring(res and res.content and #res.content or 0))
        return
    end

    LogToConsole("`2[Loader] Download sukses (" .. #res.content .. " bytes), menjalankan...")

    local fn, err = nil, nil
    if loadstring then
        fn, err = loadstring(res.content)
    elseif load then
        fn, err = load(res.content)
    end

    if not fn then
        LogToConsole("`4[Loader] Syntax error: " .. tostring(err))
        return
    end

    local ok, execErr = pcall(fn)
    if not ok then
        LogToConsole("`4[Loader] Runtime error: " .. tostring(execErr))
    else
        LogToConsole("`2[Loader] ZAKICIT BERHASIL DIJALANKAN!")
    end
end

if RunThread then
    RunThread(RunLoader)
else
    RunLoader()
end
