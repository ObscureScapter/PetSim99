--  services

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService    = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
}
local GameModules   = {}
local GameStates    = {
    Fishing = false,
    Digging = false,
}
local EggHatching   = getsenv(Player.PlayerScripts.Scripts.Game:WaitForChild("Egg Opening Frontend"))
local CollectBags   = getsenv(Player.PlayerScripts.Scripts.Game:WaitForChild("Lootbags Frontend")).Claim
local OldHooks= {}
local VendingMachines   = require(ReplicatedStorage.Library.Directory.VendingMachines)
local VendingMachineCooldowns   = {}
local DailyRewards  = {}
local DailyRewardsCooldowns = {}
local FlagIDs   = {
    ["Coins Flag"]   = "afb269f6d8e34907af6d8bd34564c403",
    ["Magnet Flag"]  = "f7ccf7845bbd4ea284817a744be2a733",
    ["Hasty Flag"]    = "aebc5b01e2954e50a6a1db81256a696e",
    ["Diamonds Flag"]    = "9320347d09394ae59aa3b1dc6d9dc1fd",
    ["Fortune Flag"]    = "0ef83c417b88463abeb9862a5a4a4149",
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
        {"Auto Collect Drops", false},
        {"Auto Claim Dailies", false},
        {"Auto Purchase Vending Machines", false},
    }},
    {"Flags", {
        {"Selected Flag",  "Coins Flag"},
        {"Auto Place Flag", false},
    }},
    {"Minigames", {
        {"Auto Fish", false},
        {"Auto Dig", false},
        {"Digging Range", 16}
    }},
    {"Eggs", {
        {"Auto Open Eggs", false},
        {"Remove Egg Animation", false},
        {"Selected Egg", "Cracked Egg"},
        {"Egg Amount", 1},
    }},
    {"Fruits", {
        {"Auto Eat Apple", false},
        {"Apple Amount", 10},
        {"Auto Eat Banana", false},
        {"Banana Amount", 10},
        {"Auto Eat Orange", false},
        {"Orange Amount", 10},
        {"Auto Eat Pineapple", false},
        {"Pineapple Amount", 10},
        {"Auto Eat Rainbow", false},
        {"Rainbow Amount", 10},
    }},
    {"Settings", {
        {"Toggle UI", Enum.KeyCode.P},
    }},
}
local CollectStates = {
    Dailies = false,
    Vendors = false,
}

--  functions

--  // Anti-AFK
for _,v in getconnections(Player.Idled) do
    v:Disable()
end

--  // Hook Egg Animation
OldHooks.PlayEggAnimation   = EggHatching.PlayEggAnimation
EggHatching.PlayEggAnimation    = function(...)
    if not Settings.Eggs["Remove Egg Animation"] then
        return OldHooks.PlayEggAnimation(...)
    end
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
            if type(c) == "boolean" then
                NewPage.CreateToggle(q, c, function(NewState: boolean)
                    Settings[i][q]  = NewState
                end)

            elseif type(c) == "number" then
                NewPage.CreateSlider(q, c, 1, q == "Egg Amount" and 99 or q == "Digging Range" and 16 or 20, function(NewState: number)
                    Settings[i][q]  = NewState
                end)

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
        return Settings.Minigames["Auto Fish"] and math.random(1, 6) ~= 1 or OldHooks.IsFishInBar(...)
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
        MyOrbDrops[i]  = {v.Name}
    end

    if #BagChildren > 0 and CollectBags then
        for _,v in BagChildren do
            CollectBags(v.Name)
        end
    end
    if #OrbChildren > 0 then
        Network.Orbs_ClaimMultiple:FireServer(MyOrbDrops)
    end
end

--  // Collect Daily Rewards
local function CollectDailies()
    CollectStates.Dailies   = true
    Cooldowns.Daily = tick()

    local CachedCFrame  = Player.Character.HumanoidRootPart.CFrame
    for i,v in DailyRewards do
        if not DailyRewardsCooldowns[i] or tick()-DailyRewardsCooldowns[i] >= v.Cooldown then
            DailyRewardsCooldowns[i]  = tick()
            
            local RealReward   = Workspace.Map:FindFirstChild(i, true)
            if RealReward then
                Player.Character.HumanoidRootPart.CFrame    = RealReward.Pad.CFrame
                task.wait(0.3)

                Network.DailyRewards_Redeem:InvokeServer(i)
                task.wait(0.3)
            end
        end
    end

    Player.Character.HumanoidRootPart.CFrame    = CachedCFrame
    CollectStates.Dailies   = false
end

--  // Purchase Vending Items
local function PurchaseVenders()
    CollectStates.Vendors   = true
    Cooldowns.Vending   = tick()

    local CachedCFrame  = Player.Character.HumanoidRootPart.CFrame
    for i,v in VendingMachines do
        if not VendingMachineCooldowns[i] or tick()-VendingMachineCooldowns[i] >= v.RestockTime then
            VendingMachineCooldowns[i]  = tick()
            
            local RealMachine   = Workspace.Map:FindFirstChild(i, true)
            if RealMachine then
                Player.Character.HumanoidRootPart.CFrame    = RealMachine.Pad.CFrame
                task.wait(0.3)
                
                for Purchase = 1, 4 do
                    Network.VendingMachines_Purchase:InvokeServer(i, 1)

                    task.wait(0.1)
                end
                task.wait(0.3)
            end
        end
    end
    
    Player.Character.HumanoidRootPart.CFrame    = CachedCFrame
    CollectStates.Vendors   = false
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

    if tick()-Cooldowns.OrbCollect >= 0.5 and Settings.Automatics["Auto Collect Drops"] then
        pcall(CollectDrops)
    end

    if tick()-Cooldowns.PlaceFlag >= 5 and Settings.Flags["Auto Place Flag"] then
        Cooldowns.PlaceFlag = tick()

        local MyFlag    = Settings.Flags["Selected Flag"]

        if FlagIDs[MyFlag] then
            Network["Flags: Consume"]:InvokeServer(MyFlag, FlagIDs[MyFlag])
        end
    end

    if tick()-Cooldowns.OpenEggs >= 1 and Settings.Eggs["Auto Open Eggs"] then
        Cooldowns.OpenEggs  = tick()
        Network.Eggs_RequestPurchase:InvokeServer(Settings.Eggs["Selected Egg"], Settings.Eggs["Egg Amount"])
    end

    if tick()-Cooldowns.Vending >= 5 and Settings.Automatics["Auto Purchase Vending Machines"] and not CollectStates.Dailies and not CollectStates.Vendors then
       pcall(PurchaseVenders)
    end

    if tick()-Cooldowns.Daily >= 5 and Settings.Automatics["Auto Claim Dailies"] and not CollectStates.Vendors and not CollectStates.Dailies then
        pcall(CollectDailies)
    end

    if tick()-Cooldowns.Fruits >= 1 then
        Cooldowns.Fruits    = tick()

        for i,v in FruitIDs do
            if Settings.Fruits["Auto Eat "..i] then
                Network["Fruits: Consume"]:FireServer(v, Settings.Fruits[i.." Amount"])
            end
        end
    end
end
