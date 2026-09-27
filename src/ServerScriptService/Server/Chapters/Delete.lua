--!nonstrict
-- ENDING ROUTE: DELETE. The god gathers what is left of every land into the
-- Evil Lands, one land at a time. You erase all of it. Then the world goes.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local RNG = require(Shared.RNG)
local Rig = require(Shared.Rig)
local Story = require(Shared.Story)
local S = require(script.Parent.Parent.S)

local Ch: any = {}
local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB

local RACES = {
	Meadow = { "Human", "Human", "Beastkin" },
	Evil = { "Demon", "Human", "Undead" },
}

function Ch.run(D)
	local run = S.State.run
	local b = D.bible()
	local rng = RNG.new(D.seed()):fork("delete")
	local refs = S.Chapters.Tower.ensureLand6(D)
	local center = refs.town.center
	run.deleteMode = true
	D.look("awakened")
	D.spawnPlayers(CFrame.lookAt(center + V(0, 4, 36), center + V(0, 4, 0)))
	D.checkpoint(CFrame.lookAt(center + V(0, 4, 36), center + V(0, 4, 0)))
	S.Entities.clearNPCs()
	D.zone("Evil", "DELETE", "Every living thing.")
	D.music("Silence")
	D.lock(false, false, false)
	D.deathHandler = function(player)
		S.PlayerService.spawn(player, S.PlayerService.checkpoint)
		local prof = S.State.profile(player)
		prof.flasks = prof.maxFlasks
		S.State.sync(player)
		return true
	end
	local start = run.flags.deleteWave or 1
	local total = #b.lands
	for L = start, total do
		run.flags.deleteWave = L
		local info = b.lands[L]
		local binfo = Story.BIOME_INFO[info.biome] or Story.BIOME_INFO.Meadow
		local level = (info.level or L * 8) + (run.ngPlus or 0) * 20
		local tag = "delete" .. L
		D.title("WHAT IS LEFT OF", string.upper(info.name), 3)
		Net.fireAll("FX", "Shout", { target = D.leaderChar(), text = b.god .. ": Here you go. Don't miss any.", dur = 3 })
		task.wait(1.5)
		-- the people
		local races = binfo.races or RACES[info.biome] or { "Human" }
		for i = 1, 6 do
			local p = center + V(rng:float(-40, 40), 3, rng:float(-40, 40))
			local look = Rig.randomLook(rng, rng:pick(races), rng:pick({ "peasant", "peasant", "merchant", "noble" }))
			look.mood = "scared"
			Net.fireAll("FX", "Teleport", { to = p, color = rgb(255, 255, 255) })
			S.NPCs.townsfolk(look, CF(p), {
				name = Story.personName(rng, look.race == "Beastkin"),
				level = level,
				tags = { [tag] = true, npc = true },
				fightBack = rng:chance(0.5),
				talk = { { speaker = "", text = rng:pick({ "Please. I have a family.", "What did we ever do to you?", "The god said you'd come.", "...Make it quick." }) } },
			})
		end
		-- the monsters
		for i = 1, 5 + L do
			local p = center + V(rng:float(-55, 55), 4, rng:float(-55, 55))
			Net.fireAll("FX", "Teleport", { to = p, color = rgb(255, 255, 255) })
			S.AI.spawn(rng:pick(binfo.monsters), CF(p), { level = level, tags = { [tag] = true }, aggro = 200, leash = 400 })
		end
		D.waitKills(tag, "Delete every living thing  -  " .. info.short)
		local pct = math.floor(L / total * 100)
		Net.fireAll("Notify", { kind = "level", text = pct .. "% OF ALL LIFE DELETED", sub = info.name .. " is empty." })
		D.save()
		task.wait(2)
	end
	D.deathHandler = nil
	run.flags.deleteWave = nil
	-- and then the world
	D.lock(true, true, false)
	D.say({
		{ speaker = b.god, text = "Last one. Oh, that was beautiful. Not a single survivor." },
		{ speaker = b.god, text = "Now. The furniture." },
	}, { auto = 2.6 })
	D.scene("glitch", { dur = 4 })
	D.scene("delete", {})
	D.shake(3, 6)
	task.wait(6)
	D.zone("void")
	D.say({ { speaker = "You", text = "..." } }, { auto = 2.5 })
	D.ending("delete", true)
	run.deleteMode = false
	return D.restartStory(false)
end

return Ch
