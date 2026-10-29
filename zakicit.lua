-- ============================================================
--  ZAKICIT PNB v2 — Ultimate Consolidated Edition
--  The Continental Architecture + Bothax/Dederika Features + Web Monitor
--  API List required: io, MakeRequest, ImGui
-- ============================================================

-- ------------------------------------------------------------
--  STATE & SETTINGS
-- ------------------------------------------------------------
Setting = {
    PNB = {
        WearItem          = "Mythical Necklace",
        AutoCollectGems   = true,
        AutoChangeRemote  = false,
        AutoConsumables   = true,
        AutoBuyWL         = false,
        ConvertDLBGL      = false,
        ConvertBGL        = false,
        MaxGems           = 400000,
        SendToWebhook     = false,
        HideCollected     = false,
        WebhookURL        = "",
        WebhookDelay      = 300,
        AutoBuyCheats     = true,
        AutoRadio         = true,
        AutoSuckBgems     = true,
        Modfly            = true,
        TakeMagFromBehind = true,
        -- Fitur baru
        FaceRight         = false,   -- hadap kanan saat farming BFG
        AntiLag           = false,   -- skip heavy render (FC prevention)
        IgnoreOther       = false,   -- abaikan player lain
        EnableMonitor     = false,   -- remote command dari server (opt-in)
    },
    World     = "",
    PosX      = 0,
    PosY      = 0,
    MagplantX = 0,
    MagplantY = 0,
    TelX      = 0,
    TelY      = 0,
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
    testHook   = false,
    lastHook   = 0,
}

local worldName     = ""
local changeRemote  = false
local m             = false
local TOP_UP        = false
local GetPos        = false
local CaptureMag    = false
local CaptureBreak  = false
local FirstMagX     = 0
local MagIndex      = 1
local ConsumeTime   = 0
local LastConvert   = 0
local LastBuyCheat  = 0
local savePathUsed  = ""
local blockSB       = false
local Mag           = {}

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

local function obj(id)
    local count = 0
    for _, o in pairs(GetObjectList() or {}) do
        if o.id == id then count = count + o.amount end
    end
    return count
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
    local h = math.floor(sec / 3600)
    local mi = math.floor((sec % 3600) / 60)
    local s = sec % 60
    return string.format("%02d:%02d:%02d", h, mi, s)
end

local function Esc(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("[\r\n]", " ")
    return s
end

local function WorldNow()
    local w = GetWorld()
    if w and w.name then return w.name:upper() end
    return nil
end

local function InWorld()
    local ok, tile = pcall(GetTile, 0, 0)
    return ok and tile ~= nil
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
    if not GetWorld() then return false end
    local t = GetTile(x, y)
    if not t then return false end
    local id = t.fg or 0
    if id ~= 0 then
        if ALLOWED_BLOCKS[id] then return true end
        if BLOCKED_BLOCKS[id] then return false end
    end
    if id == 0 then return true end
    if t.flags and t.flags.locked then return false end
    if CheckPath then
        local ok, res = pcall(CheckPath, x, y)
        if ok then return res == true end
    end
    return false
end

-- Integer hash key: jauh lebih cepat dari string concat, zero GC pressure
local function K(x, y) return y * 210 + x end

local _NB = {{0,-1},{0,1},{-1,0},{1,0}} -- reuse tabel neighbor, no alloc

local function FindSafePath(sx, sy, tx, ty, maxIter)
    maxIter = maxIter or 3000
    local open, closed, from = {}, {}, {}
    local gScore = {}
    local function h(x, y) return math.abs(x-tx)+math.abs(y-ty) end
    local sk = K(sx, sy)
    open[sk] = { x=sx, y=sy, g=0, f=h(sx,sy) }
    gScore[sk] = 0
    local iter = 0
    while next(open) and iter < maxIter do
        iter = iter + 1
        local bk, best = nil, nil
        for k,v in pairs(open) do
            if not best or v.f < best.f then best=v; bk=k end
        end
        if not best then break end
        if best.x == tx and best.y == ty then
            -- reconstruct path tanpa table.insert(path, 1, ...) O(n^2)
            local path, cur, len = {}, best, 0
            while cur do
                len = len + 1
                path[len] = cur
                cur = from[K(cur.x, cur.y)]
            end
            -- reverse in-place
            local rev = {}
            for i = len, 1, -1 do rev[len - i + 1] = path[i] end
            return rev
        end
        open[bk] = nil
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
                    open[nk] = { x=nx, y=ny, g=g, f=g+h(nx,ny) }
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
        for _, pt in ipairs(path) do
            FindPath(pt.x, pt.y)
            Sleep(stepDelay)
        end
    else
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

local function Wrench(x, y)
    local me = GetLocal()
    if not me then return end
    local pkt = {}
    pkt.type = 3
    pkt.value = 32
    pkt.px = math.floor(me.pos.x / 32 + x)
    pkt.py = math.floor(me.pos.y / 32 + y)
    pkt.x = me.pos.x
    pkt.y = me.pos.y
    SendPacketRaw(false, pkt)
end

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

local function MagKey(x, y) return tostring(x) .. "," .. tostring(y) end

local function MarkMagEmpty(x, y, ttl, source)
    if not x or not y then return end
    ttl = ttl or MAG_TTL_SEC
    local key = MagKey(x, y)
    local exp = os.time() + ttl
    MagIntel[key] = { empty = true, expires = exp, source = source or "local" }
    if source ~= "shared" then
        PendingMagSync[key] = { x = tonumber(x), y = tonumber(y), empty = true, ttl = ttl }
    end
end

local function MarkMagReady(x, y, source)
    if not x or not y then return end
    local key = MagKey(x, y)
    MagIntel[key] = { empty = false, expires = 0, source = source or "local" }
    if source ~= "shared" then
        PendingMagSync[key] = { x = tonumber(x), y = tonumber(y), empty = false }
    end
end

local function IsMagCooldown(x, y)
    local key = MagKey(x, y)
    local info = MagIntel[key]
    if not info or not info.empty then return false, 0 end
    local rem = info.expires - os.time()
    if rem <= 0 then
        -- TTL habis! Auto-unban: boleh dicek ulang (siapa tahu sudah di-refill)
        info.empty = false
        return false, 0
    end
    return true, rem, info.source
end

-- Kompatibilitas tabel MagEmpty lama
local MagEmpty = setmetatable({}, {
    __index = function(_, k)
        local x, y = k:match("^(%d+),(%d+)$")
        if x and y then
            local cd = IsMagCooldown(tonumber(x), tonumber(y))
            return cd
        end
        return false
    end,
    __newindex = function(_, k, v)
        local x, y = k:match("^(%d+),(%d+)$")
        if x and y then
            if v then MarkMagEmpty(tonumber(x), tonumber(y), MAG_TTL_SEC, "local")
            else MarkMagReady(tonumber(x), tonumber(y), "local") end
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

local function Wear(item)
    local id = WearIDs[item]
    if not id then return end
    SendPacketRaw(false, { type = 10, value = id })
    TOP_UP = (item == "Mythical Necklace")
end

-- Auto Find Magplant: cari semua fg=5638 di world
local function GetMag()
    local list = {}
    local w = GetWorld()
    if not w then return list end
    local maxX, maxY = w.width - 1, w.height - 1
    for y = 0, maxY do
        for x = 0, maxX do
            local t = GetTile(x, y)
            if t and t.fg == 5638 then
                table.insert(list, { x = x, y = y })
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
        if t and t.fg == 0 and t.isSecret == 0 then
            return ax, ay
        end
    end
    -- Fallback: coba semua arah walkable
    for dy = -2, 2 do
        for dx = -2, 2 do
            if dx ~= 0 or dy ~= 0 then
                local ax, ay = tx + dx, ty + dy
                local t = GetTile(ax, ay)
                if t and t.fg == 0 and t.isSecret == 0 then
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
    -- Match posisi magplant manual ke list kalau ada
    if S.MagplantX ~= 0 and S.MagplantY ~= 0 then
        for i, mp in ipairs(Mag) do
            if mp.x == S.MagplantX and mp.y == S.MagplantY then
                MagIndex = i
                break
            end
        end
    end
    Log("`2Auto-find magplant: " .. #Mag .. " ditemukan (paling dekat dulu)")
end

local function GetNextMag()
    if #Mag == 0 then RecalcMag() end
    local now = os.time()

    local function magTier(mp)
        local key = mp.x .. "," .. mp.y
        local info = MagIntel[key]
        if not info then return 1 end                      -- Tier 1: Unknown / belum pernah dicek
        if not info.empty then return 1 end                 -- Tier 1: Ready
        local rem = info.expires - now
        if rem <= 0 then return 2 end                      -- Tier 2: Cooldown TTL expired, boleh re-check
        if info.source == "shared" then return 3 end        -- Tier 3: Shared report (advisory, boleh pakai kalau tidak ada opsi lain)
        return 4                                             -- Tier 4: Kosong lokal aktif, skip dulu
    end

    local function magDist(mp)
        return math.abs(mp.x - S.PosX) + math.abs(mp.y - S.PosY)
    end

    -- Seleksi tier terbaik + jarak terdekat
    local best = nil
    local bestTier = 99
    local bestDist = 9999

    for _, mp in ipairs(Mag) do
        local tier = magTier(mp)
        local dist = magDist(mp)
        if tier < bestTier or (tier == bestTier and dist < bestDist) then
            bestTier = tier
            bestDist = dist
            best = mp
        end
    end

    return best
end

local function FetchRemote()
    if inv(5640) > 0 and not changeRemote then return end
    Cheat(false)
    Sleep(D("RemoteStep"))

    if #Mag == 0 then RecalcMag() end
    if #Mag == 0 then
        Log("`4[SmartMag]`w Tidak ada magplant terdeteksi di world ini!")
        Run.start = false
        Run.status = "Tidak Ada Mag"
        return
    end

    local maxAttempts = math.min(#Mag, 20)
    local attempt = 0

    while attempt < maxAttempts do
        attempt = attempt + 1
        local target = GetNextMag()
        if not target then
            Log("`4[SmartMag]`w SEMUA MAGPLANT DI WORLD INI KOSONG!")
            Run.start = false
            Run.status = "Semua Mag Kosong"
            Cheat(false)
            return
        end

        S.MagplantX = target.x
        S.MagplantY = target.y
        local key = target.x .. "," .. target.y

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
                Log(string.format("`2[SmartMag]`w Remote sukses diambil dari (%d, %d)!", target.x, target.y))
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
        Log("`4[SmartMag]`w Semua opsi magplant telah dicoba dan habis!")
        Run.start = false
        Run.status = "Semua Mag Kosong"
        Cheat(false)
    end
end

local function BuyCheat()
    if not S.PNB.AutoBuyCheats then return end
    local now = os.time()
    local delaySec = (tonumber(S.DelayBuyCheat) or 30) * 60
    if LastBuyCheat > 0 and now - LastBuyCheat < delaySec then return end
    LastBuyCheat = now
    Log("`9[Cheat]`w Memperpanjang / Membeli Cheats menu...")
    SendPacket(2, "action|dialog_return\ndialog_name|buycheat\ndialog_name|cheats\nbuttonClicked|1\n")
    -- Auto-recover: paksa Step() panggil Cheat(true) lagi dan re-check remote
    m = false
    changeRemote = false
end

local LastSuckBgem = 0
local function SuckBgems()
    if not S.PNB.AutoSuckBgems then return end
    local now = os.time()
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

local function Consume()
    if os.time() - ConsumeTime < 60 * 30 then return end
    ConsumeTime = os.time()
    Log("`wConsuming `9Arroz `wand `2Clover")
    Cheat(false)
    Sleep(D("Consume"))
    for _, id in ipairs({ 4604, 528, 1056 }) do
        if inv(id) > 0 then
            Raw(3, 0, id, S.PosX, S.PosY)
            Sleep(D("Consume"))
        end
    end
    Cheat(true)
    Sleep(D("Consume"))
end

local function TelPos()
    if S.TelX ~= 0 or S.TelY ~= 0 then return S.TelX, S.TelY end
    return S.PosX, S.PosY
end

local function TelDialog(button)
    local tx, ty = TelPos()
    SendPacket(2, "action|dialog_return\ndialog_name|telephone\nnum|53785|\nx|" .. tx ..
        "|\ny|" .. ty .. "|\nbuttonClicked|" .. button)
end

local function MakeBGL()
    SendPacket(2, "action|dialog_return\ndialog_name|info_box\nbuttonClicked|make_bgl")
end

local function AutoConvert()
    local now = os.time()
    if now - LastConvert < 10 then return end
    LastConvert = now

    local gems = Gems()
    local maxG = tonumber(S.PNB.MaxGems) or 400000
    local wl, dl, bgl = inv(242), inv(1796), inv(7188)

    if S.PNB.AutoBuyWL then
        if wl < 100 and dl < 100 and bgl < 100 and gems >= maxG then
            Log("`2Beli World Lock Pack")
            SendPacket(2, "action|buy\nitem|buy_worldlockpack")
        elseif wl >= 100 and dl < 100 and bgl < 100 then
            SendPacketRaw(false, { type = 10, value = 242 })
        elseif dl >= 100 and bgl < 100 then
            TelDialog("bglconvert")
        elseif bgl >= 100 then
            MakeBGL()
        end
    end

    if S.PNB.ConvertDLBGL then
        if gems >= maxG and dl < 100 and bgl < 100 then
            Log("`2Convert gems -> DL")
            TelDialog("dlconvert")
        elseif dl >= 100 and bgl < 100 then
            TelDialog("bglconvert")
        elseif bgl >= 100 then
            MakeBGL()
        end
    end

    if S.PNB.ConvertBGL then
        if gems > maxG and bgl < 100 then
            Log("`2Convert gems -> BGL")
            TelDialog("bglconvert2")
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
        math.randomseed(os.time() * 1000 + math.floor(os.clock() * 1e6))
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
        self.interval = 10  -- selaras dengan interval thread
        self.instanceId = uuid4()
        self.seq = 0
        self.lastTick = 0
        self.lastCmdId = nil
        self.startTime = os.time()
        return self
    end
    function M:tick()
        -- Opt-in check: hanya kirim jika user mengaktifkan EnableMonitor
        if not S.PNB.EnableMonitor then return end
        if os.time() - self.lastTick < self.interval then return end
        self.lastTick = os.time()
        self.seq = self.seq + 1

        -- Lazy identity resolution (jika saat script di-load bot belum login)
        local me = GetLocal and GetLocal()
        if not self.userId or self.userId:find("^Bot_") then
            if me and me.userid and me.userid > 0 then
                self.userId = tostring(me.userid)
                self.name = StripColor(me.name)
            else
                self.userId = self.userId or tostring(math.random(100000, 999999))
                self.name = self.name or ("Bot_" .. self.userId)
            end
        end

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
            table.insert(magUpdates, string.format('{"x":%d,"y":%d,"empty":%s,"ttl":%d}', v.x, v.y, v.empty and "true" or "false", v.ttl or 300))
        end
        PendingMagSync = {} -- Bersihkan queue
        local magsJson = "[" .. table.concat(magUpdates, ",") .. "]"

        local body = string.format(
            '{"userId":"%s","name":"%s","world":"%s","posX":%d,"posY":%d,"gems":%d,"wl":%d,"dl":%d,"bgl":%d,"level":%d,"pingMs":%d,"uptimeSec":%d,"instanceId":"%s","seq":%d,"magReports":%s}',
            self.userId,
            self.name:gsub('"', '\\"'):gsub("[%c]", ""),
            world:gsub('"', '\\"'):gsub("[%c]", ""),
            px, py,
            gems, wl, dl, bgl, level, ping,
            os.time() - self.startTime,
            self.instanceId, self.seq,
            magsJson
        )
        local ok, res = pcall(MakeRequest, self.endpoint, "POST", { ["Content-Type"] = "application/json" }, body)
        if ok and res and type(res) == "table" and res.content then
            pcall(function()
                local content = res.content

                -- Inbound Sharding Knowledge: serap advisory status mag dari bot lain
                if content:find('"sharedMags"') then
                    for block in content:gmatch('(%{[^%}]-x[^%}]-y[^%}]-%})') do
                        local mx = block:match('"x"%s*:%s*(%d+)')
                        local my = block:match('"y"%s*:%s*(%d+)')
                        local mEmpty = block:match('"empty"%s*:%s*(%a+)')
                        local mRem = block:match('"remTtl"%s*:%s*(%d+)') or block:match('"ttl"%s*:%s*(%d+)')
                        if mx and my and mEmpty then
                            local key = mx .. "," .. my
                            local isEmp = (mEmpty == "true")
                            local remTtl = tonumber(mRem) or 300
                            -- ADVISORY: hanya timpa jika belum ada data atau data sebelumnya juga shared
                            if not MagIntel[key] or MagIntel[key].source == "shared" then
                                if isEmp then
                                    MarkMagEmpty(tonumber(mx), tonumber(my), remTtl, "shared")
                                else
                                    MarkMagReady(tonumber(mx), tonumber(my), "shared")
                                end
                            end
                        end
                    end
                end

                -- Dedupe check via cmdId
                local cmdId = content:match('"id"%s*:%s*"(.-)"') or content:match('"cmdId"%s*:%s*"(.-)"')
                if cmdId and cmdId == self.lastCmdId then
                    return -- Sudah pernah diproses, abaikan
                end

                local cmdAction = content:match('"action"%s*:%s*"([^"]+)"')
                local cmdParam  = content:match('"param"%s*:%s*"([^"]+)"')
                if cmdAction then
                    if cmdId then self.lastCmdId = cmdId end
                    Log("`3[RemoteCmd] Action: " .. cmdAction .. " Param: " .. tostring(cmdParam))
                    if cmdAction == "warp" and cmdParam and cmdParam ~= "" then
                        Join(cmdParam:upper())
                    elseif cmdAction == "stop" then
                        StopPNB()
                    elseif cmdAction == "start" then
                        StartPNB()
                    elseif cmdAction == "path" and cmdParam then
                        local tx, ty = cmdParam:match("(%d+),(%d+)")
                        if tx and ty then
                            SlowFindPath(tonumber(tx), tonumber(ty))
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

local function ValidWebhook(url)
    url = tostring(url or "")
    return url:find("^https://discord%.com/api/webhooks/") ~= nil
        or url:find("^https://discordapp%.com/api/webhooks/") ~= nil
end

local function SendHook(force)
    if not force and not S.PNB.SendToWebhook then return end
    if not ValidWebhook(S.PNB.WebhookURL) then return end
    local me = GetLocal()
    local pname = me and StripColor(me.name):gsub("#", "") or "?"
    local data = string.format([[
{
  "embeds": [{
    "title": "ZAKICIT PNB Information",
    "color": 5793266,
    "fields": [
      { "name": "Player", "value": "%s", "inline": false },
      { "name": "Gems", "value": "%s", "inline": true },
      { "name": "World", "value": "%s", "inline": true },
      { "name": "Farm Pos", "value": "X: %d, Y: %d", "inline": true },
      { "name": "Uptime", "value": "%s", "inline": true },
      { "name": "DL", "value": "%d", "inline": true },
      { "name": "BGL", "value": "%d", "inline": true }
    ]
  }]
}]],
        Esc(pname), FNum(Gems()), Esc(worldName), S.PosX, S.PosY,
        FTime(NowTime() - Run.startTime),
        inv(1796), inv(7188))
    MakeRequest(S.PNB.WebhookURL, "POST", { ["Content-Type"] = "application/json" }, data)
    Run.lastHook = NowTime()
end

-- ------------------------------------------------------------
--  SAVE / LOAD
-- ------------------------------------------------------------
local function SavePaths()
    local p = {}
    p[#p + 1] = "/storage/emulated/0/Android/media/com.rtsoft.growtopia/scripts/ZAKICIT_SETTINGS.txt"
    local ok, ad = pcall(function() return os.getenv("APPDATA") end)
    if ok and ad and ad ~= "" then
        p[#p + 1] = ad .. "\\Growtopia\\scripts\\ZAKICIT_SETTINGS.txt"
    end
    p[#p + 1] = "ZAKICIT_SETTINGS.txt"
    return p
end

local function SyncDerived()
    FirstMagX = S.MagplantX
    if S.World and S.World ~= "" then worldName = S.World:upper() end
    UpdateBypassRules()
end

function SaveSettings()
    S.World = worldName
    for _, path in ipairs(SavePaths()) do
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
            f:write("Setting.DelayBuyCheat=" .. tostring(S.DelayBuyCheat) .. "\n")
            for k, v in pairs(S.Delay) do
                f:write("Delay." .. k .. "=" .. tostring(v) .. "\n")
            end
            f:close()
            savePathUsed = path
            Log("`2Config tersimpan: " .. path)
            return true
        end
    end
    Log("`4Gagal menyimpan config")
    return false
end

function LoadSettings()
    for _, path in ipairs(SavePaths()) do
        local f = io.open(path, "r")
        if f then
            for line in f:lines() do
                local section, key, value = line:match("^([^%.=]+)%.([^=]+)=(.*)$")
                if section and key then
                    if value == "true" then value = true
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
            Log("`2Config dimuat: " .. path)
            return true
        end
    end
    Log("`3Config belum ada, pakai default")
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

    local wn = WorldNow()
    if not wn or wn ~= worldName then
        Run.status = "Joining " .. worldName
        Join(worldName)
        Sleep(D("Join"))
        m = false
        return
    end

    if changeRemote or inv(5640) == 0 then
        Run.status = "Smart Mag fetching"
        Cheat(false)
        FetchRemote()
        if not Run.start then return end
        changeRemote = false
        Sleep(D("Switch"))
    end

    if inv(5640) >= 1 then
        if not m then
            Run.status = "Moving to farm pos"
            Cheat(false)
            Sleep(D("PreMove"))
            SlowFindPath(S.PosX, S.PosY, D("PathStep"))
            Sleep(D("PostMove"))

            -- Hadap karakter sesuai setting (BFG kanan vs kiri)
            local targetPlaceX = S.PNB.FaceRight and (S.PosX + 1) or (S.PosX - 1)
            if S.PNB.FaceRight then
                FindTPRight(S.PosX, S.PosY)
                Log("`9[BFG]`w Hadap KANAN di farm pos")
            else
                FindTPLeft(S.PosX, S.PosY)
                Log("`9[BFG]`w Hadap KIRI di farm pos")
            end
            Sleep(250)

            -- Auto-place remote & showhand sebelum cheat aktif (mengunci posisi target)
            PlaceShowHand(targetPlaceX, S.PosY)
            Sleep(200)

            Cheat(true)
            if S.PNB.Modfly then
                pcall(ChangeValue, "[C] Modfly", true)
            end
            Sleep(D("CheatOn"))

            -- Auto-place remote & showhand setelah cheat aktif (langsung memicu loop autofarm jalan otomatis)
            PlaceShowHand(targetPlaceX, S.PosY)
            Sleep(150)
            PlaceShowHand(targetPlaceX, S.PosY)
            m = true
        end
    else
        m = false
    end

    if m then Run.status = "Farming" end

    BuyCheat()
    if S.PNB.AutoSuckBgems then SuckBgems() end
    if S.PNB.AutoConsumables then Consume() end
    if S.PNB.AutoBuyWL or S.PNB.ConvertDLBGL or S.PNB.ConvertBGL then AutoConvert() end

    if S.PNB.SendToWebhook
        and NowTime() - Run.lastHook >= math.max(10, tonumber(S.PNB.WebhookDelay) or 300) then
        SendHook(false)
    end
end

function StartPNB()
    if Run.start then return end
    changeRemote = false
    m = false
    RecalcMag()  -- Auto find & sort mag terdekat saat start
    Run.startTime = NowTime()
    Run.lastHook = NowTime()
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
    Log("`4PNB dihentikan")
end

RunThread(function()
    while true do
        Sleep(D("Loop"))
        if Run.testHook then
            Run.testHook = false
            local ok, err = pcall(SendHook, true)
            if ok then Log("`2Test webhook terkirim") else Log("`4Webhook error: " .. tostring(err)) end
        end
        if Run.start then
            local ok, err = pcall(Step)
            if not ok then
                Log("`4Error: " .. tostring(err))
                Sleep(3000)
            end
        end
    end
end)

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
    if pkt.value == 18 and GetPos then
        if CaptureMag then
            S.MagplantX = pkt.px
            S.MagplantY = pkt.py
            FirstMagX = pkt.px
            Log("Magplant Pos : " .. pkt.px .. ", " .. pkt.py)
            CaptureMag = false
            GetPos = false
        elseif CaptureBreak then
            S.PosX = pkt.px
            S.PosY = pkt.py
            Log("Farming Pos : " .. pkt.px .. ", " .. pkt.py)
            CaptureBreak = false
            GetPos = false
        end
        return true
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
        if S.PNB.AutoRadio then SendPacket(2, "action|input\n|text|/radio") end
        return true
    end

    if k == "OnDialogRequest" and type(a) == "string" then
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
            end
            return true
        end
        for _, p in ipairs(BlockDialogs) do
            if a:find(p, 1, true) then return true end
        end
    elseif k == "OnConsoleMessage" and type(a) == "string" then
        if a:find("Radio enabled,", 1, true) then blockSB = true end
        for _, p in ipairs(BlockConsole) do
            if a:find(p, 1, true) then return true end
        end
    elseif k == "OnTalkBubble" and type(b) == "string" then
        if b:find("The MAGPLANT 5000 is empty.", 1, true) or b:find("MAGPLANT 5000 is empty", 1, true) then
            if S.MagplantX ~= 0 and S.MagplantY ~= 0 then
                MagEmpty[S.MagplantX .. "," .. S.MagplantY] = true
            end
            changeRemote = true
            return true
        end
        if S.PNB.HideCollected and b:find("Collected", 1, true) then return true end
    end
    return false
end)

-- ------------------------------------------------------------
--  GUI HELPERS & THEME  (CYBERPUNK DARK)
-- ------------------------------------------------------------
local C = {
    neon_cyan  = { 0.00, 0.95, 1.00, 1 },
    neon_pink  = { 1.00, 0.15, 0.85, 1 },
    neon_green = { 0.00, 1.00, 0.50, 1 },
    neon_yel   = { 1.00, 0.90, 0.00, 1 },
    neon_red   = { 1.00, 0.20, 0.20, 1 },
    neon_purp  = { 0.60, 0.20, 1.00, 1 },
    bg_card    = { 0.10, 0.10, 0.22, 0.98 },
    bg_dark    = { 0.06, 0.06, 0.14, 1.00 },
    border     = { 0.20, 0.18, 0.40, 1 },
    text_bright= { 0.92, 0.92, 1.00, 1 },
    text_dim   = { 0.50, 0.50, 0.65, 1 },
}

local function AvailW()
    if ImGui.GetContentRegionAvailX then
        return ImGui.GetContentRegionAvailX()
    end
    local ok, v = pcall(ImGui.GetContentRegionAvail)
    if ok and v then return v.x or 460 end
    return 460
end

local function V4(c, a)
    if ImVec4 then return ImVec4(c[1], c[2], c[3], a or c[4] or 1) end
    return nil
end

local function CText(c, txt)
    if ImGui.TextColored and ImVec4 then
        local v = ImVec4(c[1], c[2], c[3], c[4] or 1)
        local ok = pcall(ImGui.TextColored, v, txt)
        if ok then return end
    end
    if ImGui.Text then pcall(ImGui.Text, txt)
    else print("[zakicit] " .. txt) end
end

local function PushCols(list)
    if not (ImGui.PushStyleColor and ImGui.PopStyleColor and ImVec4) then return 0 end
    local enum = ImGuiCol or ImGuiCol_
    if not enum then return 0 end
    local n = 0
    for _, e in ipairs(list) do
        local id = enum[e[1]]
        if id ~= nil then
            local ok = pcall(ImGui.PushStyleColor, id, V4(e[2]))
            if ok then n = n + 1 end
        end
    end
    return n
end

local function PopCols(n)
    if n > 0 then pcall(ImGui.PopStyleColor, n) end
end

local function Sep(col)
    if col then PushCols{{"Separator", col}} end
    ImGui.Separator()
    if col then PopCols(1) end
end

local function Sp(h) ImGui.SetCursorPosY(ImGui.GetCursorPosY() + (h or 6)) end

-- NEON BUTTON: tombol besar warna neon
local function NButton(label, col, w, h)
    col = col or C.neon_green
    local n = PushCols({
        { "Button",        { col[1]*0.5, col[2]*0.5, col[3]*0.5, 1 } },
        { "ButtonHovered", { col[1]*0.7, col[2]*0.7, col[3]*0.7, 1 } },
        { "ButtonActive",  col },
    })
    local res = ImGui.Button(label, ImVec2(w or -1, h or 42))
    PopCols(n)
    return res
end

local function Bar(frac, label, col)
    frac = math.max(0, math.min(1, frac))
    if ImGui.ProgressBar then
        pcall(ImGui.ProgressBar, frac, ImVec2(-1, 16),
            (col and ("`8") or "`7") .. (label or ""))
    else
        ImGui.Text(label or "")
    end
end

local function CB(label, val)
    local r1, r2 = ImGui.Checkbox(label, val and true or false)
    if r2 ~= nil then return r1, r2 end
    if r1 then return true, not val end
    return false, val
end

local function Section(title)
    Sp(4)
    CText(C.neon_cyan, "  " .. title)
    Sep(C.border)
end

local function Row(label, value, col)
    CText(C.text_dim, "  " .. label)
    ImGui.SameLine(140)
    CText(col or C.text_bright, tostring(value))
end

-- ------------------------------------------------------------
--  GUI TABS
-- ------------------------------------------------------------

-- ─── TAB 1: FARM (MAIN, ZERO-SCROLL) ────────────────────────
local function TabFarm()
    local running = Run.start

    -- START / STOP
    Sp(2)
    if running then
        if NButton("STOP PNB", C.neon_red, -1, 44) then StopPNB() end
    else
        if NButton("START PNB", C.neon_green, -1, 44) then StartPNB() end
    end
    -- Status mini
    CText(running and C.neon_green or C.neon_red,
        running and ("  " .. Run.status) or "  Idle")
    Sp(4)
    Sep(C.border)

    -- STATS ringkas (1 baris per stat, tanpa scroll)
    local gems = Gems()
    Row("Gems",       FNum(gems),                     C.neon_cyan)
    Row("Gems/Jam",   FNum(GetEfficiency()),           running and C.neon_pink or C.text_dim)
    Row("DL / BGL",  inv(1796) .. " / " .. inv(7188), C.neon_yel)
    Row("Remote",    inv(5640) .. "x | Mag Aktif (" .. S.MagplantX .. "," .. S.MagplantY .. ")", C.neon_purp)
    Row("Uptime",    running and FTime(NowTime() - Run.startTime) or "--:--:--", C.neon_green)
    Sp(4)
    Sep(C.border)

    -- WORLD
    local ch, nv = ImGui.InputText("World##w", worldName, 64)
    if ch then worldName = tostring(nv):upper() end
    if NButton("Pakai World Sekarang", C.neon_cyan, -1, 32) then
        local w = WorldNow()
        if w then worldName = w; RecalcMag(); Log("World: "..w)
        else Log("`4Belum di dalam world") end
    end
    Sp(4)
    Sep(C.border)

    -- POSISI: 1-Klik ambil posisi berdiri sekarang & Farming Tile
    local posSet = S.PosX ~= 0 or S.PosY ~= 0
    if NButton(posSet and string.format("[OK] Farm Pos: (%d, %d)", S.PosX, S.PosY) or "[!] Set di Posisi Saya", posSet and C.neon_cyan or C.neon_red, -1, 36) then
        local me = GetLocal()
        if me and me.pos then
            S.PosX = math.floor(me.pos.x / 32)
            S.PosY = math.floor(me.pos.y / 32)
            Log(string.format("`2Farm Pos di-set ke posisi berdiri: (%d, %d)", S.PosX, S.PosY))
            RecalcMag()
        else
            Log("`4Gagal mendeteksi posisi bot!")
        end
    end
    CText(C.text_dim, string.format("  Mag Terdeteksi: %d (Auto-Find Aktif)", #Mag))
    Sp(4)
    Sep(C.border)

    -- HADAP (2 tombol toggle highlight)
    CText(C.text_dim, "  Arah hadap saat farming BFG:")
    local left_n = PushCols({
        { "Button",        not S.PNB.FaceRight and C.neon_purp or {0.08,0.08,0.22,1} },
        { "ButtonHovered", {0.50,0.20,1.00,1} },
        { "ButtonActive",  C.neon_purp },
    })
    if ImGui.Button("KIRI", ImVec2(AvailW()/2 - 4, 34)) then
        S.PNB.FaceRight = false
    end
    PopCols(left_n)
    ImGui.SameLine()
    local right_n = PushCols({
        { "Button",        S.PNB.FaceRight and C.neon_cyan or {0.08,0.08,0.22,1} },
        { "ButtonHovered", {0.00,0.80,1.00,1} },
        { "ButtonActive",  C.neon_cyan },
    })
    if ImGui.Button("KANAN", ImVec2(-1, 34)) then
        S.PNB.FaceRight = true
    end
    PopCols(right_n)
end

-- ─── TAB 2: MAGPLANT (Smart Auto-Find) ────────────────────────
local function TabMag()
    -- STAT BOX: ringkasan status magplant
    local totalMag = #Mag
    local emptyMag = 0
    for i, mp in ipairs(Mag) do
        if MagEmpty[mp.x .. "," .. mp.y] then emptyMag = emptyMag + 1 end
    end
    local readyMag = totalMag - emptyMag
    CText(C.neon_cyan, "  Smart Magplant Monitor")
    Sp(3)
    Row("Total Terdeteksi",    totalMag,   C.text_bright)
    Row("Siap Pakai",         readyMag,   readyMag > 0 and C.neon_green or C.neon_red)
    Row("Kosong / Empty",     emptyMag,   emptyMag > 0 and C.neon_red or C.neon_green)
    if S.MagplantX ~= 0 then
        local k = S.MagplantX .. "," .. S.MagplantY
        Row("Mag Aktif",       "(" .. S.MagplantX .. "," .. S.MagplantY .. ")", MagEmpty[k] and C.neon_red or C.neon_green)
    end
    Sp(4)
    Sep(C.border)

    -- TOMBOL AKSI
    if NButton("Rescan & Urut Ulang Mag", C.neon_cyan, -1, 36) then
        MagIntel = {}
        PendingMagSync = {}
        RecalcMag()
        Log("`2SmartMag: Scan ulang magplant di world...")
    end
    if emptyMag > 0 and NButton("Reset Semua Status Empty", C.neon_yel, -1, 34) then
        MagIntel = {}
        PendingMagSync = {}
        RecalcMag()
        Log("`2SmartMag: Semua status kosong di-reset!")
    end
    Sp(4)
    Sep(C.border)

    -- DAFTAR MAGPLANT TERDEKAT
    CText(C.text_dim, "  5 Magplant Terdekat ke Farm Pos:")
    Sp(2)
    local now = os.time()
    for i = 1, math.min(5, #Mag) do
        local mp = Mag[i]
        local key = mp.x .. "," .. mp.y
        local dist = math.abs(mp.x - S.PosX) + math.abs(mp.y - S.PosY)
        local isCd, remSec, src = IsMagCooldown(mp.x, mp.y)
        local isActive = (mp.x == S.MagplantX and mp.y == S.MagplantY)
        local prefix = isActive and "[*] " or "[" .. i .. "] "
        local suffix = ""
        local color = C.neon_green

        if isCd then
            color = (src == "shared") and C.neon_yel or C.neon_red
            local m = math.floor(remSec / 60)
            local s = remSec % 60
            local tag = (src == "shared") and " [Shared]" or ""
            suffix = string.format(" - EMPTY%s (%dm %ds)", tag, m, s)
        else
            suffix = " - READY"
        end

        CText(color, "  " .. prefix .. "(" .. mp.x .. "," .. mp.y .. ") dist " .. dist .. suffix)
    end
    if #Mag == 0 then
        CText(C.neon_red, "  [X] Tidak ada magplant terdeteksi di world ini!")
    end
end

-- ─── TAB 3: SETTING ─────────────────────────────────────────
local function TabSetting()
    Section("Item & Wear")
    for _, item in ipairs(WearList) do
        if ImGui.Selectable(item, S.PNB.WearItem == item) then
            S.PNB.WearItem = item; Wear(item)
        end
    end
    Sp(4)

    Section("Fitur")
    local opts = {
        { "Modfly",            "Modfly" },
        { "TakeMagFromBehind", "Scan Mag dari Belakang" },
        { "AutoCollectGems",   "Auto Collect Gems" },
        { "AutoChangeRemote",  "Auto Ganti Remote" },
        { "AutoConsumables",   "Auto Consume" },
        { "AutoSuckBgems",     "Auto Suck Black Gems" },
        { "BypassPaywall",     "Bypass Paywall (16308)" },
        { "BypassWayBlock",    "Bypass One-Way (3796)" },
        { "HideCollected",     "Hide Popup Collected" },
        { "AntiLag",           "AntiLag / FC Guard" },
        { "IgnoreOther",       "Ignore Player Lain" },
        { "EnableMonitor",     "Remote Command (Opt-in)" },
    }
    for _, o in ipairs(opts) do
        local c, v = CB(o[2], S.PNB[o[1]])
        if c then
            S.PNB[o[1]] = v
            if o[1] == "AntiLag" then ActiveLag(v) end
            UpdateBypassRules()
        end
    end
    Sp(4)

    Section("Auto Buy / Convert")
    local conv = {
        { "AutoBuyWL",    "Auto Buy WL" },
        { "ConvertDLBGL", "Convert Gems -> DL -> BGL" },
        { "ConvertBGL",   "Convert Gems -> BGL langsung" },
    }
    for _, o in ipairs(conv) do
        local c, v = CB(o[2], S.PNB[o[1]])
        if c then S.PNB[o[1]] = v end
    end
    local cg, mg = ImGui.InputInt("Max Gems (convert)", S.PNB.MaxGems)
    if cg then S.PNB.MaxGems = math.max(0, mg) end
    local ctx, tx = ImGui.InputInt("Tel X", S.TelX); if ctx then S.TelX = tx end
    local cty, ty = ImGui.InputInt("Tel Y", S.TelY); if cty then S.TelY = ty end
    Sp(4)

    Section("Delay")
    local cbc, bcv = ImGui.InputInt("Delay Buy Cheat (menit)", S.DelayBuyCheat)
    if cbc then S.DelayBuyCheat = math.max(1, bcv) end
    local cp, vp = ImGui.InputInt("Delay per Tile Jalan (ms)", S.Delay.PathStep)
    if cp then S.Delay.PathStep = math.max(50, math.min(5000, vp)) end
    local presets = {{"Fast",60},{"Normal",100},{"Safe",200},{"Pelan",300}}
    for i, pr in ipairs(presets) do
        if ImGui.Button(pr[1], ImVec2(AvailW()/4 - 4, 30)) then
            S.Delay.Scale = pr[2]
        end
        if i < #presets then ImGui.SameLine() end
    end
end

-- ─── TAB 4: WEBHOOK ─────────────────────────────────────────
local function TabWebhook()
    Section("Discord Webhook")
    local cw, vw = CB("Aktifkan Webhook", S.PNB.SendToWebhook)
    if cw then S.PNB.SendToWebhook = vw end
    local ch, nv = ImGui.InputText("URL##wurl", S.PNB.WebhookURL, 256)
    if ch then S.PNB.WebhookURL = nv end
    if S.PNB.WebhookURL ~= "" then
        if ValidWebhook(S.PNB.WebhookURL) then
            CText(C.neon_green, "  URL valid")
        else
            CText(C.neon_red, "  Harus diawali https://discord.com/api/webhooks/")
        end
    end
    local c2, nd = ImGui.InputInt("Interval (detik)", S.PNB.WebhookDelay)
    if c2 then S.PNB.WebhookDelay = math.max(10, nd) end
    if Run.start and S.PNB.SendToWebhook then
        local d  = math.max(10, tonumber(S.PNB.WebhookDelay) or 300)
        local el = NowTime() - Run.lastHook
        Bar(math.min(1, el / d), "Berikutnya " .. FTime(math.max(0, d - el)))
    end
    Sp(4)
    if NButton("Test Webhook Sekarang", C.neon_cyan, -1, 40) then
        Log("Mengirim test..."); Run.testHook = true
    end
end

-- ─── TAB 5: CONFIG ──────────────────────────────────────────
local function TabConfig()
    if NButton("SAVE SETTINGS", C.neon_green, -1, 44) then SaveSettings() end
    Sp(4)
    if NButton("LOAD SETTINGS", {0.00,0.55,1.00,1}, -1, 36) then LoadSettings() end
    if savePathUsed ~= "" then CText(C.text_dim, "  " .. savePathUsed) end
    Sp(6)
    Section("Log")
    if ImGui.Button("Clear Log", ImVec2(-1, 28)) then LogBuf = {} end
    Sp(2)
    local from = math.max(1, #LogBuf - 18)
    for i = from, #LogBuf do CText(C.text_dim, LogBuf[i]) end
end

local function TabAbout()
    Section("ZAKICIT PNB v2")
    ImGui.Text("Web Monitor: https://gt-pi-ten.vercel.app")
end

local sizeSet = false
AddHook("OnDraw", "ZAKICIT_DRAW", function()
    if not ImGui then return end
    if not sizeSet and ImGui.SetNextWindowSize then
        pcall(ImGui.SetNextWindowSize, ImVec2(500, 640), 4)
        sizeSet = true
    end

    local n = PushCols({
        { "WindowBg",      { 0.05, 0.05, 0.13, 0.98 } },
        { "TitleBg",       { 0.08, 0.05, 0.22, 1 } },
        { "TitleBgActive", { 0.10, 0.00, 0.40, 1 } },
        { "FrameBg",       { 0.10, 0.10, 0.20, 1 } },
        { "FrameBgHovered",{ 0.15, 0.14, 0.30, 1 } },
        { "FrameBgActive", { 0.20, 0.18, 0.40, 1 } },
        { "CheckMark",     C.neon_cyan },
        { "Button",        { 0.10, 0.08, 0.28, 1 } },
        { "ButtonHovered", { 0.20, 0.18, 0.50, 1 } },
        { "ButtonActive",  { 0.30, 0.28, 0.70, 1 } },
        { "Header",        { 0.15, 0.12, 0.38, 0.9 } },
        { "HeaderHovered", { 0.22, 0.20, 0.55, 1 } },
        { "Tab",           { 0.10, 0.08, 0.22, 1 } },
        { "TabHovered",    { 0.20, 0.18, 0.50, 1 } },
        { "TabActive",     { 0.18, 0.00, 0.58, 1 } },
        { "Separator",     { 0.20, 0.18, 0.45, 1 } },
        { "PlotHistogram", C.neon_cyan },
    })
    if ImGui.Begin("ZAKICIT PNB v2") then
        if ImGui.BeginTabBar("ZakiTabs") then
            if ImGui.BeginTabItem("Farm")     then TabFarm();     ImGui.EndTabItem() end
            if ImGui.BeginTabItem("Mag")      then TabMag();      ImGui.EndTabItem() end
            if ImGui.BeginTabItem("Setting")  then TabSetting();  ImGui.EndTabItem() end
            if ImGui.BeginTabItem("Webhook")  then TabWebhook();  ImGui.EndTabItem() end
            if ImGui.BeginTabItem("Config")   then TabConfig();   ImGui.EndTabItem() end
            if ImGui.BeginTabItem("About")    then TabAbout();    ImGui.EndTabItem() end
            ImGui.EndTabBar()
        end
    end
    ImGui.End()
    PopCols(n)
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
Log("`2ZAKICIT PNB v2 siap. Buka menu.")
