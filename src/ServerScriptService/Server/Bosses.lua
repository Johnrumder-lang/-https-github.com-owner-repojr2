--!nonstrict
-- Boss brains. All build on AI.Melee (timing, facing, tokens, reactions) and add
-- phases and special attacks. Special attacks use kind = "special" with an `sp` id.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Enemies = require(Shared.Enemies)
local Util = require(Shared.Util)
local RNG = require(Shared.RNG)
local Rig = require(Shared.Rig)
local S = require(script.Parent.S)

local Bosses = {}
local rng = RNG.new(os.time() % 55555 + 1)
local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB
local atk = Enemies.atk
local A = Enemies.A

local function sp(id, anim, w, a, r, cd, weight, extra)
	local t = { id = id, sp = id, anim = anim, w = w, a = a, r = r, range = 200, arc = 360, dmg = 1, kb = 20, kind = "special", cd = cd, weight = weight }
	for k, v in extra or {} do
		t[k] = v
	end
	return t
end
Bosses.sp = sp

-- ------------------------------------------------------------------ telegraph helpers
function Bosses.circle(pos: Vector3, radius: number, t: number, color: Color3?)
	Net.fireAll("FX", "Circle", { pos = pos, radius = radius, t = t, color = color or rgb(255, 40, 40) })
end

-- The floor under a point: first whatever solid thing is right below it (tower
-- platforms, castle floors, the white arena), then the terrain, then the point.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.RespectCanCollide = true
function Bosses.groundAt(pos: Vector3): Vector3
	local ex = { S.AI.folder() }
	for _, pl in Players:GetPlayers() do
		if pl.Character then
			table.insert(ex, pl.Character)
		end
	end
	groundParams.FilterDescendantsInstances = ex
	local r = workspace:Raycast(pos + V(0, 2, 0), V(0, -90, 0), groundParams)
	if r then
		return r.Position
	end
	local p = S.World.ground(pos)
	return p or pos
end

-- Delayed AoE at a point (telegraphed).
function Bosses.blast(owner, pos: Vector3, radius: number, delay: number, dmg: number, kb: number?, color: Color3?, style: string?)
	local g = Bosses.groundAt(pos)
	Bosses.circle(g, radius, delay, color)
	task.delay(delay, function()
		if owner.dead then
			return
		end
		local t0 = os.clock()
		while S.TimeStop.active and os.clock() - t0 < 12 do
			task.wait(0.05)
		end
		Net.fireAll("FX", style or "Explosion", { pos = g, radius = radius, color = color })
		S.Combat.aoe(owner, g, radius, { dmg = dmg, kbPower = kb or 35, kbUp = 30, attackType = "aoe", kind = "blast", posture = 20 })
	end)
end

-- Sweeping laser from `origin` rotating yaw0 -> yaw1 over dur. Hits players within `width`.
function Bosses.laser(owner, getOrigin, yaw0: number, yaw1: number, dur: number, len: number, dmg: number, height: number?, color: Color3?)
	local o = getOrigin()
	Net.fireAll("FX", "Laser", { from = o, yaw0 = yaw0, yaw1 = yaw1, dur = dur, len = len, color = color or rgb(255, 40, 60), height = height })
	task.spawn(function()
		local t = 0
		local hitSet = {}
		local last = os.clock()
		while t < dur and not owner.dead do
			local now = os.clock()
			local dt = now - last
			last = now
			if not S.TimeStop.active then
				t += dt
			end
			local yaw = Util.lerp(yaw0, yaw1, t / dur)
			local origin = getOrigin()
			local dir = V(-math.sin(yaw), 0, -math.cos(yaw))
			for _, e in S.Entities.players() do
				if not hitSet[e] then
					local p = S.Entities.position(e)
					local rel = p - origin
					local along = rel:Dot(dir)
					if along > 0 and along < len then
						local lateral = (rel - dir * along)
						local flatLat = V(lateral.X, 0, lateral.Z).Magnitude
						local dy = math.abs(p.Y - (origin.Y + (height or 0)))
						if flatLat < 3 and dy < 4 then
							hitSet[e] = true
							S.Combat.hit(owner, e, { dmg = dmg, kb = dir * 40 + V(0, 20, 0), attackType = "heavy", kind = "laser", pos = p })
						end
					end
				end
			end
			task.wait(0.03)
		end
	end)
end

-- ------------------------------------------------------------------ phased melee boss
local Phased = setmetatable({}, { __index = function(t, k)
	return S.AI.Melee[k]
end })
Phased.__index = Phased
Bosses.Phased = Phased

function Bosses.makePhased(e, opts, phases)
	local base = S.AI.Melee.new(e, opts)
	local self = setmetatable(base, Phased)
	self.phases = phases or {}
	self.phaseIndex = 1
	self.extraTokens = 1
	return self
end

function Phased:onHit(attacker, info)
	S.AI.Melee.onHit(self, attacker, info)
	local hp, max = S.Entities.health(self.e)
	local ph = self.phases[self.phaseIndex]
	if ph and hp / max <= ph.at then
		self.phaseIndex += 1
		task.spawn(ph.fn, self)
	end
	if S.Director then
		S.Director.bossHp(self.e)
	end
end

function Phased:enrage(mult: number, text: string?)
	self.speedMult = (self.speedMult or 1) * mult
	self.dmgMult = (self.dmgMult or 1) * (1 + (mult - 1) * 0.8)
	Net.fireAll("FX", "Shockwave", { pos = self:pos() - V(0, 3, 0), radius = 24, color = rgb(255, 60, 60) })
	if text then
		Net.fireAll("FX", "Shout", { target = self.e.model, text = text, dur = 3 })
	end
end

-- Swaps an entity's brain (keeps the scheduler slot, drops the old facing constraint).
function Bosses.replaceBrain(e, newBrain)
	local old = e.brain
	if old and old ~= newBrain and old.ao and old.ao ~= newBrain.ao then
		old.ao:Destroy()
	end
	local idx = table.find(S.AI.brains, old)
	e.brain = newBrain
	if idx then
		S.AI.brains[idx] = newBrain
	else
		table.insert(S.AI.brains, newBrain)
	end
	return newBrain
end

-- ------------------------------------------------------------------ spawn helpers
function Bosses.spawn(defOrId, cf: CFrame, level: number, opts)
	opts = opts or {}
	local e = S.AI.spawn(defOrId, cf, { level = level, tags = opts.tags or { boss = true }, aggro = opts.aggro or 400, leash = 2000, noDrop = opts.noDrop, name = opts.name, hpMult = opts.hpMult, look = opts.look })
	return e
end

-- Wraps an existing entity's brain in phases.
function Bosses.phase(e, phases, opts)
	local b = Bosses.makePhased(e, opts or { aggro = 400, leash = 2000 }, phases)
	return Bosses.replaceBrain(e, b)
end

-- ================================================================== WARDEN / CHAMPION / LAND BOSSES
function Bosses.warden(cf: CFrame, level: number)
	local e = Bosses.spawn("PitWarden", cf, level, { tags = { boss = true, pit = true } })
	Bosses.phase(e, {
		{ at = 0.6, fn = function(b)
			b:enrage(1.15, "YOU WILL ROT DOWN HERE!")
			for _ = 1, 2 do
				b.cds = {}
			end
		end },
		{ at = 0.3, fn = function(b)
			b:enrage(1.2, "RISE, MY CHILDREN!")
			for i = 1, 4 do
				local off = CFrame.Angles(0, i * 1.57, 0) * V(0, 0, 16)
				S.AI.spawn("Crawler", CF(b:pos() + off), { level = level, tags = { pit = true }, aggro = 300 })
			end
		end },
	})
	return e
end

function Bosses.champion(cf: CFrame, level: number)
	local e = Bosses.spawn("ArenaChampion", cf, level, { tags = { boss = true, arena = true } })
	Bosses.phase(e, {
		{ at = 0.5, fn = function(b)
			b:enrage(1.25, "BRAMORR DOES NOT FALL!")
		end },
	})
	return e
end

function Bosses.landBoss(baseId: string, cf: CFrame, level: number, name: string?)
	local def = Enemies.elite(baseId, rng)
	def.hp = Enemies.DEFS[baseId].hp * 14
	def.boss = true
	def.miniboss = false
	def.name = name or def.name
	def.xp = Enemies.DEFS[baseId].xp * 25
	table.insert(def.attacks, A.stomp)
	local e = Bosses.spawn(def, cf, level, { tags = { boss = true, landboss = true } })
	Bosses.phase(e, {
		{ at = 0.66, fn = function(b)
			b:enrage(1.15, "You are strong... but not enough!")
		end },
		{ at = 0.33, fn = function(b)
			b:enrage(1.2, "ENOUGH!")
			for i = 1, 3 do
				S.AI.spawn(def.baseId, CF(b:pos() + V(rng:float(-14, 14), 2, rng:float(-14, 14))), { level = level, tags = { landboss = true }, aggro = 300 })
			end
		end },
	})
	return e
end

-- ================================================================== ARCHMAGE
local Archmage = setmetatable({}, { __index = function(t, k)
	return S.AI.Melee[k]
end })
Archmage.__index = Archmage
Bosses.Archmage = Archmage

Bosses.ARCHMAGE_DEF = {
	name = "Archmage", team = "human", blood = "red", hp = 5200, dmg = 34, speed = 18, aggro = 400, xp = 1500, gold = { 300, 400 }, ai = "caster", boss = true, keepAway = 26, posture = 700,
	look = { outfit = "archmage", race = "Elf", shirt = rgb(50, 40, 110), accent = rgb(240, 210, 110), hair = rgb(230, 230, 240), hairStyle = "long", mood = "smug" },
	weapon = "staff",
	attacks = {
		sp("Missiles", "Cast", 0.6, 0.2, 0.5, 1.2, 3),
		sp("Bubble", "CastUp", 0.5, 0.3, 0.5, 5, 2),
		sp("Meteors", "CastUp", 0.9, 0.4, 0.8, 9, 1.5),
		sp("Beam", "Cast", 0.8, 1.8, 0.6, 10, 1.2),
		sp("Mirror", "Teleport", 0.6, 0.2, 0.6, 20, 0.8),
		sp("Blink", "Teleport", 0.2, 0.1, 0.2, 4, 1.5),
	},
}

function Bosses.archmage(cf: CFrame, level: number, name: string, roomCenter: Vector3, roomRadius: number)
	local def = table.clone(Bosses.ARCHMAGE_DEF)
	def.name = name
	local e = Bosses.spawn(def, cf, level, { tags = { boss = true, castle = true }, name = name })
	local b = S.AI.Melee.new(e, { aggro = 400, leash = 2000 })
	setmetatable(b, Archmage)
	b.room = roomCenter
	b.roomR = roomRadius
	b.phase2 = false
	Bosses.replaceBrain(e, b)
	e.model:SetAttribute("Pose", "Float")
	-- hover
	local att = e.root:FindFirstChild("RootAttachment")
	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.MaxForce = 1e6
	ap.Responsiveness = 12
	ap.Position = e.root.Position + V(0, 5, 0)
	ap.Parent = e.root
	b.ap = ap
	e.hum.PlatformStand = true
	return e
end

function Archmage:think(dt)
	if self.t >= self.nextScan then
		self.nextScan = self.t + 0.4
		self:scan()
	end
	local target = self.target
	if not target then
		return
	end
	local my = self:pos()
	local tp = S.Entities.position(target)
	self:face(tp)
	-- keep distance, circle around the room
	local toMe = Util.flatUnit(my - tp)
	local ang = math.atan2(toMe.X, toMe.Z) + 0.4 * dt
	local want = tp + V(math.sin(ang), 0, math.cos(ang)) * 24
	if self.room and (want - self.room).Magnitude > self.roomR then
		want = self.room + (want - self.room).Unit * self.roomR
	end
	self.ap.Position = V(want.X, (self.room and self.room.Y or tp.Y) + 7 + math.sin(self.t * 1.3) * 1.5, want.Z)
	local hp, max = S.Entities.health(self.e)
	if not self.phase2 and hp / max < 0.5 then
		self.phase2 = true
		self.speedMult = 1.35
		Net.fireAll("FX", "Shout", { target = self.e.model, text = "You. Are. NOTHING!", dur = 3 })
		Net.fireAll("FX", "Shockwave", { pos = my, radius = 30, color = rgb(160, 120, 255) })
		self.cds = {}
	end
	local a = self:chooseAttack((tp - my).Magnitude)
	if a then
		self:startAction(a)
	end
end

function Archmage:special(a, act)
	local e = self.e
	local target = act.target
	if not target or not S.Entities.isAlive(target) then
		return
	end
	local my = self:pos()
	local tp = S.Entities.position(target)
	local dmg = e.dmg * (self.dmgMult or 1)
	if a.sp == "Missiles" then
		S.Projectiles.fire(e, my + V(0, 2, 0), (tp - my).Unit * 55, { speed = 55, gravity = 0, size = 1.1, color = rgb(160, 120, 255), style = "orb", homing = 2.4, count = if self.phase2 then 7 else 5, spread = 16 }, { dmg = dmg * 0.55, kbPower = 12, shooter = e }, target)
	elseif a.sp == "Bubble" then
		Bosses.blast(e, tp, 8, 1.1, dmg * 1.2, 20, rgb(190, 120, 255), "Bubble")
	elseif a.sp == "Meteors" then
		for i = 1, if self.phase2 then 9 else 6 do
			local off = V(rng:float(-18, 18), 0, rng:float(-18, 18))
			if i == 1 then
				off = Vector3.zero
			end
			task.delay(i * 0.12, function()
				Bosses.blast(e, tp + off, 7, 1.3, dmg * 1.1, 40, rgb(255, 120, 40), "Explosion")
			end)
		end
	elseif a.sp == "Beam" then
		local look = Util.flatUnit(tp - my)
		local yaw = math.atan2(-look.X, -look.Z)
		Bosses.laser(e, function()
			return self:pos()
		end, yaw + 1.1, yaw - 1.1, a.a, 90, dmg * 1.4, -4, rgb(170, 130, 255))
	elseif a.sp == "Mirror" then
		for i = 1, 2 do
			local def = {
				name = "Illusion", team = "human", blood = "purple", hp = 60, dmg = e.dmg * 0.4, speed = 18, aggro = 300, xp = 0, ai = "caster", keepAway = 24,
				look = Bosses.ARCHMAGE_DEF.look, weapon = "staff",
				attacks = { atk(A.bolt, { cd = 1.6 }) },
			}
			local off = CFrame.Angles(0, i * math.pi, 0) * V(0, 0, 16)
			local ill = S.AI.spawn(def, CF(my + off), { level = e.level, tags = { castle = true }, noDrop = true, aggro = 300 })
			if ill and ill.model then
				ill.model:SetAttribute("Pose", "Float")
				task.delay(20, function()
					if S.Entities.isAlive(ill) then
						S.Combat.kill(ill, nil, {})
					end
				end)
			end
			Net.fireAll("FX", "Teleport", { from = my, to = my + off, color = rgb(170, 120, 255) })
		end
	elseif a.sp == "Blink" then
		local dir = rng:flatDir()
		local dest = tp + dir * 26
		if self.room and (dest - self.room).Magnitude > self.roomR then
			dest = self.room + (dest - self.room).Unit * (self.roomR - 4)
		end
		dest = V(dest.X, (self.room and self.room.Y or tp.Y) + 7, dest.Z)
		Net.fireAll("FX", "Teleport", { from = my, to = dest, color = rgb(170, 120, 255) })
		e.root.CFrame = CF(dest)
		self.ap.Position = dest
	end
end

function Archmage:onHit(attacker, info)
	if attacker then
		self.target = attacker
	end
	if S.Director then
		S.Director.bossHp(self.e)
	end
end

function Archmage:onParried(by)
	self.e.stunUntil = os.clock() + 0.8
end

-- ================================================================== THE HOLLOW (the other you)
local Hollow = setmetatable({}, { __index = function(t, k)
	return S.AI.Melee[k]
end })
Hollow.__index = Hollow
Bosses.Hollow = Hollow

function Bosses.hollowDef(level: number)
	return {
		name = "???", team = "monster", blood = "void", hp = 9000, dmg = 40, speed = 30, aggro = 500, xp = 5000, gold = { 800, 1200 }, ai = "melee", boss = true, parryChance = 0.45, posture = 900, armor = 0.1,
		look = { outfit = "cloak", race = "Human", shirt = rgb(10, 10, 14), mood = "hollow", glowEye = rgb(255, 20, 30), glow = rgb(255, 20, 30) },
		attacks = {
			atk(A.slash, { w = 0.24, a = 0.1, r = 0.22, range = 8, dmg = 0.8, id = "H1" }),
			atk(A.backslash, { w = 0.2, a = 0.1, r = 0.22, range = 8, dmg = 0.8, id = "H2" }),
			atk(A.overhead, { w = 0.34, a = 0.12, r = 0.3, range = 8.5, dmg = 1.1, id = "H3", cd = 0.6 }),
			atk(A.thrust, { kind = "lunge", lunge = 120, range = 30, minRange = 9, w = 0.32, a = 0.18, r = 0.3, dmg = 1.2, id = "Dash", cd = 2.5 }),
			sp("Behind", "Teleport", 0.12, 0.1, 0.1, 4, 1.5),
			sp("Waves", "SlashR", 0.4, 0.15, 0.4, 6, 1.2),
			sp("Leap", "Slam", 0.7, 0.2, 0.6, 8, 1),
			atk(A.sweep, { w = 0.45, range = 10, dmg = 1.0, id = "HSweep", cd = 5 }),
		},
	}
end

function Bosses.hollow(cf: CFrame, level: number)
	local def = Bosses.hollowDef(level)
	local e = Bosses.spawn(def, cf, level, { tags = { boss = true, final = true }, name = "???" })
	local b = S.AI.Melee.new(e, { aggro = 500, leash = 3000 })
	setmetatable(b, Hollow)
	b.aura = 0
	b.extraTokens = 2
	b.stopsUsed = 0
	Bosses.replaceBrain(e, b)
	e.minHealth = 1
	e.model:SetAttribute("Aura", 0)
	return e
end

function Hollow:gainAura(n: number)
	local before = self.aura
	self.aura = math.clamp(self.aura + n, 0, 100)
	self.speedMult = 1 + self.aura / 180
	self.dmgMult = 1 + self.aura / 250
	self.e.model:SetAttribute("Aura", self.aura)
	for _, th in { 25, 50, 75, 100 } do
		if before < th and self.aura >= th then
			Net.fireAll("FX", "Text", { pos = self:pos() + V(0, 6, 0), text = "+" .. (th * 40) .. " AURA", color = rgb(255, 40, 60), size = 1.4 })
			Net.fireAll("FX", "Shockwave", { pos = self:pos() - V(0, 3, 0), radius = 12, color = rgb(40, 0, 10) })
		end
	end
end

function Hollow:afterThink(dt)
	local hp, max = S.Entities.health(self.e)
	local frac = hp / max
	-- two time stops of his own
	if (self.stopsUsed == 0 and frac < 0.6) or (self.stopsUsed == 1 and frac < 0.25) then
		if not S.TimeStop.active and self.target then
			self.stopsUsed += 1
			self:timeStop()
		end
	end
end

function Hollow:timeStop()
	local e = self.e
	local target = self.target
	Net.fireAll("FX", "Shout", { target = e.model, text = "My turn.", dur = 2 })
	if not S.TimeStop.start(e, 3, { scripted = true, inverted = true }) then
		return
	end
	self.scripted = true
	task.spawn(function()
		task.wait(0.6)
		if target and S.Entities.isAlive(target) then
			local tp = S.Entities.position(target)
			local look = Util.flatUnit(tp - self:pos())
			local dest = tp - look * 4
			Net.fireAll("FX", "Teleport", { from = self:pos(), to = dest, color = rgb(255, 20, 40) })
			e.root.CFrame = CFrame.lookAt(dest, V(tp.X, dest.Y, tp.Z))
			for i = 1, 4 do
				self:playAct(({ "SlashR", "SlashL", "SlashR", "Overhead" })[i], 0.08, 0.1, 0.12)
				S.Combat.hit(e, target, { dmg = e.dmg * 0.55 * (self.dmgMult or 1), kb = look * 22 + V(0, 12, 0), attackType = "true", kind = "melee", pos = tp })
				task.wait(0.35)
			end
		end
		task.wait(0.4)
		S.TimeStop.stop()
		self.scripted = false
		self:gainAura(15)
	end)
end

function Hollow:special(a, act)
	local e = self.e
	local target = act.target
	if not target or not S.Entities.isAlive(target) then
		return
	end
	local my = self:pos()
	local tp = S.Entities.position(target)
	local dmg = e.dmg * (self.dmgMult or 1)
	if a.sp == "Behind" then
		local tl = if target.root then target.root.CFrame.LookVector else V(0, 0, -1)
		local dest = tp - Util.flatUnit(tl) * 5
		Net.fireAll("FX", "Teleport", { from = my, to = dest, color = rgb(255, 20, 40) })
		e.root.CFrame = CFrame.lookAt(dest, V(tp.X, dest.Y, tp.Z))
		self.cds.H1 = 0
		self.cds.H3 = 0
	elseif a.sp == "Waves" then
		for i = 0, 2 do
			task.delay(i * 0.18, function()
				if e.dead or not e.root.Parent then
					return
				end
				local look = Util.flatUnit(S.Entities.position(target) - self:pos())
				S.Projectiles.fire(e, self:pos() + V(0, 1, 0), look * 95, { size = 5, color = rgb(255, 30, 50), style = "slash", gravity = 0, life = 1.2 }, { dmg = dmg * 0.7, kbPower = 26, shooter = e })
			end)
		end
	elseif a.sp == "Leap" then
		local dest = tp
		Net.fireAll("FX", "Teleport", { from = my, to = dest + V(0, 30, 0), color = rgb(255, 20, 40) })
		e.root.CFrame = CF(dest + V(0, 30, 0))
		Bosses.blast(e, dest, 12, 0.6, dmg * 1.3, 45, rgb(255, 30, 50), "Shockwave")
	end
end

function Hollow:onHit(attacker, info)
	S.AI.Melee.onHit(self, attacker, info)
	self:gainAura(-2)
	if S.Director then
		S.Director.bossHp(self.e)
	end
end

function Hollow:tryDefend(attacker, info)
	local r = S.AI.Melee.tryDefend(self, attacker, info)
	if r then
		self:gainAura(6)
		-- instant counter
		self.cds.H1 = 0
		self.cds.H2 = 0
	end
	return r
end

function Hollow:onParried(by, info)
	S.AI.Melee.onParried(self, by, info)
	self.e.stunUntil = os.clock() + 0.55
	self:gainAura(-6)
end

-- ================================================================== THE ABNORMALITY
local Abn = setmetatable({}, { __index = function(t, k)
	return S.AI.Melee[k]
end })
Abn.__index = Abn
Bosses.Abnormality = Abn

function Bosses.abnormality(cf: CFrame, level: number)
	local def = {
		name = "THE STRONGEST ABNORMALITY", team = "monster", blood = "void", hp = 16000, dmg = 46, speed = 16, aggro = 800, xp = 9000, gold = { 1500, 2000 }, ai = "melee", boss = true, poise = true, posture = 99999, armor = 0.35,
		look = { race = "Monster", outfit = "cloak", shirt = rgb(4, 4, 6), skin = rgb(6, 4, 8), mood = "monster", glow = rgb(255, 0, 30), glowEye = rgb(255, 0, 30), scale = 4.2, extras = { "horns", "wings" } },
		attacks = {
			sp("Grab", "Grab", 0.95, 0.25, 0.9, 5, 1.6),
			atk(A.sweep, { id = "ASweep", range = 30, arc = 220, w = 1.0, a = 0.25, r = 0.8, dmg = 1.2, kb = 50, cd = 4, weight = 2 }),
			sp("Laser", "Roar", 1.0, 2.2, 0.8, 9, 1.4),
			sp("Rings", "Slam", 1.0, 0.2, 1.0, 7, 1.6),
			sp("Flames", "CastUp", 0.8, 0.3, 0.8, 8, 1.2),
			atk(A.slam, { id = "ASlam", range = 22, shock = 26, w = 1.1, dmg = 1.3, kb = 60, cd = 3, weight = 2 }),
		},
	}
	local e = Bosses.spawn(def, cf, level, { tags = { boss = true, final = true } })
	local b = S.AI.Melee.new(e, { aggro = 800, leash = 3000 })
	setmetatable(b, Abn)
	b.extraTokens = 3
	b.attacksSinceCore = 0
	Bosses.replaceBrain(e, b)
	e.minHealth = 1
	e.radius = 7
	-- black flames
	local torso = e.model:FindFirstChild("Torso")
	if torso then
		local fx = Instance.new("ParticleEmitter")
		fx.Texture = "rbxasset://textures/particles/fire_main.dds"
		fx.Color = ColorSequence.new(rgb(20, 0, 10), rgb(0, 0, 0))
		fx.LightEmission = 0
		fx.LightInfluence = 0
		fx.Rate = 60
		fx.Lifetime = NumberRange.new(0.6, 1.2)
		fx.Speed = NumberRange.new(6, 14)
		fx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 0) })
		fx.Transparency = NumberSequence.new(0.1, 1)
		fx.SpreadAngle = Vector2.new(40, 40)
		fx.Acceleration = V(0, 12, 0)
		fx.Parent = torso
		local core = Instance.new("Part")
		core.Name = "Core"
		core.Size = V(3, 3, 3)
		core.Color = rgb(255, 20, 40)
		core.Material = Enum.Material.Neon
		core.CanCollide = false
		core.CanQuery = false
		core.Massless = true
		core.CFrame = torso.CFrame * CF(0, 0, -torso.Size.Z / 2 - 0.2)
		core.Parent = e.model
		local w = Instance.new("WeldConstraint")
		w.Part0 = torso
		w.Part1 = core
		w.Parent = core
		local l = Instance.new("PointLight")
		l.Color = rgb(255, 20, 40)
		l.Range = 30
		l.Brightness = 3
		l.Parent = core
		b.core = core
	end
	e.damageMult = 0.6
	return e
end

function Abn:exposeCore()
	self.exposed = true
	self.e.damageMult = 2.2
	if self.core then
		self.core.Size = V(6, 6, 6)
	end
	Net.fireAll("FX", "Text", { pos = self:pos() + V(0, 18, 0), text = "CORE EXPOSED", color = rgb(255, 60, 80), size = 1.5 })
	self.e.stunUntil = os.clock() + 4
	self.e.model:SetAttribute("Pose", "Stagger")
	task.delay(4, function()
		self.exposed = false
		self.e.damageMult = 0.6
		if self.core and self.core.Parent then
			self.core.Size = V(3, 3, 3)
		end
		if self.e.model.Parent then
			self.e.model:SetAttribute("Pose", nil)
		end
	end)
end

function Abn:special(a, act)
	local e = self.e
	local target = act.target
	if not target or not S.Entities.isAlive(target) then
		return
	end
	local my = self:pos()
	local tp = S.Entities.position(target)
	local dmg = e.dmg
	self.attacksSinceCore += 1
	if a.sp == "Grab" then
		local look = Util.flatUnit(tp - my)
		local reach = my + look * 16
		for _, p in S.Entities.players() do
			local pp = S.Entities.position(p)
			if (pp - reach).Magnitude < 14 then
				local r = S.Combat.hit(e, p, { dmg = dmg * 1.6, kb = look * 10 + V(0, 70, 0), attackType = "grab", kind = "grab", pos = pp })
				if r == "hit" or r == "queued" then
					task.delay(0.8, function()
						if S.Entities.isAlive(p) then
							S.Combat.hit(e, p, { dmg = dmg * 0.8, kb = V(0, -90, 0) + look * 30, attackType = "true", kind = "slam", pos = S.Entities.position(p) })
							Net.fireAll("FX", "Shockwave", { pos = S.Entities.position(p) - V(0, 3, 0), radius = 12, color = rgb(40, 0, 10) })
						end
					end)
				end
			end
		end
	elseif a.sp == "Laser" then
		local look = Util.flatUnit(tp - my)
		local yaw = math.atan2(-look.X, -look.Z)
		local head = e.model:FindFirstChild("Head")
		Bosses.laser(e, function()
			local h = head and head.Position or my
			local g = Bosses.groundAt(h)
			return V(h.X, g.Y + 3.5, h.Z)
		end, yaw + 1.3, yaw - 1.3, a.a, 140, dmg * 1.3, 0, rgb(255, 10, 40))
	elseif a.sp == "Rings" then
		local g = Bosses.groundAt(my)
		Net.fireAll("FX", "Ringwave", { pos = g, speed = 45, max = 90, color = rgb(255, 20, 40) })
		task.spawn(function()
			local hit = {}
			local r = 0
			while r < 90 and not e.dead do
				if not S.TimeStop.active then
					r += 45 * 0.05
				end
				for _, p in S.Entities.players() do
					if not hit[p] then
						local pp = S.Entities.position(p)
						local d = Util.flatDist(pp, g)
						local ground = Bosses.groundAt(pp)
						if math.abs(d - r) < 3 and pp.Y - ground.Y < 5 then
							hit[p] = true
							S.Combat.hit(e, p, { dmg = dmg * 0.9, kb = Util.flatUnit(pp - g) * 40 + V(0, 25, 0), attackType = "heavy", kind = "ring", pos = pp })
						end
					end
				end
				task.wait(0.05)
			end
		end)
	elseif a.sp == "Flames" then
		for _, p in S.Entities.players() do
			local pp = S.Entities.position(p)
			for i = 0, 2 do
				Bosses.blast(e, pp + V(rng:float(-6, 6), 0, rng:float(-6, 6)), 8, 0.9 + i * 0.25, dmg * 0.9, 50, rgb(30, 0, 10), "Pillar")
			end
		end
	end
	if self.attacksSinceCore >= 3 then
		self.attacksSinceCore = 0
		task.delay(1.2, function()
			if not e.dead then
				self:exposeCore()
			end
		end)
	end
end

function Abn:onHit(attacker, info)
	if attacker then
		self.target = attacker
	end
	if S.Director then
		S.Director.bossHp(self.e)
	end
end

function Abn:onParried(by)
	self.e.stunUntil = os.clock() + 0.3
end

-- ================================================================== THE GOD
local God = setmetatable({}, { __index = function(t, k)
	return S.AI.Melee[k]
end })
God.__index = God
Bosses.God = God

function Bosses.god(cf: CFrame, level: number, bible, arenaCenter: Vector3)
	local def = {
		name = bible.god, team = "monster", blood = "gold", hp = 24000, dmg = 52, speed = 22, aggro = 900, xp = 20000, gold = { 5000, 6000 }, ai = "caster", boss = true, poise = true, posture = 99999, armor = 0.3,
		look = { outfit = "robeGod", skin = rgb(255, 238, 215), hair = rgb(255, 250, 240), hairStyle = "long", beard = "long", shirt = rgb(252, 250, 244), accent = rgb(236, 190, 70), mood = "god", glow = rgb(255, 225, 120), halo = rgb(255, 230, 140), scale = 2.2 },
		attacks = {
			sp("Spears", "CastUp", 0.8, 0.3, 0.6, 3, 3),
			sp("Pillar", "Point", 0.6, 0.2, 0.5, 2.5, 3),
			sp("Smite", "Cast", 0.5, 0.2, 0.4, 2, 2.5),
			sp("Radiance", "Roar", 0.9, 0.3, 0.7, 7, 1.2),
			sp("Blink", "Teleport", 0.15, 0.1, 0.15, 3, 1.5),
			sp("Beam", "Cast", 0.8, 2.0, 0.6, 9, 1),
		},
	}
	local e = Bosses.spawn(def, cf, level, { tags = { boss = true, god = true }, name = bible.god })
	local b = S.AI.Melee.new(e, { aggro = 900, leash = 3000 })
	setmetatable(b, God)
	b.center = arenaCenter
	b.phase2 = false
	Bosses.replaceBrain(e, b)
	e.minHealth = 1
	e.radius = 4
	local att = e.root:FindFirstChild("RootAttachment")
	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.MaxForce = 1e7
	ap.Responsiveness = 10
	ap.Position = e.root.Position
	ap.Parent = e.root
	b.ap = ap
	e.hum.PlatformStand = true
	e.model:SetAttribute("Pose", "Float")
	return e
end

function God:think(dt)
	if self.t >= self.nextScan then
		self.nextScan = self.t + 0.4
		self:scan()
	end
	local target = self.target
	if not target then
		return
	end
	local my = self:pos()
	local tp = S.Entities.position(target)
	self:face(tp)
	local toMe = Util.flatUnit(my - tp)
	local ang = math.atan2(toMe.X, toMe.Z) + 0.25 * dt
	local want = tp + V(math.sin(ang), 0, math.cos(ang)) * 30
	if (want - self.center).Magnitude > 100 then
		want = self.center + (want - self.center).Unit * 100
	end
	self.ap.Position = V(want.X, self.center.Y + 10 + math.sin(self.t) * 2, want.Z)
	local a = self:chooseAttack((tp - my).Magnitude)
	if a then
		self:startAction(a)
	end
end

function God:baseSpecial(a, act)
	local e = self.e
	local target = act.target
	if not target or not S.Entities.isAlive(target) then
		return
	end
	local my = self:pos()
	local tp = S.Entities.position(target)
	local dmg = e.dmg * (self.dmgMult or 1)
	local col = if self.phase2 then rgb(20, 0, 30) else rgb(255, 230, 140)
	if a.sp == "Spears" then
		for i = 1, if self.phase2 then 16 else 10 do
			local off = V(rng:float(-28, 28), 0, rng:float(-28, 28))
			if i <= 2 then
				off = V(rng:float(-3, 3), 0, rng:float(-3, 3))
			end
			task.delay(i * 0.06, function()
				Bosses.blast(e, tp + off, 5, 1.0, dmg * 0.9, 30, col, "Pillar")
			end)
		end
	elseif a.sp == "Pillar" then
		Bosses.blast(e, tp, 11, 0.9, dmg * 1.4, 55, col, "Pillar")
	elseif a.sp == "Smite" then
		S.Projectiles.fire(e, my + V(0, 3, 0), (tp - my).Unit * 90, { speed = 90, gravity = 0, size = 1.4, color = col, style = "orb", homing = 1.5, count = if self.phase2 then 5 else 3, spread = 10 }, { dmg = dmg * 0.6, kbPower = 20, shooter = e }, target)
	elseif a.sp == "Radiance" then
		local g = Bosses.groundAt(my)
		Bosses.blast(e, g, 26, 0.9, dmg * 1.2, 70, col, "Explosion")
	elseif a.sp == "Blink" then
		local dest = tp + rng:flatDir() * 32
		if (dest - self.center).Magnitude > 100 then
			dest = self.center + (dest - self.center).Unit * 90
		end
		dest = V(dest.X, self.center.Y + 10, dest.Z)
		Net.fireAll("FX", "Teleport", { from = my, to = dest, color = col })
		e.root.CFrame = CF(dest)
		self.ap.Position = dest
	elseif a.sp == "Beam" then
		local look = Util.flatUnit(tp - my)
		local yaw = math.atan2(-look.X, -look.Z)
		Bosses.laser(e, function()
			local p = self:pos()
			return V(p.X, self.center.Y + 3.5, p.Z)
		end, yaw - 1.4, yaw + 1.4, a.a, 160, dmg * 1.3, 0, col)
	end
end

function God:onHit(attacker, info)
	if attacker then
		self.target = attacker
	end
	if S.Director then
		S.Director.bossHp(self.e)
	end
	local hp, max = S.Entities.health(self.e)
	if not self.phase2 and hp / max < 0.5 and not self.transforming then
		self.transforming = true
		if self.onPhase2 then
			task.spawn(self.onPhase2, self)
		end
	end
end

function God:becomeAntiLight()
	self.phase2 = true
	self.speedMult = 1.45
	self.dmgMult = 1.35
	self.cds = {}
	for _, d in self.e.model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name ~= "HumanoidRootPart" then
				d.Color = rgb(0, 0, 0)
				d.Material = Enum.Material.SmoothPlastic
			end
		elseif d:IsA("PointLight") then
			d.Color = rgb(40, 0, 60)
		elseif d:IsA("SurfaceGui") then
			d.Enabled = false
		end
	end
	local h = Instance.new("Highlight")
	h.FillColor = rgb(0, 0, 0)
	h.OutlineColor = rgb(255, 255, 255)
	h.FillTransparency = 0
	h.OutlineTransparency = 0.2
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = self.e.model
	table.insert(self.def.attacks, sp("Well", "CastUp", 0.8, 0.3, 0.6, 8, 1.4))
	table.insert(self.def.attacks, sp("Stop", "Teleport", 0.3, 0.2, 0.3, 25, 0.8))
end

function God:special(a, act)
	if a.sp == "Well" then
		local target = act.target
		if not target then
			return
		end
		local p = Bosses.groundAt(S.Entities.position(target) + rng:flatDir() * 10)
		Net.fireAll("FX", "Well", { pos = p, dur = 5 })
		task.spawn(function()
			local t = 0
			while t < 5 and not self.e.dead do
				for _, pl in S.Entities.players() do
					local pp = S.Entities.position(pl)
					local d = Util.flatDist(pp, p)
					if d < 40 and d > 2 then
						S.Combat.push(pl, Util.flatUnit(p - pp) * 22)
					end
					if d < 5 and not S.TimeStop.active then
						S.Combat.hit(self.e, pl, { dmg = self.e.dmg * 0.25, kb = V(0, 10, 0), attackType = "true", kind = "well", pos = pp })
					end
				end
				task.wait(0.25)
				if not S.TimeStop.active then
					t += 0.25
				end
			end
		end)
		return
	elseif a.sp == "Stop" then
		if not S.TimeStop.active and act.target then
			local target = act.target
			if S.TimeStop.start(self.e, 3, { scripted = true, inverted = true }) then
				task.spawn(function()
					task.wait(0.5)
					for i = 1, 5 do
						if S.Entities.isAlive(target) then
							local tp = S.Entities.position(target)
							Bosses.blast(self.e, tp + rng:flatDir() * rng:float(0, 4), 6, 0.01, self.e.dmg * 0.35, 20, rgb(20, 0, 30), "Pillar")
						end
						task.wait(0.35)
					end
					task.wait(0.3)
					S.TimeStop.stop()
				end)
			end
		end
		return
	end
	self:baseSpecial(a, act)
end

-- ================================================================== PRINCE (if you killed the king)
function Bosses.prince(cf: CFrame, level: number)
	local def = table.clone(Enemies.DEFS.RoyalKnight)
	def.name = "Prince Alaric"
	def.hp = 3000
	def.dmg = 32
	def.boss = true
	def.parryChance = 0.4
	def.blockChance = 0.3
	def.xp = 2500
	def.look = { outfit = "knight", race = "Human", accent = rgb(170, 30, 40), metal = rgb(230, 230, 240), mood = "angry" }
	local e = Bosses.spawn(def, cf, level, { tags = { boss = true, prince = true }, name = "Prince Alaric" })
	Bosses.phase(e, {
		{ at = 0.5, fn = function(b)
			b:enrage(1.25, "FOR MY FATHER!")
		end },
	})
	return e
end

return Bosses
