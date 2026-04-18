local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local ScreenGui = PlayerGui:WaitForChild("TDSHub")

local ManageProgramFrame = ScreenGui:WaitForChild("ManageProgramFrame")

local LoadProgramTabButton = ManageProgramFrame:WaitForChild("LoadProgramTabButton")
local CustomProgramTabButton = ManageProgramFrame:WaitForChild("CustomProgramTabButton")

local LoadProgramButton = ManageProgramFrame:WaitForChild("LoadProgramButton")
local ProgramBox = ManageProgramFrame:WaitForChild("ProgramBox")

local CustomProgramUI = ManageProgramFrame:WaitForChild("CustomProgramUI")

local LoadTabStroke = LoadProgramTabButton:WaitForChild("UIStroke")
local CustomTabStroke = CustomProgramTabButton:WaitForChild("UIStroke")

local function SetTab(tab)

	if tab == "load" then

		-- Load UI
		LoadProgramButton.Visible = true
		ProgramBox.Visible = true

		-- Custom UI
		for _,obj in ipairs(CustomProgramUI:GetChildren()) do
			if obj:IsA("GuiObject") then
				obj.Visible = false
			end
		end

		LoadTabStroke.Enabled = true
		CustomTabStroke.Enabled = false


	elseif tab == "custom" then

		-- Load UI
		LoadProgramButton.Visible = false
		ProgramBox.Visible = false

		-- Custom UI
		for _,obj in ipairs(CustomProgramUI:GetChildren()) do
			if obj:IsA("GuiObject") then
				obj.Visible = true
			end
		end

		LoadTabStroke.Enabled = false
		CustomTabStroke.Enabled = true

	end

end


LoadProgramTabButton.MouseButton1Click:Connect(function()
	SetTab("load")
end)

CustomProgramTabButton.MouseButton1Click:Connect(function()
	SetTab("custom")
end)

-- đảm bảo mặc định là Load
for _,obj in ipairs(CustomProgramUI:GetChildren()) do
	if obj:IsA("GuiObject") then
		obj.Visible = false
	end
end

task.defer(function()
	SetTab("load")
end)
