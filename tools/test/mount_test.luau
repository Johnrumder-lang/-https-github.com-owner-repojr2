--@stubs world_stubs
--@server World, Fauna, Mounts
-- Smoke test: the saddled horse and the summon / ride / dismount flow on a fake
-- character (Server/Mounts): welds, hip height, attributes, clean-up.
local S = {}
__mods["srv:S"] = function()
	return S
end
S.World = require(Server.World)
S.Fauna = require(Server.Fauna)
S.Mounts = require(Server.Mounts)
S.Director = { state = { zone = "fields" } }
local prof = { horseTier = 0 }
S.State = {
	run = { flags = { pitDone = true } },
	profile = function()
		return prof
	end,
}
local RNG = require(Shared.RNG)

-- the horse itself
local m, saddle = S.Fauna.steed(workspace, CFrame.new(0, 0, 0), RNG.new(5))
for _, n in { "Body", "Head", "Tail", "Saddle", "Leg1", "Leg2", "Leg3", "Leg4", "Hoof1", "Hoof4" } do
	assert(m:FindFirstChild(n), "steed is missing " .. n)
end
assert(saddle > 4.5 and saddle < 6, "saddle height " .. saddle)
local n = 0
for _, d in m:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
print(string.format("steed: %d parts, saddle %.2f", n, saddle))
m:Destroy()

-- a fake rider
local char = Instance.new("Model")
char.Name = "Rider"
local root = Instance.new("Part")
root.Name = "HumanoidRootPart"
root.Size = Vector3.new(2, 2, 1)
root.CFrame = CFrame.new(10, 3, 10)
root.Parent = char
char.PrimaryPart = root
local hum = Instance.new("Humanoid")
hum.Health = 100
hum.HipHeight = 0
hum.Parent = char
char.Parent = workspace
local player = { UserId = 4242, Character = char, Name = "Tester" }

-- underground: refused
S.Director.state.zone = "pit"
assert(not S.Mounts.mount(player), "a horse in the pit")
S.Director.state.zone = "fields"
assert(S.Mounts.mount(player), "mount failed")
assert(S.Mounts.isMounted(player))
assert(char:GetAttribute("Mounted") == true and char:GetAttribute("Pose") == "Ride", "rider attributes")
assert(hum.HipHeight > 2.5 and hum.HipHeight < 4, "hip height " .. hum.HipHeight)
local horse = workspace:FindFirstChild("Mounts"):FindFirstChild("Horse")
assert(horse, "no horse in workspace.Mounts")
local welds = 0
for _, d in horse:GetDescendants() do
	if d:IsA("BasePart") then
		assert(not d.Anchored and not d.CanCollide and d.Massless, "horse part physics " .. d.Name)
		local w = d:FindFirstChild("MountWeld")
		assert(w and w.Part0 == root, "unwelded horse part " .. d.Name)
		welds += 1
	end
end
print(string.format("mounted: %d welds, hip %.2f", welds, hum.HipHeight))
S.Mounts.dismount(player)
assert(not S.Mounts.isMounted(player))
assert(char:GetAttribute("Mounted") == nil and char:GetAttribute("Pose") == nil, "dismount attributes")
assert(hum.HipHeight == 0, "hip height restored")
assert(horse.Parent == nil, "horse removed")
-- a bought destrier: barding, faster
prof.horseTier = 2
S.Mounts.toggle(player)
assert(S.Mounts.isMounted(player), "remount failed")
local destrier = workspace:FindFirstChild("Mounts"):FindFirstChild("Horse")
assert(destrier and destrier:FindFirstChild("Peytral"), "destrier has no barding")
assert((char:GetAttribute("HorseMult") or 0) > 2.4, "destrier is not faster")
S.Mounts.dismount(player)
assert(char:GetAttribute("HorseMult") == nil)
print("OK")
