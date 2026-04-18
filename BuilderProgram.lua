local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ScreenGui = PlayerGui:WaitForChild("TDSHub")
local ManageProgramFrame = ScreenGui:WaitForChild("ManageProgramFrame")
local SelectType = ScreenGui:WaitForChild("SelectType")
local Executor = ScreenGui:WaitForChild("Executor")

local CustomProgramUI = ManageProgramFrame:WaitForChild("CustomProgramUI")
local BuildProgram = CustomProgramUI:WaitForChild("BuildProgram")
local BuildProgramOutput = CustomProgramUI:WaitForChild("BuildProgramOutput")
local AddProgram = CustomProgramUI:WaitForChild("AddProgram")
local DeleteProgram = CustomProgramUI:WaitForChild("DeleteProgram")
local MoveProgram = CustomProgramUI:WaitForChild("MoveProgram")
local CopyProgramButton = CustomProgramUI:WaitForChild("CopyProgramButton")
local LoadOutputProgramButton = CustomProgramUI:WaitForChild("LoadOutputProgramButton")
local LoadOutputShadowFrame = LoadOutputProgramButton:WaitForChild("ShadowFrame")

local ProgramSample = BuildProgram:WaitForChild("ProgramSample")
ProgramSample.Visible = false

local OutputSample = BuildProgramOutput:WaitForChild("OutputSample")
OutputSample.Visible = false

local SelectButtons = {
	Place = SelectType:WaitForChild("Place"),
	Upgrade = SelectType:WaitForChild("Upgrade"),
	UpgradeAll = SelectType:WaitForChild("Upgrade all"),
	Sell = SelectType:WaitForChild("Sell"),
	Wait = SelectType:WaitForChild("Wait"),
}

local DeleteStroke = DeleteProgram:FindFirstChildWhichIsA("UIStroke")
local MoveStroke = MoveProgram:FindFirstChildWhichIsA("UIStroke")
local ProgramHeight = 35
local OutputHeight = 25

local TYPE_COLORS = {
	place = Color3.fromRGB(0, 200, 120),
	upgrade = Color3.fromRGB(90, 170, 255),
	upgrade_all = Color3.fromRGB(200, 130, 255),
	sell = Color3.fromRGB(255, 95, 95),
	wait = Color3.fromRGB(180, 150, 180),
}

local STEP_LABELS = {
	place = "place",
	upgrade = "upgrade",
	upgrade_all = "upgrade all",
	sell = "sell",
	wait = "wait",
}

local STEP_DEFAULTS = {
	place = { type = "place", tower = "Scout", positions = { Vector3.new(0, 0, 0) } },
	upgrade = { type = "upgrade", tower = "Scout", order = 1, branch = 1, level_target = 1, interval = 0.3 },
	upgrade_all = { type = "upgrade_all", tower_name = "Scout", one_by_one = false, branch = 1, level_target = 1, interval = 0.3 },
	sell = { type = "sell", tower_name = "Scout", order = 1, interval = 0.2 },
	wait = { type = "wait", mode = "sec", value = 0 },
}

local ProgramSteps = {}
_G.TDSHubProgramSteps = ProgramSteps
local DeleteMode = false
local MoveMode = false
local BlockButtons = false
local SelectedMoveIndex = nil
local MoveHighlightStroke = nil
local MoveHighlightTween = nil

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

local function StripInternalKeys(step)
	local out = DeepCopy(step)
	out.id = nil
	return out
end

local function StepLabel(stepType)
	return STEP_LABELS[stepType] or tostring(stepType)
end

local function NewStep(stepType)
	local defaults = STEP_DEFAULTS[stepType]
	if not defaults then
		return nil
	end

	local step = DeepCopy(defaults)
	step.id = HttpService:GenerateGUID(false)
	return step
end

local function SetLoadButtonState()
	local enabled = #ProgramSteps > 0 and not BlockButtons
	LoadOutputProgramButton.Active = enabled
	LoadOutputProgramButton.AutoButtonColor = enabled
	LoadOutputShadowFrame.Transparency = enabled and 1 or 0.25
end

local function SetSelectTypeVisible(on)
	SelectType.Visible = on == true
end

local function IsProgramButton(obj)
	return obj and obj:IsA("GuiButton") and obj.Name:match("^Program%d+$")
end

local function IsOutputLine(obj)
	return obj and obj:IsA("GuiObject") and obj.Name:match("^Output%d+$")
end

local function ClearMoveHighlight()
	if MoveHighlightTween then
		MoveHighlightTween:Cancel()
		MoveHighlightTween = nil
	end

	if MoveHighlightStroke then
		MoveHighlightStroke:Destroy()
		MoveHighlightStroke = nil
	end
end

local function ClearMoveSelection()
	SelectedMoveIndex = nil
	ClearMoveHighlight()
end

local function CreateMoveHighlight(button)
	ClearMoveHighlight()

	local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = button

	MoveHighlightStroke = stroke

	local tween = TweenService:Create(
		stroke,
		TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.8 }
	)

	tween:Play()
	MoveHighlightTween = tween
end

local function UpdateSelectionUI()
	for _, child in ipairs(BuildProgram:GetChildren()) do
		if IsProgramButton(child) then
			local stroke = child:FindFirstChildWhichIsA("UIStroke")
			if stroke then
				stroke.Enabled = false
			end
		end
	end

	if SelectedMoveIndex then
		local btn = BuildProgram:FindFirstChild("Program" .. SelectedMoveIndex)
		if btn then
			local stroke = btn:FindFirstChildWhichIsA("UIStroke")
			if stroke then
				stroke.Enabled = true
			end
		end
	end
end

local function SetDeleteMode(on)
	DeleteMode = on == true
	if DeleteStroke then
		DeleteStroke.Enabled = DeleteMode
	end
	if DeleteMode then
		MoveMode = false
		if MoveStroke then
			MoveStroke.Enabled = false
		end
		ClearMoveSelection()
		UpdateSelectionUI()
	end
end

local function SetMoveMode(on)
	MoveMode = on == true
	if MoveStroke then
		MoveStroke.Enabled = MoveMode
	end
	if MoveMode then
		DeleteMode = false
		if DeleteStroke then
			DeleteStroke.Enabled = false
		end
		ClearMoveSelection()
		UpdateSelectionUI()
	else
		ClearMoveSelection()
		UpdateSelectionUI()
	end
end

local function ToggleDeleteMode()
	SetDeleteMode(not DeleteMode)
end

local function ToggleMoveMode()
	SetMoveMode(not MoveMode)
end

local function IsArray(tbl)
	local n = 0
	for k in pairs(tbl) do
		if type(k) ~= "number" then
			return false
		end
		n += 1
	end
	return n > 0 and n == #tbl
end

local function EscapeString(s)
	return string.format("%q", tostring(s))
end

local function CompactEncodeValue(v)
	local tv = typeof(v)

	if tv == "Vector3" then
		return ("Vector3.new(%s, %s, %s)"):format(tostring(v.X), tostring(v.Y), tostring(v.Z))
	end

	if tv == "CFrame" then
		local comps = { v:GetComponents() }
		return ("CFrame.new(%s)"):format(table.concat(comps, ", "))
	end

	if type(v) == "string" then
		return EscapeString(v)
	elseif type(v) == "number" then
		return tostring(v)
	elseif type(v) == "boolean" then
		return v and "true" or "false"
	elseif type(v) == "table" then
		return CompactEncodeTable(v)
	elseif v == nil then
		return "nil"
	end

	return "nil"
end

function CompactEncodeTable(tbl)
	if IsArray(tbl) then
		local parts = {}
		for i = 1, #tbl do
			parts[#parts + 1] = CompactEncodeValue(tbl[i])
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end

	local keyOrder = { "type", "tower", "positions", "tower_name", "order", "branch", "level_target", "interval", "one_by_one", "mode", "value" }
	local used = {}
	local parts = {}

	for _, key in ipairs(keyOrder) do
		if tbl[key] ~= nil then
			used[key] = true
			parts[#parts + 1] = key .. " = " .. CompactEncodeValue(tbl[key])
		end
	end

    for k, v in pairs(tbl) do
        if not used[k] and k ~= "id" then
            local keyText = type(k) == "string" and k:match("^[%a_][%w_]*$") and k or ("[%s]"):format(CompactEncodeValue(k))
            parts[#parts + 1] = keyText .. " = " .. CompactEncodeValue(v)
        end
    end

	return "{" .. table.concat(parts, ", ") .. "}"
end

local function BuildProgramText(program)
	local out = { "{" }
	for _, step in ipairs(program) do
		out[#out + 1] = "\t" .. CompactEncodeTable(step) .. ","
	end
	out[#out + 1] = "}"
	return table.concat(out, "\n")
end

local function ClearProgramButtons()
	for _, child in ipairs(BuildProgram:GetChildren()) do
		if IsProgramButton(child) then
			child:Destroy()
		end
	end
end

local function ClearOutputLines()
	for _, child in ipairs(BuildProgramOutput:GetChildren()) do
		if IsOutputLine(child) then
			child:Destroy()
		end
	end
end

local function MoveStep(fromIndex, toIndex)
	local n = #ProgramSteps
	if n == 0 then
		return
	end

	fromIndex = math.clamp(fromIndex, 1, n)
	toIndex = math.clamp(toIndex, 1, n)

	if fromIndex == toIndex then
		return
	end

	ProgramSteps[fromIndex], ProgramSteps[toIndex] = ProgramSteps[toIndex], ProgramSteps[fromIndex]
end

local function RebuildOutputUI()
	ClearOutputLines()

	for index, step in ipairs(ProgramSteps) do
		local clone = OutputSample:Clone()
		clone.Name = "Output" .. index
		clone.Visible = true
		clone.LayoutOrder = index
		clone.Position = UDim2.new(0, 0, 0, (index - 1) * OutputHeight)
		clone.Size = UDim2.new(1, -6, 0, OutputHeight)
		clone.Text = CompactEncodeTable(step)
		clone.TextXAlignment = Enum.TextXAlignment.Left
		clone.TextYAlignment = Enum.TextYAlignment.Center
		clone.TextWrapped = false
		clone.TextScaled = true
		pcall(function()
			clone.TextTruncate = Enum.TextTruncate.None
		end)
		clone.Parent = BuildProgramOutput
	end

	BuildProgramOutput.CanvasSize = UDim2.new(0, 0, 0, math.max(0, #ProgramSteps * OutputHeight))
end

_G.TDSHubProgramOutputRebuild = RebuildOutputUI

local function OpenProgramSetting(index)
	local step = ProgramSteps[index]
	if not step then
		return
	end

	if type(_G.TDSHubOpenSetting) ~= "function" then
		return
	end

	_G.TDSHubOpenSetting(step.id or index)
end

function RebuildProgramUI()
	ClearProgramButtons()

	for index, step in ipairs(ProgramSteps) do
		local clone = ProgramSample:Clone()
		clone.Name = "Program" .. index
		clone.Visible = true
		clone.LayoutOrder = index
		clone.Position = UDim2.new(0, 0, 0, (index - 1) * ProgramHeight)
		clone.BackgroundColor3 = TYPE_COLORS[step.type] or Color3.fromRGB(200, 200, 200)
		clone.ZIndex = 1

		if clone:IsA("TextButton") or clone:IsA("TextLabel") then
			clone.Text = ("#%d - %s"):format(index, StepLabel(step.type))
		end

		local stroke = clone:FindFirstChildWhichIsA("UIStroke")
		if stroke then
			stroke.Enabled = MoveMode and SelectedMoveIndex == index
		end

		clone.Parent = BuildProgram

        clone.MouseButton1Click:Connect(function()
            if DeleteMode then
                for i, item in ipairs(ProgramSteps) do
                    if item == step then
                        table.remove(ProgramSteps, i)
                        break
                    end
                end
                ClearMoveSelection()
                RebuildProgramUI()
                return
            end

            if MoveMode then
                if SelectedMoveIndex == nil then
                    SelectedMoveIndex = index
                    CreateMoveHighlight(clone)
                    return
                end

                if SelectedMoveIndex == index then
                    ClearMoveSelection()
                    UpdateSelectionUI()
                    return
                end

                MoveStep(SelectedMoveIndex, index)
                ClearMoveSelection()
                RebuildProgramUI()
                return
            end

            OpenProgramSetting(index)
        end)
	end

	BuildProgram.CanvasSize = UDim2.new(0, 0, 0, math.max(0, #ProgramSteps * ProgramHeight))
	UpdateSelectionUI()
	RebuildOutputUI()
	SetLoadButtonState()
end

local function CopyProgram()
	local clean = {}
    for _, step in ipairs(ProgramSteps) do
        clean[#clean+1] = StripInternalKeys(step)
    end

    local text = BuildProgramText(clean)
	if type(setclipboard) == "function" then
		setclipboard(text)
		Console("System", "Copied", Color3.fromRGB(0, 255, 0))
	else
		warn("setclipboard is not available")
	end
end

local function LoadProgram()
	local program = {}
	for _, step in ipairs(ProgramSteps) do
		program[#program + 1] = StripInternalKeys(step)
	end

	if #program == 0 then
		return
	end

	if type(_G.TDSHubSubmitProgram) ~= "function" then
		Console("System", "Missing submit API", Color3.fromRGB(255, 0, 0))
		return
	end

	local ok, err = _G.TDSHubSubmitProgram(program, { updateBox = true, keepView = true })
	if not ok then
		warn(err)
		Console("System", "Load failed", Color3.fromRGB(255, 0, 0))
		return
	end

	Console("System", "Loaded", Color3.fromRGB(0, 255, 0))
    
    ManageProgramFrame.Visible = false
    Executor.Visible = true
end

local function AddStep(stepType)
	local step = NewStep(stepType)
	if not step then
		return
	end

	table.insert(ProgramSteps, step)
	ClearMoveSelection()
	RebuildProgramUI()
	SetSelectTypeVisible(false)
    ManageProgramFrame.Visible = true
	Console("System", "Added " .. StepLabel(stepType), Color3.fromRGB(0, 255, 0))
end

AddProgram.MouseButton1Click:Connect(function()
	ManageProgramFrame.Visible = false
	SetSelectTypeVisible(true)
end)

DeleteProgram.MouseButton1Click:Connect(function()
	ToggleDeleteMode()
	if DeleteMode then
		SetMoveMode(false)
	end
end)

MoveProgram.MouseButton1Click:Connect(function()
	ToggleMoveMode()
	if MoveMode then
		SetDeleteMode(false)
	end
end)

CopyProgramButton.MouseButton1Click:Connect(function()
	CopyProgram()
end)

LoadOutputProgramButton.MouseButton1Click:Connect(function()
	if not LoadOutputProgramButton.Active then
		return
	end
	LoadProgram()
end)

local function ConnectTypeButton(button, stepType)
	button.MouseButton1Click:Connect(function()
		if DeleteMode then
			SetDeleteMode(false)
		end
		if MoveMode then
			SetMoveMode(false)
		end
		AddStep(stepType)
	end)
end

ConnectTypeButton(SelectButtons.Place, "place")
ConnectTypeButton(SelectButtons.Upgrade, "upgrade")
ConnectTypeButton(SelectButtons.UpgradeAll, "upgrade_all")
ConnectTypeButton(SelectButtons.Sell, "sell")
ConnectTypeButton(SelectButtons.Wait, "wait")

SetSelectTypeVisible(false)
SetDeleteMode(false)
SetMoveMode(false)
RebuildProgramUI()
SetLoadButtonState()

_G.TDSHubCustomProgramBuilder = {
	AddStep = AddStep,
	DeleteMode = function()
		return DeleteMode
	end,
	MoveMode = function()
		return MoveMode
	end,
    GetProgram = function()
        local out = {}
        for _, step in ipairs(ProgramSteps) do
            out[#out + 1] = StripInternalKeys(step)
        end
        return out
    end,
	GetProgramText = function()
		return BuildProgramText(ProgramSteps)
	end,
	SetDeleteMode = SetDeleteMode,
	SetMoveMode = SetMoveMode,
	Rebuild = RebuildProgramUI,
}
