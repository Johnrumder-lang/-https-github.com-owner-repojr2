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
		D.fade("black", 0.1)
		D.spawnPlayers(CFrame.lookAt(bp + V(0, 4, 0), V(0, bp.Y + 4, 0)))
		task.wait(0.5)
		D.cutscene({
			shots = {
				{ cf = CFrame.lookAt(bp + V(22, 4, 18), bp + V(0, 2, 0)), t = 1.2, fov = 60, shake = 2, fromFade = 0.2 },
				{ cf = CFrame.lookAt(bp + V(14, 3, 10), bp + V(0, 6, 0)), t = 1.4, fov = 55, shake = 6 },
				{ cf = CFrame.lookAt(bp + V(3, 6, 14), refs.center + V(0, 60, 0)), to = CFrame.lookAt(bp + V(1, 5, 6), refs.center + V(0, 60, 0)), t = 3.2, fov = 60 },
			},
			duration = 5.8,
		})
		task.delay(1.1, function()
			D.scene("burst", { pos = bp })
		end)
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
