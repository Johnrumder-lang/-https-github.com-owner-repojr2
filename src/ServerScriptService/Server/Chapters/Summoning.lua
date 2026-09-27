--!nonstrict
-- CHAPTER 2: Summoned by a kingdom, appraised as garbage, thrown into the Abyss.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Palette = require(Shared.Palette)
local RNG = require(Shared.RNG)
local Enemies = require(Shared.Enemies)
local S = require(script.Parent.Parent.S)

local Ch: any = {}
local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB

function Ch.kingLook(b)
	return { name = "King " .. b.king, race = "Human", outfit = "king", skin = rgb(240, 200, 170), hair = rgb(200, 200, 206), hairStyle = "short", beard = "full", mood = "smug", scale = 1.08 }
end

function Ch.archmageLook(b)
	local look = table.clone(S.Bosses.ARCHMAGE_DEF.look)
	look.name = b.archmage
	return look
end

function Ch.run(D)
	local b = D.bible()
	local rng = RNG.new(D.seed()):fork("summon")
	D.lock(true, true, true)
	local refs = D.ensureCapital()
	D.zone("ritual")
	D.music("Calm")
	D.look(if S.State.run.flags.skippedPrologue then "night" else "night")
	-- give time stop if the prologue was skipped
	D.giveAll(function(p, prof)
		prof.abilities.timestop = true
	end)
	local c = refs.ritualCenter
	D.spawnPlayers(CFrame.lookAt(c + V(0, 3, 0), c + V(0, 3, -20)))
	D.checkpoint(CFrame.lookAt(c + V(0, 3, 0), c + V(0, 3, -20)))

	-- the court
	local mages = {}
	for _, cf in refs.mageSpots do
		local look = Enemies.LOOKS.royalMage(rng)
		look.name = "Court Mage"
		table.insert(mages, D.actor(look, cf, { anchored = true, pose = "Channel", weapon = "staff" }))
	end
	local nobles = {}
	for _, cf in refs.nobleSpots do
		local look = if rng:chance(0.4) then Enemies.LOOKS.beastVillager(rng) else Enemies.LOOKS.villager(rng)
		look.outfit = "noble"
		look.mood = "neutral"
		look.shirt = rng:pick({ rgb(120, 40, 60), rgb(40, 60, 120), rgb(60, 100, 60), rgb(110, 90, 40) })
		look.accent = Palette.metal.gold
		table.insert(nobles, D.actor(look, cf, { anchored = true, pose = rng:pick({ "Crossed", "Talk" }) }))
	end
	local guards = {}
	for _, cf in refs.guardSpots do
		local look = Enemies.LOOKS.knight(rng)
		look.name = "Royal Guard"
		table.insert(guards, D.actor(look, cf, { anchored = true, pose = "Guard", weapon = "halberd" }))
	end
	local king = D.actor(Ch.kingLook(b), refs.kingSpot, { anchored = true, weapon = "scepter" })
	local archmage = D.actor(Ch.archmageLook(b), refs.archmageSpot, { anchored = true, weapon = "staff", pose = "Crossed" })

	-- wake on the circle
	D.fade("clear", 1.6)
	D.scene("blink", { times = 2 })
	D.cutscene({
		shots = {
			{ orbit = { center = c, r = 20, h = 6, a0 = 0.2, a1 = 1.6, lookY = 2 }, t = 4.2, fov = 60 },
			{ cf = CFrame.lookAt(c + V(0, 5, 2), refs.kingSpot.Position + V(0, 2, 0)), to = CFrame.lookAt(c + V(0, 6, -4), refs.kingSpot.Position + V(0, 2, 0)), t = 2.4, fov = 55 },
		},
		duration = 6.6,
	})
	local archCam = { cf = CFrame.lookAt(refs.archmageSpot.Position + refs.archmageSpot.LookVector * 9 + V(2, 1, 0), refs.archmageSpot.Position + V(0, 1.5, 0)), fov = 50 }
	local kingCam = { cf = CFrame.lookAt(refs.kingSpot.Position + refs.kingSpot.LookVector * 9 + V(-2, 1, 0), refs.kingSpot.Position + V(0, 1.5, 0)), fov = 50 }
	local lines = D.lines("summon")
	for i, l in lines do
		l.cam = if l.speaker:find("King") then kingCam elseif l.speaker == b.archmage then archCam else { cf = CFrame.lookAt(c + V(10, 5, 8), mages[1]:GetPivot().Position), fov = 55 }
	end
	for _, m in mages do
		m:SetAttribute("Pose", "Crossed")
	end
	D.say(lines)
	D.lock(false, true, true)
	D.objective("Place your hand on the crystal")
	D.marker(refs.crystal.Position + V(0, 2, 0), "Crystal")
	D.waitPrompt(refs.crystal, "Touch", "Appraisal Crystal")
	D.marker(nil)
	D.objective(nil)
	D.lock(true, true, true)
	Net.fireAll("FX", "Flash", { pos = refs.crystal.Position, color = rgb(170, 220, 255), size = 12, t = 0.8 })
	D.scene("appraisal", { power = b.power, dur = 8 })
	task.wait(8.2)
	local ap = D.lines("appraisal")
	for _, l in ap do
		l.cam = if l.speaker:find("King") then kingCam elseif l.speaker == b.archmage then archCam elseif l.speaker == "You" then { cf = CFrame.lookAt(c + V(6, 4, -6), c + V(0, 3, 0)), fov = 60 } else { cf = CFrame.lookAt(c + V(10, 5, 8), mages[1]:GetPivot().Position), fov = 55 }
	end
	for _, n in nobles do
		n:SetAttribute("Pose", "Talk")
	end
	S.NPCs.act(archmage, "Point", 0.1, 0.4, 1.2)
	D.say(ap)
	-- dragged to the trapdoor
	for i, g in guards do
		if i <= 2 then
			g.PrimaryPart.Anchored = false
			task.spawn(S.AI.walkTo, g, c + V(if i == 1 then -2 else 2, 3, 2), 14, 3)
		end
	end
	D.cutscene({
		shots = {
			{ cf = CFrame.lookAt(c + V(8, 3.5, 6), c + V(0, 3, 0)), t = 1.6, shake = 3, fov = 60 },
			{ cf = CFrame.lookAt(refs.trapdoor + V(0, 14, 6), refs.trapdoor), t = 1.6, fov = 70, fadeTo = "black", fadeTime = 0.5 },
		},
		duration = 3.3,
		skippable = false,
	})
	D.teleport(CF(refs.trapdoor + V(0, 3, 0)))
	D.cutscene({
		shots = {
			{ cf = CFrame.lookAt(refs.trapdoor + V(0, 2, 0), refs.trapdoor - V(0, 60, 0)), to = CFrame.lookAt(refs.trapdoor - V(0, 60, 0), refs.trapdoor - V(0, 120, 0)), t = 2.2, fov = 90, fromFade = 0.3, fadeTo = "black", fadeTime = 0.8, shake = 2 },
		},
		duration = 2.4,
		skippable = false,
		bars = false,
	})
	Net.fireAll("FX", "Text", { pos = refs.trapdoor, text = "AAAAAAA", color = rgb(255, 255, 255), size = 2 })
	D.clearActors()
	return "Pit"
end

return Ch
