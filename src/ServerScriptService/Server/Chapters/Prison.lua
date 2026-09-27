--!nonstrict
-- CHAPTER 5: Captured by the floating Archmage. A cell, a talkative prisoner,
-- and eight rounds in the Proving Pit.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local RNG = require(Shared.RNG)
local Enemies = require(Shared.Enemies)
local Util = require(Shared.Util)
local Beasts = require(Shared.Beasts)
local S = require(script.Parent.Parent.S)

local Ch: any = {}
local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB

-- Rounds: crawlers first, then the run's own random beasts (tougher every round,
-- two species at once from round 4), the champion last.
local ROUNDS = {
	{ crawlers = 5 },
	{ n = 5, tiers = { 1, 2 }, species = 1, crawlers = 2 },
	{ n = 5, tiers = { 2, 2 }, species = 1 },
	{ n = 6, tiers = { 2, 3 }, species = 2 },
	{ n = 6, tiers = { 3, 3 }, species = 2 },
	{ n = 7, tiers = { 3, 4 }, species = 2 },
	{ n = 7, tiers = { 4, 5 }, species = 2 },
	{ champion = true },
}

local function gateOpen(model, open: boolean)
	if not model then
		return
	end
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			local base = p:GetAttribute("BaseY")
			if not base then
				base = p.Position.Y
				p:SetAttribute("BaseY", base)
			end
			local cf = p.CFrame
			p.CFrame = cf + V(0, (if open then base + 11 else base) - cf.Position.Y, 0)
			p.CanCollide = not open
		end
	end
end

function Ch.run(D)
	local b = D.bible()
	local rng = RNG.new(D.seed()):fork("prison")
	local refs = D.ensureCapital()
	local run = S.State.run

	-- capture ---------------------------------------------------------------------
	if not run.flags.captured then
		D.lock(true, true, false)
		local char = D.leaderChar()
		local me = char and char:GetPivot() or CF(refs.middleGate)
		local archPos = me.Position + me.LookVector * 16 + V(0, 8, 0)
		local arch = D.actor(S.Chapters.Summoning.archmageLook(b), CFrame.lookAt(archPos + V(0, 30, 0), me.Position), { anchored = true, pose = "Float", weapon = "staff" })
		Net.fireAll("FX", "Teleport", { from = archPos + V(0, 30, 0), to = archPos, color = rgb(170, 120, 255) })
		task.spawn(function()
			for i = 1, 30 do
				arch:PivotTo(CFrame.lookAt(archPos + V(0, 30 - i, 0), me.Position))
				task.wait(0.03)
			end
		end)
		task.wait(1)
		local cam = { cf = CFrame.lookAt(me.Position + V(4, 3, 0) - me.LookVector * 3, archPos), fov = 55 }
		D.say(D.lines("capture"), { cam = cam })
		for _, p in D.players() do
			if p.Character then
				D.scene("bubble", { target = p.Character })
			end
		end
		-- the time stop fails inside the bubble
		task.wait(1.2)
		Net.fireAll("FX", "Text", { pos = me.Position + V(0, 4, 0), text = "TIME STOP FAILED", color = rgb(255, 80, 90), size = 1.2 })
		D.shake(1.5, 1)
		task.wait(1.5)
		D.scene("flashWhite", { hold = 0.4, outT = 0.1, color = rgb(200, 160, 255) })
		D.fade("black", 1)
		D.scene("bubbleEnd")
		D.clearActors()
		run.flags.captured = true
	end

	-- the cell ------------------------------------------------------------------
	S.Entities.clearNPCs()
	D.look("prisoner")
	D.lock(true, true, true)
	D.spawnPlayers(refs.cellCF)
	D.checkpoint(refs.cellCF)
	D.zone("cell")
	D.music("Calm")
	local prisoner = D.actor({ name = b.prisoner, race = "Beastkin", beast = b.prisonerBeast, outfit = "prisoner", shirt = rgb(120, 110, 90), pants = rgb(90, 80, 66), hair = rgb(120, 96, 70), mood = "happy" }, refs.neighborCell, { anchored = true, pose = "Sit" })
	D.fade("clear", 1.2)
	D.scene("blink", { times = 2 })
	task.wait(1)
	local pcam = { cf = CFrame.lookAt(refs.cellCF.Position + V(3, 2, 2), prisoner:GetPivot().Position + V(0, 1, 0)), fov = 50 }
	D.say(D.lines("cell_wake"), { cam = pcam })
	D.lock(false, true, true)
	local talked = false
	S.PlayerService.prompt(prisoner.PrimaryPart, "Talk", b.prisoner, function(player)
		prisoner:SetAttribute("Pose", "SitTalk")
		D.say(D.lines("cell_talk"), { player = player })
		prisoner:SetAttribute("Pose", "Sit")
		talked = true
	end, { dist = 14 })
	D.objective("Talk to " .. b.prisoner .. " (or wait)")
	D.waitUntil(function()
		return talked
	end, 45, 0.3)
	-- a guard comes
	local guard = D.actor(Enemies.LOOKS.guard(rng), CF(refs.prisonCenter + V(12, 3, 8)), { weapon = "spear" })
	S.AI.walkTo(guard, refs.cellDoor + V(0, 0, 3), 12, 6)
	D.bark(guard, "Get up, chicken. The Pit is hungry.", 3)
	task.wait(2.5)
	D.fade("black", 0.8)
	D.clearActors()

	-- the arena -----------------------------------------------------------------
	local ac = refs.arenaCenter
	local playerGate = refs.arenaGate2
	local monsterGate = refs.arenaGate6
	local startCF = CFrame.lookAt(playerGate + (ac - playerGate).Unit * 6, ac + V(0, 3, 0))
	D.lock(true, true, false)
	D.spawnPlayers(startCF)
	D.checkpoint(startCF)
	D.zone("arena", "THE PROVING PIT", "Eight rounds.")
	-- crowd, king and archmage in the royal box
	for _, cf in refs.arenaSpectators do
		local look = if rng:chance(0.4) then Enemies.LOOKS.beastVillager(rng) else Enemies.LOOKS.villager(rng)
		look.mood = rng:pick({ "happy", "angry", "smug" })
		D.actor(look, cf, { anchored = true, pose = rng:pick({ "Cheer", "Cheer", "Talk", "Crossed" }) })
	end
	local box = refs.royalBox
	local king = D.actor(S.Chapters.Summoning.kingLook(b), CFrame.lookAt(box + V(-2, 0, 0), ac + V(0, 10, 0)), { anchored = true, pose = "Throne", weapon = "scepter" })
	local arch = D.actor(S.Chapters.Summoning.archmageLook(b), CFrame.lookAt(box + V(3, 0, 0), ac + V(0, 10, 0)), { anchored = true, pose = "Crossed", weapon = "staff" })
	D.fade("clear", 1)
	local annCam = { cf = CFrame.lookAt(ac + V(0, 18, 36), box), fov = 50 }
	local announcer = "Announcer " .. b.announcer
	D.say(D.lines("arena_intro"), { cam = annCam })
	-- nobody leaves the Pit: a barrier stands inside the ring wall for the fights
	S.WorldCapital.setArenaBarrier(refs, true)
	D.lock(false, false, false)
	D.music("Combat")
	local taunts = D.lines("arena_taunts")
	local startRound = run.flags.arenaRound or 1
	for round = startRound, 8 do
		run.flags.arenaRound = round
		local tag = "arena" .. round
		local text = Util.fill(taunts[round] or "Round {n}!", { n = round })
		D.title("ROUND " .. round, text, 3)
		task.wait(1.5)
		gateOpen(refs.arenaGateModel6, true)
		local lvl = math.max(8, S.State.profile(D.leader() or game.Players:GetPlayers()[1]).level)
		local cfg = ROUNDS[round]
		local k = 0
		local function spot()
			k += 1
			return monsterGate + (ac - monsterGate).Unit * (4 + k * 2) + V(rng:float(-4, 4), 0, rng:float(-4, 4))
		end
		if cfg.champion then
			local boss = S.Bosses.champion(CF(spot()), lvl)
			boss.tags[tag] = true
			D.bossBar(boss, "BRAMORR, CHAMPION OF THE PIT")
			D.music("Boss")
		end
		for _ = 1, cfg.crawlers or 0 do
			S.AI.spawn("Crawler", CF(spot()), { level = lvl, tags = { [tag] = true, arena = true }, aggro = 300 })
		end
		if cfg.n then
			local roster = Beasts.roster(D.seed(), 20)
			local picks = {}
			for _ = 1, cfg.species do
				table.insert(picks, Beasts.pick(roster, rng, cfg.tiers[1], cfg.tiers[2]))
			end
			local left = cfg.n
			local i = 0
			while left > 0 do
				i += 1
				local sp = picks[((i - 1) % #picks) + 1]
				local pack = if sp.swarm then 3 else 1
				for _ = 1, pack do
					S.AI.spawn(sp, CF(spot() + V(0, if sp.hover then 3 else 0, 0)), { level = lvl, tags = { [tag] = true, arena = true }, aggro = 300, rng = rng })
				end
				left -= pack
			end
			Net.fireAll("Notify", { kind = "warn", text = string.upper(picks[1].name), sub = Beasts.describe(picks[1]) })
		end
		task.wait(1.5)
		gateOpen(refs.arenaGateModel6, false)
		D.waitKills(tag, "Survive  -  Round " .. round .. " / 8")
		D.bossBar(nil)
		D.heal()
		Net.fireAll("Notify", { kind = "info", text = "Round " .. round .. " cleared", sub = "The crowd roars." })
		D.save()
		task.wait(3)
	end
	run.flags.arenaRound = nil
	run.flags.arenaDone = true
	S.WorldCapital.setArenaBarrier(refs, false)
	return "Titan"
end

return Ch
