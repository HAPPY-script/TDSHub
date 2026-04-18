local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ScreenGui = PlayerGui:WaitForChild("TDSHub")

local Executor = ScreenGui:WaitForChild("Executor")
local ConsoleScrolling = Executor:WaitForChild("ConsoleScrolling")

local ConsoleOutside = ScreenGui:WaitForChild("ConsoleOutside")
local OutsideScrolling = ConsoleOutside

-- TEMPLATE
local OutputSample = ConsoleScrolling:WaitForChild("OutputSample")
local OutputSampleOutside = OutsideScrolling:WaitForChild("OutputSample")

OutputSample.Visible = false
OutputSampleOutside.Visible = false

local LineHeight = 20
local LineCount = 0

--// SCROLL
local function ScrollToBottom(scrolling)
	task.defer(function()
		local y = math.max(0, scrolling.AbsoluteCanvasSize.Y - scrolling.AbsoluteWindowSize.Y)
		scrolling.CanvasPosition = Vector2.new(0, y)
	end)
end

--// COLOR FIX
local function ToColor3(c)
	if typeof(c) ~= "Color3" then
		return Color3.new(1, 1, 1)
	end

	local maxv = math.max(c.R, c.G, c.B)

	if maxv > 1 then
		return Color3.fromRGB(
			math.clamp(math.floor(c.R), 0, 255),
			math.clamp(math.floor(c.G), 0, 255),
			math.clamp(math.floor(c.B), 0, 255)
		)
	end

	return c
end

--// CREATE LINE
local function CreateLine(parent, template, text, color, index)

	local line = template:Clone()
	line.Name = "Output" .. index
	line.Visible = true
	line.Text = text
	line.TextColor3 = color
	line.Position = UDim2.new(0.025, 0, 0, (index - 1) * LineHeight)
	line.Parent = parent

end

--// PUSH CONSOLE
local function PushConsole(data)

	if type(data) ~= "table" then
		return
	end

	local title = tostring(data.Title or "System")
	local text = tostring(data.Text or "")
	local color = ToColor3(data.Color)

	LineCount += 1

	local finalText = ("[%s]: %s"):format(title, text)

	-- console inside executor
	CreateLine(ConsoleScrolling, OutputSample, finalText, color, LineCount)

	-- console outside
	CreateLine(OutsideScrolling, OutputSampleOutside, finalText, color, LineCount)

	ScrollToBottom(ConsoleScrolling)
	ScrollToBottom(OutsideScrolling)

end

--// EXECUTOR VISIBILITY CONTROL
local function UpdateConsoleOutside()
	ConsoleOutside.Visible = not Executor.Visible
end

Executor:GetPropertyChangedSignal("Visible"):Connect(UpdateConsoleOutside)
UpdateConsoleOutside()

--// CLEAR
_G.TDSHubConsoleClear = function()

	for _, v in ipairs(ConsoleScrolling:GetChildren()) do
		if v:IsA("TextLabel") and v ~= OutputSample then
			v:Destroy()
		end
	end

	for _, v in ipairs(OutsideScrolling:GetChildren()) do
		if v:IsA("TextLabel") and v ~= OutputSampleOutside then
			v:Destroy()
		end
	end

	LineCount = 0

	ConsoleScrolling.CanvasPosition = Vector2.new(0, 0)
	OutsideScrolling.CanvasPosition = Vector2.new(0, 0)

end

--// API
_G.TDSHubConsole = PushConsole

--// LOAD QUEUE
if _G.TDSHubConsoleQueue and type(_G.TDSHubConsoleQueue) == "table" then
	for _, item in ipairs(_G.TDSHubConsoleQueue) do
		PushConsole(item)
	end
end

--[[ API

_G.TDSHubConsole({
	Title = "System",
	Text = "Hello work",
	Color = Color3.fromRGB(180, 150, 180)
})

]]
