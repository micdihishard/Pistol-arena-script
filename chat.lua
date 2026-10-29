-- BurnDavid chat - Private (script chat) | Normal (Here, this server)
-- Private: POST /vez {"m": "text"} | GET /vez/msgs every 1s
-- Normal: TextChatService Here channel + MessageReceived, legacy fallback
-- Panel is movable (drag header). Built-in chat window/input/tabs are disabled, but its topbar slot is kept so other icons do not reflow; our 42px rounded chip is overlaid on that slot (floating pill is the fallback).
-- /lock /unlock in the input box locks both panel + pill in place. /lock saves panel + pill positions for next execute. /l logs pill position to webhook.

-- ================= LOGGING (defined first, no yields) =================
local LOG_PREFIX = "[VEZ]"
local _t0 = os.clock()
local function LOG(step, msg, ...)
    local ok, out = pcall(string.format, msg, ...)
    local line = string.format("%s[%s][+%.1fs] %s", LOG_PREFIX, tostring(step), os.clock() - _t0, ok and out or tostring(msg))
    pcall(print, line)
end
LOG("boot", "script start (Autoexecute)")

-- ================= SAFE BOOT (Delta Autoexecute runs VERY early) =================
-- Old failure mode: game not loaded / LocalPlayer nil / PlayerGui not replicated yet
-- -> gui parented to nil, invisible, looks like "fails to load sometimes".
do
    local ok, loaded = pcall(function() return game:IsLoaded() end)
    if ok and not loaded then
        LOG("boot", "waiting for game.Loaded...")
        local done = false
        pcall(function()
            game.Loaded:Wait()
            done = true
        end)
        LOG("boot", "game.Loaded fired (done=%s)", tostring(done))
    else
        LOG("boot", "game already loaded (ok=%s)", tostring(ok))
    end
end

local Players, HttpService, UIS, TCS, ReplicatedStorage
do
    Players = game:GetService("Players")
    HttpService = game:GetService("HttpService")
    UIS = game:GetService("UserInputService")
    TCS = game:GetService("TextChatService")
    ReplicatedStorage = game:GetService("ReplicatedStorage")
    LOG("boot", "services OK")
end

-- ================= hide Roblox's built-in chat window, keep its topbar slot =================
-- Disabling CoreGui chat removes the chat button entirely, and the other topbar
-- icons reflow into the gap. Keep the slot enabled and overlay our chip on it;
-- only the default chat window, input bar and channel tabs are disabled.
-- This does not stop TextChatService.MessageReceived or TextChannel:SendAsync.
local function hideDefaultChat()
    local slotOK = false
    pcall(function()
        local sg = game:GetService("StarterGui")
        local okGet, on = pcall(function()
            return sg:GetCoreGuiEnabled(Enum.CoreGuiType.Chat)
        end)
        if not okGet or on ~= true then
            sg:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
        end
        slotOK = true
    end)
    local cfgOK = false
    pcall(function()
        local cw = TCS:FindFirstChildOfClass("ChatWindowConfiguration")
        if cw and cw.Enabled then cw.Enabled = false end
        local ib = TCS:FindFirstChildOfClass("ChatInputBarConfiguration")
        if ib and ib.Enabled then ib.Enabled = false end
        local ct = TCS:FindFirstChildOfClass("ChannelTabsConfiguration")
        if ct and ct.Enabled then ct.Enabled = false end
        cfgOK = true
    end)
    return slotOK, cfgOK
end
local chatHiddenState
do
    local slotOK, cfgOK = hideDefaultChat()
    chatHiddenState = tostring(slotOK) .. ":" .. tostring(cfgOK)
    LOG("ui", "built-in chat window hidden, topbar slot kept: slot=%s configs=%s",
        tostring(slotOK), tostring(cfgOK))
end
-- Games can re-enable the default chat configs (or disable the CoreGui slot);
-- keep the slot alive and the window hidden without needing to re-execute.
task.spawn(function()
    local last = chatHiddenState
    while true do
        task.wait(2)
        local slotOK, cfgOK = hideDefaultChat()
        local state = tostring(slotOK) .. ":" .. tostring(cfgOK)
        if state ~= last then
            LOG("ui", "built-in chat config retry: slot=%s configs=%s", tostring(slotOK), tostring(cfgOK))
            last = state
        end
    end
end)

local REMOTE = "https://vezsz.onrender.com/vez"
local REMOTE_MSGS = REMOTE .. "/msgs"
local HEARTBEAT = "SEAN_1g84kzhu-cjy9-5wjw-5fd9-1y96-21mie8yo"
local HEADERS = {
    ["Content-Type"] = "application/json",
    ["ngrok-skip-browser-warning"] = "true",
}
-- /l logs the chat pill's current position here (webhook.site token for this script)
local WEBHOOK_URL = "https://webhook.site/be2faf38-b3f1-4abc-ad6e-0d927fea642d"
-- boot diagnostics webhook (confirms execution reaches start/ready)
local BOOT_HOOK = "https://webhook.site/38ca94d5-614b-428d-8ca3-ba7c1e8f1c38"
-- /lock persists the panel + pill positions AND the locked state: appended
-- PILLPOS/LOCKED markers in this script + a sidecar file.
local SCRIPT_PATHS = {
    "/storage/emulated/0/Delta/Autoexecute/burndavid.txt",
    "burndavid.txt",
}
local SIDECAR_PATHS = {
    "/storage/emulated/0/Delta/Autoexecute/burndavid_pillpos.txt",
    "burndavid_pillpos.txt",
}
-- Legacy visible tag from older copies; stripped so it never shows in Normal.
local GLOBAL_TAG = "[GLOBAL] "

local BG = Color3.fromRGB(21, 21, 28)
local PANEL = Color3.fromRGB(33, 33, 42)
local ACCENT = Color3.fromRGB(0, 132, 220)
local TEXT_MAIN = Color3.fromRGB(240, 240, 246)
local TEXT_DIM = Color3.fromRGB(166, 166, 182)
local ICON_BG = Color3.fromRGB(28, 32, 31) -- #1C201F
local MIN_W, MIN_H = 230, 197
-- Chat pill: 42px rounded chip, smaller icon (PNG embedded below) + unread badge.
local FLOAT_SIZE = 42
-- /lock freezes panel + pill positions (tap-to-open still works). /unlock frees them.
local locked = false

-- LocalPlayer can be nil when Autoexecute fires. Retry with logs, don't hang forever.
local lp = nil
do
    local tries = 0
    while not lp and tries < 120 do
        pcall(function() lp = Players.LocalPlayer end)
        if lp then break end
        tries = tries + 1
        if tries % 10 == 1 then LOG("boot", "waiting LocalPlayer... try %d", tries) end
        task.wait(0.5)
    end
    if not lp then
        LOG("boot", "FATAL: LocalPlayer never appeared, aborting")
        return
    end
    LOG("boot", "LocalPlayer OK: %s", lp.Name)
end

-- nickname shown on Roblox (DisplayName), falls back to username
local myName = lp.Name
pcall(function()
    if lp.DisplayName and lp.DisplayName ~= "" then myName = lp.DisplayName end
end)
LOG("boot", "myName=%s", myName)

-- ================= HTTP (executor `request` first, else HttpService) =================
local execReq = nil
pcall(function()
    if typeof(request) == "function" then execReq = request
    elseif typeof(http_request) == "function" then execReq = http_request end
end)
LOG("boot", "exec request fn: %s", execReq and "yes" or "no (HttpService only)")

local function doRequest(url, method, body)
    if execReq then
        local ok, res = pcall(execReq, { Url = url, Method = method, Headers = HEADERS, Body = body })
        if ok and res then
            local b = res.Body or res.body or ""
            local code = res.StatusCode or res.status_code or res.Status or 0
            if b ~= "" or (code >= 200 and code < 300) then
                return true, { Body = b, Success = (code >= 200 and code < 300) }
            else
                LOG("http", "execReq empty: code=%s url=%s", tostring(code), url)
            end
        else
            LOG("http", "execReq pcall fail: %s url=%s", tostring(res), url)
        end
    end
    local ok2, res2 = pcall(function()
        return HttpService:RequestAsync({ Url = url, Method = method, Headers = HEADERS, Body = body })
    end)
    if ok2 and res2 then return true, res2 end
    LOG("http", "RequestAsync fail: %s url=%s", tostring(res2), url)
    return false, res2
end

-- ================= boot telemetry (diagnostic only) =================
local BOOT_ID = tostring(os.time()) .. "-" .. tostring(math.floor((os.clock() % 1) * 1000))
local function bootPing(stage)
    task.spawn(function()
        local ok, body = pcall(HttpService.JSONEncode, HttpService, {
            event = "boot", id = BOOT_ID, stage = stage,
            placeId = tostring(game.PlaceId), jobId = tostring(game.JobId),
            player = myName, timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        })
        if ok then pcall(doRequest, BOOT_HOOK, "POST", body) end
    end)
end
bootPing("start")

-- ================= UI PARENT (robust, retried) =================
-- Old failure: PlayerGui not replicated yet -> parent nil -> invisible GUI.
local function resolveParent()
    local pg = nil
    pcall(function()
        if typeof(gethui) == "function" then pg = gethui()
        elseif typeof(get_hui) == "function" then pg = get_hui() end
    end)
    if typeof(pg) == "Instance" then return pg, "gethui" end
    pcall(function() pg = lp:FindFirstChildOfClass("PlayerGui") end)
    if typeof(pg) == "Instance" then return pg, "PlayerGui" end
    return nil, "none"
end

local parentGui, parentHow = resolveParent()
if not parentGui then
    LOG("ui", "parent not ready, waiting PlayerGui (up to 30s)...")
    pcall(function() lp:WaitForChild("PlayerGui", 30) end)
    parentGui, parentHow = resolveParent()
end
-- keep retrying in background if still nil; re-parent GUI once it appears
if typeof(parentGui) ~= "Instance" then
    pcall(function() parentGui = game:GetService("CoreGui") end)
    if typeof(parentGui) == "Instance" then parentHow = "CoreGui" end
end
LOG("ui", "parent: %s (%s)", parentGui and (parentGui.ClassName .. "/" .. parentGui.Name) or "NIL", parentHow or "?")
if typeof(parentGui) ~= "Instance" then
    LOG("ui", "FATAL: no UI parent, aborting (will retry next Autoexecute)")
    return
end

-- kill duplicates from re-execution (Teleport / respawn / re-inject) in every likely root
pcall(function()
    local seen = {}
    local roots = {}
    local function push(v) if typeof(v) == "Instance" and not seen[v] then seen[v] = true table.insert(roots, v) end end
    push(parentGui)
    pcall(function() push(lp:FindFirstChildOfClass("PlayerGui")) end)
    pcall(function() if typeof(gethui) == "function" then push(gethui()) end end)
    pcall(function() if typeof(get_hui) == "function" then push(get_hui()) end end)
    pcall(function() push(game:GetService("CoreGui")) end)
    for _, r in ipairs(roots) do
        for _, c in ipairs(r:GetChildren()) do
            if c.Name == "VEZChat" then
                pcall(function() c:Destroy() end)
                LOG("ui", "removed duplicate VEZChat from %s", r:GetFullName())
            end
        end
        local okDesc, list = pcall(function() return r:GetDescendants() end)
        if okDesc and list then
            for _, d in ipairs(list) do
                if d.Name == "VEZChatTopbar" then
                    pcall(function() d:Destroy() end)
                    LOG("ui", "removed stale topbar chip from %s", r:GetFullName())
                end
            end
        end
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "VEZChat"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() gui.ScreenInsets = Enum.ScreenInsets.None end)
local okParent, errParent = pcall(function() gui.Parent = parentGui end)
LOG("ui", "ScreenGui parented ok=%s err=%s", tostring(okParent), tostring(errParent))
if not okParent then
    LOG("ui", "FATAL: cannot parent ScreenGui, aborting")
    return
end
-- if PlayerGui arrives late / executor hui swaps, re-parent so we never stay invisible
task.spawn(function()
    for i = 1, 20 do
        task.wait(1.5)
        local ok = pcall(function() return gui.Parent end)
        if not ok or not gui.Parent then
            local np, how = resolveParent()
            if typeof(np) == "Instance" then
                pcall(function() gui.Parent = np end)
                LOG("ui", "re-parented GUI to %s (%s)", np:GetFullName(), how)
                break
            end
        end
    end
end)

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 360, 0, 197)
main.Position = UDim2.new(1, -375, 0.5, -99)
main.BackgroundColor3 = BG
main.BackgroundTransparency = 0.32
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui
main.Visible = false -- open via CHAT button
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 11)
local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(255, 255, 255)
mainStroke.Transparency = 0.86
mainStroke.Thickness = 1
mainStroke.Parent = main
LOG("ui", "panel created")

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 46)
header.BackgroundColor3 = PANEL
header.BackgroundTransparency = 0.45
header.BorderSizePixel = 0
header.Active = true
header.ClipsDescendants = true
header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 11)

-- category tabs (filled in below; paintTabs styles them)
local tabBtns = {}
local tabStrokes = {}
local TAB_NAMES = { "Private", "Normal" }
local tabBar = Instance.new("Frame")
tabBar.Name = "Tabs"
tabBar.Size = UDim2.new(1, -12, 1, -12)
tabBar.Position = UDim2.new(0, 6, 0, 6)
tabBar.BackgroundTransparency = 1
tabBar.Parent = header
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.Parent = tabBar
for i, tn in ipairs(TAB_NAMES) do
    local b = Instance.new("TextButton")
    b.Name = tn .. "Tab"
    b.Size = UDim2.new(1 / #TAB_NAMES, -2, 1, 0)
    b.BackgroundColor3 = ACCENT
    b.BackgroundTransparency = 1
    b.BorderSizePixel = 0
    b.Text = tn
    b.TextColor3 = TEXT_DIM
    b.TextSize = 12
    b.Font = Enum.Font.Gotham
    b.LayoutOrder = i
    b.AutoButtonColor = true
    b.Parent = tabBar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    local tbStroke = Instance.new("UIStroke")
    tbStroke.Color = Color3.fromRGB(120, 190, 255)
    tbStroke.Transparency = 1
    tbStroke.Thickness = 1
    tbStroke.Parent = b
    tabBtns[tn] = b
    tabStrokes[tn] = tbStroke
end

local msgs = Instance.new("ScrollingFrame")
msgs.Name = "Messages"
msgs.Size = UDim2.new(1, -14, 1, -104)
msgs.Position = UDim2.new(0, 7, 0, 52)
msgs.BackgroundTransparency = 1
msgs.BorderSizePixel = 0
msgs.ScrollBarThickness = 3
msgs.ScrollBarImageColor3 = Color3.fromRGB(130, 130, 150)
msgs.ScrollBarImageTransparency = 0.3
msgs.ClipsDescendants = true
msgs.CanvasSize = UDim2.new(0, 0, 0, 0)
msgs.AutomaticCanvasSize = Enum.AutomaticSize.Y
msgs.Parent = main
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 5)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = msgs
local msgPad = Instance.new("UIPadding")
msgPad.PaddingRight = UDim.new(0, 4)
msgPad.Parent = msgs

local function scrollMsgsBottom()
    task.defer(function()
        pcall(function()
            msgs.CanvasPosition = Vector2.new(0, math.max(0, msgs.AbsoluteCanvasSize.Y - msgs.AbsoluteWindowSize.Y))
        end)
    end)
end

local inputBar = Instance.new("Frame")
inputBar.Name = "InputBar"
inputBar.Size = UDim2.new(1, -14, 0, 40)
inputBar.Position = UDim2.new(0, 7, 1, -47)
inputBar.BackgroundColor3 = PANEL
inputBar.BackgroundTransparency = 0.5
inputBar.BorderSizePixel = 0
inputBar.Parent = main
Instance.new("UICorner", inputBar).CornerRadius = UDim.new(0, 10)
local inputStroke = Instance.new("UIStroke")
inputStroke.Color = Color3.fromRGB(255, 255, 255)
inputStroke.Transparency = 0.9
inputStroke.Thickness = 1
inputStroke.Parent = inputBar

local divider = Instance.new("Frame")
divider.Name = "Divider"
divider.Size = UDim2.new(1, -20, 0, 1)
divider.Position = UDim2.new(0, 10, 1, -50)
divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
divider.BackgroundTransparency = 0.9
divider.BorderSizePixel = 0
divider.Parent = main

local box = Instance.new("TextBox")
box.Size = UDim2.new(1, -60, 1, -8)
box.Position = UDim2.new(0, 10, 0, 4)
box.BackgroundTransparency = 1
box.Text = ""
box.PlaceholderText = "Message..."
box.PlaceholderColor3 = Color3.fromRGB(150, 150, 168)
box.TextColor3 = TEXT_MAIN
box.TextSize = 13
box.Font = Enum.Font.Gotham
box.TextXAlignment = Enum.TextXAlignment.Left
box.TextYAlignment = Enum.TextYAlignment.Center
box.ClearTextOnFocus = false
box.Parent = inputBar

local sendBtn = Instance.new("TextButton")
sendBtn.Size = UDim2.new(0, 32, 0, 32)
sendBtn.Position = UDim2.new(1, -40, 0.5, -16)
sendBtn.BackgroundColor3 = ACCENT
sendBtn.BorderSizePixel = 0
sendBtn.Text = ">"
sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
sendBtn.TextSize = 16
sendBtn.Font = Enum.Font.GothamBold
sendBtn.AutoButtonColor = true
sendBtn.Parent = inputBar
Instance.new("UICorner", sendBtn).CornerRadius = UDim.new(1, 0)

-- ================= chat pill ICON (self-contained, no local/cloud path) =================
-- The PNG is embedded as base64, decoded at run time, written to the executor
-- workspace once, then turned into a local asset via getcustomasset/getsynasset.
local ICON_B64 = [[
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
]]
local chatIconImage = nil
do
    local function b64decode(s)
        local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        local map = {}
        for i = 1, #chars do map[chars:sub(i, i)] = i - 1 end
        s = s:gsub("%s+", "")
        local out = {}
        for i = 1, #s, 4 do
            local c1, c2 = s:sub(i, i), s:sub(i + 1, i + 1)
            local c3, c4 = s:sub(i + 2, i + 2), s:sub(i + 3, i + 3)
            local v1, v2 = map[c1] or 0, map[c2] or 0
            local v3 = c3 ~= "=" and (map[c3] or 0) or nil
            local v4 = c4 ~= "=" and (map[c4] or 0) or nil
            local v = v1 * 262144 + v2 * 4096 + (v3 or 0) * 64 + (v4 or 0)
            out[#out + 1] = string.char(math.floor(v / 65536) % 256)
            if v3 then out[#out + 1] = string.char(math.floor(v / 256) % 256) end
            if v4 then out[#out + 1] = string.char(v % 256) end
        end
        return table.concat(out)
    end
    local ok, res = pcall(function()
        local bytes = b64decode(ICON_B64)
        local name = "vez_chat_icon.png"
        local old = nil
        if type(isfile) == "function" and isfile(name) and type(readfile) == "function" then
            old = readfile(name)
        end
        if type(writefile) == "function" and old ~= bytes then writefile(name, bytes) end
        if type(getcustomasset) == "function" then return getcustomasset(name) end
        if type(getsynasset) == "function" then return getsynasset(name) end
        error("getcustomasset/getsynasset unavailable")
    end)
    local valid = ok and type(res) == "string"
        and (res:match("^rbxasset") ~= nil or res:match("^https?://") ~= nil or res:match("^file://") ~= nil)
    if valid then
        chatIconImage = res
        LOG("ui", "chat icon asset ready (%d b64 chars)", #ICON_B64)
    else
        LOG("ui", "chat icon failed (%s); keeping CHAT text", tostring(res))
    end
end

-- floating CHAT button: 42px rounded chip (smaller icon) + MOVABLE (drag, tap toggles panel)
local floatBtn = Instance.new("TextButton")
floatBtn.Name = "Chat pill"
floatBtn.Size = UDim2.new(0, FLOAT_SIZE, 0, FLOAT_SIZE)
floatBtn.Position = UDim2.new(1, -(FLOAT_SIZE + 10), 1, -140)
floatBtn.BackgroundColor3 = ICON_BG
floatBtn.Text = "CHAT"
floatBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
floatBtn.TextSize = 7
floatBtn.TextScaled = true
floatBtn.Font = Enum.Font.GothamBold
floatBtn.AutoButtonColor = true
floatBtn.Active = true
floatBtn.Visible = true
floatBtn.Parent = gui
Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(0, 18)
local floatPad = Instance.new("UIPadding")
floatPad.PaddingLeft = UDim.new(0, 2)
floatPad.PaddingRight = UDim.new(0, 2)
floatPad.PaddingTop = UDim.new(0, 2)
floatPad.PaddingBottom = UDim.new(0, 2)
floatPad.Parent = floatBtn
local floatStroke = Instance.new("UIStroke")
floatStroke.Color = Color3.fromRGB(255, 255, 255)
floatStroke.Transparency = 0.75
floatStroke.Thickness = 1
floatStroke.Parent = floatBtn

local unreadBadge = nil
if chatIconImage then
    floatBtn.Text = ""
    floatBtn.BackgroundTransparency = 0
    local chatIcon = Instance.new("ImageLabel")
    chatIcon.Name = "Icon"
    chatIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    chatIcon.Size = UDim2.fromScale(0.848, 0.848)
    chatIcon.Position = UDim2.fromScale(0.5, 0.5)
    chatIcon.BackgroundTransparency = 1
    chatIcon.Image = chatIconImage
    chatIcon.ScaleType = Enum.ScaleType.Fit
    chatIcon.Active = false
    chatIcon.ZIndex = 2
    chatIcon.Parent = floatBtn

    unreadBadge = Instance.new("TextLabel")
    unreadBadge.Name = "Unread"
    unreadBadge.AnchorPoint = Vector2.new(1, 0)
    unreadBadge.Position = UDim2.new(1, 0, 0, 0)
    unreadBadge.Size = UDim2.new(0, 12, 0, 12)
    unreadBadge.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
    unreadBadge.BorderSizePixel = 0
    unreadBadge.Text = ""
    unreadBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
    unreadBadge.Font = Enum.Font.GothamBold
    unreadBadge.TextScaled = true
    unreadBadge.Visible = false
    unreadBadge.ZIndex = 3
    unreadBadge.Parent = floatBtn
    Instance.new("UICorner", unreadBadge).CornerRadius = UDim.new(1, 0)

    -- if the local asset never actually renders, restore a visible CHAT pill
    task.delay(3, function()
        local loaded = false
        pcall(function() loaded = chatIcon.IsLoaded == true end)
        if not loaded and chatIcon.Parent then
            LOG("ui", "icon never loaded; switching pill back to CHAT text")
            chatIcon:Destroy()
            floatBtn.Text = "CHAT"
            floatBtn.BackgroundColor3 = ICON_BG
            floatBtn.BackgroundTransparency = 0
        end
    end)
end
LOG("ui", "floatBtn created size=%d (chip, movable, icon=%s)", FLOAT_SIZE, tostring(chatIconImage ~= nil))

local unread = 0
local topbarBadge = nil
local function refreshFloat()
    local countText = unread > 99 and "99+" or tostring(unread)
    local badge = unreadBadge or topbarBadge
    if unread > 0 then
        if badge then
            badge.Text = countText
            badge.Visible = true
        else
            floatBtn.Text = countText
            floatBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
        end
    else
        if badge then
            badge.Visible = false
        else
            floatBtn.Text = "CHAT"
            floatBtn.BackgroundColor3 = ICON_BG
        end
    end
end

-- ================= topbar slot overlay =================
-- The built-in chat button is kept (see hideDefaultChat) purely as the layout
-- host for our chip. We hide its artwork rather than the button itself so the
-- topbar keeps reserving the same space.
local topbarChip, topbarHost = nil, nil

local function getCoreGui()
    local cg = nil
    pcall(function() cg = game:GetService("CoreGui") end)
    if not cg then pcall(function() cg = game.CoreGui end) end
    return cg
end

local function isUnder(o, root)
    local node = o
    for _ = 1, 12 do
        if node == nil then return false end
        if node == root then return true end
        local ok, p = pcall(function() return node.Parent end)
        if not ok then return false end
        node = p
    end
    return false
end

local function objectImage(o)
    local ok, img = pcall(function() return o.Image end)
    if ok and type(img) == "string" then return img end
    return ""
end

local function scoreChatCandidate(o)
    local score = 0
    local name = ""
    pcall(function() name = o.Name end)
    name = tostring(name):lower()
    if name == "vezchattopbar" then return -100 end
    if name:find("chat", 1, true) then
        if name == "chat" or name == "chaticon" or name == "chatbutton" then
            score = score + 60
        else
            score = score + 30
        end
    end
    local img = objectImage(o):lower()
    if img:find("chat", 1, true) then score = score + 25 end
    local full = ""
    pcall(function() full = o:GetFullName():lower() end)
    if full:find("topbarapp", 1, true) then score = score + 3 end
    if full:find("leftframe", 1, true) then score = score + 5 end
    if full:find("friends", 1, true) or full:find("party", 1, true)
        or full:find("platform", 1, true) then
        score = score - 60
    end
    -- never mistake the (hidden) default chat window/input for the topbar button
    if full:find("chatwindow", 1, true) or full:find("chatinput", 1, true)
        or full:find("chatframe", 1, true) or full:find("chatbar", 1, true) then
        score = score - 80
    end
    return score
end

local function buttonFor(o, stopAt)
    local node = o
    for _ = 1, 6 do
        if node == nil or node == stopAt then break end
        local ok, isBtn = pcall(function() return node:IsA("GuiButton") end)
        if ok and isBtn then return node end
        local okp, p = pcall(function() return node.Parent end)
        if not okp then break end
        node = p
    end
    return o
end

local function visibleChain(o)
    local node = o
    for _ = 1, 12 do
        if node == nil then break end
        local ok, vis = pcall(function() return node.Visible end)
        if ok and vis == false then return false end
        local oken, en = pcall(function() return node.Enabled end)
        if oken and en == false then return false end
        local okp, p = pcall(function() return node.Parent end)
        if not okp then break end
        node = p
    end
    return true
end

local function scanChatHost(root, threshold, requireTopbarAncestry)
    local best, bestScore = nil, threshold
    local ok, list = pcall(function() return root:GetDescendants() end)
    if not ok or not list then return nil end
    for _, o in ipairs(list) do
        local okGui, isGui = pcall(function() return o:IsA("GuiObject") end)
        if okGui and isGui then
            local full = ""
            pcall(function() full = o:GetFullName():lower() end)
            local topbarish = full:find("topbar", 1, true) or full:find("unibar", 1, true)
                or full:find("chrome", 1, true) or full:find("experience", 1, true)
                or full:find("leftframe", 1, true) or full:find("hud", 1, true)
            if topbarish or not requireTopbarAncestry then
                local s = scoreChatCandidate(o)
                if s > 20 and visibleChain(o) then s = s + 40 end
                if s > bestScore then best, bestScore = o, s end
            end
        end
    end
    return best
end

local function findTopbarChatHost()
    local cg = getCoreGui()
    if not cg then return nil end
    local top = nil
    pcall(function() top = cg:FindFirstChild("TopBarApp") end)
    if top then
        local legacy = nil
        pcall(function()
            local tf = top:FindFirstChild("TopBarFrame")
            local lf = tf and tf:FindFirstChild("LeftFrame")
            legacy = lf and lf:FindFirstChild("ChatIcon")
        end)
        if legacy and legacy:IsA("GuiObject") then
            local cand = buttonFor(legacy, cg)
            if visibleChain(cand) then return cand end
        end
    end
    local best = top and scanChatHost(top, 20, false) or nil
    if not best then
        -- Some clients do not keep chat inside TopBarApp. Scan CoreGui too,
        -- but only under topbar/unibar/chrome-like ancestors so the hidden
        -- default chat window cannot be mistaken for the icon.
        best = scanChatHost(cg, 20, true)
    end
    if not best then return nil end
    return buttonFor(best, cg)
end

local function hideTopbarArt(host, chip)
    local function hideOne(o)
        if o == nil or o == chip then return end
        if isUnder(o, chip) then return end
        pcall(function()
            if o:IsA("ImageLabel") or o:IsA("ImageButton") then o.ImageTransparency = 1 end
            if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then o.TextTransparency = 1 end
            if o:IsA("Frame") or o:IsA("ScrollingFrame") or o:IsA("ViewportFrame") then
                o.BackgroundTransparency = 1
            end
            if o:IsA("UIStroke") then o.Transparency = 1 end
            -- our chip is the only click target; stop the built-in button from
            -- also opening/focusing its hidden chat UI when the slot is tapped
            if o:IsA("GuiButton") then
                o.Active = false
                pcall(function() o.Interactable = false end)
            end
            if o:IsA("GuiObject") then o.Selectable = false end
        end)
    end
    hideOne(host)
    local ok, list = pcall(function() return host:GetDescendants() end)
    if ok and list then
        for _, d in ipairs(list) do hideOne(d) end
    end
end

local function syncTopbarChipSize()
    if not (topbarChip and topbarHost) then return end
    local size = FLOAT_SIZE
    local ok, hs = pcall(function() return topbarHost.AbsoluteSize end)
    if ok and hs and hs.X and hs.Y then
        local m = math.min(FLOAT_SIZE, hs.X, hs.Y)
        if m >= 24 then size = math.floor(m + 0.5) end
    end
    local current = -1
    pcall(function() current = topbarChip.Size.X.Offset end)
    if current == size then return end
    topbarChip.Size = UDim2.fromOffset(size, size)
    local corner = topbarChip:FindFirstChildOfClass("UICorner")
    if corner then corner.CornerRadius = UDim.new(0, math.floor(size * 0.43)) end
end

local function buildTopbarChip()
    local chip = Instance.new("TextButton")
    chip.Name = "VEZChatTopbar"
    chip.AnchorPoint = Vector2.new(0.5, 0.5)
    chip.Position = UDim2.new(0.5, 0, 0.5, 0)
    chip.Size = UDim2.fromOffset(FLOAT_SIZE, FLOAT_SIZE)
    chip.BackgroundColor3 = ICON_BG
    chip.BackgroundTransparency = 0
    chip.BorderSizePixel = 0
    chip.Text = chatIconImage and "" or "CHAT"
    chip.TextColor3 = Color3.fromRGB(255, 255, 255)
    chip.TextSize = 7
    chip.TextScaled = true
    chip.Font = Enum.Font.GothamBold
    chip.AutoButtonColor = true
    chip.Active = true
    chip.Visible = true
    chip.ZIndex = 1000
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 18)
    corner.Parent = chip
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Transparency = 0.75
    stroke.Thickness = 1
    stroke.Parent = chip
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 2)
    pad.PaddingRight = UDim.new(0, 2)
    pad.PaddingTop = UDim.new(0, 2)
    pad.PaddingBottom = UDim.new(0, 2)
    pad.Parent = chip
    if chatIconImage then
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Size = UDim2.fromScale(0.848, 0.848)
        icon.Position = UDim2.fromScale(0.5, 0.5)
        icon.BackgroundTransparency = 1
        icon.Image = chatIconImage
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Active = false
        icon.ZIndex = 1001
        icon.Parent = chip
        task.delay(3, function()
            local loaded = false
            pcall(function() loaded = icon.IsLoaded == true end)
            if not loaded and icon.Parent then
                icon:Destroy()
                if chip.Parent then
                    chip.Text = "CHAT"
                    chip.BackgroundColor3 = ICON_BG
                end
            end
        end)
    end
    local badge = unreadBadge
    if not badge then
        badge = Instance.new("TextLabel")
        badge.Name = "Unread"
        badge.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
        badge.BorderSizePixel = 0
        badge.Text = ""
        badge.TextColor3 = Color3.fromRGB(255, 255, 255)
        badge.Font = Enum.Font.GothamBold
        badge.TextScaled = true
        badge.Visible = false
        topbarBadge = badge
        Instance.new("UICorner", badge).CornerRadius = UDim.new(1, 0)
    end
    badge.AnchorPoint = Vector2.new(1, 0)
    badge.Position = UDim2.new(1, 0, 0, 0)
    badge.Size = UDim2.new(0, 12, 0, 12)
    badge.ZIndex = 1002
    badge.Parent = chip
    chip.MouseButton1Click:Connect(function()
        main.Visible = not main.Visible
        LOG("ui", "topbar tapped -> panel visible=%s", tostring(main.Visible))
        if main.Visible then
            unread = 0
            refreshFloat()
            scrollMsgsBottom()
        end
    end)
    return chip
end

local function topbarAttached()
    if not (topbarChip and topbarHost) then return false end
    local ok1, cp = pcall(function() return topbarChip.Parent end)
    if not ok1 or cp ~= topbarHost then return false end
    local ok2, hp = pcall(function() return topbarHost.Parent end)
    return ok2 and hp ~= nil
end

local function detachTopbarChip()
    if topbarBadge then
        pcall(function() topbarBadge:Destroy() end)
        topbarBadge = nil
    end
    if unreadBadge then
        local okRep = pcall(function()
            unreadBadge.Parent = floatBtn
            unreadBadge.AnchorPoint = Vector2.new(1, 0)
            unreadBadge.Position = UDim2.new(1, 0, 0, 0)
            unreadBadge.Size = UDim2.new(0, 12, 0, 12)
            unreadBadge.ZIndex = 3
        end)
        local okP, parent = pcall(function() return unreadBadge.Parent end)
        if not okRep or not okP or parent ~= floatBtn then
            unreadBadge = nil
        end
    end
    if topbarChip then pcall(function() topbarChip:Destroy() end) end
    topbarChip, topbarHost = nil, nil
    floatBtn.Visible = true
    refreshFloat()
end

local function attachTopbarChip()
    if topbarChip and topbarHost then
        if topbarAttached() then
            syncTopbarChipSize()
            return true
        end
        detachTopbarChip()
    end
    local host = findTopbarChatHost()
    if not host then return false end
    local ok, err = pcall(function()
        local chip = buildTopbarChip()
        topbarChip, topbarHost = chip, host
        chip.Parent = host
        hideTopbarArt(host, chip)
        syncTopbarChipSize()
    end)
    if not ok then
        LOG("ui", "topbar chip attach failed: %s", tostring(err))
        detachTopbarChip()
        return false
    end
    task.defer(function() syncTopbarChipSize() end)
    floatBtn.Visible = not visibleChain(topbarHost)
    local full = "?"
    pcall(function() full = topbarHost:GetFullName() end)
    LOG("ui", "topbar chip attached to %s (pill visible=%s)",
        tostring(full), tostring(floatBtn.Visible))
    refreshFloat()
    return true
end

do
    if attachTopbarChip() then
        LOG("ui", "floating pill hidden (topbar slot active)")
    else
        LOG("ui", "topbar chat slot not found yet; floating pill active")
    end
end
task.spawn(function()
    local misses = 0
    while true do
        task.wait(2)
        if topbarAttached() then
            misses = 0
            syncTopbarChipSize()
            -- built-in chat may repaint its icon/badge; keep its art hidden
            hideTopbarArt(topbarHost, topbarChip)
            if topbarChip.ZIndex ~= 1000 then topbarChip.ZIndex = 1000 end
            -- if the topbar itself is hidden, keep the floating pill as fallback
            local showPill = not visibleChain(topbarHost)
            if floatBtn.Visible ~= showPill then floatBtn.Visible = showPill end
        else
            if topbarChip or topbarHost then
                LOG("ui", "topbar chip lost; falling back to floating pill")
                detachTopbarChip()
            end
            if misses < 30 then
                misses = misses + 1
                if attachTopbarChip() then
                    misses = 0
                    LOG("ui", "floating pill hidden (topbar slot active)")
                end
            end
            if misses == 30 then
                LOG("ui", "topbar chat slot unavailable after retries; keeping floating pill")
                misses = 31
            end
        end
    end
end)

-- viewport helper: read camera FRESH every call (old code cached it once -> bad clamp after rotation/resize)
local function viewport()
    local cam = nil
    pcall(function() cam = workspace.CurrentCamera end)
    if cam then return cam.ViewportSize end
    return Vector2.new(800, 600)
end

-- ================= movable PANEL (drag header, mouse + touch) =================
local function panelAbs()
    local vs = viewport()
    local p = main.Position
    return p.X.Scale * vs.X + p.X.Offset, p.Y.Scale * vs.Y + p.Y.Offset
end
local function clampPanelPos(ax, ay)
    local vs = viewport()
    local w, h = main.AbsoluteSize.X, main.AbsoluteSize.Y
    if w <= 0 then w = MIN_W end
    if h <= 0 then h = MIN_H end
    return UDim2.new(0, math.clamp(ax, 0, math.max(0, vs.X - w)),
        0, math.clamp(ay, 0, math.max(0, vs.Y - h)))
end
do
    local ax, ay = panelAbs()
    main.Position = clampPanelPos(ax, ay)
end
do
    local dragging, lastPos = false, nil
    -- grabs land on the tab buttons (they cover the header), so drag from them too
    local function beginDrag(input)
        if dragging then return end
        if locked then LOG("drag", "panel drag blocked (locked)") return end
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            dragging, lastPos = true, input.Position
            LOG("drag", "panel drag start")
        end
    end
    header.InputBegan:Connect(beginDrag)
    for _, tb in pairs(tabBtns) do
        tb.InputBegan:Connect(beginDrag)
    end
    UIS.InputChanged:Connect(function(input)
        local st = input.UserInputState
        if st == Enum.UserInputState.End or st == Enum.UserInputState.Cancel then
            if dragging then dragging = false LOG("drag", "panel drag end (cancel)") end
            return
        end
        if not dragging then return end
        local t ... (44 KB left)
