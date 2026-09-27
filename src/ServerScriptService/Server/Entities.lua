--!nonstrict
-- Registry of everything that can fight: players, NPCs, and "virtual" boss parts
-- (e.g. titan cores) that have a position function instead of a model.
local Players = game:GetService("Players")

local Entities = {}
Entities.list = {}
Entities.byModel = {}
Entities.byPlayer = {}
Entities.byId = {}
local deathHandlers = {}
local nextId = 0

function Entities.onDeath(fn)
	table.insert(deathHandlers, fn)
end

function Entities.fireDeath(e, killer)
	for _, fn in deathHandlers do
		task.spawn(fn, e, killer)
	end
end

function Entities.new(model: Model?, opts)
	nextId += 1
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	local root = model and (model:FindFirstChild("HumanoidRootPart") :: BasePart)
	local e = {
		id = nextId,
		model = model,
		hum = hum,
		root = root,
		kind = opts.kind or "npc",
		player = opts.player,
		team = opts.team or "monster",
		def = opts.def,
		name = opts.name or (model and model.Name) or "?",
		level = opts.level or 1,
		dmg = opts.dmg or 10,
		posture = 0,
		maxPosture = opts.posture or 100,
		postureHitAt = 0,
		blood = opts.blood or (model and model:GetAttribute("Blood")) or "red",
		dead = false,
		invuln = opts.invuln or false,
		stunUntil = 0,
		riposteUntil = 0,
		parryUntil = 0,
		parryCd = 0,
		blocking = false,
		dashUntil = 0,
		sliding = false,
		iframesUntil = 0,
		armor = opts.armor or 0,
		poise = opts.poise or false,
		boss = opts.boss or false,
		miniboss = opts.miniboss or false,
		tags = opts.tags or {},
		virtual = opts.virtual or false,
		pos = opts.pos,
		radius = opts.radius or ((model and model:GetScale() or 1) * 1.6),
		hp = opts.hp,
		maxHp = opts.hp,
		frozen = false,
		xp = opts.xp or 0,
		gold = opts.gold,
		noDrop = opts.noDrop,
		hostile = if opts.hostile == nil then true else opts.hostile,
		onHit = opts.onHit,
		onDie = opts.onDie,
		spawnedAt = os.clock(),
	}
	table.insert(Entities.list, e)
	Entities.byId[e.id] = e
	if model then
		Entities.byModel[model] = e
		model:SetAttribute("EntityId", e.id)
		model:SetAttribute("Team", e.team)
		if e.boss or e.miniboss then
			model:SetAttribute("Boss", true)
		end
		-- NPC bodies: dashing players pass straight through them
		if e.kind ~= "player" then
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.CollisionGroup = "NPC"
				end
			end
		end
	end
	if opts.player then
		Entities.byPlayer[opts.player] = e
	end
	return e
end

function Entities.remove(e)
	local i = table.find(Entities.list, e)
	if i then
		table.remove(Entities.list, i)
	end
	Entities.byId[e.id] = nil
	if e.model and Entities.byModel[e.model] == e then
		Entities.byModel[e.model] = nil
	end
	if e.player and Entities.byPlayer[e.player] == e then
		Entities.byPlayer[e.player] = nil
	end
end

-- (the EntityId attribute is a fallback for environments where instances are not
-- stable table keys, e.g. the headless test harness)
local function lookup(model: Instance)
	local e = Entities.byModel[model]
	if e then
		return e
	end
	local id = model:GetAttribute("EntityId")
	return if id then Entities.byId[id] else nil
end

function Entities.fromModel(model: Instance?)
	return model and lookup(model)
end

function Entities.fromPart(part: Instance?)
	local cur = part
	while cur and cur ~= workspace do
		local e = lookup(cur)
		if e then
			return e
		end
		cur = cur.Parent
	end
	return nil
end

function Entities.forPlayer(player: Player)
	local e = Entities.byPlayer[player]
	if e then
		return e
	end
	for _, o in Entities.list do
		if o.player == player then
			return o
		end
	end
	return nil
end

function Entities.position(e): Vector3
	if e.pos then
		return e.pos()
	end
	if e.root and e.root.Parent then
		return e.root.Position
	end
	return Vector3.zero
end

function Entities.health(e): (number, number)
	if e.hum then
		return e.hum.Health, e.hum.MaxHealth
	end
	return e.hp or 0, e.maxHp or 1
end

function Entities.isAlive(e): boolean
	if e.dead then
		return false
	end
	if e.hum then
		return e.hum.Health > 0 and e.model.Parent ~= nil
	end
	return (e.hp or 0) > 0
end

-- Players are team "hero". Every NPC with hostile=true fights them.
function Entities.hostile(a, b): boolean
	if a == b then
		return false
	end
	-- player vs player: only in a duel or in the PvP arena
	if a.kind == "player" and b.kind == "player" then
		local S = require(script.Parent.S)
		return S.PvP ~= nil and S.PvP.canHit(a, b)
	end
	if a.team == "hero" then
		return b.team ~= "hero"
	elseif b.team == "hero" then
		return a.hostile
	end
	return false
end

function Entities.alive(filter)
	local out = {}
	for _, e in Entities.list do
		if Entities.isAlive(e) and (not filter or filter(e)) then
			table.insert(out, e)
		end
	end
	return out
end

function Entities.players()
	local out = {}
	for _, p in Players:GetPlayers() do
		local e = Entities.forPlayer(p)
		if e and Entities.isAlive(e) then
			table.insert(out, e)
		end
	end
	return out
end

function Entities.nearestHostile(e, maxDist: number)
	local best, bd = nil, maxDist
	local pos = Entities.position(e)
	for _, o in Entities.list do
		if o ~= e and Entities.isAlive(o) and Entities.hostile(e, o) and not o.untargetable then
			local d = (Entities.position(o) - pos).Magnitude
			if d < bd then
				best, bd = o, d
			end
		end
	end
	return best, bd
end

function Entities.countTag(tag: string): number
	local n = 0
	for _, e in Entities.list do
		if e.tags[tag] and Entities.isAlive(e) then
			n += 1
		end
	end
	return n
end

function Entities.withTag(tag: string)
	return Entities.alive(function(e)
		return e.tags[tag] == true
	end)
end

function Entities.clearNPCs(keepTag: string?)
	for i = #Entities.list, 1, -1 do
		local e = Entities.list[i]
		if e.kind ~= "player" and not (keepTag and e.tags[keepTag]) then
			e.dead = true
			if e.brain and e.brain.destroy then
				pcall(e.brain.destroy, e.brain)
			end
			if e.model then
				e.model:Destroy()
			end
			Entities.remove(e)
		end
	end
end

return Entities
