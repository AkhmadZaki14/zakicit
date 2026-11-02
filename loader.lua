-- ============================================================
--  ZAKICIT LOADER v3 (In-Memory Execution, Anti-FC & Anti-Storage Bug)
-- ============================================================

local function RunLoader()
    LogToConsole("`2[Loader] Menghubungi GitHub...")

    -- 1. Ambil Commit Hash terbaru (User-Agent header agar tidak 403)
    local hash = nil
    local headers = { ["User-Agent"] = "BothaxClient/1.0" }
    local apiRes = MakeRequest("https://api.github.com/repos/AkhmadZaki14/zakicit/commits/main", "GET", headers)
    if apiRes and apiRes.content then
        local sha = apiRes.content:match('"sha"%s*:%s*"([%x]+)"')
        if sha then hash = sha:sub(1, 7) end
    end

    -- 2. Build URL (pakai hash bypass CDN, fallback ke main)
    local url
    if hash then
        url = "https://raw.githubusercontent.com/AkhmadZaki14/zakicit/" .. hash .. "/zakicit.lua"
        LogToConsole("`2[Loader] Commit SHA: " .. hash)
    else
        url = "https://raw.githubusercontent.com/AkhmadZaki14/zakicit/main/zakicit.lua?t=" .. tostring(os.time())
        LogToConsole("`3[Loader] Fallback ke main/")
    end

    -- 3. Download script ke RAM
    local res = MakeRequest(url, "GET")
    if not res or not res.content or #res.content < 1000 then
        LogToConsole("`4[Loader] Gagal download script! Size: " .. tostring(res and res.content and #res.content or 0))
        return
    end
    LogToConsole("`2[Loader] Download sukses (" .. #res.content .. " bytes), menjalankan script...")

    -- 4. Eksekusi langsung di memori RAM (tanpa sentuh storage / tanpa dofile agar tidak crash permission)
    local fn, err = nil, nil
    if loadstring then
        fn, err = loadstring(res.content)
    elseif load then
        fn, err = load(res.content)
    end

    if not fn then
        LogToConsole("`4[Loader] Error kompilasi script: " .. tostring(err))
        return
    end

    local ok, execErr = pcall(fn)
    if not ok then
        LogToConsole("`4[Loader] Runtime error saat eksekusi: " .. tostring(execErr))
    else
        LogToConsole("`2[Loader] ZAKICIT BERHASIL DIJALANKAN 100%!")
    end
end

-- Jalankan di dalam RunThread agar tidak membekukan main thread (Anti-ANR / Anti-Freeze)
if RunThread then
    RunThread(RunLoader)
else
    RunLoader()
end
