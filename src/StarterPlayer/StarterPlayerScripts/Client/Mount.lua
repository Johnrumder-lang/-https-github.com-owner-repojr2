--!nonstrict
-- The summoned horse on the client. H asks the server for it (Server/Mounts);
-- every horse (tag "Mount") is animated here by editing its welds' C0 from the
-- rider's speed: a trot (diagonal leg pairs) that turns into a gallop, legs
-- tucked in the air, a nodding head, a swishing tail, hoofbeats under you.
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local C = require(script.Parent.C)

local Mount = {}
local CF = CFrame.new
local ANG = CFrame.Angles
local TAU = math.pi * 2
local player = Players.LocalPlayer

-- parts that move with the head
local HEAD = { Head = true, Eye = true, Ear = true, Bridle = true, Bit = true, Forelock = true, Snout = true }
-- leg phase offsets (fractions of a stride): 1 front-left, 2 front-right, 3 back-left, 4 back-right
local TROT = { 0, 0.5, 0.5, 0 }
local GALLOP = { 0, 0.18, 0.55, 0.72 }

local horses = {} -- [model] = state

local function register(m: Instance)
	if horses[m] or not m:IsA("Model") then
		return
	end
	local welds = {}
	local root = nil
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			local w = p:FindFirstChild("MountWeld")
			if w and w:IsA("Weld") and w.Part0 then
				root = root or w.Part0
				welds[p] = w
			end
		end
	end
	if not root then
		return
	end
	-- pivots in rider-root space (the welds' C0 place each part relative to the rider)
	local legPivot = {}
	local headPivot, tailPivot = nil, nil
	for p, w in welds do
		local idx = p.Name:match("^Leg(%d)$")
		if idx then
			legPivot[tonumber(idx)] = (w.C0 * CF(0, p:GetAttribute("Pivot") or p.Size.Y / 2, 0)).Position
		elseif p.Name == "Head" then
			headPivot = (w.C0 * CF(0, 0, p:GetAttribute("Pivot") or p.Size.Z / 2)).Position
		elseif p.Name == "Tail" then
			tailPivot = (w.C0 * CF(0, p:GetAttribute("Pivot") or p.Size.Y / 2, 0)).Position
		end
	end
	local st = { root = root, parts = {}, phase = math.random() * TAU, t = 0, lastBeat = 0, mine = m:GetAttribute("Rider") == player.UserId }
	for p, w in welds do
		local leg = p.Name:match("^Leg(%d)$") or p.Name:match("^Hoof(%d)$")
		local g = nil
		if leg and legPivot[tonumber(leg)] then
			g = { kind = "leg", i = tonumber(leg), at = legPivot[tonumber(leg)] }
		elseif HEAD[p.Name] and headPivot then
			g = { kind = "head", at = headPivot }
		elseif p.Name == "Tail" and tailPivot then
			g = { kind = "tail", at = tailPivot }
		end
		if g then
			table.insert(st.parts, { w = w, base = w.C0, g = g })
		end
	end
	horses[m] = st
end

local function step(dt: number)
	local camPos = workspace.CurrentCamera.CFrame.Position
	for m, st in horses do
		local root = st.root
		if not m.Parent or not root or not root.Parent then
			horses[m] = nil
			continue
		end
		if (root.Position - camPos).Magnitude > 450 then
			continue
		end
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local k = math.clamp(speed / 40, 0, 1)
		local gallop = speed > 46
		local airborne = math.abs(v.Y) > 10
		st.t += dt
		if speed > 1 then
			st.phase += dt * (3 + math.min(speed, 90) * 0.15)
		end
		for _, e in st.parts do
			local g = e.g
			local rot
			if g.kind == "leg" then
				local a
				if airborne then
					-- front legs tucked, back legs stretched out
					a = if g.i <= 2 then 0.65 else -0.55
				else
					local off = (if gallop then GALLOP else TROT)[g.i]
					a = math.sin(st.phase + off * TAU) * (0.25 + 0.5 * k) * math.min(1, speed / 3)
				end
				rot = ANG(a, 0, 0)
			elseif g.kind == "head" then
				local a = math.sin(st.phase * 2) * 0.1 * k - 0.08 * k + math.sin(st.t * 0.8) * 0.05 * (1 - k)
				rot = ANG(a, 0, 0)
			else
				rot = ANG(-(0.12 + 0.8 * k), 0, math.sin(st.t * 2.3) * 0.25 * (1 - k * 0.6))
			end
			e.w.C0 = CF(g.at) * rot * CF(-g.at) * e.base
		end
		-- hoofbeats under you
		if st.mine and not airborne and speed > 4 and C.Audio and C.Audio.play then
			local beat = math.floor((st.phase / TAU) * (if gallop then 3 else 2))
			if beat ~= st.lastBeat then
				st.lastBeat = beat
				C.Audio.play("Step", { vol = 1.1, pitch = if gallop then 0.5 else 0.6 })
			end
		end
	end
end

function Mount.init()
	local function added(m)
		-- the welds replicate with the model; give them a moment on a slow join
		task.delay(0.2, register, m)
	end
	for _, m in CollectionService:GetTagged("Mount") do
		added(m)
	end
	CollectionService:GetInstanceAddedSignal("Mount"):Connect(added)
	CollectionService:GetInstanceRemovedSignal("Mount"):Connect(function(m)
		horses[m] = nil
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.H or input.KeyCode == Enum.KeyCode.DPadDown then
			if C.Controller and C.Controller.mode == "play" and not C.wantsCursor() then
				Net.send("Input", "Horse")
			end
		end
	end)
	RunService.PreSimulation:Connect(step)
end

return Mount
