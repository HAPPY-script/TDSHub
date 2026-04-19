local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ScreenGui = PlayerGui:WaitForChild("TDSHub")
local Executor = ScreenGui:WaitForChild("Executor")
local ManageProgramFrame = ScreenGui:WaitForChild("ManageProgramFrame")

local TweenService = game:GetService("TweenService")
local ManageProgramButton = Executor:WaitForChild("ManageProgramButton")
local ComeBackButton = ManageProgramFrame:WaitForChild("ComeBackButton")
local ProgramBox = ManageProgramFrame:WaitForChild("ProgramBox")
local LoadProgramButton = ManageProgramFrame:WaitForChild("LoadProgramButton")
local LoadShadowFrame = LoadProgramButton:WaitForChild("ShadowFrame")

local Loading = false

local CurrentProgram = nil

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

local function NormalizeProgram(program)
	if type(program) ~= "table" then
		return nil, "Program is not a table"
	end

	if program.program and type(program.program) == "table" then
		program = program.program
	elseif program.steps and type(program.steps) == "table" then
		program = program.steps
	end

	if #program == 1 and type(program[1]) == "table" then
		local inner = program[1]
		if inner.type == nil and next(inner) ~= nil then
			program = inner
		end
	end

	if next(program) == nil then
		return nil, "Program is empty"
	end

	return program
end

local function ResolveSource(source)
	if type(source) == "function" then
		local ok, result = pcall(source)
		if not ok then
			return nil, "Program function error: " .. tostring(result)
		end
		source = result
	end

	return source
end

local function ToVector3(v)
	if typeof(v) == "Vector3" then
		return v
	end

	if type(v) == "table" then
		if type(v.X) == "number" and type(v.Y) == "number" and type(v.Z) == "number" then
			return Vector3.new(v.X, v.Y, v.Z)
		end

		if type(v[1]) == "number" and type(v[2]) == "number" and type(v[3]) == "number" then
			return Vector3.new(v[1], v[2], v[3])
		end
	end
end

local function SanitizeProgram(program)
	if type(program) ~= "table" then
		return nil, "Program must be a table"
	end

	program = DeepCopy(program)
	program, localErr = NormalizeProgram(program)
	if not program then
		return nil, localErr
	end

	local out = {}

	for i, step in ipairs(program) do
		if type(step) ~= "table" then
			return nil, ("Step %d must be a table"):format(i)
		end

		local t = step.type
		if type(t) ~= "string" then
			return nil, ("Step %d is missing type"):format(i)
		end

		if t == "place" then
			if type(step.tower) ~= "string" then
				return nil, ("Step %d place is missing tower"):format(i)
			end
			if type(step.positions) ~= "table" or #step.positions == 0 then
				return nil, ("Step %d place is missing positions"):format(i)
			end

			local positions = {}
			for j, pos in ipairs(step.positions) do
				local vec = ToVector3(pos)
				if not vec then
					return nil, ("Step %d place position %d must be Vector3"):format(i, j)
				end
				positions[#positions + 1] = vec
			end

			out[#out + 1] = {
				type = "place",
				tower = step.tower,
				positions = positions,
				interval = type(step.interval) == "number" and step.interval or nil,
				retry_interval = type(step.retry_interval) == "number" and step.retry_interval or nil,
			}

		elseif t == "upgrade" then
			if type(step.tower) ~= "string" then
				return nil, ("Step %d upgrade is missing tower"):format(i)
			end
			if type(step.order) ~= "number" then
				return nil, ("Step %d upgrade is missing order"):format(i)
			end
			if type(step.branch) ~= "number" then
				return nil, ("Step %d upgrade is missing branch"):format(i)
			end
			if type(step.level_target) ~= "number" then
				return nil, ("Step %d upgrade is missing level_target"):format(i)
			end

			out[#out + 1] = {
				type = "upgrade",
				tower = step.tower,
				order = step.order,
				branch = step.branch,
				level_target = step.level_target,
				interval = type(step.interval) == "number" and step.interval or nil,
			}

		elseif t == "upgrade_all" then
			if type(step.tower_name) ~= "string" then
				return nil, ("Step %d upgrade_all is missing tower_name"):format(i)
			end
			if type(step.branch) ~= "number" then
				return nil, ("Step %d upgrade_all is missing branch"):format(i)
			end
			if type(step.level_target) ~= "number" then
				return nil, ("Step %d upgrade_all is missing level_target"):format(i)
			end

			out[#out + 1] = {
				type = "upgrade_all",
				tower_name = step.tower_name,
				branch = step.branch,
				level_target = step.level_target,
				interval = type(step.interval) == "number" and step.interval or nil,
				one_by_one = step.one_by_one == true,
			}

		elseif t == "sell" then
			if type(step.tower_name) ~= "string" then
				return nil, ("Step %d sell is missing tower_name"):format(i)
			end
			if step.order ~= nil and type(step.order) ~= "number" then
				return nil, ("Step %d sell order must be number or nil"):format(i)
			end

			out[#out + 1] = {
				type = "sell",
				tower_name = step.tower_name,
				order = step.order,
				interval = type(step.interval) == "number" and step.interval or nil,
			}

		elseif t == "wait" then
			if step.mode ~= "wave" and step.mode ~= "sec" then
				return nil, ("Step %d wait mode must be wave or sec"):format(i)
			end
			if type(step.value) ~= "number" then
				return nil, ("Step %d wait is missing value"):format(i)
			end

			out[#out + 1] = {
				type = "wait",
				mode = step.mode,
				value = step.value,
			}

		else
			return nil, ("Step %d has unknown type: %s"):format(i, tostring(t))
		end
	end

	if #out == 0 then
		return nil, "Program is empty"
	end

	return out
end

local function SetView(showManage)
	Executor.Visible = not showManage
	ManageProgramFrame.Visible = showManage
end

local function Trim(text)
	return (text or ""):match("^%s*(.-)%s*$") or ""
end

local function ShowManageFrame()
	ManageProgramFrame.Position = UDim2.new(0.18,0,0.6,0)
	ManageProgramFrame.Visible = true

	local tween = TweenService:Create(
		ManageProgramFrame,
		TweenInfo.new(
			0.18,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{Position = UDim2.new(0.18,0,0.5,0)}
	)

	tween:Play()
end

local function UpdateLoadButton()
	local txt = Trim(ProgramBox.Text)
	local hasText = txt ~= ""
	local running = _G.TDSHubRunning == true

	local enabled = hasText and not Loading and not running

	LoadProgramButton.Active = enabled
	LoadProgramButton.AutoButtonColor = enabled
	LoadShadowFrame.Transparency = enabled and 1 or 0.25
end

local function Console(title, text, color)
	if type(_G.TDSHubConsole) == "function" then
		pcall(function()
			_G.TDSHubConsole({
				Title = title,
				Text = text,
				Color = color or Color3.fromRGB(180, 150, 180),
			})
		end)
	end
end

local function NormalizeProgram(program)
	if type(program) ~= "table" then
		return nil, "Program is not a table"
	end

	if #program == 1 and type(program[1]) == "table" then
		local inner = program[1]
		if inner.type == nil and next(inner) ~= nil then
			program = inner
		end
	end

	return program
end

local function ParseProgramText(input)
	local source = ResolveSource(input)
	if source == nil then
		return nil, "Program source is nil"
	end

	if type(source) == "table" then
		return SanitizeProgram(source)
	end

	if type(source) ~= "string" then
		return nil, "Program source must be a string, table, or function"
	end

	local text = Trim(source)
	if text == "" then
		return nil, "ProgramBox empty"
	end

	local function tryChunk(chunk)
		local fn, err = loadstring(chunk)
		if not fn then
			return nil, err
		end

		local ok, result = pcall(fn)
		if not ok then
			return nil, result
		end

		return result
	end

	local result = tryChunk("return " .. text)
	if type(result) == "table" then
		return SanitizeProgram(result)
	end

	result = tryChunk("return {" .. text .. "}")
	if type(result) == "table" then
		return SanitizeProgram(result)
	end

	return nil, "Invalid program format"
end

local function isArray(tbl)
	local n = 0
	for k in pairs(tbl) do
		if type(k) ~= "number" then
			return false
		end
		n += 1
	end
	return n > 0 and n == #tbl
end

local function encodeString(s)
	return string.format("%q", tostring(s))
end

local function encodeValue(v)

	local tv = typeof(v)

	if tv == "Vector3" then
		return ("Vector3.new(%s,%s,%s)"):format(
			tostring(v.X),
			tostring(v.Y),
			tostring(v.Z)
		)
	end

	if tv == "CFrame" then
		local comps = { v:GetComponents() }
		local allZero = true
		for i = 1, 12 do
			if comps[i] ~= (i == 4 and 0 or i == 8 and 0 or i == 12 and 0 or (i == 1 or i == 6 or i == 11) and 1 or 0) then
				allZero = false
				break
			end
		end
		if allZero then
			return "CFrame.new()"
		end
		return ("CFrame.new(%s)"):format(table.concat(comps, ","))
	end

	if type(v) == "string" then
		return encodeString(v)
	elseif type(v) == "number" then
		return tostring(v)
	elseif type(v) == "boolean" then
		return v and "true" or "false"
	elseif type(v) == "table" then
		return nil
	elseif v == nil then
		return "nil"
	end

	return nil
end

local function encodeTable(tbl)
	if isArray(tbl) then
		local out = {}
		for i = 1, #tbl do
			local item = tbl[i]
			local enc = encodeValue(item)
			if enc then
				out[#out + 1] = enc
			elseif type(item) == "table" then
				out[#out + 1] = encodeTable(item)
			else
				out[#out + 1] = "nil"
			end
		end
		return "{" .. table.concat(out, ",") .. "}"
	end

	local keys = {}
	for k in pairs(tbl) do
		keys[#keys + 1] = k
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)

	local out = {}
	for _, k in ipairs(keys) do
		local v = tbl[k]
		local keyText
		if type(k) == "string" and k:match("^[%a_][%w_]*$") then
			keyText = k
		else
			keyText = "[" .. encodeValue(k) .. "]"
		end

		local valText = encodeValue(v)
		if not valText and type(v) == "table" then
			valText = encodeTable(v)
		end

		if valText then
			out[#out + 1] = keyText .. "=" .. valText
		end
	end

	return "{" .. table.concat(out, ",") .. "}"
end

local function CompactProgramText(program)
	if type(program) ~= "table" then
		return nil
	end
	return encodeTable(program)
end

local function LoadProgramFromSource(source, opts)
	opts = opts or {}

	if _G.TDSHubRunning then
		return false, "Running"
	end

	if Loading then
		return false, "Loading"
	end

	Loading = true
	UpdateLoadButton()

	local program, err = ParseProgramText(source)
	if not program then
		warn(err)
		Console("System", "Load failed", Color3.fromRGB(255, 0, 0))
		Loading = false
		UpdateLoadButton()
		return false, err
	end

	CurrentProgram = DeepCopy(program)
	_G.TDSHubProgram = DeepCopy(program)

	local compact = CompactProgramText(program)
	if compact and opts.updateBox ~= false then
		ProgramBox.Text = compact
	end

	local ok, loadErr = false, nil
	if type(_G.TDSHubLoadProgram) == "function" then
		ok, loadErr = _G.TDSHubLoadProgram()
	else
		loadErr = "Missing _G.TDSHubLoadProgram"
	end

	if ok then
		if opts.keepView ~= true then
			SetView(false)
		end
	else
		warn(loadErr)
		Console("System", "Load failed", Color3.fromRGB(255, 0, 0))
	end

	Loading = false
	UpdateLoadButton()
	return ok, loadErr
end

local function LoadProgramFromBox()
	return LoadProgramFromSource(ProgramBox.Text, { updateBox = true })
end

ManageProgramButton.MouseButton1Click:Connect(function()
	Executor.Visible = false
	ShowManageFrame()
	UpdateLoadButton()
end)

ComeBackButton.MouseButton1Click:Connect(function()
	SetView(false)
end)

LoadProgramButton.MouseButton1Click:Connect(function()
	if not LoadProgramButton.Active then
		return
	end

	LoadProgramFromBox()
end)

_G.TDSHubSubmitProgram = function(source, opts)
	return LoadProgramFromSource(source, opts)
end

_G.TDSHubLoadProgramFromSource = function(source, opts)
	return LoadProgramFromSource(source, opts)
end

_G.TDSHubSetProgram = function(source, opts)
	return LoadProgramFromSource(source, opts or { updateBox = true })
end

_G.TDSHubGetProgram = function()
	return DeepCopy(CurrentProgram or _G.TDSHubProgram or {})
end

ProgramBox:GetPropertyChangedSignal("Text"):Connect(UpdateLoadButton)
ProgramBox.FocusLost:Connect(UpdateLoadButton)

SetView(false)
UpdateLoadButton()

--[[ API

_G.TDSHubSubmitProgram({
	{
		type = "wait",
		mode = "wave",
		value = 20,
	}
})

]]
