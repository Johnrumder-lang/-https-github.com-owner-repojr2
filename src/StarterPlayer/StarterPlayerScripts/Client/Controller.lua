--!nonstrict
-- Camera + movement, tuned for ULTRAKILL / DOOM speed:
--   run 25 st/s, SHIFT dash (3 charges, works in the air, keeps momentum), hold SHIFT
--   after a dash to sprint, CTRL/C slide (lasts while held, slide-jump = long jump),
--   CTRL in the air = ground slam (shockwave, slam-jump goes higher), wall jumps (3),
--   double jump, coyote time + jump buffer, momentum carried through the air.
-- Cameras: first person (default) and an over-the-shoulder third person (V).
-- Death / ragdoll: the local body really falls (client-side topple) with an orbit cam,
-- thrown away from whatever landed the last hit.
-- v4: directional air dashes (they follow the camera), dash-stabs through enemies,
-- slams from any jump height, MoveState attributes that drive third-person poses,
-- camera motion blur.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Util = require(Shared.Util)
local C = require(script.Parent.C)

local Controller: any = {}
Controller.sprintHeld = false
Controller.shiftAt = nil
Controller.yaw = 0
Controller.pitch = 0
Controller.mode = "menu"
Controller.camMode = "first" -- "first" | "third"
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local P = Config.Player

local char, hum, root, align = nil, nil, nil, nil
local sprintK = 0
local controls = nil
local dashCharges = P.dashCharges
local dashRecharge = 0
local dashUntil = 0
local sliding = false
local slideT = 0
local slideDir = Vector3.zero
local slideSpeed = 0
local slideLV: LinearVelocity? = nil
local slideLower = 0
local slamming = false
local slamFrom = 0
local slamLandedAt = -10
local doubleJumped = false
local wallJumpsLeft = P.wallJumps
local lastWallJump = 0
local momentum = 0 -- extra flat speed carried by the humanoid (air momentum)
local airT = 0
local lastGroundedAt = 0
local jumpReqAt = -10
local jumpedSinceGround = false
local hangUntil = 0
local bobT = 0
local bobAmt = 0
local landDip = 0
local landVel = 0
local lastVy = 0
local shakeI, shakeT, shakeMax = 0, 0, 0.001
local kickP, kickY = 0, 0
local fovPunch = 0
local roll = 0
local padLook = Vector2.zero
local stepSide = 1
local stepCd = 0
local stepUpCd = 0
local thirdDist = 11
local deadToppled = false
local dashDirNow = Vector3.zero
local dashStabbed = {} -- [model] = true, enemies already cut by the current dash
local dashPrevPos: Vector3? = nil
local moveState = nil
local lastCamLook = Vector3.new(0, 0, -1)
local blurFx: BlurEffect? = nil
local blurK = 0

function Controller.character()
	return char, hum, root
end

local function isGrounded(): boolean
	return hum ~= nil and hum.FloorMaterial ~= Enum.Material.Air
end
Controller.isGrounded = isGrounded

local function canMove(): boolean
	return Controller.mode == "play" and char ~= nil and not char:GetAttribute("Locked") and not char:GetAttribute("Stun") and not C.timeStop.frozenSelf and not C.wantsCursor() and not C.paused
end
Controller.canMove = canMove

local function hideSelf(hidden: boolean)
	if not char then
		return
	end
	local v = if hidden then 1 else 0
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = v
		elseif d:IsA("SurfaceGui") then
			d.Enabled = not hidden
		elseif d:IsA("ProximityPrompt") then
			-- never show prompts that sit on your own body (duel challenges etc.)
			d.Enabled = false
		end
	end
end

local lastHidden = nil
local function setHidden(h: boolean)
	if lastHidden ~= h then
		lastHidden = h
		hideSelf(h)
	end
end

local function rayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = { cam }
	if char then
		table.insert(list, char)
	end
	local fx = workspace:FindFirstChild("FX")
	if fx then
		table.insert(list, fx)
	end
	params.FilterDescendantsInstances = list
	params.IgnoreWater = true
	return params
end

local function clearMovers()
	if not root then
		return
	end
	for _, d in root:GetChildren() do
		if d:IsA("LinearVelocity") then
			d:Destroy()
		end
	end
	slideLV = nil
end

-- the local body falls over for real (physics of the own character live on this client)
local function topple(vel: Vector3?)
	if not char then
		return
	end
	clearMovers()
	sliding = false
	slamming = false
	if align then
		align.Enabled = false
	end
	local torso = char:FindFirstChild("Torso") :: BasePart
	if not torso then
		return
	end
	for _, jn in { "Neck", "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip" } do
		local m = torso:FindFirstChild(jn)
		if m and m:IsA("Motor6D") and m.Part1 and m.Enabled then
			m.Enabled = false
			if not torso:FindFirstChild("LocalSocket_" .. jn) then
				local a0 = Instance.new("Attachment")
				a0.Name = "LocalA0_" .. jn
				a0.CFrame = m.C0
				a0.Parent = m.Part0
				local a1 = Instance.new("Attachment")
				a1.Name = "LocalA1_" .. jn
				a1.CFrame = m.C1
				a1.Parent = m.Part1
				local bs = Instance.new("BallSocketConstraint")
				bs.Name = "LocalSocket_" .. jn
				bs.Attachment0 = a0
				bs.Attachment1 = a1
				bs.LimitsEnabled = true
				bs.UpperAngle = if jn:find("Shoulder") then 100 elseif jn == "Neck" then 45 else 60
				bs.TwistLimitsEnabled = true
				bs.TwistLowerAngle = -35
				bs.TwistUpperAngle = 35
				bs.Parent = torso
			end
			m.Part1.CanCollide = true
		end
	end
	torso.CanCollide = true
	local head = char:FindFirstChild("Head") :: BasePart
	if head then
		head.CanCollide = true
	end
	-- the body flies away from whoever landed the last hit
	local push = vel
	if not push then
		local hd = C.lastHurt
		if hd and os.clock() - hd.t < 2.5 and hd.dir.Magnitude > 0.1 then
			local flat = Vector3.new(hd.dir.X, 0, hd.dir.Z)
			local dir = if flat.Magnitude > 0.1 then flat.Unit else -torso.CFrame.LookVector
			push = dir * math.clamp(18 + hd.dir.Magnitude * 0.45, 18, 70) + Vector3.new(0, 10 + math.min(hd.dir.Y, 30), 0)
		else
			push = -torso.CFrame.LookVector * 10 + Vector3.new(0, 8, 0)
		end
	end
	torso.AssemblyLinearVelocity = torso.AssemblyLinearVelocity + push
	torso.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 9
end

-- MoveState drives the third-person poses (Animator) for this client; the server
-- mirrors it for everybody else from the movement inputs.
local function setMoveState(s: string?)
	if moveState == s then
		return
	end
	moveState = s
	if char then
		char:SetAttribute("MoveState", s)
	end
end
Controller.setMoveState = setMoveState

local function untopple()
	if not char then
		return
	end
	local torso = char:FindFirstChild("Torso")
	if torso then
		for _, d in torso:GetChildren() do
			if d.Name:sub(1, 12) == "LocalSocket_" then
				d:Destroy()
			end
		end
	end
	for _, d in char:GetDescendants() do
		if d:IsA("Attachment") and (d.Name:sub(1, 8) == "LocalA0_" or d.Name:sub(1, 8) == "LocalA1_") then
			d:Destroy()
		elseif d:IsA("Motor6D") and not char:GetAttribute("Ragdoll") then
			d.Enabled = true
		end
	end
end

function Controller.onCharacter(c: Model)
	char = c
	hum = c:WaitForChild("Humanoid", 10) :: Humanoid
	root = c:WaitForChild("HumanoidRootPart", 10) :: BasePart
	if not hum or not root then
		return
	end
	hum.AutoRotate = false
	hum.BreakJointsOnDeath = false
	local att = root:FindFirstChild("RootAttachment") :: Attachment
	if att then
		local ao = Instance.new("AlignOrientation")
		ao.Name = "FaceCam"
		ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
		ao.Attachment0 = att
		ao.RigidityEnabled = true
		ao.Parent = root
		align = ao
	end
	local _, y = root.CFrame:ToOrientation()
	Controller.yaw = y
	Controller.pitch = 0
	dashCharges = P.dashCharges
	sliding = false
	slamming = false
	slideLower = 0
	momentum = 0
	lastHidden = nil
	deadToppled = false
	moveState = nil
	dashStabbed = {}
	c.DescendantAdded:Connect(function(d)
		if lastHidden and d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
		elseif lastHidden and d:IsA("SurfaceGui") then
			d.Enabled = false
		elseif d:IsA("ProximityPrompt") then
			d.Enabled = false
		end
	end)
	for _, d in c:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d.Enabled = false
		end
	end
	hum.Died:Connect(function()
		if not deadToppled then
			deadToppled = true
			-- the server may already have thrown the body (Ragdoll event): don't push twice
			topple(if c:GetAttribute("Ragdoll") then Vector3.zero else nil)
		end
	end)
	hum.StateChanged:Connect(function(old, new)
		if new == Enum.HumanoidStateType.Landed then
			Controller.landed(math.abs(lastVy))
		elseif new == Enum.HumanoidStateType.Jumping then
			jumpedSinceGround = true
		end
	end)
end

local lastLandAt = 0
function Controller.landed(v: number)
	if not root then
		return
	end
	if os.clock() - lastLandAt < 0.15 and not slamming then
		return
	end
	lastLandAt = os.clock()
	local feet = root.Position - Vector3.new(0, 3, 0)
	if slamming then
		slamming = false
		slamLandedAt = os.clock()
		setMoveState(nil)
		local fall = math.max(0, slamFrom - root.Position.Y)
		Net.send("Input", "Slam", { pos = feet, fall = fall })
		Controller.shake(math.clamp(1.6 + fall / 30, 1.6, 4), 0.35)
		Controller.punch(-6)
		C.Audio.play("Slam", { pitch = 0.7, vol = 1 })
		C.Audio.play("Land", { vol = 1 })
		if C.FX then
			C.FX.dust(feet, 18, nil, 3.5, 34, 1.2)
			C.FX.cracks(feet, math.clamp(8 + fall / 6, 8, 16))
			if C.FX.ring then
				C.FX.ring(feet + Vector3.new(0, 0.2, 0), Config.Abilities.Slam.radius, Color3.fromRGB(255, 220, 190), 0.35, 0.4)
			end
		end
		landDip = -1.1
	elseif v > 30 then
		landDip = -math.clamp(v / 90, 0.15, 1.1)
		Controller.shake(math.clamp(v / 60, 0.3, 2.5), 0.2)
		C.Audio.play("Land", { vol = math.clamp(v / 80, 0.3, 1) })
		if C.FX then
			C.FX.dust(feet, math.floor(math.clamp(v / 8, 4, 16)), nil, math.clamp(v / 30, 1.5, 4), math.clamp(v / 4, 8, 26), 1)
			if v > 95 then
				C.FX.cracks(feet, math.clamp(v / 12, 6, 14))
			end
		end
	end
	doubleJumped = false
	wallJumpsLeft = P.wallJumps
	jumpedSinceGround = false
	-- jump buffer: SPACE pressed just before touching down
	if os.clock() - jumpReqAt < P.jumpBuffer and canMove() then
		jumpReqAt = -10
		task.defer(function()
			Controller.jump()
		end)
	end
end

-- ------------------------------------------------------------------ camera fx api
function Controller.shake(intensity: number, duration: number)
	intensity *= C.settings.shake or 1
	if intensity > shakeI * (shakeT / shakeMax) then
		shakeI = intensity
		shakeT = duration
		shakeMax = math.max(duration, 0.001)
	end
end

function Controller.kick(pitchDeg: number, yawDeg: number?)
	kickP += math.rad(pitchDeg)
	kickY += math.rad(yawDeg or 0)
end

function Controller.punch(fov: number)
	fovPunch += fov
end

local rollKickV = 0
function Controller.rollKick(deg: number)
	rollKickV += math.rad(deg)
end

function Controller.face(pos: Vector3)
	if not root then
		return
	end
	local from = root.Position + Vector3.new(0, 1.65, 0)
	local d = pos - from
	if d.Magnitude < 0.01 then
		return
	end
	Controller.yaw = math.atan2(-d.X, -d.Z)
	Controller.pitch = math.asin(math.clamp(d.Unit.Y, -1, 1))
end

function Controller.setYaw(y: number, p: number?)
	Controller.yaw = y
	Controller.pitch = p or 0
end

function Controller.setCamMode(m: string)
	Controller.camMode = if m == "third" then "third" else "first"
	lastHidden = nil
	if C.HUD and C.HUD.toast then
		pcall(C.HUD.toast, { kind = "info", text = if m == "third" then "THIRD PERSON" else "FIRST PERSON", sub = "V switches the camera" })
	end
end

-- keeps the player floating for a moment (air attacks / juggles)
function Controller.hang(t: number?)
	hangUntil = math.max(hangUntil, os.clock() + (t or P.airHang))
end

-- ------------------------------------------------------------------ movement abilities
local function moveDir(): Vector3
	local dir = hum and hum.MoveDirection or Vector3.zero
	if dir.Magnitude < 0.1 then
		return Util.flatUnit(cam.CFrame.LookVector)
	end
	return Util.flatUnit(dir)
end

-- Dash direction. On the ground it stays flat (input or look direction). In the air it
-- follows the camera: holding W dashes exactly where you look (up and down too), A/D
-- strafe, S dashes backwards away from the look direction.
local function dashDirection(): Vector3
	local md = hum and hum.MoveDirection or Vector3.zero
	local look = cam.CFrame.LookVector
	if isGrounded() then
		if md.Magnitude < 0.1 then
			return Util.flatUnit(look)
		end
		return Util.flatUnit(md)
	end
	if md.Magnitude < 0.1 then
		return look.Unit
	end
	local flatLook = Util.flatUnit(look)
	local right = Util.flatUnit(cam.CFrame.RightVector)
	local f = md:Dot(flatLook)
	local r = md:Dot(right)
	local dir = look * f + right * r
	if dir.Magnitude < 0.1 then
		return Util.flatUnit(md)
	end
	return dir.Unit
end

local function setCollisionGroup(group: string)
	if not char then
		return
	end
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") and d.CollisionGroup ~= "Ragdoll" then
			d.CollisionGroup = group
		end
	end
end

-- living enemy rigs near the dash path (client side; the server re-checks every stab)
local function dashStabCheck(from: Vector3, to: Vector3)
	local seg = to - from
	local len = seg.Magnitude
	if len < 0.05 then
		return
	end
	local dir = seg / len
	local radius = P.dashStabRadius or 4
	for _, m in CollectionService:GetTagged("Rig") do
		if m ~= char and not dashStabbed[m] and m.Parent and not m:GetAttribute("Dead") and not Players:GetPlayerFromCharacter(m) then
			local r = m.PrimaryPart
			local h = m:FindFirstChildOfClass("Humanoid")
			if r and h and h.Health > 0 then
				local p = r.Position
				local t = math.clamp((p - from):Dot(dir), 0, len)
				local closest = from + dir * t
				local sc = m:GetScale()
				if (p - closest).Magnitude <= radius + 1.2 * sc then
					dashStabbed[m] = true
					Controller.onDashStab(m, p, dir)
				end
			end
		end
	end
end

function Controller.onDashStab(model: Model, pos: Vector3, dir: Vector3)
	-- anime pass-through: a freeze frame, a white cut along the path, the enemy bleeds a beat later
	Net.send("Input", "DashStab", { target = model, from = pos - dir * 6, to = pos + dir * 6 })
	C.Audio.play("DashStab", { pitch = 1.25 })
	Controller.shake(1.4, 0.18)
	Controller.punch(-5)
	if C.Viewmodel and C.Viewmodel.hitstop then
		C.Viewmodel.hitstop(0.07)
		if C.Viewmodel.stab then
			C.Viewmodel.stab()
		end
	end
	if C.FX then
		if C.FX.dashCut then
			C.FX.dashCut(pos, dir, model)
		end
		C.FX.impactFrame(0.7)
		C.FX.focusLines(0.22)
	end
	if C.CombatClient and C.CombatClient.style then
		C.CombatClient.style("DASH STAB", 35)
	end
end

function Controller.dash()
	if not canMove() or dashCharges < 1 or not root or char:GetAttribute("Ragdoll") then
		return
	end
	dashCharges -= 1
	local grounded = isGrounded()
	local dir = dashDirection()
	dashDirNow = dir
	if sliding then
		Controller.endSlide(false)
	end
	slamming = false
	clearMovers()
	local lv = Instance.new("LinearVelocity")
	lv.Name = "DashLV"
	lv.Attachment0 = root:FindFirstChild("RootAttachment") :: Attachment
	lv.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	lv.MaxForce = math.huge
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = dir * P.dashSpeed
	lv.Parent = root
	dashUntil = os.clock() + P.dashTime
	dashStabbed = {}
	dashPrevPos = root.Position
	setCollisionGroup("Dashing")
	setMoveState("dash")
	task.delay(P.dashTime, function()
		if lv.Parent then
			lv:Destroy()
		end
		setCollisionGroup("Players")
		if root and root.Parent then
			local v = root.AssemblyLinearVelocity
			-- keep a good part of the dash as momentum (Ultrakill style)
			local g = isGrounded()
			local keep = if g then 0.32 else 0.45
			root.AssemblyLinearVelocity = Vector3.new(v.X * keep, math.clamp(v.Y * 0.35, -30, 22), v.Z * keep)
			momentum = math.max(momentum, if g then 8 else 24)
		end
		if moveState == "dash" then
			setMoveState(nil)
		end
		dashPrevPos = nil
	end)
	Controller.punch(12)
	Controller.kick(if dir.Y > 0.3 then -1.5 elseif dir.Y < -0.3 then 1.5 else 0, 0)
	C.Audio.play("Dash", { pitch = 1.35 })
	Net.send("Input", "Dash", { dir = dir })
	if C.FX then
		C.FX.speedLines(0.35)
		if grounded then
			C.FX.dust(root.Position - Vector3.new(0, 2.8, 0), 6, nil, 1.6, 10, 1)
		end
		if C.FX.afterimage then
			C.FX.afterimage(char, 0.35)
		end
	end
end

function Controller.endSlide(jump: boolean)
	if not sliding then
		return
	end
	sliding = false
	if slideLV then
		slideLV:Destroy()
		slideLV = nil
	end
	if moveState == "slide" then
		setMoveState(nil)
	end
	Net.send("Input", "Slide", { on = false })
	if jump and root then
		local speed = math.max(slideSpeed, P.walkSpeed) * 1.08
		root.AssemblyLinearVelocity = slideDir * speed + Vector3.new(0, P.jumpPower * 0.92, 0)
		momentum = math.max(momentum, speed - P.walkSpeed)
		jumpedSinceGround = true
		Controller.punch(6)
		C.Audio.play("Jump", { pitch = 0.9 })
	end
end

function Controller.startSlam(): boolean
	if not canMove() or not root or slamming or isGrounded() then
		return false
	end
	-- any real jump is high enough (feet are 3 studs below the root)
	local r = workspace:Raycast(root.Position, Vector3.new(0, -(3 + (P.slamMinHeight or 2.2)), 0), rayParams())
	if r then
		return false -- practically on the floor: slide instead
	end
	if sliding then
		Controller.endSlide(false)
	end
	clearMovers()
	slamming = true
	slamFrom = root.Position.Y
	momentum = 0
	setMoveState("slam")
	root.AssemblyLinearVelocity = Vector3.new(0, -P.slamSpeed, 0)
	Controller.punch(8)
	C.Audio.play("Dash", { pitch = 0.6 })
	Net.send("Input", "SlamStart")
	return true
end

-- CTRL / C: slide on the ground, slam in the air
function Controller.slide()
	if not canMove() or sliding or not root or (char and char:GetAttribute("Mounted")) then
		return
	end
	if not isGrounded() then
		if Controller.startSlam() then
			return
		end
		if airT > 0.08 then
			return
		end
	end
	local v = Util.flat(root.AssemblyLinearVelocity)
	local dir = if hum.MoveDirection.Magnitude > 0.1 then Util.flatUnit(hum.MoveDirection) elseif v.Magnitude > 4 then v.Unit else Util.flatUnit(cam.CFrame.LookVector)
	sliding = true
	slideT = 0
	slideDir = dir
	slideSpeed = math.max(P.slideSpeed, v.Magnitude * 1.05)
	local lv = Instance.new("LinearVelocity")
	lv.Name = "SlideLV"
	lv.Attachment0 = root:FindFirstChild("RootAttachment") :: Attachment
	lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	lv.MaxAxesForce = Vector3.new(1, 0, 1) * 1e6
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = dir * slideSpeed
	lv.Parent = root
	slideLV = lv
	setMoveState("slide")
	Net.send("Input", "Slide", { on = true })
	C.Audio.play("Dash", { pitch = 0.7, vol = 0.7 })
	Controller.punch(6)
	if C.FX then
		C.FX.dust(root.Position - Vector3.new(0, 2.8, 0), 5, nil, 1.2, 8, 0.6)
	end
end

-- CTRL released
function Controller.slideRelease()
	if sliding then
		Controller.endSlide(false)
	end
end

function Controller.isSliding(): boolean
	return sliding
end

function Controller.isSlamming(): boolean
	return slamming
end

function Controller.isDashing(): boolean
	return os.clock() < dashUntil
end

function Controller.dashInfo()
	return dashCharges, P.dashCharges, dashRecharge
end

function Controller.aetherStep(): boolean
	if not canMove() or not root then
		return false
	end
	local cfg = Config.Abilities.AetherStep
	local eye = root.Position + Vector3.new(0, 1.65, 0)
	local look = cam.CFrame.LookVector
	local dir = Vector3.new(look.X, math.clamp(look.Y, -0.3, 0.55), look.Z).Unit
	local r = workspace:Raycast(eye, dir * cfg.distance, rayParams())
	local dest = if r then r.Position - dir * 2.5 else eye + dir * cfg.distance
	local from = root.Position
	local to = dest - Vector3.new(0, 1.65, 0)
	root.CFrame = CFrame.new(to) * CFrame.Angles(0, Controller.yaw, 0)
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 6), v.Z)
	doubleJumped = false
	Controller.punch(14)
	Net.send("Input", "AetherStep", { from = from, to = to })
	C.Audio.play("Teleport", { pitch = 1.3 })
	if C.FX then
		C.FX.speedLines(0.35)
	end
	return true
end

-- a wall within reach of the body (for wall jumps)
local DIRS = {}
for i = 0, 7 do
	local a = i / 8 * math.pi * 2
	table.insert(DIRS, Vector3.new(math.cos(a), 0, math.sin(a)))
end
local function wallNormal(): Vector3?
	if not root then
		return nil
	end
	local params = rayParams()
	local best, bd = nil, math.huge
	for _, h in { -1.2, 0.8 } do
		local o = root.Position + Vector3.new(0, h, 0)
		for _, d in DIRS do
			local r = workspace:Raycast(o, d * 2.7, params)
			if r and math.abs(r.Normal.Y) < 0.45 and r.Distance < bd then
				best, bd = r.Normal, r.Distance
			end
		end
	end
	return best
end

function Controller.jump()
	if not canMove() or not hum or not root then
		return
	end
	local now = os.clock()
	local grounded = isGrounded()
	if sliding then
		Controller.endSlide(true)
		return
	end
	local v = root.AssemblyLinearVelocity
	if grounded then
		-- slam jump: jump right after the slam landed
		if now - slamLandedAt < 0.32 then
			slamLandedAt = -10
			root.AssemblyLinearVelocity = Vector3.new(v.X, P.jumpPower * P.slamJump, v.Z)
			jumpedSinceGround = true
			Controller.punch(6)
			C.Audio.play("Jump", { pitch = 0.8 })
			if C.FX then
				C.FX.dust(root.Position - Vector3.new(0, 3, 0), 8, nil, 2, 16, 1)
			end
		end
		return -- the humanoid does ordinary jumps itself
	end
	if slamming then
		return
	end
	-- coyote time
	if not jumpedSinceGround and now - lastGroundedAt < P.coyote then
		jumpedSinceGround = true
		root.AssemblyLinearVelocity = Vector3.new(v.X, P.jumpPower, v.Z)
		C.Audio.play("Jump")
		return
	end
	-- wall jump
	local n = if wallJumpsLeft > 0 and now - lastWallJump > 0.18 then wallNormal() else nil
	if n then
		wallJumpsLeft -= 1
		lastWallJump = now
		local look = Util.flatUnit(cam.CFrame.LookVector)
		local out = (Util.flat(n).Unit * P.wallJumpOut + look * 14)
		root.AssemblyLinearVelocity = out + Vector3.new(0, P.wallJumpUp, 0)
		momentum = math.max(momentum, out.Magnitude - P.walkSpeed)
		doubleJumped = false
		Controller.punch(5)
		Controller.kick(-2, 0)
		C.Audio.play("WallJump", { pitch = 1.1 + (P.wallJumps - wallJumpsLeft) * 0.08 })
		Net.send("Input", "WallJump", { n = n })
		-- wall jump animation: a kick off the wall (body), a push with the free hand (first person)
		setMoveState("walljump")
		task.delay(0.38, function()
			if moveState == "walljump" then
				setMoveState(nil)
			end
		end)
		if C.Viewmodel and C.Viewmodel.wallPush then
			C.Viewmodel.wallPush(cam.CFrame:VectorToObjectSpace(n))
		end
		Controller.rollKick(if cam.CFrame.RightVector:Dot(n) > 0 then 6 else -6)
		if C.FX then
			C.FX.dust(root.Position - n * 1.2, 6, nil, 1.4, 10, 0.4)
		end
		return
	end
	-- double jump
	if not doubleJumped and airT > 0.1 then
		doubleJumped = true
		local md = hum.MoveDirection * (P.walkSpeed + momentum) * 1.05
		root.AssemblyLinearVelocity = Vector3.new(if md.Magnitude > 1 then md.X else v.X, P.doubleJumpPower, if md.Magnitude > 1 then md.Z else v.Z)
		C.Audio.play("Jump", { pitch = 1.25 })
		Controller.punch(3)
		if C.FX then
			C.FX.puff(root.Position - Vector3.new(0, 3, 0))
		end
	end
end

-- ------------------------------------------------------------------ input
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then
		return
	end
	local k = input.KeyCode
	if k == Enum.KeyCode.Space or k == Enum.KeyCode.ButtonA then
		jumpReqAt = os.clock()
		Controller.jump()
	elseif k == Enum.KeyCode.V or k == Enum.KeyCode.ButtonSelect then
		if Controller.mode == "play" then
			Controller.setCamMode(if Controller.camMode == "first" then "third" else "first")
		end
	end
end)

-- touch / other jump sources
UserInputService.JumpRequest:Connect(function()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		if os.clock() - jumpReqAt > 0.2 then
			jumpReqAt = os.clock()
			Controller.jump()
		end
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Thumbstick2 then
		local p = input.Position
		padLook = Vector2.new(if math.abs(p.X) > 0.15 then p.X else 0, if math.abs(p.Y) > 0.15 then p.Y else 0)
	elseif input.UserInputType == Enum.UserInputType.MouseWheel and Controller.camMode == "third" then
		thirdDist = math.clamp(thirdDist - input.Position.Z * 1.5, 6, 22)
	end
end)

-- ------------------------------------------------------------------ per frame
local function getControls()
	if controls then
		return controls
	end
	local ok, pm = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript)
	end)
	if ok and pm then
		controls = pm:GetControls()
	end
	return controls
end

local function update(dt: number)
	dt = math.min(dt, 0.1)
	cam.CameraType = Enum.CameraType.Scriptable
	local mode = "play"
	if C.inCutscene then
		mode = "cutscene"
	elseif C.menuOpen or not char or not root or not root.Parent or not hum then
		mode = "menu"
	elseif hum.Health <= 0 then
		mode = "dead"
	elseif char:GetAttribute("Ragdoll") then
		mode = "ragdoll"
	end
	Controller.mode = mode

	-- cursor
	local wantCursor = C.wantsCursor() or mode == "menu" or mode == "cutscene"
	if wantCursor then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	end

	-- controls on/off
	local ctl = getControls()
	if ctl then
		if canMove() then
			ctl:Enable(true)
		else
			ctl:Enable(false)
			if hum and hum.Parent then
				hum:Move(Vector3.zero)
			end
		end
	end

	if C.FX and C.FX.setSpeed and (mode ~= "play") then
		C.FX.setSpeed(0)
	end
	if mode == "menu" or mode == "cutscene" then
		setHidden(mode ~= "cutscene")
		return
	end

	-- look input
	if not wantCursor and not C.timeStop.frozenSelf and not C.paused then
		local d = UserInputService:GetMouseDelta()
		local sens = 0.0032 * (C.settings.sensitivity or 1)
		Controller.yaw -= d.X * sens
		Controller.pitch -= d.Y * sens
		Controller.yaw -= padLook.X * 3.2 * dt
		Controller.pitch += padLook.Y * 2.4 * dt
	end
	Controller.pitch = math.clamp(Controller.pitch, -1.45, 1.45)

	-- dash-stab: everything along this frame's dash path gets cut
	if dashPrevPos and os.clock() < dashUntil + 0.03 then
		local now = root.Position
		dashStabCheck(dashPrevPos, now)
		dashPrevPos = now
	end

	-- dash recharge
	if dashCharges < P.dashCharges then
		dashRecharge += dt
		if dashRecharge >= P.dashRecharge then
			dashRecharge = 0
			dashCharges += 1
		end
	end

	local vel = root.AssemblyLinearVelocity
	local flatSpeed = Util.flat(vel).Magnitude
	local grounded = isGrounded()
	if grounded then
		airT = 0
		lastGroundedAt = os.clock()
		if not sliding then
			momentum = Util.approach(momentum, 0, 70, dt)
		end
	else
		airT += dt
		momentum = Util.approach(momentum, 0, 7, dt)
	end
	lastVy = vel.Y

	-- slam: straight down, fast
	if slamming then
		if grounded then
			Controller.landed(math.abs(vel.Y))
		else
			root.AssemblyLinearVelocity = Vector3.new(0, -P.slamSpeed, 0)
			if airT > 4 then
				slamming = false
			end
		end
	end

	-- air hang (air attacks)
	if os.clock() < hangUntil and not grounded and not slamming and vel.Y < 3 then
		root.AssemblyLinearVelocity = Vector3.new(vel.X * 0.96, 3, vel.Z * 0.96)
	end

	-- slide update: lasts while held, slowly loses speed
	if sliding then
		slideT += dt
		slideSpeed = math.max(P.slideMin, slideSpeed - dt * (if slideT > 0.5 then 14 else 4))
		local look = Util.flatUnit(cam.CFrame.LookVector)
		slideDir = (slideDir + look * dt * 1.4).Unit
		if slideLV then
			slideLV.VectorVelocity = slideDir * slideSpeed
		end
		if slideT >= P.slideMaxTime or (not grounded and airT > 0.3) or not canMove() then
			Controller.endSlide(false)
		end
	end
	slideLower = Util.approach(slideLower, if sliding then 1.75 else 0, 14, dt)

	-- walk speed: base * stats * sprint + air momentum
	if hum and canMove() then
		local d = C.profile and C.profile.derived
		local sprint = Controller.sprintHeld and hum.MoveDirection.Magnitude > 0.1 and not (C.Viewmodel and C.Viewmodel.busy())
		sprintK = Util.approach(sprintK, if sprint then 1 else 0, 4, dt)
		local ride = if char:GetAttribute("Mounted") then (char:GetAttribute("HorseMult") or P.horseMult) else 1
		local base = P.walkSpeed * ride * (if d and d.speed then d.speed else 1) * (1 + (P.sprintMult - 1) * sprintK)
		hum.WalkSpeed = base + momentum
		hum.JumpPower = P.jumpPower
	end

	-- step-up assist: the part-built countryside is terraced, so walking into a low
	-- ledge (up to ~6 studs) hops you onto it instead of stopping you dead
	if hum and grounded and not sliding and canMove() and hum.MoveDirection.Magnitude > 0.1 and os.clock() > stepUpCd then
		local dir = Util.flatUnit(hum.MoveDirection)
		-- (a rider's hip height is raised: the feet are the horse's hooves)
		local feet = root.Position - Vector3.new(0, 3 + hum.HipHeight, 0)
		local params = rayParams()
		local hit = workspace:Raycast(feet + Vector3.new(0, 0.5, 0), dir * 2.2, params)
		if hit and hit.Normal.Y < 0.3 then
			local over = Vector3.new(hit.Position.X, feet.Y, hit.Position.Z) + dir * 0.9
			local top = workspace:Raycast(over + Vector3.new(0, 6.6, 0), Vector3.new(0, -6.4, 0), params)
			if top and top.Normal.Y > 0.7 then
				local dh = top.Position.Y - feet.Y
				if dh > 0.5 and dh < 6.3 and not workspace:Raycast(root.Position, Vector3.new(0, dh + 1.2, 0), params) then
					stepUpCd = os.clock() + 0.15
					local v = root.AssemblyLinearVelocity
					local up = math.sqrt(2 * workspace.Gravity * (dh + 0.5))
					root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, up), v.Z) + dir * 3
				end
			end
		end
	end

	-- bob & footsteps
	local moving = grounded and flatSpeed > 2 and not sliding
	bobAmt = Util.approach(bobAmt, if moving then math.clamp(flatSpeed / P.walkSpeed, 0, 1.4) else 0, 10, dt)
	if moving then
		local before = math.sin(bobT)
		bobT += dt * flatSpeed * 0.36
		local after = math.sin(bobT)
		if (before < 0) ~= (after < 0) and os.clock() > stepCd then
			stepCd = os.clock() + 0.14
			stepSide = -stepSide
			C.Audio.play("Step", { vol = 0.8, pitch = 1 + stepSide * 0.05 })
		end
	end
	local bobY = math.abs(math.cos(bobT)) * 0.12 * bobAmt - 0.06 * bobAmt
	local bobX = math.sin(bobT) * 0.06 * bobAmt

	-- landing dip spring
	landVel += (-landDip * 90 - landVel * 14) * dt
	landDip += landVel * dt

	-- roll when strafing
	local rightV = cam.CFrame.RightVector
	local strafe = if flatSpeed > 1 then Util.flat(vel):Dot(Util.flat(rightV)) / math.max(P.walkSpeed, 1) else 0
	roll = Util.approach(roll, -strafe * math.rad(2.2) + (if sliding then math.rad(-5) else 0), 8, dt)

	-- kicks decay
	kickP = Util.approach(kickP, 0, 12, dt)
	kickY = Util.approach(kickY, 0, 12, dt)
	rollKickV = Util.approach(rollKickV, 0, 9, dt)
	fovPunch = Util.approach(fovPunch, 0, 7, dt)

	-- shake
	local shakeRot = CFrame.identity
	if shakeT > 0 then
		shakeT -= dt
		local k = math.max(shakeT / shakeMax, 0) * shakeI
		local n = os.clock() * 42
		shakeRot = CFrame.Angles(math.rad(math.noise(n, 0.3) * k), math.rad(math.noise(0.7, n) * k), math.rad(math.noise(n, n * 0.5) * k * 0.6))
	end

	-- speed feedback: FOV, speed lines, HUD readout
	local speed3 = math.max(flatSpeed, if slamming then P.slamSpeed * 0.5 else 0)
	local speedK = math.clamp((speed3 - 30) / 50, 0, 1)
	if C.FX and C.FX.setSpeed then
		C.FX.setSpeed(if mode == "play" then speedK else 0)
	end
	if C.HUD and C.HUD.speed then
		C.HUD.speed(flatSpeed)
	end

	-- sprint pose for the third-person body
	if moveState == nil or moveState == "sprint" then
		setMoveState(if sprintK > 0.5 and grounded and flatSpeed > P.walkSpeed * 0.8 then "sprint" else nil)
	end

	-- motion blur: fast turns, dashes and raw speed smear the frame a little
	local look = cam.CFrame.LookVector
	local turn = math.deg(math.acos(math.clamp(look:Dot(lastCamLook), -1, 1))) / math.max(dt, 1e-3)
	lastCamLook = look
	local blurTarget = 0
	if C.settings.motionBlur ~= false and mode == "play" then
		blurTarget = math.clamp((turn - 160) / 260, 0, 1) * 5 + (if Controller.isDashing() then 4 else 0) + speedK * 2.5 + (if slamming then 3 else 0)
	end
	blurK = Util.approach(blurK, blurTarget, 40, dt)
	if blurFx then
		blurFx.Size = blurK
		blurFx.Enabled = blurK > 0.05
	end

	local rot = CFrame.fromOrientation(Controller.pitch + kickP, Controller.yaw + kickY, roll + rollKickV)
	local targetFov = (C.settings.fov or 95) + fovPunch + (if Controller.isDashing() then 10 else 0) + speedK * 16

	if mode == "play" and Controller.camMode == "first" then
		setHidden(true)
		local eye = root.Position + Vector3.new(0, 1.65 - slideLower + landDip * 1.2 + bobY, 0) + rightV * bobX
		cam.CFrame = CFrame.new(eye) * rot * shakeRot
		cam.FieldOfView = Util.approach(cam.FieldOfView, targetFov, 12, dt)
		if align then
			align.Enabled = true
			align.CFrame = CFrame.Angles(0, Controller.yaw, 0)
		end
	elseif mode == "play" then
		-- over-the-shoulder third person
		setHidden(false)
		local target = root.Position + Vector3.new(0, 2.3 - slideLower * 0.6 + landDip * 0.6, 0)
		local orbit = CFrame.new(target) * CFrame.fromOrientation(Controller.pitch + kickP, Controller.yaw + kickY, roll * 0.5)
		local want = orbit * CFrame.new(2.2, 0.8, thirdDist)
		local r = workspace:Raycast(target, want.Position - target, rayParams())
		local p = if r then r.Position + r.Normal * 0.6 else want.Position
		cam.CFrame = CFrame.new(p) * (orbit - orbit.Position) * shakeRot
		cam.FieldOfView = Util.approach(cam.FieldOfView, targetFov - 6, 12, dt)
		if align then
			align.Enabled = true
			align.CFrame = CFrame.Angles(0, Controller.yaw, 0)
		end
	else
		-- ragdoll / dead: third person orbit around the head
		setHidden(false)
		if align then
			align.Enabled = false
		end
		if mode == "dead" and not deadToppled then
			deadToppled = true
			topple(nil)
		end
		local head = char:FindFirstChild("Head") :: BasePart
		local target = if head then head.Position else root.Position
		local orbit = CFrame.new(target) * CFrame.fromOrientation(math.clamp(Controller.pitch, -1.2, 0.3) - 0.25, Controller.yaw, 0)
		local want = orbit * CFrame.new(0, 1.5, if mode == "dead" then 13 else 10)
		local r = workspace:Raycast(target, want.Position - target, rayParams())
		local p = if r then r.Position + r.Normal * 0.6 else want.Position
		cam.CFrame = CFrame.lookAt(p, target) * shakeRot
		cam.FieldOfView = Util.approach(cam.FieldOfView, 70, 6, dt)
	end
end

function Controller.init()
	if player.Character then
		task.spawn(Controller.onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(Controller.onCharacter)
	RunService:BindToRenderStep("TRSCamera", Enum.RenderPriority.Camera.Value + 1, update)
	local bl = Instance.new("BlurEffect")
	bl.Name = "MotionBlur"
	bl.Size = 0
	bl.Enabled = false
	bl.Parent = Lighting
	blurFx = bl
	Net.on("Ragdoll", function(data)
		if not hum or not root then
			return
		end
		if data.push then
			local push: Vector3 = data.push
			local lv = Instance.new("LinearVelocity")
			lv.Name = "PushLV"
			lv.Attachment0 = root:FindFirstChild("RootAttachment") :: Attachment
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(1, 0, 1) * 1e6
			lv.RelativeTo = Enum.ActuatorRelativeTo.World
			lv.VectorVelocity = Vector3.new(push.X, 0, push.Z)
			lv.Parent = root
			task.delay(0.13, function()
				lv:Destroy()
			end)
			if push.Y > 1 then
				-- launched: the hit also keeps you in the air (juggles)
				local v = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 0) + push.Y, v.Z)
			end
			return
		end
		if data.on then
			if sliding then
				Controller.endSlide(false)
			end
			slamming = false
			clearMovers()
			if hum.Health > 0 then
				hum.PlatformStand = true
				hum:ChangeState(Enum.HumanoidStateType.Physics)
			end
			local torso = char:FindFirstChild("Torso") :: BasePart
			if torso and data.vel then
				torso.AssemblyLinearVelocity = data.vel
				torso.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * (data.spin or 8)
			end
		else
			untopple()
			hum.PlatformStand = false
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			local _, y = root.CFrame:ToOrientation()
			Controller.yaw = y
		end
	end)
	Net.on("Shake", function(d)
		Controller.shake(d.i or 1, d.t or 0.3)
	end)
	Net.on("Scene", function(name, d)
		if name == "camMode" and type(d) == "table" then
			Controller.setCamMode(d.mode)
		end
	end)
end

return Controller
