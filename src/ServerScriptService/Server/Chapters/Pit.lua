--!nonstrict
-- CHAPTER 3: The Abyss. Five layers up. The sword, the awakening, the tutorial,
-- the run's own random fauna, a random miniboss on layer 3, the Pit Warden on 5.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Weapons = require(Shared.Weapons)
local Enemies = require(Shared.Enemies)
local RNG = require(Shared.RNG)
local Kit = require(Shared.Kit)
local Beasts = require(Shared.Beasts)
local S = require(script.Parent.Parent.S)

local Ch: any = {}
local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB

-- Five layers up to the surface. Every layer has its own fauna from the run's
-- bestiary (trait monsters, tougher the higher you climb); crawlers are the only
-- fixed monster. Layer 3 hides a random miniboss, layer 5 the Pit Warden.
Ch.FLOORS = {
	{ count = 9, tiers = { 1, 1 }, crawlers = 5, species = 2, theme = 1 },
	{ count = 11, tiers = { 1, 2 }, crawlers = 3, species = 3, theme = 2 },
	{ count = 12, tiers = { 2, 3 }, crawlers = 0, species = 3, theme = 5, miniboss = true, big = true },
	{ count = 14, tiers = { 3, 4 }, crawlers = 0, species = 3, theme = 3 },
	{ count = 15, tiers = { 3, 5 }, crawlers = 2, species = 3, theme = 4, warden = true, big = true },
}
Ch.LAYERS = #Ch.FLOORS

local function monsterLevel(floor: number): number
	return floor * 2 - 1
end

-- the species that live on a floor (stable per seed)
function Ch.fauna(D, floor: number)
	local cfg = Ch.FLOORS[floor]
	local roster = Beasts.roster(D.seed(), 20)
	local rng = RNG.new(D.seed()):fork("fauna", floor)
	local list, used = {}, {}
	for _ = 1, cfg.species do
		local sp = Beasts.pick(roster, rng, cfg.tiers[1], cfg.tiers[2], function(d)
			return not used[d]
		end)
		if sp and not used[sp] then
			used[sp] = true
			table.insert(list, sp)
		end
	end
	return list
end

local function populate(D, refs, floor, rng)
	local cfg = Ch.FLOORS[floor]
	local tag = "floor" .. floor
	local level = monsterLevel(floor)
	local points = rng:shuffle(table.clone(refs.spawnPoints))
	local i = 1
	local function nextPoint()
		local p = points[((i - 1) % #points) + 1] + V(rng:float(-3, 3), 0, rng:float(-3, 3))
		i += 1
		return p
	end
	for _ = 1, cfg.crawlers do
		S.AI.spawn("Crawler", CF(nextPoint()) * CFrame.Angles(0, rng:angle(), 0), { level = level, tags = { [tag] = true, pit = true }, aggro = 85 })
	end
	local fauna = Ch.fauna(D, floor)
	local left = cfg.count - cfg.crawlers
	local k = 0
	while left > 0 and #fauna > 0 do
		k += 1
		local sp = fauna[((k - 1) % #fauna) + 1]
		local p = nextPoint()
		local pack = if sp.swarm then 3 else 1
		for j = 1, pack do
			S.AI.spawn(sp, CF(p + V((j - 1) * 2.5, (if sp.hover then 3 else 0), 0)) * CFrame.Angles(0, rng:angle(), 0), { level = level, tags = { [tag] = true, pit = true }, aggro = 90, rng = rng })
		end
		left -= pack
	end
	for j, cf in refs.chestSpots do
		if j <= 3 then
			local special = nil
			if floor == 1 and j == 1 then
				special = require(Shared.Gear).unique("PitRags", 1)
			elseif floor == 2 and j == 1 then
				special = require(Shared.Gear).roll(rng, 4, { base = "NasalHelm", rarity = "Uncommon" })
			elseif floor == 4 and j == 1 then
				special = require(Shared.Gear).roll(rng, 7, { base = "RoundShield", rarity = "Rare" })
			end
			S.Loot.chest(nil, cf, if floor >= 3 or j == 1 and floor >= 2 then "iron" else "wood", { level = level + 1, item = special })
		end
	end
end

local function tutorial(D, refs, rng)
	local b = D.bible()
	D.lock(true, true, true)
	D.say(D.lines("pit_wake"))
	D.lock(false, true, true)
	-- the sword and its previous owner
	local deco = S.World.sub("Pit")
	local sp = refs.swordPos
	if not refs.skeleton then
		for i = 1, 5 do
			S.World.deco(deco, V(0.4, 0.4, 2), CF(sp + V(-2 + i * 0.6, 0.2, 1.5)) * CFrame.Angles(0, i, 0), rgb(225, 220, 200))
		end
		S.World.deco(deco, V(1.2, 1, 1.2), CF(sp + V(-2.5, 0.5, 0.5)), rgb(235, 230, 214))
	end
	local item = Weapons.unique("PitBlade", 1)
	local sword = Weapons.buildModel(item)
	for _, p in sword:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
		end
	end
	sword:PivotTo(CF(sp + V(0, 0.4, 0)) * CFrame.Angles(0, 0.5, math.pi / 2))
	sword.Parent = deco
	local beam = S.World.deco(deco, V(0.8, 30, 0.8), CF(sp + V(0, 15, 0)), rgb(200, 180, 255), Enum.Material.Neon, { Transparency = 0.78 })
	Kit.pointLight(beam, rgb(200, 180, 255), 18, 2)
	D.objective("Take the sword")
	D.marker(sp + V(0, 2, 0), "???")
	D.waitPrompt(sword.PrimaryPart, "Take", "Old sword")
	D.marker(nil)
	beam:Destroy()
	sword:Destroy()
	D.say(D.lines("pit_sword"), { auto = 2.5 })
	D.giveAll(function(p, prof)
		S.State.addItem(p, table.clone(item), true)
		S.State.equip(p, item.id)
	end)
	D.lock(true, true, false)
	-- something behind you
	local leader = D.leader()
	local char = leader and leader.Character
	local pe = D.playerEntity()
	local me = char and char:GetPivot() or refs.spawnCF
	local behind = me.Position - me.LookVector * 6 + V(0, 0.5, 0)
	local crawler = S.AI.spawn("Crawler", CFrame.lookAt(behind, me.Position), { level = 1, tags = { tutorial = true }, aggro = 200, noDrop = true })
	local brain = crawler.brain
	brain.scripted = true
	crawler.model:SetAttribute("ActW", 3)
	crawler.model:SetAttribute("ActA", 0.2)
	crawler.model:SetAttribute("ActR", 0.3)
	crawler.model:SetAttribute("ActT0", workspace:GetServerTimeNow() - 1.2)
	crawler.model:SetAttribute("Act", "ClawR")
	task.wait(0.3)
	S.TimeStop.start(pe, 999, { scripted = true })
	D.scene("face", { pos = behind + V(0, 1.5, 0) })
	task.wait(1.2)
	D.say({
		{ speaker = "", text = "Your ability awakened on its own." },
		{ speaker = "", text = "Time is frozen. Nothing moves but you." },
		{ speaker = "You", text = "...It was about to kill me." },
	}, { auto = 2.4 })
	D.tutorial("When it attacks, PARRY", "RMB")
	S.TimeStop.stop()
	crawler.model:SetAttribute("Act", nil)
	-- v3 kept you locked here (no movement, no parry): you are free now
	D.lock(false, false, false)
	-- a slow, harmless attack until the player parries it
	crawler.dmg = 0
	local parried = false
	local origParried = brain.onParried
	brain.onParried = function(self, by, info)
		parried = true
		origParried(self, by, info)
		crawler.stunUntil = os.clock() + 6
		crawler.riposteUntil = os.clock() + 6
	end
	brain.def = table.clone(brain.def)
	brain.def.attacks = { Enemies.atk(Enemies.A.claw, { id = "Tut", w = 1.4, a = 0.15, r = 0.6, cd = 1.2, range = 8 }) }
	brain.target = pe
	brain.scripted = false
	local tries = 0
	D.waitUntil(function()
		tries += 1
		return parried
	end, 60, 0.1)
	if parried then
		D.tutorial("Parried! Now STRIKE", "LMB")
		if crawler.hum then
			crawler.hum.Health = 1
		end
	else
		D.tutorial("Just hit it", "LMB")
	end
	D.lock(false, false, false)
	D.waitUntil(function()
		return not S.Entities.isAlive(crawler)
	end, 60, 0.1)
	if S.Entities.isAlive(crawler) then
		S.Combat.kill(crawler, pe, {})
	end
	D.tutorial("More are coming...", nil, 2.5)
	task.wait(1.5)
	-- a small rush from the tunnels: real spawn points (v3 dropped them at fixed
	-- offsets, sometimes inside the rock, so one could never be reached)
	local pts = table.clone(refs.spawnPoints)
	table.sort(pts, function(a, b)
		return (a - me.Position).Magnitude < (b - me.Position).Magnitude
	end)
	for i = 1, math.min(4, #pts) do
		S.AI.spawn("Crawler", CF(pts[i] + V(0, 1, 0)), { level = 1, tags = { floor1 = true, pit = true }, aggro = 200 })
	end
	D.tutorial("Hold LMB for a HEAVY attack that launches enemies", "LMB", 5)
	task.delay(6, function()
		D.tutorial("Press Q to STOP TIME. Every hit lands the moment time resumes.", "Q", 7)
	end)
	task.delay(14, function()
		D.tutorial("SHIFT dash (dash THROUGH enemies to stab them)  ·  CTRL slide / slam  ·  SPACE twice to double jump", nil, 7)
	end)
	task.delay(21, function()
		D.tutorial("R: healing flask  ·  I: inventory  ·  K: spend level-up points", nil, 6)
	end)
	S.State.run.flags.gotSword = true
end

function Ch.run(D)
	local run = S.State.run
	local start = math.clamp(run.flags.pitFloor or 1, 1, Ch.LAYERS)
	D.music("Combat")
	D.lock(true, true, not run.flags.gotSword)
	-- make sure you have a weapon on a continue
	if run.flags.gotSword then
		D.giveAll(function(p, prof)
			if #prof.inventory == 0 then
				local it = Weapons.unique("PitBlade", 1)
				S.State.addItem(p, it, true)
			end
		end)
	end
	for floor = start, Ch.LAYERS do
		local cfg = Ch.FLOORS[floor]
		run.flags.pitFloor = floor
		D.save()
		local rng = RNG.new(D.seed()):fork("pitfloor", floor)
		D.fade("black", 0.3)
		D.clearActors()
		S.Entities.clearNPCs()
		S.WorldPit.clear()
		local refs = S.WorldPit.build({ level = if floor == 1 then 1 else floor * 2, seed = D.seed(), big = cfg.big, theme = S.WorldPit.THEMES[cfg.theme] })
		D.zone("pit", "THE ABYSS  -  LAYER " .. floor .. " OF " .. Ch.LAYERS, refs.theme.name)
		D.spawnPlayers(refs.spawnCF)
		D.checkpoint(refs.spawnCF)
		D.fade("clear", 0.8)
		if floor == 1 and not run.flags.gotSword then
			tutorial(D, refs, rng)
		else
			D.lock(false, false, false)
		end
		populate(D, refs, floor, rng)
		local boss = nil
		local level = monsterLevel(floor)
		if cfg.miniboss and refs.bossCenter then
			local def = Beasts.boss(rng, level, { miniboss = true, hpMult = 5 })
			boss = S.AI.spawn(def, CF(refs.bossCenter + V(0, 3, 0)), { level = level + 1, tags = { ["floor" .. floor] = true, pit = true }, aggro = 70, rng = rng })
			if boss then
				D.bossBar(boss, string.upper(def.name))
			end
		elseif cfg.warden and refs.bossCenter then
			boss = S.Bosses.warden(CF(refs.bossCenter), level + 1)
			boss.tags["floor" .. floor] = true
		end
		D.marker(refs.exitCenter + V(0, 8, 0), "Seal")
		if cfg.warden then
			D.objective("Reach the top of the Abyss")
			D.waitNear(refs.bossCenter, 34)
			D.lock(true, true, false)
			D.bossBar(boss, "THE PIT WARDEN")
			D.say(D.lines("warden"), { cam = { follow = boss.model, offset = V(12, 6, 18), lookY = 5, fov = 55 } })
			D.lock(false, false, false)
			D.music("Boss")
		end
		D.waitKills("floor" .. floor, "Slay the monsters of layer " .. floor)
		if boss then
			D.bossBar(nil)
		end
		if cfg.warden then
			D.say(D.lines("warden_dead"), { auto = 2.2 })
		end
		if refs.barrier and refs.barrier.Parent then
			Net.fireAll("FX", "Flash", { pos = refs.barrier.Position, color = refs.theme.glow, size = 20, t = 0.6 })
			refs.barrier:Destroy()
		end
		D.objective(if floor < Ch.LAYERS then "Climb to layer " .. (floor + 1) else "Break out")
		D.marker(refs.exitCenter + V(0, 8, 0), "Ascend")
		D.waitPrompt(refs.portalFilm, "Ascend", if floor < Ch.LAYERS then "Layer " .. (floor + 1) else "The surface")
		D.marker(nil)
		D.heal()
		Net.fireAll("Notify", { kind = "info", text = "Flasks refilled" })
	end
	run.flags.pitFloor = nil
	run.flags.pitDone = true
	S.WorldPit.clear()
	S.Entities.clearNPCs()
	return "Breakout"
end

return Ch
