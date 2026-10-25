local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LP = Players.LocalPlayer
local Modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")

getgenv().AimbotEnabled = true
getgenv().AimbotFOV = 180
getgenv().AutoShoot = false
getgenv().ShootCooldown = 0
getgenv().ChamsEnabled = false
getgenv().ChamsTransparency = 0.3
getgenv().ChamsColor = Color3.fromRGB(0, 255, 255)
getgenv().HitboxExpand = false
getgenv().HitboxMultiplier = 2

-- new globals
getgenv().AimbotTeamCheck = false
getgenv().AimbotRequireVisible = false
getgenv().AimbotPriority = "Default"

getgenv().ESPEnabled = false
getgenv().ESPBox = true
getgenv().ESPName = true
getgenv().ESPHealth = true
getgenv().ESPDistance = true
getgenv().ESPSkeleton = false
getgenv().ESPTracer = false
getgenv().ESPHeadDot = true
getgenv().ESPTeamCheck = false
getgenv().ESPMaxDistance = 1000

getgenv().ShowFovCircle = false
getgenv().ShowCrosshair = false

-- silent aim
getgenv().SilentAimEnabled = false
getgenv().SilentAimFOV = 15
getgenv().SilentAimTarget = "Head"
getgenv().SilentAimTeamCheck = false

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library, ThemeManager, SaveManager, Window, Tabs, Toggles, Options, MainBox, VisualsBox, MenuGroup

task.spawn(function()
    local ok, a, b, c = pcall(function()
        return loadstring(game:HttpGet(repo .. "Library.lua"))(), loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))(), loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
    end)
    if not ok then return end
    Library, ThemeManager, SaveManager = a, b, c
    Window = Library:CreateWindow({ Title = "PIS - @DRR_R2", Footer = "Copyright (c) 2026 @DRR_R2", NotifySide = "Right" })
    Tabs = { Main = Window:AddTab("Aimbot", "crosshair"), Visuals = Window:AddTab("Visuals", "eye"), Settings = Window:AddTab("Settings", "settings") }

    MainBox = Tabs.Main:AddLeftGroupbox("Aim Assist", "target")
    MainBox:AddToggle("AimbotToggle", { Text = "Enable Aimbot", Default = true })
    MainBox:AddToggle("AutoShoot", { Text = "Auto Shoot", Default = false })
    MainBox:AddSlider("AimbotFOV", { Text = "Aimbot FOV", Default = 180, Min = 5, Max = 360, Rounding = 0, Suffix = "°" })
    MainBox:AddDivider("Filters")
    MainBox:AddToggle("TeamCheck", { Text = "Team Check", Default = false })
    MainBox:AddToggle("VisibleCheck", { Text = "Visible Check (LOS)", Default = false })
    MainBox:AddDropdown("AimbotPriority", { Text = "Target Priority", Values = { "Default", "Distance", "Lowest HP" }, Default = 1 })
    MainBox:AddDivider("Silent Aim")
    MainBox:AddToggle("SilentAimToggle", { Text = "Silent Aim", Default = false })
    MainBox:AddSlider("SilentAimFOV", { Text = "Silent Aim FOV", Default = 15, Min = 1, Max = 90, Rounding = 0, Suffix = "°" })
    MainBox:AddDropdown("SilentAimTarget", { Text = "Target Part", Values = { "Head", "Torso" }, Default = 1 })
    MainBox:AddToggle("SilentAimTeamCheck", { Text = "Silent Team Check", Default = false })
    MainBox:AddDivider("Info")
    MainBox:AddLabel("Friction: 1.0 | Tracking: 1.0 | Centering: 1.0", false)
    MainBox:AddLabel("Range: 99999 | Recoil: Disabled", false)

    local RightBox = Tabs.Main:AddRightGroupbox("Hitbox", "target")
    RightBox:AddToggle("HitboxToggle", { Text = "Hitbox Expander", Default = false })
    RightBox:AddSlider("HitboxSize", { Text = "Scale", Default = 2, Min = 1, Max = 5, Rounding = 1, Suffix = "x" })

    local FovBox = Tabs.Main:AddLeftGroupbox("Overlays", "eye")
    FovBox:AddToggle("ShowFovCircle", { Text = "FOV Circle", Default = false })
    FovBox:AddToggle("ShowCrosshair", { Text = "Crosshair Dot", Default = false })

    VisualsBox = Tabs.Visuals:AddLeftGroupbox("Chams (Lightweight)", "eye")
    VisualsBox:AddToggle("ChamsToggle", { Text = "Enable Chams", Default = false })
    VisualsBox:AddLabel("Chams Color"):AddColorPicker("ChamsColor", { Default = Color3.fromRGB(0, 255, 255), Title = "Chams Color" })
    VisualsBox:AddSlider("ChamsTransparency", { Text = "Transparency", Default = 0.3, Min = 0, Max = 1, Rounding = 2 })

    local EspBox = Tabs.Visuals:AddRightGroupbox("ESP (Drawing)", "eye")
    EspBox:AddToggle("ESPEnabled", { Text = "Enable ESP", Default = false })
    EspBox:AddToggle("ESPBox", { Text = "Box", Default = true })
    EspBox:AddToggle("ESPName", { Text = "Name", Default = true })
    EspBox:AddToggle("ESPHealth", { Text = "Health Bar", Default = true })
    EspBox:AddToggle("ESPDistance", { Text = "Distance", Default = true })
    EspBox:AddToggle("ESPHeadDot", { Text = "Head Dot", Default = true })
    EspBox:AddToggle("ESPSkeleton", { Text = "Skeleton", Default = false })
    EspBox:AddToggle("ESPTracer", { Text = "Tracer", Default = false })
    EspBox:AddToggle("ESPTeamCheck", { Text = "Team Check", Default = false })
    EspBox:AddSlider("ESPMaxDistance", { Text = "Max Distance", Default = 1000, Min = 50, Max = 5000, Rounding = 0, Suffix = "m" })

    Toggles, Options = Library.Toggles, Library.Options
    Toggles.AimbotToggle:OnChanged(function(v) getgenv().AimbotEnabled = v end)
    Options.AimbotFOV:OnChanged(function(v) getgenv().AimbotFOV = v end)
    Toggles.AutoShoot:OnChanged(function(v) getgenv().AutoShoot = v end)
    Toggles.TeamCheck:OnChanged(function(v) getgenv().AimbotTeamCheck = v end)
    Toggles.VisibleCheck:OnChanged(function(v) getgenv().AimbotRequireVisible = v end)
    Options.AimbotPriority:OnChanged(function(v) getgenv().AimbotPriority = v end)
    Toggles.SilentAimToggle:OnChanged(function(v) getgenv().SilentAimEnabled = v end)
    Options.SilentAimFOV:OnChanged(function(v) getgenv().SilentAimFOV = v end)
    Options.SilentAimTarget:OnChanged(function(v) getgenv().SilentAimTarget = v end)
    Toggles.SilentAimTeamCheck:OnChanged(function(v) getgenv().SilentAimTeamCheck = v end)
    Toggles.HitboxToggle:OnChanged(function(v) getgenv().HitboxExpand = v end)
    Options.HitboxSize:OnChanged(function(v) getgenv().HitboxMultiplier = v end)
    Toggles.ShowFovCircle:OnChanged(function(v) getgenv().ShowFovCircle = v end)
    Toggles.ShowCrosshair:OnChanged(function(v) getgenv().ShowCrosshair = v end)

    Toggles.ChamsToggle:OnChanged(function(v) getgenv().ChamsEnabled = v end)
    Options.ChamsTransparency:OnChanged(function(v) getgenv().ChamsTransparency = v end)
    Options.ChamsColor:OnChanged(function(v) getgenv().ChamsColor = v end)

    Toggles.ESPEnabled:OnChanged(function(v) getgenv().ESPEnabled = v end)
    Toggles.ESPBox:OnChanged(function(v) getgenv().ESPBox = v end)
    Toggles.ESPName:OnChanged(function(v) getgenv().ESPName = v end)
    Toggles.ESPHealth:OnChanged(function(v) getgenv().ESPHealth = v end)
    Toggles.ESPDistance:OnChanged(function(v) getgenv().ESPDistance = v end)
    Toggles.ESPHeadDot:OnChanged(function(v) getgenv().ESPHeadDot = v end)
    Toggles.ESPSkeleton:OnChanged(function(v) getgenv().ESPSkeleton = v end)
    Toggles.ESPTracer:OnChanged(function(v) getgenv().ESPTracer = v end)
    Toggles.ESPTeamCheck:OnChanged(function(v) getgenv().ESPTeamCheck = v end)
    Options.ESPMaxDistance:OnChanged(function(v) getgenv().ESPMaxDistance = v end)

    ThemeManager:SetLibrary(Library)
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
    ThemeManager:ApplyToTab(Tabs.Settings)
    SaveManager:BuildConfigSection(Tabs.Settings)
    MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu", "wrench")
    MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
    Library.ToggleKeybind = Options.MenuKeybind
    SaveManager:LoadAutoloadConfig()
    Library:OnUnload(function()
        getgenv().AimbotEnabled = false; getgenv().AutoShoot = false
        getgenv().ChamsEnabled = false; getgenv().ESPEnabled = false
        getgenv().ShowFovCircle = false; getgenv().ShowCrosshair = false
        getgenv().SilentAimEnabled = false
        resetAllHitboxes()
    end)
end)

repeat task.wait() until LP:FindFirstChild("PlayerData") and LP:FindFirstChild("PlayerDataLoaded")

local AAEnum = require(Modules.AimAssistController.AimAssistEnum)
local AAC = require(Modules.AimAssistController)

local oldGamepad = AAC.getGamepadEligibility
AAC.getGamepadEligibility = function(self, ...)
    if getgenv().AimbotEnabled then return true end
    return oldGamepad(self, ...)
end

local oldTouch = AAC.getTouchEligibility
AAC.getTouchEligibility = function(self, ...)
    if getgenv().AimbotEnabled then return true end
    return oldTouch(self, ...)
end

local AAMod = require(Modules.AimAssistController.AimAdjuster)
local oldAdjustAim = AAMod.adjustAim
AAMod.adjustAim = function(self, data)
    if getgenv().AimbotEnabled then
        self.strengthTable[AAEnum.AimAssistMethod.Friction] = 1.0
        self.strengthTable[AAEnum.AimAssistMethod.Tracking] = 1.0
        self.strengthTable[AAEnum.AimAssistMethod.Centering] = 1.0
        data.adjustmentStrength = 1.0
    end
    return oldAdjustAim(self, data)
end

-- ===== DEAD TARGET FILTER + TEAM/LOS/priority =====
local DeadFolders = {
    workspace:FindFirstChild("Ragdolls"),
    workspace:FindFirstChild("DeadBodies"),
}

local function resolveChar(target)
    if target == nil then return nil end
    if type(target) == "table" then
        local c = target.Character or target.character
            or target.Model or target.model
            or target.Instance or target.instance
            or target.Part or target.part
        if c ~= nil and c ~= target then
            local r = resolveChar(c)
            if r then return r end
        end
        return nil
    end
    if typeof(target) ~= "Instance" then return nil end
    if target:IsA("Model") then return target end
    if target:IsA("BasePart") then return target:FindFirstAncestorOfClass("Model") end
    local p = target.Parent
    while p and not p:IsA("Model") do p = p.Parent end
    return p
end

local function hasLineOfSight(char)
    if not getgenv().AimbotRequireVisible then return true end
    local cam = workspace.CurrentCamera
    local target = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if not target then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = { LP.Character }
    local r = workspace:Raycast(cam.CFrame.Position, target.Position - cam.CFrame.Position, params)
    if not r then return false end
    return r.Instance:IsDescendantOf(char)
end

local function isLiveTarget(target)
    local model = resolveChar(target)
    if not model then return false end
    for _, f in ipairs(DeadFolders) do
        if f and model:IsDescendantOf(f) then return false end
    end
    local plr = Players:GetPlayerFromCharacter(model)
    if not plr or plr == LP then return false end
    if plr.Character ~= model then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if getgenv().AimbotTeamCheck and LP.Team and plr.Team == LP.Team then return false end
    if not hasLineOfSight(model) then return false end
    return true
end

local function sortByPriority(list)
    local p = getgenv().AimbotPriority
    if p == "Default" or #list < 2 then return list end
    local camPos = workspace.CurrentCamera.CFrame.Position
    table.sort(list, function(a, b)
        local ma, mb = resolveChar(a), resolveChar(b)
        if not ma then return false end
        if not mb then return true end
        local ha = ma:FindFirstChild("HumanoidRootPart")
        local hb = mb:FindFirstChild("HumanoidRootPart")
        if not ha then return false end
        if not hb then return true end
        if p == "Distance" then
            return (camPos - ha.Position).Magnitude < (camPos - hb.Position).Magnitude
        elseif p == "Lowest HP" then
            local hua = ma:FindFirstChildOfClass("Humanoid")
            local hub = mb:FindFirstChildOfClass("Humanoid")
            if not hua then return false end
            if not hub then return true end
            return hua.Health < hub.Health
        end
        return false
    end)
    return list
end

local TSMod = require(Modules.AimAssistController.TargetSelector)

local oldTSNew = TSMod.new
TSMod.new = function(...)
    local self = oldTSNew(...)
    self.fieldOfView = getgenv().AimbotFOV
    self.range = 99999
    self.ignoreLineOfSight = true
    if type(self.validTargets) == "function" then
        local oldVT = self.validTargets
        self.validTargets = function(self2, ...)
            local list = oldVT(self2, ...)
            if type(list) == "table" and getgenv().AimbotEnabled then
                local filtered = {}
                for _, v in ipairs(list) do
                    if isLiveTarget(v) then table.insert(filtered, v) end
                end
                return sortByPriority(filtered)
            end
            return list
        end
    end
    return self
end

local oldSetFOV = TSMod.setFieldOfView
TSMod.setFieldOfView = function(self, fov)
    if getgenv().AimbotEnabled then return oldSetFOV(self, getgenv().AimbotFOV) end
    return oldSetFOV(self, fov)
end

local oldSetRange = TSMod.setRange
TSMod.setRange = function(self, range)
    if getgenv().AimbotEnabled then return oldSetRange(self, 99999) end
    return oldSetRange(self, range)
end

local oldSetMethodStrength = AAC.setMethodStrength
AAC.setMethodStrength = function(self, method, strength)
    if getgenv().AimbotEnabled then return oldSetMethodStrength(self, method, 1.0) end
    return oldSetMethodStrength(self, method, strength)
end

local oldSelectTarget = TSMod.selectTarget
TSMod.selectTarget = function(self, subject)
    if getgenv().AimbotEnabled then self.fieldOfView = getgenv().AimbotFOV end
    local target = oldSelectTarget(self, subject)
    if target ~= nil and not isLiveTarget(target) then return nil end
    return target
end

-- ===== PlayerData / sensitivity =====
local pd = LP.PlayerData
local aaGP = pd:WaitForChild("AimAssist_Gamepad")
local aaTouch = pd:WaitForChild("AimAssist_Touch")
aaGP.Value = true
aaTouch.Value = true

RunService.RenderStepped:Connect(function()
    pcall(function()
        if getgenv().AimbotEnabled then
            if aaGP and not aaGP.Value then aaGP.Value = true end
            if aaTouch and not aaTouch.Value then aaTouch.Value = true end
        end
    end)
end)

local camM = pd:WaitForChild("CameraSensitivity_Mouse")
local camG = pd:WaitForChild("CameraSensitivity_Gamepad")
local camT = pd:WaitForChild("CameraSensitivity_Touch")
local aimM = pd:WaitForChild("AimSensitivity_Mouse")
local aimG = pd:WaitForChild("AimSensitivity_Gamepad")
local aimT = pd:WaitForChild("AimSensitivity_Touch")

camM.Value = 5; camG.Value = 5; camT.Value = 5
aimM.Value = 6; aimG.Value = 6; aimT.Value = 6

RunService.RenderStepped:Connect(function()
    pcall(function()
        if getgenv().AimbotEnabled then
            if camM and camM.Value ~= 5 then camM.Value = 5 end
            if aimM and aimM.Value ~= 6 then aimM.Value = 6 end
        end
    end)
end)

local CRMod = Modules:FindFirstChild("CameraRecoiler")
if CRMod then
    local cr = require(CRMod)
    if cr then
        for k, v in pairs(cr) do
            if type(v) == "function" then cr[k] = function() end end
        end
    end
end

-- ===== Refs =====
local RS = game:GetService("ReplicatedStorage")
local Events = RS:WaitForChild("Events"):WaitForChild("RemoteEvents")
local ReplicateFakeBullet = Events:WaitForChild("ReplicateFakeBullet")
local CharMuzzleFlash = Events:WaitForChild("CharacterMuzzleFlash")
local SysRes = RS:FindFirstChild("SystemResources")
local hiddenRemote
if SysRes then
    local buf = SysRes:FindFirstChild("BufferCache")
    if buf then hiddenRemote = buf:FindFirstChild("RequestActionSync") end
end
if not hiddenRemote then hiddenRemote = Events:WaitForChild("ReplicateFakeBullet") end

-- ===== Silent Aim =====
local function findSilentAimTarget(origin, currentDir)
    local bestTarget, bestScore = nil, math.huge
    local maxAngle = math.rad((getgenv().SilentAimFOV or 15) / 2)
    local maxDist = 1000
    local preferHead = (getgenv().SilentAimTarget or "Head") == "Head"

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        if getgenv().SilentAimTeamCheck and LP.Team and plr.Team == LP.Team then continue end
        local char = plr.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        local isDead = false
        for _, f in ipairs(DeadFolders) do
            if f and char:IsDescendantOf(f) then isDead = true; break end
        end
        if isDead then continue end

        local targetPart = preferHead and char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        if not targetPart then continue end

        local toTarget = targetPart.Position - origin
        local dist = toTarget.Magnitude
        if dist > maxDist or dist < 0.1 then continue end

        local dot = math.clamp(currentDir:Dot(toTarget.Unit), -1, 1)
        local angle = math.acos(dot)
        if angle <= maxAngle and angle < bestScore then
            bestScore = angle
            bestTarget = {
                pos = targetPart.Position,
                instance = targetPart,
                hum = hum,
                isHead = (targetPart.Name == "Head"),
            }
        end
    end
    return bestTarget
end

local saOk, saMt = pcall(getrawmetatable, game)
if saOk and saMt and getnamecallmethod and setreadonly and newcclosure then
    local oldNamecall = saMt.__namecall
    pcall(setreadonly, saMt, false)
    saMt.__namecall = newcclosure(function(self, ...)
        if getnamecallmethod() == "FireServer" and getgenv().SilentAimEnabled and self == hiddenRemote then
            local args = { ... }
            local payload = args[1]
            if type(payload) == "table" and typeof(payload.origin) == "Vector3" and typeof(payload.direction) == "Vector3" then
                local target = findSilentAimTarget(payload.origin, payload.direction.Unit)
                if target then
                    local newVec = target.pos - payload.origin
                    payload.direction = newVec.Unit * payload.direction.Magnitude
                    payload.hitPosition = target.pos
                    payload.hitInstance = target.instance
                    payload.hitHumanoid = target.hum
                    payload.IsHeadshot = target.isHead
                end
            end
            return oldNamecall(self, table.unpack(args))
        end
        return oldNamecall(self, ...)
    end)
    pcall(setreadonly, saMt, true)
end

local BulletTracer = require(Modules:WaitForChild("BulletTracer"))
local CameraRecoiler = require(Modules:WaitForChild("CameraRecoiler"))
local Assets = RS:WaitForChild("Assets")
local BulletImpactEffect = Assets:WaitForChild("BulletImpactEffect")
local Effects = workspace:WaitForChild("Effects")
local Debris = game:GetService("Debris")

local function emitMuzzleFlash(vm)
    local att = vm:FindFirstChild("WeaponAttachment")
    if not att then return end
    local muzzle = att:FindFirstChild("MuzzleAttachment")
    if not muzzle then return end
    for _, child in pairs(muzzle:GetChildren()) do
        if child:IsA("ParticleEmitter") and child:GetAttribute("EmitCount") then child:Emit(child:GetAttribute("EmitCount")) end
    end
end

local function createImpactEffect(pos, color)
    local effect = BulletImpactEffect:Clone()
    effect.Position = pos
    effect.Parent = Effects
    for _, child in pairs(effect:GetChildren()) do
        if child:IsA("Sound") then child:Play()
        elseif child:IsA("ParticleEmitter") then
            if child.Name == "Debris" and color then child.Color = ColorSequence.new(color) end
            child:Emit(child:GetAttribute("EmitCount"))
        end
    end
    Debris:AddItem(effect, 3)
end

-- ===== Auto-shoot =====
task.spawn(function()
    while task.wait() do
        pcall(function()
            if not getgenv().AimbotEnabled or not getgenv().AutoShoot then return end
            if getgenv().ShootCooldown > tick() then return end
            local cam = workspace.CurrentCamera
            if not cam then return end
            local char = LP.Character
            if not char then return end
            local hum = char:FindFirstChild("Humanoid")
            if not hum or hum.Health <= 0 then return end
            local tool = char:FindFirstChildOfClass("Tool")
            if not tool then return end
            local vm = cam:FindFirstChild("Viewmodel")
            if not vm then return end
            local origin = cam.CFrame.Position
            local direction = cam.CFrame.LookVector
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Blacklist
            local filterList = { char }
            local rag = workspace:FindFirstChild("Ragdolls")
            if rag then table.insert(filterList, rag) end
            if Effects then table.insert(filterList, Effects) end
            params.FilterDescendantsInstances = filterList
            local result = workspace:Raycast(origin, direction * 1000, params)
            if not result then return end
            local hitParent = result.Instance:FindFirstAncestorOfClass("Model")
            if not hitParent then return end
            local hitHum = hitParent:FindFirstChildOfClass("Humanoid")
            if not hitHum or hitHum.Health <= 0 then return end
            local hitPlr = Players:GetPlayerFromCharacter(hitParent)
            if not hitPlr or hitPlr == LP then return end
            if getgenv().AimbotTeamCheck and LP.Team and hitPlr.Team == LP.Team then return end
            local isHeadshot = (result.Instance.Name == "Head" or result.Instance.Name == "HeadHitbox")
            local hitPos = result.Position
            local wc = require(Modules.WeaponConfig)
            local weaponRange = wc.WeaponStats.Range
            local weaponAtt = vm:FindFirstChild("WeaponAttachment")
            local muzzle = weaponAtt and weaponAtt:FindFirstChild("MuzzleAttachment")
            local muzzleCF = muzzle and muzzle.WorldCFrame
            local aimDir = direction
            if muzzleCF then
                aimDir = (hitPos - muzzleCF.Position).Unit
                if aimDir:Dot(direction) < 0.5 then aimDir = direction end
            end
            hiddenRemote:FireServer({ origin = origin, direction = aimDir * weaponRange, hitPosition = hitPos, hitInstance = result.Instance, hitHumanoid = hitHum, IsHeadshot = isHeadshot })
            if muzzleCF then
                pcall(ReplicateFakeBullet.FireServer, ReplicateFakeBullet, muzzleCF, aimDir)
                pcall(BulletTracer.Create, BulletTracer, muzzleCF, aimDir, 0.5)
            end
            emitMuzzleFlash(vm)
            pcall(CharMuzzleFlash.FireServer, CharMuzzleFlash)
            local recoil = wc.RecoilAmount or Vector2.new(0.1, 0.3)
            if math.random(1, 2) == 1 then recoil = Vector2.new(-recoil.X, recoil.Y) end
            pcall(CameraRecoiler.recoil, CameraRecoiler, recoil)
            local handle = tool:FindFirstChild("Handle")
            if handle then
                local sounds = handle:FindFirstChild("Sounds")
                if sounds then
                    local shootSound = sounds:FindFirstChild("Shoot")
                    if shootSound and handle:FindFirstChild("MuzzleAttachment") then
                        local s = shootSound:Clone()
                        s.Parent = handle; s:Play()
                        Debris:AddItem(s, s.TimeLength + 1)
                    end
                end
            end
            createImpactEffect(hitPos, result.Instance:IsA("BasePart") and result.Instance.Color or nil)
            getgenv().ShootCooldown = tick() + wc.WeaponStats.ReloadDuration
        end)
    end
end)

-- ===== Lightweight Highlight Chams =====
local hlCache = {}

RunService.RenderStepped:Connect(function()
    pcall(function()
        if not getgenv().ChamsEnabled then
            for plr, hl in pairs(hlCache) do hl:Destroy(); hlCache[plr] = nil end
            return
        end
        local col = getgenv().ChamsColor
        local tr = getgenv().ChamsTransparency
        local seen = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LP then continue end
            local c = p.Character
            if not c then continue end
            local h = c:FindFirstChildOfClass("Humanoid")
            if not h or h.Health <= 0 then continue end
            seen[p] = true
            local hl = hlCache[p]
            if not hl or not hl.Parent then
                hl = Instance.new("Highlight")
                hl.Name = "PIS_Chams"
                hl.Parent = c
                hlCache[p] = hl
            end
            hl.Adornee = c
            hl.Enabled = true
            hl.FillColor = col
            hl.FillTransparency = tr
            hl.OutlineColor = col
            hl.OutlineTransparency = 0.3
        end
        for p, hl in pairs(hlCache) do
            if not seen[p] then hl:Destroy(); hlCache[p] = nil end
        end
    end)
end)

-- ===== Drawing-based ESP =====
local hasDrawing = pcall(function()
    local t = Drawing.new("Text"); t:Remove()
end)

local espCache = {}

local function destroyEsp(plr)
    local t = espCache[plr]
    if not t then return end
    for k, v in pairs(t) do
        if k == "skeletonLines" then
            for _, line in ipairs(v) do pcall(function() line:Remove() end) end
        else
            pcall(function() v:Remove() end)
        end
    end
    espCache[plr] = nil
end

local function getEsp(plr)
    if espCache[plr] then return espCache[plr] end
    local t = {
        box = Drawing.new("Square"),
        name = Drawing.new("Text"),
        healthBg = Drawing.new("Square"),
        healthFg = Drawing.new("Square"),
        dist = Drawing.new("Text"),
        tracer = Drawing.new("Line"),
        headDot = Drawing.new("Square"),
        skeletonLines = {},
    }
    t.box.Filled = false
    t.box.Thickness = 1
    t.name.Center = true; t.name.Outline = true; t.name.Size = 14
    t.healthBg.Filled = true
    t.healthFg.Filled = true
    t.dist.Center = true; t.dist.Outline = true; t.dist.Size = 12
    t.headDot.Filled = true; t.headDot.Size = Vector2.new(4, 4)
    for i = 1, 5 do
        local line = Drawing.new("Line")
        line.Thickness = 1
        t.skeletonLines[i] = line
    end
    espCache[plr] = t
    return t
end

Players.PlayerRemoving:Connect(function(plr)
    if espCache[plr] then destroyEsp(plr) end
end)

RunService.RenderStepped:Connect(function()
    pcall(function()
        if not getgenv().ESPEnabled or not hasDrawing then
            if next(espCache) then
                for plr in pairs(espCache) do destroyEsp(plr) end
            end
            return
        end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local vp = cam.ViewportSize
        local col = Color3.fromRGB(0, 255, 255)
        local maxDist = getgenv().ESPMaxDistance or 1000

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LP then continue end
            local char = plr.Character
            if not char then destroyEsp(plr); continue end
            if getgenv().ESPTeamCheck and LP.Team and plr.Team == LP.Team then destroyEsp(plr); continue end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then destroyEsp(plr); continue end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("Head")
            if not hrp or not head then destroyEsp(plr); continue end

            local dist = (cam.CFrame.Position - hrp.Position).Magnitude
            if dist > maxDist then destroyEsp(plr); continue end

            local ok, cf, size = pcall(function() return char:GetBoundingBox() end)
            if not ok then destroyEsp(plr); continue end

            local sx, sy, ex, ey = math.huge, math.huge, -math.huge, -math.huge
            local anyOnScreen = false
            for ix = -1, 1, 2 do
                for iy = -1, 1, 2 do
                    for iz = -1, 1, 2 do
                        local wp = (cf * CFrame.new(ix * size.X / 2, iy * size.Y / 2, iz * size.Z / 2)).Position
                        local sp, os = cam:WorldToViewportPoint(wp)
                        if os then
                            anyOnScreen = true
                            if sp.X < sx then sx = sp.X end
                            if sp.Y < sy then sy = sp.Y end
                            if sp.X > ex then ex = sp.X end
                            if sp.Y > ey then ey = sp.Y end
                        end
                    end
                end
            end
            if not anyOnScreen or ex < sx or ey < sy then destroyEsp(plr); continue end

            local t = getEsp(plr)

            t.box.Visible = getgenv().ESPBox
            if getgenv().ESPBox then
                t.box.Size = Vector2.new(ex - sx, ey - sy)
                t.box.Position = Vector2.new(sx, sy)
                t.box.Color = col
            end

            t.name.Visible = getgenv().ESPName
            if getgenv().ESPName then
                t.name.Text = plr.Name
                t.name.Color = col
                t.name.Position = Vector2.new((sx + ex) / 2, sy - 16)
            end

            if getgenv().ESPHealth then
                t.healthBg.Visible = true
                t.healthFg.Visible = true
                local hbH = ey - sy
                local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                t.healthBg.Size = Vector2.new(3, hbH)
                t.healthBg.Position = Vector2.new(sx - 6, sy)
                t.healthBg.Color = Color3.new(0, 0, 0)
                local fgH = hbH * pct
                t.healthFg.Size = Vector2.new(3, fgH)
                t.healthFg.Position = Vector2.new(sx - 6, sy + (hbH - fgH))
                t.healthFg.Color = Color3.fromRGB(255, 0, 0):Lerp(Color3.fromRGB(0, 255, 0), pct)
            else
                t.healthBg.Visible = false
                t.healthFg.Visible = false
            end

            t.dist.Visible = getgenv().ESPDistance
            if getgenv().ESPDistance then
                t.dist.Text = tostring(math.floor(dist)) .. "m"
                t.dist.Color = col
                t.dist.Position = Vector2.new((sx + ex) / 2, ey + 2)
            end

            t.headDot.Visible = getgenv().ESPHeadDot
            if getgenv().ESPHeadDot then
                local hp, hos = cam:WorldToViewportPoint(head.Position)
                if hos then
                    t.headDot.Position = Vector2.new(hp.X - 2, hp.Y - 2)
                    t.headDot.Color = col
                else
                    t.headDot.Visible = false
                end
            end

            t.tracer.Visible = getgenv().ESPTracer
            if getgenv().ESPTracer then
                t.tracer.From = Vector2.new(vp.X / 2, vp.Y)
                t.tracer.To = Vector2.new((sx + ex) / 2, ey)
                t.tracer.Color = col
            end

            if getgenv().ESPSkeleton then
                local parts = {
                    head = head,
                    root = hrp,
                    la = char:FindFirstChild("LeftUpperArm") or char:FindFirstChild("Left Arm"),
                    ra = char:FindFirstChild("RightUpperArm") or char:FindFirstChild("Right Arm"),
                    ll = char:FindFirstChild("LeftUpperLeg") or char:FindFirstChild("Left Leg"),
                    rl = char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg"),
                }
                local conns = {
                    {parts.head, parts.root},
                    {parts.root, parts.la},
                    {parts.root, parts.ra},
                    {parts.root, parts.ll},
                    {parts.root, parts.rl},
                }
                for i, line in ipairs(t.skeletonLines) do
                    local c = conns[i]
                    if c and c[1] and c[2] then
                        local p1, o1 = cam:WorldToViewportPoint(c[1].Position)
                        local p2, o2 = cam:WorldToViewportPoint(c[2].Position)
                        if o1 and o2 then
                            line.Visible = true
                            line.From = Vector2.new(p1.X, p1.Y)
                            line.To = Vector2.new(p2.X, p2.Y)
                            line.Color = col
                        else
                            line.Visible = false
                        end
                    else
                        line.Visible = false
                    end
                end
            else
                for _, line in ipairs(t.skeletonLines) do line.Visible = false end
            end
        end
    end)
end)

-- ===== FOV Circle + Crosshair =====
local fovCircle = nil
local crosshair = nil

RunService.RenderStepped:Connect(function()
    pcall(function()
        if not hasDrawing then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local vp = cam.ViewportSize

        if getgenv().ShowFovCircle then
            if not fovCircle then
                local ok, c = pcall(function() return Drawing.new("Circle") end)
                if ok then
                    fovCircle = c
                    fovCircle.Thickness = 1
                    fovCircle.Filled = false
                    pcall(function() fovCircle.NumSides = 64 end)
                end
            end
            if fovCircle then
                local halfFovRad = math.min(math.rad(getgenv().AimbotFOV / 2), math.rad(89))
                local radius = math.tan(halfFovRad) / math.tan(math.rad(cam.FieldOfView / 2)) * (vp.Y / 2)
                radius = math.min(radius, vp.Y * 3)
                fovCircle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
                fovCircle.Radius = radius
                fovCircle.Color = Color3.fromRGB(0, 255, 255)
                fovCircle.Visible = true
            end
        elseif fovCircle then
            fovCircle.Visible = false
        end

        if getgenv().ShowCrosshair then
            if not crosshair then
                crosshair = Drawing.new("Square")
                crosshair.Filled = true
                crosshair.Size = Vector2.new(4, 4)
                crosshair.Color = Color3.fromRGB(0, 255, 255)
            end
            crosshair.Position = Vector2.new(vp.X / 2 - 2, vp.Y / 2 - 2)
            crosshair.Visible = true
        elseif crosshair then
            crosshair.Visible = false
        end
    end)
end)

-- ===== Hitbox Expander =====
local origSizes = {}
local hbParts = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "HumanoidRootPart" }

local function resetAllHitboxes()
    for pt, sz in pairs(origSizes) do pcall(function() pt.Size = sz end) end
    origSizes = {}
end

RunService.RenderStepped:Connect(function()
    pcall(function()
        local enabled = getgenv().HitboxExpand
        local mult = getgenv().HitboxMultiplier or 2
        if not enabled then
            if next(origSizes) then resetAllHitboxes() end
            return
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LP then continue end
            local c = p.Character
            if not c then continue end
            local hum = c:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            for _, n in ipairs(hbParts) do
                local pt = c:FindFirstChild(n)
                if pt and pt:IsA("BasePart") then
                    if not origSizes[pt] then origSizes[pt] = pt.Size end
                    pt.Size = origSizes[pt] * mult
                    pt.CanCollide = false
                end
            end
        end
    end)
end)
