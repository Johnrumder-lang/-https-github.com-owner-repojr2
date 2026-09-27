--!nonstrict
-- Procedural animation for every tagged rig (NPCs, other players, cutscene actors).
-- Writes Motor6D.Transform in PreSimulation; freezes when the rig is Frozen.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Anim = require(Shared.Anim)
local Rig = require(Shared.Rig)
local Animator = {}
local rigs = {} -- [model] = state
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera

local function setup(model: Model)
	if rigs[model] then
		return
	end
	local torso = model:WaitForChild("Torso", 5)
	local hrp = model:WaitForChild("HumanoidRootPart", 5)
	if not torso or not hrp then
		return
	end
	local motors = {}
	for _, jn in Rig.JOINT_ORDER do
		local m = if jn == "RootJoint" then hrp:WaitForChild("RootJoint", 3) else torso:WaitForChild(jn, 3)
		if m then
			motors[jn] = m
		end
	end
	rigs[model] = {
		motors = motors,
		root = hrp,
		hum = model:FindFirstChildOfClass("Humanoid"),
		pose = Anim.zero(),
		t = math.random() * 10,
		phase = 0,
		skip = 0,
		out = {},
		opts = {},
		scale = model:GetScale(),
	}
end

local function remove(model)
	rigs[model] = nil
end

local tmpTarget = {}
local function step(dt: number)
	local now = workspace:GetServerTimeNow()
	local camPos = cam.CFrame.Position
	for model, st in rigs do
		if not model.Parent then
			rigs[model] = nil
			continue
		end
		if model:GetAttribute("Frozen") or model:GetAttribute("Ragdoll") or model:GetAttribute("Dead") or model:GetAttribute("Paused") then
			continue
		end
		local root = st.root
		if not root.Parent then
			continue
		end
		local dist = (root.Position - camPos).Magnitude
		if dist > 600 then
			continue
		end
		local rate = if dist > 180 then 4 elseif dist > 90 then 2 else 1
		st.skip += 1
		if st.skip < rate then
			continue
		end
		st.skip = 0
		local sdt = dt * rate
		st.t += sdt
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local hum = st.hum
		local grounded = true
		if hum then
			grounded = hum.FloorMaterial ~= Enum.Material.Air or math.abs(v.Y) < 2
			if hum.PlatformStand then
				grounded = true
			end
		end
		st.phase += sdt
		-- movement state: this client drives its own body, everybody else's comes from the server
		local state = if model == player.Character then model:GetAttribute("MoveState") else model:GetAttribute("MoveStateS")
		st.opts.state = state
		st.opts.quad = model:GetAttribute("Quad") == true
		st.opts.fly = model:GetAttribute("Flying") == true
		st.opts.hover = model:GetAttribute("Hover") == true
		local base = Anim.locomotion(st.t, speed / st.scale, grounded, v.Y, model:GetAttribute("Hunch") == true, false, st.opts)
		local poseName = model:GetAttribute("Pose")
		if poseName then
			local fn = Anim.LOOPS[poseName]
			if fn then
				fn(st.t, base)
			end
		end
		local target = base
		local act = model:GetAttribute("Act")
		local rateK = 16
		if act then
			local t0 = model:GetAttribute("ActT0") or now
			local w = model:GetAttribute("ActW") or 0.3
			local a = model:GetAttribute("ActA") or 0.15
			local r = model:GetAttribute("ActR") or 0.4
			local p = Anim.actionPose(act, now - t0, w, a, r, base, tmpTarget)
			if p then
				target = p
				rateK = 34
			end
		end
		if state == "dash" or state == "walljump" then
			rateK = 30 -- snap into the quick poses
		end
		local k = 1 - math.exp(-rateK * sdt)
		Anim.blend(st.pose, target, k, st.pose)
		Anim.toTransforms(st.pose, st.out)
		for jn, m in st.motors do
			local tr = st.out[jn]
			if tr then
				m.Transform = tr
			end
		end
	end
end

function Animator.init()
	for _, m in CollectionService:GetTagged("Rig") do
		task.spawn(setup, m)
	end
	CollectionService:GetInstanceAddedSignal("Rig"):Connect(function(m)
		task.spawn(setup, m)
	end)
	CollectionService:GetInstanceRemovedSignal("Rig"):Connect(remove)
	RunService.PreSimulation:Connect(step)
end

return Animator
