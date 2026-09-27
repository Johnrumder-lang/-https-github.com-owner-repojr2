--!nonstrict
-- CHAPTER 6: A monster bigger than the kingdom steps on the arena. The Old God
-- gives you his spare power. Time stops. You walk out from under the foot... and
-- kill the Kingdom-Eater.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local RNG = require(Shared.RNG)
local Enemies = require(Shared.Enemies)
local TitanAnim = require(Shared.TitanAnim)
local Util = require(Shared.Util)
local S = require(script.Parent.Parent.S)

local Ch: any = {}
local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB

function Ch.run(D)
	local b = D.bible()
	local rng = RNG.new(D.seed()):fork("titan")
	local refs = D.ensureCapital()
	local run = S.State.run
	local ac = refs.arenaCenter
	local level = math.max(12, S.State.profile(D.leader() or game.Players:GetPlayers()[1]).level)

	-- the titan stands outside the arena, facing it, on the ground (v3 left it
	-- standing inside the city tiers)
	local SC = TitanAnim.SCALE
	local dir = Util.flatUnit(ac - refs.center)
	local standPos = V(ac.X, ac.Y, ac.Z) + dir * 95 * SC
	local face = CFrame.lookAt(standPos, V(ac.X, ac.Y, ac.Z))
	-- position so the hovering right foot sits over the arena centre
	local hoverParts = TitanAnim.solve(face, TitanAnim.pose("hover", 3))
	local footOff = hoverParts.RFoot.Position - standPos
	local rootCF = S.TitanBoss.rootAt(ac.X - footOff.X, ac.Z - footOff.Z, face.LookVector)
	local rootPos = rootCF.Position

	if not run.flags.blessed then
		-- the alarm
		D.lock(true, true, false)
		D.look("prisoner")
		D.spawnPlayers(CFrame.lookAt(ac + V(0, 3, 6), ac + V(0, 3, -20)))
		D.zone("arena")
		local knight = D.actor(Enemies.LOOKS.knight(rng), CF(refs.arenaGate2 + V(0, 0, 0)), { weapon = "sword" })
		knight.Name = b.knight
		S.AI.walkTo(knight, ac + V(0, 3, 12), 20, 3)
		D.say(D.lines("alarm"), { cam = { cf = CFrame.lookAt(ac + V(8, 5, 20), refs.royalBox), fov = 50 } })
		D.shake(3, 3)
		D.zone("titan")
		D.music("Boss")
		-- enter: the titan
		local st = S.TitanBoss.create(rootCF, b)
		S.TitanBoss.play(st, "hover")
		D.cutscene({
			shots = {
				{ cf = CFrame.lookAt(ac + V(0, 4, 0), ac + V(0, 60, 0) + dir * 40), to = CFrame.lookAt(ac + V(0, 4, 0), rootPos + V(0, 200 * SC, 0)), t = 3.2, fov = 70, shake = 1.5 },
				{ cf = CFrame.lookAt(ac + V(60, 40, 60), rootPos + V(0, 180 * SC, 0)), t = 2.6, fov = 60, shake = 2 },
				{ cf = CFrame.lookAt(ac + V(0, 3, 0), ac + V(0, 100, 0)), toFov = 90, fov = 60, t = 2.2, shake = 3 },
			},
			duration = 8,
			skippable = false,
		})
		D.title(string.upper(b.titan), b.titanTitle, 3)
		D.scene("flashWhite", { inT = 0.3, hold = 1.6, outT = 0.1 })
		task.wait(1.2)
		-- the Old God
		local elder = S.WorldHeaven.elderRoom(b)
		D.fade("white", 0.1)
		D.spawnPlayers(elder.spawn)
		D.zone("elder")
		Net.fireAll("Fade", { to = "clear", time = 2.5, color = Color3.new(1, 1, 1) })
		task.wait(1)
		D.say(D.lines("elder"), { cam = { cf = elder.cam, fov = 50 } })
		D.giveAll(function(p, prof)
			prof.blessed = true
			prof.abilities.aetherStep = true
			prof.abilities.voidSlash = true
			prof.flasks = prof.maxFlasks
		end)
		D.look("awakened", true)
		for _, p in D.players() do
			D.scene("power", { target = p.Character, color = rgb(255, 225, 150) })
			S.State.applyStats(p)
		end
		D.say(D.lines("awaken"), { auto = 2.5 })
		D.title("THE REAL STORY BEGINS", "Time Stop +2s  ·  [F] Aether Step  ·  [G] Void Slash  ·  x1.5 damage")
		task.wait(2)
		D.scene("flashWhite", { hold = 0.6, outT = 1.2 })
		task.wait(0.4)
		local ef = workspace.World:FindFirstChild("Elder")
		if ef then
			ef:Destroy()
		end
		-- back under the foot, time frozen
		D.spawnPlayers(CFrame.lookAt(ac + V(0, 3, 0), ac + V(0, 3, 0) - dir * 20))
		D.checkpoint(CFrame.lookAt(refs.center + V(0, 4, 60), ac))
		D.zone("titan")
		local pe = D.playerEntity()
		S.TimeStop.start(pe, 999, { scripted = true })
		D.lock(false, false, false)
		D.tutorial("Time is yours now. Walk out from under the foot.", nil, 6)
		D.objective("Get out from under the foot")
		D.marker(ac - dir * 60 + V(0, 4, 0), "Out")
		D.waitUntil(function()
			for _, p in D.players() do
				local c = p.Character
				if c and Util.flatDist(c:GetPivot().Position, ac) < 40 then
					return false
				end
			end
			return true
		end, 90, 0.2)
		D.marker(nil)
		S.TimeStop.stop()
		-- the foot slams the empty arena
		S.TitanBoss.play(st, "stompR", rootCF, 0)
		local stompDef = TitanAnim.ACTIONS.stompR
		S.TitanBoss.waitUntil(st, 0)
		-- skip to the slam part of the stomp
		st.clock0 = S.TitanBoss.clock() - 1.6
		Net.fireAll("Scene", "titanAction", { action = "stompR", clock0 = st.clock0, clock = S.TitanBoss.clock(), from = rootCF, to = rootCF, moveDur = 0 })
		S.TitanBoss.waitUntil(st, stompDef.hit)
		Net.fireAll("FX", "Shockwave", { pos = ac, radius = 70, color = rgb(220, 190, 150) })
		Net.fireAll("FX", "Debris", { pos = ac + V(0, 4, 0), count = 50, speed = 70, size = 2, color = rgb(160, 150, 130) })
		D.shake(7, 1.2)
		S.TitanBoss.breakCity(ac, 55, 80)
		local arena = workspace.World.City:FindFirstChild("Arena")
		if arena then
			for _, p in arena:GetDescendants() do
				if p:IsA("BasePart") and math.random() < 0.6 then
					S.World.breakPart(p, Util.flatUnit(p.Position - ac) * 60 + V(0, 50, 0))
				end
			end
		end
		S.TitanBoss.waitUntil(st, stompDef.dur)
		run.flags.blessed = true
		D.save()
		Ch.st = st
	end

	-- the fight -------------------------------------------------------------------
	local st = Ch.st
	if not st or st.dead or not st.model.Parent then
		-- (continue from a save) rebuild the titan near the arena
		D.look("awakened")
		D.spawnPlayers(CFrame.lookAt(refs.center + V(0, 4, 60), ac))
		D.checkpoint(CFrame.lookAt(refs.center + V(0, 4, 60), ac))
		D.zone("titan")
		D.music("Boss")
		st = S.TitanBoss.create(rootCF, b)
	end
	D.lock(false, false, false)
	D.deathHandler = function(player)
		S.PlayerService.spawn(player, S.PlayerService.checkpoint)
		local prof = S.State.profile(player)
		prof.flasks = prof.maxFlasks
		S.State.sync(player)
		return true
	end
	D.title(string.upper(b.titan), b.titanTitle, 3)
	D.tutorial("Hit the glowing cores. Stop time to line up your hits.", "Q", 6)
	S.TitanBoss.fight(D, st, level)
	-- death
	D.lock(true, true, false)
	local c = S.TitanBoss.currentRoot(st)
	D.cutscene({
		shots = {
			{ cf = CFrame.lookAt(c.Position + V(140, 60, 140) * SC, c.Position + V(0, 40 * SC, 0)), to = CFrame.lookAt(c.Position + V(170, 80, 90) * SC, c.Position + V(0, 20 * SC, 0)), t = 5, fov = 60, shake = 2 },
		},
		duration = 5,
	})
	S.TitanBoss.breakCity(c.Position + c.LookVector * 80 * SC, 90 * SC, 90)
	S.TitanBoss.destroy(st)
	Ch.st = nil
	D.deathHandler = nil
	-- loot: the titan's fang
	local pe = D.playerEntity()
	if pe then
		local item = require(Shared.Weapons).unique("TitanFang", level)
		S.Loot.dropWeapon(S.Entities.position(pe) + V(0, 1, -6), item)
		S.Loot.dropItem(S.Entities.position(pe) + V(4, 1, -6), require(Shared.Gear).unique("TitanHide", level))
		for _, p in D.players() do
			S.State.addXP(p, 3000 + level * 100)
		end
	end
	D.say(D.lines("titan_dead"))
	D.lock(false, false, false)
	D.music("Combat")
	run.flags.titanDead = true
	return "Castle"
end

return Ch
