--!nonstrict
-- PVP ARENA (main menu). Everyone against everyone on the Ashen Field, instant
-- respawns, a full kit (all abilities, a rack of rare weapons, armour), a kill
-- feed. Playing alone? Duelist bots join so the combos can be tried out.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local RNG = require(Shared.RNG)
local Weapons = require(Shared.Weapons)
local Gear = require(Shared.Gear)
local S = require(script.Parent.Parent.S)

local Ch: any = {}
local V = Vector3.new
local CF = CFrame.new

local KIT_WEAPONS = { "Sword", "Katana", "Greatsword", "Spear", "Dagger", "Hammer", "Axe", "Scythe" }
local KIT_GEAR = { "Head", "Chest", "Hands", "Legs", "Feet", "Cloak", "Amulet" }
local BOTS = { "Berserker", "Raider", "SkeletonKnight", "DemonKnight", "RoyalKnight", "AbyssKnight" }
local LEVEL = 30

local function giveKit(player: Player, rng)
	local prof = S.State.profile(player)
	if prof.arenaKit then
		return
	end
	prof.arenaKit = true
	prof.level = LEVEL
	prof.points = 0
	prof.stats = { dmg = 6, hp = 10, tsDur = 2, tsCd = 6 }
	prof.abilities = { timestop = true, aetherStep = true, voidSlash = true, flameRune = true, stormWeb = true }
	prof.flasks, prof.maxFlasks = 3, 3
	prof.look = "hero"
	local first = nil
	for i, kind in KIT_WEAPONS do
		local ok, item = pcall(Weapons.roll, rng, LEVEL, { rarity = if i == 1 then "Legendary" else "Epic", type = kind })
		if ok and item then
			S.State.addItem(player, item, true)
			first = first or item
		end
	end
	for _, slot in KIT_GEAR do
		local ok, item = pcall(Gear.roll, rng, LEVEL, { slot = slot, rarity = "Epic" })
		if ok and item then
			S.State.addItem(player, item, true)
			prof.equipment = prof.equipment or {}
			prof.equipment[item.slot] = item.id
		end
	end
	if first then
		prof.equipped = first.id
	end
	S.State.applyStats(player)
	S.State.sync(player)
end

local function randomSpawn(refs, rng): CFrame
	local best, bd = refs.spawns[1], -1
	-- spawn far away from everybody else
	for _ = 1, 6 do
		local cf = refs.spawns[rng:int(1, #refs.spawns)]
		local nearest = math.huge
		for _, e in S.Entities.alive() do
			nearest = math.min(nearest, (S.Entities.position(e) - cf.Position).Magnitude)
		end
		if nearest > bd then
			best, bd = cf, nearest
		end
	end
	return best
end

function Ch.run(D)
	local run = S.State.run
	local rng = RNG.new(D.seed()):fork("arena")
	local refs = D.ensure("arena", function()
		return S.WorldArena.build(D.seed())
	end)
	S.PvP.setArena(true)
	for _, p in Players:GetPlayers() do
		giveKit(p, rng)
	end
	D.look("hero")
	D.zone("Arena", "THE ASHEN FIELD", "PVP ARENA  ·  everyone against everyone")
	D.music("Combat")
	D.checkpoint(refs.spawns[1])
	D.spawnPlayers(refs.spawns[1])
	for _, p in Players:GetPlayers() do
		S.PlayerService.teleport(p, randomSpawn(refs, rng))
		S.PvP.spawnProtect[p] = os.clock() + 3
	end
	D.lock(false, false, false)
	D.fade("clear", 0.8)
	Net.fireAll("PvP", { kind = "arena", on = true })
	Net.fireAll("Scene", "camMode", { mode = "third" })
	D.objective("Kill everyone", "Hold LMB to launch  ·  hit them in the air  ·  CTRL in the air slams  ·  Z / X spells")
	D.tutorial("V switches between first and third person", "V", 6)
	D.deathHandler = function(player: Player)
		task.delay(2.2, function()
			if not player.Parent then
				return
			end
			local prof = S.State.profile(player)
			prof.flasks = prof.maxFlasks
			S.PlayerService.spawn(player, randomSpawn(refs, rng))
			S.PvP.spawnProtect[player] = os.clock() + 2.5
			S.State.sync(player)
		end)
		return true
	end

	-- the arena never ends: keep kits, bots and the scoreboard going
	local bots = {}
	while S.State.run == run do
		D.wait(1.5)
		local players = Players:GetPlayers()
		for _, p in players do
			local prof = S.State.profile(p)
			if not prof.arenaKit then
				giveKit(p, rng)
				Net.fire(p, "PvP", { kind = "arena", on = true })
				Net.fire(p, "Scene", "camMode", { mode = "third" })
			end
		end
		-- bots while there are fewer than 3 players
		local want = math.max(0, 3 - #players)
		for i = #bots, 1, -1 do
			if not S.Entities.isAlive(bots[i]) then
				table.remove(bots, i)
			end
		end
		if #bots < want then
			local cf = randomSpawn(refs, rng)
			local e = S.AI.spawn(rng:pick(BOTS), cf, { level = LEVEL - 4, tags = { arena = true }, aggro = 400, leash = 900 })
			if e then
				table.insert(bots, e)
				Net.fireAll("PvP", { kind = "feed", killer = "A challenger", victim = "enters the field", score = S.PvP.scores() })
			end
		end
	end
	S.PvP.setArena(false)
	return "__stop"
end

return Ch
