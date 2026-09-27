--!nonstrict
-- CHAPTER 8: The real RPG. Leave the ruined kingdom and cross five lands: towns,
-- quests, merchants, monster camps, dungeons, monster towers, roaming elites and
-- a land lord guarding the gate to the next land.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local RNG = require(Shared.RNG)
local Enemies = require(Shared.Enemies)
local Story = require(Shared.Story)
local Palette = require(Shared.Palette)
local Rig = require(Shared.Rig)
local Util = require(Shared.Util)
local Beasts = require(Shared.Beasts)
local S = require(script.Parent.Parent.S)

local Ch: any = {}
local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB

local PIT_THEME = {
	Autumn = 3, Desert = 3, Frost = 1, Swamp = 2, Volcanic = 4, Crystal = 1, Mushroom = 2, Evil = 4, Meadow = 1, Fjord = 1, Giantwood = 3,
}

-- Pure beasts in the old biome lists are replaced by the run's random bestiary;
-- the thinking races (goblins, bandits, cultists, raiders ...) stay.
local BEASTLIKE = { Werewolf = true, FrostTroll = true, Fungoid = true, Imp = true, Hellbrute = true, Shade = true, Slime = true, Ghoul = true, Hellhound = true, VoidShade = true }

function Ch.landPool(D, L: number, info)
	local binfo = Story.BIOME_INFO[info.biome] or Story.BIOME_INFO.Meadow
	local pool = {}
	for _, id in binfo.monsters do
		if not BEASTLIKE[id] then
			table.insert(pool, id)
		end
	end
	local roster = Beasts.roster(D.seed(), 20)
	local rng = RNG.new(D.seed()):fork("landfauna", L)
	local tier = math.clamp(L, 1, 5)
	local species = {}
	for _ = 1, 3 do
		local sp = Beasts.pick(roster, rng, math.max(1, tier - 1), tier, function(d)
			return table.find(species, d) == nil
		end)
		if sp and not table.find(species, sp) then
			table.insert(species, sp)
		end
	end
	-- beasts are twice as common as any single race
	for _, sp in species do
		table.insert(pool, sp)
		table.insert(pool, sp)
	end
	return pool, species
end

local function defName(entry): string
	if type(entry) == "table" then
		return entry.name
	end
	local d = Enemies.DEFS[entry]
	return if d then d.name else tostring(entry)
end

-- Hunt quests are always completable: the quarry roams in packs that come back
-- until the quest is done (v3 asked for 12 kills of a type that might not exist).
local function huntPacks(D, L: number, sp, level: number, plan, rng)
	local tag = "hunt" .. L
	local spots = {}
	for _, w in plan.wilds or {} do
		table.insert(spots, w)
	end
	if #spots == 0 then
		table.insert(spots, V(0, 20, 0))
	end
	local function packAt(p: Vector3)
		for _ = 1, 4 do
			S.AI.spawn(sp, CF(p + V(rng:float(-10, 10), 4 + (if sp.hover then 4 else 0), rng:float(-10, 10))), { level = level, tags = { [tag] = true }, aggro = 80, wanderRadius = 40, rng = rng })
		end
	end
	for i = 1, 4 do
		packAt(spots[(i - 1) % #spots + 1])
	end
	task.spawn(function()
		local run = S.State.run
		while S.State.run == run and run.land == L do
			task.wait(20)
			if S.Quests.isDone("hunt" .. L) then
				break
			end
			if S.Entities.countTag(tag) < 4 then
				packAt(spots[rng:int(1, #spots)])
			end
		end
	end)
end

local function levelFor(L: number, info)
	return (info.level or L * 8) + (S.State.run.ngPlus or 0) * 20
end

local function travelMenu(D, current: number)
	local run = S.State.run
	local choices, targets = {}, {}
	for i = 1, 6 do
		if run.waystones[i] and i ~= current then
			table.insert(choices, D.bible().lands[i].name)
			table.insert(targets, i)
		end
	end
	if run.flags.epilogue then
		table.insert(choices, "Begin a brand new random story")
		table.insert(targets, -1)
	end
	table.insert(choices, "Stay")
	local c = D.say({ { speaker = "Waystone", text = "The stone hums. Where do you want to go?" } }, { choices = choices })
	local to = targets[c]
	if to == -1 then
		local sure = D.say({ { speaker = "Waystone", text = "A new seed, a new world, a new truck. You keep your level and your gear. Begin?" } }, { choices = { "Begin a new story", "Not yet" } })
		if sure ~= 1 then
			return nil
		end
	end
	return to
end

-- ------------------------------------------------------------------ town
local function townsfolkLook(rng, races)
	local race = rng:pick(races)
	local d = Rig.randomLook(rng, if race == "Dwarf" then "Human" else race, rng:pick({ "peasant", "peasant", "merchant", "noble" }))
	d.mood = rng:pick({ "neutral", "happy", "calm" })
	d.apron = if rng:chance(0.2) then rgb(220, 210, 190) else nil
	return d
end

local function populateTown(D, refs, L, rng, level)
	local b = D.bible()
	local info = b.lands[L]
	local binfo = Story.BIOME_INFO[info.biome] or Story.BIOME_INFO.Meadow
	local t = refs.town
	local points = {}
	for _, s in t.spots do
		table.insert(points, s + V(0, 3, 0))
	end
	table.insert(points, t.center + V(0, 3, 8))
	for i = 1, 10 do
		local look = townsfolkLook(rng, binfo.races)
		local line = Story.fillText(rng:pick(Story.CHATTER), b)
		S.NPCs.townsfolk(look, CF(rng:pick(points) + V(rng:float(-4, 4), 0, rng:float(-4, 4))), {
			name = Story.personName(rng, look.race == "Beastkin"),
			talk = { { speaker = "", text = line } },
			points = points,
			level = level,
			tags = { ["town" .. L] = true, npc = true },
			fightBack = true,
		})
	end
	-- merchant
	local mlook = townsfolkLook(rng, binfo.races)
	mlook.outfit = "merchant"
	local merchantName = Story.personName(rng) .. " the Merchant"
	local m = S.NPCs.townsfolk(mlook, t.merchant, { name = merchantName, stationary = true, level = level, tags = { ["town" .. L] = true, npc = true } })
	S.Loot.merchant(m.model, merchantName, level)
	-- innkeeper: rest to heal & save
	local ilook = townsfolkLook(rng, binfo.races)
	ilook.apron = rgb(230, 220, 200)
	S.NPCs.townsfolk(ilook, t.innkeeper, {
		name = "Innkeeper of " .. b.tavern,
		stationary = true,
		level = level,
		tags = { ["town" .. L] = true, npc = true },
		talk = function(player)
			local c = D.say({ { speaker = "Innkeeper", text = "Welcome to " .. b.tavern .. ". A bed's free. You look like you need it." } }, { player = player, choices = { "Rest (heal, refill flasks, save)", "Leave" } })
			if c == 1 then
				D.fade("black", 0.6)
				D.heal()
				D.save()
				D.fade("clear", 0.8)
				Net.fire(player, "Notify", { kind = "info", text = "Rested", sub = "Progress saved." })
			end
		end,
	})
	-- quest giver + elder
	local qlook = townsfolkLook(rng, binfo.races)
	qlook.outfit = "guard"
	local captainName = "Captain " .. Story.personName(rng)
	local plan = refs.plan
	local camp1 = plan.camps[1]
	local _, species = Ch.landPool(D, L, info)
	local quarry = species[1]
	S.NPCs.townsfolk(qlook, t.questGiver, {
		name = captainName,
		stationary = true,
		level = level,
		tags = { ["town" .. L] = true, npc = true },
		talk = function(player)
			D.say({
				{ speaker = captainName, text = "You're the stranger everyone's whispering about. Good. We need someone who doesn't mind blood." },
				{ speaker = captainName, text = "There's a camp of monsters to the " .. (if camp1.pos.X > 0 then "east" else "west") .. ". Burn it out." },
				{ speaker = captainName, text = "And thin out the " .. defName(quarry) .. "s on the roads. Twelve should send a message. They hunt in packs of four." },
			}, { player = player })
			S.Quests.give({ id = camp1.id, title = "Burn the camp", text = "Clear the monster camp near " .. info.town, kind = "tag", tag = camp1.id, total = camp1.count or 7, reward = { gold = 150 * L, xp = 400 * L, rarity = "Rare" } })
			S.Quests.give({ id = "hunt" .. L, title = "Road warden", text = "Kill 12 " .. defName(quarry) .. "s  (" .. Beasts.describe(quarry) .. ")", kind = "count", defId = defName(quarry), total = 12, reward = { gold = 120 * L, xp = 300 * L, flask = true } })
		end,
	})
	local elook = townsfolkLook(rng, binfo.races)
	elook.beard = "long"
	elook.hair = rgb(220, 220, 225)
	S.NPCs.townsfolk(elook, t.elder, {
		name = "Elder " .. Story.personName(rng),
		stationary = true,
		pose = "Crossed",
		level = level,
		tags = { ["town" .. L] = true, npc = true },
		talk = function(player)
			D.say({
				{ speaker = "Elder", text = "The lord of " .. info.short .. " sits in the fortress to the north. As long as he lives, the gate to the next land stays sealed." },
				{ speaker = "Elder", text = "Two of his beasts roam our hills with names of their own. Kill them and the people will sing about you. Badly, but still." },
			}, { player = player })
			S.Quests.give({ id = "elite" .. L .. "_1", title = "Named beast", text = "Hunt the named monster roaming " .. info.short, kind = "tag", tag = "elite" .. L .. "_1", total = 1, reward = { gold = 250 * L, xp = 600 * L, rarity = "Epic" } })
		end,
	})
	-- waystone
	S.PlayerService.prompt(t.waystonePart, "Travel", "Waystone", function(player)
		if player ~= D.leader() then
			return
		end
		local to = travelMenu(D, L)
		if to then
			Ch.travelTo = to
		end
	end, { dist = 10 })
end

-- ------------------------------------------------------------------ dungeon
local function dungeon(D, refs, L, rng, level)
	local run = S.State.run
	local info = D.bible().lands[L]
	local plan = refs.plan
	local poi = plan.dungeon
	if run.cleared[poi.id] then
		Net.fireAll("Notify", { kind = "info", text = "The dungeon is silent now." })
		return
	end
	D.fade("black", 0.5)
	local theme = S.WorldPit.THEMES[PIT_THEME[info.biome] or 1]
	S.WorldPit.clear("Dungeon")
	local dr = S.WorldPit.build({ level = level, seed = D.seed() + L * 101, theme = theme, folderName = "Dungeon", origin = V(0, -1400, 0), grid = 4, big = true })
	D.spawnPlayers(dr.spawnCF)
	local back = CFrame.lookAt((poi.ground or poi.pos) + V(0, 4, 8), (poi.ground or poi.pos) + V(0, 4, 20))
	D.checkpoint(dr.spawnCF)
	D.zone("pit", string.upper(info.short) .. " DEPTHS", "A dungeon of the " .. info.biome:lower() .. " lands")
	D.fade("clear", 0.6)
	local pool = Ch.landPool(D, L, info)
	local tag = poi.id
	for i, p in dr.spawnPoints do
		if i <= 16 then
			S.AI.spawn(rng:pick(pool), CF(p), { level = level, tags = { [tag] = true }, aggro = 80 })
		end
	end
	local elite = Enemies.elite(rng:pick(pool), rng)
	local boss = S.AI.spawn(elite, CF(dr.bossCenter), { level = level + 2, tags = { [tag] = true }, aggro = 60 })
	D.bossBar(boss)
	D.waitKills(tag, "Clear the dungeon")
	D.bossBar(nil)
	S.Loot.chest(nil, CF(dr.exitCenter + V(6, 0, 6)), "gold", { level = level, id = poi.id .. "_chest" })
	if dr.barrier then
		dr.barrier:Destroy()
	end
	run.cleared[poi.id] = true
	D.objective("Return to the surface")
	D.waitPrompt(dr.portalFilm, "Leave", "Back to " .. info.short)
	D.fade("black", 0.5)
	D.spawnPlayers(back)
	D.checkpoint(CFrame.new(refs.town.center + V(0, 4, 0)))
	D.zone(info.biome)
	S.WorldPit.clear("Dungeon")
	D.fade("clear", 0.6)
end

-- ------------------------------------------------------------------ land 1 (the ruined kingdom)
local function land1(D)
	local run = S.State.run
	local b = D.bible()
	local rng = RNG.new(D.seed()):fork("land1")
	local refs = D.ensureCapital()
	run.waystones[1] = true
	D.zone("Meadow", b.lands[1].name, "Land 1 of 6  -  the smallest")
	D.music("Calm")
	if not D.leaderChar() then
		D.spawnPlayers(CFrame.lookAt(refs.center + V(0, 4, 70), refs.northPass))
	end
	D.checkpoint(CFrame.lookAt(refs.center + V(0, 4, 70), refs.northPass))
	D.lock(false, false, false)
	-- the kingdom is at peace again: people come back out into the streets
	for _, name in refs.townSets or {} do
		S.Townlife.enable(name, true)
	end
	-- roaming packs out in the countryside (goblins, bandits and the run's beasts)
	local pool = { "Goblin", "Goblin", "Bandit", "Orc" }
	local _, species = Ch.landPool(D, 1, b.lands[1])
	for _, sp in species do
		table.insert(pool, sp)
		table.insert(pool, sp)
	end
	local wilds = refs.wilds or {}
	for i = 1, math.min(8, #wilds) do
		local p = wilds[i] + V(0, 4, 0)
		local pack = {}
		for _ = 1, 4 do
			table.insert(pack, rng:pick(pool))
		end
		S.AI.spawnGroup(pack, p, 14, { level = 12, tags = { land1 = true } })
	end
	-- pass portal
	local portal, film = S.World.portal(S.World.sub("City"), CFrame.lookAt(refs.northPass, refs.northPass + V(0, 0, -1)), rgb(120, 220, 255), "THE FIVE LANDS")
	D.objective("Leave the kingdom through the northern pass")
	D.marker(refs.northPass + V(0, 6, 0), "Northern pass")
	D.waitPrompt(film, "Travel", b.lands[2].name)
	run.land = 2
end

-- ------------------------------------------------------------------ lands 2-5
local function land(D, L: number)
	local run = S.State.run
	local b = D.bible()
	local info = b.lands[L]
	local rng = RNG.new(D.seed()):fork("landpop", L)
	local refs = D.ensure("land" .. L, function()
		return S.WorldLand.build(L, b, D.seed())
	end)
	local plan = refs.plan
	local level = levelFor(L, info)
	local binfo = Story.BIOME_INFO[info.biome] or Story.BIOME_INFO.Meadow
	local pool, species = Ch.landPool(D, L, info)
	run.waystones[L] = true
	D.zone(info.biome, string.upper(info.name), "Land " .. L .. " of 6")
	D.music("Calm")
	if Ch.skipSpawn then
		Ch.skipSpawn = nil
	else
		D.spawnPlayers(refs.entry)
	end
	D.checkpoint(CFrame.new(refs.town.center + V(0, 4, 0)))
	D.lock(false, false, false)
	Ch.travelTo = nil
	populateTown(D, refs, L, rng, level)
	-- camps
	for _, c in plan.camps do
		if not run.cleared[c.id] then
			local g = c.ground or c.pos
			c.count = rng:int(6, 8)
			for _ = 1, c.count do
				S.AI.spawn(rng:pick(pool), CF(g + V(rng:float(-18, 18), 4, rng:float(-18, 18))), { level = level, tags = { [c.id] = true }, aggro = 70, leash = 180 })
			end
			if c.chest then
				S.Loot.chest(nil, c.chest, "iron", { level = level, id = c.id .. "_chest" })
			end
		end
	end
	-- the hunt quest's quarry roams the wilds
	if species[1] and not S.Quests.isDone("hunt" .. L) then
		huntPacks(D, L, species[1], level, plan, rng)
	end
	-- monster tower
	local mt = plan.monsterTower
	if not run.cleared[mt.id] and mt.floors then
		for _, fp in mt.floors do
			for i = 1, 3 do
				S.AI.spawn(rng:pick(pool), CF(fp + V(rng:float(-6, 6), 0, rng:float(-6, 6))), { level = level + 1, tags = { [mt.id] = true }, aggro = 50, leash = 60 })
			end
		end
		local topBoss = S.AI.spawn(Enemies.elite(rng:pick(pool), rng), CF(mt.top), { level = level + 2, tags = { [mt.id] = true }, aggro = 40, leash = 50 })
		S.Loot.chest(nil, CF(mt.top + V(6, -1, 6)), "gold", { level = level, id = mt.id .. "_chest" })
	end
	-- shrines
	for _, sh in plan.shrines do
		if not run.cleared[sh.id .. "_chest"] and sh.chest then
			S.Loot.chest(nil, sh.chest, rng:pick({ "wood", "iron" }), { level = level, id = sh.id .. "_chest" })
		end
	end
	-- roaming elites
	for i = 1, 2 do
		local tag = "elite" .. L .. "_" .. i
		if not run.cleared[tag] then
			local p = if #plan.wilds > 0 then plan.wilds[(i - 1) % #plan.wilds + 1] + V(0, 4, 0) else V(rng:float(-plan.half + 200, plan.half - 200), 20, rng:float(-plan.half + 250, plan.half - 350))
			local e = S.AI.spawn(Enemies.elite(rng:pick(pool), rng), CF(p), { level = level + 2, tags = { [tag] = true }, aggro = 90, wanderRadius = 60 })
			if e then
				e.onDie = function()
					run.cleared[tag] = true
				end
			end
		end
	end
	-- the land lord
	local castle = plan.castle
	local lordTag = "landboss" .. L
	if castle and not run.cleared[lordTag] then
		for i = 1, 8 do
			S.AI.spawn(rng:pick(pool), CF(castle.courtyard + V(rng:float(-35, 35), 1, rng:float(-15, 30))), { level = level + 1, tags = { [castle.id] = true }, aggro = 80, leash = 120 })
		end
		-- beast lords are random bosses from the run's bestiary; the others stay canon
		local lordDef, lordName = binfo.boss, "Lord of " .. info.short
		if BEASTLIKE[binfo.boss] then
			lordDef = Beasts.boss(RNG.new(D.seed()):fork("lord", L), level)
			lordDef.minion = species[1]
			lordName = lordDef.name .. ", Lord of " .. info.short
		end
		local lord = S.Bosses.landBoss(lordDef, CF(castle.courtyard + V(0, 1, -10)), level + 3, lordName)
		lord.tags[lordTag] = true
		lord.onDie = function()
			run.cleared[lordTag] = true
			D.save()
		end
		task.spawn(function()
			D.waitNear(castle.courtyard, 60)
			if S.Entities.isAlive(lord) then
				D.bossBar(lord)
				D.music("Boss")
				D.waitUntil(function()
					return not S.Entities.isAlive(lord)
				end, nil, 0.5)
				D.bossBar(nil)
				D.music("Calm")
			end
		end)
	end
	-- dungeon entrance
	S.PlayerService.prompt(plan.dungeon.door or refs.exitSeal, "Enter", "Dungeon of " .. info.short, function(player)
		if player == D.leader() and not Ch.inDungeon then
			Ch.inDungeon = true
			local ok, err = pcall(dungeon, D, refs, L, rng, level)
			if not ok then
				warn("[World] dungeon error: " .. tostring(err))
			end
			Ch.inDungeon = false
			D.objective(if run.cleared[lordTag] then "Travel onward" else "Defeat the Lord of " .. info.short, info.name)
		end
	end, { dist = 12 })
	-- lava lands hurt
	local hazard = true
	if info.biome == "Volcanic" then
		task.spawn(function()
			while hazard do
				for _, e in S.Entities.players() do
					local p = S.Entities.position(e)
					if p.Y < 5 then
						S.Combat.hit(nil, e, { dmg = 12, kb = V(0, 60, 0), attackType = "true", kind = "lava", pos = p, noDefer = true })
					end
				end
				task.wait(0.5)
			end
		end)
	end
	S.Quests.give({ id = lordTag, title = "The Lord of " .. info.short, text = "Defeat the lord in his fortress to unseal the road onward.", kind = "tag", tag = lordTag, total = 1, reward = { gold = 500 * L, xp = 1500 * L, rarity = "Legendary" } })
	if run.cleared[lordTag] then
		S.Quests.complete(lordTag)
	end
	-- main loop
	D.objective("Defeat the Lord of " .. info.short, "Visit " .. info.town .. " first")
	D.marker(castle and castle.gate or refs.exitPos, "Fortress")
	while not run.cleared[lordTag] and not Ch.travelTo do
		task.wait(0.5)
	end
	if not Ch.travelTo then
		if refs.exitSeal and refs.exitSeal.Parent then
			refs.exitSeal:Destroy()
		end
		Net.fireAll("Notify", { kind = "level", text = "THE ROAD IS OPEN", sub = "The gate north of " .. info.short .. " is unsealed." })
		D.objective("Travel onward", "Through the gate in the north")
		D.marker(refs.exitPos + V(0, 8, 0), "Gate")
		local went = false
		local nextName = if run.flags.epilogue and L >= 5 then b.lands[2].name else b.lands[L + 1].name
		S.PlayerService.prompt(refs.exitFilm, "Travel", nextName, function(player)
			if player == D.leader() then
				went = true
			end
		end, { dist = 14 })
		while not went and not Ch.travelTo do
			task.wait(0.3)
		end
		if went then
			run.land = L + 1
		end
	end
	hazard = false
	if Ch.travelTo then
		run.land = Ch.travelTo
		Ch.travelTo = nil
	end
	D.marker(nil)
	D.save()
end

function Ch.run(D)
	local run = S.State.run
	run.land = run.land or 1
	while true do
		local L = run.land
		if L == -1 then
			run.land = 1
			return D.restartStory(false)
		end
		if L >= 6 then
			if not run.flags.epilogue then
				return "Tower"
			end
			-- after the end the road loops back to the first open land
			run.land = 2
			L = 2
		end
		if L == 1 then
			land1(D)
		else
			land(D, L)
		end
	end
end

return Ch
