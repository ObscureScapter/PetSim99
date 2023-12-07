--	services

local Players	= game:GetService("Players")
local CoreGui	= game:GetService("CoreGui")
local RunService	= game:GetService("RunService")
local TweenService	= game:GetService("TweenService")
local UserInputService	= game:GetService("UserInputService")

--	variables

local Player	= Players.LocalPlayer
local Assets	= RunService:IsStudio() and script:WaitForChild("Assets") or game:GetObjects("rbxassetid://15561945238")[1]
local UI	= Assets.ScapLib
local Tab	= Assets.Tab
local Page	= Assets.Page
local Input	= Assets.Input
local Slider	= Assets.Slider
local Toggle	= Assets.Toggle
local Dropdown	= Assets.Dropdown
local Keybind	= Assets.Keybind
local Divider	= Assets.Divider
local Library = {}
local FirstPage	= false
local PageCount	= 0
local TabTweens	= {}
local CurrentPage	= 0

--	functions

local function GetUIParent()
	local Success	= pcall(function() return CoreGui.Name end)
	
	return not Success and Player:WaitForChild("PlayerGui") or CoreGui
end

local function ChangePage(PageOffset: number, Tab: TextButton)
	UI.Base.Pages.Slide:TweenPosition(UDim2.new(PageOffset * -1, 0, 0, 0), "Out", "Linear", 0.2, true)
	
	for i,v in TabTweens do
		if i == Tab then
			v.Closed:Pause()
			v.Opened:Play()
			i.Highlight:TweenSize(UDim2.new(0.7, 0, 0.05, 0), "Out", "Sine", 0.2, true)
		else
			v.Opened:Pause()
			v.Closed:Play()
			i.Highlight:TweenSize(UDim2.new(0, 0, 0.05, 0), "Out", "Sine", 0.2, true)
		end
	end
end

--	// Handle Window Dragging
UI.Base.Ignore.Drag.MouseButton1Down:Connect(function()
	local StartingPos	= UserInputService:GetMouseLocation()
	local UIStart	= UI.Base.Position
	
	task.wait(0.3)
	while RunService.RenderStepped:Wait() and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
		local NewPosition	= UserInputService:GetMouseLocation()
		local DragOffset	= (NewPosition-StartingPos)
		local OffsetX	= (DragOffset.X/UI.Base.Pages.Slide.AbsoluteSize.X)/2.5
		local OffsetY	= (DragOffset.Y/UI.Base.Pages.Slide.AbsoluteSize.Y)/2.5
		
		UI.Base:TweenPosition(UIStart + UDim2.new(OffsetX, 0, OffsetY, 0), "Out", "Linear", 0.1, true)
	end
end)

function Library:CreatePage(PageName: string)
	local MyPage	= PageCount
	local NewPage	= {}
	
	--	// Building Visuals
	local TabVisual	= Tab:Clone()
	TabVisual.LayoutOrder	= MyPage
	TabVisual.Visible	= true
	TabVisual.Highlight.BackgroundColor3	= not FirstPage and Color3.fromRGB(85, 255, 127) or TabVisual.Highlight.BackgroundColor3
	TabVisual.Highlight.Size	= UDim2.new(not FirstPage and 0.6 or 0, 0, 0.05, 0)
	TabVisual.Text	= PageName
	TabVisual.Parent	= UI.Base.Tabs
	
	local PageVisual	= Page:Clone()
	PageVisual.Parent	= UI.Base.Pages.Slide
	
	TabTweens[TabVisual]	= {
		Opened	= TweenService:Create(TabVisual.Highlight, TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
			BackgroundColor3	= Color3.fromRGB(85, 255, 127)
		}),
		Closed	= TweenService:Create(TabVisual.Highlight, TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
			BackgroundColor3	= Color3.fromRGB(85, 170, 255)
		}),
	}
	
	--	// Handle Tab Visual Effects
	TabVisual.MouseEnter:Connect(function()
		TabVisual.Highlight:TweenSize(UDim2.new(MyPage == CurrentPage and 0.7 or 0.6, 0, 0.05, 0), "Out", "Sine", 0.2, true)
	end)
	TabVisual.MouseLeave:Connect(function()
		TabVisual.Highlight:TweenSize(UDim2.new(MyPage == CurrentPage and 0.5 or 0, 0, 0.05, 0), "Out", "Sine", 0.2, true)
	end)
	
	TabVisual.MouseButton1Down:Connect(function()
		CurrentPage	= MyPage
		
		ChangePage(MyPage, TabVisual)
	end)
	
	if not FirstPage then
		FirstPage	= true
		UI.Parent	= GetUIParent()
	end
	
	--	// Add Dividers For Sub-Categories
	NewPage.AddDivider	= function()
		local DividerVisual	= Assets.Divider:Clone()
		DividerVisual.Parent	= PageVisual
	end
	
	--	// Handle Keybind Inputs
	NewPage.CreateKeybind	= function(Description: string, Key: Enum.KeyCode, Callback: any)
		local KeybindVisual	= Keybind:Clone()
		KeybindVisual.Description.Text	= Description
		KeybindVisual.Click.Text	= tostring(Key):gsub("Enum.KeyCode.", "")
		KeybindVisual.Parent	= PageVisual
		
		KeybindVisual.Click.MouseButton1Down:Connect(function()
			KeybindVisual.Click.Text	= "..."
			
			local WaitForInput
			WaitForInput	= UserInputService.InputBegan:Connect(function(Input: InputObject)
				if Input and Input.KeyCode and Input.KeyCode ~= Enum.KeyCode.Unknown then
					Key	= Input.KeyCode
					KeybindVisual.Click.Text	= tostring(Key):gsub("Enum.KeyCode.", "")
					
					if Callback then
						task.wait(0.1)
						
						Callback(Key)
					end
					
					WaitForInput:Disconnect()
				end
			end)
		end)
	end
	
	--	// Handle Dropdowns
	NewPage.CreateDropdown	= function(Description: string, Selected: string, Entries: table, Callback: any)
		local IsOpen	= false
		local isClosing	= false
		local DropdownSendback	= {}
		local EntryButtons	= {}
		
		local DropdownVisual	= Dropdown:Clone()
		DropdownVisual.Click.Text	= Selected
		DropdownVisual.Description.Text	= Description
		DropdownVisual.Parent	= PageVisual
		
		local ArrowOpen	= TweenService:Create(DropdownVisual.Click.Drop, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
			Rotation	= 180,
		})
		local ArrowClose	= TweenService:Create(DropdownVisual.Click.Drop, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
			Rotation	= 0,
		})
		
		local function Close()
			IsOpen	= false
			
			if not isClosing	 then
				isClosing	= true
				DropdownVisual.Click.List:TweenSize(UDim2.new(0.9, 0, 0, 0), "Out", "Linear", 0.1, true)

				task.wait(0.1)
				if not IsOpen then
					DropdownVisual.Click.List.Visible	= false
				end
				isClosing	= false
			end

			ArrowOpen:Pause()
			ArrowClose:Play()
		end
		
		local function CreateEntry(Entry: string)
			local NewEntry	= Assets.Entry:Clone()
			NewEntry.Text	= Entry
			NewEntry.Parent	= DropdownVisual.Click.List

			NewEntry.MouseButton1Down:Connect(function()
				DropdownVisual.Click.Text	= Entry

				Callback(Entry)
				Close()
			end)
			
			EntryButtons[Entry]	= NewEntry
		end
		
		for _,v in Entries do
			CreateEntry(v)
		end
		
		DropdownVisual.Click.MouseButton1Down:Connect(function()
			IsOpen	= not IsOpen
			
			if IsOpen then
				DropdownVisual.Click.List.Visible	= true
				DropdownVisual.Click.List:TweenSize(UDim2.new(0.9, 0, 9, 0), "Out", "Linear", 0.1, true)
				
				ArrowClose:Pause()
				ArrowOpen:Play()
			else
				Close()
			end
		end)
		
		function DropdownSendback:NewEntry(Entry: string)
			if not table.find(EntryButtons, Entry) then
				CreateEntry(Entry)
			end
		end
		
		function DropdownSendback:RemoveEntry(Entry: string)
			if EntryButtons[Entry] then
				EntryButtons[Entry]:Destroy()
				EntryButtons[Entry]	= nil
			end
		end
		
		return DropdownSendback
	end	
		
	--	// Handle Sliders
	NewPage.CreateSlider	= function(Description: string, Start: number, Minimum: number, Maximum: number, Callback: any)
		local SliderVisual	= Slider:Clone()
		SliderVisual.Slider.Filler.Size	= UDim2.new(Start/Maximum, 0, 1, 0)
		SliderVisual.Slider.Progress.Text	= Start.."/"..Maximum
		SliderVisual.Description.Text	= Description
		SliderVisual.Parent	= PageVisual

		local function doSlide()
			while UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and RunService.RenderStepped:Wait() do
				local MousePos	= UserInputService:GetMouseLocation()
				local RelativeUI	= (MousePos-SliderVisual.Slider.AbsolutePosition)
				local NewX	= math.clamp(RelativeUI.X, 0, SliderVisual.Slider.AbsoluteSize.X)
				local ToScale	= NewX/SliderVisual.Slider.AbsoluteSize.X
				Start	= math.clamp(math.floor(Maximum*ToScale), Minimum, Maximum)
				
				SliderVisual.Slider.Progress.Text	= Start.."/"..Maximum
				SliderVisual.Slider.Filler:TweenSize(UDim2.new(ToScale, 0, 0.85, 0), "Out", "Linear", 0.1, true)
				
				if Callback then
					Callback(Start)
				end
			end
		end
		
		SliderVisual.Slider.MouseButton1Down:Connect(function()
			doSlide()
		end)
	end
	
	--	// Handle InputBoxes
	NewPage.CreateInput	= function(Description: string, Default: string, Callback: any)
		local InputVisual	= Input:Clone()
		InputVisual.Description.Text	= Description
		InputVisual.Click.PlaceholderText	= Default
		InputVisual.Parent	= PageVisual

		InputVisual.Click.FocusLost:Connect(function()
			if Callback then
				Callback(InputVisual.Click.Text)
			end
		end)
	end
	
	--	// Handle Toggle Buttons
	NewPage.CreateToggle	= function(Description: string, Status: boolean, Callback: any)
		local ToggleVisual	= Toggle:Clone()
		ToggleVisual.Description.Text	= Description
		ToggleVisual.Click.UIStroke.Color	= Status and Color3.fromRGB(85, 255, 127) or Color3.fromRGB(255, 85, 127)


		local OnTween	= TweenService:Create(ToggleVisual.Click.UIStroke, TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
			Color	= Color3.fromRGB(85, 255, 127)
		})
		local OffTween	= TweenService:Create(ToggleVisual.Click.UIStroke, TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
			Color	= Color3.fromRGB(255, 85, 127)
		})
		
		local OnGradientTween	= TweenService:Create(ToggleVisual.Toggled.UIGradient, TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
			Offset	= Vector2.new(0, 0)
		})
		local OffGradientTween	= TweenService:Create(ToggleVisual.Toggled.UIGradient, TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {
			Offset	= Vector2.new(1, 0)
		})

		local StateChange	= Instance.new("BoolValue")
		StateChange.Value	= Status
		StateChange:GetPropertyChangedSignal("Value"):Connect(function()
			if StateChange.Value then
				OffTween:Pause()
				OffGradientTween:Pause()
				
				OnTween:Play()
				OnGradientTween:Play()
			else
				OnTween:Pause()
				OnGradientTween:Pause()
				
				OffTween:Play()
				OffGradientTween:Play()
			end
		end)

		ToggleVisual.Click.MouseButton1Down:Connect(function()
			Status	= not Status
			StateChange.Value	= Status

			if Callback then
				Callback(Status)
			end
		end)

		ToggleVisual.Parent	= PageVisual
	end
	
	PageCount	+= 1
	return NewPage
end

--	// Handle UI Hiding
function Library:ToggleUI()
	UI.Enabled	= not UI.Enabled
end

return Library
