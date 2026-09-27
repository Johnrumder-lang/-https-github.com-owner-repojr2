--!nonstrict
-- CHAPTER 0: An ordinary life. Wake up, breakfast, work, dinner, club... truck.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Palette = require(Shared.Palette)
local RNG = require(Shared.RNG)
local Rig = require(Shared.Rig)
local Net = require(Shared.Net)
local S = require(script.Parent.Parent.S)

local Ch: any = {}
local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB

local function modernLook(rng, outfit)
	return {
		race = "Human",
		skin = rng:pick(Palette.skin),
		hair = rng:pick(Palette.hair),
		hairStyle = rng:pick({ "short", "long", "bun", "slick", "messy", "ponytail", "bald" }),
		shirt = rng:pick(Palette.modernCloth),
		pants = rng:pick({ rgb(40, 50, 80), rgb(30, 30, 34), rgb(90, 80, 70), rgb(60, 60, 66) }),
		shoes = rng:pick({ rgb(30, 30, 30), rgb(240, 240, 240), rgb(120, 70, 40) }),
		outfit = outfit or rng:pick({ "casual", "jacket", "office" }),
		blazer = if rng:chance(0.4) then rng:pick({ rgb(40, 44, 60), rgb(60, 50, 44) }) else nil,
		jacket = rng:pick({ rgb(30, 30, 34), rgb(80, 40, 40), rgb(40, 60, 90) }),
		accent = rng:pick({ rgb(150, 30, 40), rgb(40, 70, 150), rgb(40, 110, 60) }),
		beard = if rng:chance(0.25) then rng:pick({ "stubble", "goatee", "mustache" }) else nil,
		extras = if rng:chance(0.2) then { "glasses" } else nil,
	}
end

-- A few pedestrians walking along the sidewalks for life on the street.
local function pedestrians(D, rng, n)
	local walkers = {}
	for i = 1, n do
		local side = rng:sign()
		local x0 = rng:float(-380, 100)
		local m = D.actor(modernLook(rng), CF(x0, 3, side * 19.5))
		table.insert(walkers, { m = m, side = side })
	end
	for _, w in walkers do
		task.spawn(function()
			local dir = if math.random() < 0.5 then 1 else -1
			while w.m.Parent do
				local p = w.m:GetPivot().Position
				local tx = math.clamp(p.X + dir * math.random(60, 140), -400, 110)
				S.AI.walkTo(w.m, V(tx, 3, w.side * 19.5 + math.random(-2, 2)), math.random(8, 11), 18)
				if math.random() < 0.3 then
					w.m:SetAttribute("Pose", "Phone")
					task.wait(math.random(2, 5))
					w.m:SetAttribute("Pose", nil)
				end
				dir = -dir
			end
		end)
	end
end

function Ch.run(D)
	local b = D.bible()
	local rng = RNG.new(D.seed()):fork("prologueActors")
	local refs = D.ensure("prologue", function()
		return S.WorldPrologue.build(b, D.seed())
	end)
	D.lock(true, true, true)
	D.look("office")
	D.zone("apartment")
	D.music("Calm")
	D.spawnPlayers(refs.wakeCF)
	S.WorldPrologue.setNight(refs, false)
	pedestrians(D, rng, 8)

	-- wake up -----------------------------------------------------------------
	local eye = CFrame.lookAt(refs.wakeCF.Position + V(0, 1.6, 0), refs.wakeCF.Position + refs.wakeCF.LookVector * 10 + V(0, 1.4, 0))
	D.fade("clear", 0.1)
	D.scene("blink", { times = 2 })
	D.cutscene({ shots = { { cf = refs.ceilingCam, t = 2.6, fov = 70 }, { cf = refs.ceilingCam, to = eye, t = 1.6, fov = 70 } }, bars = false, duration = 4.3 })
	D.title(b.weekday .. ", 7:02 AM", "The last ordinary day.")
	D.say(D.lines("wake"))
	D.lock(false, true, true)

	-- breakfast ----------------------------------------------------------------
	D.objective("Eat breakfast", b.breakfast)
	D.marker(refs.plate.Position + V(0, 1, 0), "Breakfast")
	D.waitPrompt(refs.plate, "Eat", b.breakfast)
	D.marker(nil)
	D.lock(true, true, true)
	D.fade("black", 0.5)
	for _ = 1, 4 do
		Net.fireAll("FX", "Text", { pos = refs.plate.Position + V(0, 2, 0), text = "*munch*", color = rgb(255, 255, 255), size = 0.6 })
		task.wait(0.35)
	end
	D.fade("clear", 0.6)
	D.say(D.lines("breakfast"))
	D.lock(false, true, true)

	-- go to work -----------------------------------------------------------------
	D.objective("Go to work", b.company)
	D.marker(refs.aptDoor.Position, "Front door")
	D.waitPrompt(refs.aptDoor, "Open", "Front door")
	refs.aptDoor.CanCollide = false
	refs.aptDoor.Transparency = 1
	D.zone("street_day")
	D.marker(refs.officeDoor, b.company)
	-- coworkers & boss
	local coworkers = {}
	for i, seat in refs.coworkerSeats do
		if i <= 9 then
			local m = D.actor(modernLook(rng, "office"), seat, { anchored = true, pose = "Type" })
			table.insert(coworkers, m)
		end
	end
	local boss = D.actor({ race = "Human", outfit = "suit", skin = rng:pick(Palette.skin), hair = rgb(120, 120, 128), hairStyle = "bald", beard = "mustache", shirt = rgb(240, 240, 240), accent = rgb(40, 40, 120), mood = "angry", name = b.bossName, scale = 1.05 }, refs.bossSpot, { anchored = true, pose = "Crossed" })
	for i, m in coworkers do
		local chatter = D.lines("coworker")
		local alt = chatter[((i - 1) % #chatter) + 1]
		S.PlayerService.prompt(m.PrimaryPart, "Talk", b.coworkers[((i - 1) % 3) + 1] or "Coworker", function(player)
			D.say(alt, { player = player })
		end, { dist = 8 })
	end
	D.waitNear(refs.officeDoor, 10)
	D.zone("office")
	D.waitNear(refs.officeInside, 14)
	D.lock(true, true, true)
	S.NPCs.pose(boss, "Talk")
	D.say(D.lines("office_boss"), { cam = { cf = CFrame.lookAt(refs.bossSpot.Position + refs.bossSpot.LookVector * 7 + V(1, 1.6, 0), refs.bossSpot.Position + V(0, 1.8, 0)), fov = 55 } })
	S.NPCs.pose(boss, "Crossed")
	D.lock(false, true, true)
	D.objective("Sit at your desk")
	D.marker(refs.myDesk.Position, "Desk")
	D.waitPrompt(refs.myDesk, "Work", "Spreadsheet #4,812")
	D.marker(nil)
	D.lock(true, true, true)
	D.teleport(refs.mySeat)
	local keys = {}
	local pool = { "A", "S", "D", "F", "J", "K", "L", "E", "R", "U" }
	for i = 1, 9 do
		table.insert(keys, rng:pick(pool))
	end
	task.spawn(function()
		D.say(D.lines("office_work"), { auto = 1.5, cam = { cf = refs.deskCam, fov = 50 } })
	end)
	local score = D.qte("type", { keys = keys, per = 1.05, title = "QUARTERLY REPORT", time = 14 }) or 0
	D.fade("black", 0.8)
	D.title("17:00", if score >= 8 then "Flawless. Nobody noticed." else "Nine hours of your life, gone.")
	D.zone("street_evening")
	task.wait(1.5)
	D.fade("clear", 0.8)
	S.NPCs.pose(boss, "Talk")
	D.say(D.lines("office_done"), { cam = { cf = CFrame.lookAt(refs.bossSpot.Position + refs.bossSpot.LookVector * 7 + V(1, 1.6, 0), refs.bossSpot.Position + V(0, 1.8, 0)), fov = 55 } })
	S.PlayerService.teleportAll(CF(refs.officeInside + V(0, 0, 3)))
	D.lock(false, true, true)

	-- go home ---------------------------------------------------------------------
	for _, m in coworkers do
		m:SetAttribute("Pose", "Phone")
	end
	D.objective("Go home")
	D.marker(refs.aptCenter, "Home")
	D.waitNear(refs.aptCenter, 16)
	D.lock(true, true, true)
	D.fade("black", 0.5)
	D.look("casual", true)
	D.fade("clear", 0.5)
	D.lock(false, true, true)
	D.objective("Eat something", b.dinner)
	D.marker(refs.fridge.Position, "Fridge")
	D.waitPrompt(refs.fridge, "Cook", b.dinner)
	D.marker(nil)
	D.lock(true, true, true)
	D.fade("black", 0.6)
	D.teleport(refs.dinnerSpot)
	task.wait(0.8)
	D.fade("clear", 0.6)
	D.say(D.lines("dinner"))

	-- night: the club -----------------------------------------------------------------
	D.zone("street_night")
	S.WorldPrologue.setNight(refs, true)
	D.scene("phone", { from = b.friend, messages = { { text = "yo " .. b.hero }, { text = b.club .. " tonight. 11pm. no excuses" }, { text = "...fine. just once.", me = true } }, hold = 2 })
	task.wait(3.5)
	D.say(D.lines("phone"))
	D.fade("black", 0.6)
	D.look("night", true)
	-- the club queue and bouncer
	for _, cf in refs.clubQueue do
		D.actor(modernLook(rng, "jacket"), cf, { anchored = true, pose = rng:pick({ "Phone", "Crossed", "Dance", nil }) })
	end
	D.actor({ race = "Human", outfit = "bouncer", skin = rng:pick(Palette.skin), hairStyle = "bald", scale = 1.2, name = "Bouncer" }, refs.bouncer, { anchored = true, pose = "Crossed" })
	D.fade("clear", 0.6)
	D.lock(false, true, true)
	D.objective("Go to the club", b.club)
	D.marker(refs.clubDoor, b.club)
	local crossEntry = refs.crossing + V(-12, 3, 0)
	D.waitUntil(function()
		for _, p in D.players() do
			local c = p.Character
			local r = c and c.PrimaryPart
			if r and r.Position.X > 133 and r.Position.X < 167 and math.abs(r.Position.Z - 40) < 9 then
				return true
			end
		end
		return false
	end, nil, 0.1)

	-- the truck ---------------------------------------------------------------------
	D.lock(true, true, true)
	D.marker(nil)
	D.objective(nil)
	local leader = D.leader()
	local char = leader and leader.Character
	local pos = if char then char:GetPivot().Position else refs.crossing + V(0, 3, 0)
	local dur = 2.6
	local impact = 0.735 * dur
	D.scene("truck", { company = b.truck, color = rng:pick({ rgb(200, 40, 40), rgb(230, 230, 235), rgb(40, 90, 200) }), from = refs.truckFrom, to = refs.truckTo, dur = dur })
	D.bark(char, "...huh?", 2)
	task.delay(impact, function()
		for _, p in D.players() do
			local c = p.Character
			if c then
				S.Ragdoll.enable(c, V(math.random(-8, 8), 80, 150), 16)
			end
		end
		Net.fireAll("FX", "Flash", { pos = pos + V(0, 2, -4), color = rgb(255, 250, 230), size = 30, t = 0.4 })
		Net.fireAll("FX", "Hit", { pos = pos, dir = V(0, 0.4, 1), blood = "red", dmg = 60, heavy = true })
		D.shake(5, 0.8)
		D.scene("flashWhite", { inT = 0.05, hold = 0.05, outT = 0.8 })
	end)
	D.cutscene({
		shots = {
			{ cf = CFrame.lookAt(pos + V(0, 1.6, 0), pos + V(0, 1.2, -60)), toFov = 38, fov = 70, t = 1.25, ease = "in" },
			{ cf = CFrame.lookAt(V(178, 5, 56), pos + V(0, 2, -6)), t = 0.7 },
			{ follow = char, offset = V(18, 7, 10), offsetTo = V(26, 14, 30), t = 2.6, fadeTo = "black", fadeTime = 1.4, fov = 60 },
		},
		bars = true,
		skippable = false,
		duration = 4.6,
	})
	D.fade("black", 0.3)
	D.say(D.lines("truck"), { auto = 1.5 })
	S.State.run.flags.prologueDone = true
	return "Afterlife"
end

return Ch
