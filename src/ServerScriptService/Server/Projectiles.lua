--!nonstrict
-- Server-simulated projectiles (arrows, orbs, fireballs, rocks, void slashes).
-- Clients draw them from the same launch data; the server decides hits.
-- Paused during time stop. Parried projectiles fly back at the shooter.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local S = require(script.Parent.S)

local Projectiles = {}
local active = {}
local paused = false
local nextId = 0

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true
local filterDirty = true
local filterAt = 0

function Projectiles.pause(on: boolean)
	paused = on
end

-- def: {speed, gravity, size, color, style, homing, explode, pierce, life, count, spread}
-- hit: {dmg, kbPower, posture, attackType}
function Projectiles.fire(owner, origin: Vector3, velocity: Vector3, def, hit, target)
	local count = def.count or 1
	local spread = math.rad(def.spread or 0)
	for i = 1, count do
		local v = velocity
		if count > 1 then
			local a = (i - (count + 1) / 2) * spread
			v = CFrame.fromAxisAngle(Vector3.yAxis, a):VectorToWorldSpace(velocity)
		end
		nextId += 1
		local p = {
			id = nextId,
			owner = owner,
			team = owner and owner.team or "monster",
			pos = origin,
			vel = v,
			gravity = def.gravity or 0,
			size = def.size or 1,
			life = def.life or 6,
			age = 0,
			homing = def.homing,
			target = target,
			explode = def.explode,
			pierce = def.pierce,
			pierced = {},
			hit = hit or {},
			style = def.style or "orb",
			color = def.color or Color3.new(1, 1, 1),
			reflected = false,
			lastSync = 0,
		}
		active[p.id] = p
		Net.fireAll("Projectile", "spawn", {
			id = p.id,
			pos = origin,
			vel = v,
			gravity = p.gravity,
			size = p.size,
			color = p.color,
			style = p.style,
			homing = p.homing ~= nil,
		})
	end
end

local function finish(p, pos: Vector3, exploded: boolean?)
	active[p.id] = nil
	Net.fireAll("Projectile", "end", { id = p.id, pos = pos, explode = exploded and p.explode, color = p.color, style = p.style })
end

local function explode(p, pos: Vector3)
	if p.explode then
		S.Combat.aoe(p.owner, pos, p.explode, {
			dmg = (p.hit.dmg or 10) * 0.8,
			kbPower = p.hit.kbPower or 30,
			kbUp = 22,
			attackType = "aoe",
			kind = "explosion",
		}, function(e)
			return p.team == "hero" and e.team ~= "hero" or p.team ~= "hero" and e.team == "hero"
		end)
	end
end

local function hostileTo(p, e): boolean
	if p.team == "hero" then
		return e.team ~= "hero"
	end
	return e.team == "hero"
end

local function segDist(a: Vector3, b: Vector3, c: Vector3): number
	local ab = b - a
	local l = ab.Magnitude
	if l < 1e-4 then
		return (c - a).Magnitude
	end
	local t = math.clamp((c - a):Dot(ab) / (l * l), 0, 1)
	return (a + ab * t - c).Magnitude
end

local function refreshFilter()
	local list = {}
	for _, e in S.Entities.list do
		if e.model then
			table.insert(list, e.model)
		end
	end
	for _, m in CollectionService:GetTagged("Rig") do
		table.insert(list, m)
	end
	local fx = workspace:FindFirstChild("FX")
	if fx then
		table.insert(list, fx)
	end
	params.FilterDescendantsInstances = list
end

RunService.Heartbeat:Connect(function(dt)
	if paused or next(active) == nil or (S.Pause and S.Pause.active) then
		return
	end
	local now = os.clock()
	if now - filterAt > 0.5 or filterDirty then
		refreshFilter()
		filterAt = now
		filterDirty = false
	end
	for id, p in active do
		p.age += dt
		if p.age > p.life then
			explode(p, p.pos)
			finish(p, p.pos, true)
			continue
		end
		if p.homing and p.target and S.Entities.isAlive(p.target) and not p.reflected then
			local to = (S.Entities.position(p.target) - p.pos)
			if to.Magnitude > 1 then
				local speed = p.vel.Magnitude
				local want = to.Unit * speed
				p.vel = p.vel:Lerp(want, math.clamp(p.homing * dt, 0, 1))
			end
			if now - p.lastSync > 0.15 then
				p.lastSync = now
				Net.fireAll("Projectile", "sync", { id = p.id, pos = p.pos, vel = p.vel })
			end
		end
		local newPos = p.pos + p.vel * dt
		p.vel += Vector3.new(0, -p.gravity * dt, 0)
		-- entity hits
		local done = false
		for _, e in S.Entities.list do
			if not done and S.Entities.isAlive(e) and hostileTo(p, e) and not p.pierced[e] and e ~= p.owner then
				local c = S.Entities.position(e)
				if segDist(p.pos, newPos, c) <= (e.radius or 1.5) + p.size * 0.5 + 0.6 then
					-- parry reflect
					local now2 = os.clock()
					if e.kind == "player" and now2 < e.parryUntil and p.style ~= "slash" and not p.unparryable then
						S.Combat.parried(nil, e, {})
						p.reflected = true
						p.team = "hero"
						p.owner = e
						p.pierced = {}
						local back = if p.hit.shooter and S.Entities.isAlive(p.hit.shooter) then (S.Entities.position(p.hit.shooter) - newPos).Unit else -p.vel.Unit
						p.vel = back * p.vel.Magnitude * 1.3
						p.gravity = 0
						p.hit.dmg = (p.hit.dmg or 10) * 2
						p.age = 0
						Net.fireAll("Projectile", "redirect", { id = p.id, pos = newPos, vel = p.vel })
						newPos = p.pos
						done = true
						break
					end
					S.Combat.hit(p.owner, e, {
						dmg = p.hit.dmg or 10,
						kb = p.vel.Unit * (p.hit.kbPower or 14) + Vector3.new(0, 6, 0),
						posture = p.hit.posture or 8,
						attackType = p.hit.attackType or "projectile",
						kind = "proj",
						pos = c,
						chrono = p.hit.chrono,
					})
					if p.pierce then
						p.pierced[e] = true
					else
						explode(p, c)
						finish(p, c, true)
						done = true
						break
					end
				end
			end
		end
		if done then
			if active[id] then
				p.pos = newPos
			end
			continue
		end
		-- world hits
		local r = workspace:Raycast(p.pos, newPos - p.pos, params)
		if r and not (p.pierce and p.style == "slash") then
			explode(p, r.Position)
			finish(p, r.Position, true)
			continue
		end
		p.pos = newPos
	end
end)

function Projectiles.clear()
	for id, p in active do
		finish(p, p.pos, false)
	end
end

return Projectiles
