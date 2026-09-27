--!nonstrict
-- Loading screen shown before anything else replicates.
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "Loading"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1000
gui.ResetOnSpawn = false
local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.new(0, 0, 0)
bg.BorderSizePixel = 0
bg.Parent = gui
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 80)
title.Position = UDim2.fromScale(0, 0.4)
title.BackgroundTransparency = 1
title.Font = Enum.Font.Arcade
title.TextSize = 64
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "THE RANDOM STORY"
title.Parent = bg
local cube = Instance.new("Frame")
cube.Size = UDim2.fromOffset(28, 28)
cube.AnchorPoint = Vector2.new(0.5, 0.5)
cube.Position = UDim2.new(0.5, 0, 0.4, 130)
cube.BackgroundColor3 = Color3.fromRGB(190, 170, 255)
cube.BorderSizePixel = 0
cube.Parent = bg
local tip = Instance.new("TextLabel")
tip.Size = UDim2.new(1, 0, 0, 30)
tip.Position = UDim2.new(0, 0, 0.4, 170)
tip.BackgroundTransparency = 1
tip.Font = Enum.Font.RobotoMono
tip.TextSize = 18
tip.TextColor3 = Color3.fromRGB(170, 170, 185)
local TIPS = {
	"Hits during a time stop land all at once when time resumes.",
	"Red flash: you can't parry it. Dash.",
	"Yellow flash: slide under it.",
	"A perfect parry refunds a second of time stop cooldown.",
	"Hold attack for a heavy swing that launches enemies.",
	"Look both ways before crossing the street.",
}
tip.Text = TIPS[math.random(1, #TIPS)]
tip.Parent = bg
gui.Parent = player:WaitForChild("PlayerGui")
local conn = RunService.RenderStepped:Connect(function()
	cube.Rotation = (os.clock() * 180) % 360
end)
if not game:IsLoaded() then
	game.Loaded:Wait()
end
local t0 = os.clock()
while not player:GetAttribute("ClientReady") and os.clock() - t0 < 20 do
	task.wait(0.1)
end
task.wait(0.4)
TweenService:Create(bg, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
TweenService:Create(title, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
TweenService:Create(tip, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
TweenService:Create(cube, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
task.wait(0.9)
conn:Disconnect()
gui:Destroy()
