--!nonstrict
-- CHAPTER 3: The Abyss. Ten floors up. The sword, the awakening, the tutorial,
-- hordes, a miniboss on floor 5 and the Pit Warden on floor 10.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Weapons = require(Shared.Weapons)
local Enemies = require(Shared.Enemies)
local RNG = require(Shared.RNG)
local Kit = require(Shared.Kit)
local S = require(script.Parent.Parent.S)

local Ch: any = {}
local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB

local POOLS = {
	{ { "Crawler", 8 } },
	{ { "Crawler", 8 }, { "Ghoul", 2 } },
	{ { "Crawler", 6 }, { "Ghoul", 4 }, { "Slime", 1 } },
	{ { "Ghoul", 6 }, { "Crawler", 4 }, { "BoneArcher", 2 }, { "Slime", 2 } },
	{ { "Ghoul", 5 }, { "Crawler", 5 }, { "BoneArcher", 3 }, { "Slime", 2 } },
	{ { "Ghoul", 6 }, { "BoneArcher", 4 }, { "Shade", 3 }, { "PitBrute", 1 }, { "Crawler", 4 } },
	{ { "Ghoul", 6 }, { "Shade", 4 }, { "BoneArcher", 4 }, { "PitBrute", 2 }, { "Slime", 2 } },
	{ { "Ghoul", 8 }, { "Shade", 4 }, { "BoneArcher", 4 }, { "PitBrute", 2 }, { "Crawler", 6 } },
	{ { "Ghoul", 8 }, { "Shade", 5 }, { "BoneArcher", 5 }, { "PitBrute", 3 }, { "Crawler", 6 } },
	{ { "Crawler", 6 }, { "Ghoul", 4 } },
}

local function populate(D, refs, floor, rng)
	local tag = "floor" .. floor
	local points = rng:shuffle(table.clone(refs.spawnPoints))
	local i = 1
	for _, entry in POOLS[floor] do
		for _ = 1, entry[2] do
			local p = points[((i - 1) % #points) + 1] + V(rng:float(-3, 3), 0, rng:float(-3, 3))
			i += 1
			S.AI.spawn(entry[1], CF(p) * CFrame.Angles(0, rng:angle(), 0), { level = floor, tags = { [tag] = true, pit = true }, aggro = 85 })
		end
	end
	for j, cf in refs.chestSpots do
		if j <= 3 then
			local special = nil
			if floor == 1 and j == 1 then
				special = require(Shared.Gear).unique("PitRags", 1)
			elseif floor == 4 and j == 1 then
				special = require(Shared.Gear).roll(rng, 4, { base = "NasalHelm", rarity = "Uncommon" })
			elseif floor == 7 and j == 1 then
				special = require(Shared.Gear).roll(rng, 7, { base = "RoundShield", rarity = "Rare" })
			end
			S.Loot.chest(nil, cf, if floor >= 6 or j == 1 and floor >= 3 then "iron" else "wood", { level = floor, item = special })
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
	-- a small rush from the tunnels
	for i = 1, 4 do
		local off = CFrame.Angles(0, i * 1.57, 0) * V(0, 0, 26)
		S.AI.spawn("Crawler", CF(me.Position + off + V(0, 2, 0)), { level = 1, tags = { floor1 = true, pit = true }, aggro = 200 })
	end
	D.tutorial("Hold LMB for a HEAVY attack that launches enemies", "LMB", 5)
	task.delay(6, function()
		D.tutorial("Press Q to STOP TIME. Every hit lands the moment time resumes.", "Q", 7)
	end)
	task.delay(14, function()
		D.tutorial("SHIFT dash  ·  CTRL slide  ·  SPACE twice to double jump", nil, 6)
	end)
	task.delay(21, function()
		D.tutorial("R: healing flask  ·  TAB: inventory & level-up points", nil, 6)
	end)
	S.State.run.flags.gotSword = true
end

function Ch.run(D)
	local run = S.State.run
	local b = D.bible()
	local start = run.flags.pitFloor or 1
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
	for floor = start, 10 do
		run.flags.pitFloor = floor
		D.save()
		local rng = RNG.new(D.seed()):fork("pitfloor", floor)
		D.fade("black", 0.3)
		D.clearActors()
		S.Entities.clearNPCs()
		S.WorldPit.clear()
		local refs = S.WorldPit.build({ level = floor, seed = D.seed(), big = floor == 5 or floor == 10 })
		D.zone("pit", "THE ABYSS  -  FLOOR " .. floor, refs.theme.name)
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
		if floor == 5 then
			boss = S.AI.spawn("Gnasher", CF(refs.bossCenter), { level = 5, tags = { floor5 = true, pit = true }, aggro = 60 })
			D.bossBar(boss)
		elseif floor == 10 then
			boss = S.Bosses.warden(CF(refs.bossCenter), 10)
			boss.tags.floor10 = true
		end
		D.marker(refs.exitCenter + V(0, 8, 0), "Seal")
		if floor == 10 then
			D.objective("Reach the top of the Abyss")
			D.waitNear(refs.bossCenter, 34)
			D.lock(true, true, false)
			D.bossBar(boss, "THE PIT WARDEN")
			D.say(D.lines("warden"), { cam = { follow = boss.model, offset = V(12, 6, 18), lookY = 5, fov = 55 } })
			D.lock(false, false, false)
			D.music("Boss")
		end
		D.waitKills("floor" .. floor, "Slay the monsters of floor " .. floor)
		if boss then
			D.bossBar(nil)
		end
		if floor == 10 then
			D.say(D.lines("warden_dead"), { auto = 2.2 })
		end
		if refs.barrier and refs.barrier.Parent then
			Net.fireAll("FX", "Flash", { pos = refs.barrier.Position, color = refs.theme.glow, size = 20, t = 0.6 })
			refs.barrier:Destroy()
		end
		D.objective(if floor < 10 then "Ascend to floor " .. (floor + 1) else "Break out")
		D.marker(refs.exitCenter + V(0, 8, 0), "Ascend")
		D.waitPrompt(refs.portalFilm, "Ascend", if floor < 10 then "Floor " .. (floor + 1) else "The surface")
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
