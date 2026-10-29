--[[
    ================================================================================
    🐾 KAITUN BOT v9.0 — THROW FOOD FOR ANIMALS (CENTER UI & CLEAN DISPLAY)
    ================================================================================
    Place ID    : 120219252362013
    File Name   : kaitun_bot9.lua (เวอร์ชัน 9.0 แยกไฟล์ใหม่ ไม่เขียนทับไฟล์เดิม)
    
    🎯 ฟีเจอร์ใหม่และการปรับปรุงใน v9.0:
      1. 🎯 จัดตำแหน่ง UI ให้อยู่ตรงกลางจอทันทีที่รันสคริปต์ (Center Screen Spawn):
         - วางตำแหน่ง `Position = UDim2.new(0.5, -215, 0.5, -70)` กึ่งกลางหน้าจอพอดี
         - รองรับการลากย้ายตำแหน่งได้อย่างอิสระ (Draggable)
       
      2. 🏷️ เปลี่ยนชื่อแถวบนสุดของ UI เป็น:
         - `Throw Food For Animals - Kaitun`
       
      3. 🚫 ลบ/ซ่อนปุ่มวงกลมโบนัส Tap Bonus (👉 x2) ออกจากหน้าจอ 100%:
         - ตัวบอททำการเคลมโบนัส Tap Bonus ผ่าน Remote (0ms) อัตโนมัติอยู่แล้ว
         - จึงทำการซ่อน `TapBonusLayer` และ `TapBonus` ให้หน้าจอสะอาด ไร้ปุ่มรบกวนสายตา
       
      4. 🏋️ การโหนบาร์ & ลำดับความสำคัญในการอัปเกรด (คงความสมบูรณ์แบบจาก v8.0):
         - ขณะโหนบาร์: ปล่อยมือลงมาเฉพาะตอน "บาร์ (Stand)" อัปเกรดได้เท่านั้น แล้วกลับไปโหนต่อทันที
         - นอกบาร์/ก่อนปา: อัปเกรดเป็นอันดับแรกเสมอ (1. บาร์ -> 2. อาหาร -> 3. ฐาน)
         - ซื้ออาหารด้วย Integer Index ที่ถูกต้อง ปลอดภัย ไม่วนลูป
         - สวมสัตว์ที่ดีที่สุดลงแปลงก่อนขาย (Equip Best Before Sell All)
       
      5. 📢 ระบบพิมพ์รายงานสดบน /console (F9):
         - แสดง "กำลังทำ", "ถัดไป", พลัง, ด่าน, เงิน และผลการทำงานอย่างละเอียด
    ================================================================================
]]

--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
assert(LocalPlayer, "LocalPlayer not found!")

--// ---------------------------------------------------------------------------
--// WAIT FOR REMOTES & PLAYER DATA
--// ---------------------------------------------------------------------------
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 30)
assert(RemotesFolder, "Remotes folder not found in ReplicatedStorage!")

local PlayerDataFolder = ReplicatedStorage:WaitForChild("PlayerData", 30)
local PlayerData = PlayerDataFolder:WaitForChild(tostring(LocalPlayer.UserId), 60)
assert(PlayerData, "PlayerData for LocalPlayer not found!")

--// Remotes Lookup
local Remotes = {
    Throw_Start = RemotesFolder:WaitForChild("Throw_Start"),
    Throw_Resolve = RemotesFolder:WaitForChild("Throw_Resolve"),
    Throw_Complete = RemotesFolder:WaitForChild("Throw_Complete"),
    Throw_Cancel = RemotesFolder:WaitForChild("Throw_Cancel"),
    Throw_UseSuper = RemotesFolder:WaitForChild("Throw_UseSuper"),
    Training_Start = RemotesFolder:WaitForChild("Training_Start"),
    Training_Stop = RemotesFolder:WaitForChild("Training_Stop"),
    Training_TapBonus = RemotesFolder:WaitForChild("Training_TapBonus"),
    Training_Bonus = RemotesFolder:WaitForChild("Training_Bonus"),
    Stand_Upgrade = RemotesFolder:WaitForChild("Stand_Upgrade"),
    Plot_UpgradeFence = RemotesFolder:WaitForChild("Plot_UpgradeFence"),
    Plot_EquipBest = RemotesFolder:WaitForChild("Plot_EquipBest"),
    Plot_SellAll = RemotesFolder:WaitForChild("Plot_SellAll"),
    Shop_Buy = RemotesFolder:WaitForChild("Shop_Buy"),
    Shop_Equip = RemotesFolder:WaitForChild("Shop_Equip"),
    Shop_ClaimFree = RemotesFolder:WaitForChild("Shop_ClaimFree"),
    Offline_Claim = RemotesFolder:WaitForChild("Offline_Claim")
}

--// Configs Lookup
local AnimalEconomy = nil
pcall(function()
    AnimalEconomy = require(ReplicatedStorage.Config.AnimalEconomy)
end)

local FenceConfig = nil
pcall(function()
    FenceConfig = require(ReplicatedStorage.Config.FenceConfig)
end)

local FoodsConfig = nil
pcall(function()
    FoodsConfig = require(ReplicatedStorage.Config.FoodsConfig)
end)

local StandsConfig = nil
pcall(function()
    StandsConfig = require(ReplicatedStorage.Config.StandsConfig)
end)

--// Cooldown Tables เพื่อป้องกันปัญหาลูปไม่สิ้นสุดกรณีเซิร์ฟเวอร์ไม่ตอบสนอง
local failedFoodCooldowns = {}
local failedStandCooldown = 0
local failedFenceCooldown = 0

--// ---------------------------------------------------------------------------
--// 🗺️ 16 AREAS MATRIX (ด่านและเกณฑ์พลัง)
--// ---------------------------------------------------------------------------
local AreaMatrix = {
    { Index = 1,  Key = "Forest",            Name = "Forest (ป่า)",              ReqPower = 18 },
    { Index = 2,  Key = "Savana",            Name = "Savanna (สะวันนา)",         ReqPower = 153 },
    { Index = 3,  Key = "Desert",            Name = "Desert (ทะเลทราย)",         ReqPower = 321 },
    { Index = 4,  Key = "Jungle",            Name = "Jungle (ป่าดงดิบ)",          ReqPower = 489 },
    { Index = 5,  Key = "Ocean",             Name = "Ocean (มหาสมุทร)",          ReqPower = 657 },
    { Index = 6,  Key = "Arctic",            Name = "Arctic (ทุ่งหิมะ)",         ReqPower = 825 },
    { Index = 7,  Key = "Swamp",             Name = "Swamp (หนองน้ำ)",           ReqPower = 1005 },
    { Index = 8,  Key = "Volcano",           Name = "Volcano (ภูเขาไฟ)",         ReqPower = 1209 },
    { Index = 9,  Key = "SkyIslands",        Name = "Sky Islands (เกาะลอยฟ้า)",  ReqPower = 1449 },
    { Index = 10, Key = "DeepWaters",        Name = "Deep Waters (ทะเลลึก)",     ReqPower = 1737 },
    { Index = 11, Key = "Hell",              Name = "Hell (ขุมนรก)",             ReqPower = 2025 },
    { Index = 12, Key = "AncientRuins",      Name = "Ancient Ruins (ซากโบราณ)",  ReqPower = 2361 },
    { Index = 13, Key = "MythicalParadise",  Name = "Mythical (แดนมายา)",       ReqPower = 2745 },
    { Index = 14, Key = "ShadowRealm",       Name = "Shadow Realm (แดนเงามืด)",  ReqPower = 3225 },
    { Index = 15, Key = "HarvestFields",     Name = "Harvest (ทุ่งกสิกรรม)",      ReqPower = 4065 },
    { Index = 16, Key = "PhantomHarbor",     Name = "Phantom (ท่าเรือภูติพราย)",   ReqPower = 5145 }
}

local AreaRankByKey = {}
for _, a in ipairs(AreaMatrix) do
    AreaRankByKey[a.Key] = a.Index
end

--// State & Telemetry
local BotState = {
    CurrentAction = "กำลังเริ่มต้นระบบ v9.0...",
    NextAction = "ตรวจสอบการอัปเกรดก่อนเริ่มงาน",
    LastActionTime = os.clock(),
    LastProgressTime = os.clock(),
    ThrowsCount = 0,
    CurrentArea = AreaMatrix[1],
    NextArea = AreaMatrix[2],
    PlacedCount = 0,
    MaxSlots = 10,
    CurrentPower = 18,
    IsTraining = false
}

--// ---------------------------------------------------------------------------
--// 📢 CONSOLE LOGGING SYSTEM (พิมพ์สิ่งที่กำลังทำและถัดไปลง /console F9)
--// ---------------------------------------------------------------------------
local function GetCurrentThrowPower()
    local level = PlayerData:FindFirstChild("Level") and PlayerData.Level.Value or 1
    local power = 18 + 5 * (level - 1)
    return power
end

local function LogConsole(tag, message)
    local timestamp = os.date("%X")
    print(string.format("[%s] [%s] %s", timestamp, tag, message))
end

local function LogWarnConsole(tag, message)
    local timestamp = os.date("%X")
    warn(string.format("[%s] [⚠️ %s] %s", timestamp, tag, message))
end

local function UpdateState(current, nextAct)
    BotState.CurrentAction = current
    if nextAct then
        BotState.NextAction = nextAct
    end
    BotState.LastActionTime = os.clock()
    
    local timestamp = os.date("%X")
    local power = GetCurrentThrowPower()
    local money = PlayerData:FindFirstChild("Money") and PlayerData.Money.Value or 0
    local areaName = BotState.CurrentArea and BotState.CurrentArea.Name or "Unknown"
    
    print("--------------------------------------------------------------------------------")
    print(string.format("[%s] [KAITUN v9] 📌 กำลังทำ: %s", timestamp, tostring(current)))
    if nextAct then
        print(string.format("[%s] [KAITUN v9] ➡️  ถัดไป: %s", timestamp, tostring(nextAct)))
    end
    print(string.format("[%s] [KAITUN v9] 📊 สถานะ: [ด่าน: %s] | [พลัง: %d⚡] | [สัตว์ในแปลง: %d/%d] | [เงิน: %s]",
        timestamp,
        areaName,
        power,
        BotState.PlacedCount or 0,
        BotState.MaxSlots or 10,
        tostring(math.floor(money))
    ))
    print("--------------------------------------------------------------------------------")
end

local function MarkProgress()
    BotState.LastProgressTime = os.clock()
end

--// ---------------------------------------------------------------------------
--// NON-BLOCKING SAFE INVOKE WITH TIMEOUT GUARD
--// ---------------------------------------------------------------------------
local function SafeInvokeTimeout(remote, timeout, ...)
    local args = { ... }
    local completed = false
    local result = nil
    
    task.spawn(function()
        local success, res = pcall(function()
            return remote:InvokeServer(unpack(args))
        end)
        if success then
            result = res
        else
            result = { Ok = false, Reason = tostring(res) }
        end
        completed = true
    end)
    
    local start = os.clock()
    local limit = timeout or 4
    while not completed and (os.clock() - start < limit) do
        task.wait(0.05)
    end
    
    if not completed then
        LogWarnConsole("TIMEOUT", string.format("Remote %s หมดเวลาตอบสนอง (%ds)", remote.Name, limit))
        return { Ok = false, Reason = "Timeout" }
    end
    return result
end

--// ---------------------------------------------------------------------------
--// 1. MINIMAL CYBER HUD (CENTER SCREEN DISPLAY)
--// ---------------------------------------------------------------------------
-- ทำความสะอาด GUI เวอร์ชันเก่าก่อนเสมอเพื่อป้องกันการซ้อนทับ
pcall(function()
    for _, name in ipairs({"KaitunProgressionHUD_v7", "KaitunProgressionHUD_v8", "KaitunProgressionHUD_v9"}) do
        local oldCore = CoreGui:FindFirstChild(name)
        if oldCore then oldCore:Destroy() end
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        if pGui then
            local oldP = pGui:FindFirstChild(name)
            if oldP then oldP:Destroy() end
        end
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "KaitunProgressionHUD_v9"
ScreenGui.ResetOnSpawn = false
pcall(function()
    ScreenGui.Parent = CoreGui
end)
if not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "HUDCard"
MainFrame.Size = UDim2.new(0, 430, 0, 140)
-- 🌟 แสดงตรงกลางจอพอดีหลังรันสคริปต์
MainFrame.Position = UDim2.new(0.5, -215, 0.5, -70)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner", MainFrame)
UICorner.CornerRadius = UDim.new(0, 12)

local UIStroke = Instance.new("UIStroke", MainFrame)
UIStroke.Color = Color3.fromRGB(0, 210, 255)
UIStroke.Thickness = 1.5

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, -20, 0, 22)
Title.Position = UDim2.new(0, 10, 0, 8)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextColor3 = Color3.fromRGB(0, 230, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
-- 🌟 เปลี่ยนชื่อแถวบนสุดตามคำสั่งผู้ใช้
Title.Text = "Throw Food For Animals - Kaitun"

local LineCurrent = Instance.new("TextLabel", MainFrame)
LineCurrent.Size = UDim2.new(1, -20, 0, 20)
LineCurrent.Position = UDim2.new(0, 10, 0, 32)
LineCurrent.BackgroundTransparency = 1
LineCurrent.Font = Enum.Font.GothamMedium
LineCurrent.TextSize = 12
LineCurrent.TextColor3 = Color3.fromRGB(255, 255, 255)
LineCurrent.TextXAlignment = Enum.TextXAlignment.Left
LineCurrent.Text = "กำลังทำ: กำลังตรวจสอบ..."

local LineNext = Instance.new("TextLabel", MainFrame)
LineNext.Size = UDim2.new(1, -20, 0, 20)
LineNext.Position = UDim2.new(0, 10, 0, 54)
LineNext.BackgroundTransparency = 1
LineNext.Font = Enum.Font.Gotham
LineNext.TextSize = 12
LineNext.TextColor3 = Color3.fromRGB(180, 200, 225)
LineNext.TextXAlignment = Enum.TextXAlignment.Left
LineNext.Text = "ถัดไป: คำนวณเส้นทาง"

local ProgressInfo = Instance.new("TextLabel", MainFrame)
ProgressInfo.Size = UDim2.new(1, -20, 0, 22)
ProgressInfo.Position = UDim2.new(0, 10, 0, 76)
ProgressInfo.BackgroundTransparency = 1
ProgressInfo.Font = Enum.Font.GothamBold
ProgressInfo.TextSize = 11
ProgressInfo.TextColor3 = Color3.fromRGB(255, 215, 60)
ProgressInfo.TextXAlignment = Enum.TextXAlignment.Left
ProgressInfo.Text = "📍 ด่าน: Forest | 🐾 สัตว์ด่านนี้ในแปลง: 0/10 ตัว"

local StatsLine = Instance.new("TextLabel", MainFrame)
StatsLine.Size = UDim2.new(1, -20, 0, 22)
StatsLine.Position = UDim2.new(0, 10, 0, 102)
StatsLine.BackgroundTransparency = 1
StatsLine.Font = Enum.Font.Code
StatsLine.TextSize = 11
StatsLine.TextColor3 = Color3.fromRGB(100, 245, 160)
StatsLine.TextXAlignment = Enum.TextXAlignment.Left
StatsLine.Text = "💰 เงิน: $0 | ⚡ พลัง: 18 | 🎯 ปา: 0 ครั้ง"

-- HUD Refresh Loop
task.spawn(function()
    while task.wait(0.3) do
        pcall(function()
            LineCurrent.Text = "กำลังทำ: " .. BotState.CurrentAction
            LineNext.Text = "ถัดไป: " .. BotState.NextAction
            
            ProgressInfo.Text = string.format("📍 ด่าน: %s | 🐾 ในแปลง: %d/%d ตัว (เป้าหมาย: %d⚡)",
                BotState.CurrentArea.Name,
                BotState.PlacedCount,
                BotState.MaxSlots,
                BotState.NextArea.ReqPower
            )
            
            local money = PlayerData:FindFirstChild("Money") and PlayerData.Money.Value or 0
            StatsLine.Text = string.format("💰 เงิน: %s | ⚡ พลัง: %s | 🎯 ปา: %d รอบ", 
                tostring(math.floor(money)), 
                tostring(math.floor(BotState.CurrentPower)), 
                BotState.ThrowsCount
            )
        end)
    end
end)

--// ---------------------------------------------------------------------------
--// 1.1 SUPPRESS TAP BONUS BUTTON (ลบ/ซ่อนปุ่มวงกลมม่วง 👉 x2 ออกจากหน้าจอ)
--// ---------------------------------------------------------------------------
local function SuppressTapBonus(obj)
    if obj and (obj.Name == "TapBonus" or obj.Name == "TapBonusLayer") then
        pcall(function()
            if obj:IsA("GuiObject") then
                obj.Visible = false
                obj.Position = UDim2.new(100, 0, 100, 0)
            end
        end)
    end
end

pcall(function()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
    if playerGui then
        playerGui.DescendantAdded:Connect(SuppressTapBonus)
        for _, desc in ipairs(playerGui:GetDescendants()) do
            SuppressTapBonus(desc)
        end
    end
end)

--// ---------------------------------------------------------------------------
--// 2. ANTI-AFK (ป้องกันหลุด 20 นาที)
--// ---------------------------------------------------------------------------
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(100, 100))
end)

--// ---------------------------------------------------------------------------
--// 3. SAFE POSITIONING & INERTIA CLEAR
--// ---------------------------------------------------------------------------
local FallFloor = Instance.new("Part")
FallFloor.Name = "AntiVoidFloor_v9"
FallFloor.Size = Vector3.new(3000, 2, 3000)
FallFloor.Position = Vector3.new(0, -60, 0)
FallFloor.Anchored = true
FallFloor.CanCollide = true
FallFloor.Transparency = 1
FallFloor.Parent = workspace

local function ClearInertia()
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Landed)
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end
end

local function SafeTeleportTo(targetPos)
    local char = LocalPlayer.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not (root and hum) then return false end
    
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.CFrame = CFrame.new(targetPos)
    task.wait(0.1)
    hum:ChangeState(Enum.HumanoidStateType.Landed)
    ClearInertia()
    return true
end

--// ---------------------------------------------------------------------------
--// 4. SMART GAME INSPECTORS
--// ---------------------------------------------------------------------------
local function GetPlotCapacity()
    local fenceLevel = PlayerData:FindFirstChild("FenceLevel") and PlayerData.FenceLevel.Value or 0
    if FenceConfig and FenceConfig.Upgrades and FenceConfig.Upgrades[fenceLevel] then
        return FenceConfig.Upgrades[fenceLevel].Slots or 10
    end
    return 10
end

local function GetReachableArea(power)
    local highestArea = AreaMatrix[1]
    local nextArea = AreaMatrix[2]
    
    for i, a in ipairs(AreaMatrix) do
        if power >= a.ReqPower then
            highestArea = a
            nextArea = AreaMatrix[i + 1] or a
        end
    end
    return highestArea, nextArea
end

local function CountPlacedAnimalsFromArea(targetArea)
    local plotIndex = LocalPlayer:GetAttribute("PlotIndex")
    if not plotIndex or not workspace:FindFirstChild("Plots") then return 0 end
    local plot = workspace.Plots:FindFirstChild(tostring(plotIndex))
    if not plot or not plot:FindFirstChild("Animals") then return 0 end
    
    local targetRank = targetArea.Index
    local count = 0
    
    for _, model in ipairs(plot.Animals:GetChildren()) do
        local animalName = model:GetAttribute("AnimalName") or model.Name
        local info = AnimalEconomy and AnimalEconomy.List and AnimalEconomy.List[animalName]
        if info then
            local areaKey = info.Area
            local rank = AreaRankByKey[areaKey] or 1
            if rank >= targetRank then
                count = count + 1
            end
        else
            if targetRank == 1 then
                count = count + 1
            end
        end
    end
    return count
end

--// ---------------------------------------------------------------------------
--// 5. EXACT SPOT LOCATORS
--// ---------------------------------------------------------------------------
local function GetThrowSpot()
    local starterArea = workspace:FindFirstChild("StarterArea")
    if starterArea then
        local crossLine = starterArea:FindFirstChild("CrossLine")
        if crossLine then
            return Vector3.new(crossLine.Position.X, crossLine.Position.Y + 3, crossLine.Position.Z + 4)
        end
    end
    return Vector3.new(0, 6, -36)
end

local function GetTrainingSpot()
    local plotIndex = LocalPlayer:GetAttribute("PlotIndex")
    if not plotIndex or not workspace:FindFirstChild("Plots") then return nil end
    local plot = workspace.Plots:FindFirstChild(tostring(plotIndex))
    if not plot then return nil end
    
    local spot = plot:FindFirstChild("TrainingSpot", true)
    if spot and spot:IsA("BasePart") then
        return spot.Position + Vector3.new(0, 3, 0)
    end
    
    local trainingArea = plot:FindFirstChild("TrainingArea", true)
    if trainingArea then
        if trainingArea:IsA("BasePart") then
            return trainingArea.Position + Vector3.new(0, 3, 0)
        elseif trainingArea:IsA("Model") and trainingArea.PrimaryPart then
            return trainingArea.PrimaryPart.Position + Vector3.new(0, 3, 0)
        end
    end
    
    return plot.Position + Vector3.new(-16, 3, -30.5)
end

--// ---------------------------------------------------------------------------
--// 6. SAFE INVENTORY MANAGEMENT: EQUIP BEST BEFORE SELLING
--// ---------------------------------------------------------------------------
local function SafeSellAnimals()
    if BotState.IsTraining or LocalPlayer:GetAttribute("Training") == true then
        return nil
    end
    
    UpdateState("จัดสัตว์ที่ดีที่สุดลงแปลง (Equip Best)", "เตรียมขายสัตว์ส่วนเกิน")
    local equipRes = SafeInvokeTimeout(Remotes.Plot_EquipBest, 3)
    LogConsole("EQUIP_BEST", string.format("ผลการจัดสัตว์ที่ดีที่สุด: %s", tostring(equipRes and equipRes.Ok and "สำเร็จ (OK)" or "ไม่มีสัตว์เปลี่ยน")))
    task.wait(0.35)
    
    UpdateState("ขายสัตว์ส่วนเกินในกระเป๋า (Sell All)", "รับเงินเข้าบัญชี")
    local sellRes = SafeInvokeTimeout(Remotes.Plot_SellAll, 3)
    if sellRes and sellRes.Ok then
        LogConsole("SELL_ALL", string.format("ขายสัตว์สำเร็จ! จำนวน %s ตัว | ได้เงิน +$%s", 
            tostring(sellRes.Count or 0), tostring(sellRes.Money or 0)))
    else
        LogConsole("SELL_ALL", "ไม่มีสัตว์ส่วนเกินในกระเป๋าให้ขาย")
    end
    task.wait(0.35)
    
    MarkProgress()
    return sellRes
end

--// ---------------------------------------------------------------------------
--// 7. STRICT SEQUENTIAL UPGRADES (1. บาร์ -> 2. อาหาร -> 3. ฐาน)
--// ---------------------------------------------------------------------------
-- ฟังก์ชันตรวจสอบว่ามีรายการใดเงินพออัปเกรดได้บ้าง ณ ขณะนี้
local function CheckAffordableUpgrades()
    local money = PlayerData:FindFirstChild("Money") and PlayerData.Money.Value or 0
    local canStand = false
    local canFood = false
    local canFence = false
    local standTarget = nil
    
    -- 1. ตรวจสอบบาร์ (Stand / Bar)
    local onStandCooldown = (os.clock() < failedStandCooldown)
    local currentStand = PlayerData:FindFirstChild("Stand") and PlayerData.Stand.Value or 0
    local nextStandIndex = currentStand + 1
    local standsList = (StandsConfig and StandsConfig.List) or (StandsConfig and StandsConfig.All) or {}
    local nextStandInfo = standsList[nextStandIndex]
    if nextStandInfo and not onStandCooldown and money >= (nextStandInfo.Price or 0) then
        canStand = true
        standTarget = nextStandInfo
    end
    
    -- 2. ตรวจสอบอาหาร (Food / Bait)
    if FoodsConfig and FoodsConfig.All then
        local ownedFoods = PlayerData:FindFirstChild("OwnedFoods")
        for i, item in ipairs(FoodsConfig.All) do
            local foodIndex = item.Index or i
            local isLocked = false
            if FoodsConfig.IsLocked then
                pcall(function() isLocked = FoodsConfig.IsLocked(foodIndex) end)
            end
            
            -- ตรวจสอบความเป็นเจ้าของด้วย Integer Index หรือ Bait Identifier
            local isOwned = ownedFoods and (
                ownedFoods:FindFirstChild(tostring(foodIndex)) or 
                (item.Bait and ownedFoods:FindFirstChild(tostring(item.Bait)))
            )
            
            local onCooldown = failedFoodCooldowns[foodIndex] and (os.clock() < failedFoodCooldowns[foodIndex])
            
            if not isLocked and not isOwned and not onCooldown and money >= (item.Price or 0) then
                canFood = true
                break
            end
        end
    end
    
    -- 3. ตรวจสอบฐาน/รั้ว (Fence / Base)
    local onFenceCooldown = (os.clock() < failedFenceCooldown)
    local currentFence = PlayerData:FindFirstChild("FenceLevel") and PlayerData.FenceLevel.Value or 0
    local fenceUpgrades = FenceConfig and FenceConfig.Upgrades or {}
    local nextFenceInfo = fenceUpgrades[currentFence + 1]
    if nextFenceInfo and not onFenceCooldown and money >= (nextFenceInfo.Price or 0) then
        canFence = true
    end
    
    local hasAny = canStand or canFood or canFence
    return hasAny, canStand, canFood, canFence, standTarget
end

-- ฟังก์ชันอัปเกรดบาร์โหนให้ได้มากที่สุดเท่าที่เงินมี
local function UpgradeStandAsMuchAsPossible()
    local upgradedCount = 0
    while true do
        local money = PlayerData:FindFirstChild("Money") and PlayerData.Money.Value or 0
        local currentStand = PlayerData:FindFirstChild("Stand") and PlayerData.Stand.Value or 0
        local nextStandIndex = currentStand + 1
        local standsList = (StandsConfig and StandsConfig.List) or (StandsConfig and StandsConfig.All) or {}
        local nextStandInfo = standsList[nextStandIndex]
        
        if not nextStandInfo or money < (nextStandInfo.Price or 0) then
            break
        end
        
        UpdateState(string.format("อัปเกรดบาร์โหนเป็น [%s] (ลำดับ 1: Stand)", nextStandInfo.Name), "เพิ่มตัวคูณ XP ต่อการดึงข้อ")
        local res = SafeInvokeTimeout(Remotes.Stand_Upgrade, 4)
        if res and res.Ok then
            upgradedCount = upgradedCount + 1
            LogConsole("UPGRADE_STAND", string.format("🔥 อัปเกรดบาร์เป็น [%s] สำเร็จ! (ราคา: $%s)", nextStandInfo.Name, tostring(nextStandInfo.Price)))
            MarkProgress()
            task.wait(0.3)
        else
            LogWarnConsole("UPGRADE_STAND", "ยังไม่สามารถอัปเกรดบาร์ต่อได้: " .. tostring(res and res.Reason or "Failed"))
            failedStandCooldown = os.clock() + 15
            break
        end
    end
    return upgradedCount > 0
end

-- "เพิ่มการอัปเกรดมาเป็นอันดับแรก ถ้ามีอะไรให้อัปเกรดให้อัปเกรดก่อนค่อยไปทำอย่างอื่น"
local function PerformSequentialEconomyUpgrades()
    local money = PlayerData:FindFirstChild("Money") and PlayerData.Money.Value or 0
    
    -- =========================================================================
    -- ลำดับที่ 1: บาร์โหน (Stand / Pull-up Bar) - สูงสุด
    -- =========================================================================
    UpgradeStandAsMuchAsPossible()
    
    -- อัปเดตเงินคงเหลือ
    money = PlayerData:FindFirstChild("Money") and PlayerData.Money.Value or 0
    
    -- =========================================================================
    -- ลำดับที่ 2: อาหาร (Food / Bait) - เงินเหลือค่อยซื้อ
    -- =========================================================================
    if FoodsConfig and FoodsConfig.All then
        local ownedFoods = PlayerData:FindFirstChild("OwnedFoods")
        
        for i, item in ipairs(FoodsConfig.All) do
            local foodIndex = item.Index or i
            local price = item.Price or 0
            
            local isLocked = false
            if FoodsConfig.IsLocked then
                pcall(function() isLocked = FoodsConfig.IsLocked(foodIndex) end)
            end
            
            local isOwned = ownedFoods and (
                ownedFoods:FindFirstChild(tostring(foodIndex)) or 
                (item.Bait and ownedFoods:FindFirstChild(tostring(item.Bait)))
            )
            
            local onCooldown = failedFoodCooldowns[foodIndex] and (os.clock() < failedFoodCooldowns[foodIndex])
            
            if not isLocked and not isOwned and not onCooldown and money >= price then
                local foodName = item.Name or ("Food #" .. foodIndex)
                UpdateState(string.format("ซื้ออาหาร [%s] ชิ้นที่ %d (ลำดับ 2: Food)", foodName, foodIndex), "เพิ่มโอกาสเจอสัตว์หายาก")
                
                -- สำคัญ: ส่ง foodIndex (Integer 1, 2, ..., 26) ไปที่ Shop_Buy
                local buyRes = SafeInvokeTimeout(Remotes.Shop_Buy, 4, foodIndex)
                if buyRes and buyRes.Ok then
                    LogConsole("BUY_FOOD", string.format("🍏 ซื้ออาหาร [%s] (ชิ้นที่ %d) สำเร็จ! (ราคา: $%s)", foodName, foodIndex, tostring(price)))
                    money = money - price
                    MarkProgress()
                else
                    LogWarnConsole("BUY_FOOD", string.format("ซื้ออาหาร [%s] (ชิ้นที่ %d) ไม่สำเร็จ: %s (ติดคูลดาวน์ 30วิ)", 
                        foodName, foodIndex, tostring(buyRes and buyRes.Reason or "Rejected")))
                    failedFoodCooldowns[foodIndex] = os.clock() + 30
                end
                task.wait(0.25)
            end
        end
        
        -- สวมใส่อาหารที่ดีที่สุดเสมอ
        for i = #FoodsConfig.All, 1, -1 do
            local item = FoodsConfig.All[i]
            local foodIndex = item.Index or i
            local isOwned = ownedFoods and (
                ownedFoods:FindFirstChild(tostring(foodIndex)) or 
                (item.Bait and ownedFoods:FindFirstChild(tostring(item.Bait)))
            )
            if isOwned then
                SafeInvokeTimeout(Remotes.Shop_Equip, 3, foodIndex)
                break
            end
        end
    end
    
    -- อัปเดตเงินคงเหลือ
    money = PlayerData:FindFirstChild("Money") and PlayerData.Money.Value or 0
    
    -- =========================================================================
    -- ลำดับที่ 3: ฐาน/รั้วแปลง (Fence / Base) - เงินเหลือขั้นสุดท้ายค่อยขยายฐาน
    -- =========================================================================
    local currentFence = PlayerData:FindFirstChild("FenceLevel") and PlayerData.FenceLevel.Value or 0
    local nextFenceIndex = currentFence + 1
    local fenceUpgrades = FenceConfig and FenceConfig.Upgrades or {}
    local nextFenceInfo = fenceUpgrades[nextFenceIndex]
    local onFenceCooldown = (os.clock() < failedFenceCooldown)
    
    if nextFenceInfo and not onFenceCooldown and money >= (nextFenceInfo.Price or 0) then
        UpdateState(string.format("อัปเกรดฐาน/รั้วแปลงเป็นเลเวล %d (ลำดับ 3: Base)", nextFenceIndex), "เพิ่มช่องสล็อตสัตว์ในแปลง")
        local fenceRes = SafeInvokeTimeout(Remotes.Plot_UpgradeFence, 4)
        if fenceRes and fenceRes.Ok then
            LogConsole("UPGRADE_FENCE", string.format("🏡 อัปเกรดรั้วเป็นเลเวล %d สำเร็จ! (ช่องใส่สัตว์: %d ช่อง, ราคา: $%s)", 
                nextFenceIndex, nextFenceInfo.Slots or 12, tostring(nextFenceInfo.Price)))
            money = money - (nextFenceInfo.Price or 0)
            MarkProgress()
        else
            LogWarnConsole("UPGRADE_FENCE", string.format("อัปเกรดรั้วเลเวล %d ไม่สำเร็จ: %s (ติดคูลดาวน์ 30วิ)", 
                nextFenceIndex, tostring(fenceRes and fenceRes.Reason or "Failed")))
            failedFenceCooldown = os.clock() + 30
        end
        task.wait(0.25)
    end
end

--// ---------------------------------------------------------------------------
--// 8. REACTIVE TAP BONUS (0ms) & WATCHDOG
--// ---------------------------------------------------------------------------
Remotes.Training_Bonus.OnClientEvent:Connect(function(bonusId)
    task.spawn(function()
        SafeInvokeTimeout(Remotes.Training_TapBonus, 2, bonusId)
        LogConsole("TAP_BONUS", "กดวงกลมโบนัส Tap Bonus 0ms สำเร็จ! (ซ่อนปุ่มจากหน้าจอเรียบร้อย)")
    end)
end)

-- Anti-Stall Watchdog
task.spawn(function()
    while task.wait(3) do
        if os.clock() - BotState.LastProgressTime > 25 then
            LogWarnConsole("WATCHDOG", "ตรวจพบการหยุดนิ่งเกิน 25 วินาที! สั่งรีเซ็ตสถานะและกลับจุดปลอดภัย...")
            pcall(function() Remotes.Throw_Cancel:InvokeServer() end)
            pcall(function() Remotes.Training_Stop:InvokeServer() end)
            ClearInertia()
            
            local plotSpot = GetTrainingSpot()
            if plotSpot then
                SafeTeleportTo(plotSpot)
            end
            
            BotState.IsTraining = false
            MarkProgress()
            task.wait(1)
        end
    end
end)

-- Background Rewards
task.spawn(function()
    while task.wait(30) do
        pcall(function()
            SafeInvokeTimeout(Remotes.Shop_ClaimFree, 3)
            task.wait(0.5)
            SafeInvokeTimeout(Remotes.Offline_Claim, 3)
        end)
    end
end)

--// ---------------------------------------------------------------------------
--// 9. CORE ACTION: SINGLE THROW
--// ---------------------------------------------------------------------------
local function PerformSingleThrow()
    SafeInvokeTimeout(Remotes.Training_Stop, 2)
    SafeInvokeTimeout(Remotes.Throw_Cancel, 2)
    
    local throwPos = GetThrowSpot()
    UpdateState("เดินไปที่จุดปาอาหาร", "เตรียมตั้งท่าปา")
    SafeTeleportTo(throwPos)
    task.wait(0.2)
    
    local superCount = PlayerData:FindFirstChild("SuperThrows") and PlayerData.SuperThrows.Value or 0
    if superCount > 0 then
        SafeInvokeTimeout(Remotes.Throw_UseSuper, 2)
        task.wait(0.15)
    end
    
    UpdateState("เริ่มปาอาหาร (Throw_Start)", "คำนวณกำลังปา 100% Perfect")
    local startRes = SafeInvokeTimeout(Remotes.Throw_Start, 4)
    if not (startRes and startRes.Ok) then
        LogWarnConsole("THROW_START", "Throw_Start ไม่สำเร็จ: " .. tostring(startRes and startRes.Reason))
        SafeInvokeTimeout(Remotes.Throw_Cancel, 2)
        task.wait(0.5)
        return false
    end
    LogConsole("THROW_START", "เริ่มปาอาหารสำเร็จ (Server OK)")
    task.wait(0.25)
    
    UpdateState("ส่งค่า Perfect Meter (1.0)", "จบการปาอาหาร")
    local resolveRes = SafeInvokeTimeout(Remotes.Throw_Resolve, 4, 1.0)
    if not (resolveRes and resolveRes.Ok) then
        LogWarnConsole("THROW_RESOLVE", "Throw_Resolve ไม่สำเร็จ: " .. tostring(resolveRes and resolveRes.Reason))
        SafeInvokeTimeout(Remotes.Throw_Cancel, 2)
        task.wait(0.5)
        return false
    end
    LogConsole("THROW_RESOLVE", string.format("คำนวณการตกสำเร็จ! สัตว์ที่ได้: %s (ระยะ: %s)", 
        tostring(resolveRes.Result and resolveRes.Result.Name or "-"), tostring(resolveRes.Distance or "-")))
    task.wait(0.35)
    
    local compRes = SafeInvokeTimeout(Remotes.Throw_Complete, 4)
    if compRes and compRes.Ok then
        BotState.ThrowsCount = BotState.ThrowsCount + 1
        LogConsole("THROW_COMPLETE", string.format("จบการปารอบที่ %d สมบูรณ์!", BotState.ThrowsCount))
        MarkProgress()
    end
    
    ClearInertia()
    task.wait(0.25)
    return true
end

--// ---------------------------------------------------------------------------
--// 10. CORE ACTION: TRAINING UNTIL NEXT AREA (SMART STAND UPGRADE & RESUME)
--// ---------------------------------------------------------------------------
local function PerformTrainingUntil(targetPower)
    -- ก่อนขึ้นบาร์ ทำการอัปเกรดทุกอย่างที่มีให้เรียบร้อย (Priority #1: บาร์ -> อาหาร -> ฐาน)
    local hasUpgradesBefore = CheckAffordableUpgrades()
    if hasUpgradesBefore then
        LogConsole("PRIORITY_UPGRADE", "🔥 ตรวจพบการอัปเกรดก่อนขึ้นบาร์! ดำเนินการอัปเกรดก่อน...")
        PerformSequentialEconomyUpgrades()
        task.wait(0.3)
    end

    local trainPos = GetTrainingSpot()
    if not trainPos then 
        LogWarnConsole("TRAINING", "ไม่พบตำแหน่ง TrainingSpot ในพล็อต!")
        return 
    end
    
    SafeInvokeTimeout(Remotes.Throw_Cancel, 2)
    UpdateState("ไปที่แท่นฝึกพลังในพล็อต", "เริ่มโหมดโหนบาร์เทรนพลัง")
    SafeTeleportTo(trainPos)
    task.wait(0.3)
    
    -- ตรวจสอบว่าระบบเกมเริ่มโหนบาร์ให้อัตโนมัติแล้วหรือไม่
    if LocalPlayer:GetAttribute("Training") == true then
        LogConsole("TRAINING_START", "ตัวเกมตรวจพบแท่นและเริ่มโหนบาร์ให้อัตโนมัติแล้ว! (Training Attribute == true)")
    else
        local startRes = SafeInvokeTimeout(Remotes.Training_Start, 4)
        if startRes and startRes.Ok then
            LogConsole("TRAINING_START", "ส่ง Remote Training_Start เริ่มโหนบาร์สำเร็จ (Server OK)")
        elseif startRes and startRes.Reason == "Busy" then
            LogConsole("TRAINING_START", "ตัวละครกำลังโหนบาร์อยู่แล้ว (Busy) -> ให้ฝึกพลังต่อเนื่อง!")
        else
            LogWarnConsole("TRAINING_START", "Training_Start ไม่สำเร็จ: " .. tostring(startRes and startRes.Reason))
            task.wait(0.5)
            return
        end
    end
    
    BotState.IsTraining = true
    MarkProgress()
    LogConsole("TRAINING", string.format("🏋️ เริ่มโหนบาร์ฝึกพลัง! พลังปัจจุบัน: %d⚡ | เป้าหมาย: %d⚡ (ด่าน: %s)",
        GetCurrentThrowPower(), targetPower, BotState.NextArea.Name))
    
    local lastLog = os.clock()
    
    while BotState.IsTraining do
        task.wait(0.4)
        
        local currentPower = GetCurrentThrowPower()
        BotState.CurrentPower = currentPower
        
        -- =====================================================================
        -- 🌟 จุดสำคัญ: "ถ้าบาร์อัปเกรดได้ ให้มาอัปเกรดก่อนแล้วค่อยโหนบาร์ต่อ"
        -- ตรวจสอบเฉพาะ "บาร์ (Stand)" เท่านั้นขณะกำลังโหนบาร์!
        -- อาหารและรั้วจะไม่รบกวนการโหนบาร์ แต่จะอัปเกรดเมื่อจบรอบฝึกพลัง
        -- =====================================================================
        local _, canStand, _, _, standTarget = CheckAffordableUpgrades()
        if canStand and standTarget then
            LogConsole("UPGRADE_STAND", string.format("🔔 ตรวจพบเงินพออัปเกรดบาร์เป็น [%s] (ราคา: $%s)! ปล่อยมือลงมาอัปเกรดบาร์ก่อน...", 
                standTarget.Name, tostring(standTarget.Price)))
            UpdateState(string.format("พักโหนบาร์เพื่ออัปเกรดบาร์เป็น [%s]", standTarget.Name), "อัปเกรดเสร็จจะกลับไปโหนต่อทันที")
            
            -- 1. ปล่อยมือลงจากบาร์ชั่วคราว
            SafeInvokeTimeout(Remotes.Training_Stop, 3)
            BotState.IsTraining = false
            ClearInertia()
            task.wait(0.3)
            
            -- 2. ดำเนินการอัปเกรดบาร์ทันที (อัปเกรดได้หลายขั้นถ้าเงินพอ)
            UpgradeStandAsMuchAsPossible()
            task.wait(0.5)
            
            -- 3. อัปเดตพิกัดแท่นโหนบาร์ใหม่ (บาร์โมเดลใหม่อาจสปอว์นแทนที่) แล้ววาร์ปกลับขึ้นบาร์ต่อ!
            trainPos = GetTrainingSpot() or trainPos
            UpdateState("อัปเกรดบาร์สำเร็จ! กำลังกลับขึ้นโหนบาร์ต่อ", string.format("ดันพลังไปเป้าหมาย %d⚡", targetPower))
            SafeTeleportTo(trainPos)
            task.wait(0.3)
            
            if LocalPlayer:GetAttribute("Training") ~= true then
                local reStart = SafeInvokeTimeout(Remotes.Training_Start, 4)
                if reStart and (reStart.Ok or reStart.Reason == "Busy") then
                    LogConsole("TRAINING", "กลับขึ้นบาร์เพื่อฝึกพลังต่อเรียบร้อย!")
                end
            else
                LogConsole("TRAINING", "ตัวเกมเชื่อมต่อโหนบาร์ใหม่อัตโนมัติเรียบร้อย!")
            end
            
            BotState.IsTraining = true
            MarkProgress()
        end
        
        -- ตรวจสอบว่าหลุดจากบาร์หรือไม่ ถ้าหลุด ให้ก้าวขึ้นบาร์ใหม่
        if LocalPlayer:GetAttribute("Training") == false and BotState.IsTraining then
            LogWarnConsole("TRAINING", "ตรวจพบตัวละครหลุดจากบาร์! กำลังก้าวขึ้นไปโหนต่อทันที...")
            SafeTeleportTo(trainPos)
            task.wait(0.3)
            local reStart = SafeInvokeTimeout(Remotes.Training_Start, 3)
            if reStart and (reStart.Ok or reStart.Reason == "Busy") then
                LogConsole("TRAINING", "เชื่อมต่อกลับขึ้นบาร์สำเร็จ!")
            end
        end
        
        -- พิมพ์รายงานความคืบหน้าลง /console ทุก 3 วินาที
        if os.clock() - lastLog > 3 then
            lastLog = os.clock()
            LogConsole("TRAINING_PROGRESS", string.format("กำลังโหนบาร์... พลัง: %d/%d⚡ (ขาดอีก %d⚡ จะถึงด่าน %s)",
                currentPower, targetPower, math.max(0, targetPower - currentPower), BotState.NextArea.Name))
        end
        
        UpdateState(
            string.format("กำลังโหนบาร์ฝึกพลัง: %d / %d⚡", currentPower, targetPower),
            string.format("ขาดอีก %d⚡ จะปลดล็อค %s", math.max(0, targetPower - currentPower), BotState.NextArea.Name)
        )
        MarkProgress()
        
        -- เมื่อพลังถึงเกณฑ์ปลดล็อคด่านถัดไป
        if currentPower >= targetPower then
            LogConsole("TRAINING_DONE", string.format("🏆 พลังถึงเป้าหมาย %d⚡ แล้ว! ปลดล็อคด่าน %s เรียบร้อย!", 
                currentPower, BotState.NextArea.Name))
            break
        end
    end
    
    SafeInvokeTimeout(Remotes.Training_Stop, 3)
    BotState.IsTraining = false
    ClearInertia()
    task.wait(0.3)
end

--// ---------------------------------------------------------------------------
--// 11. MAIN AUTONOMOUS STATE MACHINE (UPGRADE AS #1 PRIORITY)
--// ---------------------------------------------------------------------------
print("================================================================================")
print("🐾 [KAITUN BOT v9.0] Throw Food For Animals - Kaitun")
print("📢 ข้อมูลการทำงานทั้งหมดแสดงใน /console (กด F9 เพื่อดู Log สด)")
print("🎯 ลำดับการอัปเกรด: 1.บาร์ (Stand) -> 2.อาหาร (Food) -> 3.ฐาน (Fence)")
print("🔒 กฎการขายสัตว์: ต้อง Equip Best ก่อนขายสัตว์ทุกครั้ง")
print("================================================================================")

task.spawn(function()
    while true do
        task.wait(0.2)
        
        -- =====================================================================
        -- 🌟 ลำดับสูงสุดอันดับที่ 1: "ถ้ามีอะไรให้อัปเกรด ให้อัปเกรดก่อนค่อยไปทำอย่างอื่น"
        -- =====================================================================
        local hasUpgrades = CheckAffordableUpgrades()
        if hasUpgrades then
            UpdateState("พบรายการที่พร้อมอัปเกรด!", "อัปเกรดเป็นอันดับแรกก่อนเริ่มงานอื่น")
            LogConsole("PRIORITY_UPGRADE", "🔥 ตรวจพบรายการอัปเกรดพร้อมซื้อ! ดำเนินการอัปเกรดก่อนเริ่มทำงานอื่น...")
            PerformSequentialEconomyUpgrades()
            task.wait(0.3)
        end
        
        -- 1. ตรวจสอบข้อมูลสเตตัสปัจจุบัน
        BotState.MaxSlots = GetPlotCapacity()
        BotState.CurrentPower = GetCurrentThrowPower()
        
        local curArea, nextArea = GetReachableArea(BotState.CurrentPower)
        BotState.CurrentArea = curArea
        BotState.NextArea = nextArea
        
        -- 2. จัดสัตว์ตัวที่ดีที่สุดลงแปลงก่อนเสมอ และขายสัตว์ส่วนเกินในกระเป๋า
        SafeSellAnimals()
        
        -- เช็คการอัปเกรดอีกรอบเผื่อได้เงินจากการขายสัตว์
        if CheckAffordableUpgrades() then
            PerformSequentialEconomyUpgrades()
        end
        
        -- 3. นับจำนวนสัตว์ในแปลงที่มาจากด่านปัจจุบันขึ้นไป
        BotState.PlacedCount = CountPlacedAnimalsFromArea(BotState.CurrentArea)
        MarkProgress()
        
        -- 4. การตัดสินใจของบอท:
        if BotState.CurrentArea.Index >= #AreaMatrix and BotState.PlacedCount >= BotState.MaxSlots then
            UpdateState("ฟาร์มด่านสุดท้าย Phantom Harbor สมบูรณ์แบบ!", "โหนบาร์ปั๊มพลังต่อเนื่อง")
            PerformTrainingUntil(BotState.CurrentPower + 200)
            
        elseif BotState.PlacedCount < BotState.MaxSlots then
            local needed = BotState.MaxSlots - BotState.PlacedCount
            UpdateState(
                string.format("ปาอาหารจับสัตว์ %s (ขาดอีก %d ตัว)", BotState.CurrentArea.Name, needed),
                "เก็บสัตว์ให้เต็มแปลงก่อนไปเทรน"
            )
            
            for _ = 1, math.min(needed, 3) do
                -- เช็คการอัปเกรดก่อนปาแต่ละครั้งเสมอ
                if CheckAffordableUpgrades() then
                    PerformSequentialEconomyUpgrades()
                end
                
                PerformSingleThrow()
                task.wait(0.3)
            end
            
            SafeSellAnimals()
            PerformSequentialEconomyUpgrades()
            
        else
            UpdateState(
                string.format("สัตว์ด่าน %s ครบแปลงแล้ว (%d/%d)", BotState.CurrentArea.Name, BotState.PlacedCount, BotState.MaxSlots),
                string.format("ย้ายไปโหนบาร์เพื่อดันพลังไปด่าน %s (%d⚡)", BotState.NextArea.Name, BotState.NextArea.ReqPower)
            )
            task.wait(0.5)
            
            SafeSellAnimals()
            
            -- โหนบาร์เทรนพลัง (ถ้าบาร์อัปเกรดได้ จะปล่อยมือลงมาอัปเกรดทันทีแล้วขึ้นไปโหนต่อ)
            PerformTrainingUntil(BotState.NextArea.ReqPower)
            
            PerformSequentialEconomyUpgrades()
        end
    end
end)
