local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ScreenGui = PlayerGui:WaitForChild("TDSHub")
local ManageProgramFrame = ScreenGui:WaitForChild("ManageProgramFrame")
local Executor = ScreenGui:WaitForChild("Executor")

--// SETTINGS FRAMES
local PlaceSetting = ScreenGui:WaitForChild("PlaceSetting")
local UpgradeSetting = ScreenGui:WaitForChild("UpgradeSetting")
local UpgradeAllSetting = ScreenGui:WaitForChild("UpgradeAllSetting")
local SellSetting = ScreenGui:WaitForChild("SellSetting")
local WaitSetting = ScreenGui:WaitForChild("WaitSetting")

--// PLACE
local PlaceTowerField = PlaceSetting:WaitForChild("Tower")
local AddPositionButton = PlaceSetting:WaitForChild("AddPositionButton")
local PositionFrame = PlaceSetting:WaitForChild("Position")
local PositionSample = PositionFrame:WaitForChild("PositionSample")
local PlaceSaveButton = PlaceSetting:WaitForChild("SaveButton")
local PlaceCancelButton = PlaceSetting:WaitForChild("CancelButton")
local PlaceSettingActivePosition = UDim2.new(0.18, 0, 0.835, 0)
local PlaceSettingDefaultPosition = UDim2.new(0.18, 0, 0.5, 0)
local MoveTweenInfo = TweenInfo.new(
	0.25,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)

--// UPGRADE
local UpgradeTowerField = UpgradeSetting:WaitForChild("Tower")
local UpgradeLevelTargetField = UpgradeSetting:WaitForChild("LevelTarget")
local UpgradeOrtherField = UpgradeSetting:WaitForChild("Orther")
local UpgradeIntervalField = UpgradeSetting:WaitForChild("Interval")
local UpgradeBranchButton = UpgradeSetting:WaitForChild("Branch")
local UpgradeSaveButton = UpgradeSetting:WaitForChild("SaveButton")
local UpgradeCancelButton = UpgradeSetting:WaitForChild("CancelButton")

--// UPGRADE ALL
local UpgradeAllTowerField = UpgradeAllSetting:WaitForChild("Tower")
local UpgradeAllLevelTargetField = UpgradeAllSetting:WaitForChild("LevelTarget")
local UpgradeAllOneByOneButton = UpgradeAllSetting:WaitForChild("One_by_one")
local UpgradeAllIntervalField = UpgradeAllSetting:WaitForChild("Interval")
local UpgradeAllBranchButton = UpgradeAllSetting:WaitForChild("Branch")
local UpgradeAllSaveButton = UpgradeAllSetting:WaitForChild("SaveButton")
local UpgradeAllCancelButton = UpgradeAllSetting:WaitForChild("CancelButton")

--// SELL
local SellTowerField = SellSetting:WaitForChild("Tower")
local SellIntervalField = SellSetting:WaitForChild("Interval")
local SellOrtherTextbox = SellSetting:WaitForChild("OrtherTextbox")
local SellOrtherButton = SellSetting:WaitForChild("OrtherButton")
local SellSaveButton = SellSetting:WaitForChild("SaveButton")
local SellCancelButton = SellSetting:WaitForChild("CancelButton")

--// WAIT
local WaitModeButton = WaitSetting:WaitForChild("Mode")
local WaitValueField = WaitSetting:WaitForChild("Value")
local WaitSaveButton = WaitSetting:WaitForChild("SaveButton")
local WaitCancelButton = WaitSetting:WaitForChild("CancelButton")

PositionSample.Visible = false

local AddPositionShadow = AddPositionButton:FindFirstChild("ShadowFrame")
local AddPositionStroke = AddPositionButton:FindFirstChildWhichIsA("UIStroke")

local SettingFrames = {
	place = PlaceSetting,
	upgrade = UpgradeSetting,
	upgrade_all = UpgradeAllSetting,
	sell = SellSetting,
	wait = WaitSetting,
}

local CurrentKey = nil
local CurrentIndex = nil
local CurrentStep = nil
local CurrentType = nil
local CurrentDraft = nil
local CaptureArmed = false
local CaptureReady = false
local PositionButtons = {}

local function Console(title, text, color)
	if type(_G.TDSHubConsole) ~= "function" then
		return
	end

	pcall(function()
		_G.TDSHubConsole({
			Title = title,
			Text = text,
			Color = color or Color3.fromRGB(180, 150, 180),
		})
	end)
end

local function DeepCopy(value, seen)
	if type(value) ~= "table" then
		return value
	end

	seen = seen or {}
	if seen[value] then
		return seen[value]
	end

	local copy = {}
	seen[value] = copy
	for k, v in pairs(value) do
		copy[DeepCopy(k, seen)] = DeepCopy(v, seen)
	end
	return copy
end

local function ClampNumText(v, default)
	local n = tonumber(v)
	return n or default
end

local function Trim(str)
	if not str then
		return ""
	end
	return string.match(str, "^%s*(.-)%s*$")
end

local function GetPlaceCapturePosition()
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end

	local mousePos = UserInputService:GetMouseLocation()
	local ray = cam:ViewportPointToRay(mousePos.X, mousePos.Y)

	local ignore = { cam }

	local char = LocalPlayer.Character
	if char then
		ignore[#ignore + 1] = char
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true

	local result = workspace:Raycast(ray.Origin, ray.Direction * 10000, params)
	return result and result.Position or nil
end

local function VecToText(v)
	return ("%s, %s, %s"):format(
		string.format("%.2f", v.X):gsub("%.?0+$", ""),
		string.format("%.2f", v.Y):gsub("%.?0+$", ""),
		string.format("%.2f", v.Z):gsub("%.?0+$", "")
	)
end

local function GetProgramStepsRef()
	local steps = rawget(_G, "TDSHubProgramSteps")
	if type(steps) == "table" then
		return steps
	end

	local builder = rawget(_G, "TDSHubCustomProgramBuilder")
	if builder and type(builder.GetProgramRef) == "function" then
		local ok, result = pcall(builder.GetProgramRef)
		if ok and type(result) == "table" then
			return result
		end
	end

	return nil
end

local function FindStepByKey(key)
	local steps = GetProgramStepsRef()
	if not steps then
		return nil, nil
	end

	if type(key) == "number" then
		return steps[key], key
	end

	for i, step in ipairs(steps) do
		if tostring(step.id) == tostring(key) then
			return step, i
		end
	end

	return nil, nil
end

local function GetFrameForType(stepType)
	return SettingFrames[stepType]
end

local function HideAllFrames()
	for _, frame in pairs(SettingFrames) do
		if frame and frame:IsA("GuiObject") then
			frame.Visible = false
		end
	end
end

local function ShowFrame(frame)
	HideAllFrames()
	if frame and frame:IsA("GuiObject") then
		frame.Visible = true
	end
end

local function ClearPositionButtons()
	for _, child in ipairs(PositionFrame:GetChildren()) do
		if child:IsA("GuiButton") and child.Name:match("^Position%d+$") then
			child:Destroy()
		end
	end
	PositionButtons = {}
end

local function SyncPositionCanvas()
	local count = (CurrentDraft and CurrentDraft.positions and #CurrentDraft.positions) or 0
	PositionFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(0, count * 21))
end

local function SetAddPositionState(on)
	CaptureArmed = on == true

	if AddPositionShadow then
		AddPositionShadow.Transparency = CaptureArmed and 0.25 or 1
	end

	if AddPositionStroke then
		AddPositionStroke.Enabled = CaptureArmed
	end

	local mouse = LocalPlayer:GetMouse()
	local cam = workspace.CurrentCamera
	local preview = cam and cam:FindFirstChild("PlacePreview") -- đổi tên này theo model của bạn
	mouse.TargetFilter = CaptureArmed and preview or nil

	local targetPos = CaptureArmed and PlaceSettingActivePosition or PlaceSettingDefaultPosition
	TweenService:Create(PlaceSetting, MoveTweenInfo, { Position = targetPos }):Play()

	if CaptureArmed then
		CaptureReady = false
		task.defer(function()
			CaptureReady = true
		end)
	else
		CaptureReady = false
	end
end

local function RefreshPositionList()
	ClearPositionButtons()
	if not CurrentDraft or type(CurrentDraft.positions) ~= "table" then
		CurrentDraft.positions = {}
	end

	for index, pos in ipairs(CurrentDraft.positions) do
		local clone = PositionSample:Clone()
		clone.Name = "Position" .. index
		clone.Visible = true
		clone.LayoutOrder = index
		clone.Position = UDim2.new(0, 0, 0, (index - 1) * 21)
		clone.Text = VecToText(pos)
		clone.Parent = PositionFrame
		PositionButtons[index] = clone

		clone.MouseButton1Click:Connect(function()
			table.remove(CurrentDraft.positions, index)
			RefreshPositionList()
		end)
	end

	SyncPositionCanvas()
end

local function BranchToText(branch)
	return tonumber(branch) == 2 and "Below" or "Above"
end

local function TextToBranch(text)
	text = Trim(text)
	return text == "Below" and 2 or 1
end

local function BoolToOneByOneText(v)
	return v and "On" or "Off"
end

local function OneByOneTextToBool(text)
	text = Trim(text)
	return text == "On"
end

local function ModeToText(mode)
	mode = string.lower(Trim(mode))
	return mode == "wave" and "Wave" or "Second"
end

local function TextToMode(text)
	text = string.lower(Trim(text))
	return text == "wave" and "wave" or "sec"
end

local function OrderToText(order)
	if order == nil or order == "all" then
		return "All"
	end
	return tostring(order)
end

local function TextToOrder(text)
	text = string.lower(Trim(text))
	if text == "" or text == "all" or text == "nil" then
		return nil
	end
	return tonumber(text)
end

local function SyncUpgradeBranch(button, branch)
	if button and button:IsA("TextButton") then
		button.Text = BranchToText(branch)
	end
end

local function SyncOneByOne(button, v)
	if button and button:IsA("TextButton") then
		button.Text = BoolToOneByOneText(v)
	end
end

local function SyncSellOrder(textbox, order)
	if textbox and textbox:IsA("TextBox") then
		textbox.Text = OrderToText(order)
	end
end

local function SyncWaitMode(button, mode)
	if button and button:IsA("TextButton") then
		button.Text = ModeToText(mode)
	end
end

local function LoadPlaceSetting(data)
	PlaceTowerField.Text = data.tower or ""
	CurrentDraft.positions = DeepCopy(data.positions or {})
	RefreshPositionList()
end

local function LoadUpgradeSetting(data)
	UpgradeTowerField.Text = data.tower or data.tower_name or ""
	UpgradeLevelTargetField.Text = tostring(data.level_target or 1)
	UpgradeOrtherField.Text = tostring(data.order or 1)
	UpgradeIntervalField.Text = tostring(data.interval or 0.3)
	SyncUpgradeBranch(UpgradeBranchButton, data.branch or 1)
end

local function LoadUpgradeAllSetting(data)
	UpgradeAllTowerField.Text = data.tower_name or data.tower or ""
	UpgradeAllLevelTargetField.Text = tostring(data.level_target or 1)
	UpgradeAllIntervalField.Text = tostring(data.interval or 0.3)
	SyncUpgradeBranch(UpgradeAllBranchButton, data.branch or 1)
	SyncOneByOne(UpgradeAllOneByOneButton, data.one_by_one == true)
end

local function LoadSellSetting(data)
	SellTowerField.Text = data.tower_name or data.tower or ""
	SellIntervalField.Text = tostring(data.interval or 0.2)
	SyncSellOrder(SellOrtherTextbox, data.order)
end

local function LoadWaitSetting(data)
	SyncWaitMode(WaitModeButton, data.mode or "sec")
	WaitValueField.Text = tostring(data.value or 0)
end

local function CloseSetting()
	SetAddPositionState(false)
	CurrentKey = nil
	CurrentIndex = nil
	CurrentStep = nil
	CurrentType = nil
	CurrentDraft = nil
	HideAllFrames()
	ManageProgramFrame.Visible = true
end

local function CommitToProgram()
	local steps = GetProgramStepsRef()
	if not steps or not CurrentStep or CurrentIndex == nil then
		return false
	end

	local target = steps[CurrentIndex]
	if not target then
		return false
	end

	for k in pairs(target) do
		if k ~= "id" then
			target[k] = nil
		end
	end

	for k, v in pairs(CurrentDraft) do
		if k ~= "id" and k ~= "_order_nil" then
			target[k] = DeepCopy(v)
		end
	end

	if CurrentDraft._order_nil then
		target.order = nil
	end

	if _G.TDSHubCustomProgramBuilder and _G.TDSHubCustomProgramBuilder.Rebuild then
		pcall(function()
			_G.TDSHubCustomProgramBuilder.Rebuild()
		end)
	end

	if _G.TDSHubProgramOutputRebuild then
		pcall(_G.TDSHubProgramOutputRebuild)
	end

	return true
end

local function SaveSetting()
	if not CurrentStep or not CurrentDraft then
		return
	end

	if CurrentType == "place" then
		CurrentDraft.tower = Trim(PlaceTowerField.Text)
		CurrentDraft.positions = DeepCopy(CurrentDraft.positions or {})

	elseif CurrentType == "upgrade" then
		CurrentDraft.tower = Trim(UpgradeTowerField.Text)
		CurrentDraft.level_target = ClampNumText(UpgradeLevelTargetField.Text, 1)
		CurrentDraft.order = ClampNumText(UpgradeOrtherField.Text, 1)
		CurrentDraft.interval = ClampNumText(UpgradeIntervalField.Text, 0.3)
		CurrentDraft.branch = TextToBranch(UpgradeBranchButton.Text)

	elseif CurrentType == "upgrade_all" then
		CurrentDraft.tower_name = Trim(UpgradeAllTowerField.Text)
		CurrentDraft.level_target = ClampNumText(UpgradeAllLevelTargetField.Text, 1)
		CurrentDraft.interval = ClampNumText(UpgradeAllIntervalField.Text, 0.3)
		CurrentDraft.branch = TextToBranch(UpgradeAllBranchButton.Text)
		CurrentDraft.one_by_one = OneByOneTextToBool(UpgradeAllOneByOneButton.Text)

	elseif CurrentType == "sell" then
		CurrentDraft.tower_name = Trim(SellTowerField.Text)
		CurrentDraft.interval = ClampNumText(SellIntervalField.Text, 0.2)
		local order = TextToOrder(SellOrtherTextbox.Text)
		if order == nil then
			CurrentDraft.order = nil
			CurrentDraft._order_nil = true
		else
			CurrentDraft.order = order
			CurrentDraft._order_nil = nil
		end

	elseif CurrentType == "wait" then
		CurrentDraft.mode = TextToMode(WaitModeButton.Text)
		CurrentDraft.value = ClampNumText(WaitValueField.Text, 0)
	end

	local ok = CommitToProgram()
	if not ok then
		Console("System", "Save failed", Color3.fromRGB(255, 0, 0))
		return
	end

	Console("System", "Saved", Color3.fromRGB(0, 255, 0))
	CloseSetting()
end

local function OpenSetting(programKey)
	local step, index = FindStepByKey(programKey)
	if not step then
		Console("System", "Setting not found", Color3.fromRGB(255, 0, 0))
		return false, "Setting not found"
	end

	CurrentKey = programKey
	CurrentIndex = index
	CurrentStep = step
	CurrentType = step.type
	CurrentDraft = DeepCopy(step)

	if type(_G.TDSHubRunning) == "boolean" and _G.TDSHubRunning then
		return false, "Running"
	end

	SetAddPositionState(false)
	ManageProgramFrame.Visible = false

	local frame = GetFrameForType(CurrentType)
	if not frame then
		Console("System", "Missing frame: " .. tostring(CurrentType), Color3.fromRGB(255, 0, 0))
		ManageProgramFrame.Visible = true
		return false, "Missing frame"
	end

	if CurrentType == "place" then
		LoadPlaceSetting(CurrentDraft)
	elseif CurrentType == "upgrade" then
		LoadUpgradeSetting(CurrentDraft)
	elseif CurrentType == "upgrade_all" then
		LoadUpgradeAllSetting(CurrentDraft)
	elseif CurrentType == "sell" then
		LoadSellSetting(CurrentDraft)
	elseif CurrentType == "wait" then
		LoadWaitSetting(CurrentDraft)
	end

	ShowFrame(frame)
	return true
end

local function ToggleAddPosition()
	if not CurrentDraft or CurrentType ~= "place" then
		return
	end

	SetAddPositionState(not CaptureArmed)
end

local function CaptureWorldPosition()
	if not CaptureArmed or not CaptureReady then
		return
	end
	if not CurrentDraft or CurrentType ~= "place" then
		return
	end

	local pos = GetPlaceCapturePosition()
	if not pos then
		return
	end

	CurrentDraft.positions = CurrentDraft.positions or {}
	table.insert(CurrentDraft.positions, pos)
	RefreshPositionList()
	SetAddPositionState(false)
end

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		CaptureWorldPosition()
	end
end)

UpgradeBranchButton.MouseButton1Click:Connect(function()
	local t = UpgradeBranchButton.Text
	UpgradeBranchButton.Text = (t == "Above") and "Below" or "Above"
end)

UpgradeAllBranchButton.MouseButton1Click:Connect(function()
	local t = UpgradeAllBranchButton.Text
	UpgradeAllBranchButton.Text = (t == "Above") and "Below" or "Above"
end)

UpgradeAllOneByOneButton.MouseButton1Click:Connect(function()
	local t = UpgradeAllOneByOneButton.Text
	UpgradeAllOneByOneButton.Text = (t == "On") and "Off" or "On"
end)

SellOrtherButton.MouseButton1Click:Connect(function()
	SellOrtherTextbox.Text = "All"
end)

WaitModeButton.MouseButton1Click:Connect(function()
	local t = ModeToText(WaitModeButton.Text)
	WaitModeButton.Text = (t == "Second") and "Wave" or "Second"
end)

AddPositionButton.MouseButton1Click:Connect(ToggleAddPosition)

PlaceSaveButton.MouseButton1Click:Connect(SaveSetting)
UpgradeSaveButton.MouseButton1Click:Connect(SaveSetting)
UpgradeAllSaveButton.MouseButton1Click:Connect(SaveSetting)
SellSaveButton.MouseButton1Click:Connect(SaveSetting)
WaitSaveButton.MouseButton1Click:Connect(SaveSetting)

PlaceCancelButton.MouseButton1Click:Connect(CloseSetting)
UpgradeCancelButton.MouseButton1Click:Connect(CloseSetting)
UpgradeAllCancelButton.MouseButton1Click:Connect(CloseSetting)
SellCancelButton.MouseButton1Click:Connect(CloseSetting)
WaitCancelButton.MouseButton1Click:Connect(CloseSetting)

_G.TDSHubOpenSetting = OpenSetting
_G.TDSHubSettingOpen = OpenSetting
_G.TDSHubSettingSave = SaveSetting
_G.TDSHubSettingClose = CloseSetting
_G.TDSHubSettingRefreshPositions = RefreshPositionList
_G.TDSHubSettingsLoad = function(programKey)
	return OpenSetting(programKey)
end
