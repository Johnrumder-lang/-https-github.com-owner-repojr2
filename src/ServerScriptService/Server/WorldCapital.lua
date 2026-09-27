--!nonstrict
-- LAND 1: THE WALLED KINGDOM. A tiered capital on a hill, ringed by a colossal
-- wall with four gatehouses:
--   castle plateau (y70) > upper city, arena + prison (y52) > inner wall >
--   middle village (y30) > lower village (y12) > THE GREAT WALL (140 studs) >
--   farmland, windmills and a river > forests and a grove of giant trees >
--   a ring of snow-capped cubic mountains with a pass to the north.
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Kit = require(Shared.Kit)
local Palette = require(Shared.Palette)
local Util = require(Shared.Util)
local RNG = require(Shared.RNG)
local S = require(script.Parent.S)

local Capital = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB

local TIERS = {
	{ r = 80, y = 70 },
	{ r = 210, y = 52 },
	{ r = 400, y = 30 },
	{ r = 656, y = 12 },
}
Capital.TIERS = TIERS
Capital.WALL_R = 668
Capital.WALL_H = 140
Capital.WALL_T = 24
Capital.OUTER_Y = 4
local RAMP = 16
local ROAD_W = 9 -- half width of the four radial roads
local ROADS = { 0, math.pi / 2, math.pi, math.pi * 1.5 } -- angle 0 = +Z (south)
local SIZE = 3600
local CELL = 12
local RIVER_R = 900
local RIVER_A0, RIVER_A1 = math.rad(15), math.rad(170)
local MOUNTAIN_R = 1480
-- centre of the 12x12 heightfield cell left open for the trapdoor shaft
Capital.SHAFT = V(-6, 0, 6)

local function tierHeight(r: number): number
	for _, t in TIERS do
		if r < t.r then
			return t.y
		end
	end
	return Capital.OUTER_Y
end

local function onRoad(x: number, z: number): (boolean, number)
	local r = math.sqrt(x * x + z * z)
	for _, a in ROADS do
		local dx, dz = math.sin(a), math.cos(a)
		local along = x * dx + z * dz
		local across = math.abs(x * dz - z * dx)
		if along > 0 and across < ROAD_W and r < 1400 then
			return true, across
		end
	end
	return false, 999
end
Capital.onRoad = onRoad

local function angleOf(x: number, z: number): number
	return math.atan2(x, z) % (2 * math.pi)
end

local function riverDist(x: number, z: number): number
	local a = angleOf(x, z)
	if a < RIVER_A0 or a > RIVER_A1 then
		return 999
	end
	local r = math.sqrt(x * x + z * z)
	local wiggle = math.sin(a * 5) * 40
	return math.abs(r - (RIVER_R + wiggle))
end
Capital.riverDist = riverDist

-- height at world XZ (before quantisation)
function Capital.heightAt(x: number, z: number, seed: number): number
	local r = math.sqrt(x * x + z * z)
	local road = onRoad(x, z)
	if r < TIERS[#TIERS].r then
		if road then
			for i = 1, #TIERS - 1 do
				local t = TIERS[i]
				if math.abs(r - t.r) < RAMP then
					local k = (r - (t.r - RAMP)) / (RAMP * 2)
					return math.floor(Util.lerp(t.y, TIERS[i + 1].y, k) + 0.5)
				end
			end
		end
		return tierHeight(r)
	end
	local base = Capital.OUTER_Y
	-- the ground just outside the wall stays flat
	if r < 720 then
		return base
	end
	-- north pass through the mountains
	if z < 0 and math.abs(x) < 36 and r > 1100 then
		return base + 2 + math.max(0, r - 1300) * 0.035
	end
	-- the river
	local rd = riverDist(x, z)
	if rd < 16 then
		return 0
	elseif rd < 30 then
		return Util.lerp(0, base, (rd - 16) / 14)
	end
	local n = Util.fbm(x / 260, z / 260, 3, seed + 11)
	local hill = math.max(0, n) * 10 * math.clamp((r - 720) / 260, 0, 1)
	local h = base + hill
	if r > 1180 then
		local k = math.clamp((r - 1180) / 300, 0, 1)
		h += k * 18 * (0.5 + Util.noise(x / 120, z / 120, seed + 5))
	end
	if r > MOUNTAIN_R then
		local k = math.clamp((r - MOUNTAIN_R) / 160, 0, 1)
		h += k * (150 + Util.ridge(x / 150, z / 150, 2, seed + 3) * 150)
	end
	return h
end

local function quant(h: number, x: number, z: number): number
	if onRoad(x, z) then
		return math.floor(h + 0.5)
	end
	local r = math.sqrt(x * x + z * z)
	local step = if r > MOUNTAIN_R then 12 elseif r > 1180 then 4 elseif r > 700 then 2 else 2
	return math.floor(h / step + 0.5) * step
end
Capital.ground = function(x: number, z: number, seed: number): number
	return quant(Capital.heightAt(x, z, seed), x, z)
end

-- ------------------------------------------------------------------ the Abyss trapdoor
-- `top` = centre of the opening at floor level. The shaft fills a 12x12 column
-- (3-stud walls around a 6x6 hole) and drops 150 studs.
function Capital.trapShaft(parent: Instance, top: Vector3, refs, floorC: Color3)
	local W = S.World
	local m = Kit.model("Trapdoor", parent)
	local depth = 150
	local bottom = top.Y - depth
	local wallC = Palette.shade(floorC, 0.55)
	local x, z = top.X, top.Z
	-- shaft walls (their tops are the floor around the hole)
	W.solid(m, V(12, depth, 3), CF(x, bottom + depth / 2, z - 4.5), wallC, Enum.Material.Cobblestone)
	W.solid(m, V(12, depth, 3), CF(x, bottom + depth / 2, z + 4.5), wallC, Enum.Material.Cobblestone)
	W.solid(m, V(3, depth, 6), CF(x - 4.5, bottom + depth / 2, z), wallC, Enum.Material.Cobblestone)
	W.solid(m, V(3, depth, 6), CF(x + 4.5, bottom + depth / 2, z), wallC, Enum.Material.Cobblestone)
	-- iron rim
	for _, e in { { V(7, 0.3, 0.5), V(0, 0, -3.25) }, { V(7, 0.3, 0.5), V(0, 0, 3.25) }, { V(0.5, 0.3, 7), V(-3.25, 0, 0) }, { V(0.5, 0.3, 7), V(3.25, 0, 0) } } do
		W.deco(m, e[1], CF(top + e[2] + V(0, 0.1, 0)), rgb(46, 44, 46), Enum.Material.Metal)
	end
	-- the bottom: bones and a pale shaft of light
	W.solid(m, V(6, 2, 6), CF(x, bottom - 1, z), rgb(40, 36, 34), Enum.Material.Slate)
	for i = 1, 6 do
		W.deco(m, V(0.4, 0.4, 1.6), CF(x + math.sin(i * 2.1) * 2, bottom + 0.2, z + math.cos(i * 1.3) * 2) * ANG(0, i, 0), rgb(220, 214, 196))
	end
	W.deco(m, V(1.2, 1.2, 1.2), CF(x + 1.4, bottom + 0.6, z - 1.2) * ANG(0.2, 0.5, 0), rgb(226, 220, 204))
	for y = bottom + 20, top.Y - 20, 34 do
		local t = W.torch(m, CF(x - 2.9, y, z) * ANG(0, 0, -0.25), rgb(255, 120, 60))
		t.Name = "ShaftTorch"
	end
	-- two leaves hinged on the outer edges, swinging down into the hole
	refs.trapLeaves = {}
	for _, s in { -1, 1 } do
		local hinge = CF(x + s * 3, top.Y - 0.2, z)
		local offset = CF(-s * 1.5, 0, 0)
		local leaf = W.solid(m, V(3, 0.4, 6), hinge * offset, rgb(52, 46, 42), Enum.Material.DiamondPlate)
		leaf.Name = "TrapLeaf"
		table.insert(refs.trapLeaves, { part = leaf, hinge = hinge, offset = offset, dir = s })
	end
	refs.trapdoor = V(x, top.Y + 1, z)
	refs.shaftBottom = V(x, bottom + 1, z)
	return m
end

-- ------------------------------------------------------------------ build
function Capital.build(bible, seed: number)
	local rng = RNG.new(seed):fork("capital")
	local W = S.World
	local B = S.Build
	local N = S.Nature
	local map = W.sub("Map")
	local props = W.sub("Props")
	local city = W.sub("City")
	local refs = { houses = {}, lowerHouses = {}, middleHouses = {}, upperHouses = {}, spawnsLower = {}, spawnsMiddle = {}, spawnsUpper = {}, castleSpawns = {}, breakables = {} }
	local pal = Palette.biomes.Meadow
	local stone = rgb(150, 146, 140)
	local cobble = rgb(128, 122, 116)
	local dirt = rgb(132, 100, 70)
	local counter = { n = 0 }
	local palette = {
		pal.grass[1], pal.grass[2], pal.grass[3], pal.grass[4],
		cobble, dirt, stone, rgb(110, 80, 50), rgb(210, 190, 90), rgb(100, 150, 60), pal.rock, rgb(235, 240, 245), rgb(150, 140, 100),
	}
	local mats = {
		[5] = Enum.Material.Cobblestone,
		[6] = Enum.Material.Ground,
		[7] = Enum.Material.Slate,
		[8] = Enum.Material.Ground,
		[11] = Enum.Material.Slate,
		[12] = Enum.Material.Snow,
		[13] = Enum.Material.Sand,
	}
	-- two resolutions: fine terrain where you walk, coarse terrain for the
	-- distant mountain ring
	local INNER = 1500
	local innerOrigin = V(-INNER, 0, -INNER)
	local ni = math.floor(INNER * 2 / CELL)
	local function colorAt(x: number, z: number, h: number)
		local r = math.sqrt(x * x + z * z)
		if onRoad(x, z) then
			return if r < Capital.WALL_R + 20 then 5 else 6
		end
		if r < 80 then
			return 7
		elseif r < 210 then
			return 5
		elseif r > MOUNTAIN_R + 20 then
			return if h > 210 then 12 else 11
		end
		if riverDist(x, z) < 34 then
			return 13
		end
		if r < Capital.WALL_R + 30 then
			-- city ground: packed earth along the streets, grass behind the houses
			if math.abs(r - 520) < 30 or math.abs(r - 300) < 28 then
				return 6
			end
			return if Util.noise(x / 90, z / 90, seed) > 0.1 then 1 else 2
		end
		local g = Util.noise(x / 300, z / 300, seed)
		return if g > 0.25 then 3 elseif g > -0.05 then 1 else 2
	end
	local function material(k)
		return mats[k] or Enum.Material.Grass
	end
	W.heightfield({
		parent = map,
		origin = innerOrigin,
		nx = ni,
		nz = ni,
		cell = CELL,
		step = 1,
		base = -30,
		skip = function(ix, iz)
			local x = innerOrigin.X + (ix - 0.5) * CELL
			local z = innerOrigin.Z + (iz - 0.5) * CELL
			-- the Abyss shaft under the great hall's trapdoor
			if math.abs(x - Capital.SHAFT.X) < 1 and math.abs(z - Capital.SHAFT.Z) < 1 then
				return true
			end
			return x * x + z * z > (INNER - 20) ^ 2
		end,
		height = function(ix, iz)
			local x = innerOrigin.X + (ix - 0.5) * CELL
			local z = innerOrigin.Z + (iz - 0.5) * CELL
			return quant(Capital.heightAt(x, z, seed), x, z)
		end,
		color = function(ix, iz, h)
			return colorAt(innerOrigin.X + (ix - 0.5) * CELL, innerOrigin.Z + (iz - 0.5) * CELL, h)
		end,
		palette = palette,
		material = material,
	})
	local OUTER_CELL = 40
	local outerOrigin = V(-SIZE / 2, 0, -SIZE / 2)
	local no = math.floor(SIZE / OUTER_CELL)
	W.heightfield({
		parent = map,
		origin = outerOrigin,
		nx = no,
		nz = no,
		cell = OUTER_CELL,
		step = 1,
		base = -30,
		skip = function(ix, iz)
			local x = outerOrigin.X + (ix - 0.5) * OUTER_CELL
			local z = outerOrigin.Z + (iz - 0.5) * OUTER_CELL
			return x * x + z * z < (INNER - 40) ^ 2
		end,
		height = function(ix, iz)
			local x = outerOrigin.X + (ix - 0.5) * OUTER_CELL
			local z = outerOrigin.Z + (iz - 0.5) * OUTER_CELL
			return math.floor(Capital.heightAt(x, z, seed) / 20 + 0.5) * 20
		end,
		color = function(ix, iz, h)
			return if h > 230 then 12 else 11
		end,
		palette = palette,
		material = material,
	})

	-- tier retaining walls (stone lips along each edge)
	for i = 1, #TIERS - 1 do
		local t = TIERS[i]
		local segs = math.floor(t.r * 2 * math.pi / 18)
		local drop = t.y - TIERS[i + 1].y
		for s = 1, segs do
			local a = s / segs * math.pi * 2
			local x, z = math.sin(a) * t.r, math.cos(a) * t.r
			if not onRoad(x, z) then
				local p = V(x, t.y, z)
				local c = CFrame.lookAt(p, p + V(-math.cos(a), 0, math.sin(a)))
				W.solid(map, V(18.6, 3, 2.5), c * CF(0, 1.5, 0), Palette.shade(stone, 0.9 + (s % 3) * 0.05), Enum.Material.Cobblestone)
				W.deco(map, V(18.8, drop + 0.4, 1.2), c * CF(0, -drop / 2, 0) * CF(0, 0, 0), Palette.shade(stone, 0.8), Enum.Material.Slate)
			end
		end
	end

	-- ------------------------------------------------------------ castle
	local castle = Kit.model("Castle", city)
	local cy = TIERS[1].y
	local keepHalf = 26
	local wallC = rgb(170, 166, 158)
	local roofC = rgb(60, 70, 120)
	-- outer curtain wall with gate facing +Z
	local corners = { V(-50, cy, -50), V(50, cy, -50), V(50, cy, 50), V(-50, cy, 50) }
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		if i == 3 then
			-- south wall with a gate gap
			W.wall(castle, a, V(12, cy, 50), 16, 5, wallC)
			W.wall(castle, V(-12, cy, 50), b, 16, 5, wallC)
			W.solid(castle, V(24, 5, 5), CF(0, cy + 16.5, 50), wallC, Enum.Material.Cobblestone)
		else
			W.wall(castle, a, b, 16, 5, wallC)
		end
		W.tower(castle, a, 7, 26, wallC, roofC)
	end
	-- keep: 3 floors (great hall/ritual, halls, crown room)
	local keepC = CF(0, cy, 0)
	local FH = 24
	local kmat = Enum.Material.Cobblestone
	local function keepWalls(y0: number, h: number, doorSouth: boolean)
		local k = keepHalf
		if doorSouth then
			W.solid(castle, V(k - 5, h, 2), CF(-(k + 5) / 2 - 0, y0 + h / 2, k), wallC, kmat)
			W.solid(castle, V(k - 5, h, 2), CF((k + 5) / 2, y0 + h / 2, k), wallC, kmat)
			W.solid(castle, V(10, h - 12, 2), CF(0, y0 + 12 + (h - 12) / 2, k), wallC, kmat)
		else
			W.solid(castle, V(k * 2, h, 2), CF(0, y0 + h / 2, k), wallC, kmat)
		end
		W.solid(castle, V(k * 2, h, 2), CF(0, y0 + h / 2, -k), wallC, kmat)
		W.solid(castle, V(2, h, k * 2), CF(k, y0 + h / 2, 0), wallC, kmat)
		W.solid(castle, V(2, h, k * 2), CF(-k, y0 + h / 2, 0), wallC, kmat)
		-- tall windows
		for i = -1, 1 do
			for _, side in { V(k + 0.1, 0, 0), V(-k - 0.1, 0, 0) } do
				W.deco(castle, V(0.4, 9, 3), CF(side + V(0, y0 + h * 0.5, i * 14)), rgb(160, 190, 255), Enum.Material.Neon, { Transparency = 0.35 })
			end
			W.deco(castle, V(3, 9, 0.4), CF(i * 14, y0 + h * 0.5, -k - 0.1), rgb(160, 190, 255), Enum.Material.Neon, { Transparency = 0.35 })
		end
	end
	local wood = rgb(110, 90, 70)
	local function floorWithHole(y: number, hx0: number, hx1: number, hz0: number, hz1: number)
		local k = keepHalf
		-- west strip, east strip, north strip, south strip around the hole
		if hx0 > -k then
			W.solid(castle, V(hx0 + k, 2, k * 2), CF((-k + hx0) / 2, y, 0), wood, Enum.Material.WoodPlanks)
		end
		if hx1 < k then
			W.solid(castle, V(k - hx1, 2, k * 2), CF((k + hx1) / 2, y, 0), wood, Enum.Material.WoodPlanks)
		end
		if hz0 > -k then
			W.solid(castle, V(hx1 - hx0, 2, hz0 + k), CF((hx0 + hx1) / 2, y, (-k + hz0) / 2), wood, Enum.Material.WoodPlanks)
		end
		if hz1 < k then
			W.solid(castle, V(hx1 - hx0, 2, k - hz1), CF((hx0 + hx1) / 2, y, (k + hz1) / 2), wood, Enum.Material.WoodPlanks)
		end
	end
	local y1 = cy + FH + 1
	local y2 = cy + FH * 2 + 3
	keepWalls(cy, FH, true)
	floorWithHole(y1, -keepHalf, -keepHalf + 10, -14, 22)
	keepWalls(cy + FH + 2, FH, false)
	floorWithHole(y2, keepHalf - 10, keepHalf, -18, 20)
	keepWalls(cy + FH * 2 + 4, FH + 6, false)
	-- keep roof (stepped) and corner turrets
	for i = 0, 7 do
		local sz = keepHalf * 2 + 4 - i * 6
		W.solid(castle, V(sz, 2.5, sz), CF(0, cy + FH * 3 + 10 + i * 2.5, 0), Palette.shade(roofC, 1 - i * 0.04))
	end
	for _, c in { V(-keepHalf, 0, -keepHalf), V(keepHalf, 0, -keepHalf), V(keepHalf, 0, keepHalf), V(-keepHalf, 0, keepHalf) } do
		W.tower(castle, V(c.X, cy, c.Z), 5, FH * 3 + 14, wallC, roofC)
	end
	-- stairs: ground -> floor 1 along the west wall (+Z), floor 1 -> crown room along the east wall (-Z)
	for i = 0, 12 do
		W.solid(castle, V(8, 2, 3), CF(-keepHalf + 5, cy + 1 + i * 2, -12 + i * 2.6), rgb(120, 110, 100), kmat)
	end
	for i = 0, 12 do
		W.solid(castle, V(8, 2, 3), CF(keepHalf - 5, y1 + 2 + i * 2, 16 - i * 2.6), rgb(120, 110, 100), kmat)
	end

	-- great hall / ritual chamber details (floor 0)
	local hall = cy
	for i = -2, 2 do
		for _, x in { -16, 16 } do
			W.solid(castle, V(3, FH, 3), CF(x, hall + FH / 2, i * 10), rgb(190, 186, 176), Enum.Material.Marble)
		end
	end
	W.solid(castle, V(10, 0.3, 40), CF(0, hall + 0.2, 4), rgb(150, 20, 30), Enum.Material.Fabric)
	refs.ritualCenter = V(0, hall + 0.4, -4)
	W.circle(castle, refs.ritualCenter, 9, rgb(170, 120, 255), false)
	-- throne-ish balcony for king at north
	W.solid(castle, V(16, 4, 8), CF(0, hall + 2, -20), rgb(120, 110, 100), Enum.Material.Marble)
	W.solid(castle, V(4, 7, 3), CF(0, hall + 7.5, -22), rgb(236, 190, 70), Enum.Material.Metal)
	refs.hallThrone = CF(0, hall + 4, -21) * ANG(0, 0, 0)
	-- appraisal crystal
	W.solid(castle, V(2.4, 3.6, 2.4), CF(7, hall + 1.8, -8), rgb(110, 100, 120), Enum.Material.Marble)
	local crystal = W.solid(castle, V(2, 2.6, 2), CF(7, hall + 5, -8) * ANG(0.2, 0.7, 0.2), rgb(170, 220, 255), Enum.Material.Glass, { Transparency = 0.2 })
	Kit.pointLight(crystal, rgb(170, 220, 255), 16, 1.4)
	refs.crystal = crystal
	-- trapdoor to the Abyss: a real hole with two hinged iron leaves and a deep shaft
	Capital.trapShaft(castle, V(Capital.SHAFT.X, hall, Capital.SHAFT.Z), refs, stone)
	for i = 1, 6 do
		W.torch(castle, CF(-keepHalf + 1.2, hall + 8, -22 + i * 7))
		W.torch(castle, CF(keepHalf - 1.2, hall + 8, -22 + i * 7))
	end
	refs.mageSpots = {}
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		table.insert(refs.mageSpots, CFrame.lookAt(refs.ritualCenter + V(math.cos(a) * 12, 3, math.sin(a) * 12), refs.ritualCenter + V(0, 3, 0)))
	end
	refs.nobleSpots = {}
	for i = 1, 6 do
		local x = if i <= 3 then -20 else 20
		table.insert(refs.nobleSpots, CFrame.lookAt(V(x, hall + 3, -14 + (i % 3) * 8), refs.ritualCenter + V(0, 3, 0)))
	end
	refs.guardSpots = { CF(-5, hall + 3, 22) * ANG(0, math.pi, 0), CF(5, hall + 3, 22) * ANG(0, math.pi, 0), CF(-10, hall + 3, -18), CF(10, hall + 3, -18) }
	refs.archmageSpot = CFrame.lookAt(V(-6, hall + 7, -19), refs.ritualCenter + V(0, 3, 0))
	refs.kingSpot = CFrame.lookAt(V(0, hall + 7, -19), refs.ritualCenter + V(0, 3, 0))

	-- floor 1: halls (castle assault)
	local f1 = cy + FH + 2
	for i = -1, 1 do
		W.solid(castle, V(24, 7, 2), CF(1, f1 + 3.5, i * 16), rgb(150, 146, 138), kmat)
		W.solid(castle, V(4, 0.5, 5), CF(1, f1 + 7.2, i * 16), rgb(236, 190, 70), Enum.Material.Metal)
	end
	for i = 1, 6 do
		W.torch(castle, CF(keepHalf - 1.2, f1 + 8, -22 + i * 7))
		table.insert(refs.castleSpawns, CF(rng:float(-10, 20), f1 + 3, rng:float(-20, 20)))
	end
	refs.floor1 = V(0, f1 + 3, 0)
	-- floor 2: crown room
	local f2 = cy + FH * 2 + 4
	W.solid(castle, V(20, 3, 14), CF(0, f2 + 1.5, -18), rgb(130, 120, 110), Enum.Material.Marble)
	W.solid(castle, V(14, 1, 10), CF(0, f2 + 3.5, -18), rgb(160, 20, 30), Enum.Material.Fabric)
	local throne = W.solid(castle, V(6, 11, 3), CF(0, f2 + 8.5, -22), Palette.metal.gold, Enum.Material.Metal)
	W.solid(castle, V(5, 2, 4), CF(0, f2 + 5, -20), Palette.metal.gold, Enum.Material.Metal)
	W.deco(castle, V(1.4, 1.4, 0.4), CF(0, f2 + 12, -20.4), rgb(220, 30, 60), Enum.Material.Neon)
	refs.throne = CF(0, f2 + 7, -19.5)
	refs.crownRoom = V(0, f2 + 3, 0)
	W.solid(castle, V(10, 0.3, 40), CF(0, f2 + 0.2, 4), rgb(150, 20, 30), Enum.Material.Fabric)
	for i = -2, 2 do
		for _, x in { -14, 14 } do
			W.solid(castle, V(3, FH + 6, 3), CF(x, f2 + (FH + 6) / 2, i * 9), rgb(200, 196, 186), Enum.Material.Marble)
			W.banner(castle, CF(x * 1.6, f2 + 6, i * 9) * ANG(0, if x < 0 then math.pi / 2 else -math.pi / 2, 0), rgb(40, 60, 140), Palette.metal.gold)
		end
	end
	for i = 1, 4 do
		W.torch(castle, CF(-keepHalf + 1.2, f2 + 9, -18 + i * 9))
		W.torch(castle, CF(keepHalf - 1.2, f2 + 9, -18 + i * 9))
	end
	refs.castleGate = V(0, cy + 2, 58)
	refs.keepDoor = V(0, cy + 2, keepHalf + 4)
	-- courtyard dressing
	for i = 1, 6 do
		W.banner(castle, CF(rng:float(-40, 40), cy, rng:float(32, 44)), rgb(40, 60, 140), Palette.metal.gold)
		W.barrel(castle, CF(rng:float(-40, 40), cy, rng:float(-44, -32)))
		W.crate(castle, CF(rng:float(-40, 40), cy, rng:float(-44, -32)))
	end

	-- ------------------------------------------------------------ arena (Proving Pit) + prison
	local arenaA = math.rad(225)
	local ar = 145
	local ac = V(math.sin(arenaA) * ar, TIERS[2].y, math.cos(arenaA) * ar)
	refs.arenaCenter = ac
	local arena = Kit.model("Arena", city)
	local sand = rgb(214, 190, 140)
	W.solid(arena, V(50, 1, 50), CF(ac + V(0, 0.5, 0)), sand, Enum.Material.Sand)
	-- octagonal walls + stands
	for tier = 0, 3 do
		local R = 26 + tier * 5
		local h = 10 + tier * 3.5
		for i = 1, 8 do
			local a1 = (i - 0.5) / 8 * math.pi * 2
			local a2 = (i + 0.5) / 8 * math.pi * 2
			local p1 = ac + V(math.cos(a1) * R, 0, math.sin(a1) * R)
			local p2 = ac + V(math.cos(a2) * R, 0, math.sin(a2) * R)
			local gate = tier == 0 and (i == 2 or i == 6)
			if not gate then
				local mid = (p1 + p2) / 2
				W.solid(arena, V(5, h, (p2 - p1).Magnitude + 2), CFrame.lookAt(mid + V(0, h / 2, 0), p2 + V(0, h / 2, 0)), Palette.shade(stone, 1 - tier * 0.05), Enum.Material.Cobblestone)
			else
				local mid = (p1 + p2) / 2
				W.solid(arena, V(5, 4, (p2 - p1).Magnitude + 2), CFrame.lookAt(mid + V(0, h - 2, 0), p2 + V(0, h - 2, 0)), stone, Enum.Material.Cobblestone)
				local bars = Kit.model("Gate" .. i, arena)
				for b = -3, 3 do
					W.solid(bars, V(0.5, h - 4, 0.5), CFrame.lookAt(mid, p2) * CF(0, (h - 4) / 2, b * 2), Palette.metal.dark, Enum.Material.Metal)
				end
				refs["arenaGate" .. i] = mid + V(0, 3, 0)
				refs["arenaGateModel" .. i] = bars
			end
		end
	end
	-- royal box
	local boxP = ac + V(0, 0, -37)
	W.solid(arena, V(16, 18, 8), CF(boxP + V(0, 9, 0)), rgb(140, 130, 120), Enum.Material.Marble)
	W.solid(arena, V(16, 1, 8), CF(boxP + V(0, 18.5, 3)), rgb(150, 20, 30), Enum.Material.Fabric)
	W.banner(arena, CF(boxP + V(-7, 18, 4)), rgb(40, 60, 140), Palette.metal.gold)
	W.banner(arena, CF(boxP + V(7, 18, 4)), rgb(40, 60, 140), Palette.metal.gold)
	refs.royalBox = boxP + V(0, 21, 2)
	for i = 1, 8 do
		W.torch(arena, CF(ac + V(math.cos(i / 8 * math.pi * 2) * 25, 7, math.sin(i / 8 * math.pi * 2) * 25)))
	end
	refs.arenaSpectators = {}
	for i = 1, 22 do
		local a = rng:angle()
		local R = rng:pick({ 31, 36, 41 })
		table.insert(refs.arenaSpectators, CFrame.lookAt(ac + V(math.cos(a) * R, 10 + (R - 26) * 0.7 + 3, math.sin(a) * R), ac + V(0, 10, 0)))
	end
	-- prison block next to the arena
	local pc = ac + V(-44, 0, 20)
	refs.prisonCenter = pc
	local prison = Kit.model("Prison", city)
	W.solid(prison, V(34, 1, 22), CF(pc + V(0, 0.5, 0)), rgb(90, 88, 86), Enum.Material.Slate)
	W.solid(prison, V(34, 14, 2), CF(pc + V(0, 7, -11)), rgb(110, 106, 100), Enum.Material.Cobblestone)
	W.solid(prison, V(34, 14, 2), CF(pc + V(0, 7, 11)), rgb(110, 106, 100), Enum.Material.Cobblestone)
	W.solid(prison, V(2, 14, 22), CF(pc + V(-17, 7, 0)), rgb(110, 106, 100), Enum.Material.Cobblestone)
	W.solid(prison, V(2, 14, 22), CF(pc + V(17, 7, 0)), rgb(110, 106, 100), Enum.Material.Cobblestone)
	W.solid(prison, V(34, 1, 22), CF(pc + V(0, 14.5, 0)), rgb(90, 88, 86), Enum.Material.Slate)
	for c = 0, 2 do
		local x = -11 + c * 11
		W.solid(prison, V(1, 14, 10), CF(pc + V(x - 5.5, 7, -6)), rgb(110, 106, 100), Enum.Material.Cobblestone)
		for b = -2, 2 do
			W.solid(prison, V(0.4, 14, 0.4), CF(pc + V(x + b * 2, 7, -1)), Palette.metal.dark, Enum.Material.Metal)
		end
		W.deco(prison, V(4, 1, 6), CF(pc + V(x, 1.5, -8)), rgb(200, 180, 110), Enum.Material.Fabric)
		W.deco(prison, V(2, 2, 0.3), CF(pc + V(x, 10, -10.9)), rgb(255, 240, 200), Enum.Material.Neon, { Transparency = 0.2 })
	end
	W.solid(prison, V(1, 14, 10), CF(pc + V(10.5, 7, -6)), rgb(110, 106, 100), Enum.Material.Cobblestone)
	refs.cellCF = CFrame.lookAt(pc + V(0, 3, -7), pc + V(0, 3, 4))
	refs.neighborCell = CFrame.lookAt(pc + V(11, 3, -7), pc + V(0, 3, 4))
	refs.cellDoor = pc + V(0, 3, -1)
	W.torch(prison, CF(pc + V(-8, 6, 9)))
	W.torch(prison, CF(pc + V(8, 6, 9)))

	-- ------------------------------------------------------------ streets
	local function ringStreet(r: number, y: number, width: number, color: Color3)
		local segs = math.floor(2 * math.pi * r / 40)
		for i = 0, segs - 1 do
			local a0, a1 = i / segs * math.pi * 2, (i + 1) / segs * math.pi * 2
			local p0 = V(math.sin(a0) * r, y + 0.25, math.cos(a0) * r)
			local p1 = V(math.sin(a1) * r, y + 0.25, math.cos(a1) * r)
			W.deco(map, V(width, 0.5, (p1 - p0).Magnitude + 1.4), CFrame.lookAt((p0 + p1) / 2, p1), color, Enum.Material.Cobblestone)
		end
	end
	ringStreet(150, TIERS[2].y, 10, cobble)
	ringStreet(300, TIERS[3].y, 12, cobble)
	ringStreet(520, TIERS[4].y, 13, Palette.shade(cobble, 0.95))

	-- ------------------------------------------------------------ houses
	local function roadClear(p: Vector3, margin: number)
		for _, a in ROADS do
			local dx, dz = math.sin(a), math.cos(a)
			local along = p.X * dx + p.Z * dz
			local across = math.abs(p.X * dz - p.Z * dx)
			if along > -margin and across < ROAD_W + margin then
				return false
			end
		end
		return true
	end
	local function farFrom(p: Vector3, list, d: number)
		for _, q in list do
			if Util.flatDist(p, q) < d then
				return false
			end
		end
		return true
	end
	local blocked = { ac, pc, V(0, 0, 0) }
	local squares = {
		{ pos = V(math.sin(0.35) * 590, TIERS[4].y, math.cos(0.35) * 590), r = 34 },
		{ pos = V(math.sin(2.2) * 590, TIERS[4].y, math.cos(2.2) * 590), r = 30 },
		{ pos = V(math.sin(4.4) * 590, TIERS[4].y, math.cos(4.4) * 590), r = 30 },
		{ pos = V(math.sin(-0.4) * 340, TIERS[3].y, math.cos(-0.4) * 340), r = 28 },
		{ pos = V(math.sin(2.6) * 340, TIERS[3].y, math.cos(2.6) * 340), r = 26 },
	}
	for _, sq in squares do
		table.insert(blocked, sq.pos)
	end
	local function clearOfSquares(p: Vector3, pad: number)
		for _, sq in squares do
			if Util.flatDist(p, sq.pos) < sq.r + pad then
				return false
			end
		end
		return true
	end
	-- Dense districts of houses along a ring street: `side` = +1 outside the
	-- street, -1 inside. Houses stand shoulder to shoulder inside a district;
	-- gardens and yards fill the gaps between districts.
	local housePts = {}
	local function district(streetR: number, side: number, tierY: number, style: string, bucket, spawnBucket, maxCount: number, nDistricts: number)
		local perD = math.ceil(maxCount / nDistricts)
		for k = 0, nDistricts - 1 do
			local a = (k + rng:float(0.05, 0.35)) / nDistricts * math.pi * 2
			local placed, tries = 0, 0
			while placed < perD and tries < perD * 4 do
				tries += 1
				local w = if style == "stone" then rng:int(18, 22) elseif style == "cottage" then rng:int(12, 15) else rng:int(13, 17)
				local d = if style == "stone" then rng:int(14, 16) else rng:int(11, 13)
				local r = streetR + side * (7 + d / 2 + 1.5)
				local p = V(math.sin(a) * r, tierY, math.cos(a) * r)
				if roadClear(p, w * 0.5 + 4) and clearOfSquares(p, w * 0.6) and farFrom(p, blocked, 50) then
					local face = CFrame.lookAt(p, V(math.sin(a) * streetR, tierY, math.cos(a) * streetR))
					local cf = CF(p) * (face - face.Position)
					local model, door
					if style == "stone" then
						model, door = B.stoneHouse(city, cf, { rng = rng, w = w, d = d, floors = rng:int(2, 3) })
					else
						local floors = if style == "cottage" then (if rng:chance(0.65) then 1 else 2) else (if rng:chance(0.6) then 2 else 3)
						model, door = B.halfTimber(city, cf, { rng = rng, w = w, d = d, floors = floors, sign = rng:chance(0.12) })
					end
					table.insert(bucket, { model = model, door = door, cf = cf })
					table.insert(refs.houses, model)
					table.insert(spawnBucket, door)
					table.insert(housePts, p)
					placed += 1
					if rng:chance(0.2) then
						W.barrel(props, cf * CF(w / 2 + 1.2, 0, -d / 2 - 1))
					end
					a += (w + rng:float(1.5, 4)) / r
					W.yield(counter)
				else
					a += 8 / r
				end
			end
		end
	end
	district(520, 1, TIERS[4].y, "cottage", refs.lowerHouses, refs.spawnsLower, 50, 7)
	district(520, -1, TIERS[4].y, "cottage", refs.lowerHouses, refs.spawnsLower, 34, 5)
	district(300, 1, TIERS[3].y, "timber", refs.middleHouses, refs.spawnsMiddle, 38, 5)
	district(300, -1, TIERS[3].y, "timber", refs.middleHouses, refs.spawnsMiddle, 18, 3)
	district(150, 1, TIERS[2].y, "stone", refs.upperHouses, refs.spawnsUpper, 16, 4)

	-- gardens between the districts: trees, vegetable plots, laundry, hay
	for i = 1, 150 do
		local a = rng:angle()
		local ring = rng:pick({ { 430, 640, TIERS[4].y }, { 230, 390, TIERS[3].y } })
		local r = rng:float(ring[1], ring[2])
		local p = V(math.sin(a) * r, ring[3], math.cos(a) * r)
		if roadClear(p, 6) and clearOfSquares(p, 6) and farFrom(p, housePts, 16) and farFrom(p, blocked, 40) and math.abs(r - 520) > 12 and math.abs(r - 300) > 12 and math.abs(r - 406) > 14 then
			local roll = rng:float()
			if roll < 0.3 then
				N.oak(props, p, rng, rng:float(0.8, 1.1), pal)
			elseif roll < 0.45 then
				N.field(props, CF(p) * ANG(0, a, 0), rng:int(12, 18), rng:int(8, 12), rng:pick({ "green", "green", "wheat" }), rng)
			elseif roll < 0.55 then
				B.laundry(props, p, p + V(rng:float(-8, 8), 0, rng:float(-8, 8)))
			elseif roll < 0.65 then
				B.haystack(props, p, 0.7)
			elseif roll < 0.75 then
				B.woodpile(props, CF(p) * ANG(0, rng:angle(), 0))
			else
				N.bush(props, p, rng, pal)
			end
			table.insert(housePts, p)
		end
	end

	-- squares: markets, wells, fountains, a church
	for i, sq in squares do
		local p = sq.pos
		if i == 1 or i == 4 then
			B.fountain(props, p)
		else
			W.well(props, p)
		end
		for k = 1, 4 do
			local off = CFrame.Angles(0, k * 1.57 + 0.4, 0) * V(0, 0, sq.r * 0.55)
			B.stall(props, CF(p + off) * ANG(0, k * 1.57 + 0.4, 0), rng:pick({ rgb(170, 40, 40), rgb(40, 90, 160), rgb(200, 150, 40), rgb(60, 120, 60) }), rng)
		end
		for k = 1, 3 do
			B.cart(props, CF(p + V(rng:float(-sq.r, sq.r) * 0.7, 0, rng:float(-sq.r, sq.r) * 0.7)) * ANG(0, rng:angle(), 0))
		end
	end
	refs.lowerSquare = squares[1].pos
	do
		local a = 1.2
		local p = V(math.sin(a) * 350, TIERS[3].y, math.cos(a) * 350)
		local face = CFrame.lookAt(p, V(math.sin(a) * 300, TIERS[3].y, math.cos(a) * 300))
		B.church(city, CF(p) * (face - face.Position), { rng = rng })
	end
	B.statue(props, V(0, TIERS[2].y, 108), math.pi)

	-- street lanterns along the radial roads
	for _, a in ROADS do
		for r = 90, 640, 34 do
			for _, side in { -1, 1 } do
				local dx, dz = math.sin(a), math.cos(a)
				local x = dx * r + dz * (ROAD_W + 2.5) * side
				local z = dz * r - dx * (ROAD_W + 2.5) * side
				local y = quant(Capital.heightAt(x, z, seed), x, z)
				local nearEdge = false
				for _, t in TIERS do
					if math.abs(r - t.r) < RAMP + 4 then
						nearEdge = true
					end
				end
				if not nearEdge then
					W.lantern(props, V(x, y, z))
				end
			end
		end
	end

	-- ------------------------------------------------------------ walls
	-- inner wall between the middle and the lower village (with four gates)
	local inner = B.greatWall(city, V(0, TIERS[4].y, 0), TIERS[3].r + 6, 34, 10, { gates = ROADS, gateWidth = 22, gateHeight = 22, segment = 36, cannons = false, name = "InnerWall", color = rgb(176, 170, 158) })
	-- THE GREAT WALL
	local great = B.greatWall(city, V(0, Capital.OUTER_Y, 0), Capital.WALL_R, Capital.WALL_H, Capital.WALL_T, { gates = ROADS, gateWidth = 28, gateHeight = 56, segment = 52, name = "GreatWall", banner = rgb(40, 60, 140), emblem = Palette.metal.gold })
	refs.greatGates = great.gates
	refs.wallTop = Capital.OUTER_Y + Capital.WALL_H
	-- stairs up the inside of the wall next to the south gate
	do
		local c = CFrame.lookAt(V(40, TIERS[4].y, Capital.WALL_R - 24), V(40, TIERS[4].y, Capital.WALL_R - 24) + V(1, 0, 0))
		for i = 0, 40 do
			W.solid(city, V(6, 3.4, 5), c * CF(0, 1.7 + i * 3.1, -i * 2.8), Palette.shade(stone, 1 - (i % 2) * 0.05), Enum.Material.Slate)
		end
	end

	-- ------------------------------------------------------------ farmland outside the wall
	local fieldsFolder = W.sub("Fields")
	local farmSpots = {}
	for i = 1, 70 do
		local a = rng:angle()
		local r = rng:float(740, 1120)
		local x, z = math.sin(a) * r, math.cos(a) * r
		local p = V(x, 0, z)
		if roadClear(p, 26) and riverDist(x, z) > 50 and farFrom(p, farmSpots, 70) then
			local y = quant(Capital.heightAt(x, z, seed), x, z)
			local cf = CF(x, y, z) * ANG(0, a + rng:float(-0.2, 0.2), 0)
			local w, d = rng:int(36, 64), rng:int(30, 50)
			N.field(fieldsFolder, cf, w, d, rng:pick({ "wheat", "wheat", "green", "flax" }), rng)
			table.insert(farmSpots, p)
			-- fence along one side
			local a0 = (cf * CF(-w / 2, 0, d / 2 + 2)).Position
			local a1 = (cf * CF(w / 2, 0, d / 2 + 2)).Position
			W.fence(fieldsFolder, a0, a1)
			if rng:chance(0.4) then
				B.haystack(fieldsFolder, (cf * CF(w / 2 + 6, 0, 0)).Position)
			end
		end
	end
	-- farmsteads, barns and windmills
	local farmsteads = 0
	for i = 1, 40 do
		if farmsteads >= 16 then
			break
		end
		local a = rng:angle()
		local r = rng:float(760, 1100)
		local x, z = math.sin(a) * r, math.cos(a) * r
		local p = V(x, 0, z)
		if roadClear(p, 24) and riverDist(x, z) > 40 and farFrom(p, farmSpots, 46) then
			local y = quant(Capital.heightAt(x, z, seed), x, z)
			local cf = CF(x, y, z) * ANG(0, rng:angle(), 0)
			if farmsteads % 4 == 0 then
				B.windmill(fieldsFolder, V(x, y, z), rng:angle())
			else
				B.halfTimber(fieldsFolder, cf, { rng = rng, floors = 1, w = rng:int(12, 15), d = 11 })
				B.longhouse(fieldsFolder, cf * CF(22, 0, 6) * ANG(0, 0.3, 0), { rng = rng, turf = rng:chance(0.5), shields = false, name = "Barn" })
				B.cart(fieldsFolder, cf * CF(-10, 0, -10) * ANG(0, 0.6, 0))
				B.woodpile(fieldsFolder, cf * CF(-9, 0, 5))
			end
			table.insert(farmSpots, p)
			farmsteads += 1
		end
	end
	refs.burstPoint = V(0, Capital.OUTER_Y, 900)
	refs.fieldsSpawn = CFrame.lookAt(V(0, Capital.OUTER_Y + 3, 900), V(0, Capital.OUTER_Y + 3, 0))

	-- the river (water + reeds) and bridges where the roads cross it
	local waterC = pal.water
	local segs = 40
	for i = 0, segs - 1 do
		local a0 = Util.lerp(RIVER_A0, RIVER_A1, i / segs)
		local a1 = Util.lerp(RIVER_A0, RIVER_A1, (i + 1) / segs)
		local r0 = RIVER_R + math.sin(a0 * 5) * 40
		local r1 = RIVER_R + math.sin(a1 * 5) * 40
		local p0 = V(math.sin(a0) * r0, 2.2, math.cos(a0) * r0)
		local p1 = V(math.sin(a1) * r1, 2.2, math.cos(a1) * r1)
		W.water(map, CFrame.lookAt((p0 + p1) / 2, p1), V(34, 1, (p1 - p0).Magnitude + 6), waterC)
		if i % 3 == 0 then
			N.reeds(props, p0 + (p0 - V(0, 2.2, 0)).Unit * 17 + V(0, 1, 0), rng)
		end
	end
	for _, a in ROADS do
		if a >= RIVER_A0 and a <= RIVER_A1 then
			local r = RIVER_R + math.sin(a * 5) * 40
			local dir = V(math.sin(a), 0, math.cos(a))
			B.bridge(city, dir * (r - 30) + V(0, Capital.OUTER_Y, 0), dir * (r + 30) + V(0, Capital.OUTER_Y, 0), ROAD_W * 2 + 2)
		end
	end
	-- a lake in the east
	local lake = V(1060, 1.6, -260)
	W.water(map, CF(lake), V(180, 1, 140), waterC)
	B.dock(props, CFrame.lookAt(lake + V(-80, 0.6, 0), lake + V(0, 0.6, 0)), 30)

	-- ------------------------------------------------------------ forests
	local forestCount = 0
	for i = 1, 900 do
		local a = rng:angle()
		local r = rng:float(740, MOUNTAIN_R + 40)
		local x, z = math.sin(a) * r, math.cos(a) * r
		local p = V(x, 0, z)
		local density = Util.noise(x / 180, z / 180, seed + 5) + (if r > 1150 then 0.45 else -0.15)
		if density > 0.05 and roadClear(p, 8) and riverDist(x, z) > 36 and farFrom(p, farmSpots, 40) and not (z < 0 and math.abs(x) < 40) then
			local y = quant(Capital.heightAt(x, z, seed), x, z)
			local roll = rng:float()
			if roll < 0.45 then
				N.oak(props, V(x, y, z), rng, nil, pal)
			elseif roll < 0.7 then
				N.pine(props, V(x, y, z), rng, nil, pal)
			elseif roll < 0.85 then
				N.birch(props, V(x, y, z), rng, nil, pal)
			else
				N.bush(props, V(x, y, z), rng, pal)
			end
			forestCount += 1
		elseif rng:chance(0.3) and r < 1150 then
			local y = quant(Capital.heightAt(x, z, seed), x, z)
			local roll = rng:float()
			if roll < 0.3 then
				N.rocks(props, V(x, y, z), rng:float(2, 6), pal.rock, rng, true)
			elseif roll < 0.7 then
				W.flowers(props, V(x, y, z), rng, pal)
			else
				N.bush(props, V(x, y, z), rng, pal)
			end
		end
		W.yield(counter)
	end
	-- the old grove: giant trees in the north-west
	refs.giantGrove = V(-820, Capital.OUTER_Y, -760)
	for i = 1, 14 do
		local p = refs.giantGrove + V(rng:float(-240, 240), 0, rng:float(-200, 200))
		if Util.flatDist(p, V(0, 0, 0)) > 760 and not (p.Z < 0 and math.abs(p.X) < 60) then
			local y = quant(Capital.heightAt(p.X, p.Z, seed), p.X, p.Z)
			N.giant(props, V(p.X, y, p.Z), rng, nil, pal)
		end
	end
	-- cubic mountains around the edge
	for i = 1, 44 do
		local a = i / 44 * math.pi * 2 + rng:float(-0.05, 0.05)
		local nearPass = math.abs(((a - math.pi + math.pi) % (2 * math.pi)) - math.pi) < 0.08
		if not nearPass then
			local r = rng:float(MOUNTAIN_R + 120, MOUNTAIN_R + 280)
			local x, z = math.sin(a) * r, math.cos(a) * r
			local y = quant(Capital.heightAt(x, z, seed), x, z)
			N.mountain(map, V(x, y - 10, z), rng:float(90, 150), rng:float(220, 420), rng, pal, 250)
		end
	end

	-- ------------------------------------------------------------ gates & markers
	refs.middleGate = V(0, TIERS[3].y + 2, TIERS[3].r + 4)
	refs.upperGate = V(0, TIERS[2].y + 2, TIERS[2].r + 4)
	refs.lowerVillageEdge = V(0, TIERS[4].y + 2, Capital.WALL_R - 30)
	refs.southGate = V(0, Capital.OUTER_Y + 2, Capital.WALL_R + 20)
	for _, g in { { r = TIERS[2].r, y = TIERS[2].y } } do
		for _, a in ROADS do
			local p = V(math.sin(a) * (g.r + RAMP + 4), g.y, math.cos(a) * (g.r + RAMP + 4))
			local fwd = V(math.sin(a), 0, math.cos(a))
			local side = fwd:Cross(V(0, 1, 0))
			local ybase = quant(Capital.heightAt(p.X, p.Z, seed), p.X, p.Z)
			for _, s in { -1, 1 } do
				W.tower(city, V(p.X, ybase, p.Z) + side * s * (ROAD_W + 5), 4, 18, stone, rgb(40, 60, 140))
			end
		end
	end
	-- north pass to the next land
	refs.northPass = V(0, quant(Capital.heightAt(0, -1560, seed), 0, -1560) + 3, -1560)
	refs.center = V(0, cy, 0)
	refs.titanStand = V(-220, 0, -220)
	return refs
end

return Capital
