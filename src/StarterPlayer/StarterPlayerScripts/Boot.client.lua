--!nonstrict
-- THE RANDOM STORY - client boot. Requires every client module and initialises them.
-- Every require/init is isolated: one broken module can never stop the others (the
-- HUD in particular must always come up so the profile reaches the client).
if not game:IsLoaded() then
	game.Loaded:Wait()
end
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local folder = script.Parent:WaitForChild("Client")
local C = require(folder:WaitForChild("C"))

-- restyle the ReplicatedFirst loading screen (it stays up until ClientReady)
pcall(function()
	local pg = player:FindFirstChildOfClass("PlayerGui")
	local lg = pg and pg:FindFirstChild("Loading")
	if not lg then
		return
	end
	for _, d in lg:GetDescendants() do
		if d:IsA("TextLabel") then
			if d.Text == "THE RANDOM STORY" then
				d.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
				d.TextColor3 = Color3.fromRGB(232, 226, 214)
				d.TextSize = 56
			else
				d.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular)
				d.TextColor3 = Color3.fromRGB(168, 160, 146)
				d.TextSize = 18
			end
		elseif d:IsA("Frame") and d.Size.X.Offset > 0 and d.Size.X.Offset < 60 then
			d.BackgroundColor3 = Color3.fromRGB(170, 24, 32)
			d.Size = UDim2.fromOffset(18, 18)
		elseif d:IsA("Frame") then
			d.BackgroundColor3 = Color3.fromRGB(10, 9, 12)
		end
	end
end)

local ORDER = {
	"Audio", "UI", "Controller", "Viewmodel", "CombatClient", "TimeStopFX", "Animator", "Mount",
	"FX", "Projectiles", "HUD", "Dialogue", "Cutscene", "Mood", "Menu", "Inventory", "Scenes", "Titan", "PvPClient", "Ambient",
}
for _, name in ORDER do
	local ok, mod = pcall(require, folder:WaitForChild(name))
	if ok then
		C[name] = mod
	else
		C.report("Boot load " .. name, mod)
		C[name] = {}
	end
end
for _, name in ORDER do
	local m = C[name]
	if type(m) == "table" and type(m.init) == "function" then
		local ok, err = pcall(m.init)
		if not ok then
			C.report("Boot init " .. name, err)
		end
	end
end
player:SetAttribute("ClientReady", true)
