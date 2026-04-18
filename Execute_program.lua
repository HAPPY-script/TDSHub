local Rep = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ScreenGui = PlayerGui:WaitForChild("TDSHub")
local Executor = ScreenGui:WaitForChild("Executor")

local ExecutorButton = Executor:WaitForChild("ExecutorButton")
local ExecutorShadowFrame = ExecutorButton:WaitForChild("ShadowFrame")
local IconPlay = ExecutorButton:WaitForChild("IconPlay")
local IconStop = ExecutorButton:WaitForChild("IconStop")
local TextStatusButton = ExecutorButton:WaitForChild("TextStatusButton")
local UIStroke = ExecutorButton:WaitForChild("UIStroke")

local ResetButton = Executor:WaitForChild("ResetButton")
local ResetShadowFrame = ResetButton:WaitForChild("ShadowFrame")
local CloseButton = Executor:WaitForChild("CloseButton")
local MinimizeButton = Executor:WaitForChild("MinimizeButton")

local MiniIcon = MinimizeButton:WaitForChild("MiniIcon")
local ZoomIcon = MinimizeButton:WaitForChild("ZoomIcon")

local ConsoleScrolling = Executor:WaitForChild("ConsoleScrolling")
local ManageProgramButton = Executor:WaitForChild("ManageProgramButton")

local IsMinimized = false

local Remote = Rep:WaitForChild("RemoteFunction")
local Towers = workspace:FindFirstChild("Towers")

local ENV_SUPPORTED = Towers ~= nil

if not ENV_SUPPORTED then

	task.spawn(function()
		while true do
			if type(_G.TDSHubConsole) == "function" then
				pcall(function()
					_G.TDSHubConsole({
						Title = "System",
						Text = "The current environment is not supported.",
						Color = Color3.fromRGB(255, 170, 0)
					})
				end)
			end

			task.wait(30)
		end
	end)

	return
end

local State = "idle" -- idle / running / paused / resetting
local PulseToken = 0
local Runner = nil

local Program = {}
local ProgramError = nil

local MAX_LOG_CHARS = 28

local function Clip(s, n)
	s = tostring(s or "")
	if #s <= n then
		return s
	end
	if n <= 1 then
		return s:sub(1, n)
	end
	return s:sub(1, n - 1) .. "…"
end

local function LogConsole(title, text, color)
	if type(_G.TDSHubConsole) ~= "function" then
		return
	end

	title = Clip(title, 12)
	text = Clip(text, math.max(0, MAX_LOG_CHARS - #title - 4))

	pcall(function()
		_G.TDSHubConsole({
			Title = title,
			Text = text,
			Color = color or Color3.fromRGB(180, 150, 180)
		})
	end)
end

local function LogUpgradeStep(tower, beforeLvl)
	if not tower then
		return
	end

	local name = tower.Name
	local tn = tower:FindFirstChild("TowerName")
	if tn and tn:IsA("StringValue") and tn.Value ~= "" then
		name = tn.Value
	end

	LogConsole("Upgrade", ("%s %d->%d"):format(name, beforeLvl, beforeLvl + 1), C_PURPLE)
end

local C_GREEN = Color3.fromRGB(0, 255, 0)
local C_RED = Color3.fromRGB(255, 0, 0)
local C_PURPLE = Color3.fromRGB(180, 150, 180)

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

local function ValidateProgram(program)
	if type(program) ~= "table" then
		return false, "Program must be a table"
	end

	if next(program) == nil then
		return false, "Program is empty"
	end

	for i, step in ipairs(program) do
		if type(step) ~= "table" then
			return false, ("Step %d must be a table"):format(i)
		end

		local t = step.type
		if type(t) ~= "string" then
			return false, ("Step %d is missing type"):format(i)
		end

		if t == "place" then
			if type(step.tower) ~= "string" then
				return false, ("Step %d place is missing tower"):format(i)
			end

			if type(step.positions) ~= "table" or #step.positions == 0 then
				return false, ("Step %d place is missing positions"):format(i)
			end

			for j, pos in ipairs(step.positions) do
				if typeof(pos) ~= "Vector3" then
					return false, ("Step %d place position %d must be Vector3"):format(i, j)
				end
			end

		elseif t == "upgrade" then
			if type(step.tower) ~= "string" then
				return false, ("Step %d upgrade is missing tower"):format(i)
			end
			if type(step.order) ~= "number" then
				return false, ("Step %d upgrade is missing order"):format(i)
			end
			if type(step.branch) ~= "number" then
				return false, ("Step %d upgrade is missing branch"):format(i)
			end
			if type(step.level_target) ~= "number" then
				return false, ("Step %d upgrade is missing level_target"):format(i)
			end

		elseif t == "upgrade_all" then
			if type(step.tower_name) ~= "string" then
				return false, ("Step %d upgrade_all is missing tower_name"):format(i)
			end
			if type(step.branch) ~= "number" then
				return false, ("Step %d upgrade_all is missing branch"):format(i)
			end
			if type(step.level_target) ~= "number" then
				return false, ("Step %d upgrade_all is missing level_target"):format(i)
			end

		elseif t == "sell" then
			if type(step.tower_name) ~= "string" then
				return false, ("Step %d sell is missing tower_name"):format(i)
			end
			if step.order ~= nil and type(step.order) ~= "number" then
				return false, ("Step %d sell order must be number or nil"):format(i)
			end

		elseif t == "wait" then
			if step.mode ~= "wave" and step.mode ~= "sec" then
				return false, ("Step %d wait mode must be wave or sec"):format(i)
			end
			if type(step.value) ~= "number" then
				return false, ("Step %d wait is missing value"):format(i)
			end

		else
			return false, ("Step %d has unknown type: %s"):format(i, tostring(t))
		end
	end

	return true
end

local function IsProgramValid()
	return type(Program) == "table" and next(Program) ~= nil and ProgramError == nil
end

local function IsProgramPlayable()
	return State == "idle" and IsProgramValid()
end

local function CanResetProgram()
	return State ~= "running"
end

local function SetButtonUI()
	local running = State == "running"
	local valid = IsProgramValid()

	TextStatusButton.Text = running and "Stop" or "Play"
	IconPlay.Visible = not running
	IconStop.Visible = running

	-- chỉ hiện shadow khi Program rỗng hoặc lỗi cú pháp
	ExecutorShadowFrame.Transparency = valid and 1 or 0.25

	if not running then
		UIStroke.Transparency = 1
	end
end

local function SetResetUI()
	local enabled = State ~= "running"

	ResetButton.Active = enabled
	ResetShadowFrame.Transparency = enabled and 1 or 0.25
end

local function RefreshUI()
	SetButtonUI()
	SetResetUI()
end

local function SetStrokePulse(on)
	PulseToken += 1
	local token = PulseToken

	if not on then
		UIStroke.Transparency = 1
		return
	end

	task.spawn(function()
		while token == PulseToken and State == "running" do
			local a = (math.sin(os.clock() * 8) + 1) * 0.5
			UIStroke.Transparency = 0.25 + (a * 0.65)
			task.wait(0.03)
		end

		if token == PulseToken then
			UIStroke.Transparency = 1
		end
	end)
end

local function SetState(newState)
	local old = State
	State = newState

	_G.TDSHubState = State
	_G.TDSHubRunning = (State == "running")
	_G.TDSHubPaused = (State == "paused")

	RefreshUI()
	SetStrokePulse(State == "running")

	if old ~= "running" and newState == "running" then
		LogConsole("System", "Running", C_GREEN)
    elseif old == "running" and newState == "paused" then
        LogConsole("System", "Paused", C_RED)
    end
end

local function IsAbortState()
	return State == "idle" or State == "resetting"
end

local function WaitUntilRunning()
	while State == "paused" do
		task.wait(0.05)
	end
	return State == "running"
end

local function WaitDuration(sec)
	local elapsed = 0

	while elapsed < sec do
		if IsAbortState() then
			return false
		end

		if State == "paused" then
			if not WaitUntilRunning() then
				return false
			end
		else
			local step = math.min(0.05, sec - elapsed)
			task.wait(step)
			elapsed += step
		end
	end

	return State == "running"
end

local WaveLabel = PlayerGui
	:WaitForChild("ReactGameTopGameDisplay")
	:WaitForChild("Frame")
	:WaitForChild("wave")
	:WaitForChild("container")
	:WaitForChild("value")

local function GetCurrentWave()
	if not WaveLabel or not WaveLabel:IsA("TextLabel") then
		return 0
	end

	local txt = WaveLabel.Text or ""
	local cur = txt:match("(%d+)%s*/")
	return tonumber(cur) or 0
end

local function WaitStep(cfg)
	local mode = cfg.mode
	local value = cfg.value or 0

	if mode == "sec" then
		LogConsole("Wait", tostring(value) .. "s", C_PURPLE)
		return WaitDuration(value)
	end

	if mode == "wave" then
		LogConsole("Wait", "Wave " .. tostring(value), C_PURPLE)
		while true do
			if State ~= "running" then
				return false
			end

			if GetCurrentWave() >= value then
				return true
			end

			task.wait(0.2)
		end
	end

	return true
end

local function InvokeRemote(...)
	local args = { ... }

	local ok, result = pcall(function()
		return Remote:InvokeServer(unpack(args))
	end)

	if ok then
		return result
	end

	return nil
end

local function IsMyTower(tower)
	local owner = tower and tower:FindFirstChild("Owner")
	return owner and owner.Value == LocalPlayer.UserId
end

local function GetTowerLevel(tower)
	local rep = tower and tower:FindFirstChild("TowerReplicator")
	if not rep then
		return 0
	end
	return rep:GetAttribute("Upgrade") or 0
end

local function PlaceTower(name, pos)
	local args = {
		"Troops",
		"Pl\208\176ce",
		{
			Position = pos,
			Rotation = CFrame.new()
		},
		name
	}

	return InvokeRemote(unpack(args))
end

local function UpgradeTower(tower, path)
	if not tower or not tower.Parent then
		return false
	end

	local args = {
		"Troops",
		"Upgrade",
		"Set",
		{
			Troop = tower,
			Path = path or 1
		}
	}

	local ok = InvokeRemote(unpack(args))
	return ok ~= nil or true
end

local function SellTower(tower)
	if not tower or not tower.Parent then
		return
	end

	local args = {
		"Troops",
		"Sell",
		{
			Troop = tower
		}
	}

	return InvokeRemote(unpack(args))
end

local function GetMyTowers()
	local list = {}

	for _, v in ipairs(Towers:GetChildren()) do
		if IsMyTower(v) then
			table.insert(list, v)
		end
	end

	return list
end

local function WaitForNewPlacedTower(beforeSet, timeout)
	local start = os.clock()
	timeout = timeout or 1

	while os.clock() - start < timeout do
		if IsAbortState() then
			return nil
		end

		if State == "paused" then
			if not WaitUntilRunning() then
				return nil
			end
		else
			for _, v in ipairs(Towers:GetChildren()) do
				if not beforeSet[v] and IsMyTower(v) then
					return v
				end
			end
			task.wait(0.01)
		end
	end
end

local function SetTowerName(tower, name)
	if not tower then
		return
	end

	local old = tower:FindFirstChild("TowerName")
	if old then
		old:Destroy()
	end

	local sv = Instance.new("StringValue")
	sv.Name = "TowerName"
	sv.Value = name
	sv.Parent = tower
end

local function GetTowerName(tower)
	local sv = tower and tower:FindFirstChild("TowerName")
	return sv and sv.Value or nil
end

local function GetTowersByName(name)
	local list = {}

	for _, v in ipairs(Towers:GetChildren()) do
		if IsMyTower(v) and GetTowerName(v) == name then
			table.insert(list, v)
		end
	end

	return list
end

local function GetTowerByOrder(name, order)
	local count = 0

	for _, v in ipairs(Towers:GetChildren()) do
		if IsMyTower(v) and GetTowerName(v) == name then
			count += 1
			if count == order then
				return v
			end
		end
	end
end

local function PlaceAndMark(cfg)
	local positions = cfg.positions or {}
	if #positions == 0 then
		return
	end

	for _, pos in ipairs(positions) do
		local placed = nil

		while not placed do
			if IsAbortState() then
				return
			end

			if not WaitUntilRunning() then
				return
			end

			local beforeSet = {}
			for _, v in ipairs(Towers:GetChildren()) do
				beforeSet[v] = true
			end

			PlaceTower(cfg.tower, pos)
			placed = WaitForNewPlacedTower(beforeSet, 1)

			if placed then
				SetTowerName(placed, cfg.tower)
				LogConsole("Place", "Success " .. cfg.tower, C_GREEN)
				break
			end

			if not WaitDuration(cfg.retry_interval or 0.01) then
				return
			end
		end

		if not WaitDuration(cfg.interval or 0.01) then
			return
		end
	end
end

local function UpgradeToTarget(tower, path, target, interval, logEach)
	if not tower or not tower.Parent then
		return
	end

	path = path or 1
	interval = interval or 1.5
	target = target or 0

	while tower.Parent do
		if IsAbortState() then
			return
		end

		if not WaitUntilRunning() then
			return
		end

		local before = GetTowerLevel(tower)
		if before >= target then
			break
		end

		UpgradeTower(tower, path)
		if not WaitDuration(interval) then
			return
		end

		local after = GetTowerLevel(tower)
		if logEach and after > before then
			LogUpgradeStep(tower, before)
		end
	end
end

local function UpgradeByOrder(cfg)
	local name = cfg.tower
	local order = cfg.order or 1
	local path = cfg.branch or 1
	local target = cfg.level_target or 0
	local interval = cfg.interval or 1.5

	local tower = GetTowerByOrder(name, order)
	if not tower then
		return
	end

	while tower.Parent do
		if IsAbortState() then
			return
		end

		if not WaitUntilRunning() then
			return
		end

		local before = GetTowerLevel(tower)
		if before >= target then
			break
		end

		UpgradeTower(tower, path)

		if not WaitDuration(interval) then
			return
		end

		local after = GetTowerLevel(tower)
		if after > before then
			LogUpgradeStep(tower, before)
		end
	end
end

local function UpgradeAll(cfg)
	local name = cfg.tower_name
	local path = cfg.branch or 1
	local target = cfg.level_target or 0
	local interval = cfg.interval or 1.5
	local oneByOne = cfg.one_by_one == true

	LogConsole("Upgrade all", "Start " .. name, C_PURPLE)

	if oneByOne then
		local index = 1

		while true do
			if IsAbortState() then
				return
			end

			if not WaitUntilRunning() then
				return
			end

			local towers = GetTowersByName(name)
			local tower = towers[index]
			if not tower then
				break
			end

			while tower.Parent and GetTowerLevel(tower) < target do
				if IsAbortState() then
					return
				end

				if not WaitUntilRunning() then
					return
				end

				local before = GetTowerLevel(tower)
				UpgradeTower(tower, path)

				if not WaitDuration(interval) then
					return
				end

				local after = GetTowerLevel(tower)
				if after > before then
					LogUpgradeStep(tower, before)
				end
			end

			index += 1
		end
	else
		while true do
			if IsAbortState() then
				return
			end

			if not WaitUntilRunning() then
				return
			end

			local towers = GetTowersByName(name)
			local selectedTower
			local lowestLevel = math.huge

			for _, tower in ipairs(towers) do
				local lvl = GetTowerLevel(tower)
				if lvl < target and lvl < lowestLevel then
					lowestLevel = lvl
					selectedTower = tower
				end
			end

			if not selectedTower then
				break
			end

			local before = GetTowerLevel(selectedTower)
			UpgradeTower(selectedTower, path)

			if not WaitDuration(interval) then
				return
			end

			local after = GetTowerLevel(selectedTower)
			if after > before then
				LogUpgradeStep(selectedTower, before)
			end
		end
	end

	LogConsole("Upgrade all", "Done " .. name, C_GREEN)
end

local function SellByName(cfg)
	local name = cfg.tower_name
	local order = cfg.order
	local interval = cfg.interval or 1.5

	if order == nil then
		while true do
			if IsAbortState() then
				return
			end

			if not WaitUntilRunning() then
				return
			end

			local tower = GetTowerByOrder(name, 1)
			if not tower then
				break
			end

			SellTower(tower)
			LogConsole("Sell", name .. " sold", C_RED)

			if not WaitDuration(interval) then
				return
			end
		end
		return
	end

	local tower = GetTowerByOrder(name, order)
	if tower then
		SellTower(tower)
		LogConsole("Sell", name .. " sold", C_RED)
	end
end

local function SellAllMyTowers()
	while true do
		if IsAbortState() then
			return
		end

		if not WaitUntilRunning() then
			return
		end

		local towers = GetMyTowers()
		if #towers == 0 then
			break
		end

		for _, tower in ipairs(towers) do
			if IsAbortState() then
				return
			end

			if not WaitUntilRunning() then
				return
			end

			if tower.Parent and IsMyTower(tower) then
				SellTower(tower)
				task.wait(0.05)
			end
		end

		task.wait(0.05)
	end
end

local function RunProgram(program)
	for _, step in ipairs(program) do
		if IsAbortState() then
			return
		end

		if not WaitUntilRunning() then
			return
		end

		if step.type == "place" then
			PlaceAndMark(step)
		elseif step.type == "upgrade" then
			UpgradeByOrder(step)
		elseif step.type == "upgrade_all" then
			UpgradeAll(step)
		elseif step.type == "sell" then
			SellByName(step)
		elseif step.type == "wait" then
			WaitStep(step)
		end

		if not WaitDuration(0.2) then
			return
		end
	end
end

local function LoadProgramFromSource(src)
	if State ~= "idle" then
		return false, "Busy"
	end

	ProgramError = nil

	if type(src) == "function" then
		local ok, result = pcall(src)
		if not ok then
			Program = {}
			ProgramError = "Program function error: " .. tostring(result)
			RefreshUI()
			return false, ProgramError
		end
		src = result
	end

	if type(src) ~= "table" then
		Program = {}
		ProgramError = "Program source must be a table, got " .. type(src)
		RefreshUI()
		return false, ProgramError
	end

	Program = DeepCopy(src)

	local ok, err = ValidateProgram(Program)
	if not ok then
		ProgramError = err
		Program = {}
		warn("ValidateProgram failed:", err)
		LogConsole("System", "Bad: " .. tostring(err), C_RED)
		RefreshUI()
		return false, err
	end

	ProgramError = nil
	LogConsole("System", "Program loaded", C_GREEN)
	RefreshUI()
	return true
end

local function LoadProgramFromG()
	local src = rawget(_G, "TDSHubProgram")
	print("TDSHubProgram type:", type(src))
	return LoadProgramFromSource(src)
end

local function ResetProgram()
	if State == "running" then
		return
	end

	SetState("resetting")
	LogConsole("System", "Resetting", C_RED)

	Program = {}
	ProgramError = nil
	RefreshUI()

	SellAllMyTowers()

	Runner = nil
	SetState("idle")
	LogConsole("System", "Reset done", C_GREEN)
end

local function StartRunner()
	if Runner or not IsProgramPlayable() then
		return
	end

	Runner = task.spawn(function()
		SetState("running")
		RunProgram(Program)

		Runner = nil
		if State ~= "idle" then
			SetState("idle")
		else
			RefreshUI()
		end

		LogConsole("System", "Finished", C_GREEN)
	end)
end

_G.TDSHubLoadProgram = function()
	return LoadProgramFromG()
end

_G.TDSHubSetProgram = function(src)
	_G.TDSHubProgram = src
	return LoadProgramFromSource(src)
end

task.spawn(function()
	LoadProgramFromG()
	RefreshUI()
end)

ExecutorButton.MouseButton1Click:Connect(function()
	if State == "running" then
		SetState("paused")
		return
	end

	if State == "paused" then
		SetState("running")
		return
	end

	if IsProgramPlayable() then
		StartRunner()
	end
end)

ResetButton.MouseButton1Click:Connect(function()
	if State ~= "running" then
		task.spawn(ResetProgram)
	end
end)

local function SetMinimize(state)
	IsMinimized = state

	if state then
		-- thu nhỏ
		ConsoleScrolling.Visible = false
		ManageProgramButton.Visible = false

		Executor.Size = UDim2.new(0,300,0,110)

		ResetButton.Position = UDim2.new(0.57,0,0.55,0)
		ExecutorButton.Position = UDim2.new(0.03,0,0.55,0)

		MiniIcon.Visible = false
		ZoomIcon.Visible = true
	else
		-- phóng to
		ConsoleScrolling.Visible = true
		ManageProgramButton.Visible = true

		Executor.Size = UDim2.new(0,300,0,350)

		ResetButton.Position = UDim2.new(0.57,0,0.85,0)
		ExecutorButton.Position = UDim2.new(0.03,0,0.85,0)

		MiniIcon.Visible = true
		ZoomIcon.Visible = false
	end
end

MinimizeButton.MouseButton1Click:Connect(function()
	SetMinimize(not IsMinimized)
end)

CloseButton.MouseButton1Click:Connect(function()

	-- nếu đang chạy thì dừng
	if State == "running" or State == "paused" then
		SetState("idle")
	end

	Runner = nil

	if ScreenGui then
		ScreenGui:Destroy()
	end
end)

SetState("idle")

--[[ API
_G.TDSHubState
_G.TDSHubRunning
_G.TDSHubPaused

_G.TDSHubProgram = {
	-- Program ở đây
}
_G.TDSHubLoadProgram()
]]
