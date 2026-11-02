-- ========================================================
-- PNB BOTHAX V2 - JustEx (versi bug-fix lengkap)
-- ========================================================

-- ========================================================
-- CONFIG & GLOBAL DEFAULTS
-- ========================================================
Android = Android or false
Windows = Windows or false
BackgroundID = BackgroundID or 12840
VerticalPNB = VerticalPNB or false
VerticalPlant = VerticalPNB
pnbX = tonumber(pnbX) or 0
pnbY = tonumber(pnbY) or 0
TelX = tonumber(TelX) or 0
TelY = tonumber(TelY) or 0
AutoBuff = AutoBuff or false
AutoRemote = AutoRemote or false
ConsumeArroz = ConsumeArroz or false
ConsumeClover = ConsumeClover or false
ConsumeSongpyeon = ConsumeSongpyeon or false
AutoBuyWL = AutoBuyWL or false
ConvertBGL = ConvertBGL or false
ConvertDLBGL = (ConvertDLBGL == nil) and true or ConvertDLBGL
MaxGems = MaxGems or 400000
DelayTake = DelayTake or 1000
WorldConsume = WorldConsume or "JustEx"
TakeConsumable = TakeConsumable or false
AutoBuyCheats = (AutoBuyCheats == nil) and true or AutoBuyCheats
WebhookUrl = WebhookUrl or ""          -- isi webhook milikmu sendiri
WebhookPNB = (WebhookPNB == nil) and false or WebhookPNB
WebhookPTHT = WebhookPNB
DiscordID = DiscordID or 0
IgnoreOther = IgnoreOther or false
MirrorPNB = MirrorPNB or false
PublicPNB = PublicPNB or false
BypassPaywall = BypassPaywall or false
BypassWayBlock = BypassWayBlock or false
SuckBgems = SuckBgems or false
NoGemsDrop = (NoGemsDrop == nil) and true or NoGemsDrop
AntiLag = AntiLag or false
TakeMagFromBehind = (TakeMagFromBehind == nil) and true or TakeMagFromBehind
AutoDonate = AutoDonate or false
DonateX = tonumber(DonateX) or 0
DonateY = tonumber(DonateY) or 0
DelayBuyCheat = tonumber(DelayBuyCheat) or 30
VendingBackgroundID = VendingBackgroundID or 298
Modfly = (Modfly == nil) and true or Modfly
ConfigPath = ConfigPath or "PNB-SETTING.lua"

GUI_open = (GUI_open == nil) and true or GUI_open
ScriptRunning = false
StopRequested = false
Intevoir = true

-- Runtime tracking
Now = 1
Tile = {}
PASSED_BLOCKS = {}
FAILED_BLOCKS = {}
Mag = {}
GetRemote = false
CheatStopped = true
StartTime = os.time()
local ALLOWED_BLOCKS = { [0] = true, [3898] = true, [15858] = true }
local BLOCKED_BLOCKS = { [3796] = true }

-- Buang webhook bawaan pembuat script kalau masih ada
local function SanitizeWebhook()
    if type(WebhookUrl) == "string" and WebhookUrl:find("1345179059092455576", 1, true) then
        WebhookUrl = ""
    end
    if not WebhookUrl or WebhookUrl == "" then
        WebhookPNB = false
        WebhookPTHT = false
    end
end
SanitizeWebhook()

-- ========================================================
-- HELPER FUNCTIONS
-- ========================================================
function TextOverlay(text)
    SendVariantList({ [0] = "OnTextOverlay", [1] = text })
end

function ToInt(val)
    return math.floor(tonumber(val or 0) or 0)
end

function inv(itemId)
    for _, item in pairs(GetInventory() or {}) do
        if item.id == itemId then
            return item.amount
        end
    end
    return 0
end

function obj(itemId)
    local count = 0
    for _, o in pairs(GetObjectList() or {}) do
        if o.id == itemId then
            count = count + o.amount
        end
    end
    return count
end

function FNum(num)
    local n = tonumber(num) or 0
    if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
    if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
    if n >= 1e3 then return string.format("%.0fK", n / 1e3) end
    return tostring(n)
end

function FTime(seconds)
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds % 86400) / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if d > 0 then return string.format("%s day %s hour %s minute %s second", d, h, m, s) end
    if h > 0 then return string.format("%s hour %s minute %s second", h, m, s) end
    if m > 0 then return string.format("%s minute %s second", m, s) end
    return string.format("%s second", s)
end

function Wrench(x, y)
    SendPacketRaw(false, { type = 3, state = 32, value = 32, px = x, py = y, x = x * 32, y = y * 32 })
end

function SendWebhook(url, payload)
    if not url or url == "" then return end
    MakeRequest(url, "POST", { ["Content-Type"] = "application/json" }, payload)
end

local function Esc(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("[\r\n]", " ")
    return s
end

-- ========================================================
-- GAME & BOT MECHANICS
-- ========================================================
function UpdateBypassRules()
    ALLOWED_BLOCKS = ALLOWED_BLOCKS or {}
    BLOCKED_BLOCKS = BLOCKED_BLOCKS or {}
    if BypassPaywall then
        ALLOWED_BLOCKS[16308] = true
        BLOCKED_BLOCKS[16308] = nil
        LogToConsole("`2Paywall block 16308 -> ALLOWED")
    else
        ALLOWED_BLOCKS[16308] = nil
        BLOCKED_BLOCKS[16308] = true
        LogToConsole("`4Paywall block 16308 -> NOT ALLOWED")
    end

    if BypassWayBlock then
        ALLOWED_BLOCKS[3796] = true
        BLOCKED_BLOCKS[3796] = nil
        LogToConsole("`2One way block 3796 -> ALLOWED")
    else
        ALLOWED_BLOCKS[3796] = nil
        BLOCKED_BLOCKS[3796] = true
        LogToConsole("`4One way block 3796 -> NOT ALLOWED")
    end
end

function GetTileId(tile)
    if not GetWorld() or not tile then return 0 end
    if tile.fg and tile.fg ~= 0 then return tile.fg end
    if tile.bg and tile.bg ~= 0 then return tile.bg end
    return 0
end

function GetWorldSize()
    if not GetWorld() then return 0, 0 end
    if GetTile(209, 0) then return 209, 209 end
    if GetTile(199, 0) then return 199, 199 end
    if GetTile(149, 0) then return 149, 149 end
    if GetTile(99, 0) then return 99, 59 end
    if GetTile(29, 0) then return 29, 29 end
    return 199, 199
end

function GetMag(maxX, maxY)
    local list = {}
    for y = 0, maxY do
        for x = 0, maxX do
            local t = GetTile(x, y)
            if t and t.fg == 5638 and t.bg == BackgroundID then
                table.insert(list, { x = x, y = y })
            end
        end
    end
    return list
end

function RecalcMag()
    local ok, err = pcall(function()
        local wX, wY = GetWorldSize()
        Mag = GetMag(wX, wY)
        Now = 1
        TextOverlay("`2Mag recalculated: " .. #Mag)
        LogToConsole(string.format("RecalcMag -> %d magplants found (bg=%s)", #Mag, tostring(BackgroundID)))
    end)
    if not ok then LogToConsole("RecalcMag error: " .. tostring(err)) end
    return Mag and #Mag or 0
end

function ActiveLag()
    local val = AntiLag
    ChangeValue("[C] No render name", val)
    ChangeValue("[C] No render particle", val)
    ChangeValue("[C] No render shadow", val)
    ChangeValue("[C] No render world", val)
    ChangeValue("[C] No render object", val)
    ChangeValue("[C] No render player", val)
end

function FindTPVertical(x, y)
    SendPacketRaw(false, { state = 32, x = (x * 32) - 1, y = (y * 32) - 1, px = -1, py = -1 })
end

function FindTPLeft(x, y)
    SendPacketRaw(false, { state = 48, x = x * 32, y = y * 32, px = x, py = y })
end

function CheatTurnOff()
    local check = CheckIgnore or 0
    SendPacket(2, string.format(
        "action|dialog_return\ndialog_name|cheats\ncheck_autofarm|0\ncheck_bfg|0\ncheck_gems|1\ncheck_lonely|%s\ncheck_ignoreo|%s\ncheck_ignoref|%s",
        check, check, check))
end

function CheatTurnOn()
    local buff   = (AutoBuff    and 1 or 0)
    local remote = (AutoRemote  and 1 or 0)
    local gems   = (NoGemsDrop  and 1 or 0)
    local ignore = (IgnoreOther and 1 or 0)
    local fly    = (Modfly      and 1 or 0)
    SendPacket(2, string.format(
        "action|dialog_return\ndialog_name|cheats\ncheck_autofarm|1\ncheck_bfg|1\ncheck_modfly|%s\ncheck_autobuff|%s\ncheck_autoremote|%s\ncheck_gems|%s\ncheck_lonely|%s\ncheck_ignoreo|%s\ncheck_ignoref|%s",
        fly, buff, remote, gems, ignore, ignore, ignore))
end

function GoPath(packetType, state, value, x, y)
    if not GetWorld() then return end
    SendPacketRaw(false, { type = packetType, state = state, value = value, px = x, py = y, x = x * 32, y = y * 32 })
    if packetType == nil then
        local localPlayer = GetLocal()
        if localPlayer then
            SendVariantList({ [0] = "OnSetPos", [1] = { x = x * 32, y = y * 32 } }, localPlayer.netid)
        end
    end
end

function IsTileWalkable(x, y)
    if not GetWorld() then return false end
    local maxX, maxY = GetWorldSize()
    if x < 0 or y < 0 or x > maxX or y > maxY then return false end

    local t = GetTile(x, y)
    if not t then return false end

    local tileId = GetTileId(t)
    if tileId ~= 0 then
        if ALLOWED_BLOCKS[tileId] or (PASSED_BLOCKS and PASSED_BLOCKS[tileId]) then return true end
        if BLOCKED_BLOCKS[tileId] then return false end
    end

    -- FIX: tile yang hanya punya background dianggap kosong
    if not t.fg or t.fg == 0 then return true end
    if t.flags and t.flags.locked then return false end

    if CheckPath then
        local ok, res = pcall(CheckPath, x, y)
        if ok and res then return true end
    end
    return false
end

-- ========================================================
-- PATHFINDING (A*)
-- ========================================================
local function Heuristic(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2)
end

local function GetNeighbors(x, y)
    return {
        { x = x,     y = y - 1 },
        { x = x,     y = y + 1 },
        { x = x - 1, y = y     },
        { x = x + 1, y = y     }
    }
end

function FindSafePath(startX, startY, targetX, targetY, maxIterations)
    if not GetWorld() then return nil end
    maxIterations = maxIterations or 2000

    local openSet   = {}
    local closedSet = {}
    local cameFrom  = {}

    local startKey = startX .. "," .. startY
    openSet[startKey] = {
        x = startX, y = startY, g = 0,
        h = Heuristic(startX, startY, targetX, targetY),
        f = Heuristic(startX, startY, targetX, targetY)
    }

    local count = 0
    while next(openSet) and count < maxIterations do
        count = count + 1
        local currentKey, current = nil, nil
        for k, v in pairs(openSet) do
            if not current or v.f < current.f then
                current = v
                currentKey = k
            end
        end

        if not current then break end

        if current.x == targetX and current.y == targetY then
            local path = {}
            local curr = current
            while curr do
                table.insert(path, 1, { x = curr.x, y = curr.y })
                curr = cameFrom[curr.x .. "," .. curr.y]
            end
            return path
        end

        openSet[currentKey] = nil
        closedSet[currentKey] = true

        for _, neighbor in ipairs(GetNeighbors(current.x, current.y)) do
            local nKey = neighbor.x .. "," .. neighbor.y
            if not closedSet[nKey] and IsTileWalkable(neighbor.x, neighbor.y) then
                local tentativeG = current.g + 1
                if not openSet[nKey] or tentativeG < openSet[nKey].g then
                    cameFrom[nKey] = current
                    local h = Heuristic(neighbor.x, neighbor.y, targetX, targetY)
                    openSet[nKey] = {
                        x = neighbor.x, y = neighbor.y,
                        g = tentativeG, h = h, f = tentativeG + h
                    }
                end
            end
        end
    end
    return nil
end

function SafeFindPath(targetX, targetY, delay)
    delay = delay or 100
    if not PublicPNB then
        FindPath(targetX, targetY, 550)
        Sleep(delay)
        return
    end

    if not GetWorld() then return false end
    local me = GetLocal()
    if not me then return false end

    local curX = math.floor(me.pos.x / 32)
    local curY = math.floor(me.pos.y / 32)
    if curX == targetX and curY == targetY then return true end

    local path = FindSafePath(curX, curY, targetX, targetY, 5000)
    if path and #path > 0 then
        for i, pt in ipairs(path) do
            if i > 1 then
                GoPath(3, 1, 0, pt.x, pt.y)
                GoPath(nil, nil, nil, pt.x, pt.y)
                Sleep(delay)
                local lp = GetLocal()
                if not lp then return false end
                local pos = lp.pos
                if math.floor(pos.x / 32) ~= pt.x or math.floor(pos.y / 32) ~= pt.y then
                    if GetTileId(GetTile(pt.x, pt.y)) == 16308 then
                        LogToConsole("`4Server menolak lewat pintu paywall. Cek akses akun/world ini. Script dihentikan.")
                        TextOverlay("`4Paywall menolak akses, stopped")
                        ScriptRunning = false
                    end
                    return false
                end
            end
        end
        return true
    end

    LogToConsole(string.format("`9No Path Found! %d,%d -> %d,%d | target walkable=%s",
        curX, curY, targetX, targetY, tostring(IsTileWalkable(targetX, targetY))))
    for _, d in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
        local tx, ty = targetX + d[1], targetY + d[2]
        LogToConsole(string.format("tile %d,%d id=%s", tx, ty, tostring(GetTileId(GetTile(tx, ty)))))
    end
    return false
end

-- ========================================================
-- AUTOMATION & LOGIC
-- ========================================================
function AutoConsume(itemId)
    SendPacketRaw(false, { type = 3, value = itemId, px = pnbX, py = pnbY, x = pnbX * 32, y = pnbY * 32 })
    Sleep(500)
end

function TakeConsumes()
    if not TakeConsumable then return end
    if not GetWorld() then
        Sleep(2000)
        return
    end

    local consumableIDs = {}
    if ConsumeArroz then table.insert(consumableIDs, 4604) end
    if ConsumeClover then table.insert(consumableIDs, 528) end
    if ConsumeSongpyeon then table.insert(consumableIDs, 1056) end

    if #consumableIDs == 0 then
        LogToConsole("`9[JustEx] `4No ConsumableID configured.")
        return
    end

    for _, itemId in ipairs(consumableIDs) do
        if inv(itemId) < 1 then
            Taking = true
            GetRemote = false
            CheatOn = false
            CheatOff = false
            MagW = false

            RemoveHooks("onvariant")
            AddHook("OnDraw", "PNB_GUI", PNB_GUI)

            local attempts = 0
            repeat
                attempts = attempts + 1
                local world = GetWorld()
                if world and world.name ~= WorldConsume then
                    SendPacket(3, "action|join_request\nname|" .. WorldConsume .. "|\ninvitedWorld|0")
                    Sleep(7000)
                else
                    Sleep(800)
                end

                LogToConsole("`9[JustEx] `1Taking Consumable...")

                for _, o in pairs(GetObjectList() or {}) do
                    if o.id == itemId then
                        Sleep(500)
                        SendPacket(2, "action|dialog_return\ndialog_name|cheats\ncheck_autofarm|0\ncheck_bfg|0\ncheck_gems|1\ncheck_lonely|0\ncheck_ignoreo|0\ncheck_ignoref|0\n")
                        Sleep(5000)
                        SendPacket(2, "action|respawn\n")
                        Sleep(5000)
                        SafeFindPath(math.floor(o.pos.x / 32), math.floor(o.pos.y / 32), 500)
                        ChangeValue("[C] Modfly", true)
                        Sleep(DelayTake)
                        ChangeValue("[C] Modfly", false)
                        Sleep(DelayTake)
                        if inv(itemId) > 0 then
                            LogToConsole("`9[JustEx] `2Successfully Took Item! ID=" .. itemId)
                        end
                        break
                    end
                end
            until inv(itemId) >= 1 or attempts >= 15 or not ScriptRunning

            if inv(itemId) < 1 then
                LogToConsole("`9[JustEx] `4Gagal ambil item " .. itemId .. ", TakeConsumable dimatikan.")
                TakeConsumable = false
            else
                LogToConsole("`9[JustEx] `2Consumable ready! BFG Mode Active!")
            end

            if WorldName and WorldName ~= "" then
                SendPacket(3, "action|join_request\nname|" .. WorldName .. "|\ninvitedWorld|0")
                Sleep(7000)
            end
            Taking = false
            Sleep(1200)
            AddHook("onvariant", "onvariant", onvariant)
            if not TakeConsumable then return end
        end
    end
end

LastConvertTime = 0

function AutoConvert()
    if TelX == 0 and TelY == 0 then return end
    if os.time() - LastConvertTime < 10 then return end
    LastConvertTime = os.time()

    local gems = Windows and (GetPlayerInfo().gems or 0) or (GetPlayerItems().gems or 0)
    local maxG = MaxGems or 300000

    if SuckBgems and obj(BlackGems or 0) >= 100000 then
        SendPacket(2, "action|dialog_return\ndialog_name|popup\nbuttonClicked|bgem_suckall\n")
    end

    if AutoBuyWL then
        if inv(242) < 100 and inv(1796) < 100 and inv(7188) < 100 and gems >= maxG then
            SendPacket(2, "action|buy\nitem|buy_worldlockpack")
        elseif inv(242) >= 100 and inv(1796) < 100 and inv(7188) < 100 then
            SendPacketRaw(false, { type = 10, value = 242 })
        elseif inv(1796) >= 100 and inv(7188) < 100 then
            SendPacket(2, string.format("action|dialog_return\ndialog_name|telephone\nnum|53785|\nx|%s|\ny|%s|\nbuttonClicked|bglconvert", TelX, TelY))
        elseif inv(7188) >= 100 then
            SendPacket(2, "action|dialog_return\ndialog_name|info_box\nbuttonClicked|make_bgl")
        end
    end

    if ConvertDLBGL then
        if gems >= maxG and inv(1796) < 100 and inv(7188) < 100 then
            SendPacket(2, string.format("action|dialog_return\ndialog_name|telephone\nnum|53785|\nx|%s|\ny|%s|\nbuttonClicked|dlconvert", TelX, TelY))
        elseif inv(1796) >= 100 and inv(7188) < 100 then
            SendPacket(2, string.format("action|dialog_return\ndialog_name|telephone\nnum|53785|\nx|%s|\ny|%s|\nbuttonClicked|bglconvert", TelX, TelY))
        elseif inv(7188) >= 100 then
            SendPacket(2, "action|dialog_return\ndialog_name|info_box\nbuttonClicked|make_bgl")
        end
    end

    if ConvertBGL then
        if gems > maxG and inv(7188) < 100 then
            SendPacket(2, string.format("action|dialog_return\ndialog_name|telephone\nnum|53785|\nx|%s|\ny|%s|\nbuttonClicked|bglconvert2", TelX, TelY))
        elseif inv(7188) >= 100 then
            SendPacket(2, "action|dialog_return\ndialog_name|info_box\nbuttonClicked|make_bgl")
        end
    end
end

function SendInfoPNB()
    if not WebhookUrl or WebhookUrl == "" then return end
    local gems = Windows and (GetPlayerInfo().gems or 0) or (GetPlayerItems().gems or 0)
    local mention = (tonumber(DiscordID) or 0) > 0 and string.format("<@%s>", tostring(ToInt(DiscordID))) or ""
    local payload = string.format([[
{
  "content": "%s",
  "embeds": [
    {
      "title": "PNB LOG",
      "fields": [
        { "name": "Account", "value": "%s", "inline": false },
        { "name": "World", "value": "%s", "inline": false },
        { "name": "Magplant", "value": "%d / %d", "inline": false },
        { "name": "Consumables", "value": "%d Songpyeon, %d Clover, %d Arroz", "inline": false },
        { "name": "Total Locks", "value": "%d BLK, %d BGL, %d DL", "inline": false },
        { "name": "Current Gems", "value": "%s", "inline": false },
        { "name": "Gems Drop", "value": "%s BGems, %s PGems", "inline": false },
        { "name": "Uptime", "value": "%s", "inline": false }
      ],
      "footer": { "text": "Today At %s" }
    }
  ]
}]],
        mention,
        Esc(Nick or "?"),
        Esc(WorldName or "?"),
        Now, (Mag and #Mag or 0),
        inv(1056), inv(528), inv(4604),
        inv(11550), inv(7188), inv(1796),
        FNum(gems),
        FNum(obj(BlackGems or 0)), FNum(obj(PinkGems or 0)),
        FTime(os.time() - (StartTime or os.time())),
        os.date("%H:%M")
    )
    SendWebhook(WebhookUrl, payload)
end

function CheckTime()
    if not os or not WebhookPNB then return end
    local now = os.time()
    if (now - (LastTime or 0)) >= 300 then
        if GetWorld() and GetRemote then
            SendInfoPNB()
            Sleep(1000)
            LastTime = now
        end
    end
end

local function AutoPNBCore()
    if not ScriptRunning then return false end
    if not Mag or #Mag == 0 then return false end
    if Now < 1 or Now > #Mag then Now = 1 end

    -- Handle consumables first
    if inv(cid or 0) < 1 then TakeConsumes() end

    -- Handle reconnect
    if reconnect then
        reconnect = false
        Sleep(2000)
        if not GetWorld() then
            SendPacket(3, "action|join_request\nname|" .. (WorldName or "") .. "|\ninvitedWorld|0")
            Sleep(7000)
        end
        return true
    end

    -- Handle pending consumable buffs
    if arroz and ConsumeArroz and GetRemote and not AutoBuff then
        SafeFindPath(pnbX, pnbY, 550)
        Sleep(2000)
        AutoConsume(4604)
        return true
    end

    if clover and (ConsumeSongpyeon or ConsumeClover) and GetRemote and not AutoBuff then
        SafeFindPath(pnbX, pnbY, 550)
        Sleep(2000)
        AutoConsume(ConsumeSongpyeon and 1056 or 528)
        return true
    end

    -- Handle cheat buy
    if cheat and AutoBuyCheats then
        SendPacket(2, "action|dialog_return\ndialog_name|buycheat\ndialog_name|cheats\nbuttonClicked|1\n")
        Sleep(5000)
        MagW = false
        GetRemote = false
        CheatOff = true
        Sleep(2000)
        return true
    end

    -- CheatOff state
    if CheatOff and not GetRemote then
        Sleep(500)
        CheatOff = false
        CheatTurnOff()
        if PublicPNB then
            Sleep(800)
            SendPacket(2, "action|respawn\n")
            Sleep(3000)
        end
        LogToConsole(string.format("`9[JustEx] `1Stop PnB! Last Magplant #%d", Now))
        CheatStopped = true
    end

    local currentMag = Mag[Now]

    if GetRemote then
        if not pnbX or not pnbY then return true end
        if Taking then return true end

        local me = GetLocal()
        if me and me.pos then
            local cx = math.floor(me.pos.x / 32)
            local cy = math.floor(me.pos.y / 32)

            if cx ~= pnbX or cy ~= pnbY then
                CheatTurnOff()
                SafeFindPath(pnbX, pnbY, 550)
                PendingCheatOn = true
                CheatOn = false
            else
                if PendingCheatOn then
                    PendingCheatOn = false
                    CheatOn = true
                    LogToConsole("`9[JustEx] `1Arrived at PnB: enabling CheatOn.")

                    if Modfly then ChangeValue("[C] Modfly", true) end
                    if VerticalPNB then
                        ChangeValue("[C] Ghost mode", true)
                        FindTPVertical(pnbX, pnbY)
                    elseif MirrorPNB then
                        ChangeValue("[C] Ghost mode", true)
                        FindTPLeft(pnbX, pnbY)
                    end
                    Sleep(2000)
                end

                if CheatOn then
                    CheatOn = false
                    CheatTurnOn()
                    LogToConsole(string.format("`9[JustEx] `1Start PnB! X: `2%d, `1Y: `2%d", pnbX, pnbY))
                end

                AutoConvert()
            end
        end

        CheckTime()
        return true
    else
        -- Walk to current mag and wrench it
        if currentMag and currentMag.x and currentMag.y then
            if CheatStopped then
                Sleep(500)
                if PublicPNB then
                    if IsTileWalkable(currentMag.x, currentMag.y - 1) then
                        SafeFindPath(currentMag.x, currentMag.y - 1, 550)
                        Wrench(currentMag.x, currentMag.y)
                    else
                        LogToConsole("`9[JustEx] `1AutoPNB: Current mag blocked, advancing.")
                        Now = (Now >= #Mag) and 1 or (Now + 1)
                    end
                else
                    SafeFindPath(currentMag.x, currentMag.y - 1, 550)
                    Wrench(currentMag.x, currentMag.y)
                end
                return true
            else
                Sleep(500)
            end
        else
            Now = (Now >= #Mag) and 1 or (Now + 1)
            LogToConsole("`9[JustEx] `1AutoPNB: Current mag missing, advancing.")
        end
    end

    return false
end

-- Wrapper: isi WorldName/Nick, cek Mag kosong, tangkap error supaya thread tidak mati
function AutoPNB()
    if not ScriptRunning then return false end

    local w = GetWorld()
    if w and (not WorldName or WorldName == "") then WorldName = w.name end
    local me = GetLocal()
    if me and not Nick then Nick = me.name end
    StartTime = StartTime or os.time()

    if not Mag or #Mag == 0 then
        RecalcMag()
        if not Mag or #Mag == 0 then
            LogToConsole("`9[JustEx] `4Magplant tidak ditemukan (cek BackgroundID). Script dihentikan.")
            TextOverlay("`4No magplant found, stopped")
            ScriptRunning = false
            return false
        end
    end

    local ok, res = pcall(AutoPNBCore)
    if not ok then
        LogToConsole("`9[JustEx] `4AutoPNB error: " .. tostring(res))
        Sleep(2000)
        return false
    end
    return res
end

-- ========================================================
-- PACKET / EVENT HOOKS
-- ========================================================
function onvariant(var)
    local cmd = var[0]

    if not GetWorld() then
        reconnect = true
        if WebhookPNB then ReconnectWebhook = true end
        return false
    end

    if cmd == "OnSDBroadcast" then
        SendPacket(2, "action|input\n|text|/radio")
        return false
    end

    -- Parse talk bubble messages for buff/cheat status
    if type(var[1]) == "string" then
        local msg = var[1]
        if msg:find("backpack slots.") then
            Ghost   = not msg:find("Ghost in the shell")
            arroz   = not msg:find("Breaking Gems")
            clover  = not msg:find("Lucky!")
            cheat   = not msg:find("Cheater")
            return true
        end
    end

    if cmd == "OnConsoleMessage" and type(var[1]) == "string" then
        local msg = var[1]
        if msg:find("Radio enabled,") then BlockSB = true end
        if msg:find("World Locked") then
            if msg:find(WorldName or "", 1, true) then
                MagW = false; GetRemote = false
            else
                MagW = false; GetRemote = false; Ghost = true
                SendPacket(3, "action|join_request\nname|" .. (WorldName or "") .. "|\ninvitedWorld|0")
            end
        end
        if msg:find("Your luck has worn off.") then clover = true end
        if msg:find("Your stomach's rumbling.") then arroz = true end
        if msg:find("boringness.") then cheat = true end
        if msg:find("You're luckier than before!") then clover = false end
        if msg:find("chance of a gem") then arroz = false end
        if msg:find("cheater!") then cheat = false end
    end

    if cmd == "OnTalkBubble" and var[2] then
        local txt = var[2]
        if txt:find("You received a MAGPLANT 5000 Remote") then
            GetRemote = true
            PendingCheatOn = true
            Taking = false
        elseif txt:find("The MAGPLANT 5000 is empty") then
            if not CheatOff then
                GetRemote = false
                CheatOff = true
                MagW = false
                CheatStopped = false
                Taking = true
            end
        end
    end

    if cmd == "OnDialogRequest" and var[1] then
        local dlg = var[1]
        if not GetRemote and Mag and #Mag > 0 then
            local m = Mag[Now]
            if not m then return false end

            if dlg:find("ACTIVE") and dlg:find(tostring(m.x) .. "\n") and dlg:find(tostring(m.y) .. "\n") then
                if dlg:find("Seed") then
                    Now = (Now >= #Mag) and 1 or (Now + 1)
                else
                    SendPacket(2, string.format(
                        "action|dialog_return\ndialog_name|magplant_edit\nx|%d|\ny|%d|\nbuttonClicked|getRemote\n",
                        m.x, m.y))
                end
            elseif dlg:find("DISABLED") and dlg:find(tostring(m.x) .. "\n") and dlg:find(tostring(m.y) .. "\n") then
                if WebhookPNB and Now >= #Mag then AllMagEmpty = true end
                Now = (Now >= #Mag) and 1 or (Now + 1)
            elseif dlg:find("The machine is disabled.") and dlg:find(tostring(m.x) .. "\n") and dlg:find(tostring(m.y) .. "\n") then
                if WebhookPNB and Now >= #Mag then AllMagEmpty = true end
                Now = (Now >= #Mag) and 1 or (Now + 1)
            end
        end
    end

    if not MagW and not Ghost then MagW = true end

    return false
end

-- ========================================================
-- CONFIG SAVE / LOAD
-- ========================================================
local function GetSavePaths(filename)
    local paths = {}
    if Android then
        table.insert(paths, "/storage/emulated/0/Android/media/com.rtsoft.growtopia/scripts/" .. filename)
        table.insert(paths, "/sdcard/Android/media/com.rtsoft.growtopia/scripts/" .. filename)
    end
    if Windows then
        local ok, appdata = pcall(function() return os.getenv("LOCALAPPDATA") end)
        if ok and appdata and appdata ~= "" then
            table.insert(paths, (appdata:gsub("\\", "\\\\")) .. "\\Growtopia\\scripts\\" .. filename)
        end
    end
    table.insert(paths, filename)
    return paths
end

function SaveConfig(filename)
    filename = filename or ConfigPath
    local data = {
        Android = Android, Windows = Windows, BackgroundID = BackgroundID,
        VerticalPNB = VerticalPNB, pnbX = pnbX, pnbY = pnbY,
        TelX = TelX, TelY = TelY, AutoBuff = AutoBuff, AutoRemote = AutoRemote,
        ConsumeArroz = ConsumeArroz, ConsumeClover = ConsumeClover,
        ConsumeSongpyeon = ConsumeSongpyeon, AutoBuyWL = AutoBuyWL,
        ConvertBGL = ConvertBGL, ConvertDLBGL = ConvertDLBGL,
        MaxGems = MaxGems, DelayTake = DelayTake, TakeConsumable = TakeConsumable,
        WorldConsume = WorldConsume, AutoBuyCheats = AutoBuyCheats,
        WebhookPNB = WebhookPNB, WebhookUrl = WebhookUrl, DiscordID = DiscordID,
        IgnoreOther = IgnoreOther, MirrorPNB = MirrorPNB, PublicPNB = PublicPNB,
        BypassPaywall = BypassPaywall, BypassWayBlock = BypassWayBlock,
        SuckBgems = SuckBgems, NoGemsDrop = NoGemsDrop, AntiLag = AntiLag,
        TakeMagFromBehind = TakeMagFromBehind, AutoDonate = AutoDonate,
        DonateX = DonateX, DonateY = DonateY, DelayBuyCheat = DelayBuyCheat,
        VendingBackgroundID = VendingBackgroundID, Modfly = Modfly
    }

    local lines = { "return {\n" }
    for k, v in pairs(data) do
        if type(v) == "string" then
            local esc = v:gsub("\\", "\\\\"):gsub('"', '\\"')
            table.insert(lines, string.format('  %s = "%s",\n', k, esc))
        else
            table.insert(lines, string.format('  %s = %s,\n', k, tostring(v)))
        end
    end
    table.insert(lines, "}\n")
    local serialized = table.concat(lines)

    for _, path in ipairs(GetSavePaths(filename)) do
        local f = io.open(path, "w")
        if f then
            local ok, werr = pcall(function() f:write(serialized); f:close() end)
            if ok then
                TextOverlay("`2Config saved: " .. path)
                LogToConsole("SaveConfig -> " .. path)
                return true
            else
                TextOverlay("`4Write failed: " .. tostring(werr))
            end
        end
    end
    TextOverlay("`4Failed to save config")
    return false
end

function LoadConfig(filename)
    filename = filename or ConfigPath
    local paths = GetSavePaths(filename)

    for _, path in ipairs(paths) do
        local f = io.open(path, "r")
        if f then
            f:close()
            local ok, cfg = pcall(dofile, path)
            if ok and type(cfg) == "table" then
                for k, v in pairs(cfg) do _G[k] = v end
                SanitizeWebhook()
                CheckIgnore = IgnoreOther and 1 or 0
                if type(ApplyGUI) == "function" then ApplyGUI() end
                TextOverlay("`2Config loaded: " .. path)
                LogToConsole("LoadConfig -> " .. path)
                return true
            else
                TextOverlay("`4Invalid config: " .. path)
            end
        end
    end

    TextOverlay("`4Config not found: " .. filename)
    return false
end

-- ========================================================
-- APPLY GUI SETTINGS TO SCRIPT STATE
-- ========================================================
function ApplyGUI()
    Android     = not not Android
    Windows     = not not Windows
    VerticalPNB = not not VerticalPNB
    VerticalPlant = VerticalPNB
    WebhookPNB  = not not WebhookPNB
    WebhookPTHT = WebhookPNB

    BackgroundID = tonumber(BackgroundID) or 12840
    MaxGems      = tonumber(MaxGems)      or 400000
    DelayTake    = tonumber(DelayTake)    or 1000
    DiscordID    = tonumber(DiscordID)    or 0
    pnbX = tonumber(pnbX) or 0
    pnbY = tonumber(pnbY) or 0
    TelX = tonumber(TelX) or 0
    TelY = tonumber(TelY) or 0
    WorldConsume = tostring(WorldConsume or "")
    WebhookUrl   = tostring(WebhookUrl   or "")
    SanitizeWebhook()

    CheckIgnore  = IgnoreOther  and 1 or 0
    CheckBuff    = AutoBuff     and 1 or 0
    CheckRemote  = AutoRemote   and 1 or 0
    CheckGems    = NoGemsDrop   and 1 or 0

    RecalcMag()
    UpdateBypassRules()
    ActiveLag()

    TextOverlay("`2GUI applied to script settings")
    LogToConsole("ApplyGUI -> settings applied")
end

-- ========================================================
-- IN-GAME DIALOG (fallback when ImGui not available)
-- ========================================================
function dialog(message)
    local me = GetLocal()
    local name = me and me.name:match("%S+") or "?"
    local body = string.format(
        "add_label_with_icon|big|`2PNB BOTHAX V2  ||16224|\n" ..
        "add_spacer|small|\n" ..
        "add_textbox|GrowID : %s||\n" ..
        "add_textbox|World : `2%s||\n" ..
        "add_textbox|Position BFG : `6%s `0, `6%s||\n" ..
        "add_textbox|`8%s||\n" ..
        "add_spacer|small|\n" ..
        "add_smalltext|JustEx Community.|\n" ..
        "add_url_button||`0Discord``|NOFLAGS|https://discord.gg/Zs4CyJM2u|Join my server.|0|\n" ..
        "add_quick_exit|",
        name, tostring(WorldName), tostring(pnbX), tostring(pnbY), tostring(message)
    )
    SendVariantList({ [0] = "OnDialogRequest", [1] = body })
end

-- ========================================================
-- MAIN ENTRY / IMGUI GUI
-- ========================================================
function PNB_GUI()
    if not ImGui then return end

    local opened = ImGui.Begin("PNB - BOTHAX V2 - Settings")
    if not opened then ImGui.End(); return end

    -- Top bar
    if ImGui.Button("Save") then SaveConfig(ConfigPath) end
    ImGui.SameLine()
    if ImGui.Button("Load") then LoadConfig(ConfigPath) end
    ImGui.SameLine()
    if ImGui.Button("Defaults") then
        for k, v in pairs({
            Android=false, Windows=false, BackgroundID=12840, VerticalPNB=false,
            AutoBuff=false, AutoRemote=false, ConsumeArroz=false, ConsumeClover=false,
            ConsumeSongpyeon=false, AutoBuyWL=false, ConvertBGL=false, ConvertDLBGL=true,
            MaxGems=400000, DelayTake=1000, TakeConsumable=false, WorldConsume="JustEx",
            AutoBuyCheats=true, WebhookPNB=false, WebhookUrl="", DiscordID=0, IgnoreOther=false,
            MirrorPNB=false, PublicPNB=false, BypassPaywall=false, BypassWayBlock=false,
            SuckBgems=false, NoGemsDrop=true, AntiLag=false,
            TakeMagFromBehind=true, AutoDonate=false, DonateX=0, DonateY=0,
            DelayBuyCheat=30, VendingBackgroundID=298, Modfly=true
        }) do _G[k] = v end
        TextOverlay("`2Defaults restored")
    end

    ImGui.Separator()
    local okP, vP = ImGui.InputText("##configpath", ConfigPath or "PNB-SETTING.lua", 256)
    if okP and vP ~= "" then ConfigPath = vP end

    -- Device
    ImGui.Separator()
    ImGui.Text("Device")
    local okA, vA = ImGui.Checkbox("Android", Android or false)
    if okA then Android = vA end
    ImGui.SameLine()
    local okW, vW = ImGui.Checkbox("Windows", Windows or false)
    if okW then Windows = vW end

    -- Magplant
    ImGui.Separator()
    ImGui.Text("Magplant & Background")
    local okBg, vBg = ImGui.InputInt("BackgroundID", BackgroundID or 12840)
    if okBg then BackgroundID = vBg end
    local okTMB, vTMB = ImGui.Checkbox("Take Mag From Behind", TakeMagFromBehind or false)
    if okTMB then TakeMagFromBehind = vTMB end

    -- Mode
    ImGui.Separator()
    ImGui.Text("Mode PNB")
    local okVP, vVP = ImGui.Checkbox("VerticalPNB (Mneck)", VerticalPNB or false)
    if okVP then VerticalPNB = vVP; VerticalPlant = vVP end
    local okPub, vPub = ImGui.Checkbox("PublicPNB", PublicPNB or false)
    if okPub then PublicPNB = vPub end
    local okBPW, vBPW = ImGui.Checkbox("Bypass Paywall", BypassPaywall or false)
    if okBPW then BypassPaywall = vBPW; UpdateBypassRules() end
    local okBWB, vBWB = ImGui.Checkbox("Bypass One-Way Block", BypassWayBlock or false)
    if okBWB then BypassWayBlock = vBWB; UpdateBypassRules() end

    -- Positions
    ImGui.Separator()
    ImGui.Text("Positions (PNB / TEL)")
    local okX, vX = ImGui.InputInt("pnbX", pnbX or 0); if okX then pnbX = vX end
    local okY, vY = ImGui.InputInt("pnbY", pnbY or 0); if okY then pnbY = vY end
    local okTX, vTX = ImGui.InputInt("TelX", TelX or 0); if okTX then TelX = vTX end
    local okTY, vTY = ImGui.InputInt("TelY", TelY or 0); if okTY then TelY = vTY end

    if ImGui.Button("Capture PNB pos") then
        local me = GetLocal()
        if me and me.pos then
            pnbX = math.floor(me.pos.x / 32)
            pnbY = math.floor(me.pos.y / 32)
            TextOverlay(string.format("`2PNB Pos: X=%d Y=%d", pnbX, pnbY))
        end
    end
    ImGui.SameLine()
    if ImGui.Button("Capture TEL pos") then
        local me = GetLocal()
        if me and me.pos then
            TelX = math.floor(me.pos.x / 32)
            TelY = math.floor(me.pos.y / 32)
            TextOverlay(string.format("`2TEL Pos: X=%d Y=%d", TelX, TelY))
        end
    end

    -- Conversion
    ImGui.Separator()
    ImGui.Text("Conversion & Timing")
    local okABW, vABW = ImGui.Checkbox("Auto Buy WL", AutoBuyWL or false); if okABW then AutoBuyWL = vABW end
    local okCB, vCB = ImGui.Checkbox("Convert BGL", ConvertBGL or false); if okCB then ConvertBGL = vCB end
    local okCD, vCD = ImGui.Checkbox("Convert DL to BGL", (ConvertDLBGL == nil) and true or ConvertDLBGL)
    if okCD then ConvertDLBGL = vCD end
    local okMG, vMG = ImGui.InputInt("Max Earn Gems", MaxGems or 400000)
    if okMG then MaxGems = math.max(0, vMG) end

    -- Consumables
    ImGui.Separator()
    ImGui.Text("Auto Consumable")
    local okCA, vCA = ImGui.Checkbox("ConsumeArroz", ConsumeArroz or false); if okCA then ConsumeArroz = vCA end
    local okCC, vCC = ImGui.Checkbox("ConsumeClover", ConsumeClover or false); if okCC then ConsumeClover = vCC end
    local okCS, vCS = ImGui.Checkbox("ConsumeSongpyeon", ConsumeSongpyeon or false); if okCS then ConsumeSongpyeon = vCS end

    ImGui.Separator()
    ImGui.Text("Auto Take Consumable")
    local okTC, vTC = ImGui.Checkbox("TakeConsumable", TakeConsumable or false); if okTC then TakeConsumable = vTC end
    local okWC, vWC = ImGui.InputText("World Consume", WorldConsume or "", 256); if okWC then WorldConsume = vWC end
    ImGui.TextColored(1, 0.7, 0, 1, "VendingBackgroundID diatur di Other Settings")

    -- Cheat
    ImGui.Separator()
    ImGui.Text("Auto Cheat")
    local okMF, vMF = ImGui.Checkbox("Modfly (aktif saat PNB start)", Modfly or false)
    if okMF then Modfly = vMF end
    local okAB, vAB = ImGui.Checkbox("Auto Buff", AutoBuff or false)
    if okAB then AutoBuff = vAB; CheckBuff = vAB and 1 or 0 end
    local okAR, vAR = ImGui.Checkbox("Auto Magplant Remote", AutoRemote or false)
    if okAR then AutoRemote = vAR; CheckRemote = vAR and 1 or 0 end

    -- Other
    ImGui.Separator()
    ImGui.Text("Other Settings")
    local okABC, vABC = ImGui.Checkbox("AutoBuyCheats", (AutoBuyCheats == nil) and true or AutoBuyCheats)
    if okABC then AutoBuyCheats = vABC end
    local okSB, vSB = ImGui.Checkbox("SuckBgems", SuckBgems or false); if okSB then SuckBgems = vSB end
    local okNG, vNG = ImGui.Checkbox("NoGemsDrop", NoGemsDrop or false)
    if okNG then NoGemsDrop = vNG; CheckGems = vNG and 1 or 0 end
    local okIO, vIO = ImGui.Checkbox("IgnoreOther", IgnoreOther or false)
    if okIO then IgnoreOther = vIO; CheckIgnore = vIO and 1 or 0 end
    local okMP, vMP = ImGui.Checkbox("MirrorPNB", MirrorPNB or false); if okMP then MirrorPNB = vMP end
    local okAL, vAL = ImGui.Checkbox("AntiLag", AntiLag or false)
    if okAL then AntiLag = vAL; ActiveLag() end
    local okAD, vAD = ImGui.Checkbox("AutoDonate (2 BGL)", AutoDonate or false)
    if okAD then AutoDonate = vAD end
    if AutoDonate then
        local okDX, vDX = ImGui.InputInt("DonateX", DonateX or 0); if okDX then DonateX = vDX end
        local okDY, vDY = ImGui.InputInt("DonateY", DonateY or 0); if okDY then DonateY = vDY end
        if ImGui.Button("Capture Donate pos") then
            local me = GetLocal()
            if me and me.pos then
                DonateX = math.floor(me.pos.x / 32)
                DonateY = math.floor(me.pos.y / 32)
                TextOverlay(string.format("`2Donate Pos: X=%d Y=%d", DonateX, DonateY))
            end
        end
    end
    local okDBC, vDBC = ImGui.InputInt("DelayBuyCheat (menit)", DelayBuyCheat or 30)
    if okDBC then DelayBuyCheat = math.max(1, vDBC) end
    local okVBG, vVBG = ImGui.InputInt("VendingBackgroundID", VendingBackgroundID or 298)
    if okVBG then VendingBackgroundID = vVBG end

    -- Webhook
    ImGui.Separator()
    ImGui.Text("Webhook (isi URL webhook milikmu)")
    local okWH, vWH = ImGui.Checkbox("Enable Webhook", WebhookPNB or false)
    if okWH then WebhookPNB = vWH; WebhookPTHT = vWH end
    local okWU, vWU = ImGui.InputText("Webhook URL", WebhookUrl or "", 256); if okWU then WebhookUrl = vWU end
    local okDI, vDI = ImGui.InputText("Discord ID", tostring(DiscordID or 0), 256)
    if okDI then DiscordID = tonumber(vDI) or 0 end

    -- Start / Stop
    ImGui.Separator()
    if ImGui.Button("Start PNB") then
        if not ScriptRunning then
            StopRequested = false
            ScriptRunning = true
            GetRemote = false
            CheatStopped = true
            StartTime = os.time()
            local w = GetWorld()
            if w then WorldName = w.name end
            local me = GetLocal()
            if me then Nick = me.name end
            ApplyGUI()
            RunThread(function()
                while ScriptRunning do
                    AutoPNB()
                    Sleep(500)
                end
            end)
        else
            TextOverlay("`9Script already running")
        end
    end
    ImGui.SameLine()
    if ImGui.Button("Stop PNB") then
        if ScriptRunning then
            StopRequested = true
            ScriptRunning = false
            GetRemote = false
            CheatOn = false
            RemoveHooks()
            AddHook("OnDraw", "PNB_GUI", PNB_GUI)
            AddHook("onvariant", "onvariant", onvariant)
            TextOverlay("`4Stop requested")
        else
            TextOverlay("`9Script not running")
        end
    end

    -- Status
    ImGui.Separator()
    local status = ScriptRunning and "Running" or "Stopped"
    ImGui.Text("Status: " .. status)
    ImGui.Text(string.format("Config: %s", tostring(ConfigPath)))
    ImGui.Text(string.format("pnbX:%s pnbY:%s TelX:%s TelY:%s Mags:%d",
        tostring(pnbX or "-"), tostring(pnbY or "-"),
        tostring(TelX or "-"), tostring(TelY or "-"),
        (Mag and #Mag or 0)))

    ImGui.End()
end

-- ========================================================
-- STARTUP
-- ========================================================
math.randomseed(os.time())

-- ImGui.Checkbox: normalkan ke (changed, value) apa pun bentuk return binding-nya
if ImGui and not ImGui._cbPatched then
    local _CB = ImGui.Checkbox
    ImGui.Checkbox = function(label, v)
        local r1, r2 = _CB(label, v)
        if r2 ~= nil then return r1, r2 end
        if r1 then return true, not v end
        return false, v
    end
    ImGui._cbPatched = true
end

-- RemoveHooks() tanpa nama jangan mematikan onvariant selamanya
if not _RemoveHooksPatched then
    local _Remove = RemoveHooks
    function RemoveHooks(name)
        _Remove(name)
        if not name then AddHook("onvariant", "onvariant", onvariant) end
    end
    _RemoveHooksPatched = true
end

-- Scan magplant awal (aman kalau belum di dalam world)
do
    local wX, wY = GetWorldSize()
    Mag = GetMag(wX, wY) or {}
end

-- Snapshot awal
PGems = pcall(obj, PinkGems) and obj(PinkGems or 0) or 0
BGems = pcall(obj, BlackGems) and obj(BlackGems or 0) or 0
BLK   = pcall(inv, 11550) and inv(11550) or 0
BGL   = pcall(inv, 7188)  and inv(7188)  or 0
DL    = pcall(inv, 1796)  and inv(1796)  or 0

do
    local w = GetWorld()
    if w then WorldName = w.name end
    local me = GetLocal()
    if me then Nick = me.name end
end

AddHook("OnDraw",    "PNB_GUI",    PNB_GUI)
AddHook("onvariant", "onvariant",  onvariant)
LoadConfig(ConfigPath)


-- ------------------------------------------------------------
-- GT FLEET MONITOR -- https://gt-pi-ten.vercel.app
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
    local function countItem(id)
        local n = 0
        pcall(function()
            if FindItem then n = math.max(n, tonumber(FindItem(id)) or 0) end
            if GetItemCount then n = math.max(n, tonumber(GetItemCount(id)) or 0) end
            if GetInventory then
                local bag = GetInventory()
                if type(bag) == "table" then
                    for _, it in ipairs(bag) do
                        if it.id == id then
                            n = n + (tonumber(it.count or it.amount or it.qty) or 1)
                        end
                    end
                end
            end
        end)
        return n
    end
    function M.new(cfg)
        local me = GetLocal and GetLocal()
        local self = setmetatable({}, M)
        self.endpoint = MONITOR_URL .. "/api/heartbeat"
        self.userId = tostring(cfg.userId or (me and me.userid) or math.random(100000, 999999))
        self.name = cfg.name or (me and StripColor(me.name)) or ("Bot_" .. self.userId)
        self.interval = 5
        self.instanceId = uuid4()
        self.seq = 0
        self.lastTick = 0
        self.startTime = os.time()
        return self
    end
    function M:tick()
        if os.time() - self.lastTick < self.interval then return end
        self.lastTick = os.time()
        self.seq = self.seq + 1
        local gems, wl, dl, bgl, level, ping = 0, 0, 0, 0, 1, 0
        local world = (WorldName ~= "" and WorldName) or "EXIT"
        pcall(function()
            local me = GetLocal and GetLocal()
            if me then
                gems = tonumber(me.gems or gems) or gems
                level = tonumber(me.level or level) or level
                ping = tonumber(me.ping or ping) or ping
            end
            wl  = countItem(1796)
            dl  = countItem(7188)
            bgl = countItem(11330)
        end)
        local body = string.format(
            '{"userId":%s,"name":"%s","world":"%s","gems":%d,"wl":%d,"dl":%d,"bgl":%d,"level":%d,"pingMs":%d,"uptimeSec":%d,"instanceId":"%s","seq":%d}',
            self.userId,
            (self.name):gsub('"', '\"'):gsub("%c", ""),
            world:gsub('"', '\"'):gsub("%c", ""),
            gems, wl, dl, bgl, level, ping,
            os.time() - self.startTime,
            self.instanceId, self.seq
        )
        pcall(MakeRequest, self.endpoint, "POST", body, { ["Content-Type"] = "application/json" })
    end
    local me = GetLocal and GetLocal()
    _mon = M.new({
        userId = me and me.userid,
        name = me and StripColor(me.name),
    })
end

local function PushWebMonitor()
    if _mon and _mon.tick then _mon:tick() end
end

RunThread(function()
    while true do
        Sleep(10000)
        pcall(PushWebMonitor)
    end
end)
