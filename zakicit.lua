-- ============================================================
--  ZAKICIT PNB v2 -- Ultimate Consolidated Edition
--  BUILD: 2026-11-04T00:00:00 CONSUMABLE_VEND_OK PATH_FIX2 RENT_GUARD_FIX VEND_FIX2
--  The Continental Architecture + Bothax/Dederika Features + Web Monitor
--  API List required: io, MakeRequest, ImGui
-- ============================================================
local BUILD_ID = "1104-0648"

-- ------------------------------------------------------------
--  STATE & SETTINGS
-- ------------------------------------------------------------
Setting = {
    PNB = {
        WearItem          = "Mythical Necklace",
        AutoCollectGems   = true,
        AutoChangeRemote  = true,  -- [2e] Default true sesuai perilaku lama bot
        AutoConsumables   = true,
        AutoBuyWL         = false,
        ConvertDLBGL      = false,
        ConvertBGL        = false,
        MaxGems           = 400000,
        HideCollected     = false,
        AutoBuyCheats     = true,
        AutoRadio         = true,
        AutoSuckBgems     = true,
        Modfly            = true,
        BypassPaywall     = false,   -- [17] default false
        BypassWayBlock    = false,   -- [17] default false
        -- Fitur baru
        FaceRight         = false,   -- hadap kanan saat farming BFG
        AntiLag           = false,   -- skip heavy render (FC prevention)
        IgnoreOther       = false,   -- abaikan player lain
        EnableMonitor     = true,    -- remote monitoring aktif by default
        ScanBG            = false,   -- filter magplant berdasarkan background ID
        MagBgID           = 0,       -- ID background target magplant
        AutoPaywall       = false,   -- aktifkan fitur cek/sensor paywall
        AutoRenewPaywall  = false,   -- auto renew sebelum habis (timer ~2 menit sebelum expire)
        AutoBuyPaywall    = false,   -- auto beli ulang kalau dicabut paksa / expired mendadak
        RentTargetItem    = "Auto-Detect", -- Item sewa yang diharapkan (LSS, MRay, LRay, Auto-Detect)
        AutoRent          = false,   -- auto rent mray/item dari renting station
        RentWorld         = "",      -- world renting station
        MonitorToken      = "",      -- [8] Token remote monitor (X-Monitor-Token)
        SendToWebhook     = false,   -- [14, 16] Webhook toggle
        WebhookURL        = "",      -- [14] URL discord webhook
        StuckMinutes      = 10,      -- [16a] Stuck detector menit
        -- Consumable restocking
        BuyConsumables    = false,   -- aktifkan beli consumable dari vending
        BuyConsumeArroz   = true,    -- beli Arroz Con Pollo (4604)
        BuyConsumeClover  = true,    -- beli Four-Leaf Clover (528)
        BuyConsumeSong    = false,   -- beli Songpyeon (1056)
        BuyConsumeWorld   = "",      -- world vending ("" = world farming)
        BuyConsumeMaxPrice= 10,      -- harga max per item (WL)
        BuyConsumeAmount  = 200,     -- jumlah beli per transaksi
        BuyConsumeTries   = 10,      -- max retry per item sebelum skip
        BuyConsumeMaxTotal= 500,     -- max total WL per transaksi (harga ? jumlah beli)
        DebugVend         = false,   -- log field tile.extra vending pertama
    },
    World     = "",
    PosX      = 0,
    PosY      = 0,
    MagplantX = 0,
    MagplantY = 0,
    TelX      = 0,
    TelY      = 0,
    PaywallX  = 0,
    PaywallY  = 0,
    RentX     = 0,
    RentY     = 0,
    RentStandX= 0,
    RentStandY= 0,
    Delay     = {},
    DelayBuyCheat      = 30,
}
local S = Setting

local DelayDefault = {
    Scale        = 100,
    Loop         = 1000,
    Join         = 5000,
    PathStep     = 450,
    RemoteStep   = 500,
    RemoteDialog = 800,
    AfterRemote  = 1000,
    Switch       = 1200,
    PreMove      = 1500,
    PostMove     = 1500,
    CheatOn      = 1500,
    Consume      = 2000,
    FaceDelay    = 250,  -- [17c]
    PlaceDelay   = 200,  -- [17c]
    ShortDelay   = 150,  -- [17c]
}
for k, v in pairs(DelayDefault) do S.Delay[k] = v end

local function D(key)
    local base = tonumber(S.Delay[key]) or DelayDefault[key] or 1000
    local scale = (tonumber(S.Delay.Scale) or 100) / 100
    return math.max(0, math.floor(base * scale))
end

local Run = {
    start      = false,
    startTime  = 0,
    status     = "Idle",
}

local worldName     = ""
local changeRemote  = false
local m             = false
local TOP_UP        = false
local ConsumeTime   = 0
local LastConvert   = 0
local LastBuyCheat  = 0
local savePathUsed  = ""
local blockSB       = false
local Mag           = {}
local CheatNeedsRenewal = false -- [3] Flag jika cheat expired terdeteksi dari console
local PaywallExpires   = 0  -- kapan akses paywall habis
local CapturePaywall   = false  -- flag: punch berikutnya set PaywallX/Y
local CaptureTel       = false  -- [11] flag: punch berikutnya set TelX/Y
local CaptureFarmPos   = false  -- flag: punch berikutnya set PosX/Y farm
local LastPaywallCheck = 0  -- kapan terakhir wrench untuk cek/renew

-- [7b, 9, 11, 14, 16] State Baru
local PendingPath      = nil    -- { x, y } dieksekusi di Step
local JoinFail         = 0
local LastJoinAttempt  = 0
local StuckGems        = 0
local StuckGemTime     = 0
local StuckCount       = 0
local PosCheckCounter  = 0
local Disconnected     = false
local ConsecErrors     = 0

-- RENT STATE
local RentExpires     = 0     -- kapan durasi sewa habis
local RentEquipped    = false -- apakah item sewaan sedang terpasang di badan
local RentChecking    = false -- flag sedang dalam proses cek sisa sewa
local BotTriggeredWrench = false -- true = bot yang kirim wrench (silent), false = user manual klik wrench
local RentWarActive   = false -- flag sedang dalam mode spam war sewa
local CaptureRent     = false -- flag: punch berikutnya set RentX/Y
local LastRentCheck   = 0     -- kapan terakhir cek sisa sewa (self-wrench)
local RentClothBtn    = ""    -- tombol cloth, misal "cloth_-258"
local RentItemId      = ""    -- ID icon item sewaan, misal 16690
local RentLastToggle  = 0     -- timestamp kapan terakhir kali klik tombol cloth (anti ajep-ajep)
local RentWtb         = ""    -- token wtb dari dialog rent_buyconfirm
local RentSuccess     = false -- konfirmasi sewa sukses dari console
local RentStep        = "IDLE"-- state machine: IDLE | WAIT_BUY | WAIT_CONFIRM | WAIT_RESULT | DONE
local RentStepTime    = 0     -- waktu saat berpindah ke state terbaru

-- ------------------------------------------------------------
--  UTIL
-- ------------------------------------------------------------
local LogBuf = {}

local function StripColor(s)
    s = tostring(s or "")
    s = s:gsub("`.", "")
    return s
end

local function Stamp()
    local ok, t = pcall(os.date, "%H:%M:%S")
    return ok and t or "--:--:--"
end

function Log(x)
    LogToConsole("`0[`4ZAKICIT`0] " .. tostring(x))
    if #LogBuf >= 50 then
        local newBuf = {}
        for i = 25, #LogBuf do table.insert(newBuf, LogBuf[i]) end
        LogBuf = newBuf
    end
    table.insert(LogBuf, Stamp() .. "  " .. StripColor(x))
end

local function NowTime()
    local ok, t = pcall(os.time)
    return ok and t or 0
end

local function ValidWebhook(url) return false end
local function WebhookNotify(eventType, detail) end

-- [WA ALERT] Kirim notif ke WhatsApp via Fonnte langsung dari bot (non-blocking via RunThread)
local FONNTE_TOKEN  = "J458dV68YKaGXJ6h3bPJ"
local FONNTE_TARGET = "120363429381553519@g.us"
local WAAlertLimit  = {}
local function SendWhatsAppAlert(alasan, detail)
    local now = NowTime()
    if WAAlertLimit[alasan] and (now - WAAlertLimit[alasan] < 180) then return end
    WAAlertLimit[alasan] = now
    RunThread(function()
        local me = GetLocal and GetLocal()
        local botName = (me and me.name and StripColor(me.name)) or "Bot"
        local world = (worldName ~= "" and worldName) or "?"
        local pesan = string.format(
            "?? [%s] di %s\nAlasan: %s\nDetail: %s\nBot TIDAK dimatikan -- auto-recovery aktif.",
            botName, world, alasan, tostring(detail or "-"))
        pcall(MakeRequest, "https://api.fonnte.com/send", "POST", {
            ["Authorization"] = FONNTE_TOKEN,
            ["Content-Type"]  = "application/json",
        }, string.format('{"target":"%s","message":%q}', FONNTE_TARGET, pesan))
    end)
    Log("`3[WA Alert]`w " .. alasan)
end

local function inv(id)
    local count = 0
    for _, itm in pairs(GetInventory() or {}) do
        if itm.id == id then count = count + itm.amount end
    end
    return count
end

local function Gems()
    local ok, info = pcall(GetPlayerInfo)
    if ok and info then return info.gems or 0 end
    return 0
end

local function FNum(n)
    n = tonumber(n) or 0
    if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
    if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
    if n >= 1e3 then return string.format("%.0fK", n / 1e3) end
    return tostring(math.floor(n))
end

local function FTime(sec)
    sec = math.max(0, math.floor(sec))
    local d = math.floor(sec / 86400)
    local rem = sec % 86400
    local h = math.floor(rem / 3600)
    local mi = math.floor((rem % 3600) / 60)
    local s = rem % 60
    if d > 0 then
        return string.format("%dd %02d:%02d:%02d", d, h, mi, s)
    end
    return string.format("%02d:%02d:%02d", h, mi, s)
end

local function Esc(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("[\r\n]", " ")
    return s
end

-- [6a] Escape JSON string lengkap: backslash, kutip, \r, \n, \t, dan control chars
local function JsonEsc(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\r", "\\r")
    s = s:gsub("\n", "\\n")
    s = s:gsub("\t", "\\t")
    s = s:gsub("%c", function(c) return string.format("\\u%04x", c:byte()) end)
    return s
end

-- [2b] Parser JSON terstruktur untuk respons heartbeat (flat object + array sharedMags)
local function ParseJsonSharedMags(text)
    local ok, result
    if json and json.decode then
        ok, result = pcall(json.decode, text)
        if ok and type(result) == "table" and type(result.sharedMags) == "table" then
            return result.sharedMags
        end
    end
    if JSON and JSON.decode then
        ok, result = pcall(JSON.decode, JSON, text)
        if ok and type(result) == "table" and type(result.sharedMags) == "table" then
            return result.sharedMags
        end
    end
    -- Fallback extractor array objek sharedMags
    local list = {}
    local arr = text:match('"sharedMags"%s*:%s*%[(.-)%]')
    if arr then
        for block in arr:gmatch("%{([^%}]+)%}") do
            local item = {}
            for k, v in block:gmatch('"([^"]+)"%s*:%s*"([^"]*)"') do item[k] = v end
            for k, v in block:gmatch('"([^"]+)"%s*:%s*(%-?%d+%.?%d*)') do item[k] = tonumber(v) end
            if block:find('"empty"%s*:%s*true') then item.empty = true
            elseif block:find('"empty"%s*:%s*false') then item.empty = false end
            list[#list + 1] = item
        end
    end
    return list
end

local function ParseJsonFlat(text)
    local ok, result
    if json and json.decode then
        ok, result = pcall(json.decode, text)
        if ok and result then return result end
    end
    if JSON and JSON.decode then
        ok, result = pcall(JSON.decode, JSON, text)
        if ok and result then return result end
    end
    -- Fallback: flat key extractor (string/number/bool)
    local t = {}
    for k, v in text:gmatch('"([^"]+)"%s*:%s*"([^"]*)"') do t[k] = v end
    for k, v in text:gmatch('"([^"]+)"%s*:%s*(%-?%d+%.?%d*)') do t[k] = tonumber(v) end
    for k in text:gmatch('"([^"]+)"%s*:%s*true') do t[k] = true end  -- [2b] Lua tidak support alternasi |
    for k in text:gmatch('"([^"]+)"%s*:%s*false') do t[k] = false end
    return t
end

local function WorldNow()
    local w = GetWorld()
    if w and w.name then return w.name:upper() end
    return nil
end

-- ------------------------------------------------------------
--  GAME ACTIONS & BYPASS RULES
-- ------------------------------------------------------------
local ALLOWED_BLOCKS = { [0] = true, [3898] = true, [15858] = true }
local BLOCKED_BLOCKS = { [3796] = true }

local function UpdateBypassRules()
    if S.PNB.BypassPaywall then
        ALLOWED_BLOCKS[16308] = true
        BLOCKED_BLOCKS[16308] = nil
    else
        ALLOWED_BLOCKS[16308] = nil
        BLOCKED_BLOCKS[16308] = true
    end
    if S.PNB.BypassWayBlock then
        ALLOWED_BLOCKS[3796] = true
        BLOCKED_BLOCKS[3796] = nil
    else
        ALLOWED_BLOCKS[3796] = nil
        BLOCKED_BLOCKS[3796] = true
    end
end

local function Join(w)
    SendPacket(3, "action|join_request\nname|" .. w .. "\ninvitedWorld|0")
end

local function Cheat(on)
    local v = on and 1 or 0
    local fly = (S.PNB.Modfly and on) and 1 or 0
    SendPacket(2, string.format(
        "action|dialog_return\ndialog_name|cheats\ncheck_autofarm|%d\ncheck_bfg|%d\ncheck_modfly|%d\ncheck_autobuff|%d\ncheck_autoremote|%d\ncheck_lonely|0\ncheck_ignoreo|%d\ncheck_gems|%d",
        v, v, fly,
        (on and 1 or 0),   -- check_autobuff (if toggled separately, use S.PNB.AutoBuff)
        (on and 1 or 0),   -- check_autoremote (if toggled separately, use S.PNB.AutoRemote)
        (S.PNB.IgnoreOther and 1 or 0),
        (S.PNB.AutoCollectGems and 1 or 0)))
end

local function IsTileWalkable(x, y)
    local w = GetWorld()
    if not w then return false end
    local mw = w.width or 100
    local mh = w.height or 60
    if x < 0 or x >= mw or y < 0 or y >= mh then return false end

    local t = GetTile(x, y)
    if not t then return false end

    local id = t.fg or 0
    if BLOCKED_BLOCKS[id] then return false end

    -- Gunakan CheckPath bawaan C++ Bothax sebagai penentu utama
    if CheckPath then
        local ok, walkable = pcall(CheckPath, x, y)
        if ok then return walkable == true end
    end

    -- Validasi collidable bawaan struct Tile Bothax
    if t.collidable == true and not ALLOWED_BLOCKS[id] then
        return false
    end

    if t.flags and t.flags.locked then return false end
    if id == 0 or ALLOWED_BLOCKS[id] then return true end
    return false
end

-- [12b] Integer hash key: pakai w.width nyata, fallback 100
local function K(x, y)
    local w = GetWorld()
    local mw = (w and w.width) or 100
    return y * mw + x
end

local _NB = {{0,-1},{0,1},{-1,0},{1,0}} -- reuse tabel neighbor, no alloc

-- Binary heap helpers (min-heap by .f)
local function heap_push(heap, node)
    heap[#heap + 1] = node
    local i = #heap
    while i > 1 do
        local p = math.floor(i / 2)
        if heap[p].f <= heap[i].f then break end
        heap[p], heap[i] = heap[i], heap[p]
        i = p
    end
end
local function heap_pop(heap)
    local top = heap[1]
    local n = #heap
    heap[1] = heap[n]
    heap[n] = nil
    local i, size = 1, n - 1
    while true do
        local l, r, smallest = i * 2, i * 2 + 1, i
        if l <= size and heap[l].f < heap[smallest].f then smallest = l end
        if r <= size and heap[r].f < heap[smallest].f then smallest = r end
        if smallest == i then break end
        heap[i], heap[smallest] = heap[smallest], heap[i]
        i = smallest
    end
    return top
end

local function FindSafePath(sx, sy, tx, ty, maxIter)
    maxIter = maxIter or 3000
    local openHeap, openMap, closed, from = {}, {}, {}, {}
    local gScore = {}
    local function h(x, y) return math.abs(x-tx)+math.abs(y-ty) end
    local sk = K(sx, sy)
    local startNode = { x=sx, y=sy, g=0, f=h(sx,sy) }
    heap_push(openHeap, startNode)
    openMap[sk] = startNode
    gScore[sk] = 0
    local iter = 0
    while #openHeap > 0 and iter < maxIter do
        iter = iter + 1
        local best = heap_pop(openHeap)
        local bk = K(best.x, best.y)
        openMap[bk] = nil
        if best.x == tx and best.y == ty then
            -- reconstruct path tanpa table.insert(path, 1, ...) O(n^2)
            local path, cur, len = {}, best, 0
            while cur do
                len = len + 1
                path[len] = cur
                cur = from[K(cur.x, cur.y)]
            end
            local rev = {}
            for i = len, 1, -1 do rev[len - i + 1] = path[i] end
            return rev
        end
        closed[bk] = true
        local bx, by = best.x, best.y
        for i = 1, 4 do
            local nx, ny = bx + _NB[i][1], by + _NB[i][2]
            local nk = K(nx, ny)
            if not closed[nk] and IsTileWalkable(nx, ny) then
                local g = best.g + 1
                if not gScore[nk] or g < gScore[nk] then
                    gScore[nk] = g
                    from[nk] = best
                    local node = { x=nx, y=ny, g=g, f=g+h(nx,ny) }
                    openMap[nk] = node
                    heap_push(openHeap, node)
                end
            end
        end
    end
    return nil
end

local function SlowFindPath(tx, ty, stepDelay)
    stepDelay = stepDelay or D("PathStep")
    local me = GetLocal()
    if not me then return end
    local cx = math.floor(me.pos.x / 32)
    local cy = math.floor(me.pos.y / 32)
    if cx == tx and cy == ty then return end

    local path = FindSafePath(cx, cy, tx, ty)
    if path and #path > 0 then
        -- Step per node A* -- bot ngikut jalur aman, bukan teleport lurus
        -- Skip node pertama (posisi sekarang), mulai dari index 2
        for i = 2, #path do
            local pt = path[i]
            FindPath(pt.x, pt.y)
            Sleep(stepDelay)
            -- Early exit kalau bot sudah sampai tujuan
            local cur = GetLocal()
            if cur and cur.pos then
                local nx = math.floor(cur.pos.x / 32)
                local ny = math.floor(cur.pos.y / 32)
                if nx == tx and ny == ty then break end
            end
        end
    else
        -- Fallback: jalan langsung ke target
        FindPath(tx, ty)
        Sleep(stepDelay)
    end
end

local function Raw(a, b, c, d, e)
    SendPacketRaw(false, {
        type = a, state = b, value = c, px = d, py = e,
        x = TOP_UP and (d * 32 - 2) or (d * 32),
        y = TOP_UP and (e * 32 - 2) or (e * 32),
    })
end

local function FindTPLeft(x, y)
    SendPacketRaw(false, { state = 48, x = x * 32, y = y * 32, px = x, py = y })
end

local function FindTPRight(x, y)
    SendPacketRaw(false, { state = 32, x = x * 32, y = y * 32, px = x, py = y })
end

local function ActiveLag(val)
    pcall(ChangeValue, "[C] No render name", val)
    pcall(ChangeValue, "[C] No render particle", val)
    pcall(ChangeValue, "[C] No render shadow", val)
    pcall(ChangeValue, "[C] No render world", val)
    pcall(ChangeValue, "[C] No render object", val)
    pcall(ChangeValue, "[C] No render player", val)
end

-- [18] Wrench(x,y) dihapus; pertahankan WrenchTile
-- Wrench tile langsung via koordinat absolut (tanpa offset relatif dari player)
local function WrenchTile(tx, ty)
    local pkt = {
        type = 3,
        value = 32,
        px = tx,
        py = ty,
        x = tx * 32,
        y = ty * 32
    }
    SendPacketRaw(false, pkt)
end

-- Place remote + showhand (animasi tangan ayun) ke tile target
-- Pakai contoh resmi dari dokumentasi Bothax:
--   pkt.x = player position, pkt.px = target tile
local function PlaceShowHand(tx, ty)
    pcall(SetItemSelected, 5640)
    local me = GetLocal()
    if not me or not me.pos then return end
    -- Place packet dengan posisi player di x/y
    SendPacketRaw(false, {
        type = 3,
        value = 5640,
        px = tx,
        py = ty,
        x = me.pos.x,
        y = me.pos.y
    })
    -- Trigger touch fisik di Bothax (animasi swing / showhand)
    if SendWorldTouch and Vector2 then
        local vpos = Vector2(tx * 32 + 16, ty * 32 + 16)
        pcall(SendWorldTouch, vpos, true)
        pcall(SendWorldTouch, vpos, false)
    end
end

-- ------------------------------------------------------------
--  SMART MAG INTEL & SHARDED KNOWLEDGE (TTL + Advisory)
-- ------------------------------------------------------------
local MagIntel = {}       -- [key] = { empty = bool, expires = ts, source = "local"|"shared" }
local PendingMagSync = {} -- daftar perubahan untuk dikirim ke Vercel
local MAG_TTL_SEC = 300   -- 5 menit cooldown mag kosong sebelum auto-unban / re-check
local LastDialogEmpty = false

local function MagKey(x, y, w)
    w = (w and w ~= "") and w:upper() or ((worldName and worldName ~= "") and worldName:upper() or "NOWORLD")
    return w .. ":" .. tostring(x) .. "," .. tostring(y)
end

local function MarkMagEmpty(x, y, ttl, source, w)
    if not x or not y then return end
    ttl = ttl or MAG_TTL_SEC
    local key = MagKey(x, y, w)
    local exp = NowTime() + ttl
    MagIntel[key] = { empty = true, expires = exp, source = source or "local" }
    if source ~= "shared" then
        local wField = (w and w ~= "") and w:upper() or ((worldName and worldName ~= "") and worldName:upper() or "NOWORLD")
        PendingMagSync[key] = { world = wField, x = tonumber(x), y = tonumber(y), empty = true, ttl = ttl }
    end
end

local function MarkMagReady(x, y, count, source, w)
    if not x or not y then return end
    count = tonumber(count) -- nil jika tidak diketahui (jangan nebak 200k)
    local key = MagKey(x, y, w)
    MagIntel[key] = { empty = false, count = count, expires = 0, source = source or "local" }
    if source ~= "shared" then
        local wField = (w and w ~= "") and w:upper() or ((worldName and worldName ~= "") and worldName:upper() or "NOWORLD")
        PendingMagSync[key] = { world = wField, x = tonumber(x), y = tonumber(y), empty = false, count = count }
    end
end

local function IsMagCooldown(x, y, w)
    local key = MagKey(x, y, w)
    local info = MagIntel[key]
    if not info or not info.empty then return false, 0 end
    local rem = info.expires - NowTime()
    if rem <= 0 then
        -- TTL habis! Auto-unban: boleh dicek ulang (siapa tahu sudah di-refill)
        info.empty = false
        return false, 0
    end
    return true, rem, info.source
end

-- Kompatibilitas tabel MagEmpty (pakai MagKey dengan worldName)
local MagEmpty = setmetatable({}, {
    __index = function(_, k)
        local w, x, y = k:match("^([^:]+):(%d+),(%d+)$")
        if not w then
            x, y = k:match("^(%d+),(%d+)$")
        end
        if x and y then
            local cd = IsMagCooldown(tonumber(x), tonumber(y), w)
            return cd
        end
        return false
    end,
    __newindex = function(_, k, v)
        local w, x, y = k:match("^([^:]+):(%d+),(%d+)$")
        if not w then
            x, y = k:match("^(%d+),(%d+)$")
        end
        if x and y then
            if v then MarkMagEmpty(tonumber(x), tonumber(y), MAG_TTL_SEC, "local", w)
            else MarkMagReady(tonumber(x), tonumber(y), nil, "local", w) end
        end
    end
})

local WearIDs = {
    ["Mythical Necklace"]       = 15748,
    ["Mythical Infinity Fist"]  = 15730,
    ["Legendary Infinity Fist"] = 15694,
    ["Legendary Shard Sword"]   = 15444,
}
local WearList = {
    "Mythical Necklace", "Mythical Infinity Fist",
    "Legendary Infinity Fist", "Legendary Shard Sword",
}

local wornItem = nil -- [4] Menyimpan item yang saat ini terpasang (anti toggle type 10)

local function Wear(item)
    local id = WearIDs[item]
    if not id then return end
    if wornItem == item then return end -- Jangan kirim ulang jika item sama
    SendPacketRaw(false, { type = 10, value = id })
    wornItem = item
    TOP_UP = (item == "Mythical Necklace")
end

-- Auto Find Magplant: cari fg=5638 di world (dengan opsi filter ScanBG)
local function GetMag()
    local list = {}
    local w = GetWorld()
    if not w then return list end
    local maxX, maxY = w.width - 1, w.height - 1
    local filterBg = S.PNB.ScanBG and tonumber(S.PNB.MagBgID) or nil
    for y = 0, maxY do
        for x = 0, maxX do
            local t = GetTile(x, y)
            if t and t.fg == 5638 then
                if not filterBg or t.bg == filterBg then
                    table.insert(list, { x = x, y = y })
                end
            end
        end
    end
    return list
end

-- Urutkan magplant berdasarkan jarak ke farm pos
local function SortMagByDistance(magList, fx, fy)
    table.sort(magList, function(a, b)
        local da = math.abs(a.x - fx) + math.abs(a.y - fy)
        local db = math.abs(b.x - fx) + math.abs(b.y - fy)
        return da < db
    end)
    return magList
end

-- Cari tile walkable di sebelah magplant (adjacent)
local function FindAdjacent(tx, ty)
    -- Prioritas: atas, kanan, bawah, kiri
    local offsets = {
        { x = 0, y = -1 },
        { x = 1, y = 0 },
        { x = 0, y = 1 },
        { x = -1, y = 0 },
    }
    for _, o in ipairs(offsets) do
        local ax, ay = tx + o.x, ty + o.y
        local t = GetTile(ax, ay)
        local notSecret = (function() local ok,s = pcall(function() return t and t.isSecret end); return (ok and s or 0) == 0 end)() -- VERIFY isSecret
        if t and t.fg == 0 and notSecret and IsTileWalkable(ax, ay) then
            return ax, ay
        end
    end
    -- Fallback: coba semua arah walkable
    for dy = -2, 2 do
        for dx = -2, 2 do
            if dx ~= 0 or dy ~= 0 then
                local ax, ay = tx + dx, ty + dy
                local t = GetTile(ax, ay)
                local notSecret = (function() local ok,s = pcall(function() return t and t.isSecret end); return (ok and s or 0) == 0 end)() -- VERIFY isSecret
                if t and t.fg == 0 and notSecret and IsTileWalkable(ax, ay) then
                    return ax, ay
                end
            end
        end
    end
    return nil
end

local function RecalcMag()
    Mag = GetMag()  -- auto find semua fg=5638
    Mag = SortMagByDistance(Mag, S.PosX, S.PosY)  -- urut jarak ke farm pos
    if #Mag == 0 then
        Log("`4Tidak ada magplant ditemukan di world ini!")
        return
    end
    Log("`2Auto-find magplant: " .. #Mag .. " ditemukan (paling dekat dulu)")
end

local function GetNextMag()
    if #Mag == 0 then RecalcMag() end
    local now = NowTime()

    local function magTier(mp)
        local key = MagKey(mp.x, mp.y)
        local info = MagIntel[key]
        if not info then return 1 end
        if not info.empty then return 1 end
        local rem = info.expires - now
        if rem <= 0 then return 2 end
        if info.source == "shared" then return 3 end
        return 4
    end

    local function magDist(mp)
        return math.abs(mp.x - S.PosX) + math.abs(mp.y - S.PosY)
    end

    -- Cari tier 1 / tier 2 dulu; tier 3 hanya jika tak ada 1/2; tier 4 diskip
    local best12, best12Dist = nil, 9999
    local best12Tier = 99
    local best3, best3Dist = nil, 9999

    for _, mp in ipairs(Mag) do
        local tier = magTier(mp)
        local dist = magDist(mp)
        if tier == 1 or tier == 2 then
            if tier < best12Tier or (tier == best12Tier and dist < best12Dist) then
                best12Tier = tier
                best12Dist = dist
                best12 = mp
            end
        elseif tier == 3 then
            if dist < best3Dist then
                best3Dist = dist
                best3 = mp
            end
        end
    end

    return best12 or best3
end

local function FetchRemote()
    if inv(5640) > 0 and not changeRemote then return end
    Cheat(false)
    Sleep(D("RemoteStep"))

    if #Mag == 0 then RecalcMag() end
    if #Mag == 0 then
        Log("`4[SmartMag]`w Tidak ada magplant terdeteksi di world ini! Kirim WA alert & menunggu...")
        pcall(SendWhatsAppAlert, "Tidak Ada Magplant", "Bot tidak mendeteksi ada Magplant (fg=5638) di world ini. Bot standby menunggu mag dipasang.")
        Run.status = "Tidak Ada Mag (Wait)"
        Sleep(30000)
        return
    end

    local maxAttempts = math.min(#Mag, 20)
    local attempt = 0

    while attempt < maxAttempts do
        attempt = attempt + 1
        local target = GetNextMag()
        if not target then
            Log("`4[SmartMag]`w SEMUA MAGPLANT DI WORLD INI KOSONG! Menunggu restock...")
            Run.status = "Semua Mag Kosong (Wait)"
            Cheat(false)
            pcall(SendWhatsAppAlert, "Semua Magplant Kosong", "Seluruh magplant kosong atau cooldown. Bot standby menunggu restock (TIDAK dimatikan).")
            pcall(WebhookNotify, "semua_mag_kosong", "Semua mag kosong di world " .. worldName)
            Sleep(30000)
            MagIntel = {} -- Reset intel agar coba re-scan setelah delay
            return
        end

        S.MagplantX = target.x
        S.MagplantY = target.y
        local key = MagKey(target.x, target.y)

        local ax, ay = FindAdjacent(target.x, target.y)
        if not ax then ax, ay = target.x, target.y - 1 end

        Log(string.format("`9[SmartMag]`w Menuju magplant (%d, %d)...", target.x, target.y))
        SlowFindPath(ax, ay, D("PathStep"))
        Sleep(D("RemoteStep"))

        LastDialogEmpty = false
        WrenchTile(target.x, target.y)
        Sleep(D("RemoteStep"))

        -- Request remote via dialog return
        SendPacket(2, string.format("action|dialog_return\ndialog_name|magplant_edit\nx|%d|\ny|%d|\nbuttonClicked|getRemote", target.x, target.y))
        Sleep(D("RemoteDialog"))

        -- Evaluasi hasil dialog & inventory
        if LastDialogEmpty or MagEmpty[key] then
            Log(string.format("`4[SmartMag]`w Mag (%d, %d) KOSONG! Langsung cari mag lain...", target.x, target.y))
            MagEmpty[key] = true
            -- Lanjut loop while ke mag berikutnya
        else
            Sleep(D("AfterRemote"))
            if inv(5640) > 0 then
                local curCount = MagIntel[key] and MagIntel[key].count
                local countTxt = curCount and tostring(curCount) or "tidak diketahui"
                Log(string.format("`2[SmartMag]`w Remote diambil dari (%d, %d)! Stok: %s. Lapor siap panen!", target.x, target.y, countTxt))
                MarkMagReady(target.x, target.y, curCount, "local")
                S.MagplantX = target.x
                S.MagplantY = target.y
                changeRemote = false
                m = false
                return
            else
                -- Kalau belum masuk tas, kemungkinan kosong/gagal klik
                Log(string.format("`3[SmartMag]`w Remote tidak masuk dari (%d, %d). Tandai kosong.", target.x, target.y))
                MagEmpty[key] = true
            end
        end
    end

    if inv(5640) == 0 then
        Log("`4[SmartMag]`w Semua opsi magplant telah dicoba dan habis! Menunggu 20 detik...")
        Run.status = "Semua Mag Dicoba (Wait)"
        Cheat(false)
        pcall(SendWhatsAppAlert, "Semua Opsi Mag Habis", "Semua magplant telah dicoba dan tas belum dapat remote. Bot standby retry.")
        Sleep(20000)
        MagIntel = {}
    end
end

local function BuyCheat()
    if not S.PNB.AutoBuyCheats then return end
    local now = NowTime()
    local delaySec = (tonumber(S.DelayBuyCheat) or 30) * 60
    if LastBuyCheat > 0 and now - LastBuyCheat < delaySec then return end
    LastBuyCheat = now
    Log("`9[Cheat]`w Memperpanjang / Membeli Cheats menu...")
    SendPacket(2, "action|dialog_return\ndialog_name|buycheat\ndialog_name|cheats\nbuttonClicked|1\n")
    -- Auto-recover: paksa Step() panggil Cheat(true) lagi dan re-place showhand
    m = false
    changeRemote = false
end

local LastRestockCheck = 0
local LastSuckBgem = 0
local function SuckBgems()
    if not S.PNB.AutoSuckBgems then return end
    -- Jangan saat sedang CheckRentStatus (popup self-wrench sedang terbuka)
    if RentChecking then return end
    local now = NowTime()
    if now - LastSuckBgem < 5 then return end
    LastSuckBgem = now
    pcall(function()
        if GetObjectList then
            local count = 0
            for _, o in pairs(GetObjectList()) do
                if o.id == 16750 or o.id == 11550 then
                    count = count + (o.amount or 1)
                end
            end
            if count >= 10000 then
                SendPacket(2, "action|dialog_return\ndialog_name|popup\nbuttonClicked|bgem_suckall\n")
            end
        end
    end)
end

-- ?? Consumable restock via vending ???????????????????????????
-- State untuk intercept dialog vending (dipakai di OnVariant hook)
local _VendPending   = nil
local _VendConfirm   = nil
local _VendBought    = false
local _VendFailed    = {}
local _RestockRunning = false  -- guard: cegah TakeConsumes jalan dobel

local function _BuildConsumeList()
    local ids = {}
    if S.PNB.BuyConsumeArroz  then table.insert(ids, 4604) end
    if S.PNB.BuyConsumeClover then table.insert(ids, 528)  end
    if S.PNB.BuyConsumeSong   then table.insert(ids, 1056) end
    return ids
end

local function _NeedsRestock()
    for _, id in ipairs(_BuildConsumeList()) do
        if inv(id) < 1 then return true end
    end
    return false
end

-- Dipanggil dari Step() -- beli consumable yang habis dari vending
local function TakeConsumes()
    if not S.PNB.BuyConsumables then return end
    if _RestockRunning then
        Log("`3[Consume]`w Restock sudah jalan, skip.")
        return
    end
    local ids = _BuildConsumeList()
    if #ids == 0 then return end

    _RestockRunning = true

    -- Matikan cheat + reset farming state sebelum bergerak ke vending
    Cheat(false)
    m = false
    _VendFailed = {}  -- reset di awal sesi, bukan akhir (kalau interrupt tidak nyangkut)

    local targetWorld = tostring(S.PNB.BuyConsumeWorld or ""):upper()
    local useOtherWorld = (targetWorld ~= "" and targetWorld ~= worldName)
    local maxTry  = math.max(1, tonumber(S.PNB.BuyConsumeTries)  or 10)
    local buyAmt  = math.max(1, tonumber(S.PNB.BuyConsumeAmount)  or 200)

    -- Warp ke world vending kalau perlu
    if useOtherWorld then
        local wn = WorldNow()
        if not wn or wn ~= targetWorld then
            Log("`9[Consume]`w Warp ke world vending: " .. targetWorld)
            Run.status = "Warp ke world vending"
            Join(targetWorld)
            Sleep(D("Join"))
            local deadline = NowTime() + 8
            while NowTime() < deadline do
                local ww = GetWorld()
                if ww and ww.name and ww.name:upper() == targetWorld then break end
                Sleep(500)
            end
        end
    end

    -- Scan semua vending SEKALI untuk semua cid (hemat GetTile)
    local allCandidates = {}  -- [key] = { x, y, key }
    local ww = GetWorld()
    if not ww then
        Log("`4[Consume]`w GetWorld() nil, batal restock.")
        m = false
        return
    end
    local debugDone = false
    for y = 0, (ww.height or 60) - 1 do
        for x = 0, (ww.width or 100) - 1 do
            local t = GetTile(x, y)
            if t and t.fg == 9268 then
                if S.PNB.DebugVend and not debugDone and t.extra then
                    debugDone = true
                    local dbg = "DebugVend tile.extra:"
                    for k, v in pairs(t.extra) do
                        dbg = dbg .. " " .. tostring(k) .. "=" .. tostring(v)
                    end
                    Log("`3" .. dbg)
                end
                local key = x .. "," .. y
                if not _VendFailed[key] then
                    table.insert(allCandidates, { x = x, y = y, key = key })
                end
            end
        end
    end

    -- Proses tiap item yang habis, pakai candidate list yang sama
    for _, cid in ipairs(ids) do
        if inv(cid) >= 1 then goto continue end

        local itemName = (cid == 4604 and "Arroz") or (cid == 528 and "Clover") or (cid == 1056 and "Songpyeon") or tostring(cid)
        Log(string.format("`9[Consume]`w %s habis, cari vending...", itemName))

        if #allCandidates == 0 then
            Log(string.format("`4[Consume]`w Tidak ada vending tersedia untuk %s.", itemName))
            goto continue
        end

        local bought = false
        local tries  = 0
        for _, vend in ipairs(allCandidates) do
            if tries >= maxTry then break end
            if _VendFailed[vend.key] then goto next_vend end
            tries = tries + 1

            local ax, ay = FindAdjacent(vend.x, vend.y)
            if not ax then ax, ay = vend.x, vend.y end
            SlowFindPath(ax, ay, D("PathStep"))
            Sleep(D("RemoteStep"))

            _VendPending = { x = vend.x, y = vend.y, id = cid }
            _VendBought  = false
            WrenchTile(vend.x, vend.y)

            -- Tunggu dialog vend_buy (hook set _VendConfirm) maks 3s
            local t0 = NowTime()
            while NowTime() - t0 < 3 do
                if _VendConfirm then break end
                Sleep(300)
            end

            if not _VendConfirm then
                Log(string.format("`3[Consume]`w Vending (%d,%d) tidak buka dialog, skip.", vend.x, vend.y))
                _VendPending = nil
                _VendFailed[vend.key] = true
                goto next_vend
            end

            -- Kirim dialog_return vend_buy dengan jumlah yang sudah disesuaikan stok
            local sendAmt = (_VendConfirm and _VendConfirm.amt) or buyAmt
            SendPacket(2, string.format(
                "action|dialog_return\ndialog_name|vend_buy\nx|%d|\ny|%d|\nbuyamount|%d\n",
                vend.x, vend.y, sendAmt))
            _VendConfirm = nil
            Sleep(D("RemoteDialog"))

            -- Tunggu konfirmasi beli (hook set _VendBought) maks 3s
            t0 = NowTime()
            while NowTime() - t0 < 3 do
                if _VendBought then break end
                Sleep(300)
            end

            _VendPending = nil
            if inv(cid) >= 1 then
                Log(string.format("`2[Consume]`w %s berhasil dibeli dari vending (%d,%d)!", itemName, vend.x, vend.y))
                bought = true
                break
            else
                Log(string.format("`4[Consume]`w Vending (%d,%d) gagal. Skip.", vend.x, vend.y))
                _VendFailed[vend.key] = true
            end
            ::next_vend::
        end

        if not bought then
            Log(string.format("`4[Consume]`w Gagal beli %s setelah %d percobaan.", itemName, tries))
            pcall(SendWhatsAppAlert, "Consumable Habis",
                string.format("%s habis dan tidak bisa dibeli dari vending. Cek vending world %s.",
                    itemName, useOtherWorld and targetWorld or worldName))
        end
        ::continue::
    end

    _VendFailed = {}  -- sudah di-reset di awal, ini cleanup redundan tapi tidak masalah
    m = false  -- selalu reset setelah selesai agar Step re-setup farming
    _RestockRunning = false

    -- Balik ke world farming
    if useOtherWorld then
        local wn = WorldNow()
        if wn and wn ~= worldName and worldName ~= "" then
            Log("`9[Consume]`w Selesai beli, balik ke world farm: " .. worldName)
            Run.status = "Balik ke world farm"
            Join(worldName)
            Sleep(D("Join"))
            -- Tunggu konfirmasi masuk world farm
            local deadline = NowTime() + 8
            while NowTime() < deadline do
                local ww = GetWorld()
                if ww and ww.name and ww.name:upper() == worldName then break end
                Sleep(500)
            end
        end
    end
end

local function Consume()
    if NowTime() - ConsumeTime < 60 * 30 then return end
    ConsumeTime = NowTime()

    -- Restock dulu kalau ada yang habis dan BuyConsumables aktif
    if S.PNB.BuyConsumables and _NeedsRestock() then
        Log("`9[Consume]`w Stok consumable habis, memulai restock dari vending...")
        Run.status = "Restock consumable"
        Cheat(false)
        pcall(TakeConsumes)
        if not Run.start then return end
        Cheat(true)
        Sleep(D("Consume"))
    end

    -- Consume dari inventory -- hanya item yang toggle-nya aktif
    local consumeIds = {}
    if S.PNB.BuyConsumeArroz  then table.insert(consumeIds, 4604) end
    if S.PNB.BuyConsumeClover then table.insert(consumeIds, 528)  end
    if S.PNB.BuyConsumeSong   then table.insert(consumeIds, 1056) end
    -- Fallback: kalau BuyConsumables mati, consume semua seperti sebelumnya
    if not S.PNB.BuyConsumables or #consumeIds == 0 then
        consumeIds = { 4604, 528, 1056 }
    end
    local names = { [4604]="Arroz", [528]="Clover", [1056]="Songpyeon" }
    local activeNames = {}
    for _, id in ipairs(consumeIds) do
        if inv(id) > 0 then table.insert(activeNames, names[id] or tostring(id)) end
    end
    if #activeNames > 0 then
        Log("`wConsuming: `9" .. table.concat(activeNames, ", "))
    end
    Cheat(false)
    Sleep(D("Consume"))
    for _, id in ipairs(consumeIds) do
        if inv(id) > 0 then
            Raw(3, 0, id, S.PosX, S.PosY)
            Sleep(D("Consume"))
        end
    end
    Cheat(true)
    Sleep(D("Consume"))
end

local function AutoFindTel()
    local w = GetWorld()
    if not w then return nil end
    local me = GetLocal()
    local originX = (S.PosX ~= 0) and S.PosX or (me and math.floor(me.pos.x / 32) or 0)
    local originY = (S.PosY ~= 0) and S.PosY or (me and math.floor(me.pos.y / 32) or 0)
    local bestX, bestY = nil, nil
    local bestDist = 999999
    local maxX, maxY = w.width - 1, w.height - 1
    for y = 0, maxY do
        for x = 0, maxX do
            local t = GetTile(x, y)
            if t and (t.fg == 3898 or t.bg == 3898) then
                local dist = math.abs(x - originX) + math.abs(y - originY)
                if dist < bestDist then
                    bestDist = dist
                    bestX, bestY = x, y
                end
            end
        end
    end
    if bestX and bestY then
        S.TelX = bestX
        S.TelY = bestY
        Log(string.format("`2[Tel]`w Auto-search: Telephone ditemukan di (%d, %d) jarak %d", bestX, bestY, bestDist))
        return bestX, bestY
    end
    Log("`4[Tel]`w Tidak ada Telephone (3898) terdeteksi di world!")
    return nil
end

local TEL_NUMBER = "53785" -- VERIFY: nomor telephone default GT

local function TelPos()
    if S.TelX ~= 0 or S.TelY ~= 0 then return S.TelX, S.TelY end
    local fx, fy = AutoFindTel()
    if fx and fy then return fx, fy end
    return nil, nil -- [11] Jika belum diset, return nil
end

local function PunchTile(x, y)
    local me = GetLocal()
    local px = me and me.pos.x or (x * 32)
    local py = me and me.pos.y or (y * 32)
    SendPacketRaw(false, {
        type = 3,
        value = 18, -- fist / punch
        px = x,
        py = y,
        x = px,
        y = py,
    })
end

local function TelDialog(button)
    local tx, ty = TelPos()
    if not tx or not ty then
        Log("`4[Tel]`w Posisi Telephone belum di-set! Set di Setting dulu.")
        return false
    end
    local ax, ay = FindAdjacent(tx, ty)
    if not ax then ax, ay = tx, ty end
    SlowFindPath(ax, ay, D("PathStep"))
    Sleep(D("RemoteStep"))
    PunchTile(tx, ty)
    Sleep(D("ShortDelay"))
    SendPacket(2, "action|dialog_return\ndialog_name|telephone\nnum|" .. TEL_NUMBER .. "|\nx|" .. tx ..
        "|\ny|" .. ty .. "|\nbuttonClicked|" .. button)
    Sleep(D("RemoteDialog"))
    -- [11] Kembali ke farm pos setelah selesai
    if S.PosX ~= 0 and S.PosY ~= 0 then
        SlowFindPath(S.PosX, S.PosY, D("PathStep"))
        Sleep(D("PostMove"))
    end
    m = false
    return true
end

local function MakeBGL()
    SendPacket(2, "action|dialog_return\ndialog_name|info_box\nbuttonClicked|make_bgl")
end

local function CheckPaywall(force)
    if not S.PNB.AutoPaywall then return end
    if S.PaywallX == 0 and S.PaywallY == 0 then return end
    local now = NowTime()
    -- Rate limiting: kalau bukan force, hanya jalan jika AutoRenew aktif dan sisa < 2 menit
    if not force then
        if not S.PNB.AutoRenewPaywall then return end
        if PaywallExpires > 0 and now < (PaywallExpires - 120) then return end
        if now - LastPaywallCheck < 30 then return end
    end
    LastPaywallCheck = now

    -- Cari tile adjacent ke paywall untuk berdiri (sama kayak FetchRemote ke mag)
    local ax, ay = FindAdjacent(S.PaywallX, S.PaywallY)
    if not ax then
        -- Fallback: tile tepat di bawah paywall
        ax, ay = S.PaywallX, S.PaywallY + 1
    end

    -- Cek jarak player ke adjacent tile, jalan kalau perlu
    local me = GetLocal()
    local cx = me and math.floor(me.pos.x / 32) or -999
    local cy = me and math.floor(me.pos.y / 32) or -999
    local dist = math.abs(cx - ax) + math.abs(cy - ay)

    if dist > 3 then
        Log(string.format("`9[Paywall]`w Jalan ke paywall (%d,%d) untuk cek/renew...", S.PaywallX, S.PaywallY))
        Run.status = "Going to paywall"
        Cheat(false)
        SlowFindPath(ax, ay, D("PathStep"))
        Sleep(D("RemoteStep"))
        -- Setelah jalan, reset m supaya bot re-setup farming setelah selesai
        m = false
    end

    Log(string.format("`9[Paywall]`w Wrench paywall (%d, %d)...", S.PaywallX, S.PaywallY))
    WrenchTile(S.PaywallX, S.PaywallY)
    -- Tunggu dialog response (hook OnDialogRequest akan handle hasilnya)
    Sleep(D("RemoteDialog"))
end

-- ------------------------------------------------------------
--  RENTING / MRAY SYSTEM (WAR & EQUIP)
-- ------------------------------------------------------------

-- Step 1: Cek & pasang item sewa secara SILENT (tanpa popup layar mengganggu user)
local function CheckRentStatus(force)
    if not S.PNB.AutoRent then return end
    local now = NowTime()
    if not force and now - LastRentCheck < 15 then return end
    LastRentCheck = now
    RentChecking = true
    BotTriggeredWrench = true

    local me = GetLocal()
    local netId = me and me.netid or 0
    Log(string.format("`9[Rent]`w Cek status sewa (silent, netid=%d)...", netId))
    SendPacket(2, "action|wrench\n|netid|" .. tostring(math.max(1, netId)) .. "\n")
    -- Tunggu hingga dialog selesai diproses di hook (maksimal 6 detik safety timeout)
    for _ = 1, 12 do
        if not RentChecking then break end
        Sleep(500)
    end
    BotTriggeredWrench = false
    RentChecking = false
end

-- Fungsi untuk memastikan item sewa terpasang: lewat alur CheckRentStatus (wrench -> popup -> clothlease -> klik)
local function SilentEquipRent(force)
    if not force and RentEquipped then return end -- SUDAH TERPASANG, JANGAN SENTUH!
    Log("`9[Rent]`w Memulai cek & pasang item sewa...")
    CheckRentStatus(true)
end

-- Step 2: WAR Renting (Spam mesin sewa sampai dapat)
local function DoWarRent()
    if not S.PNB.AutoRent then return end
    local rentWorld = (S.PNB.RentWorld or ""):upper()
    if rentWorld == "" or S.RentX == 0 and S.RentY == 0 then
        Log("`4[Rent]`w World sewa / Posisi Renting Station belum di-set!")
        return
    end

    RentWarActive = true
    RentSuccess = false
    Cheat(false)
    m = false

    -- Pastikan bot di world tempat sewa
    local curW = WorldNow()
    if not curW or curW ~= rentWorld then
        Log("`9[Rent]`w Warp ke world sewa: " .. rentWorld)
        Run.status = "Warping to Rent World"
        Join(rentWorld)
        Sleep(D("Join"))
    end

    -- [FIX 1] Tunggu tiles world sewa ter-load sebelum pathfind
    -- Beri waktu tile target masuk ke cache Bothax (maks 5 detik)
    do
        local deadline = NowTime() + 5
        while NowTime() < deadline do
            local t = pcall(GetTile, S.RentX, S.RentY)
            if GetWorld() and t then break end
            Sleep(500)
        end
        Sleep(300) -- buffer kecil tambahan
    end

    -- [POSISI MESIN SEWA TUNGGAL]
    -- Bot cukup menuju ke samping/depan tile mesin sewa (S.RentX, S.RentY)
    Log(string.format("`9[Rent]`w Menuju mesin sewa (%d, %d)...", S.RentX, S.RentY))
    Run.status = "Moving to Rent Station"
    SlowFindPath(S.RentX, S.RentY, D("PathStep"))
    Sleep(D("RemoteStep"))

    Log("`2[Rent]`w Standby di mesin! Memulai Wrench War...")
    Run.status = "WAR Renting..."
    RentStep = "WAIT_BUY"

    -- State machine war sewa: durasi 120 detik, spam wrench tiap 350-400ms
    local maxWarSec = 120
    local startWar = NowTime()
    local lastWrenchTick = 0

    while RentWarActive and (NowTime() - startWar < maxWarSec) do
        if RentSuccess then break end

        local now = NowTime()
        local curClock = os.clock()

        if RentStep == "WAIT_BUY" then
            -- Spam wrench cepat setiap 350ms (0.35 detik)
            if curClock - lastWrenchTick >= 0.35 or lastWrenchTick == 0 then
                lastWrenchTick = curClock
                WrenchTile(S.RentX, S.RentY)
            end
        elseif RentStep == "WAIT_CONFIRM" then
            if now - RentStepTime > 3 then
                Log("`3[Rent]`w Menunggu konfirmasi timeout, wrench ulang...")
                RentStep = "WAIT_BUY"
                lastWrenchTick = 0
            end
        elseif RentStep == "WAIT_RESULT" then
            if now - RentStepTime > 5 then
                Log("`3[Rent]`w Menunggu respon pembelian timeout, ulang sewa...")
                RentStep = "WAIT_BUY"
                lastWrenchTick = 0
            end
        end

        Sleep(D("ShortDelay"))
    end

    RentWarActive = false
    RentStep = "IDLE"

    if RentSuccess then
        Log("`2[Rent]`w WAR RENTING BERHASIL! Item berhasil disewa.")
        Sleep(D("RemoteDialog"))
        CheckRentStatus(true)
        Sleep(D("AfterRemote"))

        -- Hanya pulang ke world PNB jika SUDAH berhasil sewa dan item terpasang!
        if S.World and S.World ~= "" and WorldNow() ~= S.World:upper() then
            Log("`9[Rent]`w Sewa sukses! Kembali ke world PNB: " .. S.World)
            Run.status = "Returning to PNB World"
            Join(S.World:upper())
            Sleep(D("Join"))
        end
    else
        -- [SENSOR WAJIB SEWA] Jika belum berhasil sewa: DILARANG PULANG KE WORLD BFG!
        Log("`4[Rent]`w Belum berhasil sewa pada sesi ini! Tetap standby di world sewa untuk retry...")
        RentExpires = 0
        RentEquipped = false
        pcall(SendWhatsAppAlert, "Gagal Sewa Mray (Standby Retry)", string.format("War 120s di world %s mesin (%d,%d) belum dapat. Bot TETAP di world sewa & standby retry (TIDAK pulang bfg tangan kosong).", rentWorld, S.RentX, S.RentY))
        Run.status = "Gagal Sewa (Standby Retry)"
        Sleep(5000) -- Istirahat 5s lalu loop berikutnya otomatis DoWarRent lagi
    end
end

local function AutoConvert()
    local now = NowTime()
    if now - LastConvert < 10 then return end
    LastConvert = now

    local gems = Gems()
    local maxG = tonumber(S.PNB.MaxGems) or 400000
    local wl, dl, bgl = inv(242), inv(1796), inv(7188)

    local function CallTel(btn, featKey)
        local tx, ty = TelPos()
        if not tx or not ty then
            Log("`4[AutoConvert]`w Telephone belum di-set (0,0)! Fitur " .. featKey .. " dinonaktifkan.")
            S.PNB[featKey] = false
            return false
        end
        return TelDialog(btn)
    end

    if S.PNB.AutoBuyWL then
        if wl < 100 and dl < 100 and bgl < 100 and gems >= maxG then
            Log("`2Beli World Lock Pack")
            SendPacket(2, "action|buy\nitem|buy_worldlockpack")
        elseif wl >= 100 and dl < 100 and bgl < 100 then
            SendPacketRaw(false, { type = 10, value = 242 })
        elseif dl >= 100 and bgl < 100 then
            CallTel("bglconvert", "AutoBuyWL")
        elseif bgl >= 100 then
            MakeBGL()
        end
    end

    if S.PNB.ConvertDLBGL then
        if gems >= maxG and dl < 100 and bgl < 100 then
            Log("`2Convert gems -> DL")
            CallTel("dlconvert", "ConvertDLBGL")
        elseif dl >= 100 and bgl < 100 then
            CallTel("bglconvert", "ConvertDLBGL")
        elseif bgl >= 100 then
            MakeBGL()
        end
    end

    if S.PNB.ConvertBGL then
        if gems > maxG and bgl < 100 then
            Log("`2Convert gems -> BGL")
            CallTel("bglconvert2", "ConvertBGL")
        elseif bgl >= 100 then
            MakeBGL()
        end
    end
end

-- ------------------------------------------------------------
--  WEB MONITOR & HEARTBEAT (Opt-in)
-- ------------------------------------------------------------
local MONITOR_URL = "https://gt-pi-ten.vercel.app"
local _mon = {}
do
    local M = {}
    M.__index = M
    local function uuid4()
        math.randomseed(NowTime() * 1000 + math.floor(os.clock() * 1e6))
        return string.gsub("xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx", "[xy]", function(ch)
            local v = (ch == "x") and math.random(0, 15) or math.random(8, 11)
            return string.format("%x", v)
        end)
    end
    function M.new(cfg)
        local self = setmetatable({}, M)
        self.endpoint = MONITOR_URL .. "/api/heartbeat"
        self.userId = nil
        self.name = nil
        self.interval = 9  -- [6b] Default 9 detik
        self.instanceId = uuid4()
        self.seq = 0
        self.lastTick = 0
        self.lastCmdId = nil
        self.tokenWarned = false
        self.startTime = NowTime()
        return self
    end
    function M:tick()
        -- Opt-in check: hanya kirim jika user mengaktifkan EnableMonitor
        if not S.PNB.EnableMonitor then return end
        if NowTime() - self.lastTick < self.interval then return end
        self.lastTick = NowTime()
        self.seq = self.seq + 1

        -- [5] Lazy identity resolution via self.name:find("^Bot_")
        local me = GetLocal and GetLocal()
        if not self.name or self.name:find("^Bot_") then
            if me and me.userid and me.userid > 0 then
                self.userId = tostring(me.userid)
                self.name = StripColor(me.name or ("Bot_" .. self.userId))
            else
                self.userId = self.userId or tostring(math.random(100000, 999999))
                self.name = self.name or ("Bot_" .. self.userId)
            end
        end

        -- Header heartbeat tanpa token (publik)
        local reqHeaders = { ["Content-Type"] = "application/json" }

        local gems, wl, dl, bgl, level, ping = 0, 0, 0, 0, 1, 0
        local world = (worldName ~= "" and worldName) or "EXIT"
        local px, py = 0, 0
        pcall(function()
            local info = nil
            if GetPlayerInfo then
                local ok, r = pcall(GetPlayerInfo); if ok then info = r end
            end
            if not info and GetPlayerItems then
                local ok, r = pcall(GetPlayerItems); if ok then info = r end
            end
            if info then
                gems  = tonumber(info.gems)  or 0
                level = tonumber(info.level) or 1
                ping  = tonumber(info.ping)  or 0
            end
            if me and me.pos then
                px = math.floor(me.pos.x / 32)
                py = math.floor(me.pos.y / 32)
            end
            wl  = inv(242)
            dl  = inv(1796)
            bgl = inv(7188)
        end)

        -- Serialize pending magplant updates untuk sharding fleet knowledge
        local magUpdates = {}
        for _, v in pairs(PendingMagSync) do
            local cntField = "null"
            if v.empty then
                cntField = "0"
            elseif v.count ~= nil then
                cntField = tostring(math.floor(v.count))
            end
            table.insert(magUpdates, string.format('{"world":"%s","x":%d,"y":%d,"empty":%s,"count":%s,"itemId":16706,"ttl":%d}',
                (v.world or world):gsub('"', ''),
                v.x, v.y,
                v.empty and "true" or "false",
                cntField,
                v.ttl or 300
            ))
        end
        PendingMagSync = {} -- Bersihkan queue
        local magsJson = "[" .. table.concat(magUpdates, ",") .. "]"

        -- Durasi sewa Paywall & Mray/Renting Station untuk Vercel & WhatsApp
        local nowTs = NowTime()
        local paywallRem = (PaywallExpires > 0) and math.max(0, PaywallExpires - nowTs) or -1
        local rentRem = (RentExpires > 0) and math.max(0, RentExpires - nowTs) or -1

        local body = string.format(
            '{"userId":"%s","name":"%s","world":"%s","posX":%d,"posY":%d,"gems":%d,"wl":%d,"dl":%d,"bgl":%d,"level":%d,"pingMs":%d,"uptimeSec":%d,"instanceId":"%s","seq":%d,"magReports":%s,"paywallRemSec":%d,"rentRemSec":%d,"rentEquipped":%s,"autoPaywall":%s,"autoRent":%s}',
            self.userId,
            JsonEsc(self.name),
            JsonEsc(world),
            px, py,
            gems, wl, dl, bgl, level, ping,
            NowTime() - self.startTime,
            self.instanceId, self.seq,
            magsJson,
            paywallRem,
            rentRem,
            RentEquipped and "true" or "false",
            S.PNB.AutoPaywall and "true" or "false",
            S.PNB.AutoRent and "true" or "false"
        )
        local ok, res = pcall(MakeRequest, self.endpoint, "POST", reqHeaders, body)
        if ok and res and type(res) == "table" and res.content then
            pcall(function()
                local content = res.content

                -- Inbound Sharding Knowledge: serap advisory status mag dari bot lain (hanya untuk world ini)
                if content:find('"sharedMags"') then
                    local sharedList = ParseJsonSharedMags(content)
                    for _, mg in ipairs(sharedList) do
                        local bWorld = mg.world
                        local mx = mg.x
                        local my = mg.y
                        local isEmp = mg.empty == true
                        local remTtl = mg.remTtl or mg.ttl or 300
                        local matchWorld = (not bWorld) or (tostring(bWorld):upper() == world:upper())
                        if matchWorld and mx and my then
                            local key = MagKey(tonumber(mx), tonumber(my), world)
                            if not MagIntel[key] or MagIntel[key].source == "shared" then
                                if isEmp then
                                    MarkMagEmpty(tonumber(mx), tonumber(my), remTtl, "shared", world)
                                else
                                    MarkMagReady(tonumber(mx), tonumber(my), nil, "shared", world)
                                end
                            end
                        end
                    end
                end

                -- Dedupe check via cmdId (ekstrak tanpa typo regex)
                local cmdId = content:match('"id"%s*:%s*"([^"]+)"') or content:match('"cmdId"%s*:%s*"([^"]+)"')
                if not cmdId or cmdId == "" then
                    -- [6d] Command tanpa cmdId: abaikan, log peringatan
                    if content:find('"action"') then
                        Log("`5[RemoteCmd]`w Response tanpa cmdId -- diabaikan.")
                    end
                    return
                end
                if cmdId == self.lastCmdId then
                    return -- Sudah pernah diproses, abaikan
                end

                local cmdAction = content:match('"action"%s*:%s*"([^"]+)"')
                local cmdParam  = content:match('"param"%s*:%s*"([^"]+)"')
                if cmdAction then
                    if cmdId then self.lastCmdId = cmdId end
                    Log("`3[RemoteCmd] Action: " .. cmdAction .. " Param: " .. tostring(cmdParam))
                    if cmdAction == "warp" and cmdParam and cmdParam ~= "" then
                        worldName = cmdParam:upper() -- [7] Update worldName agar Step tidak melawan
                        m = false
                        Join(worldName)
                    elseif cmdAction == "stop" then
                        pcall(StopPNB)
                    elseif cmdAction == "start" then
                        pcall(StartPNB)
                    elseif cmdAction == "path" and cmdParam then
                        local tx, ty = cmdParam:match("(%d+),(%d+)")
                        if tx and ty then
                            PendingPath = { x = tonumber(tx), y = tonumber(ty) } -- [7] Biar Step yang eksekusi
                        end
                    end
                end
            end)
        end
    end
    _mon = M.new({})
end

local function PushWebMonitor()
    if _mon and _mon.tick then _mon:tick() end
end



-- ------------------------------------------------------------
--  SAVE / LOAD
-- ------------------------------------------------------------
local function SavePaths(suffix)
    suffix = suffix or ""
    local name = "ZAKICIT_SETTINGS" .. suffix .. ".txt"
    local p = {}
    p[#p + 1] = "/storage/emulated/0/Android/media/com.rtsoft.growtopia/scripts/" .. name
    local ok, ad = pcall(function() return os.getenv("APPDATA") end)
    if ok and ad and ad ~= "" then
        p[#p + 1] = ad .. "\\Growtopia\\scripts\\" .. name
    end
    p[#p + 1] = name
    return p
end

local function SyncDerived()
    worldName = tostring(S.World or ""):upper()
    UpdateBypassRules()
end

function SaveSettings(slot)
    local suffix = slot and ("_USER" .. tostring(slot)) or ""
    local label = slot and ("User " .. tostring(slot)) or "Default"
    S.World = worldName
    for _, path in ipairs(SavePaths(suffix)) do
        local f = io.open(path, "w")
        if f then
            for k, v in pairs(S.PNB) do
                f:write("PNB." .. k .. "=" .. tostring(v) .. "\n")
            end
            f:write("Setting.World=" .. tostring(S.World) .. "\n")
            f:write("Setting.PosX=" .. tostring(S.PosX) .. "\n")
            f:write("Setting.PosY=" .. tostring(S.PosY) .. "\n")
            f:write("Setting.MagplantX=" .. tostring(S.MagplantX) .. "\n")
            f:write("Setting.MagplantY=" .. tostring(S.MagplantY) .. "\n")
            f:write("Setting.TelX=" .. tostring(S.TelX) .. "\n")
            f:write("Setting.TelY=" .. tostring(S.TelY) .. "\n")
            f:write("Setting.PaywallX=" .. tostring(S.PaywallX) .. "\n")
            f:write("Setting.PaywallY=" .. tostring(S.PaywallY) .. "\n")
            f:write("Setting.RentX=" .. tostring(S.RentX) .. "\n")
            f:write("Setting.RentY=" .. tostring(S.RentY) .. "\n")
            f:write("Setting.RentStandX=" .. tostring(S.RentStandX or 0) .. "\n")
            f:write("Setting.RentStandY=" .. tostring(S.RentStandY or 0) .. "\n")
            f:write("Setting.DelayBuyCheat=" .. tostring(S.DelayBuyCheat) .. "\n")
            for k, v in pairs(S.Delay) do
                f:write("Delay." .. k .. "=" .. tostring(v) .. "\n")
            end
            f:close()
            savePathUsed = path
            Log("`2Config tersimpan (" .. label .. "): " .. path)
            return true
        end
    end
    Log("`4Gagal menyimpan config " .. label)
    return false
end

local STRING_KEYS = {
    World          = true,
    WearItem       = true,
    WebhookURL     = true,
    MonitorToken   = true,
    RentWorld      = true,
    RentTargetItem = true,
}

function LoadSettings(slot)
    local suffix = slot and ("_USER" .. tostring(slot)) or ""
    local label = slot and ("User " .. tostring(slot)) or "Default"
    for _, path in ipairs(SavePaths(suffix)) do
        local f = io.open(path, "r")
        if f then
            for line in f:lines() do
                local section, key, value = line:match("^([^%.=]+)%.([^=]+)=(.*)$")
                if section and key then
                    if STRING_KEYS[key] then
                        -- [15] Pertahankan string murni
                    elseif value == "true" then value = true
                    elseif value == "false" then value = false
                    elseif tonumber(value) then value = tonumber(value) end
                    if section == "PNB" then S.PNB[key] = value
                    elseif section == "Delay" then S.Delay[key] = value
                    elseif section == "Setting" then S[key] = value end
                end
            end
            f:close()
            SyncDerived()
            savePathUsed = path
            Log("`2Config dimuat (" .. label .. "): " .. path)
            return true
        end
    end
    Log("`3Config (" .. label .. ") belum ada")
    return false
end

-- ------------------------------------------------------------
--  LIVE EFFICIENCY TRACKER (Delta Accumulator)
-- ------------------------------------------------------------
local TrackStartTime = 0
local TrackGained    = 0
local LastSeenGems   = nil

local function TrackGems()
    if not Run.start then
        TrackStartTime = 0
        TrackGained    = 0
        LastSeenGems   = nil
        return
    end
    local g = Gems()
    if not LastSeenGems then
        LastSeenGems = g
        TrackStartTime = NowTime()
        TrackGained = 0
        return
    end
    if g > LastSeenGems then
        TrackGained = TrackGained + (g - LastSeenGems)
    end
    LastSeenGems = g
end

local function GetEfficiency()
    if not Run.start or TrackStartTime == 0 then return 0 end
    local el = math.max(1, NowTime() - TrackStartTime)
    return math.floor(TrackGained / (el / 3600))
end

-- ------------------------------------------------------------
--  MAIN STEP
-- ------------------------------------------------------------
local function Step()
    TrackGems()  -- live efficiency tracker
    if worldName == "" then
        Log("`4World belum di-set. Klik 'Use Current World'.")
        Run.start = false
        Run.status = "Idle"
        return
    end
    if S.PosX == 0 and S.PosY == 0 then
        Log("`4Farming pos belum di-set!")
        Run.start = false
        Run.status = "Idle"
        return
    end

    if Disconnected then return end

    -- [7] Eksekusi PendingPath dari remote command bila ada
    if PendingPath and PendingPath.x and PendingPath.y then
        local ptx, pty = PendingPath.x, PendingPath.y
        PendingPath = nil
        Log(string.format("`9[RemoteCmd]`w Menjalankan path ke (%d, %d)...", ptx, pty))
        SlowFindPath(ptx, pty)
    end

    local wn = WorldNow()
    if not wn or wn ~= worldName then
        -- Reset MagIntel saat pindah world agar key WORLD:x,y tidak bocor antar-world
        MagIntel = {}
        PendingMagSync = {}
        JoinFail = JoinFail + 1
        LastJoinAttempt = NowTime()
        if JoinFail >= 10 then
            Log("`4[Critical]`w Gagal join world " .. worldName .. " 10x! Cooldown 60s & kirim WA alert...")
            Run.status = "Gagal Join (Retry 60s)"
            pcall(SendWhatsAppAlert, "Gagal Join World 10x", "Bot gagal masuk ke world " .. worldName .. " setelah 10 percobaan. Menunggu 60s lalu mencoba lagi.")
            pcall(WebhookNotify, "join_fail", "Gagal join world " .. worldName .. " 10x berturut-turut")
            Sleep(60000)
            JoinFail = 5 -- Kurangi counter agar lanjut coba dengan delay backoff
            return
        end
        local delay = D("Join")
        if JoinFail >= 5 then
            delay = math.min(60000, math.floor(D("Join") * (2 ^ (JoinFail - 5))))
        end
        Run.status = string.format("Joining %s (%d/10)", worldName, JoinFail)
        Join(worldName)
        Sleep(delay)
        m = false
        PaywallExpires = 0 -- Reset expiry saat rejoin, wajib verifikasi ulang
        StuckGemTime = NowTime() -- [2d] Reset timer stuck saat join
        PosCheckCounter = 0
        return
    end

    JoinFail = 0
    Disconnected = false

    -- Kalau auto paywall aktif dan belum tau expiry (misal baru reconnect)
    -- atau sisa waktu < 2 menit: bayar/cek dulu sebelum coba masuk ke farm pos!
    if S.PNB.AutoPaywall and S.PaywallX ~= 0 and (PaywallExpires == 0 or NowTime() >= PaywallExpires - 120) then
        CheckPaywall()
    end

    -- SISTEM RENTING:
    -- 1. Cek durasi sewa secara periodik (setiap 10 menit atau saat durasi belum diketahui)
    if S.PNB.AutoRent and not RentChecking then
        local now = NowTime()
        if RentExpires == 0 and (now - LastRentCheck >= 30) then
            CheckRentStatus(false)
        elseif RentExpires > 0 and (now - LastRentCheck >= 600) then
            -- Refresh sisa jam sewa setiap 10 menit
            CheckRentStatus(false)
        end
    end
    -- 2. WAR RENTING: Jika durasi sewa sisa < 60 detik atau belum punya item sewa:
    if S.PNB.AutoRent and S.RentX ~= 0 and (RentExpires > 0 and NowTime() >= RentExpires - 60 or (RentExpires == 0 and not RentChecking and NowTime() - LastRentCheck >= 60)) then
        DoWarRent()
    end

    -- ??????????????????????????????????????????????????????????????
    -- ? GUARD MUTLAK: ITEM SEWA WAJIB TERPASANG SEBELUM APAPUN  ?
    -- ? Jika AutoRent aktif dan item BELUM di badan:             ?
    -- ? DILARANG: farm, ambil remote, jalan ke farm pos, mukul   ?
    -- ? Bot HANYA boleh coba pasang item atau sewa!              ?
    -- ??????????????????????????????????????????????????????????????
    if S.PNB.AutoRent and not RentEquipped then
        Cheat(false)
        m = false
        if RentExpires > NowTime() then
            Run.status = "WAJIB PASANG Item Sewa!"
            Log("`4[RentGuard]`w DILARANG FARM! Item sewa belum terpasang (sisa " .. FTime(RentExpires - NowTime()) .. "). Memasang sekarang...")
            CheckRentStatus(true)
            Sleep(5000) -- Beri waktu 5 detik agar respons server / mod added sempat diproses hook!
        else
            Run.status = "WAJIB SEWA Dulu!"
            Log("`4[RentGuard]`w DILARANG FARM! Sewa habis/belum ada. Menuju world sewa...")
            if S.RentX ~= 0 then
                DoWarRent()
            else
                Log("`4[RentGuard]`w Posisi Renting Station belum di-set! Bot standby...")
            end
            Sleep(3000)
        end
        return
    end

    if changeRemote or inv(5640) == 0 then
        -- [17] Jika remote habis dan AutoChangeRemote mati -> Stop PNB
        if inv(5640) == 0 and not S.PNB.AutoChangeRemote then
            Log("`4[Remote]`w Remote habis dan Auto Change Remote nonaktif! Kirim WA alert, bot tetap jalan...")
            Run.status = "Remote Habis (Alert)"
            pcall(SendWhatsAppAlert, "Remote Magplant Habis", "Remote (ID 5640) habis di tas dan AutoChangeRemote nonaktif. Bot tidak bisa lanjut ambil remote -- tolong isi remote atau aktifkan AutoChangeRemote.")
            pcall(WebhookNotify, "remote_habis", "Remote magplant habis di tas dan AutoChangeRemote nonaktif")
            Sleep(60000)
            return
        end
        Run.status = "Smart Mag fetching"
        Cheat(false)
        FetchRemote()
        if not Run.start then return end
        changeRemote = false
        StuckGemTime = NowTime() -- [2d] Reset timer stuck saat ambil remote
        PosCheckCounter = 0
        Sleep(D("Switch"))
    end

    if inv(5640) >= 1 then
        if not m then
            Run.status = "Moving to farm pos"
            Cheat(false)
            Sleep(D("PreMove"))
            SlowFindPath(S.PosX, S.PosY, D("PathStep"))
            Sleep(D("PostMove"))

            -- SENSOR 1: Verifikasi apakah bot BENAR-BENAR sampai di farm pos
            local me = GetLocal()
            local curX = me and me.pos and math.floor(me.pos.x / 32) or -999
            local curY = me and me.pos and math.floor(me.pos.y / 32) or -999
            if curX ~= S.PosX or curY ~= S.PosY then
                Log(string.format("`4[PosGuard]`w Gagal masuk Farm Pos! Sekarang di (%d, %d), target (%d, %d)", curX, curY, S.PosX, S.PosY))
                Cheat(false)
                m = false
                -- Jika ada paywall, kemungkinan tertahan pintu paywall tertutup!
                if S.PNB.AutoPaywall and S.PaywallX ~= 0 then
                    Log("`3[PosGuard]`w Mencoba periksa & bayar paywall...")
                    CheckPaywall(true)
                end
                return
            end

            -- Hadap karakter sesuai setting (BFG kanan vs kiri)
            local targetPlaceX = S.PNB.FaceRight and (S.PosX + 1) or (S.PosX - 1)
            if S.PNB.FaceRight then
                FindTPRight(S.PosX, S.PosY)
                Log("`9[BFG]`w Hadap KANAN di farm pos")
            else
                FindTPLeft(S.PosX, S.PosY)
                Log("`9[BFG]`w Hadap KIRI di farm pos")
            end
            Sleep(D("FaceDelay"))

            -- [GUARD ANTI-TANGAN-KOSONG sudah di paling atas Step() -- tidak perlu duplikat di sini]

            -- Auto-place remote & showhand sebelum cheat aktif (mengunci posisi target)
            PlaceShowHand(targetPlaceX, S.PosY)
            Sleep(D("PlaceDelay"))

            Cheat(true)
            if S.PNB.Modfly then
                pcall(ChangeValue, "[C] Modfly", true)
            end
            Sleep(D("CheatOn"))

            -- Auto-place remote & showhand setelah cheat aktif (langsung memicu loop autofarm jalan otomatis)
            PlaceShowHand(targetPlaceX, S.PosY)
            Sleep(D("ShortDelay"))
            PlaceShowHand(targetPlaceX, S.PosY)
            m = true
        end
    else
        m = false
        StuckGemTime = NowTime()  -- [2d] Reset stuck timer saat bot tidak aktif farming
        PosCheckCounter = 0
    end

    -- SENSOR 2: Watchdog posisi saat aktif farming (Run.status == "Farming" dan m == true)
    -- Jika bot terlempar / respawn / jatuh / akses dicabut paksa di tengah farming:
    if m then
        local me = GetLocal()
        local curX = me and me.pos and math.floor(me.pos.x / 32) or -999
        local curY = me and me.pos and math.floor(me.pos.y / 32) or -999
        if curX ~= S.PosX or curY ~= S.PosY then
            Log(string.format("`4[PosGuard]`w Bot terlempar dari Farm Pos! Sekarang di (%d, %d). Matikan cheat...", curX, curY))
            Cheat(false)
            m = false
            if S.PNB.AutoPaywall and S.PaywallX ~= 0 then
                Log("`3[PosGuard]`w Cek akses paywall setelah terlempar...")
                CheckPaywall(true)
            end
            return
        end
        Run.status = "Farming"

        -- [16a] Stuck detector gems
        local curGems = Gems()
        local now = NowTime()
        if curGems > StuckGems then
            StuckGems = curGems
            StuckGemTime = now
            StuckCount = 0
        else
            local maxWait = (tonumber(S.PNB.StuckMinutes) or 10) * 60
            if StuckGemTime == 0 then StuckGemTime = now end
            if now - StuckGemTime >= maxWait then
                StuckCount = StuckCount + 1
                StuckGemTime = now
                m = false  -- reset farming agar Step re-setup BFG
                Log(string.format("`4[Watchdog]`w Gems tidak naik %d menit (#%d) -- auto-recovery: re-cheat & re-place...", tonumber(S.PNB.StuckMinutes) or 10, StuckCount))
                -- Paksa beli cheat ulang dan reset posisi apapun stuck count-nya
                LastBuyCheat = 0
                m = false
                changeRemote = false
                Cheat(false)
                Sleep(D("PlaceDelay"))
                if StuckCount >= 3 then
                    -- Kirim WA alert hanya saat stuck berulang kali (>= 3x)
                    pcall(SendWhatsAppAlert, "Gems Stuck Berulang", string.format("Gems tidak naik selama %d menit x %d. Bot auto-recover re-cheat.", tonumber(S.PNB.StuckMinutes) or 10, StuckCount))
                    pcall(WebhookNotify, "stuck", "Gems stuck " .. StuckCount .. "x berturut-turut")
                    StuckCount = 0  -- reset agar tidak terus spam WA
                end
                StuckGems = Gems()
                return
            end
        end

        -- [16b] Pos check tiap 5 step
        PosCheckCounter = PosCheckCounter + 1
        if PosCheckCounter >= 5 then
            PosCheckCounter = 0
            if math.abs(curX - S.PosX) > 1 or math.abs(curY - S.PosY) > 1 then
                Log(string.format("`4[PosGuard]`w Posisi bergeser > 1 tile (%d, %d). Reset farm...", curX, curY))
                m = false
            end
        end
    end

    BuyCheat()
    if S.PNB.AutoSuckBgems then SuckBgems() end
    -- Cek restock consumable tiap 5 menit (bukan tiap loop biar tidak crash)
    if S.PNB.BuyConsumables then
        local now = NowTime()
        if now - LastRestockCheck >= 300 then
            if _NeedsRestock() then
                Cheat(false)
                m = false
                Run.status = "Restock consumable"
                pcall(TakeConsumes)
                _RestockRunning = false  -- pastikan clear walau pcall catch error
                LastRestockCheck = NowTime()
                if not Run.start then return end
            else
                LastRestockCheck = now -- tidak perlu restock, update timer
            end
        end
    end
    if S.PNB.AutoConsumables then
        Consume()
        StuckGemTime = NowTime() -- [2d] Reset timer stuck setelah consume
    end
    if S.PNB.AutoPaywall then CheckPaywall() end
    if S.PNB.AutoBuyWL or S.PNB.ConvertDLBGL or S.PNB.ConvertBGL then AutoConvert() end
end

function StartPNB()
    if Run.start then return end
    changeRemote = false
    m = false
    RecalcMag()
    Run.startTime = NowTime()
    LastBuyCheat = 0 -- [3] Inisialisasi 0 agar langsung membeli/memastikan cheat saat StartPNB
    ConsumeTime  = NowTime() -- [3] Inisialisasi agar tidak langsung jalan di Step pertama
    CheatNeedsRenewal = false
    StuckGems = Gems()
    StuckGemTime = NowTime()
    StuckCount = 0
    PosCheckCounter = 0
    Run.start = true
    Run.status = "Starting"
    if S.PNB.WearItem and S.PNB.WearItem ~= "" then
        pcall(Wear, S.PNB.WearItem)
    end
    if S.PNB.Modfly then
        pcall(ChangeValue, "[C] Modfly", true)
    end
    if S.PNB.AntiLag then ActiveLag(true) end
    Log("`2Starting ZAKICIT PNB...")
end

function StopPNB()
    if not Run.start then return end
    Run.start = false
    Run.status = "Idle"
    if S.PNB.AntiLag then ActiveLag(false) end
    Cheat(false)
    if S.PNB.Modfly then
        pcall(ChangeValue, "[C] Modfly", false)
    end
    wornItem = nil -- [4] Reset state saat bot stop
    Log("`4PNB dihentikan")
end

RunThread(function()
    while true do
        Sleep(D("Loop"))
        if Run.start then
            local ok, err = pcall(Step)
            if not ok then
                ConsecErrors = ConsecErrors + 1
                Log("`4Error: " .. tostring(err))
                if ConsecErrors >= 5 then
                    Log("`4[Critical]`w Step error 5x berturut-turut! Kirim WA alert & auto-recovering (TIDAK dimatikan)...")
                    Run.status = "Error Recovery (Wait 10s)"
                    pcall(SendWhatsAppAlert, "Step Runtime Error 5x", "Step() mengalami runtime error beruntun: " .. tostring(err) .. ". Bot reset state & retry...")
                    pcall(WebhookNotify, "error_loop", "Step() runtime error 5x berturut-turut: " .. tostring(err))
                    Cheat(false)
                    m = false
                    ConsecErrors = 0
                    Sleep(10000)
                else
                    Sleep(3000)
                end
            else
                ConsecErrors = 0
            end
        end
    end
end)

-- [14] Webhook non-blocking worker thread removed

-- Monitor di thread terpisah supaya MakeRequest ga block bot loop
RunThread(function()
    while true do
        Sleep(10000)
        pcall(PushWebMonitor)
    end
end)

-- ------------------------------------------------------------
--  HOOKS
-- ------------------------------------------------------------
AddHook("OnSendPacketRaw", "PNB_RAW", function(pkt)
    if pkt.value == 18 then
        if CapturePaywall then
            S.PaywallX = pkt.px
            S.PaywallY = pkt.py
            Log("Paywall Pos : " .. pkt.px .. ", " .. pkt.py)
            CapturePaywall = false
            return true
        elseif CaptureRent then
            S.RentX = pkt.px
            S.RentY = pkt.py
            Log("Renting Station Pos : " .. pkt.px .. ", " .. pkt.py)
            CaptureRent = false
            return true
        elseif CaptureTel then
            S.TelX = pkt.px
            S.TelY = pkt.py
            Log("Telephone Pos : " .. pkt.px .. ", " .. pkt.py)
            CaptureTel = false
            return true
        elseif CaptureFarmPos then
            S.PosX = pkt.px
            S.PosY = pkt.py
            Log("Farm Pos (Punch) : " .. pkt.px .. ", " .. pkt.py)
            CaptureFarmPos = false
            return true
        end
    end
    return false
end)

local BlockDialogs = { "The BGL Bank", "The Black Backpack", "Diamond Lock" }
local BlockConsole = {
    "Disconnected?! Will attempt to reconnect...",
    "Where would you like to go?",
    "Applying cheats...",
    "Cheat Active",
    "Whoa, calm down toggling cheats on/off",
}

AddHook("OnVariant", "PNB_VAR", function(var)
    local k, a, b = var[0], var[1], var[2]
    if k == "OnSDBroadcast" then
        return true -- [10] Blok popup dialog broadcast, jangan toggle /radio di sini
    end

    if k == "OnDialogRequest" and type(a) == "string" then
        -- VENDING: intercept dialog vend_buy (dari TakeConsumes)
        if _VendPending and a:find("vend_buy", 1, true) and not a:find("vend_buyconfirm", 1, true) then
            local dx = tonumber(a:match("embed_data|x|(%d+)")) or -1
            local dy = tonumber(a:match("embed_data|y|(%d+)")) or -1
            if dx == _VendPending.x and dy == _VendPending.y then
                local clean = StripColor(a)
                -- Debug: log isi dialog vend_buy mentah (aktifkan DebugVend)
                if S.PNB.DebugVend then
                    Log("`3[VendDbg]`w Dialog vend_buy: " .. clean:sub(1, 300))
                end
                -- Cek item -- nama harus cocok dengan yang mau dibeli
                local itemNames = { [4604]="Arroz Con Pollo", [528]="Four-Leaf Clover", [1056]="Songpyeon" }
                local expectName = itemNames[_VendPending.id] or ""
                if expectName ~= "" and not clean:find(expectName, 1, true) then
                    Log(string.format("`4[Consume]`w Vending (%d,%d) isi item SALAH (bukan %s). Skip.", dx, dy, expectName))
                    _VendFailed[dx..","..dy] = true
                    _VendPending = nil
                    SendPacket(2, string.format("action|dialog_return\ndialog_name|vend_buy\nx|%d|\ny|%d|\nbuyamount|0\n", dx, dy))
                    return true
                end
                -- Cek harga per item dari dialog
                local priceWl = tonumber(clean:match("(%d+) x World Lock")) or 0
                local maxP    = math.max(1, tonumber(S.PNB.BuyConsumeMaxPrice) or 10)
                local buyAmt  = math.max(1, tonumber(S.PNB.BuyConsumeAmount) or 200)
                local totalWl = priceWl * buyAmt
                if priceWl <= 0 then
                    -- Harga tidak terbaca -- tolak, jangan beli buta
                    Log(string.format("`4[Consume]`w Vending (%d,%d) harga tidak terbaca. Skip (aktifkan DebugVend untuk diagnosa).", dx, dy))
                    _VendFailed[dx..","..dy] = true
                    _VendPending = nil
                    SendPacket(2, string.format("action|dialog_return\ndialog_name|vend_buy\nx|%d|\ny|%d|\nbuyamount|0\n", dx, dy))
                    return true
                end
                if priceWl > maxP then
                    Log(string.format("`4[Consume]`w Vending (%d,%d) harga %dWL > max %dWL. Skip.", dx, dy, priceWl, maxP))
                    _VendFailed[dx..","..dy] = true
                    _VendPending = nil
                    SendPacket(2, string.format("action|dialog_return\ndialog_name|vend_buy\nx|%d|\ny|%d|\nbuyamount|0\n", dx, dy))
                    return true
                end
                Log(string.format("`2[Consume]`w Vending (%d,%d) OK: %s %dWL/item, total ~%dWL. Beli %d...", dx, dy, expectName, priceWl, totalWl, buyAmt))
                -- Cek batas total WL
                local maxTotal = math.max(1, tonumber(S.PNB.BuyConsumeMaxTotal) or 500)
                if totalWl > maxTotal then
                    Log(string.format("`4[Consume]`w Total %dWL > batas %dWL. Skip.", totalWl, maxTotal))
                    _VendFailed[dx..","..dy] = true
                    _VendPending = nil
                    SendPacket(2, string.format("action|dialog_return\ndialog_name|vend_buy\nx|%d|\ny|%d|\nbuyamount|0\n", dx, dy))
                    return true
                end
                -- Baca stok vending dari dialog, pakai min(buyAmt, stok) biar tidak overshoot
                local vendStock = tonumber(clean:match("total of (%d+)")) or buyAmt
                local actualAmt = math.min(buyAmt, vendStock)
                if actualAmt < 1 then
                    Log(string.format("`4[Consume]`w Vending (%d,%d) stok 0. Skip.", dx, dy))
                    _VendFailed[dx..","..dy] = true
                    _VendPending = nil
                    SendPacket(2, string.format("action|dialog_return\ndialog_name|vend_buy\nx|%d|\ny|%d|\nbuyamount|0\n", dx, dy))
                    return true
                end
                _VendConfirm = { x = dx, y = dy, amt = actualAmt }
                return true  -- biarkan TakeConsumes yang kirim dialog_return
            end
        end

        -- VENDING: intercept konfirmasi vend_buyconfirm -> auto-confirm HANYA jika vend_buy sudah divalidasi
        if _VendPending and _VendConfirm == nil and a:find("vend_buyconfirm", 1, true) then
            -- _VendConfirm nil di sini berarti hook sudah clear-kan setelah kirim dialog_return vend_buy
            -- tapi belum dapat buyconfirm -- ini flow normal, lanjut confirm
            local dx = tonumber(a:match("embed_data|x|(%d+)")) or -1
            local dy = tonumber(a:match("embed_data|y|(%d+)")) or -1
            local bamt = tonumber(a:match("embed_data|buyamount|(%d+)")) or 1
            if S.PNB.DebugVend then
                Log(string.format("`3[VendDbg]`w vend_buyconfirm x=%d y=%d amt=%d", dx, dy, bamt))
            end
            RunThread(function()
                Sleep(200)
                SendPacket(2, string.format(
                    "action|dialog_return\ndialog_name|vend_buyconfirm\nx|%d|\ny|%d|\nbuyamount|%d|\n",
                    dx, dy, bamt))
            end)
            return true
        end

        -- DIAGNOSTIC LOGGER: Cetak ringkasan setiap dialog yang masuk
        if a:find("clothlease", 1, true) or a:find("Active effects", 1, true) or a:find("Rented Clothing", 1, true) then
            Log(string.format("`3[RentDbg]`w Dialog Masuk! WrenchFlag=%s, Isi=%s", tostring(BotTriggeredWrench), a:sub(1, 80)))
        end

        -- RENTING 1: Intercept Self-Wrench Popup -> deteksi RentEquipped dari Active effects
        -- GUARD KETAT: HANYA aktif saat bot sedang proses RentChecking atau RentWarActive!
        -- Run.start TIDAK cukup -- bot farming normal juga Run.start=true tapi tidak perlu intercept.
        local isSelfPopupWithRent = (a:find("end_dialog|popup", 1, true) or a:find("add_player_info", 1, true)) and a:find("clothlease", 1, true)
        if isSelfPopupWithRent and (RentChecking or RentWarActive) then
            local clean = StripColor(a)
            local target = S.PNB.RentTargetItem or "Auto-Detect"
            -- Ambil bagian Active effects: saja
            local effectsPart = clean:match("Active effects:(.-)end_dialog") or clean
            local isEquipped = false
            if target:find("LSS", 1, true) or target:find("Legendary Shard Sword", 1, true) then
                isEquipped = effectsPart:find("16690", 1, true) ~= nil or effectsPart:lower():find("shard sword", 1, true) ~= nil
            elseif target:find("LRay", 1, true) or target:find("Legendary Ray", 1, true) then
                isEquipped = effectsPart:find("16940", 1, true) ~= nil or effectsPart:lower():find("legendary ray", 1, true) ~= nil
            elseif target:find("MRay", 1, true) or target:find("Mythical Ray", 1, true) then
                isEquipped = effectsPart:find("16976", 1, true) ~= nil or effectsPart:find("19676", 1, true) ~= nil or effectsPart:lower():find("mythical ray", 1, true) ~= nil
            elseif target:find("Ray", 1, true) or target:find("Rayman", 1, true) then
                isEquipped = effectsPart:find("5480", 1, true) ~= nil or effectsPart:lower():find("rayman", 1, true) ~= nil
            else -- Auto-Detect
                isEquipped = effectsPart:find("16690", 1, true) ~= nil or effectsPart:find("16940", 1, true) ~= nil or effectsPart:find("16976", 1, true) ~= nil or effectsPart:find("19676", 1, true) ~= nil or effectsPart:find("5480", 1, true) ~= nil
            end
            RentEquipped = (isEquipped == true)
            Log(string.format("`2[Rent]`w Target: %s | Status di badan: %s", target, RentEquipped and "`2TERPASANG`w" or "`4BELUM/BUKAN TARGET`w"))
            -- Lanjut buka menu clothlease untuk baca durasi (beri delay manusiawi agar tidak di-drop server)
            RunThread(function()
                Sleep(250)
                SendPacket(2, "action|dialog_return\ndialog_name|popup\nbuttonClicked|clothlease\n")
            end)
            return true
        end

        -- RENTING 2: Intercept Menu Rented Clothing (clothlease) -> parse durasi + pasang jika perlu
        -- GUARD KETAT: HANYA saat RentChecking atau RentWarActive, bukan Run.start biasa!
        if (RentChecking or RentWarActive) and a:find("clothlease", 1, true) and (a:find("Rented Clothing", 1, true) or a:find("staticframe", 1, true)) then
            local clean = StripColor(a)
            local target = S.PNB.RentTargetItem or "Auto-Detect"
            Log(string.format("`3[Rent]`w clothlease: TargetItem terbaca='%s'", tostring(target)))
            -- Tentukan targetFrame: jika spesifik pilih itu, jika Auto-Detect cari yang ada di dialog
            local targetFrame = nil
            local itemName = "Unknown"

            if target:find("LRay", 1, true) or target:find("Legendary Ray", 1, true) then
                targetFrame = "16940"; itemName = "Legendary Ray (LRay)"
            elseif target:find("MRay", 1, true) or target:find("Mythical Ray", 1, true) then
                targetFrame = clean:find("16976", 1, true) and "16976" or "19676"
                itemName = "Mythical Ray (MRay)"
            elseif target:find("LIF", 1, true) or target:find("Legendary Infinity Fist", 1, true) then
                targetFrame = "19678"; itemName = "Legendary Infinity Fist (LIF)"
            elseif target:find("LSS", 1, true) or target:find("Legendary Shard Sword", 1, true) then
                targetFrame = "16690"; itemName = "Legendary Shard Sword (LSS)"
            elseif target:find("Ray", 1, true) or target:find("Rayman", 1, true) then
                targetFrame = "5480"; itemName = "Rayman's Fist (Ray)"
            else
                -- AUTO-DETECT: cari berdasarkan prioritas yang ADA di dialog clothlease
                if clean:find("16976", 1, true) then
                    targetFrame = "16976"; itemName = "Mythical Ray (MRay)"
                elseif clean:find("19676", 1, true) then
                    targetFrame = "19676"; itemName = "Mythical Ray (MRay)"
                elseif clean:find("16940", 1, true) then
                    targetFrame = "16940"; itemName = "Legendary Ray (LRay)"
                elseif clean:find("19678", 1, true) then
                    targetFrame = "19678"; itemName = "Legendary Infinity Fist (LIF)"
                elseif clean:find("16690", 1, true) then
                    targetFrame = "16690"; itemName = "Legendary Shard Sword (LSS)"
                elseif clean:find("5480", 1, true) then
                    targetFrame = "5480"; itemName = "Rayman's Fist (Ray)"
                else
                    targetFrame = "16690"; itemName = "Default (16690)"
                end
                Log(string.format("`2[Rent]`w Auto-Detect memilih: %s (frame=%s)", itemName, targetFrame))
            end
            -- Cari baris yang punya staticframe targetFrame
            local btnName = ""   -- kosong = tidak ditemukan, jangan klik!
            local totalSec = 0
            for line in clean:gmatch("[^\r\n]+") do
                if line:find(targetFrame, 1, true) and line:find("cloth_", 1, true) then
                    btnName = line:match("(cloth_%-?%d+)") or ""
                    local durStr = line:match("cloth_%-?%d+|(.-)%|staticframe") or ""
                    local days = tonumber(durStr:match("(%d+)d")) or 0
                    local hrs  = tonumber(durStr:match("(%d+)h")) or 0
                    local mins = tonumber(durStr:match("(%d+)m")) or 0
                    local secs = tonumber(durStr:match("(%d+)s")) or 0
                    totalSec = days * 86400 + hrs * 3600 + mins * 60 + secs
                    Log(string.format("`2[Rent]`w Parser: targetFrame=%s -> btn=%s durasi=%ds", targetFrame, btnName, totalSec))
                    break
                end
            end
            if btnName == "" then
                Log(string.format("`4[Rent]`w TIDAK DITEMUKAN tombol untuk %s (frame=%s) di dialog clothlease!", itemName, targetFrame))
            end
            RentClothBtn = btnName
            if totalSec > 0 then
                RentExpires = NowTime() + totalSec
                Log(string.format("`2[Rent]`w Sisa durasi %s: %s", itemName, FTime(totalSec)))
            else
                Log("`4[Rent]`w Item target tidak ditemukan di menu clothlease atau durasi 0!")
            end
            -- Pasang HANYA jika belum terpasang (RentEquipped di-set akurat oleh RENTING 1 / OnConsoleMessage)
            if RentEquipped then
                Log("`2[Rent]`w Item SUDAH TERPASANG. TIDAK DIKLIK (anti-copot).")
            elseif btnName == "" then
                Log("`4[Rent]`w Tombol item tidak ditemukan, BATAL klik pasang agar tidak salah copot!")
            else
                Log(string.format("`4[Rent]`w Item BELUM TERPASANG! Mengirim klik pasang (%s) dalam 350ms...", btnName))
                -- Delay manusiawi agar packet tidak di-drop oleh anti-cheat server GT
                RunThread(function()
                    Sleep(350)
                    SendPacket(2, "action|dialog_return\ndialog_name|clothlease\nbuttonClicked|" .. btnName .. "\n")
                    RentEquipped = true
                    Log("`2[Rent]`w Packet pasang terkirim! RentEquipped=true.")
                end)
            end
            BotTriggeredWrench = false
            RentChecking = false
            return true
        end

        -- RENTING 3: Intercept dialog konfirmasi sewa (rent_buyconfirm) -- HANYA jika bot sedang war sewa!
        if RentWarActive and (a:find("rent_buyconfirm", 1, true) or a:find("Purchase Confirmation", 1, true)) then
            local wtb = a:match("embed_data|wtb|([%d%-]+)")
            local rx = a:match("embed_data|x|(%d+)") or S.RentX
            local ry = a:match("embed_data|y|(%d+)") or S.RentY
            if wtb then
                RentWtb = wtb
                Log(string.format("`2[Rent]`w Konfirmasi WTB (%s) mesin (%s,%s)! Mengirim packet beli...", wtb, tostring(rx), tostring(ry)))
                RunThread(function()
                    Sleep(200)
                    SendPacket(2, string.format("action|dialog_return\ndialog_name|rent_buyconfirm\nwtb|%s|\nx|%d|\ny|%d|\n", wtb, tonumber(rx), tonumber(ry)))
                    RentStep = "WAIT_RESULT"
                    RentStepTime = NowTime()
                end)
            end
            return true
        end

        -- RENTING 4: Intercept dialog Renting Station (rent_buy) -- HANYA jika bot sedang war sewa!
        if RentWarActive and (a:find("rent_buy", 1, true) or a:find("Renting Station", 1, true)) then
            local rx = a:match("embed_data|x|(%d+)") or S.RentX
            local ry = a:match("embed_data|y|(%d+)") or S.RentY
            Log(string.format("`2[Rent]`w Dialog mesin terbuka (%s,%s)! Mengirim tombol sewa...", tostring(rx), tostring(ry)))
            RunThread(function()
                Sleep(200)
                SendPacket(2, string.format("action|dialog_return\ndialog_name|rent_buy\nx|%d|\ny|%d|\n", tonumber(rx), tonumber(ry)))
                RentStep = "WAIT_CONFIRM"
                RentStepTime = NowTime()
            end)
            return true
        end

        -- Paywall dialog intercept
        if a:find("paywall", 1, true) or a:find("Pay Wall", 1, true) then
            local mx = a:match("embed_data|x|(%d+)")
            local my = a:match("embed_data|y|(%d+)")
            local tx = tonumber(mx) or S.PaywallX
            local ty = tonumber(my) or S.PaywallY

            -- Cek sisa waktu: parse format jam, menit, detik (kebal format variasi)
            local clean = a:gsub("`.", "")
            if clean:find("Time left:", 1, true) then
                local hrs  = tonumber(clean:match("(%d+)%s*hour")) or 0
                local mins = tonumber(clean:match("(%d+)%s*min"))  or 0
                local secs = tonumber(clean:match("(%d+)%s*sec"))  or 0
                local rem = hrs * 3600 + mins * 60 + secs
                if rem > 0 then
                    PaywallExpires = NowTime() + rem
                    Log(string.format("`2[Paywall]`w Akses masih aktif. Sisa: %s", FTime(rem)))
                    return true
                end
            end

            -- Dialog purchase (belum punya akses / habis / dicabut paksa)
            if a:find("Purchase!", 1, true) and S.PNB.AutoPaywall then
                local isRevoked = (PaywallExpires > NowTime() + 60)
                local allowBuy = false

                if isRevoked then
                    if S.PNB.AutoBuyPaywall then
                        Log("`3[Paywall]`w Akses DICABUT PAKSA! Toggle beli paksa ON -> Membeli ulang...")
                        allowBuy = true
                    else
                        Log("`4[Paywall]`w Akses DICABUT PAKSA oleh owner! Beli paksa OFF -> Kirim WA alert...")
                        pcall(SendWhatsAppAlert, "Akses Paywall Dicabut", "Owner mencabut akses pintu paywall dan AutoBuyPaywall nonaktif. Bot standby di depan paywall.")
                        Run.status = "Akses Dicabut (Standby)"
                        Cheat(false)
                        m = false
                        return true
                    end
                else
                    if S.PNB.AutoRenewPaywall or S.PNB.AutoBuyPaywall then
                        Log(string.format("`9[Paywall]`w Membeli akses paywall (%d, %d)...", tx, ty))
                        allowBuy = true
                    else
                        Log("`4[Paywall]`w Waktu sewa paywall habis! Auto-renew OFF -> Kirim WA alert...")
                        pcall(SendWhatsAppAlert, "Sewa Paywall Habis", "Akses paywall habis dan AutoRenewPaywall nonaktif. Bot standby.")
                        Run.status = "Sewa Habis (Standby)"
                        Cheat(false)
                        m = false
                        return true
                    end
                end

                if allowBuy then
                    SendPacket(2, string.format("action|dialog_return\ndialog_name|paywall\nx|%d|\ny|%d|\n", tx, ty))
                    PaywallExpires = 0
                end
            else
                -- Tutup dialog tanpa aksi (jangan biarkan menggantung di layar)
                SendPacket(2, "action|dialog_return\ndialog_name|paywall\nbuttonClicked|\n")
            end
            return true
        end
        if a:find("MAGPLANT 5000", 1, true) or a:find("magplant_edit", 1, true) then
            local mx = a:match("embed_data|x|(%d+)")
            local my = a:match("embed_data|y|(%d+)")
            if a:find("Stock: `4EMPTY!", 1, true)
               or a:find("EMPTY!", 1, true)
               or a:find("The machine is currently empty!", 1, true) then
                if mx and my then
                    MagEmpty[mx .. "," .. my] = true
                elseif S.MagplantX ~= 0 then
                    MagEmpty[S.MagplantX .. "," .. S.MagplantY] = true
                end
                LastDialogEmpty = true
                changeRemote = true
            else
                LastDialogEmpty = false
                -- Coba parse angka stok asli dari dialog Growtopia
                local rawStock = a:match("Stock:%s*`?[%a%d]?([%d,]+)") or a:match("Stock%s*:%s*([%d,]+)") or a:match("([%d,]+)/200000") or a:match("([%d,]+)/5000")
                local count = nil
                if rawStock then
                    local cleanNum = rawStock:gsub(",", "")
                    count = tonumber(cleanNum)
                end
                if mx and my then
                    MarkMagReady(tonumber(mx), tonumber(my), count, "local")
                elseif S.MagplantX ~= 0 then
                    MarkMagReady(S.MagplantX, S.MagplantY, count, "local")
                end
            end
            return true
        end
        for _, p in ipairs(BlockDialogs) do
            if a:find(p, 1, true) then return true end
        end
    elseif k == "OnConsoleMessage" and type(a) == "string" then
        -- VENDING: deteksi sukses beli dari console message
        if _VendPending and a:find("bought", 1, true) then
            _VendBought = true
        end
        -- [16c] Deteksi disconnect
        if a:find("Disconnected", 1, true) then Disconnected = true end
        -- [10] Radio: kirim /radio HANYA saat console "Radio enabled," dan blockSB belum aktif
        if a:find("Radio enabled,", 1, true) then
            if not blockSB then
                if S.PNB.AutoRadio then SendPacket(2, "action|input\n|text|/radio") end
                blockSB = true
            end
        end
        -- [3] Deteksi cheat expired dari pesan server (semua varian text GT)
        if a:find("boringness", 1, true) or a:find("worn off", 1, true)
            or a:find("expired", 1, true) or a:find("Cheat deactivated", 1, true)
            or a:find("cheats have ended", 1, true) then
            CheatNeedsRenewal = true
            LastBuyCheat = 0 -- reset timer agar BuyCheat() langsung jalan di Step berikutnya
            Log("`3[Cheat]`w Cheat MATI terdeteksi! Re-buy segera...")
        end
        -- Deteksi sukses sewa dari console message
        if a:find("rented 1", 1, true) and a:find("for 1 day", 1, true) then
            RentSuccess = true
            RentWarActive = false
            Log("`2[Rent]`w Konfirmasi: " .. StripColor(a))
        end
        -- SENSOR PRESISI DARI NAMA MOD RESMI GROWTOPIA
        -- Hanya update RentEquipped jika item yang berubah SESUAI TARGET
        local rentTarget = S.PNB.RentTargetItem or "Auto-Detect"
        local isLSS  = a:find("Legendary Shard Sword mod", 1, true)
        local isLRay = a:find("Legendary Powers mod", 1, true)
        local isMRay = a:find("Mythical Ray mod", 1, true) or a:find("Mythical Powers mod", 1, true)
        local isRay  = a:find("Rayman", 1, true)
        local isAdded   = a:find("mod added", 1, true)
        local isRemoved = a:find("mod removed", 1, true)

        local targetMatch = false
        if rentTarget:find("LSS", 1, true) or rentTarget:find("Legendary Shard Sword", 1, true) then
            targetMatch = isLSS ~= nil
        elseif rentTarget:find("LRay", 1, true) or rentTarget:find("Legendary Ray", 1, true) then
            targetMatch = isLRay ~= nil
        elseif rentTarget:find("MRay", 1, true) or rentTarget:find("Mythical Ray", 1, true) then
            targetMatch = isMRay ~= nil
        elseif rentTarget:find("Ray", 1, true) or rentTarget:find("Rayman", 1, true) then
            targetMatch = isRay ~= nil
        else -- Auto-Detect: semua item sewa valid
            targetMatch = (isLSS or isLRay or isMRay or isRay) ~= nil
        end

        if targetMatch then
            if isAdded then
                RentEquipped = true
                RentLastToggle = NowTime()
                Log("`2[Rent]`w Item target TERPASANG (mod added sesuai target: " .. rentTarget .. ")")
            elseif isRemoved then
                RentEquipped = false
                RentLastToggle = NowTime()
                Log("`4[Rent]`w Item target DILEPAS (mod removed sesuai target: " .. rentTarget .. ")")
            end
        elseif (isLSS or isLRay or isMRay) then
            Log("`3[Rent]`w Mod item lain berubah (bukan target), RentEquipped tidak diubah.")
        end
        for _, p in ipairs(BlockConsole) do
            if a:find(p, 1, true) then return true end
        end
    elseif k == "OnTalkBubble" and type(b) == "string" then
        -- Update PaywallExpires saat berhasil beli akses
        if b:find("granted access", 1, true) and b:find("Pay Wall", 1, true) then
            local hrs = b:match("for `%$(%d+) hour")
            local dur = (tonumber(hrs) or 1) * 3600
            PaywallExpires = NowTime() + dur
            Log(string.format("`2[Paywall]`w Akses dibeli! Habis dalam %s.", FTime(dur)))
            return false -- biarkan bubble tampil
        end
        -- Deteksi habis: kunci ke string resmi Growtopia Magplant, dan hanya jika bot memegang target
        if (b:find("The MAGPLANT 5000 is empty", 1, true) or b:find("MAGPLANT 5000 is empty", 1, true)) and S.MagplantX ~= 0 and S.MagplantY ~= 0 then
            Log(string.format("`4[SmartMag]`w Mag (%d, %d) HABIS! Lapor ke fleet (stok: 0)...", S.MagplantX, S.MagplantY))
            MarkMagEmpty(S.MagplantX, S.MagplantY, MAG_TTL_SEC, "local")
            S.MagplantX = 0
            S.MagplantY = 0
            changeRemote = true
            return true
        end
        if S.PNB.HideCollected and b:find("Collected", 1, true) then return true end
    end
    return false
end)

-- ============================================================
--  GUI v3  CLEAN DARK  (no webhook, all features)
-- ============================================================

-- PALET: 1 aksen biru-ungu + 3 status. Sisanya abu gelap.
local T = {
    accent = { 0.42, 0.52, 1.00, 1 },
    ok     = { 0.32, 0.80, 0.52, 1 },
    warn   = { 0.96, 0.76, 0.32, 1 },
    bad    = { 0.93, 0.38, 0.42, 1 },
    text   = { 0.90, 0.91, 0.95, 1 },
    dim    = { 0.55, 0.57, 0.65, 1 },
    card   = { 0.11, 0.11, 0.15, 1 },
    field  = { 0.14, 0.14, 0.19, 1 },
    line   = { 0.22, 0.23, 0.30, 1 },
    btn    = { 0.17, 0.18, 0.25, 1 },
}

local function AvailW()
    if ImGui.GetContentRegionAvailX then return ImGui.GetContentRegionAvailX() end
    local ok, v = pcall(ImGui.GetContentRegionAvail)
    if ok and v then return v.x or 400 end
    return 400
end

local function V4(c) return ImVec4(c[1], c[2], c[3], c[4] or 1) end

local function Dim(c, f)
    return { math.min(1, c[1]*f), math.min(1, c[2]*f), math.min(1, c[3]*f), c[4] or 1 }
end

local function CText(c, txt)
    if ImGui.TextColored and ImVec4 then
        if pcall(ImGui.TextColored, V4(c), txt) then return end
    end
    ImGui.Text(txt)
end

local function PushCols(list)
    if not (ImGui.PushStyleColor and ImGui.PopStyleColor and ImVec4) then return 0 end
    local enum = ImGuiCol or ImGuiCol_
    if not enum then return 0 end
    local n = 0
    for _, e in ipairs(list) do
        local id = enum[e[1]]
        if id ~= nil and pcall(ImGui.PushStyleColor, id, V4(e[2])) then n = n + 1 end
    end
    return n
end

local function PopCols(n)
    if n > 0 then
        for _ = 1, n do pcall(ImGui.PopStyleColor) end
    end
end

local function PushVars()
    -- Nonaktifkan PushVars sementara agar tidak memicu stack crash di Bothax mobile
    return 0
end

local function PopVars(n)
    if n > 0 then
        for _ = 1, n do pcall(ImGui.PopStyleVar) end
    end
end

local function Sp(h) ImGui.SetCursorPosY(ImGui.GetCursorPosY() + (h or 4)) end

local function Sep()
    local n = PushCols({ { "Separator", T.line } })
    ImGui.Separator()
    PopCols(n)
end

local function Btn(label, col, w, h)
    -- Warna tombol sudah di-set dari PushCols global di OnDraw.
    -- Hanya push ekstra jika col beda dari default T.btn.
    local n = 0
    if col and col ~= T.btn then
        n = PushCols({
            { "Button",        Dim(col, 0.85) },
            { "ButtonHovered", col },
            { "ButtonActive",  Dim(col, 1.2) },
        })
    end
    local r = ImGui.Button(label, ImVec2(w or -1, h or 34))
    if n > 0 then PopCols(n) end
    return r
end

local function Half() return AvailW() / 2 - 4 end

local function CB(label, val)
    local r1, r2 = ImGui.Checkbox(label, val and true or false)
    if r2 ~= nil then return r1, r2 end
    if r1 then return true, not val end
    return false, val
end

local function FW()
    if ImGui.SetNextItemWidth then pcall(ImGui.SetNextItemWidth, -1) end
end

local function Row(label, value, col)
    CText(T.dim, label)
    ImGui.SameLine(130)
    CText(col or T.text, tostring(value))
end

local function Bar(frac, label)
    frac = math.max(0, math.min(1, frac))
    if ImGui.ProgressBar then
        local n = PushCols({ { "PlotHistogram", T.accent }, { "FrameBg", T.field } })
        pcall(ImGui.ProgressBar, frac, ImVec2(-1, 14), label or "")
        PopCols(n)
    else
        ImGui.Text(label or "")
    end
end

local cardStack = {}
local function Card(id, h, title)
    -- Bothax mobile sering crash di BeginChild, pakai separator & title sebagai fallback aman
    if title then
        Sp(3)
        CText(T.accent, "?? " .. title .. " " .. string.rep("?", 20))
        Sp(1)
    end
end

local function EndCard()
    Sp(2)
end

local function Group(title, defaultOpen)
    if not ImGui.CollapsingHeader then CText(T.accent, title); return true end
    local ok, res = pcall(ImGui.CollapsingHeader, title, defaultOpen and 32 or 0)
    if not ok then return true end
    return res and true or false
end

-- ?? TAB: FARM ???????????????????????????????????????????????
local function TabFarm()
    local running = Run.start
    if running then
        if Btn("STOP", T.bad, -1, 46) then StopPNB() end
    else
        if Btn("START", T.ok, -1, 46) then StartPNB() end
    end
    CText(running and T.ok or T.dim, running and ("  " .. Run.status) or "  Idle")
    CText(T.dim, "  Build: " .. BUILD_ID .. " | CLEAN DARK v3")
    Sp(4)

    Card("c_stat", 154, "Statistik")
    Row("Gems",       FNum(Gems()),                           T.accent)
    Row("Gems/jam",   FNum(GetEfficiency()),                  running and T.ok or T.dim)
    Row("DL / BGL",   inv(1796) .. " / " .. inv(7188),       T.warn)
    Row("Remote",     inv(5640) .. "x",                      inv(5640) > 0 and T.text or T.bad)
    Row("Mag aktif",  string.format("(%d,%d)", S.MagplantX, S.MagplantY), T.dim)
    Row("Uptime",     running and FTime(NowTime() - Run.startTime) or "--:--:--", T.text)
    EndCard()

    Sp(4)
    Card("c_world", 160, "World & Posisi")
    FW()
    local ch, nv = ImGui.InputText("##world", worldName, 64)
    if ch then worldName = tostring(nv):upper() end
    if Btn("World Sekarang", T.btn, Half(), 32) then
        local w = WorldNow()
        if w then worldName = w; RecalcMag(); Log("World: " .. w)
        else Log("`4Belum di dalam world") end
    end
    local posSet = S.PosX ~= 0 or S.PosY ~= 0
    if Btn("Set Pos (Berdiri)", T.btn, Half(), 32) then
        local me = GetLocal()
        if me and me.pos then
            S.PosX = math.floor(me.pos.x / 32)
            S.PosY = math.floor(me.pos.y / 32)
            Log(string.format("`2Farm Pos (Berdiri): (%d, %d)", S.PosX, S.PosY))
            RecalcMag()
        else
            Log("`4Gagal mendeteksi posisi bot!")
        end
    end
    ImGui.SameLine()
    if Btn("Punch Tile Pos", CaptureFarmPos and T.accent or T.btn, -1, 32) then
        CaptureFarmPos = true
        Log("`9[Farm]`w Pukul/Punch tile tempat farm...")
    end
    if posSet then
        Row("Posisi Farm", string.format("(%d, %d)", S.PosX, S.PosY), T.ok)
    else
        Row("Posisi Farm", "BELUM DI-SET", T.bad)
    end
    EndCard()

    Sp(4)
    Card("c_face", 80, "Arah hadap (BFG)")
    if Btn("KIRI", not S.PNB.FaceRight and T.accent or T.btn, Half(), 36) then
        S.PNB.FaceRight = false
    end
    ImGui.SameLine()
    if Btn("KANAN", S.PNB.FaceRight and T.accent or T.btn, -1, 36) then
        S.PNB.FaceRight = true
    end
    EndCard()
end

-- ?? TAB: MAG ????????????????????????????????????????????????
local function TabMag()
    local total, empty = #Mag, 0
    for _, mp in ipairs(Mag) do
        if MagEmpty[mp.x .. "," .. mp.y] then empty = empty + 1 end
    end
    local ready = total - empty

    Card("c_magsum", 128, "Ringkasan Magplant")
    Row("Terdeteksi", total, T.text)
    Row("Siap pakai", ready, ready > 0 and T.ok or T.bad)
    Row("Kosong",     empty, empty > 0 and T.bad or T.ok)
    Sp(2)
    Bar(total > 0 and ready / total or 0, ready .. " / " .. total)
    EndCard()

    Sp(4)
    if Btn("Scan Ulang", T.accent, Half(), 34) then
        MagIntel = {}; PendingMagSync = {}; RecalcMag()
        Log("`2SmartMag: scan ulang")
    end
    ImGui.SameLine()
    if Btn("Reset Status Kosong", T.warn, -1, 34) then
        MagIntel = {}; PendingMagSync = {}; RecalcMag()
        Log("`2SmartMag: status kosong di-reset")
    end

    Sp(4)
    -- Filter BG
    local csb, vsb = CB("Filter Magplant berdasarkan Background ID", S.PNB.ScanBG)
    if csb then S.PNB.ScanBG = vsb; RecalcMag() end
    if S.PNB.ScanBG then
        FW()
        CText(T.dim, "Target BG ID:")
        FW()
        local cmb, vmb = ImGui.InputInt("##bgid", S.PNB.MagBgID)
        if cmb then S.PNB.MagBgID = math.max(0, vmb); RecalcMag() end
    end

    Sp(4)
    local shown = math.min(6, #Mag)
    Card("c_maglist", math.max(60, shown * 22 + 36), "Magplant Terdekat")
    if #Mag == 0 then
        CText(T.bad, "Tidak ada magplant terdeteksi")
    end
    for i = 1, shown do
        local mp = Mag[i]
        local dist = math.abs(mp.x - S.PosX) + math.abs(mp.y - S.PosY)
        local isCd, remSec, src = IsMagCooldown(mp.x, mp.y)
        local active = (mp.x == S.MagplantX and mp.y == S.MagplantY)
        local col, state = T.ok, "READY"
        if isCd then
            col = (src == "shared") and T.warn or T.bad
            local m, s = math.floor(remSec/60), remSec%60
            state = string.format("EMPTY %dm%02ds%s", m, s, src == "shared" and " (shared)" or "")
        end
        CText(active and T.accent or T.dim, active and "  > " or "    ")
        ImGui.SameLine(30)
        CText(T.text, string.format("(%d,%d)", mp.x, mp.y))
        ImGui.SameLine(100)
        CText(T.dim, "d" .. dist)
        ImGui.SameLine(145)
        CText(col, state)
    end
    EndCard()
end

-- ?? TAB: SETTING ????????????????????????????????????????????
local function TabSetting()
    local avail = AvailW()

    -- CONSUMABLE RESTOCK
    if Group("Beli Consumable dari Vending", false) then
        local cbBuy, vBuy = CB("Aktifkan Auto Beli Consumable##abc", S.PNB.BuyConsumables)
        if cbBuy then S.PNB.BuyConsumables = vBuy end

        if S.PNB.BuyConsumables then
            Sp(2)
            CText(T.dim, "Item yang dibeli kalau habis:")
            local cbA, vA = CB("Arroz Con Pollo (4604)##bca", S.PNB.BuyConsumeArroz)
            if cbA then S.PNB.BuyConsumeArroz = vA end
            local cbC, vC = CB("Four-Leaf Clover (528)##bcc", S.PNB.BuyConsumeClover)
            if cbC then S.PNB.BuyConsumeClover = vC end
            local cbS, vS = CB("Songpyeon (1056)##bcs", S.PNB.BuyConsumeSong)
            if cbS then S.PNB.BuyConsumeSong = vS end
            Sp(3)

            CText(T.dim, "World vending (kosong = world farm):")
            FW()
            local chW, nvW = ImGui.InputText("##bcworld", S.PNB.BuyConsumeWorld, 64)
            if chW then S.PNB.BuyConsumeWorld = tostring(nvW):upper() end
            if Btn("World Sekarang##bcwcur", T.btn, -1, 26) then
                local cw = WorldNow()
                if cw then S.PNB.BuyConsumeWorld = cw; Log("World Vending: " .. cw) end
            end
            Sp(3)

            CText(T.dim, "Max Harga / item (WL):")
            FW()
            local cpx, vpx = ImGui.InputInt("##bcmp", S.PNB.BuyConsumeMaxPrice)
            if cpx then S.PNB.BuyConsumeMaxPrice = math.max(1, vpx) end
            CText(T.dim, "Jumlah Beli per Transaksi:")
            FW()
            local cpa, vpa = ImGui.InputInt("##bcamt", S.PNB.BuyConsumeAmount)
            if cpa then S.PNB.BuyConsumeAmount = math.max(1, vpa) end
            CText(T.dim, "Max Coba per Item:")
            FW()
            local cpt, vpt = ImGui.InputInt("##bctr", S.PNB.BuyConsumeTries)
            if cpt then S.PNB.BuyConsumeTries = math.max(1, vpt) end
            CText(T.dim, "Max Total WL per Transaksi:")
            FW()
            local cpmx, vpmx = ImGui.InputInt("##bcmxt", S.PNB.BuyConsumeMaxTotal)
            if cpmx then S.PNB.BuyConsumeMaxTotal = math.max(1, vpmx) end
            Sp(2)
            local cbD, vD = CB("Debug Vend (log tile.extra)##dbvend", S.PNB.DebugVend)
            if cbD then S.PNB.DebugVend = vD end
        end
        Sp(4)
    end

    -- RENT STATION
    if Group("Sewa Item Clothing (Rent Station)", true) then
        local cbRent, vRent = CB("Aktifkan Auto Rent PNB##arn", S.PNB.AutoRent)
        if cbRent then S.PNB.AutoRent = vRent end

        if S.PNB.AutoRent then
            Sp(2)
            CText(T.dim, "Target Item Sewa:")
            local targets = {
                { "Auto", "Auto-Detect" },
                { "LSS",  "Legendary Shard Sword" },
                { "MRay", "Mythical Ray" },
                { "LRay", "Legendary Ray" },
                { "Ray",  "Rayman's Fist" },
            }
            local curTarget = S.PNB.RentTargetItem or "Auto-Detect"
            local btnW = (avail / #targets) - 3
            for i, t in ipairs(targets) do
                local isSel = (curTarget == t[2])
                if Btn(t[1] .. "##rtg"..i, isSel and T.accent or T.btn, btnW, 28) then
                    if curTarget ~= t[2] then
                        S.PNB.RentTargetItem = t[2]
                        RentEquipped = false; RentClothBtn = ""
                        Log("`2[Rent]`w Target: " .. t[2])
                        RunThread(function() Sleep(200); pcall(CheckRentStatus, true) end)
                    end
                end
                if i < #targets then ImGui.SameLine() end
            end
            Sp(4)

            local remRent = math.max(0, RentExpires - NowTime())
            local rCol = remRent > 300 and T.ok or (remRent > 0 and T.warn or T.bad)
            CText(RentEquipped and T.ok or T.bad,
                string.format("  %s  |  %s",
                    RentEquipped and "[?] TERPASANG" or "[!] BELUM DIPAKAI",
                    curTarget:gsub("Legendary ","L-"):gsub("Mythical ","M-")))
            CText(rCol, "  " .. (remRent > 0 and ("Sisa: " .. FTime(remRent)) or "HABIS / BELUM"))
            Sp(3)

            if Btn("? Cek & Pasang Sewa", T.accent, Half(), 36) then
                RunThread(function() pcall(CheckRentStatus, true) end)
            end
            ImGui.SameLine()
            if Btn("? War Sewa (Spam)", T.bad, -1, 36) then
                RunThread(function() pcall(DoWarRent) end)
            end
            if RentClothBtn ~= "" then
                Sp(2)
                if Btn("Paksa Pasang (" .. RentClothBtn .. ")", T.warn, -1, 30) then
                    RunThread(function() pcall(SilentEquipRent, true) end)
                end
            end
            Sp(3)

            FW()
            CText(T.dim, "World Sewa:")
        FW()
        local chRw, nvRw = ImGui.InputText("##rw", S.PNB.RentWorld, 64)
            if chRw then S.PNB.RentWorld = tostring(nvRw):upper() end
            if Btn("World Sekarang##rwcur", T.btn, -1, 26) then
                local cw = WorldNow()
                if cw then S.PNB.RentWorld = cw; Log("World Sewa: " .. cw) end
            end

            local rSet = S.RentX ~= 0 or S.RentY ~= 0
            if Btn("Punch Mesin Sewa", CaptureRent and T.accent or T.btn, Half(), 30) then
                CaptureRent = true
                Log("`9[Rent]`w Punch Renting Station untuk set posisi...")
            end
            ImGui.SameLine()
            if Btn("Set Mesin (Berdiri)", T.btn, -1, 30) then
                local me = GetLocal and GetLocal()
                if me and me.pos then
                    S.RentX = math.floor(me.pos.x / 32)
                    S.RentY = math.floor(me.pos.y / 32)
                    Log(string.format("`2[Rent]`w Mesin Sewa di-set (Berdiri): (%d, %d)", S.RentX, S.RentY))
                end
            end
            if rSet then
                Row("Mesin Sewa", string.format("(%d, %d)", S.RentX, S.RentY), T.ok)
            else
                Row("Mesin Sewa", "BELUM DI-SET", T.bad)
            end
            if rSet and ImGui.Button("Reset Pos Mesin##rst_rent", ImVec2(-1, 22)) then
                S.RentX = 0; S.RentY = 0; RentExpires = 0
            end
        end
        Sp(4)
    end

    -- PAYWALL
    if Group("Paywall", false) then
        if S.PNB.AutoPaywall then
            local c1, v1 = CB("Auto Renew (perpanjang sebelum habis)##arw", S.PNB.AutoRenewPaywall)
            if c1 then S.PNB.AutoRenewPaywall = v1 end
            local c2, v2 = CB("Auto Beli Paksa (kalau dicabut owner)##abp", S.PNB.AutoBuyPaywall)
            if c2 then S.PNB.AutoBuyPaywall = v2 end
            CText(S.PNB.AutoBuyPaywall and T.accent or T.warn,
                S.PNB.AutoBuyPaywall and "  Jika dicabut: beli ulang otomatis."
                                      or "  Jika dicabut: PNB stop (WL aman).")
            Sp(3)
            local pwSet = S.PaywallX ~= 0 or S.PaywallY ~= 0
            if Btn(pwSet and string.format("[OK] Paywall: (%d, %d)", S.PaywallX, S.PaywallY) or "[!] Punch Tile Paywall untuk Set", pwSet and T.accent or T.bad, -1, 32) then
                CapturePaywall = true
                Log("`9[Paywall]`w Punch tile paywall untuk set posisi...")
            end
            if pwSet then
                local rem = math.max(0, PaywallExpires - NowTime())
                local ec = rem > 300 and T.ok or (rem > 0 and T.warn or T.bad)
                CText(ec, "  " .. (rem > 0 and ("Sisa: " .. FTime(rem)) or "Habis / Belum"))
                if Btn("Cek Paywall Sekarang", T.accent, Half(), 28) then
                    RunThread(function() pcall(CheckPaywall, true) end)
                end
                ImGui.SameLine()
                if Btn("Reset##rst_pw", T.btn, -1, 28) then
                    S.PaywallX = 0; S.PaywallY = 0; PaywallExpires = 0
                end
            end
        else
            CText(T.dim, "  Aktifkan 'Auto Paywall' di Fitur untuk setting ini.")
        end
        Sp(4)
    end

    -- TELEPHONE & CONVERT GEMS
    if Group("Telephone & Convert Gems", false) then
        local conv = {
            { "AutoBuyWL",    "Auto Buy WL" },
            { "ConvertDLBGL", "Gems -> DL -> BGL" },
            { "ConvertBGL",   "Gems -> BGL langsung" },
        }
        for _, o in ipairs(conv) do
            local c, v = CB(o[2], S.PNB[o[1]])
            if c then S.PNB[o[1]] = v end
        end
        FW()
        CText(T.dim, "Max Gems (convert):")
        FW()
        local cg, mg = ImGui.InputInt("##maxgems", S.PNB.MaxGems)
        if cg then S.PNB.MaxGems = math.max(0, mg) end
        FW()
        CText(T.dim, "Tel X:")
        FW()
        local ctx, tx = ImGui.InputInt("##telx", S.TelX); if ctx then S.TelX = tx end
        CText(T.dim, "Tel Y:")
        FW()
        local cty, ty = ImGui.InputInt("##tely", S.TelY); if cty then S.TelY = ty end
        Sp(2)
        if Btn("Auto Cari Telephone di World", T.accent, -1, 30) then AutoFindTel() end
        if Btn("Set Tel di Posisi Saya", T.btn, Half(), 26) then
            local me = GetLocal and GetLocal()
            if me and me.pos then
                S.TelX = math.floor(me.pos.x / 32)
                S.TelY = math.floor(me.pos.y / 32)
                Log(string.format("`2[Tel]`w Tel pos: (%d, %d)", S.TelX, S.TelY))
            end
        end
        ImGui.SameLine()
        local telSet = S.TelX ~= 0 or S.TelY ~= 0
        if Btn(telSet and string.format("[OK] Tel:(%d,%d)", S.TelX, S.TelY) or "Punch Tile Tel", telSet and T.ok or T.bad, -1, 26) then
            CaptureTel = true
            Log("`9[Tel]`w Punch tile telephone untuk set posisi...")
        end
        if S.TelX ~= 0 and ImGui.Button("Reset Tel Pos##rst_tel", ImVec2(-1, 22)) then
            S.TelX = 0; S.TelY = 0
        end
        Sp(4)
    end

    -- FITUR & TOGGLE
    if Group("Fitur & Toggle PNB", false) then
        local opts = {
            { "Modfly",            "Modfly" },
            { "TakeMagFromBehind", "Scan mag dari belakang" },
            { "AutoCollectGems",   "Auto collect gems" },
            { "AutoChangeRemote",  "Auto ganti remote" },
            { "AutoConsumables",   "Auto consume" },
            { "AutoSuckBgems",     "Auto suck black gems" },
            { "AutoBuyCheats",     "Auto buy cheats" },
            { "AutoRadio",         "Auto radio" },
            { "HideCollected",     "Sembunyikan popup collected" },
            { "AntiLag",           "AntiLag / FC guard" },
            { "IgnoreOther",       "Abaikan player lain" },
            { "BypassPaywall",     "Bypass paywall (16308)" },
            { "BypassWayBlock",    "Bypass one-way (3796)" },
            { "AutoPaywall",       "Auto Paywall" },
            { "EnableMonitor",     "Remote command web monitor" },
        }
        for _, o in ipairs(opts) do
            local c, v = CB(o[2], S.PNB[o[1]])
            if c then
                S.PNB[o[1]] = v
                if o[1] == "AntiLag" then ActiveLag(v) end
                UpdateBypassRules()
            end
        end
        FW()
        CText(T.dim, "Monitor Token:")
        FW()
        local chTok, nvTok = ImGui.InputText("##montok", S.PNB.MonitorToken or "", 128)
        if chTok then S.PNB.MonitorToken = tostring(nvTok) end
        Sp(4)
    end

    -- DELAY SPEED
    if Group("Delay Speed", false) then
        FW()
        CText(T.dim, "Buy Cheat (menit):")
        FW()
        local cbc, bcv = ImGui.InputInt("##buycheat", S.DelayBuyCheat)
        if cbc then S.DelayBuyCheat = math.max(1, bcv) end
        FW()
        CText(T.dim, "Per Tile (ms):")
        FW()
        local cp, vp = ImGui.InputInt("##pathtile", S.Delay.PathStep)
        if cp then S.Delay.PathStep = math.max(50, math.min(5000, vp)) end
        Sp(2)
        CText(T.dim, "Kecepatan keseluruhan:")
        local presets = { {"? Fast",60}, {"? Normal",100}, {"? Safe",200}, {"? Pelan",300} }
        local pw = (avail / #presets) - 6
        for i, pr in ipairs(presets) do
            local on = (tonumber(S.Delay.Scale) == pr[2])
            if Btn(pr[1] .. "##dl"..i, on and T.accent or T.btn, pw, 30) then
                S.Delay.Scale = pr[2]; Log("Delay: " .. pr[1])
            end
            if i < #presets then ImGui.SameLine() end
        end
        Sp(4)
    end
end

-- ?? TAB: CONFIG ?????????????????????????????????????????????
local function TabConfig()
    Card("c_save", 126, "Profil Default")
    if Btn("SIMPAN DEFAULT", T.ok, Half(), 38) then SaveSettings() end
    ImGui.SameLine()
    if Btn("MUAT DEFAULT", T.accent, -1, 38) then LoadSettings() end
    Sp(4)
    CText(T.dim, "  Simpan ke Slot:")
    local sw = AvailW() / 3 - 4
    if Btn("SAVE 1", T.btn, sw, 30) then SaveSettings(1) end ImGui.SameLine()
    if Btn("SAVE 2", T.btn, sw, 30) then SaveSettings(2) end ImGui.SameLine()
    if Btn("SAVE 3", T.btn, -1, 30) then SaveSettings(3) end
    CText(T.dim, "  Muat dari Slot:")
    if Btn("LOAD 1", T.btn, sw, 30) then LoadSettings(1) end ImGui.SameLine()
    if Btn("LOAD 2", T.btn, sw, 30) then LoadSettings(2) end ImGui.SameLine()
    if Btn("LOAD 3", T.btn, -1, 30) then LoadSettings(3) end
    EndCard()

    if savePathUsed ~= "" then
        Sp(2); CText(T.dim, "  " .. savePathUsed)
    end
    Sp(4)

    local logH = math.min(14, #LogBuf) * 20 + 50
    Card("c_log", math.max(80, logH), "Log")
    if #LogBuf == 0 then CText(T.dim, "Belum ada log") end
    for i = math.max(1, #LogBuf - 13), #LogBuf do
        CText(T.dim, LogBuf[i])
    end
    EndCard()
    if Btn("Bersihkan Log", T.btn, -1, 28) then LogBuf = {} end
    Sp(4)
    CText(T.dim, "  Monitor: https://gt-pi-ten.vercel.app")
end

-- ?? WINDOW ??????????????????????????????????????????????????
local sizeSet = false
AddHook("OnDraw", "ZAKICIT_DRAW", function()
    if not ImGui then return end
    if not sizeSet and ImGui.SetNextWindowSize then
        pcall(ImGui.SetNextWindowSize, ImVec2(440, 620), 4)
        sizeSet = true
    end

    local nv = PushVars()
    local nc = PushCols({
        { "WindowBg",       { 0.07, 0.07, 0.10, 0.98 } },
        { "ChildBg",        T.card },
        { "TitleBgActive",  { 0.10, 0.11, 0.18, 1 } },
        { "FrameBg",        T.field },
        { "CheckMark",      T.accent },
        { "Button",         T.btn },
        { "ButtonHovered",  Dim(T.btn, 1.4) },
        { "ButtonActive",   Dim(T.btn, 1.8) },
        { "Header",         Dim(T.accent, 0.45) },
        { "HeaderHovered",  Dim(T.accent, 0.65) },
        { "Tab",            T.card },
        { "TabActive",      Dim(T.accent, 0.55) },
        { "Text",           T.text },
    })

    if ImGui.Begin("ZAKICIT PNB v2 [" .. BUILD_ID .. "]") then
        if ImGui.BeginTabBar("ZakiTabs") then
            if ImGui.BeginTabItem("Farm")    then Sp(2); TabFarm();    ImGui.EndTabItem() end
            if ImGui.BeginTabItem("Mag")     then Sp(2); TabMag();     ImGui.EndTabItem() end
            if ImGui.BeginTabItem("Setting") then Sp(2); TabSetting(); ImGui.EndTabItem() end
            if ImGui.BeginTabItem("Config")  then Sp(2); TabConfig();  ImGui.EndTabItem() end
            ImGui.EndTabBar()
        end
    end
    ImGui.End()
    PopCols(nc)
    PopVars(nv)
end)

-- ------------------------------------------------------------
--  INIT
-- ------------------------------------------------------------
if not io or not MakeRequest or not ImGui then
    LogToConsole("Turn On Io, MakeRequest, and ImGui on API List")
end

do
    local w = WorldNow()
    if w then
        worldName = w
        RecalcMag()
    end
end
LoadSettings()
Log("`2ZAKICIT PNB v2 [" .. BUILD_ID .. "] siap. Buka menu.")
