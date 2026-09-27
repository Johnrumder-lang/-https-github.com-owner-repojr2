--!nonstrict
-- CHAPTER 7: The castle burns. Slay everyone inside, face the Archmage in the
-- crown room, and decide what happens to the king.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local RNG = require(Shared.RNG)
local Enemies = require(Shared.Enemies)
local S = require(script.Parent.Parent.S)

local Ch: any = {}
local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB

function Ch.run(D)
	local b = D.bible()
	local rng = RNG.new(D.seed()):fork("castle")
	local refs = D.ensureCapital()
	local run = S.State.run
	local level = math.max(16, S.State.profile(D.leader() or game.Players:GetPlayers()[1]).level)
	D.look("awakened")
	D.zone("castle_burning", "THE CASTLE OF " .. string.upper(b.kingdom), "Everyone inside chose their side.")
	D.music("Combat")
	if not D.leaderChar() then
		D.spawnPlayers(CFrame.lookAt(refs.castleGate + V(0, 2, 30), refs.center))
	end
	D.checkpoint(CFrame.lookAt(refs.castleGate + V(0, 2, 30), refs.center))
	D.lock(false, false, false)
	D.fade("clear", 0.8)
	S.Chapters.Breakout.burnHouses(refs.upperHouses, rng, 0.6)
	S.Chapters.Breakout.burnHouses(refs.middleHouses, rng, 0.4)

	if not run.flags.castleCleared then
		-- defenders: courtyard, great hall, halls
		local function spawn(id, p)
			return S.AI.spawn(id, CF(p), { level = level, tags = { castle = true }, aggro = 90 })
		end
		for i = 1, 8 do
			spawn(rng:pick({ "RoyalKnight", "RoyalGuard", "Militia" }), refs.courtyardSpawns[(i - 1) % #refs.courtyardSpawns + 1])
		end
		for _, p in refs.wallSpawns do
			spawn("RoyalMage", p)
		end
		for i = 1, 7 do
			spawn(rng:pick({ "RoyalKnight", "RoyalGuard", "DemonMerc" }), refs.keepSpawns[(i - 1) % #refs.keepSpawns + 1])
		end
		for _, cf in refs.castleSpawns do
			spawn(rng:pick({ "RoyalKnight", "RoyalMage", "RoyalGuard", "DemonMerc" }), cf.Position)
		end
		D.objective("Slay everyone in the castle")
		D.marker(refs.castleGate, "Castle")
		D.waitKills("castle", "Slay everyone in the castle")
		run.flags.castleCleared = true
		D.save()
	end

	-- the crown room ---------------------------------------------------------------
	D.objective("Climb to the crown room")
	D.marker(refs.crownRoom + V(0, 3, 0), "Crown Room")
	local king = D.actor(S.Chapters.Summoning.kingLook(b), refs.throne, { anchored = true, pose = "Cower" })
	D.waitNear(refs.crownRoom, 30)
	D.marker(nil)
	if not run.flags.archmageDead then
		D.lock(true, true, false)
		local boss = S.Bosses.archmage(CFrame.lookAt(refs.crownRoom + V(0, 8, -8), refs.crownRoom + V(0, 3, 20)), level + 2, b.archmage, refs.crownRoom, 22)
		boss.tags.crown = true
		D.say(D.lines("archmage_fight"), { cam = { follow = boss.model, offset = V(8, 4, 16), lookY = 2, fov = 50 } })
		D.bossBar(boss, string.upper(b.archmage) .. ", ARCHMAGE OF " .. string.upper(b.kingdom))
		D.music("Boss")
		D.lock(false, false, false)
		D.deathHandler = function(player)
			-- the archmage resets when everybody is down
			S.PlayerService.spawn(player, CFrame.lookAt(refs.crownRoom + V(0, 3, 20), refs.crownRoom))
			local prof = S.State.profile(player)
			prof.flasks = prof.maxFlasks
			S.State.sync(player)
			return true
		end
		D.waitUntil(function()
			return not S.Entities.isAlive(boss)
		end, nil, 0.2)
		D.deathHandler = nil
		D.bossBar(nil)
		D.music("Calm")
		D.say(D.lines("archmage_dead"), { auto = 2.6 })
		S.Loot.dropItem(refs.crownRoom + V(0, 1, 8), require(Shared.Gear).unique("WallwardenHelm", level))
		run.flags.archmageDead = true
		D.save()
	end

	-- the king
	D.lock(true, true, false)
	local kingCam = { cf = CFrame.lookAt(refs.throne.Position + refs.throne.LookVector * 10 + V(3, 2, 0), refs.throne.Position + V(0, 1, 0)), fov = 50 }
	D.say(D.lines("king"), { cam = kingCam })
	local choice = D.say({ { speaker = "", text = "The king of " .. b.kingdom .. " is on his knees." } }, { cam = kingCam, choices = { "Spare him", "Kill him" } })
	if choice == 2 then
		run.flags.kingKilled = true
		D.say(D.lines("king_killed"), { cam = kingCam, auto = 2 })
		Net.fireAll("FX", "Hit", { pos = king:GetPivot().Position, dir = V(0, 0.5, -1), blood = "red", dmg = 80, heavy = true })
		king:SetAttribute("Pose", nil)
		if king.PrimaryPart then
			king.PrimaryPart.Anchored = false
		end
		S.Ragdoll.enable(king, V(0, 20, -30), 6)
	else
		run.flags.kingSpared = true
		king:SetAttribute("Pose", "KneelOne")
		D.say(D.lines("king_spared"), { cam = kingCam })
	end
	D.save()
	D.say(D.lines("open_world"))
	D.lock(false, false, false)
	run.land = 1
	return "World"
end

return Ch
