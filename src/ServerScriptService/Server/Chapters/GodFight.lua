--!nonstrict
-- SECRET CHAPTER: you pressed the button that wasn't supposed to be there.
-- The kind god fights in his white place. At half health the light goes out and
-- he becomes the Anti-Light. Beat him and he burns the world out of spite -
-- and someone else is waiting in the dark.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local S = require(script.Parent.Parent.S)

local Ch: any = {}
local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB

local function refill(player: Player, cf: CFrame)
	S.PlayerService.spawn(player, cf)
	local prof = S.State.profile(player)
	prof.flasks = prof.maxFlasks
	S.State.sync(player)
end

local function otherGodLook(b)
	return {
		name = b.otherGod,
		race = "Elf",
		outfit = "robeGod",
		skin = rgb(46, 44, 72),
		hair = rgb(225, 228, 255),
		hairStyle = "long",
		shirt = rgb(14, 14, 30),
		accent = rgb(170, 180, 255),
		mood = "calm",
		glowEye = rgb(190, 200, 255),
		halo = rgb(150, 160, 255),
		glow = rgb(150, 160, 255),
		scale = 2.6,
		health = 1000,
	}
end

function Ch.run(D)
	local run = S.State.run
	local b = D.bible()
	local level = 60 + (run.ngPlus or 0) * 20
	local arena = D.ensure("final", function()
		return S.WorldHeaven.finalArena(b)
	end)
	D.look("awakened")
	D.spawnPlayers(arena.spawn)
	D.zone("whiteroom", string.upper(b.god), "The one who wrote you")
	D.lock(true, true, false)
	Net.fireAll("Fade", { to = "clear", time = 1.5, color = Color3.new(1, 1, 1) })

	if not run.flags.godDead then
		local god = S.Bosses.god(arena.godSpot, level, b, arena.center)
		god.invuln = true
		god.brain.scripted = true
		D.say({
			{ speaker = b.god, text = "Welcome to my study. Mind the margins." },
			{ speaker = b.god, text = "Every hit you land, I felt coming a thousand years ago. Let's pretend it matters." },
		}, { cam = { follow = god.model, offset = V(10, 2, 24), lookY = 4, fov = 45 } })
		D.title(string.upper(b.god), "The Kind God", 3)
		D.bossBar(god, string.upper(b.god) .. ", THE KIND GOD")
		D.music("Boss")
		D.lock(false, false, false)
		god.invuln = false
		god.brain.scripted = false
		D.deathHandler = function(player)
			refill(player, arena.spawn)
			return true
		end
		-- phase 2: the Anti-Light
		local phase2Done = false
		god.brain.onPhase2 = function(brain)
			local waitT = os.clock()
			while S.TimeStop.active and os.clock() - waitT < 6 do
				task.wait(0.1)
			end
			if S.TimeStop.active then
				S.TimeStop.stop()
			end
			god.invuln = true
			brain.scripted = true
			if brain.cancelAction then
				pcall(brain.cancelAction, brain)
			end
			S.Projectiles.clear()
			D.lock(true, true, false)
			D.music("Silence")
			D.say(D.lines("god_phase2"), { cam = { follow = god.model, offset = V(6, 1, 16), lookY = 4, fov = 40 } })
			-- the light goes out
			D.scene("flashWhite", { color = Color3.new(0, 0, 0), inT = 0.1, hold = 0.6, outT = 1.2 })
			task.wait(0.3)
			D.zone("antilight", "THE ANTI-LIGHT", "No light. No kindness. Just him.")
			brain:becomeAntiLight()
			for _, d in workspace.World:GetDescendants() do
				if d:IsA("BasePart") and d.Transparency < 1 then
					d.Color = if d.Material == Enum.Material.Neon then rgb(255, 255, 255) else rgb(10, 10, 12)
				end
			end
			if god.hum then
				god.hum.Health = god.hum.MaxHealth * 0.75
			end
			D.bossHp(god)
			D.bossBar(god, "THE ANTI-LIGHT")
			Net.fireAll("FX", "Shockwave", { pos = arena.center, radius = 120, color = rgb(0, 0, 0) })
			D.shake(6, 1.5)
			D.title("THE ANTI-LIGHT", "The strongest thing that has ever existed", 3.5)
			task.wait(1.2)
			D.music("Final")
			D.heal()
			D.lock(false, false, false)
			god.invuln = false
			brain.scripted = false
			phase2Done = true
		end
		D.waitUntil(function()
			if not S.Entities.isAlive(god) then
				return true
			end
			local hp = S.Entities.health(god)
			return phase2Done and hp <= 1.5
		end, nil, 0.15)
		D.deathHandler = nil
		-- defeated
		local t0 = os.clock()
		while S.TimeStop.active and os.clock() - t0 < 6 do
			task.wait(0.1)
		end
		if S.TimeStop.active then
			S.TimeStop.stop()
		end
		god.invuln = true
		if god.brain then
			god.brain.scripted = true
			if god.brain.ap then
				god.brain.ap.Position = arena.center + V(0, 8, -20)
			end
		end
		S.Projectiles.clear()
		D.bossBar(nil)
		D.lock(true, true, false)
		D.music("Silence")
		god.model:SetAttribute("Pose", "KneelOne")
		D.teleport(CFrame.lookAt(arena.center + V(0, 3, 10), arena.center + V(0, 3, -20)))
		task.wait(1)
		D.say(D.lines("god_defeat"), { cam = { follow = god.model, offset = V(4, 1, 14), lookY = 5, fov = 40 } })
		for _, p in D.players() do
			S.State.addXP(p, 20000 + level * 200)
		end
		run.flags.godDead = true
		D.save()
		-- he burns it all
		D.scene("glitch", { dur = 2.5 })
		D.shake(10, 2.5)
		task.wait(1.5)
		D.scene("flashWhite", { color = Color3.new(0, 0, 0), inT = 0.05, hold = 2.5, outT = 2 })
		D.scene("delete", {})
		task.wait(0.5)
		god.dead = true
		S.Entities.remove(god)
		if god.model then
			god.model:Destroy()
		end
	end

	-- the void ---------------------------------------------------------------------
	local void = D.ensure("void", function()
		return S.WorldHeaven.void()
	end)
	D.spawnPlayers(CFrame.lookAt(void.center, void.center + V(0, 0, -20)))
	D.zone("void")
	D.lock(true, true, false)
	Net.fireAll("Fade", { to = "clear", time = 3, color = Color3.new(0, 0, 0) })
	task.wait(3.5)
	D.say(D.lines("void"), { auto = 2.8 })
	task.wait(1)
	local og = D.actor(otherGodLook(b), CFrame.lookAt(void.center + V(0, 4, -26), void.center), { anchored = true, pose = "Float" })
	Net.fireAll("FX", "Flash", { pos = void.center + V(0, 4, -26), color = rgb(160, 170, 255), size = 30, t = 1.2 })
	local cam = { cf = CFrame.lookAt(void.center + V(6, 3, -4), void.center + V(0, 7, -26)), fov = 45 }
	local choice = D.say(D.lines("other_god"), { cam = cam, choices = { "Accept", "Refuse" } })
	if choice == 1 then
		D.say({ { speaker = b.otherGod, text = "Then wake up. And this time, nobody is holding the pen." } }, { cam = cam })
		D.scene("flashWhite", { inT = 1.5, hold = 1, outT = 1.5 })
		task.wait(1.6)
		if og.Parent then
			og:Destroy()
		end
		D.ending("best", true)
		run.flags.ending = "best"
		return "Epilogue"
	end
	D.say({ { speaker = b.otherGod, text = "...I understand. Some people only feel alive when they're falling. Go on, then." } }, { cam = cam })
	D.ending("decline", false)
	return D.restartStory(false)
end

return Ch
