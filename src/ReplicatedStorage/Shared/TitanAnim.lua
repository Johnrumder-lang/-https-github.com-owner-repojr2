--!nonstrict
-- The Kingdom-Eater. A 230-stud cubic titan animated by forward kinematics.
-- The SAME functions run on the server (to know where feet, hands and weak-point
-- cores are) and on every client (to draw it smoothly). The titan clock pauses
-- during time stop on both sides.
local TitanAnim = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local sin, cos, clamp = math.sin, math.cos, math.clamp

local HIP_Y = 112
local HIP_X = 18
local THIGH = 50
local SHIN = 48
local TORSO = 62
local SHOULDER_X = 36
local UPPER = 46
local FORE = 44

TitanAnim.SIZES = {
	Pelvis = V(46, 22, 30),
	Torso = V(60, TORSO, 36),
	Head = V(32, 30, 32),
	LThigh = V(18, THIGH, 18),
	RThigh = V(18, THIGH, 18),
	LShin = V(16, SHIN, 16),
	RShin = V(16, SHIN, 16),
	LFoot = V(20, 8, 30),
	RFoot = V(20, 8, 30),
	LUpper = V(15, UPPER, 15),
	RUpper = V(15, UPPER, 15),
	LFore = V(13, FORE, 13),
	RFore = V(13, FORE, 13),
	LHand = V(18, 16, 14),
	RHand = V(18, 16, 14),
}
TitanAnim.ORDER = { "Pelvis", "Torso", "Head", "LThigh", "LShin", "LFoot", "RThigh", "RShin", "RFoot", "LUpper", "LFore", "LHand", "RUpper", "RFore", "RHand" }

local function zero()
	return {
		drop = 0, pitch = 0, roll = 0, -- root
		waist = 0, waistYaw = 0, neck = 0,
		lHip = 0, lKnee = 0, rHip = 0, rKnee = 0, lHipRoll = 0, rHipRoll = 0,
		lSh = 0, lShRoll = 0.25, lElbow = 0.2, rSh = 0, rShRoll = 0.25, rElbow = 0.2,
	}
end
TitanAnim.zero = zero

local function ease(t)
	t = clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
local function lerp(a, b, t)
	return a + (b - a) * t
end

-- Actions: returns pose for time t (seconds into the action).
TitanAnim.ACTIONS = {}
local A = TitanAnim.ACTIONS

A.idle = { dur = 4, pose = function(t, p)
	local b = sin(t * 1.2)
	p.waist = 0.05 + b * 0.02
	p.neck = b * 0.03
	p.lSh = 0.1 + b * 0.04
	p.rSh = 0.1 - b * 0.04
	p.drop = b * 1.2
end }

A.walk = { dur = 6, pose = function(t, p)
	local ph = t * 1.1
	local s = sin(ph)
	p.lHip = -s * 0.32
	p.rHip = s * 0.32
	p.lKnee = math.max(0, cos(ph)) * 0.5
	p.rKnee = math.max(0, -cos(ph)) * 0.5
	p.lSh = s * 0.25
	p.rSh = -s * 0.25
	p.drop = math.abs(cos(ph)) * 3
	p.waist = 0.08
	p.roll = s * 0.03
end }

-- Stomp with the given leg: windup 1.6, slam 0.35, recover 1.5
A.stompL = { dur = 3.45, hit = 1.95, pose = function(t, p)
	local raise = if t < 1.6 then ease(t / 1.6) elseif t < 1.95 then 1 - ease((t - 1.6) / 0.35) else 0
	local plant = if t < 1.6 then 0 elseif t < 1.95 then ease((t - 1.6) / 0.35) elseif t < 2.6 then 1 else 1 - ease((t - 2.6) / 0.85)
	p.lHip = -0.95 * raise - 0.45 * plant
	p.lKnee = 1.2 * raise
	p.rKnee = 0.15 * raise + 0.4 * plant
	p.drop = 12 * plant
	p.waist = 0.12 + 0.1 * raise
	p.lSh = 0.4 * raise
	p.rSh = -0.3 * raise
end }
A.stompR = { dur = 3.45, hit = 1.95, pose = function(t, p)
	local raise = if t < 1.6 then ease(t / 1.6) elseif t < 1.95 then 1 - ease((t - 1.6) / 0.35) else 0
	local plant = if t < 1.6 then 0 elseif t < 1.95 then ease((t - 1.6) / 0.35) elseif t < 2.6 then 1 else 1 - ease((t - 2.6) / 0.85)
	p.rHip = -0.95 * raise - 0.45 * plant
	p.rKnee = 1.2 * raise
	p.lKnee = 0.15 * raise + 0.4 * plant
	p.drop = 12 * plant
	p.waist = 0.12 + 0.1 * raise
	p.rSh = 0.4 * raise
	p.lSh = -0.3 * raise
end }

-- Right hand sweeps across the ground in front (jump over it).
A.sweep = { dur = 4.2, hitFrom = 1.7, hitTo = 2.6, pose = function(t, p)
	local down = if t < 1.4 then ease(t / 1.4) elseif t < 3.0 then 1 else 1 - ease((t - 3.0) / 1.2)
	local k = clamp((t - 1.5) / 1.2, 0, 1)
	p.waist = 1.2 * down
	p.waistYaw = lerp(0.9, -0.9, ease(k)) * down
	p.rSh = 1.35 * down
	p.rShRoll = 0.1
	p.rElbow = 0
	p.lKnee = 1.0 * down
	p.rKnee = 1.0 * down
	p.drop = 40 * down
	p.lSh = 0.3 * down
end }

A.sweepL = { dur = 4.2, hitFrom = 1.7, hitTo = 2.6, pose = function(t, p)
	local down = if t < 1.4 then ease(t / 1.4) elseif t < 3.0 then 1 else 1 - ease((t - 3.0) / 1.2)
	local k = clamp((t - 1.5) / 1.2, 0, 1)
	p.waist = 1.2 * down
	p.waistYaw = lerp(-0.9, 0.9, ease(k)) * down
	p.lSh = 1.35 * down
	p.lShRoll = 0.1
	p.lElbow = 0
	p.lKnee = 1.0 * down
	p.rKnee = 1.0 * down
	p.drop = 40 * down
	p.rSh = 0.3 * down
end }

-- Grab a chunk of the city and hurl it.
A.throw = { dur = 4.0, release = 2.6, pose = function(t, p)
	local grab = if t < 1.2 then ease(t / 1.2) elseif t < 1.8 then 1 else 0
	local wind = if t >= 1.8 and t < 2.5 then ease((t - 1.8) / 0.7) elseif t >= 2.5 and t < 2.8 then 1 - ease((t - 2.5) / 0.3) else 0
	p.waist = 0.7 * grab + 0.1
	p.rSh = 1.3 * grab + (-2.4) * wind + (if t >= 2.5 then 0.9 * ease((t - 2.5) / 0.4) * (1 - ease((t - 3) / 1)) else 0)
	p.rElbow = 0.2 + 0.8 * wind
	p.drop = 12 * grab
	p.waistYaw = 0.4 * wind
end }

A.roar = { dur = 3.2, hit = 1.2, pose = function(t, p)
	local k = if t < 1 then ease(t) elseif t < 2.4 then 1 else 1 - ease((t - 2.4) / 0.8)
	p.waist = -0.25 * k
	p.neck = -0.5 * k
	p.lShRoll = 0.25 + 1.0 * k
	p.rShRoll = 0.25 + 1.0 * k
	p.lSh = 0.3 * k
	p.rSh = 0.3 * k
	p.lElbow = 0.6 * k
	p.rElbow = 0.6 * k
end }

-- Falls forward onto its hands and chest (phase 2 starts).
A.collapse = { dur = 3.5, pose = function(t, p)
	local k = ease(t / 3.0)
	p.lKnee = 1.2 * k
	p.rKnee = 1.2 * k
	p.lHip = -0.4 * k
	p.rHip = -0.4 * k
	p.drop = 90 * k
	p.pitch = 1.35 * k
	p.lSh = 1.6 * k
	p.rSh = 1.6 * k
	p.neck = 0.3 * k
end }

-- Face down, heaving; swings its head side to side.
A.down = { dur = 5, hit = 3.0, pose = function(t, p)
	local b = sin(t * 1.6)
	p.lKnee, p.rKnee = 1.2, 1.2
	p.lHip, p.rHip = -0.4, -0.4
	p.drop = 90 + b * 2
	p.pitch = 1.35
	p.lSh, p.rSh = 1.6, 1.6
	local swing = if t > 2.2 and t < 3.6 then sin((t - 2.2) / 1.4 * math.pi) else 0
	p.neck = 0.3 + b * 0.04
	p.waistYaw = swing * 0.5
end }

A.die = { dur = 6, pose = function(t, p)
	local k = ease(t / 5)
	p.lKnee, p.rKnee = 1.2, 1.2
	p.lHip, p.rHip = -0.4, -0.4
	p.drop = 90 + 12 * k
	p.pitch = 1.35 + 0.2 * k
	p.roll = 0.35 * k
	p.lSh, p.rSh = 1.6 - k, 1.6 - k
	p.neck = 0.3 - 0.5 * k
end }

-- Stepping onto the arena in the intro (right foot hovers above target).
A.hover = { dur = 999, pose = function(t, p)
	local up = ease(math.min(t / 2.5, 1))
	p.rHip = -0.95 * up
	p.rKnee = 1.2 * up
	p.waist = 0.2 * up
	p.rSh = 0.4 * up
end }

function TitanAnim.pose(action: string, t: number)
	local p = zero()
	local a = A[action] or A.idle
	a.pose(t, p)
	return p
end

-- Forward kinematics: root CFrame (ground under the pelvis, facing -Z) -> part CFrames
function TitanAnim.solve(root: CFrame, p)
	local out = {}
	local base = root * CF(0, -p.drop, 0)
	local pelvis = base * CF(0, HIP_Y, 0) * ANG(-p.pitch, 0, p.roll)
	out.Pelvis = pelvis * CF(0, 4, 0)
	local waist = pelvis * CF(0, 14, 0) * ANG(0, p.waistYaw, 0) * ANG(-p.waist, 0, 0)
	out.Torso = waist * CF(0, TORSO / 2, 0)
	local neck = waist * CF(0, TORSO, 0) * ANG(-p.neck, 0, 0)
	out.Head = neck * CF(0, 16, -2)
	local function leg(side, hip, hipRoll, knee)
		local h = pelvis * CF(side * HIP_X, -6, 0) * ANG(-hip, 0, side * hipRoll)
		local thigh = h * CF(0, -THIGH / 2, 0)
		local k = h * CF(0, -THIGH, 0) * ANG(knee, 0, 0)
		local shin = k * CF(0, -SHIN / 2, 0)
		local ankle = k * CF(0, -SHIN, 0) * ANG(-(knee - hip) * 0.6, 0, 0)
		local foot = ankle * CF(0, -4, -6)
		return thigh, shin, foot
	end
	out.LThigh, out.LShin, out.LFoot = leg(-1, p.lHip, p.lHipRoll, p.lKnee)
	out.RThigh, out.RShin, out.RFoot = leg(1, p.rHip, p.rHipRoll, p.rKnee)
	local function arm(side, sh, roll, elbow)
		local s = waist * CF(side * SHOULDER_X, TORSO - 8, 0) * ANG(sh, 0, 0) * ANG(0, 0, -side * roll)
		local upper = s * CF(0, -UPPER / 2, 0)
		local e = s * CF(0, -UPPER, 0) * ANG(elbow, 0, 0)
		local fore = e * CF(0, -FORE / 2, 0)
		local hand = e * CF(0, -FORE - 6, 0)
		return upper, fore, hand
	end
	out.LUpper, out.LFore, out.LHand = arm(-1, p.lSh, p.lShRoll, p.lElbow)
	out.RUpper, out.RFore, out.RHand = arm(1, p.rSh, p.rShRoll, p.rElbow)
	return out
end

-- Weak points (name -> part, offset in part space)
TitanAnim.CORES = {
	LShinCore = { part = "LShin", off = V(0, -10, -8.6) },
	RShinCore = { part = "RShin", off = V(0, -10, -8.6) },
	LHandCore = { part = "LHand", off = V(0, 0, -7.6) },
	RHandCore = { part = "RHand", off = V(0, 0, -7.6) },
	HornCore = { part = "Head", off = V(0, 15.4, -4) },
	EyeCore = { part = "Head", off = V(0, 3, -16.4) },
}

function TitanAnim.corePos(parts, name: string): Vector3
	local c = TitanAnim.CORES[name]
	local cf = parts[c.part]
	return (cf * CF(c.off)).Position
end

return TitanAnim
