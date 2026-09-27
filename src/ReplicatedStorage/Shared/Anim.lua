--!nonstrict
-- Procedural R6 animation. A pose is a flat table of angles (radians):
--   rsP/rsR/rsY  right shoulder: forward raise / outward raise / twist
--   lsP/lsR/lsY  left shoulder  (same meaning, mirrored)
--   rhP/rhR      right hip: forward swing / outward
--   lhP/lhR      left hip
--   nY/nP/nR     neck: turn left / look down / tilt
--   tY/tP/tR/tH/tF  root: turn left / lean forward / lean left / height offset / forward offset
local Anim = {}

local ANG = CFrame.Angles
local CF = CFrame.new
local sin, cos, abs, min, max = math.sin, math.cos, math.abs, math.min, math.max

Anim.FIELDS = { "rsP", "rsR", "rsY", "lsP", "lsR", "lsY", "rhP", "rhR", "lhP", "lhR", "nY", "nP", "nR", "tY", "tP", "tR", "tH", "tF" }

function Anim.zero()
	local p = {}
	for _, f in Anim.FIELDS do
		p[f] = 0
	end
	return p
end

function Anim.toTransforms(p, out)
	out = out or {}
	out["Right Shoulder"] = ANG(0, 0, p.rsP) * ANG(-p.rsR, 0, 0) * ANG(0, p.rsY, 0)
	out["Left Shoulder"] = ANG(0, 0, -p.lsP) * ANG(-p.lsR, 0, 0) * ANG(0, -p.lsY, 0)
	out["Right Hip"] = ANG(0, 0, p.rhP) * ANG(-p.rhR, 0, 0)
	out["Left Hip"] = ANG(0, 0, -p.lhP) * ANG(-p.lhR, 0, 0)
	out.Neck = ANG(0, 0, p.nY) * ANG(p.nP, 0, 0) * ANG(0, p.nR, 0)
	out.RootJoint = CF(0, -p.tF, p.tH) * ANG(0, 0, p.tY) * ANG(p.tP, 0, 0) * ANG(0, p.tR, 0)
	return out
end

-- Blend: result = a + (b - a) * t, fields missing in b fall back to a.
function Anim.blend(a, b, t, out)
	out = out or {}
	for _, f in Anim.FIELDS do
		local va = a[f] or 0
		local vb = b[f]
		if vb == nil then
			vb = va
		end
		out[f] = va + (vb - va) * t
	end
	return out
end

-- Applies a partial pose on top of base (fields in `over` replace base).
function Anim.overlay(base, over, weight, out)
	out = out or {}
	for _, f in Anim.FIELDS do
		local vb = base[f] or 0
		local vo = over[f]
		out[f] = if vo == nil then vb else vb + (vo - vb) * weight
	end
	return out
end

local function smooth(t)
	t = if t < 0 then 0 elseif t > 1 then 1 else t
	return t * t * (3 - 2 * t)
end
local function easeOut(t)
	t = if t < 0 then 0 elseif t > 1 then 1 else t
	return 1 - (1 - t) * (1 - t) * (1 - t)
end

-- ------------------------------------------------------------------ locomotion
-- opts: { state = "slide"|"dash"|"walljump"|"slam"|"sprint", quad = bool, fly = bool, hover = bool }
local function airPose(p, vy: number)
	if vy > 4 then
		-- rising: knees tucked, arms swinging up
		p.rhP, p.lhP = 1.0, 0.25
		p.rsP, p.lsP = 0.9, 0.5
		p.rsR, p.lsR = 0.45, 0.45
		p.tP = 0.12
		p.nP = -0.1
	else
		-- falling: legs apart, arms out for balance, a slow flail
		local k = min(-vy / 60, 1)
		p.rhP, p.lhP = 0.45, -0.3
		p.rsP, p.lsP = 0.5 + k * 0.6, 0.35 + k * 0.5
		p.rsR, p.lsR = 0.6 + k * 0.5, 0.6 + k * 0.5
		p.tP = -0.05 - k * 0.1
		p.nP = 0.12 + k * 0.15
	end
end

local function quadPose(p, t: number, speed: number, grounded: boolean)
	-- four legs: the torso lies forward, arms become front legs, head looks ahead
	p.tP = 1.45
	p.tH = -1.0
	p.nP = -1.35
	local run = min(speed / 20, 1.5)
	local ph = t * (3.5 + speed * 0.28)
	local s = sin(ph)
	local amp = if speed < 0.8 then 0 else 0.3 + run * 0.45
	-- diagonal gait: front-right moves with back-left
	p.rsP = 1.45 - s * amp
	p.lsP = 1.45 + s * amp
	p.rhP = 1.45 + s * amp
	p.lhP = 1.45 - s * amp
	p.rsR, p.lsR = 0.05, 0.05
	p.tH += abs(cos(ph)) * 0.12 * run
	p.tR = s * 0.05 * run
	p.nY = -s * 0.06 * run
	if speed < 0.8 then
		local b = sin(t * 2)
		p.tH += b * 0.03
		p.nP += b * 0.03
	end
	if not grounded then
		-- leaping: legs stretched fore and aft
		p.rsP, p.lsP = 0.6, 0.6
		p.rhP, p.lhP = 2.2, 2.2
	end
end

local function flyPose(p, t: number, speed: number)
	-- wings on the arms, body level, legs trailing
	local flap = sin(t * (9 + speed * 0.15))
	p.tP = 0.9 + min(speed / 60, 0.5)
	p.nP = -0.9
	p.rsP, p.lsP = 0.2, 0.2
	p.rsR, p.lsR = 1.25 + flap * 0.85, 1.25 + flap * 0.85
	p.rhP, p.lhP = -0.2, -0.3
	p.tH = flap * 0.15
end

local function hoverPose(p, t: number)
	local b = sin(t * 1.8)
	p.tH = 0.4 + b * 0.3
	p.rsP, p.lsP = 0.4 + sin(t * 1.3) * 0.2, 0.4 + cos(t * 1.3) * 0.2
	p.rsR, p.lsR = 0.7, 0.7
	p.rhP, p.lhP = 0.15, 0.05
	p.nP = 0.05
end

function Anim.locomotion(t: number, speed: number, grounded: boolean, vy: number, hunch: boolean?, heavy: boolean?, opts)
	local p = Anim.zero()
	opts = opts or {}
	if opts.fly then
		flyPose(p, t, speed)
		return p
	elseif opts.hover then
		hoverPose(p, t)
		return p
	elseif opts.quad then
		quadPose(p, t, speed, grounded)
		return p
	end
	local st = opts.state
	if st == "slide" then
		-- leaning back on one hip, lead leg out front, trailing arm back for balance
		p.tH = -1.35
		p.tP = -0.6
		p.tR = 0.12
		p.rhP, p.lhP = 1.55, 0.55
		p.rhR = 0.1
		p.rsP, p.rsR = 0.9, 0.25
		p.lsP, p.lsR = -0.7, 0.75
		p.nP = 0.45
		return p
	elseif st == "dash" then
		-- anime dash: hard forward lean, arms swept back, legs trailing
		p.tP = 0.62
		p.tH = -0.25
		p.rsP, p.lsP = -1.0, -0.9
		p.rsR, p.lsR = 0.35, 0.35
		p.rhP, p.lhP = -0.55, 0.35
		p.nP = -0.45
		return p
	elseif st == "walljump" then
		-- kick off the wall: body arched, knees tucked, arms thrown up
		p.tP = -0.35
		p.rhP, p.lhP = 1.35, 0.9
		p.rsP, p.lsP = 2.3, 1.9
		p.rsR, p.lsR = 0.6, 0.5
		p.tR = sin(t * 30) * 0.05
		p.nP = -0.2
		return p
	elseif st == "slam" then
		-- dropping like a meteor: knees up, both arms raised to smash
		p.tP = 0.35
		p.tH = 0.15
		p.rhP, p.lhP = 1.35, 1.35
		p.rsP, p.lsP = 2.9, 2.9
		p.rsR, p.lsR = 0.25, 0.25
		p.nP = 0.35
		return p
	end
	if not grounded then
		airPose(p, vy)
	elseif speed < 0.8 then
		-- idle: breathing, weight shifting from one leg to the other
		local b = sin(t * 2.1)
		local w = sin(t * 0.55)
		p.tH = b * 0.03
		p.tR = w * 0.03
		p.rsR = 0.07 + b * 0.02
		p.lsR = 0.07 + b * 0.02
		p.rsP = 0.05
		p.lsP = 0.05
		p.rhR, p.lhR = 0.03 + w * 0.02, 0.03 - w * 0.02
		p.nP = b * 0.02
		p.nY = sin(t * 0.37) * 0.08
	else
		local sprint = st == "sprint"
		local run = min(speed / 22, 1.5)
		local walk = speed < 13
		local freq = if walk then 3.2 + speed * 0.3 else 4.6 + speed * 0.2
		local ph = t * freq
		local s = sin(ph)
		local c = cos(ph)
		local amp = if walk then 0.28 + speed * 0.03 else 0.55 + run * 0.4 + (if sprint then 0.15 else 0)
		p.rhP = s * amp
		p.lhP = -s * amp
		-- arms counter-swing; running arms are held forward (bent-arm look)
		local armAmp = amp * (if walk then 0.75 else 0.9)
		local armFwd = if walk then 0.05 else 0.3 + run * 0.15 + (if sprint then 0.25 else 0)
		p.rsP = -s * armAmp + armFwd
		p.lsP = s * armAmp + armFwd
		p.rsR = 0.06 + (if walk then 0 else 0.08)
		p.lsR = p.rsR
		-- body: bob twice per stride, twist against the legs, lean into speed
		p.tH = abs(c) * (if walk then 0.06 else 0.2 * run) - (if walk then 0.02 else 0.07 * run)
		p.tP = if walk then 0.04 else run * 0.16 + (if sprint then 0.14 else 0)
		p.tY = s * (if walk then 0.05 else 0.1 * run)
		p.tR = c * 0.03
		-- the head stays level while the body twists
		p.nY = -s * (if walk then 0.04 else 0.08 * run)
		p.nP = -p.tP * 0.6
	end
	if hunch then
		p.tP += 0.42
		p.nP -= 0.38
		p.rsP += 0.35
		p.lsP += 0.35
		p.rsR += 0.15
		p.lsR += 0.15
		p.tH -= 0.25
	end
	if heavy then
		p.rsR += 0.15
		p.lsR += 0.15
	end
	return p
end

-- ------------------------------------------------------------------ actions
-- Each action: windup pose -> strike pose. Timings come from the attack (ActW/ActA/ActR).
Anim.ACTIONS = {
	SlashR = {
		windup = { rsP = 1.9, rsR = 1.25, rsY = 0.4, tY = -0.55, nY = 0.3, lsP = 0.4, lsR = 0.3 },
		strike = { rsP = 1.35, rsR = -0.35, rsY = -0.5, tY = 0.6, nY = -0.2, lsP = 0.2, lsR = 0.5 },
	},
	SlashL = {
		windup = { rsP = 1.5, rsR = -0.5, rsY = -0.6, tY = 0.55, lsP = 0.3 },
		strike = { rsP = 1.6, rsR = 1.2, rsY = 0.3, tY = -0.6, lsP = 0.2, lsR = 0.4 },
	},
	Overhead = {
		windup = { rsP = 3.0, rsR = 0.15, lsP = 2.6, lsR = -0.1, tP = -0.2, nP = -0.2, tH = 0.1 },
		strike = { rsP = 0.75, rsR = 0.05, lsP = 0.6, tP = 0.35, nP = 0.15, tH = -0.3 },
	},
	Thrust = {
		windup = { rsP = 0.35, rsR = 0.35, tY = -0.45, rhP = -0.3, lhP = 0.4 },
		strike = { rsP = 1.65, rsR = 0, tY = 0.3, tF = 0.6, rhP = 0.5, lhP = -0.4, tP = 0.15 },
	},
	Slam = {
		windup = { rsP = 3.05, lsP = 3.05, rsR = 0.2, lsR = 0.2, tP = -0.25, nP = -0.3, tH = 0.2 },
		strike = { rsP = 0.7, lsP = 0.7, rsR = 0, lsR = 0, tP = 0.55, nP = 0.25, tH = -0.6, rhP = 0.4, lhP = -0.3 },
	},
	Sweep = {
		windup = { tH = -0.6, rsP = 0.9, rsR = 1.3, lsP = 0.9, lsR = -0.6, tY = -0.8, rhP = 0.5, lhP = -0.5, tP = 0.2 },
		strike = { tH = -0.6, rsP = 1.2, rsR = -0.3, lsP = 1.1, lsR = 1.0, tY = 1.0, rhP = 0.5, lhP = -0.5, tP = 0.2 },
	},
	ClawR = {
		windup = { rsP = 2.2, rsR = 0.9, tY = -0.4, tP = 0.2, lsP = 0.6 },
		strike = { rsP = 0.9, rsR = -0.2, tY = 0.5, tP = 0.35, lsP = 0.3 },
	},
	ClawL = {
		windup = { lsP = 2.2, lsR = 0.9, tY = 0.4, tP = 0.2, rsP = 0.6 },
		strike = { lsP = 0.9, lsR = -0.2, tY = -0.5, tP = 0.35, rsP = 0.3 },
	},
	Pounce = {
		windup = { tH = -0.7, tP = 0.55, rsP = -0.6, lsP = -0.6, rhP = 0.7, lhP = 0.7, nP = -0.4 },
		strike = { tH = 0, tP = 0.2, rsP = 1.7, lsP = 1.7, rsR = 0.3, lsR = 0.3, rhP = -0.4, lhP = -0.4 },
	},
	Cast = {
		windup = { rsP = 1.0, lsP = 1.0, rsR = 0.4, lsR = 0.4, tP = -0.1, nP = -0.1 },
		strike = { rsP = 1.65, lsP = 1.65, rsR = -0.05, lsR = -0.05, tP = 0.12, tF = 0.2 },
	},
	CastUp = {
		windup = { rsP = 1.2, lsP = 1.2, rsR = 0.6, lsR = 0.6 },
		strike = { rsP = 3.0, lsP = 3.0, rsR = 0.25, lsR = 0.25, nP = -0.5, tP = -0.2 },
	},
	Shoot = {
		windup = { lsP = 1.57, lsR = -0.1, rsP = 1.45, rsR = -0.45, rsY = 0.2, tY = 0.5, nY = -0.5 },
		strike = { lsP = 1.57, lsR = -0.1, rsP = 1.2, rsR = 0.6, tY = 0.5, nY = -0.5 },
	},
	Throw = {
		windup = { rsP = 2.9, rsR = 0.5, tY = -0.5, tP = -0.2, lsP = 1.0 },
		strike = { rsP = 1.0, rsR = 0.1, tY = 0.4, tP = 0.3, lsP = 0.2 },
	},
	Grab = {
		windup = { rsP = 1.5, lsP = 1.5, rsR = 1.0, lsR = 1.0, tP = -0.1 },
		strike = { rsP = 1.55, lsP = 1.55, rsR = -0.25, lsR = -0.25, tP = 0.3, tF = 0.5 },
	},
	Stomp = {
		windup = { rhP = 1.4, tP = -0.2, rsR = 0.6, lsR = 0.6, tH = 0.2 },
		strike = { rhP = 0.1, lhP = -0.2, tP = 0.3, rsR = 0.4, lsR = 0.4, tH = -0.3 },
	},
	Kick = {
		windup = { rhP = -0.6, tP = 0.15, rsR = 0.4, lsR = 0.4 },
		strike = { rhP = 1.7, tP = -0.35, rsR = 0.6, lsR = 0.6, lhP = 0.1 },
	},
	Roar = {
		windup = { rsP = 0.4, lsP = 0.4, rsR = 0.3, lsR = 0.3, tP = 0.3, nP = 0.3 },
		strike = { rsP = 0.6, lsP = 0.6, rsR = 1.4, lsR = 1.4, tP = -0.35, nP = -0.6 },
	},
	Hit = {
		windup = {},
		strike = { tP = -0.28, nP = -0.35, rsR = 0.4, lsR = 0.4, rsP = 0.3, lsP = 0.3, tH = -0.1 },
	},
	Parried = {
		windup = {},
		strike = { rsP = -0.4, rsR = 1.0, lsP = 0.6, lsR = 0.8, tP = -0.45, nP = -0.4, tY = 0.4, rhP = -0.3, lhP = 0.3 },
	},
	Dodge = {
		windup = { tH = -0.4, tR = 0.3 },
		strike = { tH = -0.2, tR = -0.3, rsR = 0.8, lsR = 0.8 },
	},
	Teleport = {
		windup = { rsP = 0.5, lsP = 0.5, rsR = 0.9, lsR = 0.9, tH = -0.3 },
		strike = { rsP = 2.6, lsP = 2.6, tH = 0.2 },
	},
	Block = {
		windup = { rsP = 1.2, rsR = -0.4, lsP = 1.2 },
		strike = { rsP = 1.45, rsR = -0.6, lsP = 1.35, lsR = -0.25, tP = -0.1 },
	},
	Point = {
		windup = {},
		strike = { rsP = 1.62, rsR = 0.1, nP = 0.05 },
	},
	Wave = {
		windup = { rsP = 2.6, rsR = 0.5 },
		strike = { rsP = 2.6, rsR = 0.1 },
	},
	Eat = {
		windup = { rsP = 1.9, rsR = -0.6, nP = 0.3 },
		strike = { rsP = 2.2, rsR = -0.7, nP = 0.2 },
	},
	-- hurt flinches (the side the hit came from)
	HitL = {
		windup = {},
		strike = { tY = -0.45, tR = -0.22, tP = -0.12, nY = -0.55, nR = -0.2, rsR = 0.4, lsR = 0.9, lsP = 0.5, rhP = -0.2 },
	},
	HitR = {
		windup = {},
		strike = { tY = 0.45, tR = 0.22, tP = -0.12, nY = 0.55, nR = 0.2, rsR = 0.9, rsP = 0.5, lsR = 0.4, lhP = -0.2 },
	},
	HitBack = {
		windup = {},
		strike = { tP = 0.45, nP = 0.5, tF = 0.35, rsP = -0.4, lsP = -0.4, rsR = 0.5, lsR = 0.5, rhP = -0.3, lhP = 0.25 },
	},
	HitHeavy = {
		windup = {},
		strike = { tP = -0.55, nP = -0.55, tF = -0.5, tH = -0.25, rsR = 1.1, lsR = 1.0, rsP = 0.7, lsP = 0.5, rhP = 0.45, lhP = -0.25 },
	},
	-- knocked flat on the back, then (recovery) back up
	Knockdown = {
		windup = { tP = -0.6, nP = -0.5, rsR = 0.9, lsR = 0.9 },
		strike = { tP = -1.5, tH = -2.35, tF = -0.7, rhP = 0.5, lhP = 0.25, rsP = 0.5, lsP = 0.3, rsR = 1.0, lsR = 0.9, nP = -0.35 },
	},
	-- launched into the air: spread-eagled, flailing
	Launched = {
		windup = { tP = -0.4, nP = -0.4 },
		strike = { tP = -0.95, rsR = 1.3, lsR = 1.2, rsP = 1.8, lsP = 0.9, rhP = 0.9, lhP = -0.45, nP = -0.45, tR = 0.3 },
	},
	-- monster moves
	Dive = {
		windup = { tP = -0.4, rsR = 1.6, lsR = 1.6, nP = 0.3 },
		strike = { tP = 1.4, rsR = 0.2, lsR = 0.2, rsP = -0.5, lsP = -0.5, nP = -1.2 },
	},
	Charge = {
		windup = { tP = 0.2, tH = -0.3, rhP = 0.5, lhP = -0.4 },
		strike = { tP = 0.7, tF = 0.8, rsP = -0.6, lsP = -0.6, nP = -0.5 },
	},
	Spit = {
		windup = { nP = 0.4, tP = -0.3, rsR = 0.4, lsR = 0.4 },
		strike = { nP = -0.35, tP = 0.3, tF = 0.2 },
	},
	-- four-legged beasts (poses keep the torso lying forward)
	QBite = {
		windup = { tP = 1.25, tH = -1.1, nP = -1.75, tF = -0.3 },
		strike = { tP = 1.6, tH = -1.15, nP = -1.0, tF = 0.7, rsP = 1.1, lsP = 1.1 },
	},
	QPounce = {
		windup = { tP = 1.55, tH = -1.4, nP = -1.5, rhP = 1.9, lhP = 1.9, rsP = 1.9, lsP = 1.9 },
		strike = { tP = 1.2, tH = -0.6, nP = -1.2, tF = 1.2, rsP = 0.4, lsP = 0.4, rhP = 2.4, lhP = 2.4 },
	},
	QStomp = {
		-- rears up on the hind legs, then crashes down with the front legs
		windup = { tP = 0.35, tH = -0.3, nP = -0.6, rsP = 2.2, lsP = 1.8, rhP = 0.35, lhP = 0.35 },
		strike = { tP = 1.6, tH = -1.2, nP = -1.2, rsP = 1.7, lsP = 1.7, rhP = 1.5, lhP = 1.5 },
	},
	QCharge = {
		windup = { tP = 1.55, tH = -1.3, nP = -1.7, tF = -0.5 },
		strike = { tP = 1.5, tH = -1.1, nP = -1.6, tF = 1.0, rsP = 1.0, lsP = 2.0, rhP = 2.0, lhP = 1.0 },
	},
}

-- ------------------------------------------------------------------ loop poses
Anim.LOOPS = {}
local L = Anim.LOOPS

function L.Cast(t, p)
	local j = sin(t * 18) * 0.05
	p.rsP, p.lsP = 1.5 + j, 1.5 - j
	p.rsR, p.lsR = 0.25, 0.25
	p.tP = -0.05
	p.nP = -0.1
end
function L.Channel(t, p)
	p.rsP, p.lsP = 2.8 + sin(t * 6) * 0.1, 2.8 - sin(t * 6) * 0.1
	p.rsR, p.lsR = 0.4, 0.4
	p.nP = -0.5
	p.tP = -0.15
end
function L.Cower(t, p)
	p.tH = -1.1
	p.tP = 0.7
	p.rhP, p.lhP = 1.6, 1.6
	p.rsP, p.lsP = 2.4, 2.4
	p.rsR, p.lsR = -0.4, -0.4
	p.nP = 0.6 + sin(t * 20) * 0.04
end
function L.Sit(t, p)
	p.tH = -1.0
	p.rhP, p.lhP = 1.57, 1.57
	p.rsP, p.lsP = 0.35, 0.35
	p.nP = sin(t * 0.7) * 0.05
end
-- astride a horse: knees out and forward, hands low on the reins (attacks
-- still take over the arms)
function L.Ride(t, p)
	p.rhP, p.lhP = 1.2, 1.2
	p.rhR, p.lhR = 0.45, 0.45
	p.rsP, p.lsP = 0.55, 0.55
	p.rsR, p.lsR = -0.15, -0.15
	p.tP = 0.1
	p.tH = 0
end
function L.SitTalk(t, p)
	L.Sit(t, p)
	p.rsP = 0.9 + sin(t * 3) * 0.3
	p.nY = sin(t * 1.1) * 0.25
end
function L.Kneel(t, p)
	p.tH = -1.0
	p.rhP = 1.57
	p.lhP = -0.1
	p.tP = 0.15
	p.nP = 0.35
	p.rsP, p.lsP = 0.2, 0.2
end
function L.KneelOne(t, p)
	p.tH = -0.95
	p.rhP = 1.6
	p.lhP = -0.35
	p.tP = 0.35
	p.nP = 0.5
	p.rsP = 0.8
	p.rsR = -0.2
	p.lsP = 0.1
end
function L.Float(t, p)
	local b = sin(t * 1.6)
	p.tH = 0.8 + b * 0.25
	p.rhP, p.lhP = 0.25, 0.1
	p.rsR, p.lsR = 0.55 + b * 0.05, 0.55 + b * 0.05
	p.rsP, p.lsP = 0.35, 0.35
	p.nP = 0.1
end
function L.Talk(t, p)
	p.rsP = 0.6 + sin(t * 3.2) * 0.35
	p.rsR = 0.25
	p.lsP = 0.2 + sin(t * 2.3 + 1) * 0.2
	p.nY = sin(t * 1.3) * 0.18
	p.nP = sin(t * 4.1) * 0.05
end
function L.Type(t, p)
	p.tH = -1.0
	p.rhP, p.lhP = 1.57, 1.57
	p.rsP = 1.25 + sin(t * 22) * 0.06
	p.lsP = 1.25 + sin(t * 19 + 1) * 0.06
	p.rsR, p.lsR = -0.18, -0.18
	p.nP = 0.2
end
function L.Dance(t, p)
	local b = sin(t * 7)
	p.tH = abs(b) * 0.3 - 0.1
	p.rsP = 2.6 + b * 0.4
	p.lsP = 1.2 - b * 0.6
	p.rsR, p.lsR = 0.5, 0.4
	p.tY = sin(t * 3.5) * 0.35
	p.nP = b * 0.15
	p.rhP = b * 0.3
	p.lhP = -b * 0.3
end
function L.Sleep(t, p)
	p.tP = -1.57
	p.tH = -2.4
	p.tF = -0.5
	p.rsR, p.lsR = 0.1, 0.1
	p.nP = sin(t * 1.2) * 0.02
end
function L.Lie(t, p)
	L.Sleep(t, p)
end
function L.Stagger(t, p)
	local w = sin(t * 9)
	p.tP = -0.35 + w * 0.1
	p.nP = -0.35
	p.rsR, p.lsR = 0.9 + w * 0.2, 0.9 - w * 0.2
	p.rsP, p.lsP = 0.5, 0.3
	p.tR = w * 0.12
	p.rhP, p.lhP = -0.2, 0.3
end
function L.Block(t, p)
	p.rsP = 1.4
	p.rsR = -0.55
	p.lsP = 1.35
	p.lsR = -0.2
	p.tP = 0.08
end
function L.Guard(t, p)
	p.rsP = 0.9
	p.rsR = 0.2
	p.lsP = 0.7
	p.lsR = -0.2
	p.tH = -0.15 + sin(t * 2) * 0.03
	p.rhP, p.lhP = 0.25, -0.2
end
function L.Cheer(t, p)
	local b = sin(t * 9)
	p.rsP = 2.9 + b * 0.15
	p.lsP = 2.9 - b * 0.15
	p.rsR, p.lsR = 0.4, 0.4
	p.tH = abs(b) * 0.25
end
function L.HandsUp(t, p)
	p.rsP, p.lsP = 2.9, 2.9
	p.rsR, p.lsR = 0.35, 0.35
	p.nP = sin(t * 12) * 0.05
end
function L.Pray(t, p)
	L.Kneel(t, p)
	p.rsP, p.lsP = 1.4, 1.4
	p.rsR, p.lsR = -0.55, -0.55
	p.nP = 0.4
end
function L.Dragged(t, p)
	p.rsP, p.lsP = 2.8, 2.8
	p.rsR, p.lsR = 0.25, 0.25
	p.tP = -0.35
	p.nP = 0.5
	p.rhP, p.lhP = -0.4 + sin(t * 8) * 0.2, -0.3 - sin(t * 8) * 0.2
end
function L.Throne(t, p)
	L.Sit(t, p)
	p.rsP, p.lsP = 0.6, 0.6
	p.rsR, p.lsR = 0.25, 0.25
	p.nP = -0.05
end
function L.Crossed(t, p)
	p.rsP, p.lsP = 1.35, 1.35
	p.rsR, p.lsR = -0.75, -0.75
	p.rsY, p.lsY = 0.3, 0.3
	p.tH = sin(t * 2) * 0.02
end
function L.Carry(t, p)
	-- both forearms under something held against the belly
	p.rsP, p.lsP = 1.05, 1.05
	p.rsR, p.lsR = -0.45, -0.45
	p.nP = 0.12
end
function L.Point(t, p)
	p.rsP = 1.6
	p.rsR = 0.05
end
function L.Phone(t, p)
	p.rsP = 2.0
	p.rsR = -0.55
	p.nP = 0.4
end
function L.Drink(t, p)
	p.rsP = 2.1
	p.rsR = -0.5
	p.nP = -0.25
end
function L.Mop(t, p)
	local s = sin(t * 3)
	p.rsP = 0.8 + s * 0.3
	p.lsP = 0.7 + s * 0.3
	p.rsR, p.lsR = -0.4, -0.3
	p.tY = s * 0.2
	p.tP = 0.25
end
function L.Hammer(t, p)
	local s = (t * 2.2) % 1
	p.rsP = if s < 0.4 then 2.6 else 0.8
	p.tP = 0.35
	p.lsP = 0.7
	p.nP = 0.35
end
function L.Dead(t, p)
	L.Sleep(t, p)
end
function L.Hunched(t, p)
	p.tP = 0.5
	p.nP = -0.35
	p.tH = -0.3
end
function L.Meditate(t, p)
	p.tH = -1.5
	p.rhP, p.lhP = 1.57, 1.57
	p.rhR, p.lhR = 0.9, 0.9
	p.rsP, p.lsP = 0.6, 0.6
	p.rsR, p.lsR = -0.2, -0.2
	p.nP = 0.25 + sin(t * 0.8) * 0.03
end

-- Evaluates an action at time `t` given windup/active/recover timings.
function Anim.actionPose(name: string, t: number, w: number, a: number, r: number, base, out)
	local def = Anim.ACTIONS[name]
	if not def then
		return nil
	end
	if t < w then
		return Anim.overlay(base, def.windup, smooth(t / max(w, 1e-3)), out), 1
	elseif t < w + a then
		local win = Anim.overlay(base, def.windup, 1)
		local k = easeOut((t - w) / max(a, 1e-3))
		local str = Anim.overlay(base, def.strike, 1)
		return Anim.blend(win, str, k, out), 1
	elseif t < w + a + r then
		local str = Anim.overlay(base, def.strike, 1)
		local k = smooth((t - w - a) / max(r, 1e-3))
		return Anim.blend(str, base, k, out), 1 - k
	end
	return nil
end

return Anim
