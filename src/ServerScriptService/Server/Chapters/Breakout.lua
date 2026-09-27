--!nonstrict
-- CHAPTER 4: Bursting out of the ground into the lower fields, then the Lower
-- Village rises against the "defective hero".
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local RNG = require(Shared.RNG)
local Kit = require(Shared.Kit)
local S = require(script.Parent.Parent.S)

local Ch: any = {}
local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB

function Ch.burnHouses(houses, rng, fraction, maxFires: number?)
	-- (the v4 city has hundreds of houses: cap the fires, every one carries a light)
	local left = maxFires or 36
	for _, h in houses do
		if left > 0 and rng:chance(fraction) then
			left -= 1
			local model = h.model or h
			local parts = {}
			for _, p in model:GetChildren() do
				if p:IsA("BasePart") and p.Size.X > 8 then
					table.insert(parts, p)
				end
			end
			if #parts > 0 then
				local roof = parts[#parts]
				Kit.fire(roof, rgb(255, 130, 40), 2.5)
				Kit.emitter(roof, { Texture = Kit.SMOKE, Color = ColorSequence.new(rgb(50, 46, 44)), LightEmission = 0, Rate = 8, Speed = NumberRange.new(6, 10), Lifetime = NumberRange.new(4, 7), Size = NumberSequence.new(3, 9), Transparency = NumberSequence.new(0.4, 1), Acceleration = V(2, 3, 0) })
				Kit.pointLight(roof, rgb(255, 140, 60), 40, 1.6)
			end
		end
	end
end

-- the hole the hero climbs out of: a ring of torn-up earth and rocks
function Ch.crater(pos: Vector3, rng)
	local folder = S.World.sub("Props")
	local m = Kit.model("Crater", folder)
	Kit.part(m, V(9, 0.4, 9), CF(pos + V(0, 0.1, 0)) * CFrame.Angles(0, 0.3, 0), rgb(40, 30, 24), Enum.Material.Ground)
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2 + rng:float(-0.15, 0.15)
		local r = rng:float(5.5, 8)
		local sz = rng:float(1.6, 3.4)
		Kit.part(m, V(sz, sz * 0.7, sz), CF(pos + V(math.cos(a) * r, sz * 0.25, math.sin(a) * r)) * CFrame.Angles(rng:float(-0.6, 0.6), rng:angle(), rng:float(-0.6, 0.6)), if i % 3 == 0 then rgb(110, 104, 96) else rgb(96, 70, 48), if i % 3 == 0 then Enum.Material.Slate else Enum.Material.Ground)
	end
	return m
end

function Ch.run(D)
	local b = D.bible()
	local rng = RNG.new(D.seed()):fork("breakout")
	local refs = D.ensureCapital()
	local run = S.State.run
	D.zone("fields")
	D.music("Calm")
	if not run.flags.burst then
		D.lock(true, true, false)
		local bp = refs.burstPoint
		local ga = refs.groundAt or function()
			return bp.Y
		end
		-- camera points stay above the real ground (the fields roll)
		local function camAt(off: Vector3, h: number): Vector3
			local p = bp + off
			return V(p.X, math.max(ga(p.X, p.Z), bp.Y) + h, p.Z)
		end
		local toCity = V(0, bp.Y, 0)
		D.fade("black", 0.1)
		-- the hero starts under the field, anchored, clawing upward
		local under = CFrame.lookAt(bp - V(0, 9, 0), V(toCity.X, bp.Y - 9, toCity.Z))
		D.spawnPlayers(under)
		for i, p in D.players() do
			local c = p.Character
			local r = c and c.PrimaryPart
			if r then
				r.Anchored = true
				r.CFrame = under * CF((i - 1) * 4, 0, 0)
				c:SetAttribute("Pose", "HandsUp")
			end
		end
		task.wait(0.4)
		-- the burst: 1.4 s in, the ground splits and the hero is thrown up out of it
		task.delay(1.4, function()
			D.scene("burst", { pos = bp })
			Ch.crater(bp, rng)
			for i, p in D.players() do
				local c = p.Character
				local r = c and c.PrimaryPart
				if r then
					task.spawn(function()
						local from = r.Position
						local to = bp + V((i - 1) * 4, 7, 0)
						local t0 = os.clock()
						while os.clock() - t0 < 0.32 do
							local k = (os.clock() - t0) / 0.32
							r.CFrame = CFrame.lookAt(from:Lerp(to, k), V(toCity.X, from.Y + (to.Y - from.Y) * k, toCity.Z))
							task.wait()
						end
						c:SetAttribute("Pose", nil)
						r.Anchored = false
						r.AssemblyLinearVelocity = V(0, 26, 0)
					end)
				end
			end
		end)
		D.cutscene({
			shots = {
				-- low over the field: it rumbles
				{ cf = CFrame.lookAt(camAt(V(12, 0, 9), 2.5), bp + V(0, 0.5, 0)), to = CFrame.lookAt(camAt(V(10, 0, 7), 2), bp + V(0, 0.5, 0)), t = 1.4, fov = 60, shake = 2.5, fromFade = 0.25 },
				-- the burst: dirt everywhere, the hero in the air
				{ cf = CFrame.lookAt(camAt(V(20, 0, 16), 5), bp + V(0, 7, 0)), to = CFrame.lookAt(camAt(V(17, 0, 13), 4), bp + V(0, 5, 0)), t = 1.6, fov = 58, shake = 6 },
				-- over the shoulder: the walls of the capital on the horizon
				{ cf = CFrame.lookAt(camAt(V(3, 0, 12), 7), toCity + V(0, 90, 0)), to = CFrame.lookAt(camAt(V(1.5, 0, 6), 6), toCity + V(0, 90, 0)), t = 3.0, fov = 60 },
			},
			duration = 6.0,
			skippable = false,
		})
		for _, p in D.players() do
			local c = p.Character
			local r = c and c.PrimaryPart
			if r and r.Anchored then
				r.Anchored = false
				c:SetAttribute("Pose", nil)
				r.CFrame = CFrame.lookAt(bp + V(0, 4, 0), V(toCity.X, bp.Y + 4, toCity.Z))
			end
		end
		D.title("THE LOWER FIELDS", "Revenge begins.")
		D.say(D.lines("burst"))
		run.flags.burst = true
		D.save()
	else
		D.spawnPlayers(refs.fieldsSpawn)
		D.fade("clear", 0.8)
	end
	D.checkpoint(refs.fieldsSpawn)
	D.lock(false, false, false)
	task.delay(4, function()
		D.tutorial("The lands are wide: press H to whistle for your horse", "H", 7)
	end)

	-- a few goblins raiding the fields
	for i = 1, 3 do
		local p = refs.burstPoint + V(rng:float(-80, 80), 2, rng:float(-110, -40))
		S.AI.spawnGroup({ "Goblin", "Goblin", "GoblinShaman" }, p, 8, { level = 9, tags = { fields = true } })
	end

	D.objective("Reach the Lower Village")
	D.marker(refs.lowerVillageEdge, "Lower Village")
	D.waitNear(refs.lowerVillageEdge, 60)
	D.marker(nil)

	-- the village fights back
	D.zone("village_burning", "LOWER VILLAGE", "They were told you were dead.")
	D.music("Combat")
	-- the lower city is huge now: the uprising is the quarter around the south gate
	local edge = refs.lowerVillageEdge
	local nearHouses, nearDoors = {}, {}
	for _, h in refs.lowerHouses do
		local hp = h.cf and h.cf.Position or (h.model or h):GetPivot().Position
		if (V(hp.X, 0, hp.Z) - V(edge.X, 0, edge.Z)).Magnitude < 420 then
			table.insert(nearHouses, h)
		end
	end
	for _, door in refs.spawnsLower do
		if (V(door.X, 0, door.Z) - V(edge.X, 0, edge.Z)).Magnitude < 380 and #nearDoors < 22 then
			table.insert(nearDoors, door)
		end
	end
	Ch.burnHouses(nearHouses, rng, 0.35)
	local shouts = D.lines("village_shouts")
	local level = 10
	local villagers = {}
	for i, door in nearDoors do
		local kind = rng:weighted({ { "Villager", 55 }, { "BeastVillager", 25 }, { "Militia", 20 } })
		local e = S.AI.spawn(kind, CF(door + V(0, 3, 0)), { level = level, tags = { village = true }, aggro = 110, shout = rng:pick(shouts) })
		if e then
			table.insert(villagers, e)
		end
		if i % 3 == 0 then
			S.AI.spawn("Villager", CF(door + V(rng:float(-6, 6), 3, rng:float(-6, 6))), { level = level, tags = { village = true }, aggro = 110 })
		end
	end
	for i = 1, 3 do
		S.AI.spawn("HedgeMage", CF(refs.lowerSquare + V(rng:float(-30, 30), 3, rng:float(-30, 30))), { level = level, tags = { village = true }, aggro = 120 })
	end
	local captain = S.AI.spawn("VillageCaptain", CF(refs.lowerSquare + V(0, 3, -10)), { level = level + 1, tags = { village = true }, aggro = 150, name = "Captain " .. b.captain, shout = "For " .. b.kingdom .. "!" })
	-- periodic shouting
	task.spawn(function()
		while S.Entities.countTag("village") > 0 do
			local list = S.Entities.withTag("village")
			if #list > 0 then
				local e = rng:pick(list)
				D.bark(e.model, rng:pick(shouts), 2.4)
			end
			task.wait(rng:float(2.5, 5))
		end
	end)
	D.waitKills("village", "Wipe out the Lower Village")
	D.music("Calm")
	D.objective("Push on to the Middle Village")
	D.marker(refs.middleGate, "Middle Village")
	D.waitNear(refs.middleGate + V(0, 0, 20), 40)
	D.marker(nil)
	return "Prison"
end

return Ch
