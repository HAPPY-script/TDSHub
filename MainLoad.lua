if _G.TDSHub then
    warn("Script đã chạy! Không thể chạy lại.")
    return
end
_G.TDSHub = true

print("UI: [🔴]")
loadstring(game:HttpGet("https://raw.githubusercontent.com/HAPPY-script/TDSHub/refs/heads/main/LoadUI.lua"))()
print("UI: [🟢]")

print("Execute program: [🔴]")
loadstring(game:HttpGet("https://raw.githubusercontent.com/HAPPY-script/TDSHub/refs/heads/main/Execute_program.lua"))()
print("Execute program: [🟢]")

print("Console: [🔴]")
loadstring(game:HttpGet("https://raw.githubusercontent.com/HAPPY-script/TDSHub/refs/heads/main/Console_system.lua"))()
print("Console: [🟢]")

print("Change tab: [🔴]")
loadstring(game:HttpGet("https://raw.githubusercontent.com/HAPPY-script/TDSHub/refs/heads/main/ChangeTab_system.lua"))()
print("Change tab: [🟢]")

print("Load program: [🔴]")
loadstring(game:HttpGet("https://raw.githubusercontent.com/HAPPY-script/TDSHub/refs/heads/main/LoadProgram.lua"))()
print("Load program: [🟢]")

print("Builder program: [🔴]")
loadstring(game:HttpGet("https://raw.githubusercontent.com/HAPPY-script/TDSHub/refs/heads/main/BuilderProgram.lua"))()
print("Builder program: [🟢]")

print("Setting program: [🔴]")
loadstring(game:HttpGet("https://raw.githubusercontent.com/HAPPY-script/TDSHub/refs/heads/main/SettingProgram.lua"))()
print("Setting program: [🟢]")

print("✅Done all✅")
