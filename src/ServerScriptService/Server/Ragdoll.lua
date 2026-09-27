--!nonstrict
-- R6 ragdolls. Joints are swapped for BallSocketConstraints on the server (so every
-- client agrees on the physics), the owner client flips its humanoid to Physics.
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local Ragdoll = {}

local GROUP = "Ragdoll"
pcall(function()
	PhysicsService:RegisterCollisionGroup(GROUP)
	PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
end)

local LIMITS = {
	Neck = { up = 45, twist = 40 },
	["Right Shoulder"] = { up = 100, twist = 60 },
	["Left Shoulder"] = { up = 100, twist = 60 },
	["Right Hip"] = { up = 60, twist = 30 },
	["Left Hip"] = { up = 60, twist = 30 },
}

function Ragdoll.isRagdolled(model: Model): boolean
	return model:GetAttribute("Ragdoll") == true
end

function Ragdoll.enable(model: Model, velocity: Vector3?, spin: number?)
	if not model or not model.Parent or Ragdoll.isRagdolled(model) then
		local pl = model and Players:GetPlayerFromCharacter(model)
		if pl and velocity then
			-- the owner client simulates its own body: hand it the new velocity (juggles)
			Net.fire(pl, "Ragdoll", { on = true, vel = velocity, spin = spin })
			return
		end
		if model and velocity then
			local torso = model:FindFirstChild("Torso") :: BasePart
			if torso and not torso.Anchored then
				torso.AssemblyLinearVelocity += velocity
			end
		end
		return
	end
	model:SetAttribute("Ragdoll", true)
	local torso = model:FindFirstChild("Torso") :: BasePart
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not torso then
		return
	end
	for jn, lim in LIMITS do
		local m = torso:FindFirstChild(jn) :: Motor6D
		if m and m:IsA("Motor6D") and m.Part1 then
			local a0 = Instance.new("Attachment")
			a0.Name = "RagA0_" .. jn
			a0.CFrame = m.C0
			a0.Parent = m.Part0
			local a1 = Instance.new("Attachment")
			a1.Name = "RagA1_" .. jn
			a1.CFrame = m.C1
			a1.Parent = m.Part1
			local bs = Instance.new("BallSocketConstraint")
			bs.Name = "RagSocket"
			bs.Attachment0 = a0
			bs.Attachment1 = a1
			bs.LimitsEnabled = true
			bs.UpperAngle = lim.up
			bs.TwistLimitsEnabled = true
			bs.TwistLowerAngle = -lim.twist
			bs.TwistUpperAngle = lim.twist
			bs.Parent = torso
			m.Enabled = false
			-- collider so limbs hit the floor
			local limb = m.Part1
			local c = Instance.new("Part")
			c.Name = "RagCollider"
			c.Size = limb.Size * Vector3.new(0.8, 0.8, 0.8)
			c.Transparency = 1
			c.CanQuery = false
			c.CanTouch = false
			c.Massless = false
			c.CFrame = limb.CFrame
			c.CollisionGroup = GROUP
			local w = Instance.new("WeldConstraint")
			w.Part0 = limb
			w.Part1 = c
			w.Parent = c
			c.Parent = limb
		end
	end
	torso.CollisionGroup = GROUP
	if hrp then
		hrp.CanCollide = false
		hrp.Massless = true
		hrp.CollisionGroup = GROUP
	end
	local player = Players:GetPlayerFromCharacter(model)
	if player then
		Net.fire(player, "Ragdoll", { on = true, vel = velocity, spin = spin })
	else
		if hum then
			hum.PlatformStand = true
			hum.AutoRotate = false
			hum:ChangeState(Enum.HumanoidStateType.Physics)
		end
		if velocity and not torso.Anchored then
			torso.AssemblyLinearVelocity = velocity
			torso.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * (spin or 8)
		end
	end
end

function Ragdoll.disable(model: Model)
	if not model or not Ragdoll.isRagdolled(model) then
		return
	end
	model:SetAttribute("Ragdoll", false)
	local torso = model:FindFirstChild("Torso") :: BasePart
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local hum = model:FindFirstChildOfClass("Humanoid")
	for _, d in model:GetDescendants() do
		if d.Name == "RagSocket" or d.Name == "RagCollider" or d.Name:sub(1, 4) == "RagA" then
			d:Destroy()
		elseif d:IsA("Motor6D") then
			d.Enabled = true
		end
	end
	local group = if Players:GetPlayerFromCharacter(model) then "Players" else "NPC"
	if torso then
		torso.CollisionGroup = group
	end
	if hrp then
		hrp.CollisionGroup = group
		hrp.Massless = false
		-- stand the root back up where the torso ended up
		if torso and not hrp.Anchored then
			local p = torso.Position
			local look = torso.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude < 0.1 then
				flat = Vector3.new(0, 0, -1)
			end
			hrp.CFrame = CFrame.lookAt(p + Vector3.new(0, 1.5, 0), p + Vector3.new(0, 1.5, 0) + flat.Unit)
		end
	end
	local player = Players:GetPlayerFromCharacter(model)
	if player then
		Net.fire(player, "Ragdoll", { on = false })
	elseif hum and hum.Health > 0 then
		hum.PlatformStand = false
		hum.AutoRotate = true
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

-- Knock a living model down for `duration` seconds, then stand it back up.
function Ragdoll.knock(model: Model, velocity: Vector3, duration: number)
	Ragdoll.enable(model, velocity)
	local token = ((model:GetAttribute("RagToken") :: any) or 0) + 1
	model:SetAttribute("RagToken", token)
	task.delay(duration, function()
		if model.Parent and model:GetAttribute("RagToken") == token then
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and not model:GetAttribute("Frozen") then
				Ragdoll.disable(model)
			elseif hum and hum.Health > 0 then
				-- still frozen by a time stop: try again shortly
				task.delay(0.3, function()
					if model.Parent and model:GetAttribute("RagToken") == token then
						Ragdoll.disable(model)
					end
				end)
			end
		end
	end)
end

return Ragdoll
