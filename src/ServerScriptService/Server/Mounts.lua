--!nonstrict
-- The summoned horse (H). A saddled horse (Fauna.steed) is welded under the
-- rider: the rider's hip height is raised so they sit in the saddle (R6: the
-- HipHeight is an offset), the body takes the "Ride" pose, and the client
-- controller multiplies the walk speed while the character has "Mounted". Every
-- client animates the horse's legs, head and tail from the rider's speed
-- (Client/Mount). Ragdolls, cutscene locks and death all throw you off.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local RNG = require(Shared.RNG)
local Kit = require(Shared.Kit)
local S = require(script.Parent.S)

local Mounts = {}
local V = Vector3.new
local CF = CFrame.new

Mounts.COOLDOWN = 1.0
-- no horses underground, indoors, in the modern prologue or in the other worlds
Mounts.NO_ZONES = {
	pit = true,
	whiteroom = true,
	space = true,
	void = true,
	antilight = true,
	cell = true,
	office = true,
	apartment = true,
	street_day = true,
	street_evening = true,
	street_night = true,
	ritual = true,
	elder = true,
	tower = true,
}

local riders = {} -- [player] = { model, conns, char, hip }
local lastToggle = {}
local told = {}

local function folder(): Instance
	local f = workspace:FindFirstChild("Mounts")
	if not f then
		f = Kit.folder("Mounts", workspace)
	end
	return f
end

function Mounts.isMounted(player: Player): boolean
	return riders[player] ~= nil
end

function Mounts.dismount(player: Player, quiet: boolean?)
	local st = riders[player]
	if not st then
		return
	end
	riders[player] = nil
	for _, c in st.conns do
		c:Disconnect()
	end
	local pos = st.model and st.model.PrimaryPart and st.model.PrimaryPart.Position
	if st.model then
		st.model:Destroy()
	end
	local char = st.char
	if char and char.Parent then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.HipHeight = st.hip
		end
		char:SetAttribute("Mounted", nil)
		if char:GetAttribute("Pose") == "Ride" then
			char:SetAttribute("Pose", nil)
		end
	end
	if pos and not quiet then
		Net.fireAll("FX", "Dust", { pos = pos - V(0, 2, 0), count = 14, color = Color3.fromRGB(150, 130, 100) })
	end
end

-- why the horse can't come right now (nil = it can)
function Mounts.blocked(player: Player): string?
	local char = player.Character
	local root = char and char.PrimaryPart
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return "dead"
	end
	if char:GetAttribute("Locked") or char:GetAttribute("Ragdoll") or char:GetAttribute("Stun") then
		return "Not now"
	end
	local zone = S.Director and S.Director.state and S.Director.state.zone
	local run = S.State.run
	if (zone and Mounts.NO_ZONES[zone]) or (run and run.flags and not run.flags.pitDone and zone ~= "Arena") then
		return "Your horse can't reach you here"
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, folder() }
	if workspace:Raycast(root.Position, V(0, 6 * char:GetScale(), 0), params) then
		return "No room for a horse here"
	end
	return nil
end

function Mounts.mount(player: Player): boolean
	local why = Mounts.blocked(player)
	if why then
		if why ~= "dead" then
			Net.fire(player, "Notify", { kind = "info", text = why })
		end
		return false
	end
	local char = player.Character
	local root = char.PrimaryPart :: BasePart
	local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid
	local sc = char:GetScale()
	-- the horse stands under the rider, facing where they face (a stable colour per player)
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude < 0.1 then
		look = V(0, 0, -1)
	end
	local flat = CFrame.lookAt(root.Position, root.Position + look.Unit)
	local ground = flat * CF(0, -3 * sc, -0.35 * sc)
	local rng = RNG.new(player.UserId % 100000 + 17)
	local model, saddle = S.Fauna.steed(nil, ground, rng)
	if math.abs(sc - 1) > 0.01 then
		model:ScaleTo(sc)
	end
	-- the rider's hips (bottom of the torso, 1 stud under the root) sit on the saddle
	local lift = (saddle + 1 - 3) * sc
	local liftedRoot = root.CFrame + V(0, lift, 0)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			local w = Instance.new("Weld")
			w.Name = "MountWeld"
			w.Part0 = root
			w.Part1 = p
			w.C0 = liftedRoot:ToObjectSpace(p.CFrame)
			w.Parent = p
		end
	end
	model:SetAttribute("Rider", player.UserId)
	model.Parent = folder()
	CollectionService:AddTag(model, "Mount")
	local st = { model = model, char = char, hip = hum.HipHeight, conns = {} }
	riders[player] = st
	hum.HipHeight = st.hip + lift
	root.CFrame = liftedRoot
	char:SetAttribute("Mounted", true)
	char:SetAttribute("Pose", "Ride")
	Net.fireAll("FX", "Dust", { pos = ground.Position, count = 18, color = Color3.fromRGB(150, 130, 100) })
	Net.fireAll("FX", "Sound", { name = "Land", pos = ground.Position, pitch = 0.6 })
	table.insert(st.conns, hum.Died:Connect(function()
		Mounts.dismount(player, true)
	end))
	for _, attr in { "Locked", "Ragdoll" } do
		table.insert(st.conns, char:GetAttributeChangedSignal(attr):Connect(function()
			if char:GetAttribute(attr) then
				Mounts.dismount(player, true)
			end
		end))
	end
	table.insert(st.conns, char.AncestryChanged:Connect(function()
		if not char:IsDescendantOf(workspace) then
			Mounts.dismount(player, true)
		end
	end))
	if not told[player] then
		told[player] = true
		Net.fire(player, "Notify", { kind = "info", text = "Your horse", sub = "Hold SHIFT to gallop  ·  H to dismount" })
	end
	return true
end

-- H: summon / dismiss
function Mounts.toggle(player: Player)
	local now = os.clock()
	if now - (lastToggle[player] or 0) < Mounts.COOLDOWN then
		return
	end
	lastToggle[player] = now
	if riders[player] then
		Mounts.dismount(player)
	else
		Mounts.mount(player)
	end
end

function Mounts.dismountAll()
	for p in riders do
		Mounts.dismount(p, true)
	end
end

function Mounts.init()
	Players.PlayerRemoving:Connect(function(p)
		Mounts.dismount(p, true)
		lastToggle[p] = nil
		told[p] = nil
	end)
end

return Mounts
