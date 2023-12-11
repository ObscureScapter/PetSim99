--  services

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService    = game:GetService("RunService")
local VirtualUser   = game:GetService("VirtualUser")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RbxAnalyticsService   = game:GetService("RbxAnalyticsService")

--  variables

local Player    = Players.LocalPlayer
local Things    = Workspace:WaitForChild("__THINGS")
local Active    = Things:WaitForChild("__INSTANCE_CONTAINER"):WaitForChild("Active")
local Debris    = Workspace:WaitForChild("__DEBRIS")
local Network   = ReplicatedStorage:WaitForChild("Network")
local Library   = loadstring(game:HttpGet("https://raw.githubusercontent.com/ObscureScapter/UILibrary/main/ScapLib.lua"))()
local Settings  = {}
local Cooldowns = {
    Fishing = tick(),
    OpenEggs    = tick(),
    OrbCollect  = tick(),
    PlaceFlag   = tick(),
    Vending = tick(),
    Daily = tick(),
    Dig = tick(),
    Fruits  = tick(),
    TNT   = tick(),
    Farm    = tick(),
    Rewards = tick(),
    Ranks = tick(),
}
local GameModules   = {}
local GameStates    = {
    Fishing = false,
    Digging = false,
}
local EggHatching   = getsenv(Player.PlayerScripts.Scripts.Game:WaitForChild("Egg Opening Frontend"))
local CollectBags   = getsenv(Player.PlayerScripts.Scripts.Game:WaitForChild("Lootbags Frontend")).Claim
local ClientCmds    = require(ReplicatedStorage.Library:WaitForChild("Client"))
local OldHooks  = {}
local VendingMachines   = require(ReplicatedStorage.Library.Directory.VendingMachines)
local DailyRewards  = {}
local FlagIDs   = {
    ["Coins Flag"]   = "afb269f6d8e34907af6d8bd34564c403",
    ["Magnet Flag"]  = "f7ccf7845bbd4ea284817a744be2a733",
    ["Hasty Flag"]    = "aebc5b01e2954e50a6a1db81256a696e",
    ["Diamonds Flag"]    = "f1b4956b3af7495f818549bd712635c1",
    ["Fortune Flag"]    = "7909dc74ca634fefa927bbb82a35ca4f",
}
local FruitIDs  = {
    Apple   = "ef9dad7c065b403fac5b107dc48ce456",
    Banana  = "6c72e7196d6b452899378feb7457d742",
    Orange  = "427c83c3abc14177b5b27e76144a4bec",
    Pineapple   = "d1cdbeccf0da48d79c8fc9adbaf22f3e",
    Rainbow = "bed8fea7965440dba3b01b126d4b30c5",
}
local SettingsOrder  = {
    {"Automatics", {
        --{"Fast Pets", false},
        {"Autofarm Nearest", false},
        {"Auto Collect Drops", false},
        {"Divider"},
        {"Auto Drop TNT", false},
        {"TNT Delay", 10},
        {"Divider"},
        {"Auto Claim Dailies", false},
        {"Auto Purchase Vending Machines", false},
        {"Divider"},
        {"Redeem Rewards", false},
        {"Redeem Rank Ups", false},
        --{"Collect Shiny Relics", "Click"},
        {"Divider"},
        {"Selected Flag",  "Coins Flag"},
        {"Auto Place Flag", false},
    }},
    {"Minigames", {
        {"Auto Fish", false},
        {"Divider"},
        {"Auto Dig", false},
        {"Digging Range", 16},
        {"Divider"},
        {"Auto Stairs", false},
    }},
    {"Eggs", {
        {"Auto Open Eggs", false},
        {"Egg Amount", 1},
        {"Selected Egg", "Cracked Egg"},
        {"Divider"},
        {"Remove Egg Animation", false},
    }},
    {"Fruits", {
        {"Auto Eat Apple", false},
        {"Apple Amount", 10},
        {"Divider"},
        {"Auto Eat Banana", false},
        {"Banana Amount", 10},
        {"Divider"},
        {"Auto Eat Orange", false},
        {"Orange Amount", 10},
        {"Divider"},
        {"Auto Eat Pineapple", false},
        {"Pineapple Amount", 10},
        {"Divider"},
        {"Auto Eat Rainbow", false},
        {"Rainbow Amount", 10},
    }},
    {"Settings", {
        {"Toggle UI", Enum.KeyCode.P},
    }},
}
local FarmTarget    = nil

--  functions

--  // Anti-AFK
Player.Idled:Connect(function()
    VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)

--  // Spoof HWID (I doubt this helps but just incase!)
hookfunction(RbxAnalyticsService.GetClientId, function()
    local MyHWID    = "0"
    return MyHWID:rep(39)
end)

--  // Hook Egg Animation
OldHooks.PlayEggAnimation   = EggHatching.PlayEggAnimation
EggHatching.PlayEggAnimation    = function(...)
    if not Settings.Eggs["Remove Egg Animation"] then
        return OldHooks.PlayEggAnimation(...)
    end
end

--  // Spoof PetSpeed
OldHooks.GetActivePotions   = ClientCmds.PotionCmds.GetActivePotions
ClientCmds.PotionCmds.GetActivePotions  = function()
    local ActivePotions = OldHooks.GetActivePotions()

    if Settings.Automatics["Fast Pets"] then
        ActivePotions.Walkspeed[3]  = 10
    end

    return ActivePotions
end

OldHooks.GetByItemUID   = ClientCmds.PlayerPet.GetByItemUID
ClientCmds.PlayerPet.GetByItemUID  = function(ID: string)
    local PetInfo = OldHooks.GetByItemUID(ID)

    for _,v in PetInfo do
        v.speedMult = Settings.Automatics["Fast Pets"] and 6 or 1
    end

    return PetInfo
end

OldHooks.GetAll   = ClientCmds.PlayerPet.GetAll
ClientCmds.PlayerPet.GetAll  = function()
    local PetInfo = OldHooks.GetAll()

    for _,v in PetInfo do
        v.speedMult = Settings.Automatics["Fast Pets"] and 6 or 1
    end

    return PetInfo
end

--  // Fetch Daily Rewards
for _,v in ReplicatedStorage.__DIRECTORY.TimedRewards:GetChildren() do
    local MyModule  = require(v)

    DailyRewards[MyModule.MachineName]  = MyModule
end

--  // Build The UI w/ Our New Library 😏
local function BuildUI()
    for i,v in SettingsOrder do
        i   = v[1]
        v   = v[2]
        local NewPage   = Library:CreatePage(i)

        Settings[i] = {}
        for q,c in v do
            q   = c[1]
            c   = c[2]

            Settings[i][q]  = c
            if q == "Divider" then
                NewPage.AddDivider()
            elseif type(c) == "boolean" then
                NewPage.CreateToggle(q, c, function(NewState: boolean)
                    Settings[i][q]  = NewState
                end)

            elseif type(c) == "number" then
                NewPage.CreateSlider(q, c, 1, q == "Egg Amount" and 99 or q == "Digging Range" and 16 or q == "TNT Delay" and 10 or 20, function(NewState: number)
                    Settings[i][q]  = NewState
                end)
            elseif type(c) == "string" and c == "Click" then
                NewPage.CreateButton(q)
            elseif type(c) == "string" then
                local MyTable   = {}
                
                if q == "Selected Egg" then
                    for _,v in ReplicatedStorage.__DIRECTORY.Eggs["Zone Eggs"]:GetChildren() do
                        local MyName    = v.Name:find("|")+2
                        table.insert(MyTable, v.Name:sub(MyName))
                    end
                elseif q == "Selected Flag" then
                    for _,v in ReplicatedStorage.__DIRECTORY.MiscItems.Flags:GetChildren() do
                        table.insert(MyTable, v.Name)
                    end
                end

                NewPage.CreateDropdown(q, c, MyTable, function(NewState: string)
                    Settings[i][q]  = NewState
                end)

            elseif typeof(c) == "EnumItem" then
                NewPage.CreateKeybind(q, c, function(NewState: EnumItem)
                    Settings[i][q]  = NewState
                end) 
            end
        end
    end
end

--  // Handle Keybind Inputs
UserInputService.InputBegan:Connect(function(Input: InputObject)
    if Input.KeyCode == Settings.Settings["Toggle UI"] then
        Library:ToggleUI()
    end
end)

--  // Handle Game Specific Events
local function SpoofFishing()
    for i,v in GameModules.Fishing do
        OldHooks[i] = v
    end
    
    GameModules.Fishing.IsFishInBar    = function(...)
        return Settings.Minigames["Auto Fish"] and math.random(1, 4) ~= 1 or OldHooks.IsFishInBar(...)
    end
    
    GameModules.Fishing.StartGame  = function(...) 
        GameStates.Fishing  = true
    
        return OldHooks.StartGame(...) 
    end
    
    GameModules.Fishing.StopGame   = function(...)
        GameStates.Fishing  = false
    
        return OldHooks.StopGame(...)
    end
end

Things.__INSTANCE_CONTAINER.Active.ChildAdded:Connect(function(Child: Instance)
    task.wait(0) -- Roblox doesn't automatically update names???

    local HasClientModule   = Child:FindFirstChild("ClientModule")

    if HasClientModule and not GameModules[Child.Name] then
        local HasGameModule = HasClientModule:FindFirstChildOfClass("ModuleScript")

        if HasGameModule then
            GameModules[Child.Name] = require(HasGameModule)

            if Child.Name == "Fishing" then
                SpoofFishing()
            end
        end
    end
end)

--  // AutoFisher
local function waitForGameState(state: boolean)
    repeat RunService.RenderStepped:Wait() until GameStates.Fishing == state
end

local function getRod()
    return Player.Character and Player.Character:FindFirstChild("Rod", true)
end

local function getBubbles(anchor: BasePart)
    local myBobber  = nil
    local myBubbles = false
    local closestBobber = math.huge

    for _,v in Active.Fishing.Bobbers:GetChildren() do
        local distance  = (v.Bobber.CFrame.Position-anchor.CFrame.Position).Magnitude

       if distance <= closestBobber then
            myBobber    = v.Bobber
            closestBobber   = distance
        end
    end

    if myBobber then
        for _,v in Debris:GetChildren() do
            if v.Name == "host" and v:FindFirstChild("Attachment") and (v.Attachment:FindFirstChild("Bubbles") or v.Attachment:FindFirstChild("Rare Bubbles")) and (v.CFrame.Position-myBobber.CFrame.Position).Magnitude <= 1 then
                myBubbles   = true

                break
            end
        end
    end

    return myBubbles
end

local function DoFish()
    if Active:FindFirstChild("Fishing") and not GameStates.Fishing then
        Network.Instancing_FireCustomFromClient:FireServer("Fishing", "RequestCast", Vector3.new(1158+math.random(-10, 10), 75, -3454+math.random(-10, 10)))

        local myAnchor  = getRod():WaitForChild("FishingLine").Attachment0
        repeat RunService.RenderStepped:Wait() until not Active:FindFirstChild("Fishing") or myAnchor and getBubbles(myAnchor) or GameStates.Fishing
        
        if Active:FindFirstChild("Fishing") then
            Network.Instancing_FireCustomFromClient:FireServer("Fishing", "RequestReel")
            waitForGameState(true)
            waitForGameState(false)
        end

        repeat RunService.RenderStepped:Wait() until not Active:FindFirstChild("Fishing") or getRod() and getRod().Parent.Bobber.Transparency <= 0
    end

    Cooldowns.Fishing = tick()
end

--  // Collect Item Drops
local function CollectDrops()
    Cooldowns.OrbCollect    = tick()

    local OrbChildren   = Things.Orbs:GetChildren()
    local BagChildren   = Things.Lootbags:GetChildren()

    local MyOrbDrops = {}

    for i,v in OrbChildren do
        MyOrbDrops[i]  = tonumber(v.Name)

        v:Destroy()
    end

    if #BagChildren > 0 and CollectBags then
        for _,v in BagChildren do
            CollectBags(v.Name)
        end
    elseif not CollectBags then
        CollectBags = getsenv(Player.PlayerScripts.Scripts.Game:WaitForChild("Lootbags Frontend")).Claim
    end
    
    if #OrbChildren > 0 then
        Network["Orbs: Collect"]:FireServer(MyOrbDrops)
    end
end

--  // Collect Daily Rewards
local function CollectDailies()
    Cooldowns.Daily = tick()

    local CachedCFrame  = Player.Character.HumanoidRootPart.CFrame
    for i,v in DailyRewards do
        local RealReward   = Workspace.Map:FindFirstChild(i, true)
        
        if RealReward and RealReward.Billboard.BillboardGui.Timer.Text:lower():find("claim") then
            Player.Character.HumanoidRootPart.CFrame    = RealReward.Pad.CFrame
            task.wait(0.5)

            Network.DailyRewards_Redeem:InvokeServer(i)
            task.wait(0.5)
        end
    end

    Player.Character.HumanoidRootPart.CFrame    = CachedCFrame
end

--  // Purchase Vending Items
local function PurchaseVenders()
    Cooldowns.Vending   = tick()

    local CachedCFrame  = Player.Character.HumanoidRootPart.CFrame
    for i,v in VendingMachines do
        local RealMachine   = Workspace.Map:FindFirstChild(i, true)

        if RealMachine and v.Stock and not RealMachine.VendingMachine.Screen.SurfaceGui.SoldOut.Visible then
            Player.Character.HumanoidRootPart.CFrame    = RealMachine.Pad.CFrame
            task.wait(0.5)
            
            for Purchase = 1, v.Stock do
                Network.VendingMachines_Purchase:InvokeServer(i, 1)

                task.wait(0.1)
            end
            task.wait(0.5)
        end
    end
    
    Player.Character.HumanoidRootPart.CFrame    = CachedCFrame
end

--  // Mining Aura
local function MineBlocks()
    Cooldowns.Dig   = tick()
    GameStates.Digging  = true

    local MyCoords  = Player.Character.HumanoidRootPart.CFrame.Position
    for _,v in Active.Digsite.Important.ActiveChests:GetChildren() do
        if (MyCoords-v.PrimaryPart.CFrame.Position).Magnitude <= Settings.Minigames["Digging Range"] then
            Network.Instancing_FireCustomFromClient:FireServer("Digsite", "DigChest", v:GetAttribute("Coord"))
        end
    end

    for _,v in Active.Digsite.Important.ActiveBlocks:GetChildren() do
        if (MyCoords-v.CFrame.Position).Magnitude <= Settings.Minigames["Digging Range"] then
            Network.Instancing_FireCustomFromClient:FireServer("Digsite", "DigBlock", v:GetAttribute("Coord"))
        end
    end

    GameStates.Digging  = false
end

--  // Get Closest Stairs For Stairway To Haven
local function GetClosestStairLevel()
    local myStep    = nil
    local currentLevel  = Player.Character.HumanoidRootPart.CFrame.Y
    local closestStair  = math.huge

    for _,c in Active.StairwayToHeaven.Stairs:GetDescendants() do
        if c:IsA("Part") and c.Size == Vector3.new(11, 1, 11) then
            local stepDiff  = c.CFrame.Y-currentLevel
            
            if stepDiff < closestStair and c.CFrame.Y > currentLevel then
                closestStair    = stepDiff
                myStep  = c
            end
        end
    end

    return myStep
end

--  // Do Custom AutoFarm
local function DoFarm()
    Cooldowns.Farm  = tick()

    local MyPets = ClientCmds.PlayerPet.GetAll()
    local CurrentClass  = "Normal"
    local ClosestTarget = 120

    if not FarmTarget or not FarmTarget.Parent then
        for _,v in Things.Breakables:GetChildren() do
            local ToDetect  = v:FindFirstChild("Hitbox", true)

            if ToDetect then
                local Distance = (Player.Character.HumanoidRootPart.CFrame.Position-ToDetect.CFrame.Position).Magnitude 

                if CurrentClass == "Normal" and Distance <= ClosestTarget or v:GetAttribute("BreakableClass") ~= "Normal" and Distance <= 120 then
                    FarmTarget    = v
                    CurrentClass    = v:GetAttribute("BreakableClass")
                    ClosestTarget   = Distance
                end
            end
        end
    end

    if FarmTarget then
        Network.Breakables_PlayerDealDamage:FireServer(tostring(FarmTarget.Name))

        for _,v in MyPets do
            ClientCmds.PlayerPet.SetTarget(v, FarmTarget)
        end
    end
end

--  // Setup
BuildUI()

--  // Main Loop
while RunService.RenderStepped:Wait() do
    if tick()-Cooldowns.Dig >= 0.05 and not GameStates.Digging and Settings.Minigames["Auto Dig"] and Active:FindFirstChild("Digsite") then
        task.spawn(function()
            pcall(MineBlocks)
        end)
    end

    if tick()-Cooldowns.Fishing >= 1.5 and GameModules.Fishing and not GameStates.Fishing and Settings.Minigames["Auto Fish"] then
        task.spawn(function()
            pcall(DoFish)
        end)
    end

    if tick()-Cooldowns.OrbCollect >= 1 and Settings.Automatics["Auto Collect Drops"] then
        task.spawn(function()
            pcall(CollectDrops)
        end)
    end

    if tick()-Cooldowns.PlaceFlag >= 1 and Settings.Automatics["Auto Place Flag"] then
        Cooldowns.PlaceFlag = tick()

        local MyFlag    = Settings.Automatics["Selected Flag"]

        if FlagIDs[MyFlag] then
            task.spawn(function()
                Network["Flags: Consume"]:InvokeServer(MyFlag, FlagIDs[MyFlag])
            end)
        end
    end

    if tick()-Cooldowns.OpenEggs >= 1 and Settings.Eggs["Auto Open Eggs"] then
        Cooldowns.OpenEggs  = tick()

        task.spawn(function()
            Network.Eggs_RequestPurchase:InvokeServer(Settings.Eggs["Selected Egg"], Settings.Eggs["Egg Amount"])
        end)
    end

    if tick()-Cooldowns.Vending >= 1 and Settings.Automatics["Auto Purchase Vending Machines"] then
       pcall(PurchaseVenders)
    end

    if tick()-Cooldowns.Daily >= 1 and Settings.Automatics["Auto Claim Dailies"] then
        pcall(CollectDailies)
    end

    if tick()-Cooldowns.Fruits >= 5 then
        Cooldowns.Fruits    = tick()

        task.spawn(function()
            for i,v in FruitIDs do
                if Settings.Fruits["Auto Eat "..i] and Settings.Fruits[i.." Amount"] then
                    Network["Fruits: Consume"]:FireServer(v, Settings.Fruits[i.." Amount"])

                    task.wait(0.5)
                end
            end
        end)
    end

    if tick()-Cooldowns.TNT >= Settings.Automatics["TNT Delay"]/10 and Settings.Automatics["Auto Drop TNT"] then
        Cooldowns.TNT   = tick()

        task.spawn(function()
            Network.TNT_Consume:InvokeServer()
        end)
    end

    if Settings.Minigames["Auto Stairs"] and Active:FindFirstChild("StairwayToHeaven") then
        local myStep    = GetClosestStairLevel()

        if myStep then
            Player.Character.Humanoid:MoveTo(myStep.CFrame.Position)
        end
    end

    if tick()-Cooldowns.Rewards and Settings.Automatics["Redeem Rewards"] then
        Cooldowns.Rewards   = tick()

        for _,v in Player.PlayerGui._MISC.FreeGifts.Frame.ItemsFrame.Gifts:GetChildren() do
            if v:FindFirstChild("Timer") and v.Timer.Text:lower():find("redeem") then
                local NewName   = v.Name:gsub("Gift", "")

                task.spawn(function()
                    Network:FindFirstChild("Redeem Free Gift"):InvokeServer(tonumber(NewName))
                end)
            end
        end
    end

    if tick()-Cooldowns.Ranks and Settings.Automatics["Redeem Rank Ups"] then
        Cooldowns.Ranks   = tick()

        for _,v in Player.PlayerGui.Rank.Frame.Rewards.Items.Unlocks:GetChildren() do
            if v.Name == "ClaimSlot" then
                task.spawn(function()
                    Network.Ranks_ClaimReward:FireServer(tonumber(v.Title.Text))
                end)
            end
        end
    end

    if tick()-Cooldowns.Farm >= 0.035 and Settings.Automatics["Autofarm Nearest"] then
        task.spawn(DoFarm)
    elseif not Settings.Automatics["Autofarm Nearest"] then
        FarmTarget  = nil
    end
end
