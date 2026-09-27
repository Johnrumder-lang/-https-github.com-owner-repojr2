--!nonstrict
-- First-person arms + weapon. Animations only define HAND frames (camera space);
-- the arms are rebuilt every frame from an off-screen shoulder to the hand.
-- Swings follow real arcs in a tilted swing plane so the blade sweeps across the screen.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Weapons = require(Shared.Weapons)
local Gear = require(Shared.Gear)
local Net = require(Shared.Net)
local Palette = require(Shared.Palette)
local Util = require(Shared.Util)
local C = require(script.Parent.C)

local VM = {}
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles

local model: any = nil
local rArm, lArm, rSleeve, lSleeve, rHand, lHand
local weapon: any = nil
local weaponOffsets = {}
local trail: any = nil
local flask: any = nil
local itemId = nil
local visible = true -- VM.setVisible(false) hides the arms (the server can also set NoWeapon)
local ARM_LEN = 2.6
local ARM_W = 0.62
local R_SHOULDER = V(1.3, -1.7, 1.0)
local L_SHOULDER = V(-1.3, -1.7, 1.0)
local WEAPON_SCALE = 0.95 -- real sword lengths (v3 used 0.62: every blade looked like a dagger)
local fingers = {} -- [hand] = { parts } (gloved fingers wrapped around the grip)

-- animation state
local action = nil -- { kind, t, dur, ... }
local timeScale = 1
local hitstopUntil = 0
local swayX, swayY = 0, 0
local lastYaw, lastPitch = 0, 0
local blockHeld = false
local charge = 0 -- 0..1 heavy charge
local charging = false
local equipT = 1
local hurtT = 0
local bobPhase = 0 -- integrated (v3 used clock * speed, which jumped every frame: the hand shake)
local yawRate, pitchRate = 0, 0

local function mkPart(name, size, color, mat)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function sampleColors()
	local skin, sleeve = Palette.skin[2], Color3.fromRGB(40, 40, 50)
	local ch = player.Character
	if ch then
		local ra = ch:FindFirstChild("Right Arm") :: BasePart
		if ra then
			skin = ra.Color
			for _, d in ra:GetChildren() do
				if d:IsA("BasePart") and d.Name == "Deco" and d.Size.Y > 0.6 then
					sleeve = d.Color
					break
				end
			end
		end
	end
	-- armour overrides what the sleeves and hands look like
	local look: any = {}
	local prof = C.profile
	if prof and prof.equipment then
		local gear = {}
		for slot, id in prof.equipment do
			for _, it in prof.inventory do
				if it.id == id then
					gear[slot] = it
				end
			end
		end
		local ok, res = pcall(Gear.viewColors, gear)
		if ok then
			look = res
		end
	end
	return skin, look.sleeve or sleeve, look
	end

function VM.build()
	if model then
		model:Destroy()
	end
	local skin, sleeve, look = sampleColors()
	model = Instance.new("Model")
	model.Name = "Viewmodel"
	-- forearms (skin shows only at the wrist), a sleeve over the upper part and a
	-- dark leather glove with knuckles and fingers. Muted, low-gloss materials so the
	-- arms never blow out to white next to torches.
	local glove = look.glove or Color3.fromRGB(58, 44, 36)
	local gloveMat = look.gloveMat or Enum.Material.Leather
	skin = Palette.shade(skin, 0.86)
	rArm = mkPart("RArm", V(ARM_W, ARM_W, ARM_LEN), skin, Enum.Material.SmoothPlastic)
	lArm = mkPart("LArm", V(ARM_W, ARM_W, ARM_LEN), skin, Enum.Material.SmoothPlastic)
	rSleeve = mkPart("RSleeve", V(ARM_W + 0.1, ARM_W + 0.1, ARM_LEN * 0.8), sleeve, Enum.Material.Fabric)
	lSleeve = mkPart("LSleeve", V(ARM_W + 0.1, ARM_W + 0.1, ARM_LEN * 0.8), sleeve, Enum.Material.Fabric)
	rHand = mkPart("RHand", V(0.62, 0.5, 0.56), glove, gloveMat)
	lHand = mkPart("LHand", V(0.62, 0.5, 0.56), glove, gloveMat)
	if look.sleeveMat then
		rSleeve.Material = look.sleeveMat
		lSleeve.Material = look.sleeveMat
	end
	for _, p in { rArm, lArm, rSleeve, lSleeve, rHand, lHand } do
		p.Parent = model
	end
	fingers = {}
	for _, hand in { rHand, lHand } do
		local list = {}
		-- cuff
		local cuff = mkPart("Cuff", V(0.72, 0.36, 0.7), Palette.shade(glove, 0.8), gloveMat)
		cuff.Parent = model
		table.insert(list, { part = cuff, off = CF(0, -0.36, 0.02) })
		-- four fingers wrapped around the grip (hand space: grip along Y, +Z faces the camera)
		for i = 0, 3 do
			local f = mkPart("Finger", V(0.46, 0.12, 0.13), Palette.shade(glove, 1.08), gloveMat)
			f.Parent = model
			table.insert(list, { part = f, off = CF(-0.05, 0.2 - i * 0.135, 0.3) })
			local tip = mkPart("Finger", V(0.12, 0.12, 0.13), Palette.shade(glove, 0.9), gloveMat)
			tip.Parent = model
			table.insert(list, { part = tip, off = CF(0.24, 0.2 - i * 0.135, 0.27) })
		end
		-- thumb and a riveted metal knuckle plate
		local thumb = mkPart("Thumb", V(0.14, 0.32, 0.15), Palette.shade(glove, 1.12), gloveMat)
		thumb.Parent = model
		table.insert(list, { part = thumb, off = CF(-0.27, 0.28, 0.2) * ANG(0, 0, math.rad(-20)) })
		local knuckle = mkPart("Knuckle", V(0.1, 0.52, 0.5), Color3.fromRGB(92, 86, 80), Enum.Material.Metal)
		knuckle.Parent = model
		table.insert(list, { part = knuckle, off = CF(-0.34, 0.02, 0) })
		fingers[hand] = list
	end
	flask = mkPart("Flask", V(0.5, 0.8, 0.5), Color3.fromRGB(220, 30, 50), Enum.Material.Glass)
	flask.Transparency = 1
	flask.Parent = model
	model.Parent = cam
	itemId = nil
	VM.setWeapon(C.profile and VM.equippedItem())
end

function VM.equippedItem()
	local prof = C.profile
	if not prof or not prof.equipped then
		return nil
	end
	for _, it in prof.inventory do
		if it.id == prof.equipped then
			return it
		end
	end
	return nil
end

function VM.setWeapon(item)
	if weapon then
		weapon:Destroy()
		weapon = nil
		trail = nil
	end
	itemId = item and item.id or nil
	if not item or not model then
		return
	end
	local w = Weapons.buildModel(item, WEAPON_SCALE)
	for _, d in w:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CastShadow = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end
	weaponOffsets = {}
	local grip = w.PrimaryPart
	for _, d in w:GetDescendants() do
		if d:IsA("BasePart") then
			weaponOffsets[d] = grip.CFrame:ToObjectSpace(d.CFrame)
		end
	end
	local a0 = grip:FindFirstChild("Base") :: Attachment
	local a1 = grip:FindFirstChild("Tip") :: Attachment
	if a0 and a1 then
		local tr = Instance.new("Trail")
		tr.Attachment0 = a0
		tr.Attachment1 = a1
		local col = if item.element then Palette.element[item.element] else Palette.rarity[item.rarity] or Color3.new(1, 1, 1)
		tr.Color = ColorSequence.new(Color3.new(1, 1, 1), col)
		tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
		tr.Lifetime = 0.14
		tr.LightEmission = 0.8
		tr.FaceCamera = false
		tr.MinLength = 0
		tr.Enabled = false
		tr.Parent = grip
		trail = tr
	end
	w.Parent = model
	weapon = w
	equipT = 0
	C.Audio.play("Equip")
end

function VM.setVisible(v: boolean)
	visible = v
end

-- ------------------------------------------------------------------ poses
-- Hand CFrame from position + blade direction + blade plane normal.
local function bladeCF(pos: Vector3, dir: Vector3, normal: Vector3): CFrame
	local y = dir.Unit
	local z = (normal - y * normal:Dot(y))
	if z.Magnitude < 1e-3 then
		z = V(0, 0, 1)
	end
	z = z.Unit
	local x = y:Cross(z)
	return CFrame.fromMatrix(pos, x, y, z)
end

local IDLE_POS = V(1.2, -1.28, -2.15)
local function idlePose(t)
	local b = math.sin(t * 1.6) * 0.015
	-- a full-length blade held forward and up, crossing toward the centre of the screen;
	-- its flat (weapon +-Z) faces the camera so the weapon reads well
	return bladeCF(IDLE_POS + V(0, b, 0), V(-0.32, 0.8, -0.95), V(0.35, 0.2, 1))
end

-- swing plane definitions (A = start side, B = through forward)
local SWINGS = {
	{ A = V(1, 0.18, 0), B = V(0, -0.05, -1), c = V(0.1, -0.55, -0.2), r = 1.75, a0 = 0.05, a1 = 2.95 }, -- right -> left
	{ A = V(-1, -0.25, 0), B = V(0, 0.05, -1), c = V(0.25, -0.45, -0.2), r = 1.7, a0 = 0.05, a1 = 2.95 }, -- left -> right (backhand, rising)
	{ A = V(0.25, 1, 0), B = V(0, 0, -1), c = V(0.35, -0.35, -0.1), r = 1.75, a0 = -0.35, a1 = 2.55 }, -- overhead
}
local HEAVY = { A = V(0.12, 1, 0.1), B = V(0, -0.1, -1), c = V(0.2, -0.3, 0), r = 1.9, a0 = -0.8, a1 = 2.7 }
local VOID = { A = V(1, -0.35, 0), B = V(0, 0.1, -1), c = V(0, -0.45, -0.2), r = 1.9, a0 = -0.1, a1 = 3.1 }

local function arcCF(s, theta: number): CFrame
	local A, B = s.A.Unit, s.B.Unit
	local radial = (A * math.cos(theta) + B * math.sin(theta)).Unit
	local handPos = s.c + radial * s.r * 0.6
	local normal = A:Cross(B)
	return bladeCF(handPos, radial + V(0, 0.1, 0), normal)
end

local function lerpCF(a: CFrame, b: CFrame, t: number): CFrame
	return a:Lerp(b, math.clamp(t, 0, 1))
end

local function easeOut(t)
	t = math.clamp(t, 0, 1)
	return 1 - (1 - t) ^ 3
end
local function easeIn(t)
	t = math.clamp(t, 0, 1)
	return t * t
end

local LEFT_IDLE = CF(-1.6, -2.4, -1.2) -- off screen

-- the anime slash: a crescent traced by the blade tip, glued to the camera
local function slashFX(a)
	if a.fx or not C.FX or not C.FX.ribbon then
		return
	end
	a.fx = true
	local s = a.swing
	local A, B = s.A.Unit, s.B.Unit
	local L = (if weapon then weapon:GetAttribute("TipY") else nil) or 3
	L = math.clamp(L, 1.5, 6)
	local pts = {}
	local n = 12
	for i = 0, n do
		local th = s.a0 + (s.a1 - s.a0) * (i / n)
		local radial = (A * math.cos(th) + B * math.sin(th)).Unit
		table.insert(pts, s.c + radial * s.r * 0.6 + (radial + V(0, 0.1, 0)).Unit * L * 0.95)
	end
	local item = VM.equippedItem()
	local col = if a.kind == "void" then Color3.fromRGB(150, 60, 255)
		elseif a.kind == "heavy" then Color3.fromRGB(255, 190, 90)
		else (item and Palette.rarity[item.rarity]) or Color3.fromRGB(230, 236, 255)
	C.FX.ribbon(pts, A:Cross(B), if a.kind == "swing" then 0.42 else 0.7, col, if a.kind == "swing" then 0.16 else 0.22, function()
		return cam.CFrame
	end)
end

local function evaluate(now: number, dt: number)
	local r = idlePose(now)
	local l = LEFT_IDLE
	local flaskT = -1
	local trailOn = false
	local a = action
	if a then
		a.t += dt * timeScale
		local k = a.t / a.dur
		if a.kind == "swing" or a.kind == "heavy" or a.kind == "void" then
			local s = a.swing
			local w, act = a.w, a.act
			local startCF = arcCF(s, s.a0 - 0.35)
			local endCF = arcCF(s, s.a1)
			if a.t < w then
				r = lerpCF(r, startCF, easeOut(a.t / w))
			elseif a.t < w + act then
				local u = easeOut((a.t - w) / act)
				r = arcCF(s, s.a0 + (s.a1 - s.a0) * u)
				trailOn = true
				slashFX(a)
			else
				local u = (a.t - w - act) / math.max(a.dur - w - act, 0.01)
				r = lerpCF(endCF, r, easeOut(u))
			end
			if a.kind == "heavy" or a.kind == "void" then
				l = lerpCF(LEFT_IDLE, CF(-0.7, -1.0, -1.4) * ANG(0.4, 0, 0.4), math.sin(math.clamp(k, 0, 1) * math.pi))
			end
		elseif a.kind == "parry" then
			local guard = bladeCF(V(0.35, -0.55, -1.65), V(-1, 0.55, -0.15), V(0, 0.25, -1))
			local u = if a.t < 0.07 then easeOut(a.t / 0.07) elseif blockHeld then 1 else 1 - easeIn((a.t - 0.07) / 0.18)
			r = lerpCF(r, guard, u)
			l = lerpCF(LEFT_IDLE, CF(-0.5, -1.0, -1.5) * ANG(0.9, 0, 0.3), u * 0.9)
			if not blockHeld and a.t > 0.25 then
				action = nil
			end
		elseif a.kind == "snap" then
			local up = CF(-0.55, -0.45, -1.55) * ANG(0.25, 0.3, 0.2)
			local u = math.sin(math.clamp(k, 0, 1) * math.pi)
			local jitter = if k > 0.35 and k < 0.5 then CF(0, math.sin(a.t * 90) * 0.04, 0) else CF()
			l = lerpCF(LEFT_IDLE, up * jitter, math.min(1, u * 1.6))
			r = r * CF(0.15 * u, -0.25 * u, 0.2 * u)
		elseif a.kind == "flask" then
			local up = CF(-0.25, -0.55, -1.0) * ANG(0.9 * math.sin(k * math.pi), 0, 0.3)
			local u = math.sin(math.clamp(k, 0, 1) * math.pi)
			l = lerpCF(LEFT_IDLE, up, math.min(1, u * 1.5))
			r = r * CF(0.2 * u, -0.4 * u, 0.3 * u)
			flaskT = u
		elseif a.kind == "push" then
			local u = math.sin(math.clamp(k, 0, 1) * math.pi)
			l = lerpCF(LEFT_IDLE, CF(-0.35, -0.45, -2.1) * ANG(1.2, 0, 0), u)
		elseif a.kind == "recoil" then
			local u = math.sin(math.clamp(k, 0, 1) * math.pi)
			r = r * CF(0.2 * u, 0.1 * u, 0.5 * u) * ANG(0.5 * u, 0, -0.3 * u)
		elseif a.kind == "stab" then
			-- dash-stab: the blade drives straight forward, then snaps back
			local thrust = bladeCF(V(0.35, -0.75, -2.6), V(-0.05, 0.12, -1), V(0, 1, 0))
			local u = if k < 0.25 then easeOut(k / 0.25) else 1 - easeIn((k - 0.25) / 0.75)
			r = lerpCF(r, thrust, u)
			trailOn = k < 0.5
		elseif a.kind == "wallpush" then
			-- the free hand slaps the wall and pushes off
			local u = math.sin(math.clamp(k, 0, 1) * math.pi)
			local n = a.n or V(-1, 0, 0)
			local side = if n.X > 0 then -1 else 1
			l = lerpCF(LEFT_IDLE, CF(-0.9 * side, -0.35, -1.5) * ANG(0.2, 0, side * 0.9), math.min(1, u * 1.8))
		end
		if action == a and a.t >= a.dur then
			action = nil
		end
	end
	if trail then
		trail.Enabled = trailOn
	end
	-- heavy charge
	if charging then
		charge = math.min(1, charge + dt / 0.38)
		local back = bladeCF(V(1.3, -0.25, -0.9), V(0.3, 1, 0.55), V(1, 0, 0.2))
		-- a faint tremble only once the heavy is fully wound up
		local tr = math.max(0, charge - 0.8) * 5
		local shakeC = CF(math.noise(now * 22, 1) * 0.012 * tr, math.noise(1, now * 22) * 0.012 * tr, 0)
		r = lerpCF(r, back * shakeC, easeOut(charge))
	else
		charge = 0
	end
	-- equip rise
	if equipT < 1 then
		equipT = math.min(1, equipT + dt / 0.35)
		local u = 1 - easeOut(equipT)
		r = r * CF(0, -1.4 * u, 0.6 * u) * ANG(-1.2 * u, 0, 0.6 * u)
	end
	if hurtT > 0 then
		hurtT = math.max(0, hurtT - dt * 4)
		r = r * CF(0.1 * hurtT, -0.2 * hurtT, 0.2 * hurtT) * ANG(0.3 * hurtT, 0, 0)
	end
	return r, l, flaskT
end

local function placeArm(arm: BasePart, sleeve: BasePart, hand: BasePart, shoulder: Vector3, handCF: CFrame, base: CFrame)
	local hp = handCF.Position
	local dir = (hp - shoulder)
	if dir.Magnitude < 0.1 then
		dir = V(0, 0, -1)
	end
	dir = dir.Unit
	local s = hp - dir * ARM_LEN
	local mid = (s + hp) * 0.5
	local armCF = CFrame.lookAt(mid, hp, handCF.UpVector)
	arm.CFrame = base * armCF
	sleeve.CFrame = base * armCF * CF(0, 0, ARM_LEN * 0.18)
	local hcf = base * handCF * CF(0, -0.12, 0)
	hand.CFrame = hcf
	for _, f in fingers[hand] or {} do
		f.part.CFrame = hcf * f.off
	end
end

local function render(dt: number)
	if not model or not model.Parent then
		return
	end
	local ch = player.Character
	local show = visible and C.Controller.mode == "play" and C.Controller.camMode ~= "third" and not C.inCutscene and not (ch and ch:GetAttribute("NoWeapon"))
	if not show then
		model:PivotTo(CF(0, -10000, 0))
		return
	end
	local now = os.clock()
	local scaled = dt
	if now < hitstopUntil then
		scaled = 0
	end
	-- sway from camera rotation
	-- sway follows the (smoothed) turn rate, so noisy per-frame mouse deltas never jitter the arms
	local y, p = C.Controller.yaw, C.Controller.pitch
	local dyaw = y - lastYaw
	local dp = p - lastPitch
	lastYaw, lastPitch = y, p
	local sdt = math.max(dt, 1 / 240)
	local kr = 1 - math.exp(-14 * dt)
	yawRate += (math.clamp(dyaw / sdt, -30, 30) - yawRate) * kr
	pitchRate += (math.clamp(dp / sdt, -30, 30) - pitchRate) * kr
	local ks = 1 - math.exp(-10 * dt)
	swayX += (math.clamp(yawRate * 0.022, -0.3, 0.3) - swayX) * ks
	swayY += (math.clamp(pitchRate * 0.022, -0.3, 0.3) - swayY) * ks
	-- walk bob
	local _, _, root = C.Controller.character()
	local speed = 0
	if root then
		speed = Util.flat(root.AssemblyLinearVelocity).Magnitude
	end
	local bob = if C.Controller.isGrounded() and speed > 2 then math.clamp(speed / 22, 0, 1.5) else 0
	bobPhase += dt * (6 + math.min(speed, 90) * 0.18)
	local bt = bobPhase
	local bobCF = CF(math.sin(bt) * 0.05 * bob, -math.abs(math.cos(bt)) * 0.06 * bob, 0) * ANG(0, 0, math.sin(bt) * 0.02 * bob)
	local slideCF = if C.Controller.isSliding() then CF(0.1, 0.25, 0.1) * ANG(0, 0, -0.35) else CF()
	local base = cam.CFrame * CF(swayX * 0.6, swayY * 0.4, 0) * ANG(swayY * 0.5, swayX * 0.8, 0) * bobCF * slideCF
	local rCF, lCF, flaskT = evaluate(now, scaled)
	placeArm(rArm, rSleeve, rHand, R_SHOULDER, rCF, base)
	placeArm(lArm, lSleeve, lHand, L_SHOULDER, lCF, base)
	if weapon and weapon.PrimaryPart then
		local grip = base * rCF * CF(0, -0.05, 0)
		for part, off in weaponOffsets do
			part.CFrame = grip * off
		end
	end
	if flask then
		if flaskT > 0 then
			flask.Transparency = 0.2
			flask.CFrame = base * lCF * CF(0, 0.55, -0.1)
		else
			flask.Transparency = 1
			flask.CFrame = CF(0, -10000, 0)
		end
	end
	-- refresh weapon if the profile changed
	local want = VM.equippedItem()
	if (want and want.id) ~= itemId then
		VM.setWeapon(want)
	end
end

-- ------------------------------------------------------------------ public actions
function VM.swing(combo: number, interval: number)
	local s = SWINGS[((combo - 1) % 3) + 1]
	local dur = math.max(interval * 0.95, 0.22)
	action = { kind = "swing", t = 0, dur = dur, w = dur * 0.22, act = dur * 0.28, swing = s }
	charging = false
end

function VM.heavy(interval: number)
	local dur = math.max(interval * 1.3, 0.45)
	action = { kind = "heavy", t = 0, dur = dur, w = 0.05, act = dur * 0.3, swing = HEAVY }
	charging = false
end

function VM.voidSlash()
	action = { kind = "void", t = 0, dur = 0.5, w = 0.08, act = 0.16, swing = VOID }
end

function VM.parry(hold: boolean)
	blockHeld = hold
	if not action or action.kind ~= "parry" then
		action = { kind = "parry", t = 0, dur = 10 }
	end
end

function VM.release()
	blockHeld = false
end

function VM.snap()
	action = { kind = "snap", t = 0, dur = 0.55 }
end

function VM.flask()
	action = { kind = "flask", t = 0, dur = 0.7 }
end

function VM.push()
	action = { kind = "push", t = 0, dur = 0.35 }
end

function VM.recoil()
	action = { kind = "recoil", t = 0, dur = 0.3 }
end

function VM.stab()
	action = { kind = "stab", t = 0, dur = 0.34 }
	charging = false
end

-- n = wall normal in camera space
function VM.wallPush(n: Vector3?)
	if action and (action.kind == "swing" or action.kind == "heavy" or action.kind == "void") then
		return
	end
	action = { kind = "wallpush", t = 0, dur = 0.34, n = n }
end

function VM.setCharging(on: boolean)
	charging = on
end

function VM.hitstop(t: number)
	hitstopUntil = os.clock() + t
end

function VM.hurt()
	hurtT = 1
end

function VM.busy(): boolean
	return action ~= nil and (action.kind == "swing" or action.kind == "heavy" or action.kind == "void") and action.t < action.w + action.act
end

function VM.tipPosition(): Vector3?
	if weapon and weapon.PrimaryPart then
		local a = weapon.PrimaryPart:FindFirstChild("Tip") :: Attachment
		if a then
			return a.WorldPosition
		end
	end
	return nil
end

function VM.init()
	RunService:BindToRenderStep("TRSViewmodel", Enum.RenderPriority.Camera.Value + 5, render)
	player.CharacterAdded:Connect(function()
		task.wait(0.3)
		VM.build()
	end)
	if player.Character then
		task.defer(VM.build)
	end
	Net.on("Scene", function(name)
		if name == "gearChanged" then
			task.delay(0.2, VM.build)
		end
	end)
	end

return VM
