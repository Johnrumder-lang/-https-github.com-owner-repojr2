--!nonstrict
-- CHAPTER 2: Summoned by a kingdom, appraised as garbage, thrown into the Abyss.
-- The guards keep the hero on the circle until the Appraisal, the crystal reads
-- the soul (holographic status in the hall), then two guards drag the hero to the
-- trapdoor, it swings open and they throw them down the shaft.
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Palette = require(Shared.Palette)
local RNG = require(Shared.RNG)
local Enemies = require(Shared.Enemies)
local Util = require(Shared.Util)
local S = require(script.Parent.Parent.S)

local Ch: any = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB

local GUARD_BARKS = {
	"Back to the circle, Hero.",
	"Nobody leaves before the Appraisal.",
	"The crystal. Now.",
	"Don't make me drag you.",
	"The King is waiting. Move.",
	"Where do you think you're going?",
}

function Ch.kingLook(b)
	return { name = "King " .. b.king, race = "Human", outfit = "king", skin = rgb(240, 200, 170), hair = rgb(200, 200, 206), hairStyle = "short", beard = "full", mood = "smug", scale = 1.08 }
end

function Ch.archmageLook(b)
	local look = table.clone(S.Bosses.ARCHMAGE_DEF.look)
	look.name = b.archmage
	return look
end

-- ------------------------------------------------------------------ puppet helpers
local function free(m: Model, speed: number)
	local root = m.PrimaryPart
	local hum = m:FindFirstChildOfClass("Humanoid")
	if root then
		root.Anchored = false
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	if hum then
		hum.WalkSpeed = speed
	end
	m:SetAttribute("Pose", nil)
end

local function park(m: Model, cf: CFrame, pose: string?)
	local root = m.PrimaryPart
	if root then
		root.Anchored = true
		m:PivotTo(cf)
	end
	m:SetAttribute("Pose", pose)
end

-- walk to a point, re-issuing MoveTo while the target moves
local function chase(m: Model, target: () -> Vector3?, near: number, timeout: number): boolean
	local hum = m:FindFirstChildOfClass("Humanoid")
	local t0 = os.clock()
	while os.clock() - t0 < timeout do
		local root = m.PrimaryPart
		local p = target()
		if not hum or not root or not m.Parent or not p then
			return false
		end
		if Util.flatDist(root.Position, p) < near then
			return true
		end
		hum:MoveTo(p)
		task.wait(0.1)
	end
	return false
end

local function charRoot(p: Player): BasePart?
	local c = p.Character
	return c and c.PrimaryPart
end

-- ------------------------------------------------------------------ the leash
-- While the hero may walk around, a guard runs over and shoves anybody who
-- strays from the circle back towards the crystal. Far strays get dragged back.
local function leash(D, refs, guards, posts)
	local c = refs.ritualCenter
	local R = refs.leashR or 17
	local running = true
	local busyGuard = {}
	local busyPlayer = {}
	local barkIx = 0
	local function nearestFreeGuard(pos: Vector3)
		local best, bd = nil, math.huge
		for i, g in guards do
			local r = g.PrimaryPart
			if r and not busyGuard[g] then
				local d = (r.Position - pos).Magnitude
				if d < bd then
					best, bd = i, d
				end
			end
		end
		return best
	end
	local function shove(p: Player)
		local pr = charRoot(p)
		local gi = nearestFreeGuard(if pr then pr.Position else c)
		if not gi then
			return
		end
		local g = guards[gi]
		busyGuard[g] = true
		free(g, 24)
		local reached = chase(g, function()
			local r = charRoot(p)
			return r and r.Position
		end, 5, 5)
		local r = charRoot(p)
		if reached and r and running then
			S.NPCs.face(g, r.Position)
			S.NPCs.act(g, "Grab", 0.08, 0.15, 0.35)
			barkIx = barkIx % #GUARD_BARKS + 1
			D.bark(g, GUARD_BARKS[barkIx], 2.2)
			local toward = Util.flatUnit(c - r.Position)
			local e = S.Entities.forPlayer(p)
			if e then
				S.Combat.push(e, toward * 78 + V(0, 22, 0))
			end
			Net.fireAll("FX", "Sound", { name = "Block", pos = r.Position, pitch = 0.8 })
			Net.fireAll("FX", "Dust", { pos = r.Position - V(0, 2.5, 0), count = 8 })
			task.wait(0.8)
		end
		-- back to the post
		local post = posts[gi]
		chase(g, function()
			return post.Position
		end, 1.5, 6)
		if running then
			park(g, post, "Guard")
		end
		busyGuard[g] = nil
	end
	task.spawn(function()
		while running do
			for _, p in D.players() do
				local r = charRoot(p)
				if r and not busyPlayer[p] then
					local d = Util.flatDist(r.Position, c)
					if d > R + 22 or math.abs(r.Position.Y - c.Y) > 30 then
						-- slipped out of the hall: the guards haul them straight back
						busyPlayer[p] = true
						D.bark(guards[1], "Get back here!", 2)
						S.PlayerService.teleport(p, CFrame.lookAt(c + V(0, 3, 3), c + V(0, 3, -10)))
						task.delay(1, function()
							busyPlayer[p] = nil
						end)
					elseif d > R then
						busyPlayer[p] = true
						task.spawn(function()
							shove(p)
							busyPlayer[p] = nil
						end)
					end
				end
			end
			task.wait(0.15)
		end
	end)
	return function()
		running = false
		for i, g in guards do
			if g.Parent then
				park(g, posts[i], "Guard")
			end
		end
	end
end

-- ------------------------------------------------------------------ trapdoor
local function openTrapdoor(refs, dur: number)
	local leaves = refs.trapLeaves or {}
	Net.fireAll("FX", "Sound", { name = "Door", pos = refs.trapdoor, pitch = 0.55, vol = 1 })
	Net.fireAll("FX", "Dust", { pos = refs.trapdoor, count = 14 })
	local t0 = os.clock()
	while os.clock() - t0 < dur do
		local k = Util.easeOut(math.clamp((os.clock() - t0) / dur, 0, 1), 3)
		for _, l in leaves do
			l.part.CFrame = l.hinge * ANG(0, 0, l.dir * k * 1.8) * l.offset
		end
		RunService.Heartbeat:Wait()
	end
	for _, l in leaves do
		l.part.CFrame = l.hinge * ANG(0, 0, l.dir * 1.8) * l.offset
	end
	Net.fireAll("FX", "Sound", { name = "Slam", pos = refs.trapdoor, pitch = 0.7, vol = 0.7 })
end

local function closeTrapdoor(refs)
	for _, l in refs.trapLeaves or {} do
		l.part.CFrame = l.hinge * l.offset
	end
end

-- Two guards drag an anchored hero (heels scraping) from where they stand to `to`.
local function drag(char: Model, gA: Model, gB: Model, to: Vector3, speed: number)
	local root = char.PrimaryPart
	if not root then
		return
	end
	root.Anchored = true
	char:SetAttribute("Pose", "Dragged")
	local from = root.Position
	local flat = V(to.X - from.X, 0, to.Z - from.Z)
	local dist = flat.Magnitude
	if dist < 0.5 then
		return
	end
	local dir = flat.Unit
	local side = dir:Cross(Vector3.yAxis)
	for _, g in { gA, gB } do
		free(g, speed + 3)
	end
	local dur = dist / speed
	local t0 = os.clock()
	while true do
		local k = math.clamp((os.clock() - t0) / dur, 0, 1)
		local p = from + flat * k
		-- hauled backwards: body leans back and faces away from the trapdoor
		root.CFrame = CFrame.lookAt(p, p - dir) * ANG(-0.35, 0, 0)
		local hA, hB = gA:FindFirstChildOfClass("Humanoid"), gB:FindFirstChildOfClass("Humanoid")
		if hA then
			hA:MoveTo(p + side * 2.3 + dir * 0.4)
		end
		if hB then
			hB:MoveTo(p - side * 2.3 + dir * 0.4)
		end
		if k >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
end

-- The throw: a short scripted arc out over the hole, then the body goes limp and
-- falls down the shaft for real.
local function throwInto(char: Model, hole: Vector3, spin: number)
	local root = char.PrimaryPart
	if not root then
		return
	end
	local from = root.Position
	local to = V(hole.X, hole.Y + 2.5, hole.Z)
	local dur = 0.42
	local t0 = os.clock()
	while true do
		local k = math.clamp((os.clock() - t0) / dur, 0, 1)
		local p = from:Lerp(to, k) + V(0, math.sin(k * math.pi) * 5, 0)
		root.CFrame = CF(p) * ANG(-k * 2.2, spin * k * 1.4, spin * k * 0.6)
		if k >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	char:SetAttribute("Pose", nil)
	root.Anchored = false
	S.Ragdoll.enable(char, V(math.random(-2, 2), -24, math.random(-2, 2)), 5)
end

-- ------------------------------------------------------------------ chapter
function Ch.run(D)
	local b = D.bible()
	local rng = RNG.new(D.seed()):fork("summon")
	D.lock(true, true, true)
	local refs = D.ensureCapital()
	D.zone("ritual")
	D.music("Calm")
	D.look("night")
	-- give time stop if the prologue was skipped
	D.giveAll(function(p, prof)
		prof.abilities.timestop = true
	end)
	closeTrapdoor(refs)
	local c = refs.ritualCenter
	local spawnCF = CFrame.lookAt(c + V(0, 3, 0), c + V(0, 3, -20))
	D.spawnPlayers(spawnCF)
	D.checkpoint(spawnCF)

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
	local mageCam = { cf = CFrame.lookAt(c + V(10, 5, 8), mages[1]:GetPivot().Position), fov = 55 }
	local lines = D.lines("summon")
	for _, l in lines do
		l.cam = if l.speaker:find("King") then kingCam elseif l.speaker == b.archmage then archCam else mageCam
	end
	for _, m in mages do
		m:SetAttribute("Pose", "Crossed")
	end
	D.say(lines)

	-- free to move, but the guards won't let the hero leave
	D.lock(false, true, true)
	D.objective("Place your hand on the crystal")
	D.marker(refs.crystal.Position + V(0, 2, 0), "Crystal")
	local stopLeash = leash(D, refs, guards, refs.guardSpots)
	D.waitPrompt(refs.crystal, "Touch", "Appraisal Crystal")
	stopLeash()
	D.marker(nil)
	D.objective(nil)
	D.lock(true, true, true)

	-- the appraisal: hand on the crystal, the soul read out in the air above it
	local cp = refs.crystal.Position
	local toCenter = Util.flatUnit(c - cp)
	local standPos = V(cp.X, c.Y + 2.6, cp.Z) + toCenter * 3.3
	local standCF = CFrame.lookAt(standPos, V(cp.X, standPos.Y, cp.Z))
	local side = toCenter:Cross(Vector3.yAxis)
	for i, p in D.players() do
		local r = charRoot(p)
		if r then
			local at = if i == 1 then standCF else standCF * CF((i - 1) * 3 - 5, 0, 4)
			S.PlayerService.teleport(p, at)
			r.Anchored = true
			p.Character:SetAttribute("Pose", "Cast")
		end
	end
	local panelPos = cp + V(0, 8.5, 0) - toCenter * 2
	D.scene("appraisal", { power = b.power, dur = 10.5, crystal = refs.crystal, panel = CFrame.lookAt(panelPos, V(standPos.X, panelPos.Y, standPos.Z)) })
	for _, m in mages do
		m:SetAttribute("Pose", "Channel")
	end
	D.cutscene({
		shots = {
			{ cf = CFrame.lookAt(cp + side * 4.5 + toCenter * 1.5 - V(0, 0.6, 0), cp - V(0, 0.4, 0)), to = CFrame.lookAt(cp + side * 3.2 + toCenter * 1.2 - V(0, 0.4, 0), cp - V(0, 0.4, 0)), t = 1.8, fov = 45, shake = 0.6 },
			{ orbit = { center = cp - V(0, 1, 0), r = 10, h = 1.5, a0 = math.atan2(toCenter.Z, toCenter.X) + 0.9, a1 = math.atan2(toCenter.Z, toCenter.X) + 2.3, lookY = 3 }, t = 3.0, fov = 58 },
			{ cf = CFrame.lookAt(standPos + toCenter * 9 + side * 2 + V(0, 3.5, 0), panelPos), to = CFrame.lookAt(standPos + toCenter * 6.5 + side * 1.2 + V(0, 3, 0), panelPos), t = 5.6, fov = 55 },
		},
		duration = 10.4,
		skippable = false,
	})
	-- verdict: the court laughs
	for _, m in mages do
		m:SetAttribute("Pose", "Crossed")
	end
	for i, n in nobles do
		n:SetAttribute("Pose", "Talk")
		if i % 2 == 1 then
			task.delay(i * 0.25, function()
				D.bark(n, rng:pick({ "Hah!", "Pathetic.", "Hahaha!", "A dud!", "Below a chicken!" }), 2)
			end)
		end
	end
	for _, p in D.players() do
		local r = charRoot(p)
		if r then
			p.Character:SetAttribute("Pose", nil)
		end
	end
	local ap = D.lines("appraisal")
	for _, l in ap do
		l.cam = if l.speaker:find("King") then kingCam elseif l.speaker == b.archmage then archCam elseif l.speaker == "You" then { cf = CFrame.lookAt(standPos + toCenter * 5 + side * 3 + V(0, 1.5, 0), standPos + V(0, 1.4, 0)), fov = 55 } else mageCam
	end
	S.NPCs.act(archmage, "Point", 0.1, 0.4, 1.2)
	D.say(ap)

	-- the throw -------------------------------------------------------------------
	local leader = D.leader()
	local heroChar = leader and leader.Character
	local hole = refs.trapdoor
	local toHole = Util.flatUnit(hole - standPos)
	local edge = V(hole.X, standPos.Y, hole.Z) - toHole * 4.2
	local gA, gB = guards[1], guards[2]
	-- guards march over and grab
	task.spawn(function()
		free(gA, 20)
		chase(gA, function()
			return standPos + side * 2.3
		end, 1.5, 4)
	end)
	free(gB, 20)
	task.spawn(function()
		chase(gB, function()
			return standPos - side * 2.3
		end, 1.5, 4)
	end)
	D.cutscene({
		shots = {
			{ cf = CFrame.lookAt(standPos + side * 9 + V(0, 2.5, 0), standPos), to = CFrame.lookAt(standPos + side * 7 + V(0, 2, 0), standPos), t = 1.8, fov = 55 },
		},
		duration = 1.8,
		skippable = false,
	})
	for _, p in D.players() do
		local ch = p.Character
		if ch and ch.PrimaryPart then
			ch.PrimaryPart.Anchored = true
			ch:SetAttribute("Pose", "Dragged")
		end
	end
	if heroChar then
		D.bark(heroChar, "Let go of me!", 2)
	end
	local dragDone = false
	task.spawn(function()
		if heroChar then
			drag(heroChar, gA, gB, edge, 9)
		end
		dragDone = true
	end)
	-- the other summoned souls get the same treatment by the second pair
	for i, p in D.players() do
		if i > 1 and p.Character and p.Character.PrimaryPart then
			local ch = p.Character
			task.spawn(function()
				local off = V(0, 0, 0) - toHole * (3 * i)
				local t0 = os.clock()
				local from = ch.PrimaryPart.Position
				while os.clock() - t0 < 2.4 and ch.Parent do
					local k = (os.clock() - t0) / 2.4
					ch.PrimaryPart.CFrame = CFrame.lookAt(from:Lerp(edge + off, k), from:Lerp(edge + off, k) - toHole)
					RunService.Heartbeat:Wait()
				end
			end)
		end
	end
	local midDrag = (standPos + edge) / 2
	D.cutscene({
		shots = {
			{ cf = CFrame.lookAt(midDrag + side * 14 + V(0, 5, 0) + toHole * 3, midDrag), to = CFrame.lookAt(edge + side * 11 + V(0, 4, 0) + toHole * 4, edge), t = 2.6, fov = 55, shake = 1 },
		},
		duration = 2.6,
		skippable = false,
	})
	D.waitUntil(function()
		return dragDone
	end, 3, 0.05)
	-- the trapdoor swings open under the King's nod
	S.NPCs.act(king, "Point", 0.1, 0.3, 0.8)
	task.spawn(openTrapdoor, refs, 0.9)
	D.cutscene({
		shots = {
			{ cf = CFrame.lookAt(hole + V(0, 7, 0) + toHole * 7 + side * 3, hole - V(0, 6, 0)), to = CFrame.lookAt(hole + V(0, 6, 0) + toHole * 6 + side * 2, hole - V(0, 14, 0)), t = 1.5, fov = 60 },
		},
		duration = 1.5,
		skippable = false,
	})
	if heroChar then
		D.bark(heroChar, "Wait— wait, WAIT—", 1.6)
	end
	-- heave!
	S.NPCs.act(gA, "Throw", 0.12, 0.1, 0.5)
	S.NPCs.act(gB, "Throw", 0.12, 0.1, 0.5)
	for i, p in D.players() do
		local ch = p.Character
		if ch then
			task.delay((i - 1) * 0.35, throwInto, ch, hole, if i % 2 == 0 then -1 else 1)
		end
	end
	Net.fireAll("FX", "Sound", { name = "SwingHeavy", pos = hole, pitch = 0.7 })
	task.delay(1.5, function()
		Net.fireAll("FX", "Sound", { name = "Slam", pos = refs.shaftBottom or hole, pitch = 0.5, vol = 1 })
	end)
	D.cutscene({
		shots = {
			{ cf = CFrame.lookAt(hole + V(0, 1.5, 0) - toHole * 7 + side * 4, hole + V(0, 5, 0)), t = 0.5, fov = 70 },
			{ follow = heroChar, offset = V(0.6, 9, 1.8), offsetTo = V(0.4, 16, 1.2), lookY = -2, t = 1.9, fov = 80, fadeTo = "black", fadeTime = 0.7, shake = 2 },
		},
		duration = 2.4,
		skippable = false,
		bars = false,
	})
	D.fade("black", 0.2)
	-- the guards look down the hole, then the court goes back to its business
	task.wait(0.4)
	for _, p in D.players() do
		local ch = p.Character
		if ch and S.Ragdoll.isRagdolled(ch) then
			S.Ragdoll.disable(ch)
		end
		local r = ch and ch.PrimaryPart
		if r then
			r.Anchored = false
			ch:SetAttribute("Pose", nil)
		end
	end
	closeTrapdoor(refs)
	D.clearActors()
	return "Pit"
end

return Ch
