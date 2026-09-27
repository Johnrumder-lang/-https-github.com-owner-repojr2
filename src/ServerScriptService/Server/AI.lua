--!nonstrict
-- Enemy & NPC brains. One Heartbeat scheduler updates every brain ~12x per second
-- using an "entity clock" that stops while the entity is frozen by a time stop,
-- so attacks resume exactly where they were when time comes back.
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Enemies = require(Shared.Enemies)
local Rig = require(Shared.Rig)
local Weapons = require(Shared.Weapons)
local Util = require(Shared.Util)
local RNG = require(Shared.RNG)
require(Shared.Beasts) -- registers the trait-monster body plans with Rig
local S = require(script.Parent.S)

local AI = {}
AI.brains = {}
AI.types = {}
local tokens = {} -- [targetEntity] = { [brain] = true }
local rng = RNG.new(os.time() % 100000 + 7)

local THINK = 1 / 12

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

function AI.folder(): Folder
	local world = workspace:FindFirstChild("World")
	if not world then
		world = Instance.new("Folder")
		world.Name = "World"
		world.Parent = workspace
	end
	local f = world:FindFirstChild("Entities")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Entities"
		f.Parent = world
	end
	return f :: Folder
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

-- ------------------------------------------------------------------ tokens
local function tokenCount(target)
	local n = 0
	for b in tokens[target] or {} do
		if b.e and not b.e.dead then
			n += 1
		end
	end
	return n
end

local function takeToken(brain, target)
	if not target then
		return false
	end
	local t = tokens[target]
	if not t then
		t = {}
		tokens[target] = t
	end
	if t[brain] then
		return true
	end
	local max = Config.Combat.maxAttackersPerTarget + (brain.extraTokens or 0)
	if S.TimeStop.active then
		max += 1
	end
	if tokenCount(target) < max then
		t[brain] = true
		return true
	end
	return false
end

local function dropToken(brain)
	for _, t in tokens do
		t[brain] = nil
	end
end

-- ================================================================== MELEE BRAIN
local Melee = {}
Melee.__index = Melee
AI.Melee = Melee
AI.types.melee = Melee

function Melee.new(e, opts)
	local self = setmetatable({}, Melee)
	self.e = e
	self.def = e.def
	self.opts = opts or {}
	self.t = 0
	self.nextScan = 0
	self.nextMove = 0
	self.target = nil
	self.home = e.root.Position
	self.cds = {}
	self.action = nil
	self.strafe = rng:sign()
	self.strafeFlip = 0
	self.lastPos = e.root.Position
	self.stuckT = 0
	self.pathT = 0
	self.path = nil
	self.pathI = 1
	self.aggro = self.opts.aggro or self.def.aggro or 90
	self.leash = self.opts.leash or 260
	self.passive = self.opts.passive or false
	self.wanderT = rng:float(1, 4)
	self.fleeing = false
	self.nextBlink = 0
	self.summoned = {}
	self.idlePose = self.opts.idlePose
	local att = e.root:FindFirstChild("RootAttachment") :: Attachment
	if att then
		local ao = Instance.new("AlignOrientation")
		ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
		ao.Attachment0 = att
		ao.MaxTorque = 1e7
		ao.Responsiveness = 28
		ao.RigidityEnabled = false
		ao.Enabled = false
		ao.Parent = e.root
		self.ao = ao
	end
	if self.idlePose then
		e.model:SetAttribute("Pose", self.idlePose)
	end
	return self
end

function Melee:pos(): Vector3
	return self.e.root.Position
end

function Melee:face(p: Vector3)
	if not self.ao then
		return
	end
	local my = self:pos()
	local d = Util.flat(p - my)
	if d.Magnitude < 0.1 then
		return
	end
	self.ao.CFrame = CFrame.lookAt(Vector3.zero, d.Unit)
	self.ao.Enabled = true
	self.e.hum.AutoRotate = false
end

function Melee:unface()
	if self.ao then
		self.ao.Enabled = false
	end
	if self.e.hum then
		self.e.hum.AutoRotate = true
	end
end

function Melee:setAct(atk)
	local m = self.e.model
	if atk then
		m:SetAttribute("ActW", atk.w)
		m:SetAttribute("ActA", atk.a)
		m:SetAttribute("ActR", atk.r)
		m:SetAttribute("ActKind", atk.kind)
		m:SetAttribute("ActT0", serverNow())
		m:SetAttribute("Act", atk.anim)
	else
		m:SetAttribute("Act", nil)
		m:SetAttribute("ActKind", nil)
	end
end

function Melee:playAct(anim: string, w: number, a: number, r: number)
	self:setAct({ anim = anim, w = w, a = a, r = r, kind = "none" })
end

function Melee:cancelAction()
	if self.action then
		self.action = nil
		self:setAct(nil)
		dropToken(self)
	end
end

function Melee:hasLOS(p: Vector3): boolean
	return S.Combat.lineOfSight(self:pos() + Vector3.new(0, 1.5, 0), p + Vector3.new(0, 1.5, 0))
end

function Melee:scan()
	local e = self.e
	if self.target and S.Entities.isAlive(self.target) and not self.target.untargetable then
		local d = (S.Entities.position(self.target) - self:pos()).Magnitude
		if d < self.leash then
			return
		end
	end
	self.target = nil
	if self.passive then
		return
	end
	local best, bd = nil, self.aggro
	for _, o in S.Entities.list do
		if o ~= e and S.Entities.isAlive(o) and S.Entities.hostile(e, o) and not o.untargetable then
			local d = (S.Entities.position(o) - self:pos()).Magnitude
			if d < bd and (d < 18 or self:hasLOS(S.Entities.position(o))) then
				best, bd = o, d
			end
		end
	end
	self.target = best
	if best and not self.alerted then
		self.alerted = true
		self:onAlert()
	end
end

function Melee:onAlert()
	if self.opts.shout then
		Net.fireAll("FX", "Shout", { target = self.e.model, text = self.opts.shout })
	end
	if self.idlePose then
		self.e.model:SetAttribute("Pose", nil)
	end
end

function Melee:attackReady(atk, dist: number): boolean
	if (self.cds[atk.id] or 0) > self.t then
		return false
	end
	if dist > atk.range * 1.05 + (self.e.radius - 1.6) then
		return false
	end
	if atk.minRange and dist < atk.minRange then
		return false
	end
	if atk.kind == "summon" then
		local alive = 0
		for _, s in self.summoned do
			if S.Entities.isAlive(s) then
				alive += 1
			end
		end
		if alive >= 4 then
			return false
		end
	end
	return true
end

function Melee:chooseAttack(dist: number)
	local list = {}
	for _, atk in self.def.attacks or {} do
		if self:attackReady(atk, dist) then
			table.insert(list, { atk, atk.weight or 1 })
		end
	end
	if #list == 0 then
		return nil
	end
	return rng:weighted(list)
end

function Melee:startAction(atk)
	local tp = S.Entities.position(self.target)
	self.action = { atk = atk, t = 0, struck = false, target = self.target, dir = Util.flatUnit(tp - self:pos()) }
	local speedMult = self.speedMult or 1
	self.cds[atk.id] = self.t + (atk.cd or 0) + (atk.w + atk.a + atk.r) / speedMult
	self:face(tp)
	self.e.hum:Move(Vector3.zero)
	self:setAct(atk)
	if atk.kind == "heavy" or atk.kind == "sweep" or atk.kind == "grab" then
		Net.fireAll("FX", "Telegraph", { target = self.e.model, kind = atk.kind, t = atk.w })
	end
end

function Melee:stepAction(dt: number)
	local a = self.action
	local atk = a.atk
	a.t += dt * (self.speedMult or 1)
	local e = self.e
	if a.t < atk.w and a.target and S.Entities.isAlive(a.target) then
		local tp = S.Entities.position(a.target)
		self:face(tp)
		a.dir = Util.flatUnit(tp - self:pos())
	end
	if (atk.kind == "lunge" or atk.lunge) and a.t >= atk.w * 0.8 and a.t < atk.w + atk.a then
		local speed = atk.lunge or 60
		local att = e.root:FindFirstChild("RootAttachment")
		if att and not a.lv then
			local lv = Instance.new("LinearVelocity")
			lv.Attachment0 = att
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(1, 0, 1) * 6e4 * e.root.AssemblyMass
			lv.RelativeTo = Enum.ActuatorRelativeTo.World
			lv.VectorVelocity = a.dir * speed
			lv.Parent = e.root
			a.lv = lv
		end
	elseif a.lv then
		a.lv:Destroy()
		a.lv = nil
	end
	if not a.struck and a.t >= atk.w then
		a.struck = true
		self:strike(atk, a)
	end
	if a.t >= atk.w + atk.a + atk.r then
		if a.lv then
			a.lv:Destroy()
		end
		self.action = nil
		self:setAct(nil)
		dropToken(self)
		self:unface()
	end
end

function Melee:meleeTargets(range: number, arcDeg: number, dir: Vector3)
	local out = {}
	local my = self:pos()
	for _, o in S.Entities.list do
		if o ~= self.e and S.Entities.isAlive(o) and S.Entities.hostile(self.e, o) then
			local p = S.Entities.position(o)
			local to = p - my
			local dist = Util.flat(to).Magnitude - (o.radius or 1.5) * 0.6
			if dist <= range and math.abs(to.Y) < range * 0.8 + 4 then
				local ang = math.deg(Util.angleBetween(Util.flat(to), dir))
				if ang <= arcDeg / 2 or dist < 2 then
					table.insert(out, o)
				end
			end
		end
	end
	return out
end

function Melee:strike(atk, a)
	local e = self.e
	local dmg = e.dmg * (atk.dmg or 1) * (self.dmgMult or 1)
	local kind = atk.kind
	local my = self:pos()
	if kind == "projectile" then
		local head = e.model:FindFirstChild("Head") :: BasePart
		local origin = (head and head.Position or my) + a.dir * 2
		local target = a.target
		if not target or not S.Entities.isAlive(target) then
			return
		end
		local tp = S.Entities.position(target)
		local proj = atk.proj
		local speed = proj.speed
		local dist = (tp - origin).Magnitude
		local t = dist / speed
		local vel = Vector3.zero
		if target.root then
			vel = target.root.AssemblyLinearVelocity
		end
		local aim = tp + Util.flat(vel) * t * 0.55 + Vector3.new(0, 0.5 * (proj.gravity or 0) * t * t, 0)
		S.Projectiles.fire(e, origin, (aim - origin).Unit * speed, proj, {
			dmg = dmg,
			kbPower = atk.kb,
			posture = 10,
			shooter = e,
		}, target)
		return
	elseif kind == "aoe" then
		local center = my
		if atk.anim == "CastUp" and a.target then
			center = S.Entities.position(a.target)
		end
		Net.fireAll("FX", "Shockwave", { pos = center - Vector3.new(0, 2.5, 0), radius = atk.aoe, color = if atk.id == "Roar" then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(255, 120, 60) })
		S.Combat.aoe(e, center, atk.aoe or 10, { dmg = dmg, kbPower = atk.kb, kbUp = 20, attackType = "aoe", kind = "aoe", posture = 12 })
		return
	elseif kind == "special" then
		if self.special then
			self:special(atk, a)
		end
		return
	elseif kind == "summon" then
		local what = atk.summon
		for i = 1, what[2] do
			local off = CFrame.Angles(0, rng:angle(), 0) * Vector3.new(0, 0, 9)
			local se = AI.spawn(what[1], CFrame.new(my + off), { level = e.level, tags = e.tags, aggro = 200 })
			if se then
				table.insert(self.summoned, se)
				Net.fireAll("FX", "Teleport", { from = my, to = my + off, color = Color3.fromRGB(160, 60, 255) })
			end
		end
		return
	end
	-- melee: tell clients to draw the slash (anime crescents)
	Net.fireAll("FX", "Slash", {
		pos = my,
		dir = a.dir,
		anim = atk.anim,
		range = atk.range,
		scale = e.model and e.model:GetScale() or 1,
		heavy = kind == "heavy" or kind == "sweep",
		giant = self.def and self.def.giant,
		color = if kind == "heavy" then Color3.fromRGB(255, 60, 50) elseif kind == "sweep" then Color3.fromRGB(255, 210, 60) elseif kind == "grab" then Color3.fromRGB(190, 80, 255) else nil,
	})
	local targets = self:meleeTargets(atk.range, atk.arc or 90, a.dir)
	for _, t in targets do
		local kb = a.dir * (atk.kb or 15) + Vector3.new(0, (atk.kb or 15) * 0.35, 0)
		S.Combat.hit(e, t, {
			dmg = dmg,
			kb = kb,
			posture = 10,
			attackType = kind,
			kind = "melee",
			pos = S.Entities.position(t),
		})
	end
	if atk.shock then
		local center = my + a.dir * (atk.range * 0.6)
		Net.fireAll("FX", "Shockwave", { pos = center - Vector3.new(0, 2.5, 0), radius = atk.shock, color = Color3.fromRGB(230, 200, 160) })
		S.Combat.aoe(e, center, atk.shock, { dmg = dmg * 0.6, kbPower = 26, kbUp = 24, attackType = "aoe", kind = "shock" })
	end
end

function Melee:moveTo(p: Vector3)
	local hum = self.e.hum
	if not hum then
		return
	end
	-- pathfind when there's no line of sight
	if not self:hasLOS(p) then
		if self.t > self.pathT then
			self.pathT = self.t + 1.3
			local path = PathfindingService:CreatePath({ AgentRadius = 2 * (self.e.radius / 1.6), AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 6 })
			local ok = pcall(function()
				path:ComputeAsync(self:pos(), p)
			end)
			if ok and path.Status == Enum.PathStatus.Success then
				self.path = path:GetWaypoints()
				self.pathI = 2
			else
				self.path = nil
			end
		end
		if self.path and self.path[self.pathI] then
			local wp = self.path[self.pathI]
			if Util.flatDist(wp.Position, self:pos()) < 4 then
				self.pathI += 1
				wp = self.path[self.pathI] or wp
			end
			if wp.Action == Enum.PathWaypointAction.Jump then
				hum.Jump = true
			end
			hum:MoveTo(wp.Position)
			return
		end
	else
		self.path = nil
	end
	hum:MoveTo(p)
end

function Melee:checkStuck(dt: number, moving: boolean)
	local p = self:pos()
	if moving and (p - self.lastPos).Magnitude < 0.25 * dt * 12 then
		self.stuckT += dt
		if self.stuckT > 1.2 then
			self.stuckT = 0
			self.e.hum.Jump = true
			self.strafe = -self.strafe
		end
	else
		self.stuckT = 0
	end
	self.lastPos = p
end

function Melee:wander(dt: number)
	local hum = self.e.hum
	if self.opts.stationary then
		hum:Move(Vector3.zero)
		return
	end
	self.wanderT -= dt
	if self.wanderT <= 0 then
		self.wanderT = rng:float(3, 7)
		local r = self.opts.wanderRadius or 18
		if r > 0 then
			local off = rng:flatDir() * rng:float(4, r)
			hum.WalkSpeed = (self.def.speed or 16) * 0.45
			hum:MoveTo(self.home + off)
		end
	end
end

function Melee:think(dt: number)
	local e = self.e
	local hum = e.hum
	if self.t >= self.nextScan then
		self.nextScan = self.t + 0.45
		self:scan()
	end
	local target = self.target
	if not target then
		self:unface()
		self:wander(dt)
		return
	end
	hum.WalkSpeed = (self.def.speed or 16) * (self.speedMult or 1) * (if e.slowed then 0.55 else 1)
	local my = self:pos()
	local tp = S.Entities.position(target)
	local dist = (tp - my).Magnitude - (target.radius or 1.5) * 0.5

	-- fleeing villagers
	if self.def.flee then
		local hp, max = S.Entities.health(e)
		if hp / max < self.def.flee and not self.brave then
			if not self.fleeing then
				self.fleeing = true
				self.fleeUntil = self.t + rng:float(4, 8)
				Net.fireAll("FX", "Shout", { target = e.model, text = rng:pick({ "Mercy!", "Help!", "Run!", "Please, no!", "Mama!" }) })
			end
		end
		if self.fleeing then
			if self.t > self.fleeUntil then
				self.fleeing = false
				self.brave = true
				e.model:SetAttribute("Pose", nil)
			elseif dist < 7 and rng:chance(0.02) then
				e.model:SetAttribute("Pose", "Cower")
				hum:Move(Vector3.zero)
				return
			else
				e.model:SetAttribute("Pose", nil)
				local away = Util.flatUnit(my - tp)
				self:moveTo(my + away * 20 + Vector3.new(rng:float(-6, 6), 0, rng:float(-6, 6)))
				self:unface()
				return
			end
		end
	end

	-- blink away (casters)
	if self.def.blink and dist < 9 and self.t > self.nextBlink then
		self.nextBlink = self.t + rng:float(5, 8)
		local dir = Util.flatUnit(my - tp)
		local step = (CFrame.Angles(0, rng:float(-1, 1), 0) * dir) * 22
		-- never through a wall: stop short of whatever is in the way
		local wall = workspace:Raycast(my + Vector3.new(0, 1, 0), step, AI.geoParams())
		if wall then
			step = step.Unit * math.max(0, wall.Distance - 3)
		end
		local dest = my + step
		local r = workspace:Raycast(dest + Vector3.new(0, 2, 0), Vector3.new(0, -40, 0), AI.geoParams())
		if r and step.Magnitude > 6 then
			dest = r.Position + Vector3.new(0, 3, 0)
			Net.fireAll("FX", "Teleport", { from = my, to = dest, color = Color3.fromRGB(170, 90, 255) })
			e.root.CFrame = CFrame.lookAt(dest, Vector3.new(tp.X, dest.Y, tp.Z))
			return
		end
	end

	-- attack
	local isRanged = self.def.ai == "ranged" or self.def.ai == "caster"
	local hasToken = e.boss or e.miniboss or isRanged or takeToken(self, target)
	if hasToken then
		local atk = self:chooseAttack(dist)
		if atk and (atk.kind == "projectile" or atk.kind == "aoe" or atk.kind == "summon" or atk.kind == "special" or dist <= atk.range) then
			if atk.kind ~= "projectile" or self:hasLOS(tp) then
				self:startAction(atk)
				return
			end
		end
	end

	-- movement
	local moving = true
	if isRanged then
		local keep = self.def.keepAway or 26
		if dist < keep * 0.6 then
			self:moveTo(my + Util.flatUnit(my - tp) * 14)
		elseif dist > keep * 1.35 or not self:hasLOS(tp) then
			self:moveTo(tp)
		else
			if self.t > self.strafeFlip then
				self.strafeFlip = self.t + rng:float(1.5, 3)
				self.strafe = -self.strafe
			end
			local side = Util.flatUnit(tp - my):Cross(Vector3.yAxis) * self.strafe
			self:moveTo(my + side * 8)
		end
		self:face(tp)
	elseif hasToken then
		self:moveTo(tp)
		if dist < 14 then
			self:face(tp)
		else
			self:unface()
		end
	else
		-- circle at a respectful distance until a token frees up
		local ring = 11 + (e.id % 4) * 1.5
		if self.t > self.strafeFlip then
			self.strafeFlip = self.t + rng:float(1.2, 2.8)
			if rng:chance(0.35) then
				self.strafe = -self.strafe
			end
		end
		local dir = Util.flatUnit(my - tp)
		local rot = CFrame.Angles(0, 0.55 * self.strafe, 0) * dir
		self:moveTo(tp + rot * ring)
		if dist < 20 then
			self:face(tp)
		end
	end
	if dist > 3 and tp.Y - my.Y > 4.5 and dist < 18 then
		hum.Jump = true
	end
	self:checkStuck(dt, moving)
end

function Melee:update(dt: number)
	local e = self.e
	if e.dead or not e.root or not e.root.Parent then
		return
	end
	self.t += dt
	local model = e.model
	if model:GetAttribute("Ragdoll") then
		self:cancelAction()
		return
	end
	if os.clock() < e.stunUntil then
		if e.hum then
			e.hum:Move(Vector3.zero)
		end
		return
	elseif self.staggered then
		self.staggered = false
		model:SetAttribute("Pose", nil)
	end
	if self.scripted then
		return
	end
	if self.action then
		self:stepAction(dt)
		return
	end
	self:think(dt)
	if self.afterThink then
		self:afterThink(dt)
	end
end

function Melee:onHit(attacker, info)
	local e = self.e
	if attacker and attacker ~= e and S.Entities.hostile(e, attacker) then
		self.target = attacker
		self.passive = false
		if not self.alerted then
			self.alerted = true
			self:onAlert()
		end
	end
	if e.poise and not info.heavy then
		return
	end
	if self.action and self.action.t < self.action.atk.w and not (e.boss and not info.heavy) then
		self:cancelAction()
	end
	if not self.action then
		local cur = e.model:GetAttribute("Act")
		if cur == "Knockdown" or cur == "Launched" then
			return -- already on the floor / in the air: don't cancel that animation
		end
		e.stunUntil = math.max(e.stunUntil, os.clock() + (if info.heavy then 0.6 else 0.32))
		self:playAct(AI.hurtAnim(e, attacker, info), 0.02, if info.heavy then 0.14 else 0.1, if info.heavy then 0.45 else 0.28)
	end
end

-- which flinch: heavy hits rock the whole body, others twist away from the side hit
function AI.hurtAnim(e, attacker, info): string
	if info and info.heavy then
		return "HitHeavy"
	end
	if not attacker or not e.root then
		return "Hit"
	end
	local to = Util.flat(S.Entities.position(attacker) - e.root.Position)
	if to.Magnitude < 0.1 then
		return "Hit"
	end
	to = to.Unit
	local cf = e.root.CFrame
	local fwd = Util.flat(cf.LookVector)
	if fwd.Magnitude > 0.1 and to:Dot(fwd.Unit) < -0.4 then
		return "HitBack"
	end
	local side = to:Dot(cf.RightVector)
	if side > 0.35 then
		return "HitR"
	elseif side < -0.35 then
		return "HitL"
	end
	return "Hit"
end

function Melee:onParried(by, info)
	local e = self.e
	self:cancelAction()
	e.stunUntil = os.clock() + (if e.boss then 0.9 else 1.25)
	e.riposteUntil = os.clock() + 1.4
	self:playAct("Parried", 0.03, 0.18, 0.9)
end

function Melee:onStagger(dur: number)
	self:cancelAction()
	self.staggered = true
	self.e.model:SetAttribute("Pose", "Stagger")
end

function Melee:tryDefend(attacker, info)
	local e = self.e
	if self.action or os.clock() < e.stunUntil or info.heavy then
		return nil
	end
	local chance = self.def.parryChance or 0
	if chance <= 0 then
		return nil
	end
	local to = S.Entities.position(attacker) - self:pos()
	local facing = e.root.CFrame.LookVector
	if math.deg(Util.angleBetween(Util.flat(to), Util.flat(facing))) > 75 then
		return nil
	end
	if rng:chance(chance) then
		Net.fireAll("FX", "Parry", { pos = self:pos() + Util.flatUnit(to) * 2 + Vector3.new(0, 1.5, 0), npc = true })
		self:playAct("Block", 0.02, 0.15, 0.3)
		if attacker.player then
			Net.fire(attacker.player, "HitConfirm", { deflected = true })
			S.Combat.push(attacker, Util.flatUnit(to) * 28)
		end
		self.cds = {}
		return "deflected"
	end
	if self.def.blockChance and rng:chance(self.def.blockChance) then
		info.dmg *= 0.35
		info.kb = (info.kb or Vector3.zero) * 0.3
		Net.fireAll("FX", "Block", { pos = self:pos() + Vector3.new(0, 1.5, 0) })
	end
	return nil
end

function Melee:onDeath()
	dropToken(self)
	self:setAct(nil)
	if self.ao then
		self.ao:Destroy()
	end
end

function Melee:destroy()
	self:onDeath()
end

-- ================================================================== SLIME BRAIN
local Slime = setmetatable({}, { __index = Melee })
Slime.__index = Slime
AI.types.slime = Slime

function Slime.new(e, opts)
	local self = setmetatable({}, Slime)
	self.e = e
	self.def = e.def
	self.opts = opts or {}
	self.t = 0
	self.nextScan = 0
	self.nextHop = rng:float(0.5, 1.5)
	self.aggro = self.def.aggro or 70
	self.leash = 200
	self.home = e.root.Position
	self.cds = {}
	self.summoned = {}
	self.lastContact = 0
	return self
end

function Slime:update(dt: number)
	local e = self.e
	if e.dead or not e.root.Parent then
		return
	end
	self.t += dt
	if self.t >= self.nextScan then
		self.nextScan = self.t + 0.5
		self:scan()
	end
	local root = e.root
	if self.t >= self.nextHop and not root.Anchored then
		self.nextHop = self.t + rng:float(0.9, 1.6)
		local dir
		if self.target then
			dir = Util.flatUnit(S.Entities.position(self.target) - root.Position)
		else
			dir = rng:flatDir()
		end
		local size = self.def.slime.size
		root.AssemblyLinearVelocity = dir * (self.def.speed or 14) * 1.6 + Vector3.new(0, 38 + size * 2, 0)
		root.AssemblyAngularVelocity = Vector3.new(rng:float(-3, 3), 0, rng:float(-3, 3))
		Net.fireAll("FX", "Squish", { target = e.model })
	end
	-- contact damage
	if self.target and self.t - self.lastContact > 0.8 then
		local tp = S.Entities.position(self.target)
		if (tp - root.Position).Magnitude < self.def.slime.size * 0.6 + 2.5 then
			self.lastContact = self.t
			S.Combat.hit(e, self.target, { dmg = e.dmg, kb = Util.flatUnit(tp - root.Position) * 26 + Vector3.new(0, 14, 0), attackType = "normal", kind = "slime", pos = tp })
		end
	end
end

function Slime:onHit(attacker, info)
	if attacker then
		self.target = attacker
	end
end

function Slime:onParried(by)
	local e = self.e
	if e.root and not e.root.Anchored then
		e.root.AssemblyLinearVelocity = Util.flatUnit(e.root.Position - S.Entities.position(by)) * 60 + Vector3.new(0, 30, 0)
	end
	self.nextHop = self.t + 1.5
end

function Slime:onDeath()
	local e = self.e
	local s = self.def.slime
	local p = e.root.Position
	Net.fireAll("FX", "Splat", { pos = p, color = s.color, size = s.size })
	if s.splits and s.splits > 0 then
		for i = 1, s.splits do
			task.delay(0.05 * i, function()
				AI.spawn("SlimeSmall", CFrame.new(p + Vector3.new(rng:float(-3, 3), 2, rng:float(-3, 3))), { level = e.level, tags = e.tags })
			end)
		end
	end
	task.defer(function()
		if e.model then
			e.model:Destroy()
		end
	end)
end

function Slime:destroy() end

local function buildSlime(def, level)
	local s = def.slime
	local model = Instance.new("Model")
	model.Name = def.name
	local body = Instance.new("Part")
	body.Name = "HumanoidRootPart"
	body.Size = Vector3.new(s.size, s.size * 0.85, s.size)
	body.Color = s.color
	body.Material = Enum.Material.Glass
	body.Transparency = 0.25
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.CustomPhysicalProperties = PhysicalProperties.new(0.6, 0.6, 0.3)
	body.Parent = model
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(s.size, s.size, s.size) * 0.35
	core.Color = Util.shade(s.color, 0.5)
	core.Material = Enum.Material.Neon
	core.CanCollide = false
	core.Massless = true
	core.CFrame = body.CFrame
	core.Parent = model
	local w = Instance.new("WeldConstraint")
	w.Part0 = body
	w.Part1 = core
	w.Parent = core
	for _, x in { -1, 1 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Size = Vector3.new(0.35, 0.5, 0.1) * (s.size / 4)
		eye.Color = Color3.new(0.05, 0.05, 0.05)
		eye.CanCollide = false
		eye.Massless = true
		eye.CFrame = body.CFrame * CFrame.new(x * s.size * 0.18, s.size * 0.12, -s.size / 2 - 0.02)
		eye.Parent = model
		local w2 = Instance.new("WeldConstraint")
		w2.Part0 = body
		w2.Part1 = eye
		w2.Parent = eye
	end
	local att = Instance.new("Attachment")
	att.Name = "RootAttachment"
	att.Parent = body
	model.PrimaryPart = body
	model:SetAttribute("Blood", def.blood)
	return model
end

-- ================================================================== FLYER BRAIN
-- Birds and floating spirits/gazers: an AlignPosition holds them in the air (the
-- humanoid platform-stands). They circle the target, dive, spit and blast. Every
-- goal is clamped to the floor, the ceiling and the walls: flyers never phase
-- through the level.
local Flyer = setmetatable({}, { __index = Melee })
Flyer.__index = Flyer
AI.types.flyer = Flyer
AI.types.floater = Flyer
AI.Flyer = Flyer

function Flyer.new(e, opts)
	local self = Melee.new(e, opts)
	setmetatable(self, Flyer)
	local def = e.def
	local sc = e.model:GetScale()
	self.floater = def.ai == "floater"
	self.hoverH = (def.hover or 10) * (if self.floater then 1 else math.clamp(sc, 0.6, 1.4))
	self.orbitA = rng:angle()
	self.baseSpeed = (def.speed or 18) * 1.1
	local att = e.root:FindFirstChild("RootAttachment")
	local ap = Instance.new("AlignPosition")
	ap.Name = "FlyAlign"
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.MaxForce = 1e7
	ap.MaxVelocity = self.baseSpeed
	ap.Responsiveness = if self.floater then 9 else 14
	ap.Position = e.root.Position + Vector3.new(0, self.hoverH * 0.5, 0)
	ap.Parent = e.root
	self.ap = ap
	e.hum.PlatformStand = true
	if self.ao then
		self.ao.Enabled = true
		self.ao.CFrame = CFrame.lookAt(Vector3.zero, Util.flatUnit(e.root.CFrame.LookVector))
	end
	return self
end

function Flyer:unface()
	-- flyers always stay upright
	if self.ao then
		self.ao.Enabled = true
	end
end

function Flyer:goTo(goal: Vector3)
	local my = self:pos()
	local params = AI.geoParams()
	local sc = self.e.model:GetScale()
	-- keep clear of the floor below the goal and of the ceiling above us
	local down = workspace:Raycast(goal + Vector3.new(0, 1, 0), Vector3.new(0, -80, 0), params)
	local minY = if down then down.Position.Y + (if self.floater then 2.4 else 4) * sc else goal.Y
	local up = workspace:Raycast(my, Vector3.new(0, 70, 0), params)
	local maxY = if up then up.Position.Y - 3 * sc else math.huge
	local y = math.clamp(goal.Y, minY, math.max(minY, maxY))
	goal = Vector3.new(goal.X, y, goal.Z)
	-- never aim through a wall
	local d = goal - my
	if d.Magnitude > 0.5 then
		local hit = workspace:Raycast(my, d, params)
		if hit then
			goal = hit.Position + hit.Normal * (2.5 * sc)
		end
	end
	self.ap.Position = goal
end

function Flyer:moveTo(p: Vector3)
	self:goTo(p + Vector3.new(0, self.hoverH, 0))
end

function Flyer:wander(dt: number)
	self.orbitA += dt * 0.45
	self:goTo(self.home + Vector3.new(math.cos(self.orbitA) * 9, self.hoverH, math.sin(self.orbitA) * 9))
end

function Flyer:think(dt: number)
	if self.t >= self.nextScan then
		self.nextScan = self.t + 0.45
		self:scan()
	end
	local target = self.target
	if not target then
		self:wander(dt)
		return
	end
	local my = self:pos()
	local tp = S.Entities.position(target)
	local dist = (tp - my).Magnitude
	local atk = self:chooseAttack(dist)
	if atk then
		local ranged = atk.kind == "projectile" or atk.kind == "aoe"
		if (ranged and (atk.kind ~= "projectile" or self:hasLOS(tp))) or atk.lunge or dist <= atk.range then
			if atk.kind ~= "aoe" or dist <= (atk.aoe or 10) + 4 then
				self:startAction(atk)
				return
			end
		end
	end
	if self.t > self.strafeFlip then
		self.strafeFlip = self.t + rng:float(2, 4)
		if rng:chance(0.4) then
			self.strafe = -self.strafe
		end
	end
	self.orbitA += dt * (if self.floater then 0.55 else 1.1) * self.strafe
	local r = if self.floater then 11 else 15
	self:goTo(tp + Vector3.new(math.cos(self.orbitA) * r, self.hoverH, math.sin(self.orbitA) * r))
	self:face(tp)
end

function Flyer:stepAction(dt: number)
	local a = self.action
	local atk = a.atk
	a.t += dt * (self.speedMult or 1)
	local my = self:pos()
	local alive = a.target and S.Entities.isAlive(a.target)
	if a.t < atk.w and alive then
		local tp = S.Entities.position(a.target)
		self:face(tp)
		a.dir = Util.flatUnit(tp - my)
		if not atk.lunge then
			self.ap.Position = my
		end
	end
	if atk.lunge and a.t >= atk.w * 0.8 and a.t < atk.w + atk.a + 0.25 then
		if not a.diveAt then
			a.diveAt = if alive then S.Entities.position(a.target) + Vector3.new(0, 0.5, 0) else my
			self.ap.MaxVelocity = atk.lunge
			self.ap.Responsiveness = 60
		end
		-- dive straight at where the target stood (clamped to the geometry)
		local d = a.diveAt - my
		local hit = workspace:Raycast(my, d, AI.geoParams())
		self.ap.Position = if hit then hit.Position + hit.Normal * 2 else a.diveAt
	end
	local strikeAt = atk.w + (if atk.lunge then atk.a * 0.6 else 0)
	if not a.struck and a.t >= strikeAt then
		a.struck = true
		self:strike(atk, a)
	end
	if a.t >= atk.w + atk.a + atk.r then
		self.ap.MaxVelocity = self.baseSpeed
		self.ap.Responsiveness = if self.floater then 9 else 14
		self.action = nil
		self:setAct(nil)
		dropToken(self)
	end
end

function Flyer:onDeath()
	Melee.onDeath(self)
	if self.ap then
		self.ap:Destroy()
	end
end

-- ================================================================== RESCUE
-- A monster stuck inside the level geometry (or fallen out of it) is put back on
-- its last good spot. v3 bug: one unreachable monster kept a floor locked forever.
local geo = RaycastParams.new()
geo.FilterType = Enum.RaycastFilterType.Exclude
geo.IgnoreWater = true
local geoAt = -10
function AI.geoParams(): RaycastParams
	if os.clock() - geoAt > 0.5 then
		geoAt = os.clock()
		local list = {}
		for _, o in S.Entities.list do
			if o.model then
				table.insert(list, o.model)
			end
		end
		for _, m in CollectionService:GetTagged("Rig") do
			table.insert(list, m)
		end
		local fx = workspace:FindFirstChild("FX")
		if fx then
			table.insert(list, fx)
		end
		geo.FilterDescendantsInstances = list
	end
	return geo
end

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
function AI.insideGeometry(p: Vector3, size: number?): boolean
	overlap.FilterDescendantsInstances = AI.geoParams().FilterDescendantsInstances
	local parts = workspace:GetPartBoundsInBox(CFrame.new(p), Vector3.one * (size or 0.8), overlap)
	for _, part in parts do
		if part.CanCollide and part.Anchored and part.Transparency < 1 then
			return true
		end
	end
	return false
end

function AI.rescue(b)
	local e = b.e
	local root = e.root
	if not root or not root.Parent or root.Anchored or e.frozen or e.dead then
		return
	end
	local p = root.Position
	local inside = AI.insideGeometry(p)
	local hum = e.hum
	local standing = b.ap ~= nil or (hum and hum.FloorMaterial ~= Enum.Material.Air)
	if not inside and standing then
		b.goodPos = p
	end
	b.goodPos = b.goodPos or b.home
	b.stuckChecks = if inside then (b.stuckChecks or 0) + 1 else 0
	local fell = b.goodPos and p.Y < b.goodPos.Y - 50
	if b.goodPos and (b.stuckChecks >= 2 or fell) then
		b.stuckChecks = 0
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(b.goodPos + Vector3.new(0, 0.5, 0)) * root.CFrame.Rotation
		Net.fireAll("FX", "Teleport", { from = p, to = b.goodPos, color = Color3.fromRGB(200, 200, 210) })
	end
end

-- ================================================================== SPAWN
function AI.spawn(defId, cf: CFrame, opts)
	opts = opts or {}
	local def = if type(defId) == "table" then defId else Enemies.DEFS[defId]
	if not def then
		warn("[AI] unknown enemy " .. tostring(defId))
		return nil
	end
	local level = opts.level or 1
	if S.TerrainGen then
		S.TerrainGen.ensure(cf.Position, 64)
	end
	local sc = Enemies.scaled(def, level)
	local hp = sc.hp * (opts.hpMult or 1)
	local model
	if def.ai == "slime" then
		model = buildSlime(def, level)
		model:PivotTo(cf)
	else
		local look = Enemies.resolveLook(def, opts.rng or rng)
		for k, v in opts.look or {} do
			look[k] = v
		end
		look.name = opts.name or def.name
		look.health = hp
		look.walkSpeed = def.speed
		look.blood = def.blood
		model = Rig.build(look)
		local wk = def.weapon
		if type(wk) == "table" then
			wk = (opts.rng or rng):pick(wk)
		end
		if wk then
			Rig.hold(model, Weapons.npcModel(wk))
		end
		if opts.weaponItem then
			Rig.hold(model, Weapons.buildModel(opts.weaponItem))
		end
		model:PivotTo(cf + Vector3.new(0, model:GetScale() * 0.2, 0))
	end
	model.Parent = opts.parent or AI.folder()
	local root = model.PrimaryPart
	if root and not root.Anchored then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	local e = S.Entities.new(model, {
		kind = "npc",
		team = opts.team or def.team or "monster",
		def = def,
		name = opts.name or def.name,
		level = level,
		dmg = sc.dmg * (opts.dmgMult or 1),
		posture = def.posture or (60 + hp * 0.15),
		blood = def.blood,
		xp = sc.xp,
		gold = def.gold,
		boss = def.boss or opts.boss,
		miniboss = def.miniboss or opts.miniboss,
		poise = def.poise,
		armor = def.armor,
		tags = opts.tags or {},
		hp = if def.ai == "slime" then hp else nil,
		hostile = opts.hostile,
		radius = if def.ai == "slime" then def.slime.size * 0.6 else nil,
		noDrop = opts.noDrop,
	})
	model:SetAttribute("Level", level)
	model:SetAttribute("DisplayName", e.name)
	if def.ai == "slime" then
		model:SetAttribute("MaxHp", hp)
		model:SetAttribute("Hp", hp)
	end
	local brainClass = opts.brain or AI.types[def.ai] or Melee
	if def.ai == "ranged" or def.ai == "caster" then
		brainClass = opts.brain or Melee
	end
	local ok, brain = pcall(brainClass.new, e, opts)
	if ok then
		e.brain = brain
		brain.nextThink = 0
		table.insert(AI.brains, brain)
	else
		warn("[AI] brain error: " .. tostring(brain))
	end
	return e
end

function AI.spawnGroup(list, center: Vector3, radius: number, opts)
	local out = {}
	if S.TerrainGen then
		S.TerrainGen.ensure(center, radius + 64)
	end
	for _, id in list do
		local off = rng:flatDir() * rng:float(0, radius)
		local p = center + off
		local r = workspace:Raycast(p + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0))
		if r then
			p = r.Position + Vector3.new(0, 3, 0)
		end
		local e = AI.spawn(id, CFrame.new(p) * CFrame.Angles(0, rng:angle(), 0), opts)
		if e then
			table.insert(out, e)
		end
	end
	return out
end

-- Moves a scripted actor (no brain) to a point; yields until reached or timeout.
function AI.walkTo(model: Model, p: Vector3, speed: number?, timeout: number?)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	hum.WalkSpeed = speed or 12
	hum:MoveTo(p)
	local t0 = os.clock()
	while os.clock() - t0 < (timeout or 8) do
		local root = model.PrimaryPart
		if not model.Parent or not root or Util.flatDist(root.Position, p) < 2.5 then
			break
		end
		task.wait(0.1)
	end
end

-- ================================================================== SCHEDULER
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < THINK then
		return
	end
	if S.Pause and S.Pause.active then
		acc = 0
		return
	end
	local step = acc
	acc = 0
	for i = #AI.brains, 1, -1 do
		local b = AI.brains[i]
		local e = b.e
		if e.dead or not e.model or not e.model.Parent then
			table.remove(AI.brains, i)
		elseif not e.frozen then
			b.rescueT = (b.rescueT or rng:float(0, 1)) + step
			if b.rescueT >= 1 then
				b.rescueT = 0
				pcall(AI.rescue, b)
			end
			local ok, err = pcall(b.update, b, step)
			if not ok then
				warn("[AI] " .. tostring(e.name) .. ": " .. tostring(err))
				b.errors = (b.errors or 0) + 1
				if b.errors > 20 then
					table.remove(AI.brains, i)
				end
			end
		end
	end
	-- slime hp attribute for health bars
	for _, e in S.Entities.list do
		if e.hp and e.model then
			e.model:SetAttribute("Hp", e.hp)
		end
	end
end)

function AI.clear()
	AI.brains = {}
	tokens = {}
end

return AI
