--!nonstrict
-- CHAPTER 10: The top of the world. The cloaked one with the red eye farms aura
-- off every second you waste. He kneels, the hood falls back - he is you, colours
-- flipped. Black flame. The Strongest Abnormality. Its core shatters, it glitches
-- through every face in the world, and a very large, very kind foot comes down.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local RNG = require(Shared.RNG)
local Enemies = require(Shared.Enemies)
local Palette = require(Shared.Palette)
local Rig = require(Shared.Rig)
local Util = require(Shared.Util)
local Weapons = require(Shared.Weapons)
local S = require(script.Parent.Parent.S)

local Ch: any = {}
local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB

-- ------------------------------------------------------------------ helpers
-- The player's own look with every colour flipped.
local function invertedLook(player: Player?)
	local base = if player then S.PlayerService.describe(player, "awakened") else { outfit = "hero", skin = rgb(230, 190, 160), hair = rgb(40, 30, 24), shirt = rgb(24, 26, 34), pants = rgb(30, 30, 38), accent = rgb(120, 220, 255), glow = rgb(140, 230, 255) }
	local d = {}
	for k, v in base do
		if typeof(v) == "Color3" then
			d[k] = Palette.invert(v)
		else
			d[k] = v
		end
	end
	d.name = "The Hollow"
	d.player = nil
	d.mood = "hollow"
	d.glowEye = rgb(255, 20, 30)
	d.awakened = true
	d.health = 1000
	return d
end

-- Every face in the world, for the glitch.
local function randomWorldLook(rng)
	local r = rng:float()
	if r < 0.35 then
		local keys = {}
		for k in Enemies.LOOKS do
			table.insert(keys, k)
		end
		table.sort(keys)
		return Enemies.LOOKS[rng:pick(keys)](rng)
	elseif r < 0.7 then
		local ids = {}
		for id, def in Enemies.DEFS do
			if def.ai ~= "slime" and def.look then
				table.insert(ids, id)
			end
		end
		table.sort(ids)
		local look = Enemies.resolveLook(Enemies.DEFS[rng:pick(ids)], rng)
		look.scale = nil
		return look
	end
	local race = rng:pick({ "Human", "Beastkin", "Elf", "Goblin", "Orc", "Demon", "Lizard", "Undead" })
	return Rig.randomLook(rng, race, rng:pick({ "peasant", "merchant", "noble", "guard", "knight", "mage", "cultist", "barbarian" }))
end

local function waitFor(fn, timeout: number)
	local t0 = os.clock()
	while not fn() and os.clock() - t0 < timeout do
		task.wait(0.1)
	end
end

-- Lets any running time stop end (queued hits get applied), or ends it.
local function stopAllTime()
	waitFor(function()
		return not S.TimeStop.active
	end, 6)
	if S.TimeStop.active then
		S.TimeStop.stop()
	end
end

local function npcAct(model, anim: string)
	S.NPCs.act(model, anim, 0.1, 0.25, 0.6)
end

-- Puts a boss into "cutscene mode": no thinking, no damage.
local function freeze(e)
	if not e then
		return
	end
	e.invuln = true
	local b = e.brain
	if b then
		b.scripted = true
		if b.cancelAction then
			pcall(b.cancelAction, b)
		end
	end
	if e.hum then
		e.hum:Move(Vector3.zero)
	end
end

local function unfreeze(e)
	e.invuln = false
	if e.brain then
		e.brain.scripted = false
	end
end

local function clearHostiles()
	for _, e in S.Entities.alive(function(o)
		return o.kind ~= "player" and not o.tags.final
	end) do
		S.Combat.kill(e, nil, {})
	end
	S.Projectiles.clear()
end

local function reward(D, xp: number, gold: number, pos: Vector3?)
	for _, p in D.players() do
		S.State.addXP(p, xp)
	end
	if pos then
		S.Loot.goldBurst(pos, gold)
	end
end

local function lowHp(e)
	return function()
		if not S.Entities.isAlive(e) then
			return true
		end
		local hp = S.Entities.health(e)
		return hp <= 1.5
	end
end

-- ------------------------------------------------------------------ stages
local function hollowStage(D, top, level, rng)
	local b = D.bible()
	local run = S.State.run
	local c = top.center
	local leader = D.leader()
	D.lock(true, true, false)
	D.music("Final")
	local hcf = CFrame.lookAt(c + V(0, 3, -28), c + V(0, 3, 20))
	local hollow = S.Bosses.hollow(hcf, level)
	freeze(hollow)
	hollow.model:SetAttribute("Pose", "Crossed")
	-- a slow push-in on the cloaked figure
	D.cutscene({
		shots = {
			{ cf = CFrame.lookAt(c + V(30, 40, 40), c + V(0, 3, -28)), to = CFrame.lookAt(c + V(8, 6, -8), c + V(0, 4, -28)), t = 4.5, fov = 55, ease = "inOut" },
		},
		duration = 4.5,
	})
	D.say(D.lines("hollow_intro"), { cam = { follow = hollow.model, offset = V(4, 2.5, 10), lookY = 1.8, fov = 42 } })
	hollow.model:SetAttribute("Pose", nil)
	D.title("???", "The one at the top of the world", 3)
	D.bossBar(hollow, "???")
	D.lock(false, false, false)
	unfreeze(hollow)
	D.tutorial("He farms AURA from your mistakes. Parry him, don't trade blows.", nil, 7)
	D.deathHandler = function(player)
		S.PlayerService.spawn(player, top.spawn)
		local prof = S.State.profile(player)
		prof.flasks = prof.maxFlasks
		S.State.sync(player)
		if hollow.brain and hollow.brain.gainAura then
			hollow.brain:gainAura(10)
		end
		return true
	end
	D.waitUntil(lowHp(hollow), nil, 0.15)
	D.deathHandler = nil
	-- he's done: finish any stopped time first (queued hits cannot kill him)
	stopAllTime()
	freeze(hollow)
	clearHostiles()
	D.bossBar(nil)
	D.lock(true, true, false)
	D.music("Silence")
	D.heal()
	local hpos = hollow.root and hollow.root.Position or (c + V(0, 3, -20))
	-- keep the scene (and the giant that comes next) well inside the platform
	local off = V(hpos.X - c.X, 0, hpos.Z - c.Z)
	if off.Magnitude > 26 then
		off = off.Unit * 26
	end
	if off.Magnitude < 12 then
		off = V(0, 0, -20)
	end
	hpos = c + off
	local toC = Util.flatUnit(c - hpos)
	local kneelCF = CFrame.lookAt(V(hpos.X, c.Y + 3, hpos.Z), V(hpos.X, c.Y + 3, hpos.Z) + toC)
	hollow.root.Anchored = true
	hollow.root.CFrame = kneelCF
	hollow.model:SetAttribute("Pose", "KneelOne")
	Net.fireAll("FX", "Shockwave", { pos = kneelCF.Position - V(0, 3, 0), radius = 16, color = rgb(40, 0, 10) })
	D.shake(2, 0.5)
	-- players gather in front of him
	D.teleport(CFrame.lookAt(kneelCF.Position + toC * 12, kneelCF.Position))
	local lines = D.lines("hollow_kneel")
	local camA = { cf = CFrame.lookAt(kneelCF.Position + toC * 7 + kneelCF.RightVector * 3 + V(0, 1, 0), kneelCF.Position + V(0, 0.6, 0)), fov = 45 }
	D.say({ lines[1], lines[2] }, { cam = camA })
	-- the hood falls back
	D.scene("glitch", { dur = 0.6 })
	Net.fireAll("FX", "Flash", { pos = kneelCF.Position + V(0, 2, 0), color = rgb(255, 255, 255), size = 14 })
	local you = D.actor(invertedLook(leader), kneelCF, { anchored = true, pose = "KneelOne" })
	local ok, blade = pcall(function()
		return Weapons.buildModel(Weapons.unique("HollowEdge", level), Weapons.HELD_SCALE)
	end)
	if ok and blade then
		Rig.hold(you, blade)
	end
	hollow.dead = true
	S.Entities.remove(hollow)
	if hollow.model then
		hollow.model:Destroy()
	end
	reward(D, 5000 + level * 100, 1000, kneelCF.Position)
	local camB = { cf = CFrame.lookAt(kneelCF.Position + toC * 5 + V(0, 0.8, 0), kneelCF.Position + V(0, 1.2, 0)), fov = 34 }
	D.say({ lines[3], lines[4] }, { cam = camB })
	local extra = if run.flags.kingKilled then D.lines("hollow_extra_killed") else D.lines("hollow_extra_spared")
	D.say(extra, { cam = camA })
	-- he stands
	you:SetAttribute("Pose", nil)
	D.say({ lines[5], lines[6] }, { cam = { follow = you, offset = toC * 8 + V(2, 1, 0), lookY = 1.6, fov = 40 } })
	run.flags.hollowDead = true
	D.save()
	return you, kneelCF
end

local function abnormalityStage(D, top, level, rng, you, spot: CFrame)
	local b = D.bible()
	local run = S.State.run
	local c = top.center
	D.lock(true, true, false)
	-- black flame
	spot = spot or CFrame.lookAt(c + V(0, 3, -28), c + V(0, 3, 20))
	local p = spot.Position
	D.shake(4, 3)
	for i = 0, 5 do
		task.delay(i * 0.35, function()
			Net.fireAll("FX", "Pillar", { pos = p - V(0, 3, 0), radius = 5 + i * 2, color = rgb(10, 0, 8) })
		end)
	end
	D.cutscene({
		shots = {
			{ cf = CFrame.lookAt(p + spot.LookVector * 22 + V(6, 4, 0), p + V(0, 2, 0)), to = CFrame.lookAt(p + spot.LookVector * 40 + V(10, 3, 0), p + V(0, 14, 0)), t = 3.4, fov = 55, shake = 2 },
		},
		duration = 3.4,
		skippable = false,
	})
	if you and you.Parent then
		you:Destroy()
	end
	Net.fireAll("Fade", { to = "clear", time = 0.4, color = Color3.new(0, 0, 0) })
	D.scene("flashWhite", { color = Color3.new(0, 0, 0), inT = 0.05, hold = 0.25, outT = 0.8 })
	local lookAt = Util.flatUnit(V(c.X, 0, c.Z) - V(p.X, 0, p.Z))
	local abn = S.Bosses.abnormality(CFrame.lookAt(V(p.X, c.Y + 2, p.Z), V(p.X, c.Y + 2, p.Z) + lookAt), level + 3)
	freeze(abn)
	npcAct(abn.model, "Roar")
	Net.fireAll("FX", "Shockwave", { pos = V(p.X, c.Y, p.Z), radius = 40, color = rgb(20, 0, 10) })
	D.shake(6, 1.5)
	D.title("THE STRONGEST ABNORMALITY", "This is true power.", 3.5)
	task.wait(1.6)
	abn.model:SetAttribute("Pose", nil)
	D.bossBar(abn, "THE STRONGEST ABNORMALITY")
	D.music("Boss")
	D.lock(false, false, false)
	unfreeze(abn)
	D.tutorial("Slide under heavy swings. When its core glows, strike it.", "Ctrl", 7)
	D.deathHandler = function(player)
		S.PlayerService.spawn(player, top.spawn)
		local prof = S.State.profile(player)
		prof.flasks = prof.maxFlasks
		S.State.sync(player)
		return true
	end
	D.waitUntil(lowHp(abn), nil, 0.15)
	D.deathHandler = nil
	stopAllTime()
	freeze(abn)
	S.Projectiles.clear()
	D.bossBar(nil)
	D.lock(false, true, false)
	D.music("Silence")
	-- kneeling, core exposed, waiting for the last blow
	local core = abn.brain and abn.brain.core
	local holding = true
	task.spawn(function()
		while holding and abn.model.Parent do
			abn.model:SetAttribute("Pose", "KneelOne")
			if core and core.Parent then
				core.Size = V(6, 6, 6)
			end
			task.wait(0.4)
		end
	end)
	D.say(D.lines("abnormality_dead"), { auto = 2 })
	D.objective("Strike the core")
	local target = if core and core.Parent then core else abn.root
	D.marker(target.Position + V(0, 4, 0), "CORE")
	D.waitPrompt(target, "Strike", "The Core", { dist = 30, hold = 0.3 })
	holding = false
	D.marker(nil)
	D.objective(nil)
	D.lock(true, true, false)
	local cp = target.Position
	local pp = D.leaderPos()
	local dir = Util.flatUnit(cp - pp)
	D.teleport(CFrame.lookAt(cp - dir * 6 - V(0, cp.Y - c.Y - 3, 0), V(cp.X, c.Y + 3, cp.Z)))
	D.cutscene({
		shots = {
			{ cf = CFrame.lookAt(cp - dir * 16 + V(4, 2, 0), cp), to = CFrame.lookAt(cp - dir * 9 + V(2, 1, 0), cp), t = 1.4, fov = 40, shake = 1 },
			{ cf = CFrame.lookAt(cp + dir * 30 + V(0, 10, 0), cp), t = 1.6, fov = 60, shake = 4 },
		},
		duration = 3,
		skippable = false,
	})
	Net.fireAll("FX", "Hit", { pos = cp, dir = dir, blood = "void", dmg = 99999, heavy = true })
	Net.fireAll("FX", "Explosion", { pos = cp, radius = 18, color = rgb(255, 20, 40) })
	Net.fireAll("FX", "Debris", { pos = cp, count = 90, speed = 60, size = 2.4, color = rgb(8, 4, 10) })
	D.scene("flashWhite", { inT = 0.05, hold = 0.2, outT = 1 })
	D.shake(8, 1.2)
	local apos = abn.root and abn.root.Position or cp
	abn.invuln = false
	abn.minHealth = nil
	S.Combat.kill(abn, D.playerEntity(), { kb = V(0, 10, 0) })
	task.wait(0.35)
	if abn.model and abn.model.Parent then
		abn.model:Destroy()
	end
	pcall(function()
		S.Loot.dropWeapon(V(apos.X, c.Y + 1, apos.Z) + dir * 6, Weapons.unique("HollowEdge", level))
		S.Loot.dropItem(V(apos.X, c.Y + 1, apos.Z) + dir * 6 + V(4, 0, 0), require(Shared.Gear).unique("HollowHood", level))
	end)
	run.flags.abnDead = true
	D.save()
	local gp = V(apos.X, c.Y + 3, apos.Z)
	return CFrame.lookAt(gp, gp - dir * 10)
end

local function glitchAndGod(D, top, level, rng, spot: CFrame)
	local b = D.bible()
	local c = top.center
	D.lock(true, true, false)
	spot = spot or CFrame.lookAt(c + V(0, 3, -20), c + V(0, 3, 20))
	-- the glitch: it cycles through every face it ever wore
	local running = true
	local current: Model? = nil
	task.spawn(function()
		while running do
			local ok, look = pcall(randomWorldLook, rng)
			if not ok then
				look = { outfit = "cloak" }
			end
			local m = S.NPCs.actor(look, spot, { anchored = true, pose = rng:pick({ "KneelOne", "Cower", "HandsUp", "Stagger" }) })
			if current and current.Parent then
				current:Destroy()
			end
			current = m
			if rng:chance(0.3) then
				Net.fireAll("FX", "Flash", { pos = spot.Position + V(0, 2, 0), color = rng:pick({ rgb(255, 0, 60), rgb(0, 255, 220), rgb(255, 255, 255) }), size = 6 })
			end
			task.wait(rng:float(0.08, 0.22))
		end
		if current and current.Parent then
			current:Destroy()
		end
	end)
	D.scene("glitch", { dur = 11 })
	local lines = D.lines("glitch")
	local cam = { cf = CFrame.lookAt(spot.Position + spot.LookVector * 9 + spot.RightVector * 2 + V(0, 1.5, 0), spot.Position + V(0, 1, 0)), fov = 42 }
	D.say({ lines[1], lines[2] }, { cam = cam, auto = 2.2 })
	-- the last line is cut off by a foot
	task.spawn(function()
		D.say({ lines[3] }, { cam = cam, auto = 1.2 })
	end)
	task.wait(2.4)
	-- the god drops out of the white
	local scale = 5
	local godPos = spot.Position - spot.LookVector * 2
	local skyPos = godPos + V(0, 420, 0)
	local face = CFrame.lookAt(godPos, godPos + spot.LookVector)
	local god = S.WorldHeaven.god(S.World.sub("Finale"), CF(skyPos) * face.Rotation, b, scale)
	S.WorldHeaven.pin(god)
	god:SetAttribute("Pose", "Float")
	local standY = 3 * scale -- root height of a scaled rig
	local t0 = os.clock()
	local fall = 0.55
	while os.clock() - t0 < fall do
		local k = (os.clock() - t0) / fall
		local y = Util.lerp(skyPos.Y, godPos.Y - 3 + standY, k * k)
		god:PivotTo(CF(godPos.X, y, godPos.Z) * face.Rotation)
		task.wait()
	end
	god:PivotTo(CF(godPos.X, godPos.Y - 3 + standY, godPos.Z) * face.Rotation)
	running = false
	god:SetAttribute("Pose", nil)
	npcAct(god, "Stomp")
	Net.fireAll("FX", "Splat", { pos = spot.Position - V(0, 2.8, 0), color = rgb(20, 0, 20), size = 14 })
	Net.fireAll("FX", "Shockwave", { pos = spot.Position - V(0, 3, 0), radius = 60, color = rgb(255, 245, 220) })
	Net.fireAll("FX", "Debris", { pos = spot.Position, count = 40, speed = 50, size = 1.4, color = rgb(255, 250, 235) })
	D.shake(9, 1.4)
	D.scene("flashWhite", { inT = 0.02, hold = 0.1, outT = 0.8 })
	task.wait(1.2)
	D.zone("whiteroom")
	local godCam = { cf = CFrame.lookAt(godPos + spot.LookVector * 34 + V(8, 6, 0), godPos + V(0, standY + 5, 0)), fov = 50 }
	god:SetAttribute("Pose", "Crossed")
	D.say(D.lines("god_arrives"), { cam = godCam })
	return god, godCam
end

-- ------------------------------------------------------------------ chapter
function Ch.run(D)
	local run = S.State.run
	local b = D.bible()
	local rng = RNG.new(D.seed()):fork("finale")
	local refs = S.Chapters.Tower.ensureLand6(D)
	local top = refs.tower.top
	local level = 54 + (run.ngPlus or 0) * 20
	D.look("awakened")
	local lp = D.leaderPos()
	if not D.leaderChar() or (lp - top.center).Magnitude > 150 then
		D.spawnPlayers(top.spawn)
	end
	D.checkpoint(top.spawn)
	D.zone("space", "THE TOP OF THE WORLD", "Altitude 10,000")
	S.Entities.clearNPCs()

	local you, spot = nil, nil
	if not run.flags.hollowDead then
		you, spot = hollowStage(D, top, level, rng)
	end
	if not run.flags.abnDead then
		spot = abnormalityStage(D, top, level, rng, you, spot)
	end
	local god, godCam = glitchAndGod(D, top, level, rng, spot)
	-- the choice
	local choice = D.say(D.lines("god_final_choice"), {
		cam = godCam,
		choices = { "Save the world", "Delete the world", "Start a brand new story" },
		hiddenChoice = { text = "K I L L   H I M", index = 4, delay = 7 },
	})
	run.flags.finalChoice = choice
	D.save()
	local godName = b.god
	if choice == 4 then
		god:SetAttribute("Pose", nil)
		D.say(D.lines("god_fight"), { cam = godCam })
		D.scene("flashWhite", { inT = 0.3, hold = 0.8, outT = 1 })
		task.wait(0.5)
		return "GodFight"
	elseif choice == 2 then
		D.say({
			{ speaker = godName, text = "Delete it? Ooh. Cold. I love it." },
			{ speaker = godName, text = "But I don't do chores. Every living thing left in this world - I'll gather them. You erase them." },
		}, { cam = godCam })
		return "Delete"
	elseif choice == 3 then
		D.say({
			{ speaker = godName, text = "A new story! Oh, you're my favourite. You really are." },
			{ speaker = godName, text = "Same you, new world. Let's see how far you get this time." },
		}, { cam = godCam })
		D.ending("restart", false)
		return D.restartStory(false)
	end
	-- save
	D.say({
		{ speaker = godName, text = "Save it? How... wholesome. Fine. The monsters stay, the people stay, and so do you." },
		{ speaker = godName, text = "Enjoy your little world, " .. b.hero .. ". I'll be watching. I'm always watching." },
	}, { cam = godCam })
	D.ending("save", true)
	run.flags.ending = "save"
	return "Epilogue"
end

return Ch
