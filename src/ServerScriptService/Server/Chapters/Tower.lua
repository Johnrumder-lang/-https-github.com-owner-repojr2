--!nonstrict
-- CHAPTER 9: The Evil Lands and the Endless Tower. The spared king keeps his
-- word - or his son comes for revenge. Then up, past the sky, into space.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local RNG = require(Shared.RNG)
local Enemies = require(Shared.Enemies)
local Story = require(Shared.Story)
local Weapons = require(Shared.Weapons)
local Util = require(Shared.Util)
local S = require(script.Parent.Parent.S)

local Ch: any = {}
local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB

local Rig = require(Shared.Rig)
local function Rig_randomLook(rng)
	local d = Rig.randomLook(rng, rng:pick({ "Human", "Beastkin", "Demon" }), "peasant")
	d.mood = "scared"
	return d
end

function Ch.ensureLand6(D)
	return D.ensure("land6", function()
		local r = S.WorldLand.build(6, D.bible(), D.seed())
		-- the plan already knows the exact height of the flattened ground
		r.tower = S.WorldTower.build(r.plan.tower.pos)
		return r
	end)
end

function Ch.run(D)
	local run = S.State.run
	local b = D.bible()
	local info = b.lands[6]
	local rng = RNG.new(D.seed()):fork("evil")
	local refs = Ch.ensureLand6(D)
	local plan = refs.plan
	local tower = refs.tower
	local level = 44 + (run.ngPlus or 0) * 20
	local pool = Story.BIOME_INFO.Evil.monsters
	run.waystones[6] = true
	run.land = 6
	D.zone("Evil", "THE EVIL LANDS", "Where evil rules everything.")
	D.music("Combat")
	D.look("awakened")
	if not run.flags.towerStop then
		D.spawnPlayers(refs.entry)
		D.checkpoint(CFrame.new(refs.town.center + V(0, 4, 0)))
		D.lock(false, false, false)
		-- the last town: a handful of survivors
		for i = 1, 5 do
			local look = Rig_randomLook(rng)
			S.NPCs.townsfolk(look, CF(refs.town.center + V(rng:float(-20, 20), 3, rng:float(-20, 20))), {
				name = Story.personName(rng),
				talk = { { speaker = "", text = rng:pick({ "The tower eats the sky. Nobody who climbs it comes down.", "Last Light is the last light. That's the whole joke.", "Something up there has been laughing for a thousand years.", "The demons don't sleep. We take turns." }) } },
				level = level,
				tags = { town6 = true, npc = true },
			})
		end
		local mlook = Rig_randomLook(rng)
		mlook.outfit = "merchant"
		local m = S.NPCs.townsfolk(mlook, refs.town.merchant, { name = "Grimwick the Last Merchant", stationary = true, level = level, tags = { town6 = true, npc = true } })
		S.Loot.merchant(m.model, "Grimwick", level)
		-- demon camps and roaming horrors
		for _, c in plan.camps do
			if not run.cleared[c.id] then
				local g = c.ground or c.pos
				for i = 1, rng:int(7, 10) do
					S.AI.spawn(rng:pick(pool), CF(g + V(rng:float(-18, 18), 4, rng:float(-18, 18))), { level = level, tags = { [c.id] = true }, aggro = 80, leash = 200 })
				end
				if c.chest then
					S.Loot.chest(nil, c.chest, "gold", { level = level, id = c.id .. "_chest" })
				end
			end
		end
		for i = 1, 3 do
			local p = if #plan.wilds > 0 then plan.wilds[(i - 1) % #plan.wilds + 1] + V(0, 4, 0) else V(rng:float(-plan.half + 200, plan.half - 200), 20, rng:float(-plan.half + 300, plan.half - 350))
			S.AI.spawn(Enemies.elite(rng:pick(pool), rng), CF(p), { level = level + 3, tags = { evilElite = true }, aggro = 100, wanderRadius = 60 })
		end
		-- the king's promise, or his son's revenge
		D.objective("Reach the Endless Tower")
		D.marker(tower.doorFront.Position + V(0, 20, 0), "The Endless Tower")
		D.waitNear(tower.doorFront.Position, 70)
		D.marker(nil)
		if run.flags.kingSpared and not run.flags.relicGiven then
			D.lock(true, true, false)
			local kcf = CFrame.lookAt(tower.doorFront.Position + V(-8, 0, 10), tower.doorFront.Position)
			local king = D.actor(S.Chapters.Summoning.kingLook(b), kcf, { anchored = true, weapon = "scepter" })
			for i = 1, 4 do
				D.actor(Enemies.LOOKS.knight(rng), kcf * CF(i * 4 - 10, 0, 6), { anchored = true, pose = "Guard", weapon = "halberd" })
			end
			D.say(D.lines("tower_base_spared"), { cam = { cf = CFrame.lookAt(kcf.Position + kcf.LookVector * 10 + V(3, 2, 0), kcf.Position + V(0, 1.6, 0)), fov = 50 } })
			local relic = Weapons.unique("RoyalRelic", level)
			local signet = require(Shared.Gear).unique("KingsSignet", level)
			D.giveAll(function(p, prof)
				S.State.addItem(p, table.clone(relic))
				S.State.addItem(p, table.clone(signet))
			end)
			run.flags.relicGiven = true
			D.lock(false, false, false)
		elseif run.flags.kingKilled and not run.flags.princeDead then
			D.lock(true, true, false)
			local prince = S.Bosses.prince(CFrame.lookAt(tower.doorFront.Position + V(0, 0, 20), tower.doorFront.Position + V(0, 0, 60)), level + 4)
			D.say(D.lines("tower_base_killed"), { cam = { follow = prince.model, offset = V(8, 3, 12), fov = 50 } })
			D.bossBar(prince, "PRINCE ALARIC, AVENGER OF " .. string.upper(b.kingdom))
			D.lock(false, false, false)
			D.music("Boss")
			D.waitUntil(function()
				return not S.Entities.isAlive(prince)
			end, nil, 0.3)
			D.bossBar(nil)
			run.flags.princeDead = true
		end
		D.objective("Enter the Endless Tower")
		D.marker(tower.doorFront.Position + V(0, 8, 0), "Enter")
		D.waitPrompt(tower.door, "Enter", "The Endless Tower")
		D.marker(nil)
		run.flags.towerStop = 1
		D.save()
	end

	-- the climb
	local startStop = run.flags.towerStop or 1
	for i = startStop, #tower.stops - 1 do
		run.flags.towerStop = i
		local stop = tower.stops[i]
		D.fade("black", 0.4)
		S.Entities.clearNPCs("npc")
		D.spawnPlayers(stop.spawn)
		D.checkpoint(stop.spawn)
		D.zone("tower", "ALTITUDE " .. Util.fmt(stop.height), "Stop " .. i .. " of " .. (#tower.stops - 1))
		D.fade("clear", 0.6)
		D.lock(false, false, false)
		local tag = "tower" .. i
		task.wait(1.5)
		for w = 1, 2 do
			for j = 1, 4 + i do
				local p = stop.center + V(rng:float(-30, 30), 3, rng:float(-30, 30))
				Net.fireAll("FX", "Teleport", { to = p, color = rgb(255, 30, 50) })
				S.AI.spawn(rng:pick(pool), CF(p), { level = level + i, tags = { [tag] = true }, aggro = 200 })
			end
			if w == 2 and (i == 3 or i == 5 or i == 7) then
				local e = S.AI.spawn(Enemies.elite(rng:pick(pool), rng), CF(stop.center + V(0, 3, 0)), { level = level + i + 2, tags = { [tag] = true }, aggro = 200 })
				D.bossBar(e)
			end
			D.waitKills(tag, "Survive the tower  -  wave " .. w .. " / 2")
			D.bossBar(nil)
		end
		D.heal()
		local nxt = tower.stops[i + 1]
		D.objective("Ascend")
		D.lock(true, true, false)
		D.scene("ascend", { from = stop.center, to = nxt.center, dur = 6, center = tower.base, radius = 150 })
		task.wait(6)
		D.save()
	end
	run.flags.towerStop = nil
	local top = tower.top
	D.fade("black", 0.3)
	D.spawnPlayers(top.spawn)
	D.checkpoint(top.spawn)
	D.zone("space", "THE TOP OF THE WORLD", "Altitude 10,000")
	D.fade("clear", 1.2)
	D.lock(false, false, false)
	Ch.top = top
	return "Finale"
end

return Ch
