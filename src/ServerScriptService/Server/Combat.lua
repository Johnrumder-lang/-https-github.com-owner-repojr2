--!nonstrict
-- Damage, parry, block, posture, knockback, deaths. Player swings are resolved here
-- with a server-side hitbox (cone in front of the player's head).
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Weapons = require(Shared.Weapons)
local Util = require(Shared.Util)
local S = require(script.Parent.S)

local Combat = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

-- collision groups: dashing players pass through monsters (anime dash-stabs),
-- corpses never trip anybody up
local PhysicsService = game:GetService("PhysicsService")
pcall(function()
	for _, g in { "Players", "NPC", "Dashing", "Ragdoll", "PlayerBarrier" } do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(g)
		end)
	end
	PhysicsService:CollisionGroupSetCollidable("Dashing", "NPC", false)
	PhysicsService:CollisionGroupSetCollidable("Dashing", "Ragdoll", false)
	PhysicsService:CollisionGroupSetCollidable("Players", "Ragdoll", false)
	-- arena barriers stop players only
	for _, g in { "Default", "NPC", "Ragdoll" } do
		PhysicsService:CollisionGroupSetCollidable("PlayerBarrier", g, false)
	end
end)

function Combat.setGroup(model: Instance, group: string)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.CollisionGroup ~= "Ragdoll" then
			d.CollisionGroup = group
		end
	end
end

local function worldFilter()
	local list = {}
	for _, e in S.Entities.list do
		if e.model then
			table.insert(list, e.model)
		end
	end
	local fx = workspace:FindFirstChild("FX")
	if fx then
		table.insert(list, fx)
	end
	for _, m in CollectionService:GetTagged("Rig") do
		table.insert(list, m)
	end
	return list
end

function Combat.lineOfSight(a: Vector3, b: Vector3): boolean
	rayParams.FilterDescendantsInstances = worldFilter()
	local r = workspace:Raycast(a, b - a, rayParams)
	return r == nil or (r.Position - a).Magnitude >= (b - a).Magnitude - 1.5
end

-- can entity e (a player) strike o?  NPCs always, other players only in PvP
function Combat.canTarget(e, o): boolean
	if o == e or not S.Entities.isAlive(o) or o.invuln then
		return false
	end
	if o.kind == "player" then
		return S.PvP ~= nil and e ~= nil and e.kind == "player" and S.PvP.canHit(e, o)
	end
	return true
end

-- is the target in the air (for juggles / airshots)?
function Combat.airborne(o): boolean
	if o.model and o.model:GetAttribute("Ragdoll") then
		local torso = o.model:FindFirstChild("Torso") :: BasePart
		return torso ~= nil and (math.abs(torso.AssemblyLinearVelocity.Y) > 6)
	end
	if o.hum then
		local ok, fm = pcall(function()
			return o.hum.FloorMaterial
		end)
		return ok and fm == Enum.Material.Air
	end
	return false
end

-- sends style-meter events to a player
function Combat.style(player: Player?, list)
	if player and list and #list > 0 then
		Net.fire(player, "HitConfirm", { n = 0, styles = list, silent = true })
	end
end

local function fxHit(target, info, extra)
	local pos = info.pos or S.Entities.position(target)
	local dir = if info.kb and info.kb.Magnitude > 0.01 then info.kb.Unit else Vector3.new(0, 1, 0)
	local data = {
		pos = pos,
		dir = dir,
		blood = target.blood,
		dmg = extra and extra.dmg or info.dmg,
		crit = info.crit,
		hits = info.hits,
		released = info.released,
		frozen = extra and extra.frozen,
		heavy = info.heavy,
		target = target.model,
		kind = info.kind,
		element = info.element,
	}
	Net.fireAll("FX", "Hit", data)
end

-- ------------------------------------------------------------------ main entry
function Combat.hit(attacker, target, info)
	if not target or not S.Entities.isAlive(target) or target.invuln then
		return "none"
	end
	local now = os.clock()
	info.kb = info.kb or Vector3.zero
	info.dmg = info.dmg or 0
	local atype: string = info.attackType or "normal"
	local unavoidable = atype == "true"
	-- player defence
	if target.kind == "player" and attacker ~= target then
		if now < target.dashUntil and not unavoidable then
			Net.fireAll("FX", "Dodge", { pos = S.Entities.position(target) })
			return "dodged"
		end
		if atype == "sweep" and target.sliding then
			Net.fireAll("FX", "Dodge", { pos = S.Entities.position(target), text = "SLID" })
			return "slid"
		end
		local parryable = atype == "normal" or atype == "lunge" or atype == "projectile"
		if parryable and now < target.parryUntil then
			Combat.parried(attacker, target, info)
			return "parried"
		end
		if parryable and target.blocking then
			info.dmg *= Config.Player.blockReduction * (1 - (target.blockBonus or 0))
			info.kb *= 0.3
			info.blocked = true
			Net.fireAll("FX", "Block", { pos = S.Entities.position(target) + Vector3.new(0, 1.5, 0) })
		end
	end
	-- smart NPCs can parry/block players
	if target.kind == "npc" and attacker and attacker.kind == "player" and not target.frozen then
		if target.brain and target.brain.tryDefend then
			local r = target.brain:tryDefend(attacker, info)
			if r then
				return r
			end
		end
	end
	-- the giants' weak spot: strikes from behind or from above land on the nape
	if target.def and target.def.giant and attacker and attacker.kind == "player" and not info.nape then
		local tp = S.Entities.position(target)
		local ap = S.Entities.position(attacker)
		local look = if target.root then Util.flat(target.root.CFrame.LookVector) else Vector3.zAxis
		local rel = Util.flat(ap - tp)
		local sc = if target.model then target.model:GetScale() else 1
		if (rel.Magnitude > 0.1 and look.Magnitude > 0.1 and rel.Unit:Dot(look.Unit) < -0.35) or ap.Y > tp.Y + 1.5 * sc then
			info.dmg *= 2.5
			info.crit = true
			info.nape = true
			Net.fireAll("FX", "Text", { pos = tp + Vector3.new(0, 2.5 * sc, 0), text = "NAPE!", color = Color3.fromRGB(255, 80, 70), size = 1.3 })
		end
	end
	-- time stop: store the hit
	if S.TimeStop.active and S.TimeStop.affects(target) and not info.noDefer then
		info.dmg *= 1 + (info.chrono or 0)
		local n = S.TimeStop.queueHit(attacker, target, info)
		fxHit(target, info, { frozen = true, dmg = info.dmg })
		if attacker and attacker.player then
			Net.fire(attacker.player, "HitConfirm", { n = 1, frozen = true, stacked = n, heavy = info.heavy })
		end
		return "queued"
	end
	Combat.apply(attacker, target, info)
	return "hit"
end

function Combat.apply(attacker, target, info)
	if not S.Entities.isAlive(target) then
		return
	end
	local now = os.clock()
	local dmg = (info.dmg or 0) * (1 - (target.armor or 0))
	if attacker and attacker.kind == "player" and now < target.riposteUntil then
		dmg *= Config.Player.riposteMult
		info.crit = true
		target.riposteUntil = 0
	end
	if target.damageMult then
		dmg *= target.damageMult
	end
	-- posture
	if info.posture and info.posture > 0 and target.maxPosture then
		target.posture += info.posture
		target.postureHitAt = now
		if target.posture >= target.maxPosture then
			Combat.postureBreak(target)
		end
	end
	-- health
	local hp, maxHp = S.Entities.health(target)
	if target.minHealth then
		dmg = math.min(dmg, math.max(0, hp - target.minHealth))
	end
	if target.hum then
		target.hum.Health = math.max(0, hp - dmg)
	else
		target.hp = math.max(0, hp - dmg)
	end
	if attacker and info.lifesteal and info.lifesteal > 0 and attacker.hum then
		attacker.hum.Health = math.min(attacker.hum.MaxHealth, attacker.hum.Health + dmg * info.lifesteal)
	end
	info.dmg = dmg
	fxHit(target, info)
	if target.onHit then
		task.spawn(target.onHit, target, attacker, info)
	end
	if target.kind == "player" then
		Net.fire(target.player, "HitConfirm", { hurt = true, dmg = dmg, dir = info.kb, blocked = info.blocked })
	end
	local newHp = S.Entities.health(target)
	if target.kind == "player" and target.duelWith and newHp <= 1 and S.PvP then
		S.PvP.onDefeat(target, attacker, info)
		return
	end
	if newHp <= 0 then
		Combat.kill(target, attacker, info)
		return
	end
	if target.brain and target.brain.onHit then
		target.brain:onHit(attacker, info)
	end
	-- knockback. Living bodies never ragdoll (that's for corpses): big hits play a
	-- knockdown animation while the body slides / flies, smaller ones a hurt flinch.
	local kb = info.kb or Vector3.zero
	local mag = kb.Magnitude
	if mag > 0.5 and target.model and not target.virtual then
		local threshold = info.ragdollAt or Config.Combat.knockdownAt or Config.Combat.ragdollKnockback
		if mag >= threshold and not target.poise and not target.noRagdoll then
			Combat.knockdown(target, kb)
		else
			Combat.push(target, if target.poise then kb * 0.2 else kb)
		end
	end
end

-- falls over (animation), slides/flies with the hit, gets back up
function Combat.knockdown(target, kb: Vector3)
	local now = os.clock()
	local model = target.model
	local dur = 1.1 + math.min(kb.Magnitude / 100, 0.9)
	if target.kind == "player" then
		-- players stagger instead of losing control of the camera
		Combat.push(target, kb)
		if S.PvP then
			S.PvP.stun(target, 0.35)
		end
		return
	end
	target.stunUntil = math.max(target.stunUntil, now + dur)
	if target.brain and target.brain.cancelAction then
		pcall(target.brain.cancelAction, target.brain)
	end
	if model then
		local launched = kb.Y > 22
		model:SetAttribute("ActW", 0.04)
		model:SetAttribute("ActA", if launched then 0.3 else 0.18)
		model:SetAttribute("ActR", dur)
		model:SetAttribute("ActKind", "none")
		model:SetAttribute("ActT0", workspace:GetServerTimeNow())
		model:SetAttribute("Act", if launched then "Launched" else "Knockdown")
		local tok = (model:GetAttribute("KdTok") or 0) + 1
		model:SetAttribute("KdTok", tok)
		task.delay(dur + 0.4, function()
			if model.Parent and model:GetAttribute("KdTok") == tok and not model:GetAttribute("Dead") then
				local a = model:GetAttribute("Act")
				if a == "Knockdown" or a == "Launched" then
					model:SetAttribute("Act", nil)
				end
			end
		end)
	end
	Combat.push(target, kb)
end

function Combat.push(target, vel: Vector3)
	if target.kind == "player" then
		Net.fire(target.player, "Ragdoll", { push = vel })
		return
	end
	local root = target.root
	if not root or root.Anchored or not root.Parent then
		return
	end
	local att = root:FindFirstChild("RootAttachment") :: Attachment
	if not att then
		return
	end
	vel = Combat.clampToWalls(root.Position, vel, target.radius or 1.6, target.model)
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	lv.MaxAxesForce = Vector3.new(1, 0, 1) * 4e4 * root.AssemblyMass
	lv.VectorVelocity = Vector3.new(vel.X, 0, vel.Z)
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = root
	if vel.Y > 0 then
		root.AssemblyLinearVelocity += Vector3.new(0, vel.Y, 0)
	end
	Debris:AddItem(lv, 0.14)
end

-- Shortens a knockback so a body stops at the wall instead of tunnelling into it
-- (fast bodies and thin walls used to trap monsters inside the level geometry).
local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude
wallParams.IgnoreWater = true
function Combat.clampToWalls(pos: Vector3, vel: Vector3, radius: number, model: Instance?): Vector3
	local flat = Vector3.new(vel.X, 0, vel.Z)
	local speed = flat.Magnitude
	local out = vel
	wallParams.FilterDescendantsInstances = worldFilter()
	if speed > 1 then
		-- the push lasts ~0.14 s, then friction; look a bit further for safety
		local reach = speed * 0.22 + radius + 1
		for _, h in { -1.2, 0.8 } do
			local r = workspace:Raycast(pos + Vector3.new(0, h, 0), flat.Unit * reach, wallParams)
			if r and r.Instance.CanCollide and math.abs(r.Normal.Y) < 0.6 then
				local free = math.max(0, r.Distance - radius - 0.4)
				local k = math.clamp(free / reach, 0, 1)
				-- bounce a little off the wall instead of sticking to it
				out = Vector3.new(flat.X * k, out.Y, flat.Z * k) + r.Normal * math.min(speed * 0.15, 8)
				break
			end
		end
	end
	if out.Y > 1 then
		local r = workspace:Raycast(pos, Vector3.new(0, out.Y * 0.35 + 3, 0), wallParams)
		if r and r.Instance.CanCollide then
			out = Vector3.new(out.X, math.max(0, r.Distance - 3) * 2, out.Z)
		end
	end
	return out
end

function Combat.parried(attacker, target, info)
	local now = os.clock()
	local p = S.Entities.position(target)
	local a = if attacker then S.Entities.position(attacker) else p
	Net.fireAll("FX", "Parry", { pos = p + (a - p).Unit * 2 + Vector3.new(0, 1.5, 0) })
	if target.player then
		Net.fire(target.player, "HitConfirm", { parry = true })
		-- perfect parries charge the time stop
		local cd = S.TimeStop.cooldownUntil[target.player]
		if cd and cd > now then
			cd -= Config.TimeStop.parryRefund
			S.TimeStop.cooldownUntil[target.player] = cd
			local total = S.State.derived(target.player).tsCooldown
			Net.fire(target.player, "TimeStop", "cooldown", { ready = workspace:GetServerTimeNow() + (cd - now), total = total })
		end
	end
	if attacker and attacker.kind == "player" and attacker.player then
		Net.fire(attacker.player, "HitConfirm", { deflected = true })
		if S.PvP then
			S.PvP.stun(attacker, 0.7)
		end
		if target.player then
			Combat.style(target.player, { { "PARRY", 60 } })
		end
	elseif attacker and attacker.brain and attacker.brain.onParried then
		attacker.brain:onParried(target, info)
	elseif attacker and attacker.kind == "npc" then
		attacker.stunUntil = now + 1.1
		attacker.riposteUntil = now + 1.3
	end
	if attacker and attacker.maxPosture then
		attacker.posture += attacker.maxPosture * 0.3
		attacker.postureHitAt = now
		if attacker.posture >= attacker.maxPosture then
			Combat.postureBreak(attacker)
		end
	end
end

function Combat.postureBreak(target)
	local now = os.clock()
	target.posture = 0
	target.stunUntil = now + 2.2
	target.riposteUntil = now + 2.4
	Net.fireAll("FX", "Break", { pos = S.Entities.position(target) + Vector3.new(0, 3, 0), target = target.model })
	if target.brain and target.brain.onStagger then
		target.brain:onStagger(2.2)
	end
end

function Combat.kill(target, killer, info)
	if target.dead then
		return
	end
	target.dead = true
	local model = target.model
	if target.kind == "player" and killer and killer.kind == "player" and S.PvP then
		task.spawn(S.PvP.onKill, killer, target)
	end
	if target.brain and target.brain.onDeath then
		pcall(target.brain.onDeath, target.brain, killer)
	end
	if model and model.Parent and not target.virtual then
		model:SetAttribute("Dead", true)
		model:SetAttribute("Act", nil)
		model:SetAttribute("Pose", nil)
		-- the corpse flies away from the killing blow (heavy / finisher kills much further)
		local kb = (info and info.kb) or Vector3.zero
		local flat = Vector3.new(kb.X, 0, kb.Z)
		if flat.Magnitude < 0.5 and killer and killer ~= target then
			flat = Util.flatUnit(S.Entities.position(target) - S.Entities.position(killer)) * 12
		end
		local heavy = info and (info.heavy or info.released or (info.kind == "stab"))
		local mult = if heavy then (Config.Combat.heavyKillLaunch or 2.6) else (Config.Combat.killLaunch or 1.35)
		local power = math.max(flat.Magnitude * mult, if heavy then 55 else 22)
		local dir = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zero
		local up = 12 + math.max(kb.Y, 0) * 0.5 + (if heavy then 16 else 0)
		local launch = Combat.clampToWalls(S.Entities.position(target), dir * power + Vector3.new(0, up, 0), 1.6, model)
		S.Ragdoll.enable(model, launch, if heavy then 16 else 10)
		Net.fireAll("FX", "Death", { pos = S.Entities.position(target), blood = target.blood, target = model, boss = target.boss, scale = model:GetScale(), giant = target.def and target.def.giant })
	end
	if target.hum then
		target.hum.Health = 0
	end
	S.Entities.fireDeath(target, killer)
	if target.onDie then
		task.spawn(target.onDie, target, killer)
	end
	if target.kind ~= "player" then
		S.Entities.remove(target)
		if model then
			task.delay(if target.boss then 20 else 9, function()
				if model.Parent then
					Net.fireAll("FX", "Fade", { target = model })
					task.wait(1.2)
					model:Destroy()
				end
			end)
		end
	end
end

-- ------------------------------------------------------------------ AoE helper
function Combat.aoe(attacker, center: Vector3, radius: number, info, filter)
	local hit = {}
	for _, e in S.Entities.alive() do
		if e ~= attacker and (not attacker or S.Entities.hostile(attacker, e)) and (not filter or filter(e)) then
			local p = S.Entities.position(e)
			local d = (p - center).Magnitude - (e.radius or 1.5)
			if d <= radius then
				local i = table.clone(info)
				local dir = Util.flatUnit(p - center)
				i.kb = dir * (info.kbPower or 30) + Vector3.new(0, info.kbUp or 18, 0)
				i.pos = p
				Combat.hit(attacker, e, i)
				table.insert(hit, e)
			end
		end
	end
	return hit
end

-- ------------------------------------------------------------------ player attacks
local boxParams = OverlapParams.new()
boxParams.FilterType = Enum.RaycastFilterType.Include

local function breakProps(origin: Vector3, look: Vector3, reach: number, force: number)
	local tagged = CollectionService:GetTagged("Breakable")
	if #tagged == 0 then
		return
	end
	boxParams.FilterDescendantsInstances = tagged
	local cf = CFrame.lookAt(origin + look * reach * 0.5, origin + look * reach)
	local parts = workspace:GetPartBoundsInBox(cf, Vector3.new(reach * 0.9, 6, reach), boxParams)
	for _, p in parts do
		if p:IsA("BasePart") and p.Anchored and p:HasTag("Breakable") then
			S.World.breakPart(p, look * force)
		end
	end
end

local function elementProc(attacker, target, element, dmg)
	if element == "Fire" then
		task.spawn(function()
			for _ = 1, 3 do
				task.wait(0.6)
				if not S.Entities.isAlive(target) then
					return
				end
				Combat.hit(attacker, target, { dmg = dmg * 0.08, kind = "burn", noDefer = false, element = "Fire" })
			end
		end)
	elseif element == "Frost" and target.hum then
		local ws = target.hum.WalkSpeed
		if not target.slowed then
			target.slowed = true
			target.hum.WalkSpeed = ws * 0.55
			task.delay(2, function()
				target.slowed = false
				if target.hum and target.hum.Parent then
					target.hum.WalkSpeed = ws
				end
			end)
		end
	elseif element == "Storm" then
		local p = S.Entities.position(target)
		for _, o in S.Entities.alive() do
			if o ~= target and o.kind ~= "player" and (S.Entities.position(o) - p).Magnitude < 14 then
				Net.fireAll("FX", "Zap", { from = p, to = S.Entities.position(o) })
				Combat.hit(attacker, o, { dmg = dmg * 0.4, kind = "zap", element = "Storm", kb = Vector3.zero })
				break
			end
		end
	end
end

function Combat.resolveSwing(e, player, item, heavy: boolean, combo: number, look: Vector3, air: boolean?)
	if not S.Entities.isAlive(e) then
		return
	end
	local head = e.model and e.model:FindFirstChild("Head") :: BasePart
	if not head then
		return
	end
	local ws = Weapons.stats(item)
	local d = S.State.derived(player)
	local origin = head.Position
	local reach = ws.reach * (if heavy then 1.15 else 1)
	local arc = math.rad(ws.arc * 0.5)
	local flatLook = Util.flatUnit(look)
	local targets = {}
	for _, o in S.Entities.list do
		if Combat.canTarget(e, o) then
			local p = S.Entities.position(o)
			local to = p - origin
			local dist = to.Magnitude - o.radius
			if dist <= reach then
				local flat = Util.flat(to)
				local ang = if flat.Magnitude < 0.5 then 0 else Util.angleBetween(flat, flatLook)
				local close = dist < 2.5
				local vertOk = math.abs(to.Y) <= reach * 0.7 + o.radius * 1.5 or (o.boss and math.abs(to.Y) <= reach + o.radius * 2)
				if (ang <= arc or close) and vertOk and Combat.lineOfSight(origin, p) then
					table.insert(targets, { e = o, dist = dist, pos = p })
				end
			end
		end
	end
	table.sort(targets, function(a, b)
		return a.dist < b.dist
	end)
	local maxTargets = if ws.arc >= 150 then 8 else 5
	local hits = 0
	local styles = {}
	local kills = 0
	for i, t in targets do
		if i > maxTargets then
			break
		end
		local dmg = Config.Player.baseDamage * ws.dmg * d.dmgMult
		if heavy then
			dmg *= Config.Combat.heavyMult
		elseif combo >= 3 then
			dmg *= Config.Combat.finisherMult
		end
		local crit = math.random() < ws.crit + (d.crit or 0)
		if crit then
			dmg *= Config.Combat.critMult + (d.critDmg or 0)
		end
		local hp, maxHp = S.Entities.health(t.e)
		if ws.execute > 0 and hp / maxHp < 0.35 then
			dmg *= 1 + ws.execute
		end
		local race = t.e.model and t.e.model:GetAttribute("Race")
		if ws.element == "Holy" and (race == "Demon" or race == "Undead") then
			dmg *= 1.35
		end
		-- knockback: heavy = launcher, 3rd hit = send flying, air hits keep juggling
		local light = not t.e.boss and not t.e.poise and not (t.e.def and t.e.def.giant)
		local inAir = Combat.airborne(t.e)
		local kb
		if heavy and light then
			kb = flatLook * 10 + Vector3.new(0, Config.Combat.launchUp, 0)
			table.insert(styles, { "LAUNCH", 30 })
		elseif heavy then
			kb = flatLook * Config.Combat.heavyKnockback + Vector3.new(0, 26, 0)
		elseif inAir and light then
			kb = flatLook * (if combo >= 3 then 34 else 6) + Vector3.new(0, if combo >= 3 then 8 else Config.Combat.juggleUp, 0)
			table.insert(styles, { "JUGGLE", 22 })
		elseif combo >= 3 then
			kb = flatLook * Config.Combat.finisherKnock + Vector3.new(0, 22, 0)
		else
			kb = flatLook * Config.Combat.baseKnockback + Vector3.new(0, 5, 0)
		end
		local hitPos = t.pos + (origin - t.pos).Unit * math.min(t.e.radius, 2)
		local res = Combat.hit(e, t.e, {
			dmg = dmg,
			kb = kb,
			posture = ws.posture * (if heavy then 2.2 else 1),
			crit = crit,
			pos = hitPos,
			kind = "slash",
			heavy = heavy,
			chrono = ws.chrono,
			lifesteal = ws.lifesteal + (d.lifesteal or 0) + (if ws.element == "Blood" then 0.03 else 0),
			element = ws.element,
		})
		if res == "hit" or res == "queued" then
			hits += 1
			if ws.element then
				elementProc(e, t.e, ws.element, dmg)
			end
			if res == "queued" then
				table.insert(styles, { "FROZEN FLURRY", 18 })
			elseif not S.Entities.isAlive(t.e) then
				kills += 1
				if inAir or air then
					table.insert(styles, { "AIRSHOT", 60 })
				end
				table.insert(styles, { if t.e.kind == "player" then "HUMILIATION" elseif t.e.boss then "GIANT KILLER" else "KILL", if t.e.boss then 200 else 45 })
			elseif crit then
				table.insert(styles, { "CRITICAL", 20 })
			end
		elseif res == "parried" then
			table.insert(styles, { "DENIED", 0 })
		end
	end
	if kills >= 2 then
		table.insert(styles, { "MULTIKILL", 60 * kills })
	end
	breakProps(origin, flatLook, reach, if heavy then 70 else 35)
	if hits > 0 and not S.TimeStop.active then
		Net.fire(player, "HitConfirm", { n = hits, heavy = heavy, styles = styles })
	elseif #styles > 0 then
		Combat.style(player, styles)
	end
end

function Combat.playerSwing(player: Player, data)
	local e = S.Entities.forPlayer(player)
	if not e or not S.Entities.isAlive(e) then
		return
	end
	local char = player.Character
	if not char or char:GetAttribute("Locked") or char:GetAttribute("NoCombat") or S.Ragdoll.isRagdolled(char) then
		return
	end
	if e.frozen then
		return
	end
	local item = S.State.equipped(player)
	if not item then
		return
	end
	local ws = Weapons.stats(item)
	local now = os.clock()
	local heavy = data.heavy == true
	local minGap = ws.interval * (if heavy then 1.0 else 0.72)
	if now - (e.lastSwing or 0) < minGap then
		return
	end
	e.lastSwing = now
	local look = typeof(data.look) == "Vector3" and data.look or Vector3.new(0, 0, -1)
	if look.Magnitude < 0.5 then
		return
	end
	look = look.Unit
	local combo = math.clamp(tonumber(data.i) or 1, 1, 3)
	Net.fireExcept(player, "FX", "Swing", { model = char, heavy = heavy })
	-- the body swings too (other players, third person camera)
	local anim = if heavy then "Overhead" elseif combo == 1 then "SlashR" elseif combo == 2 then "SlashL" else "Thrust"
	char:SetAttribute("ActW", 0.04)
	char:SetAttribute("ActA", ws.interval * 0.3)
	char:SetAttribute("ActR", ws.interval * 0.55)
	char:SetAttribute("ActT0", workspace:GetServerTimeNow())
	char:SetAttribute("Act", anim)
	local tok = (char:GetAttribute("ActTok") or 0) + 1
	char:SetAttribute("ActTok", tok)
	task.delay(ws.interval * 1.1, function()
		if char.Parent and char:GetAttribute("ActTok") == tok then
			char:SetAttribute("Act", nil)
		end
	end)
	task.delay(if heavy then 0.1 else 0.075, Combat.resolveSwing, e, player, item, heavy, combo, look, data.air == true)
end

-- Aether Step: short teleport dash; cuts everything along the path.
function Combat.aetherStep(player: Player, from: Vector3, to: Vector3)
	local e = S.Entities.forPlayer(player)
	local prof = S.State.profile(player)
	if not e or not prof.abilities.aetherStep or not S.Entities.isAlive(e) then
		return
	end
	local now = os.clock()
	if now < (e.stepCd or 0) then
		return
	end
	e.stepCd = now + Config.Abilities.AetherStep.cooldown * 0.8
	e.dashUntil = now + 0.3
	local seg = to - from
	if seg.Magnitude > Config.Abilities.AetherStep.distance + 8 then
		return
	end
	Net.fireAll("FX", "Teleport", { from = from, to = to, color = Color3.fromRGB(150, 230, 255) })
	local item = S.State.equipped(player)
	if not item then
		return
	end
	local ws = Weapons.stats(item)
	local d = S.State.derived(player)
	for _, o in S.Entities.alive() do
		if Combat.canTarget(e, o) then
			local p = S.Entities.position(o)
			local t = math.clamp((p - from):Dot(seg.Unit), 0, seg.Magnitude)
			local closest = from + seg.Unit * t
			if (p - closest).Magnitude <= 4 + o.radius then
				Combat.hit(e, o, {
					dmg = Config.Player.baseDamage * ws.dmg * d.dmgMult * 0.9,
					kb = Util.flatUnit(seg) * 20 + Vector3.new(0, 10, 0),
					posture = ws.posture,
					kind = "step",
					pos = p,
					chrono = ws.chrono,
				})
			end
		end
	end
end

-- Dash-stab: the client reports an enemy it dashed through; the cut lands a beat
-- later (anime style). Validated against the server's view of the dash.
function Combat.dashStab(player: Player, model: Instance?, from: Vector3?, to: Vector3?)
	local e = S.Entities.forPlayer(player)
	if not e or not S.Entities.isAlive(e) or typeof(model) ~= "Instance" then
		return
	end
	local now = os.clock()
	if now - (e.lastDashAt or -10) > Config.Player.dashTime + 0.4 then
		return
	end
	local o = S.Entities.fromModel(model)
	if not o or not Combat.canTarget(e, o) or not S.Entities.hostile(e, o) then
		return
	end
	e.stabbed = e.stabbed or {}
	if e.stabbed[o] == e.dashId then
		return
	end
	local ep, op = S.Entities.position(e), S.Entities.position(o)
	if (ep - op).Magnitude > 26 + (o.radius or 1.5) then
		return
	end
	e.stabbed[o] = e.dashId
	local item = S.State.equipped(player)
	if not item then
		return
	end
	local ws = Weapons.stats(item)
	local d = S.State.derived(player)
	local dir = e.dashDir or Util.flatUnit(op - ep)
	if dir.Magnitude < 0.1 then
		dir = Vector3.new(0, 0, -1)
	end
	local crit = math.random() < ws.crit + (d.crit or 0)
	local dmg = Config.Player.baseDamage * ws.dmg * d.dmgMult * (Config.Player.dashStabMult or 0.9) * (if crit then Config.Combat.critMult else 1)
	task.delay(0.16, function()
		if not S.Entities.isAlive(o) or not S.Entities.isAlive(e) then
			return
		end
		local res = Combat.hit(e, o, {
			dmg = dmg,
			kb = Util.flatUnit(dir) * 26 + Vector3.new(0, 12, 0),
			posture = ws.posture * 1.6,
			kind = "stab",
			pos = S.Entities.position(o),
			crit = crit,
			chrono = ws.chrono,
			element = ws.element,
			noDefer = false,
		})
		if res == "hit" or res == "queued" then
			local styles = { { "DASH STAB", 35 } }
			if not S.Entities.isAlive(o) then
				table.insert(styles, { "SKEWERED", 70 })
			end
			Combat.style(player, styles)
		end
	end)
end

function Combat.voidSlash(player: Player, look: Vector3)
	local e = S.Entities.forPlayer(player)
	local prof = S.State.profile(player)
	if not e or not prof.abilities.voidSlash or not S.Entities.isAlive(e) then
		return
	end
	local now = os.clock()
	if now < (e.slashCd or 0) then
		return
	end
	local cfg = Config.Abilities.VoidSlash
	e.slashCd = now + cfg.cooldown * 0.85
	local item = S.State.equipped(player)
	local ws = if item then Weapons.stats(item) else { dmg = 1, chrono = 0 }
	local d = S.State.derived(player)
	local head = e.model:FindFirstChild("Head") :: BasePart
	if not head or typeof(look) ~= "Vector3" or look.Magnitude < 0.5 then
		return
	end
	S.Projectiles.fire(e, head.Position + look.Unit * 2, look.Unit * cfg.speed, {
		size = 6,
		color = Color3.fromRGB(170, 120, 255),
		style = "slash",
		gravity = 0,
		pierce = true,
		life = cfg.range / cfg.speed,
	}, {
		dmg = Config.Player.baseDamage * ws.dmg * d.dmgMult * cfg.damage,
		kbPower = 40,
		posture = 40,
		chrono = ws.chrono,
	})
end

local function weaponDamage(player: Player): number
	local item = S.State.equipped(player)
	local ws = if item then Weapons.stats(item) else { dmg = 1 }
	local d = S.State.derived(player)
	return Config.Player.baseDamage * (ws.dmg or 1) * (d.dmgMult or 1)
end

local function countStyles(player: Player, hitList, label: string, pts: number)
	local styles = {}
	local kills = 0
	for _, o in hitList do
		if not S.Entities.isAlive(o) then
			kills += 1
		end
	end
	if #hitList > 0 then
		table.insert(styles, { label, pts * math.min(#hitList, 4) })
	end
	if kills > 0 then
		table.insert(styles, { if kills >= 2 then "MULTIKILL" else "KILL", 45 * kills })
	end
	Combat.style(player, styles)
end

-- Ground slam landing (CTRL in the air): shockwave that launches everything around.
function Combat.slam(player: Player, pos: Vector3, fall: number)
	local e = S.Entities.forPlayer(player)
	if not e or not S.Entities.isAlive(e) or typeof(pos) ~= "Vector3" then
		return
	end
	local now = os.clock()
	if now < (e.slamCd or 0) then
		return
	end
	e.slamCd = now + 0.35
	local rp = S.Entities.position(e)
	if (rp - pos).Magnitude > 14 then
		pos = rp - Vector3.new(0, 3, 0)
	end
	local cfg = Config.Abilities.Slam
	fall = math.clamp(tonumber(fall) or 0, 0, 400)
	local radius = cfg.radius + math.min(fall / 18, 8)
	Net.fireAll("FX", "Shockwave", { pos = pos, radius = radius })
	local hit = Combat.aoe(e, pos + Vector3.new(0, 2, 0), radius, {
		dmg = weaponDamage(player) * (cfg.damage + math.min(fall / 80, 1.2)),
		kbPower = 16,
		kbUp = cfg.launch,
		posture = 30,
		kind = "slam",
		heavy = true,
		ragdollAt = 40,
	})
	countStyles(player, hit, "SLAM", 25)
end

-- Flame rune (Z): a blood-fire circle on the ground erupts after a moment.
function Combat.flameRune(player: Player, pos: Vector3)
	local e = S.Entities.forPlayer(player)
	local prof = S.State.profile(player)
	local cfg = Config.Abilities.FlameRune
	if not e or not S.Entities.isAlive(e) or not prof.abilities.flameRune or typeof(pos) ~= "Vector3" then
		return
	end
	local now = os.clock()
	if now < (e.runeCd or 0) then
		return
	end
	e.runeCd = now + cfg.cooldown * 0.85
	if (S.Entities.position(e) - pos).Magnitude > cfg.range + 12 then
		return
	end
	Net.fireAll("FX", "Rune", { pos = pos, radius = cfg.radius, delay = cfg.delay })
	task.delay(cfg.delay, function()
		if not S.Entities.isAlive(e) then
			return
		end
		Net.fireAll("FX", "Eruption", { pos = pos, radius = cfg.radius })
		local hit = Combat.aoe(e, pos + Vector3.new(0, 2, 0), cfg.radius, {
			dmg = weaponDamage(player) * cfg.damage,
			kbPower = 10,
			kbUp = cfg.launch,
			posture = 45,
			kind = "fire",
			element = "Fire",
			heavy = true,
			ragdollAt = 40,
		})
		countStyles(player, hit, "IMMOLATED", 30)
	end)
end

-- Storm web (X): lightning jumps from you through up to N enemies and stuns them.
function Combat.stormWeb(player: Player, look: Vector3)
	local e = S.Entities.forPlayer(player)
	local prof = S.State.profile(player)
	local cfg = Config.Abilities.StormWeb
	if not e or not S.Entities.isAlive(e) or not prof.abilities.stormWeb then
		return
	end
	local now = os.clock()
	if now < (e.stormCd or 0) then
		return
	end
	e.stormCd = now + cfg.cooldown * 0.85
	look = if typeof(look) == "Vector3" and look.Magnitude > 0.5 then look.Unit else Vector3.new(0, 0, -1)
	local from = S.Entities.position(e) + Vector3.new(0, 1.5, 0)
	local done = {}
	local chain = {}
	local cur = from
	for i = 1, cfg.chains do
		local best, bd = nil, cfg.radius * (if i == 1 then 1 else 0.6)
		for _, o in S.Entities.alive() do
			if not done[o] and Combat.canTarget(e, o) and S.Entities.hostile(e, o) then
				local p = S.Entities.position(o)
				local d = (p - cur).Magnitude
				local ok = i > 1 or Util.flatUnit(p - from):Dot(Util.flatUnit(look)) > 0.1 or d < 8
				if ok and d < bd then
					best, bd = o, d
				end
			end
		end
		if not best then
			break
		end
		done[best] = true
		local p = S.Entities.position(best)
		table.insert(chain, { from = cur, to = p })
		cur = p
		Combat.hit(e, best, {
			dmg = weaponDamage(player) * cfg.damage,
			kb = Vector3.new(0, 10, 0),
			posture = 35,
			kind = "zap",
			element = "Storm",
			pos = p,
		})
		if best.kind == "player" then
			if S.PvP then
				S.PvP.stun(best, cfg.stun * 0.6)
			end
		else
			best.stunUntil = math.max(best.stunUntil or 0, now + cfg.stun)
		end
	end
	Net.fireAll("FX", "StormWeb", { chain = chain, origin = from })
	countStyles(player, table.clone((function()
		local l = {}
		for o in done do
			table.insert(l, o)
		end
		return l
	end)()), "ELECTRIFIED", 25)
end

function Combat.flask(player: Player)
	local e = S.Entities.forPlayer(player)
	local p = S.State.profile(player)
	if not e or not S.Entities.isAlive(e) or p.flasks <= 0 or not e.hum then
		return
	end
	if e.hum.Health >= e.hum.MaxHealth then
		return
	end
	p.flasks -= 1
	S.State.sync(player)
	Net.fireAll("FX", "Heal", { pos = S.Entities.position(e) })
	local total = e.hum.MaxHealth * Config.Player.flaskHeal
	task.spawn(function()
		for _ = 1, 10 do
			task.wait(0.06)
			if e.hum and e.hum.Health > 0 then
				e.hum.Health = math.min(e.hum.MaxHealth, e.hum.Health + total / 10)
			end
		end
	end)
end

-- ------------------------------------------------------------------ posture regen
RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for _, e in S.Entities.list do
		if e.posture > 0 and not e.frozen and now - e.postureHitAt > 2 then
			e.posture = math.max(0, e.posture - Config.Combat.postureRegen * dt * (e.maxPosture / 100))
		end
	end
end)

return Combat
