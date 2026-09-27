--!nonstrict
-- The wilds are alive: while a land is running, packs of monsters are kept out in
-- the countryside around every player (spawned out of sight, 190-330 studs away,
-- never in villages, towns or water) and recycled when nobody is near. They get
-- a little tougher the farther you ride from the city. Now and then a named
-- beast prowls instead of a pack. Everything spawned here has the tag "wild"
-- (bounties count those kills).
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local RNG = require(Shared.RNG)
local Beasts = require(Shared.Beasts)
local Util = require(Shared.Util)
local S = require(script.Parent.S)

local Wilds = {}
local V = Vector3.new
local CF = CFrame.new

Wilds.PER_PLAYER = 5 -- packs kept within reach of each player
Wilds.MAX_PACKS = 16
Wilds.ELITE_CHANCE = 0.07
Wilds.TICK = 2.5

local cfg = nil
local packs = {} -- { members = {e}, elite = bool }
local rng = RNG.new(os.time() % 7717 + 11)
local runId = 0

local function alive(pack): boolean
	for _, e in pack.members do
		if S.Entities.isAlive(e) then
			return true
		end
	end
	return false
end

local function packPos(pack): Vector3?
	for _, e in pack.members do
		if S.Entities.isAlive(e) then
			return S.Entities.position(e)
		end
	end
	return nil
end

local function remove(pack)
	for _, e in pack.members do
		if not e.dead then
			e.dead = true
			if e.brain and e.brain.destroy then
				pcall(e.brain.destroy, e.brain)
			end
			if e.model then
				e.model:Destroy()
			end
			S.Entities.remove(e)
		end
	end
end

local function playerRoots()
	local out = {}
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local r = c and c.PrimaryPart
		if r then
			table.insert(out, r)
		end
	end
	return out
end

local function anyPlayerWithin(pos: Vector3, r: number): boolean
	for _, root in playerRoots() do
		if Util.flatDist(root.Position, pos) < r then
			return true
		end
	end
	return false
end

-- where a pack may appear (nil = nowhere good on this try)
local function spotNear(from: Vector3): Vector3?
	for _ = 1, 8 do
		local a = rng:angle()
		local d = rng:float(190, 330)
		local x, z = from.X + math.cos(a) * d, from.Z + math.sin(a) * d
		local r = math.sqrt((x - cfg.center.X) ^ 2 + (z - cfg.center.Z) ^ 2)
		if r > cfg.inner and r < cfg.outer then
			local ok = true
			for _, av in cfg.avoid or {} do
				if Util.flatDist(V(x, 0, z), av.p) < av.r then
					ok = false
					break
				end
			end
			if ok and not anyPlayerWithin(V(x, 0, z), 150) then
				local y = cfg.groundAt(x, z)
				if y and y > (cfg.waterY or -1e9) + 1 then
					return V(x, y, z)
				end
			end
		end
	end
	return nil
end

local function levelAt(p: Vector3): number
	local lead = S.State.leader()
	local pl = if lead then (S.State.profile(lead).level or 1) else 1
	local r = Util.flatDist(p, cfg.center)
	local far = math.floor(math.max(0, r - cfg.inner) / 600)
	return math.max(cfg.level, pl - 1) + far
end

local function spawnPack(at: Vector3)
	local level = levelAt(at)
	local tags = { wild = true }
	for k, v in cfg.tags or {} do
		tags[k] = v
	end
	if rng:chance(Wilds.ELITE_CHANCE) then
		local def = Beasts.boss(rng, level, { miniboss = true, hpMult = 3 })
		tags.wildElite = true
		local e = S.AI.spawn(def, CF(at + V(0, 4, 0)), { level = level + 2, tags = tags, aggro = 90, rng = rng })
		if e then
			table.insert(packs, { members = { e }, elite = true })
			for _, root in playerRoots() do
				local p = Players:GetPlayerFromCharacter(root.Parent)
				if p and Util.flatDist(root.Position, at) < 600 then
					Net.fire(p, "Notify", { kind = "info", text = "A named beast prowls nearby", sub = def.name })
				end
			end
		end
		return
	end
	local list = {}
	for _ = 1, rng:int(3, 5) do
		table.insert(list, rng:pick(cfg.pool))
	end
	local members = S.AI.spawnGroup(list, at + V(0, 4, 0), 12, { level = level, tags = tags, aggro = 75, wanderRadius = 30 })
	if #members > 0 then
		table.insert(packs, { members = members })
	end
end

local function tick()
	-- forget the dead, recycle the far
	for i = #packs, 1, -1 do
		local pack = packs[i]
		if not alive(pack) then
			table.remove(packs, i)
		else
			local p = packPos(pack)
			if p and not anyPlayerWithin(p, 780) then
				remove(pack)
				table.remove(packs, i)
			end
		end
	end
	for _, root in playerRoots() do
		local pos = root.Position
		local r = Util.flatDist(pos, cfg.center)
		if r > cfg.inner - 200 and r < cfg.outer + 200 then
			local near = 0
			for _, pack in packs do
				local p = packPos(pack)
				if p and Util.flatDist(p, pos) < 450 then
					near += 1
				end
			end
			if near < Wilds.PER_PLAYER and #packs < Wilds.MAX_PACKS then
				local at = spotNear(pos)
				if at then
					spawnPack(at)
				end
			end
		end
	end
end

-- c = {pool = {defs}, level, center, inner, outer, groundAt(x, z) -> y?, waterY?,
--      avoid = {{p, r}}, tags?, active = fn() -> bool (false once: stop)}
function Wilds.start(c)
	Wilds.stop()
	cfg = c
	runId += 1
	local id = runId
	task.spawn(function()
		while runId == id and cfg do
			if cfg.active and not cfg.active() then
				-- the world it was started for is gone (travel, a new story)
				Wilds.stop()
				break
			end
			local ok, err = pcall(tick)
			if not ok then
				warn("[Wilds] " .. tostring(err))
			end
			task.wait(Wilds.TICK)
		end
	end)
end

function Wilds.stop()
	runId += 1
	cfg = nil
	for _, pack in packs do
		remove(pack)
	end
	packs = {}
end

function Wilds.running(): boolean
	return cfg ~= nil
end

Wilds._tick = tick -- (tests)

return Wilds
