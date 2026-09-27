--@stubs world_stubs
--@server Wilds
-- Smoke test: the wilds spawner (Server/Wilds) keeps packs around a player out in
-- the countryside, never inside the city or a village, and recycles them when the
-- player rides away. AI / entities are faked: spawns are just recorded.
local S = {}
__mods["srv:S"] = function()
	return S
end
local V = Vector3.new
local ents = {}
local nextId = 0
local function fakeEntity(pos: Vector3, tags)
	nextId += 1
	local e = { id = nextId, pos = pos, tags = tags, dead = false }
	table.insert(ents, e)
	return e
end
S.AI = {
	spawn = function(def, cf, opts)
		return fakeEntity(cf.Position, opts.tags)
	end,
	spawnGroup = function(list, center, r, opts)
		local out = {}
		for _ in list do
			table.insert(out, fakeEntity(center, opts.tags))
		end
		return out
	end,
}
S.Entities = {
	isAlive = function(e)
		return not e.dead
	end,
	position = function(e)
		return e.pos
	end,
	remove = function(e)
		e.removed = true
	end,
}
S.State = {
	leader = function()
		return nil
	end,
	profile = function()
		return { level = 14 }
	end,
}
S.Wilds = require(Server.Wilds)

-- one fake player standing in the countryside
local char = Instance.new("Model")
local root = Instance.new("Part")
root.CFrame = CFrame.new(2600, 20, 0)
root.Parent = char
char.PrimaryPart = root
char.Parent = workspace
local player = { Character = char, UserId = 1 }
rawset(game:GetService("Players"), "GetPlayers", function()
	return { player }
end)
rawset(game:GetService("Players"), "GetPlayerFromCharacter", function()
	return player
end)

local village = V(2600, 0, 250)
local cfg = {
	pool = { "Goblin", "Bandit" },
	level = 12,
	center = V(0, 0, 0),
	inner = 1540,
	outer = 4440,
	groundAt = function()
		return 20
	end,
	waterY = 4,
	avoid = { { p = village, r = 230 } },
	tags = { land1 = true },
}
S.Wilds.start(cfg)
for _ = 1, 30 do
	S.Wilds._tick()
end
local alive = 0
for _, e in ents do
	assert(e.tags.wild == true and e.tags.land1 == true, "wild tags")
	local r = math.sqrt(e.pos.X ^ 2 + e.pos.Z ^ 2)
	assert(r > cfg.inner and r < cfg.outer, "pack outside the countryside ring at r=" .. r)
	local dv = (V(e.pos.X, 0, e.pos.Z) - village).Magnitude
	assert(dv > 230, "pack inside a village")
	local dp = (V(e.pos.X, 0, e.pos.Z) - V(2600, 0, 0)).Magnitude
	assert(dp >= 150 and dp < 340, "pack spawned too near / far: " .. dp)
	if not e.dead then
		alive += 1
	end
end
assert(#ents >= 4, "too few monsters spawned: " .. #ents)
print(string.format("spawned %d monsters around the player", #ents))
-- inside the city: nothing new
local before = #ents
root.CFrame = CFrame.new(300, 20, 0)
for _ = 1, 10 do
	S.Wilds._tick()
end
-- everything was far away from the player now: recycled
local removed = 0
for _, e in ents do
	if e.removed then
		removed += 1
	end
end
assert(#ents == before, "spawned inside the city")
assert(removed == before, "far packs not recycled: " .. removed .. "/" .. before)
S.Wilds.stop()
assert(not S.Wilds.running())
print("OK")
