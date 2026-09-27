--!nonstrict
-- LAND 1: THE WALLED KINGDOM (v4). A capital about as big as the whole v3 map,
-- stepped up a hill in four tiers, standing on real terrain:
--   castle plateau (y100, r<190): curtain wall, towers, a three-storey keep with
--     the great hall (summoning circle, appraisal crystal, the trapdoor shaft),
--     halls and the crown room; barracks, stables, chapel, training yard
--   upper city (y72): stone mansions, the noble plaza, a cathedral, the Proving
--     Pit arena and the prison
--   middle city (y44): timber houses, the great market, church, tavern, smithy
--   the inner wall, then the lower city (y16): cottages, gardens, a small market
--   THE GREAT WALL (r1400, 150 studs) with four gatehouses and a moat
-- Outside: the countryside ring (CapitalLand) out to ~4800 studs.
-- Every house can be entered (Interiors builds them as you approach).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Kit = require(Shared.Kit)
local Palette = require(Shared.Palette)
local Util = require(Shared.Util)
local RNG = require(Shared.RNG)
local S = require(script.Parent.S)
local Land = require(script.Parent.CapitalLand)

local Capital = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB
local M = Enum.Material
local T = Land.T

local TIERS = {
	{ r = 190, y = 100 },
	{ r = 480, y = 72 },
	{ r = 900, y = 44 },
	{ r = 1388, y = 16 },
}
Capital.TIERS = TIERS
Capital.WALL_R = 1400
Capital.WALL_H = 150
Capital.WALL_T = 26
Capital.OUTER_Y = Land.OUTER_Y
Capital.INNER_WALL_R = 906
local RAMP = 44
local ROAD_W = 11 -- half width of the four radial roads
local ROADS = { 0, math.pi / 2, math.pi, math.pi * 1.5 } -- angle 0 = +Z (south)
-- ring streets (half widths) on each tier
local STREETS = {
	{ r = 330, y = 72, w = 8 },
	{ r = 690, y = 44, w = 8 },
	{ r = 1030, y = 16, w = 7 },
	{ r = 1260, y = 16, w = 7 },
}
-- the trapdoor shaft (a 12x12 column, aligned to the terrain voxels)
Capital.SHAFT = V(-14, 0, 14)

local function polar(a: number, r: number, y: number?): Vector3
	return V(math.sin(a) * r, y or 0, math.cos(a) * r)
end

-- squares: {a, r, R, kind}
local SQUARES = {
	{ a = 0.62, r = 330, R = 34, kind = "noble" },
	{ a = 2.05, r = 330, R = 30, kind = "cathedral" },
	{ a = 0.42, r = 690, R = 72, kind = "market" },
	{ a = 2.3, r = 690, R = 34, kind = "church" },
	{ a = 3.9, r = 690, R = 30, kind = "tavern" },
	{ a = 5.2, r = 690, R = 30, kind = "fountain" },
	{ a = 3.42, r = 1145, R = 46, kind = "lowmarket" },
	{ a = 0.9, r = 1030, R = 26, kind = "well" },
	{ a = 2.2, r = 1260, R = 26, kind = "well" },
	{ a = 4.6, r = 1260, R = 26, kind = "well" },
	{ a = 5.6, r = 1030, R = 26, kind = "well" },
	-- the gate plaza just inside the south gate (the south road runs through it)
	{ a = 0, r = 1318, R = 42, kind = "gate" },
}
for _, sq in SQUARES do
	sq.pos = polar(sq.a, sq.r)
end
local ARENA_A, ARENA_R = math.rad(225), 330

local function tierHeight(r: number): number
	for _, t in TIERS do
		if r < t.r then
			return t.y
		end
	end
	return TIERS[#TIERS].y
end

-- (on a road, how far across it, which road)
local function onRoad(x: number, z: number): (boolean, number, number)
	for i, a in ROADS do
		local dx, dz = math.sin(a), math.cos(a)
		local along = x * dx + z * dz
		local across = math.abs(x * dz - z * dx)
		if along > 0 and across < ROAD_W then
			return true, across, i
		end
	end
	return false, 999, 0
end
Capital.onRoad = onRoad

-- inside the Great Wall: tier heights, ramps on the roads, streets and squares
local function cityHeight(x: number, z: number, r: number): (number, number)
	if r < TIERS[1].r then
		return TIERS[1].y, T.CASTLE
	end
	local road, _, ri = onRoad(x, z)
	if road then
		for i = 1, #TIERS - 1 do
			local t = TIERS[i]
			-- only the south road climbs all the way to the castle gate
			if math.abs(r - t.r) < RAMP and (i > 1 or ri == 1) then
				local k = (r - (t.r - RAMP)) / (RAMP * 2)
				return t.y + (TIERS[i + 1].y - t.y) * k, T.STREET
			end
		end
		return tierHeight(r), T.STREET
	end
	local y = tierHeight(r)
	for _, sq in SQUARES do
		local dx, dz = x - sq.pos.X, z - sq.pos.Z
		if dx * dx + dz * dz < sq.R * sq.R then
			return y, T.PLAZA
		end
	end
	for _, st in STREETS do
		if math.abs(r - st.r) < st.w and y == st.y then
			return y, T.STREET
		end
	end
	return y, T.GARDEN
end

-- the whole world's surface (terrain height + tag)
local function surface(x: number, z: number): (number, number)
	local r = math.sqrt(x * x + z * z)
	if r < Capital.WALL_R + 14 then
		if r > TIERS[#TIERS].r then
			return TIERS[#TIERS].y, T.GRASS
		end
		return cityHeight(x, z, r)
	end
	return Land.height(x, z, r)
end
Capital.surface = surface

function Capital.ground(x: number, z: number, _seed: number?): number
	return (surface(x, z))
end
function Capital.heightAt(x: number, z: number, _seed: number?): number
	return (surface(x, z))
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
	W.solid(m, V(12, depth, 3), CF(x, bottom + depth / 2, z - 4.5), wallC, M.Cobblestone)
	W.solid(m, V(12, depth, 3), CF(x, bottom + depth / 2, z + 4.5), wallC, M.Cobblestone)
	W.solid(m, V(3, depth, 6), CF(x - 4.5, bottom + depth / 2, z), wallC, M.Cobblestone)
	W.solid(m, V(3, depth, 6), CF(x + 4.5, bottom + depth / 2, z), wallC, M.Cobblestone)
	for _, e in { { V(7, 0.3, 0.5), V(0, 0, -3.25) }, { V(7, 0.3, 0.5), V(0, 0, 3.25) }, { V(0.5, 0.3, 7), V(-3.25, 0, 0) }, { V(0.5, 0.3, 7), V(3.25, 0, 0) } } do
		W.deco(m, e[1], CF(top + e[2] + V(0, 0.1, 0)), rgb(46, 44, 46), M.Metal)
	end
	W.solid(m, V(6, 2, 6), CF(x, bottom - 1, z), rgb(40, 36, 34), M.Slate)
	for i = 1, 6 do
		W.deco(m, V(0.4, 0.4, 1.6), CF(x + math.sin(i * 2.1) * 2, bottom + 0.2, z + math.cos(i * 1.3) * 2) * ANG(0, i, 0), rgb(220, 214, 196))
	end
	W.deco(m, V(1.2, 1.2, 1.2), CF(x + 1.4, bottom + 0.6, z - 1.2) * ANG(0.2, 0.5, 0), rgb(226, 220, 204))
	for y = bottom + 20, top.Y - 20, 34 do
		local t = W.torch(m, CF(x - 2.9, y, z) * ANG(0, 0, -0.25), rgb(255, 120, 60))
		t.Name = "ShaftTorch"
	end
	refs.trapLeaves = {}
	for _, s in { -1, 1 } do
		local hinge = CF(x + s * 3, top.Y - 0.2, z)
		local offset = CF(-s * 1.5, 0, 0)
		local leaf = W.solid(m, V(3, 0.4, 6), hinge * offset, rgb(52, 46, 42), M.DiamondPlate)
		leaf.Name = "TrapLeaf"
		table.insert(refs.trapLeaves, { part = leaf, hinge = hinge, offset = offset, dir = s })
	end
	refs.trapdoor = V(x, top.Y + 1, z)
	refs.shaftBottom = V(x, bottom + 1, z)
	return m
end

-- ------------------------------------------------------------------ the castle
local function buildCastle(city: Instance, refs, rng)
	local W, B = S.World, S.Build
	local castle = Kit.model("Castle", city)
	local cy = TIERS[1].y
	local wallC = rgb(172, 168, 160)
	local roofC = rgb(58, 68, 116)
	local kmat = M.Cobblestone
	local CW = 125 -- curtain wall half size
	-- curtain wall with towers, a gatehouse on the south side
	local corners = { V(-CW, cy, -CW), V(CW, cy, -CW), V(CW, cy, CW), V(-CW, cy, CW) }
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		if i == 3 then
			W.wall(castle, a, V(12, cy, CW), 26, 8, wallC)
			W.wall(castle, V(-12, cy, CW), b, 26, 8, wallC)
		else
			W.wall(castle, a, b, 26, 8, wallC)
		end
		W.tower(castle, a, 11, 46, wallC, roofC)
		W.tower(castle, (a + b) / 2 + (if i == 3 then V(40, 0, 0) else V(0, 0, 0)), 8, 38, wallC, roofC)
	end
	-- gatehouse
	for _, sx in { -1, 1 } do
		W.tower(castle, V(sx * 17, cy, CW), 7, 42, wallC, roofC)
	end
	W.solid(castle, V(22, 12, 10), CF(0, cy + 26 + 6, CW), wallC, kmat)
	for k = -4, 4 do
		W.deco(castle, V(0.6, 7, 0.6), CF(k * 2.4, cy + 22.5, CW - 3), Palette.metal.dark, M.Metal)
	end
	for _, sx in { -1, 1 } do
		W.banner(castle, CF(sx * 9, cy + 20, CW + 5.5), rgb(40, 60, 140), Palette.metal.gold)
	end
	refs.castleGate = V(0, cy + 2, CW + 8)
	-- stairs up to the wall walk (inside the north-west and south-east corners)
	for i = 0, 12 do
		W.solid(castle, V(6, 2, 3), CF(-CW + 8, cy + 1 + i * 2, -CW + 12 + i * 2.6), rgb(140, 134, 126), kmat)
		W.solid(castle, V(6, 2, 3), CF(CW - 8, cy + 1 + i * 2, CW - 12 - i * 2.6), rgb(140, 134, 126), kmat)
	end

	-- the keep: 88x88, three storeys of 30
	local K = 44
	local FH = 30
	local hall = cy
	local f1 = cy + FH + 1
	local f2 = cy + FH * 2 + 2
	local function keepWalls(y0: number, h: number, doorSouth: boolean)
		if doorSouth then
			local side = K - 7
			W.solid(castle, V(side, h, 3), CF(-(7 + side / 2), y0 + h / 2, K), wallC, kmat)
			W.solid(castle, V(side, h, 3), CF(7 + side / 2, y0 + h / 2, K), wallC, kmat)
			W.solid(castle, V(14, h - 17, 3), CF(0, y0 + 17 + (h - 17) / 2, K), wallC, kmat)
			W.deco(castle, V(16, 1.4, 3.4), CF(0, y0 + 17, K), Palette.shade(wallC, 1.1), M.Limestone)
		else
			W.solid(castle, V(K * 2, h, 3), CF(0, y0 + h / 2, K), wallC, kmat)
		end
		W.solid(castle, V(K * 2, h, 3), CF(0, y0 + h / 2, -K), wallC, kmat)
		W.solid(castle, V(3, h, K * 2), CF(K, y0 + h / 2, 0), wallC, kmat)
		W.solid(castle, V(3, h, K * 2), CF(-K, y0 + h / 2, 0), wallC, kmat)
		for i = -2, 2 do
			for _, sx in { -1, 1 } do
				W.deco(castle, V(0.4, 11, 3.2), CF(sx * (K + 1.55), y0 + h * 0.5, i * 16), rgb(150, 180, 240), M.Neon, { Transparency = 0.45 })
			end
			W.deco(castle, V(3.2, 11, 0.4), CF(i * 16, y0 + h * 0.5, -K - 1.55), rgb(150, 180, 240), M.Neon, { Transparency = 0.45 })
		end
	end
	local wood = rgb(110, 90, 70)
	-- floor with a stair hole: the hole is [hx0, hx1] x [hz0, hz1]
	local function floorWithHole(y: number, hx0: number, hx1: number, hz0: number, hz1: number)
		if hx0 > -K then
			W.solid(castle, V(hx0 + K, 2, K * 2), CF((-K + hx0) / 2, y, 0), wood, M.WoodPlanks)
		end
		if hx1 < K then
			W.solid(castle, V(K - hx1, 2, K * 2), CF((K + hx1) / 2, y, 0), wood, M.WoodPlanks)
		end
		if hz0 > -K then
			W.solid(castle, V(hx1 - hx0, 2, hz0 + K), CF((hx0 + hx1) / 2, y, (-K + hz0) / 2), wood, M.WoodPlanks)
		end
		if hz1 < K then
			W.solid(castle, V(hx1 - hx0, 2, K - hz1), CF((hx0 + hx1) / 2, y, (K + hz1) / 2), wood, M.WoodPlanks)
		end
	end
	keepWalls(cy, FH, true)
	floorWithHole(f1 - 1, -K, -K + 11, -20, 26)
	keepWalls(f1, FH, false)
	floorWithHole(f2 - 1, K - 11, K, -24, 22)
	keepWalls(f2, FH + 6, false)
	for i = 0, 8 do
		local sz = K * 2 + 6 - i * 7
		W.solid(castle, V(sz, 3, sz), CF(0, f2 + FH + 7.5 + i * 3, 0), Palette.shade(roofC, 1 - i * 0.04), M.Slate)
	end
	for _, c in { V(-K, 0, -K), V(K, 0, -K), V(K, 0, K), V(-K, 0, K) } do
		W.tower(castle, V(c.X, cy, c.Z), 7, FH * 3 + 22, wallC, roofC)
	end
	-- stairs: ground -> floor 1 along the west wall, floor 1 -> crown room along the east wall
	for i = 0, 14 do
		W.solid(castle, V(9, 2, 3), CF(-K + 6, cy + 1 + i * 2, -18 + i * 2.8), rgb(120, 110, 100), kmat)
	end
	for i = 0, 14 do
		W.solid(castle, V(9, 2, 3), CF(K - 6, f1 + 1 + i * 2, 20 - i * 2.8), rgb(120, 110, 100), kmat)
	end

	-- the great hall (ground floor): pillars, carpet, dais, summoning circle
	local marbleC = rgb(214, 208, 196)
	-- marble floor, leaving the trapdoor cell open
	local sx0, sx1 = Capital.SHAFT.X - 6, Capital.SHAFT.X + 6
	local sz0, sz1 = Capital.SHAFT.Z - 6, Capital.SHAFT.Z + 6
	local fy = hall + 0.1
	W.deco(castle, V(sx0 + K, 0.2, K * 2), CF((-K + sx0) / 2, fy, 0), marbleC, M.Marble)
	W.deco(castle, V(K - sx1, 0.2, K * 2), CF((K + sx1) / 2, fy, 0), marbleC, M.Marble)
	W.deco(castle, V(12, 0.2, sz0 + K), CF(Capital.SHAFT.X, fy, (-K + sz0) / 2), marbleC, M.Marble)
	W.deco(castle, V(12, 0.2, K - sz1), CF(Capital.SHAFT.X, fy, (K + sz1) / 2), marbleC, M.Marble)
	for i = -2, 2 do
		for _, x in { -26, 26 } do
			W.solid(castle, V(4, FH, 4), CF(x, hall + FH / 2, i * 14), rgb(196, 190, 180), M.Marble)
			W.banner(castle, CF(x + (if x < 0 then -2.2 else 2.2), hall + 8, i * 14 + 7) * ANG(0, if x < 0 then math.pi / 2 else -math.pi / 2, 0), rgb(40, 60, 140), Palette.metal.gold)
		end
	end
	W.deco(castle, V(12, 0.3, 50), CF(0, hall + 0.3, 16), rgb(150, 20, 30), M.Fabric)
	refs.ritualCenter = V(0, hall + 0.4, -6)
	W.circle(castle, refs.ritualCenter, 10, rgb(170, 120, 255), false)
	-- the royal dais
	W.solid(castle, V(26, 4, 10), CF(0, hall + 2, -37), rgb(150, 142, 132), M.Marble)
	W.solid(castle, V(12, 2, 3), CF(0, hall + 1, -31), rgb(150, 142, 132), M.Marble)
	W.solid(castle, V(5, 9, 3), CF(0, hall + 8.5, -40.5), Palette.metal.gold, M.Metal)
	refs.hallThrone = CF(0, hall + 4, -39)
	-- appraisal crystal on its pedestal
	W.solid(castle, V(2.6, 3.6, 2.6), CF(12, hall + 1.8, -14), rgb(110, 100, 120), M.Marble)
	local crystal = W.solid(castle, V(2, 2.6, 2), CF(12, hall + 5, -14) * ANG(0.2, 0.7, 0.2), rgb(170, 220, 255), M.Glass, { Transparency = 0.2 })
	Kit.pointLight(crystal, rgb(170, 220, 255), 16, 1.4)
	refs.crystal = crystal
	-- the trapdoor to the Abyss
	Capital.trapShaft(castle, V(Capital.SHAFT.X, hall, Capital.SHAFT.Z), refs, marbleC)
	for i = 1, 6 do
		W.torch(castle, CF(-K + 1.8, hall + 9, -30 + i * 9))
		W.torch(castle, CF(K - 1.8, hall + 9, -30 + i * 9))
	end
	refs.mageSpots = {}
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		table.insert(refs.mageSpots, CFrame.lookAt(refs.ritualCenter + V(math.cos(a) * 14, 2.6, math.sin(a) * 14), refs.ritualCenter + V(0, 2.6, 0)))
	end
	refs.nobleSpots = {}
	for i = 1, 6 do
		local x = if i <= 3 then -32 else 32
		table.insert(refs.nobleSpots, CFrame.lookAt(V(x, hall + 3, -20 + (i % 3) * 12), refs.ritualCenter + V(0, 2.6, 0)))
	end
	refs.guardSpots = {
		CF(-7, hall + 3, 38),
		CF(7, hall + 3, 38),
		CF(-15, hall + 3, -28) * ANG(0, math.pi, 0),
		CF(15, hall + 3, -28) * ANG(0, math.pi, 0),
	}
	refs.archmageSpot = CFrame.lookAt(V(-8, hall + 7, -37), refs.ritualCenter + V(0, 3, 0))
	refs.kingSpot = CFrame.lookAt(V(0, hall + 7, -37), refs.ritualCenter + V(0, 3, 0))
	refs.leashR = 18
	refs.keepSpawns = {}
	for _ = 1, 8 do
		table.insert(refs.keepSpawns, V(rng:float(-18, 18), hall + 3, rng:float(-20, 30)))
	end

	-- floor 1: the long halls (feasting tables, partitions)
	for i = -1, 1 do
		W.solid(castle, V(30, 9, 2), CF(4, f1 + 4.5, i * 18), rgb(150, 146, 138), kmat)
		W.solid(castle, V(5, 0.6, 6), CF(4, f1 + 9.3, i * 18), Palette.metal.gold, M.Metal)
	end
	for _, z in { -27, 9 } do
		W.solid(castle, V(24, 1, 4), CF(4, f1 + 3, z), rgb(120, 84, 54), M.WoodPlanks)
		for k = -2, 2 do
			W.solid(castle, V(1.4, 2, 1.4), CF(4 + k * 5, f1 + 1.8, z - 3), rgb(100, 70, 44), M.WoodPlanks)
			W.solid(castle, V(1.4, 2, 1.4), CF(4 + k * 5, f1 + 1.8, z + 3), rgb(100, 70, 44), M.WoodPlanks)
		end
	end
	refs.castleSpawns = {}
	for i = 1, 8 do
		W.torch(castle, CF(K - 1.8, f1 + 9, -30 + i * 7))
		table.insert(refs.castleSpawns, CF(rng:float(-14, 24), f1 + 3, rng:float(-28, 28)))
	end
	refs.floor1 = V(0, f1 + 3, 0)
	-- floor 2: the crown room
	W.solid(castle, V(24, 3, 14), CF(0, f2 + 1.5, -34), rgb(130, 120, 110), M.Marble)
	W.solid(castle, V(16, 1, 10), CF(0, f2 + 3.5, -34), rgb(160, 20, 30), M.Fabric)
	W.solid(castle, V(7, 12, 3), CF(0, f2 + 9, -38.5), Palette.metal.gold, M.Metal)
	W.solid(castle, V(5, 2, 4), CF(0, f2 + 5, -36), Palette.metal.gold, M.Metal)
	W.deco(castle, V(1.4, 1.4, 0.4), CF(0, f2 + 13, -36.9), rgb(220, 30, 60), M.Neon)
	refs.throne = CF(0, f2 + 7, -35.5)
	refs.crownRoom = V(0, f2 + 3, 0)
	W.deco(castle, V(12, 0.3, 56), CF(0, f2 + 0.2, 8), rgb(150, 20, 30), M.Fabric)
	for i = -2, 2 do
		for _, x in { -18, 18 } do
			W.solid(castle, V(3.4, FH + 6, 3.4), CF(x, f2 + (FH + 6) / 2, i * 12), rgb(204, 198, 188), M.Marble)
			W.banner(castle, CF(x * 1.9, f2 + 7, i * 12) * ANG(0, if x < 0 then math.pi / 2 else -math.pi / 2, 0), rgb(40, 60, 140), Palette.metal.gold)
		end
	end
	for i = 1, 5 do
		W.torch(castle, CF(-K + 1.8, f2 + 10, -26 + i * 10))
		W.torch(castle, CF(K - 1.8, f2 + 10, -26 + i * 10))
	end
	refs.keepDoor = V(0, cy + 2, K + 5)

	-- the courtyard: barracks, stables, chapel, well, training yard
	B.stoneHouse(castle, CF(-92, cy, 10) * ANG(0, -math.pi / 2, 0), { rng = rng, w = 34, d = 16, floors = 2, name = "Barracks" })
	B.longhouse(castle, CF(92, cy, 50) * ANG(0, math.pi / 2, 0), { rng = rng, turf = false, shields = false, name = "Stables", len = 34 })
	for k = 1, 3 do
		S.Fauna.animal(castle, "horse", CF(80, cy, 30 + k * 12) * ANG(0, rng:angle(), 0), rng, { wander = 5 })
	end
	B.church(castle, CF(-80, cy, -85) * ANG(0, math.pi / 4, 0), { rng = rng })
	W.well(castle, V(70, cy, -70))
	for k = 1, 4 do
		local p = V(60 + k * 8, cy, 90)
		W.solid(castle, V(0.8, 5, 0.8), CF(p + V(0, 2.5, 0)), rgb(110, 80, 50), M.WoodPlanks)
		W.solid(castle, V(3, 0.8, 0.6), CF(p + V(0, 4.2, 0)), rgb(110, 80, 50), M.WoodPlanks)
		W.solid(castle, V(1.6, 1.6, 1.6), CF(p + V(0, 5.8, 0)), rgb(200, 180, 120), M.Fabric)
	end
	refs.courtyardSpawns = {}
	for _ = 1, 10 do
		table.insert(refs.courtyardSpawns, V(rng:float(-60, 60), cy + 3, rng:float(58, 110)))
	end
	refs.wallSpawns = { V(-60, cy + 29, CW), V(60, cy + 29, CW) }
	for _ = 1, 8 do
		W.barrel(castle, CF(rng:float(-100, -70), cy, rng:float(40, 100)))
		W.crate(castle, CF(rng:float(-100, -70), cy, rng:float(40, 100)))
	end
	for i = 1, 6 do
		W.banner(castle, CF(-50 + i * 14, cy, 118), rgb(40, 60, 140), Palette.metal.gold)
	end
	return castle
end

-- ------------------------------------------------------------------ arena + prison
local function buildArena(city: Instance, refs, rng)
	local W = S.World
	local stone = rgb(150, 146, 140)
	local ac = polar(ARENA_A, ARENA_R, TIERS[2].y)
	refs.arenaCenter = ac
	local arena = Kit.model("Arena", city)
	local sand = rgb(214, 190, 140)
	W.solid(arena, V(50, 1, 50), CF(ac + V(0, 0.5, 0)), sand, M.Sand)
	for tier = 0, 3 do
		local R = 26 + tier * 5
		local h = 10 + tier * 3.5
		for i = 1, 8 do
			local a1 = (i - 0.5) / 8 * math.pi * 2
			local a2 = (i + 0.5) / 8 * math.pi * 2
			local p1 = ac + V(math.cos(a1) * R, 0, math.sin(a1) * R)
			local p2 = ac + V(math.cos(a2) * R, 0, math.sin(a2) * R)
			local gate = tier == 0 and (i == 2 or i == 6)
			local mid = (p1 + p2) / 2
			if not gate then
				W.solid(arena, V(5, h, (p2 - p1).Magnitude + 2), CFrame.lookAt(mid + V(0, h / 2, 0), p2 + V(0, h / 2, 0)), Palette.shade(stone, 1 - tier * 0.05), M.Cobblestone)
			else
				W.solid(arena, V(5, 4, (p2 - p1).Magnitude + 2), CFrame.lookAt(mid + V(0, h - 2, 0), p2 + V(0, h - 2, 0)), stone, M.Cobblestone)
				local bars = Kit.model("Gate" .. i, arena)
				for b = -3, 3 do
					W.solid(bars, V(0.5, h - 4, 0.5), CFrame.lookAt(mid, p2) * CF(0, (h - 4) / 2, b * 2), Palette.metal.dark, M.Metal)
				end
				refs["arenaGate" .. i] = mid + V(0, 3, 0)
				refs["arenaGateModel" .. i] = bars
			end
		end
	end
	local boxP = ac + V(0, 0, -37)
	W.solid(arena, V(16, 18, 8), CF(boxP + V(0, 9, 0)), rgb(140, 130, 120), M.Marble)
	W.solid(arena, V(16, 1, 8), CF(boxP + V(0, 18.5, 3)), rgb(150, 20, 30), M.Fabric)
	W.banner(arena, CF(boxP + V(-7, 18, 4)), rgb(40, 60, 140), Palette.metal.gold)
	W.banner(arena, CF(boxP + V(7, 18, 4)), rgb(40, 60, 140), Palette.metal.gold)
	refs.royalBox = boxP + V(0, 21, 2)
	for i = 1, 8 do
		W.torch(arena, CF(ac + V(math.cos(i / 8 * math.pi * 2) * 25, 7, math.sin(i / 8 * math.pi * 2) * 25)))
	end
	refs.arenaSpectators = {}
	for _ = 1, 22 do
		local a = rng:angle()
		local R = rng:pick({ 31, 36, 41 })
		table.insert(refs.arenaSpectators, CFrame.lookAt(ac + V(math.cos(a) * R, 10 + (R - 26) * 0.7 + 3, math.sin(a) * R), ac + V(0, 10, 0)))
	end
	-- the prison block next to it
	local pc = ac + V(-44, 0, 20)
	refs.prisonCenter = pc
	local prison = Kit.model("Prison", city)
	local pw = rgb(110, 106, 100)
	W.solid(prison, V(34, 1, 22), CF(pc + V(0, 0.5, 0)), rgb(90, 88, 86), M.Slate)
	W.solid(prison, V(34, 14, 2), CF(pc + V(0, 7, -11)), pw, M.Cobblestone)
	W.solid(prison, V(34, 14, 2), CF(pc + V(0, 7, 11)), pw, M.Cobblestone)
	W.solid(prison, V(2, 14, 22), CF(pc + V(-17, 7, 0)), pw, M.Cobblestone)
	W.solid(prison, V(2, 14, 22), CF(pc + V(17, 7, 0)), pw, M.Cobblestone)
	W.solid(prison, V(34, 1, 22), CF(pc + V(0, 14.5, 0)), rgb(90, 88, 86), M.Slate)
	for c = 0, 2 do
		local x = -11 + c * 11
		W.solid(prison, V(1, 14, 10), CF(pc + V(x - 5.5, 7, -6)), pw, M.Cobblestone)
		for b = -2, 2 do
			W.solid(prison, V(0.4, 14, 0.4), CF(pc + V(x + b * 2, 7, -1)), Palette.metal.dark, M.Metal)
		end
		W.deco(prison, V(4, 1, 6), CF(pc + V(x, 1.5, -8)), rgb(200, 180, 110), M.Fabric)
		W.deco(prison, V(2, 2, 0.3), CF(pc + V(x, 10, -10.9)), rgb(255, 240, 200), M.Neon, { Transparency = 0.2 })
	end
	W.solid(prison, V(1, 14, 10), CF(pc + V(10.5, 7, -6)), pw, M.Cobblestone)
	refs.cellCF = CFrame.lookAt(pc + V(0, 3, -7), pc + V(0, 3, 4))
	refs.neighborCell = CFrame.lookAt(pc + V(11, 3, -7), pc + V(0, 3, 4))
	refs.cellDoor = pc + V(0, 3, -1)
	W.torch(prison, CF(pc + V(-8, 6, 9)))
	W.torch(prison, CF(pc + V(8, 6, 9)))
	return ac, pc
end

-- ------------------------------------------------------------------ build
function Capital.build(bible, seed: number)
	local rng = RNG.new(seed):fork("capital")
	local W = S.World
	local B = S.Build
	local N = S.Nature
	local counter = { n = 0 }
	local refs = { houses = {}, lowerHouses = {}, middleHouses = {}, upperHouses = {}, spawnsLower = {}, spawnsMiddle = {}, spawnsUpper = {}, castleSpawns = {}, breakables = {} }
	local pal = Palette.biomes.Meadow
	local stone = rgb(150, 146, 140)
	local folders = {
		map = W.sub("Map"),
		props = W.sub("Props"),
		city = W.sub("City"),
		houses = W.sub("Houses"),
		fields = W.sub("Fields"),
		farms = W.sub("Farms"),
	}

	-- terrain: plan the countryside, write the city + near ring now, stream the rest
	Land.plan(seed)
	local terrain = workspace.Terrain
	pcall(function()
		terrain.WaterColor = rgb(46, 92, 104)
		terrain.WaterTransparency = 0.55
		terrain.WaterReflectance = 0.5
		terrain.WaterWaveSize = 0.12
		terrain.WaterWaveSpeed = 7
		terrain:SetMaterialColor(M.Grass, rgb(92, 138, 58))
		terrain:SetMaterialColor(M.LeafyGrass, rgb(74, 114, 48))
		terrain:SetMaterialColor(M.Ground, rgb(112, 92, 66))
		terrain:SetMaterialColor(M.Mud, rgb(84, 68, 52))
		terrain:SetMaterialColor(M.Sand, rgb(206, 190, 142))
		terrain:SetMaterialColor(M.Rock, rgb(118, 114, 110))
		terrain:SetMaterialColor(M.Slate, rgb(128, 124, 118))
		terrain:SetMaterialColor(M.Snow, rgb(236, 240, 246))
		terrain:SetMaterialColor(M.Cobblestone, rgb(132, 126, 118))
		terrain:SetMaterialColor(M.Pavement, rgb(150, 146, 138))
		workspace.GlobalWind = V(7, 0, 4)
	end)
	local shaft = Capital.SHAFT
	local job = S.TerrainGen.start({
		key = "capital:" .. tostring(seed),
		radius = Land.EDGE_R,
		height = surface,
		paint = Land.paint,
		water = Land.WL,
		depth = 8,
		carves = { { shaft.X - 6, shaft.X + 6, shaft.Z - 6, shaft.Z + 6, TIERS[1].y - 170, TIERS[1].y + 6 } },
		budget = 7,
	})
	S.TerrainGen.runSync(job, 1750)
	S.TerrainGen.background(job)

	-- tier retaining walls (the terrain steps are hidden behind them)
	for i = 1, #TIERS - 1 do
		local t = TIERS[i]
		if t.r ~= TIERS[3].r then -- the inner wall stands on the middle tier's edge
			local R = t.r + 2.5
			local segs = math.floor(R * 2 * math.pi / 18)
			local drop = t.y - TIERS[i + 1].y
			for s = 1, segs do
				local a = s / segs * math.pi * 2
				local x, z = math.sin(a) * R, math.cos(a) * R
				local _, _, ri = onRoad(x, z)
				local ramp = ri > 0 and (i > 1 or ri == 1)
				if not ramp then
					local p = V(x, t.y, z)
					local c = CFrame.lookAt(p, p + V(math.sin(a), 0, math.cos(a)))
					W.solid(folders.map, V(19, 3, 2.5), c * CF(0, 1.5, 0), Palette.shade(stone, 0.9 + (s % 3) * 0.05), M.Cobblestone)
					W.solid(folders.map, V(19, drop + 0.6, 4), c * CF(0, -drop / 2 + 0.2, 0), Palette.shade(stone, 0.8), M.Slate)
				end
			end
		end
	end
	W.yield(counter)

	-- the castle, the arena and the prison
	buildCastle(folders.city, refs, rng)
	local ac, pc = buildArena(folders.city, refs, rng)

	-- houses along the ring streets -------------------------------------------------
	local blocked = { { p = ac, r = 60 }, { p = pc, r = 34 } }
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
	local function clearOfSquares(p: Vector3, pad: number)
		for _, sq in SQUARES do
			if Util.flatDist(p, sq.pos) < sq.R + pad then
				return false
			end
		end
		for _, b in blocked do
			if Util.flatDist(p, b.p) < b.r + pad then
				return false
			end
		end
		return true
	end
	local housePts = {}
	local function farFrom(p: Vector3, list, d: number)
		for _, q in list do
			if Util.flatDist(p, q) < d then
				return false
			end
		end
		return true
	end
	local specials = { tavern = false, smith = false }
	local function district(street, side: number, style: string, bucket, spawnBucket, maxCount: number, nDistricts: number)
		local streetR, tierY = street.r, street.y
		local perD = math.ceil(maxCount / nDistricts)
		for k = 0, nDistricts - 1 do
			local a = (k + rng:float(0.02, 0.3)) / nDistricts * math.pi * 2
			local placed, tries = 0, 0
			while placed < perD and tries < perD * 5 do
				tries += 1
				local w = if style == "stone" then rng:int(18, 22) elseif style == "cottage" then rng:int(12, 15) else rng:int(13, 17)
				local d = if style == "stone" then rng:int(14, 16) else rng:int(11, 13)
				local r = streetR + side * (street.w + 2 + d / 2)
				local p = V(math.sin(a) * r, tierY, math.cos(a) * r)
				if roadClear(p, w * 0.5 + 4) and clearOfSquares(p, w * 0.6) and farFrom(p, housePts, 12) then
					local face = CFrame.lookAt(p, V(math.sin(a) * streetR, tierY, math.cos(a) * streetR))
					local cf = CF(p) * (face - face.Position)
					local model, door
					if style == "stone" then
						local floors = rng:int(2, 3)
						model, door = B.stoneHouse(folders.houses, cf, { rng = rng, w = w, d = d, floors = floors })
						S.Interiors.register(model, { kind = "stone", cf = cf, w = w, d = d, floors = floors, fh = 10, plinth = 1.6, t = 1, seed = rng:int(1, 1e6), upper = false })
					else
						local floors = if style == "cottage" then (if rng:chance(0.6) then 1 else 2) else (if rng:chance(0.55) then 2 else 3)
						local sign = rng:chance(0.14)
						local kind = if sign then "shop" elseif style == "cottage" then "cottage" else "timber"
						if style == "timber" and not specials.tavern and rng:chance(0.08) then
							specials.tavern = true
							kind, sign, w, d, floors = "tavern", true, 17, 13, 2
						elseif style == "timber" and not specials.smith and rng:chance(0.08) then
							specials.smith = true
							kind, sign, floors = "smith", true, 1
						end
						model, door = B.halfTimber(folders.houses, cf, { rng = rng, w = w, d = d, floors = floors, sign = sign })
						S.Interiors.register(model, { kind = kind, cf = cf, w = w, d = d, floors = floors, fh = 9, plinth = 1.2, t = 0.8, seed = rng:int(1, 1e6), upper = floors > 1 })
					end
					table.insert(bucket, { model = model, door = door, cf = cf })
					table.insert(refs.houses, model)
					table.insert(spawnBucket, door)
					table.insert(housePts, p)
					placed += 1
					if rng:chance(0.2) then
						W.barrel(folders.props, cf * CF(w / 2 + 1.2, 0, -d / 2 - 1))
					end
					a += (w + rng:float(1.5, 4)) / r
					W.yield(counter)
				else
					a += 8 / r
				end
			end
		end
	end
	district(STREETS[4], 1, "cottage", refs.lowerHouses, refs.spawnsLower, 46, 7)
	district(STREETS[4], -1, "cottage", refs.lowerHouses, refs.spawnsLower, 40, 6)
	district(STREETS[3], 1, "cottage", refs.lowerHouses, refs.spawnsLower, 44, 6)
	district(STREETS[3], -1, "cottage", refs.lowerHouses, refs.spawnsLower, 34, 5)
	district(STREETS[2], 1, "timber", refs.middleHouses, refs.spawnsMiddle, 56, 6)
	district(STREETS[2], -1, "timber", refs.middleHouses, refs.spawnsMiddle, 48, 6)
	district(STREETS[1], 1, "stone", refs.upperHouses, refs.spawnsUpper, 20, 4)
	district(STREETS[1], -1, "stone", refs.upperHouses, refs.spawnsUpper, 14, 3)

	-- gardens, trees and yards between the districts
	for _ = 1, 320 do
		local a = rng:angle()
		local ring = rng:pick({ { 912, 1375, TIERS[4].y }, { 912, 1375, TIERS[4].y }, { 490, 890, TIERS[3].y }, { 200, 470, TIERS[2].y } })
		local r = rng:float(ring[1], ring[2])
		local p = V(math.sin(a) * r, ring[3], math.cos(a) * r)
		local streetOk = true
		for _, st in STREETS do
			if math.abs(r - st.r) < st.w + 4 then
				streetOk = false
			end
		end
		if streetOk and roadClear(p, 6) and clearOfSquares(p, 6) and farFrom(p, housePts, 16) then
			local roll = rng:float()
			if roll < 0.36 then
				N.oak(folders.props, p - V(0, 0.4, 0), rng, rng:float(1.1, 1.7), pal)
			elseif roll < 0.46 then
				N.field(folders.fields, CF(p) * ANG(0, a, 0), rng:int(12, 18), rng:int(8, 12), rng:pick({ "green", "green", "wheat" }), rng)
			elseif roll < 0.54 then
				B.laundry(folders.props, p, p + V(rng:float(-8, 8), 0, rng:float(-8, 8)))
			elseif roll < 0.62 then
				B.haystack(folders.props, p, 0.7)
			elseif roll < 0.7 then
				B.woodpile(folders.props, CF(p) * ANG(0, rng:angle(), 0))
			elseif roll < 0.82 then
				Land.flowers(folders.props, p, rng, pal.flowers)
			else
				N.bush(folders.props, p, rng, pal)
			end
			table.insert(housePts, p)
		end
		W.yield(counter)
	end

	-- squares: the great market, churches, fountains, wells ------------------------
	refs.marketVendors = {}
	refs.squares = {}
	for _, sq in SQUARES do
		local y = tierHeight(sq.r)
		local c = V(sq.pos.X, y, sq.pos.Z)
		table.insert(refs.squares, c)
		local face = CFrame.lookAt(c, V(0, y, 0))
		if sq.kind == "market" or sq.kind == "lowmarket" then
			B.fountain(folders.props, c)
			local rings = if sq.kind == "market" then { { 22, 8 }, { 46, 13 } } else { { 24, 9 } }
			for _, ring in rings do
				for k = 1, ring[2] do
					local a = k / ring[2] * math.pi * 2 + (if ring[1] > 30 then 0.12 else 0)
					local p = c + V(math.cos(a) * ring[1], 0, math.sin(a) * ring[1])
					local cf = CFrame.lookAt(p, c)
					B.stall(folders.props, cf, rng:pick({ rgb(170, 40, 40), rgb(40, 90, 160), rgb(200, 150, 40), rgb(60, 120, 60), rgb(130, 60, 130) }), rng)
					table.insert(refs.marketVendors, cf * CF(0, 3, 3.9))
				end
			end
			for _ = 1, 8 do
				local p = c + V(rng:float(-sq.R, sq.R) * 0.8, 0, rng:float(-sq.R, sq.R) * 0.8)
				local roll = rng:float()
				if roll < 0.35 then
					B.cart(folders.props, CF(p) * ANG(0, rng:angle(), 0))
				elseif roll < 0.7 then
					W.crate(folders.props, CF(p) * ANG(0, rng:angle(), 0))
				else
					W.barrel(folders.props, CF(p))
				end
			end
			for k = 1, 6 do
				local a = k / 6 * math.pi * 2
				Land.lamp(folders.props, c + V(math.cos(a) * (sq.R - 3), 0, math.sin(a) * (sq.R - 3)), k % 2 == 0)
			end
			if sq.kind == "market" then
				refs.marketCenter = c
			else
				refs.lowerSquare = c
			end
		elseif sq.kind == "church" or sq.kind == "cathedral" then
			B.church(folders.city, face * CF(0, 0, sq.R + 26), { rng = rng })
			B.fountain(folders.props, c)
		elseif sq.kind == "noble" then
			B.fountain(folders.props, c, { color = rgb(214, 208, 196) })
			B.statue(folders.props, c + V(0, 0, 18), math.pi, { scale = 2.6 })
			for k = 1, 4 do
				local a = k / 4 * math.pi * 2 + 0.4
				B.bench(folders.props, CFrame.lookAt(c + V(math.cos(a) * 14, 0, math.sin(a) * 14), c))
			end
		elseif sq.kind == "fountain" or sq.kind == "tavern" then
			B.fountain(folders.props, c)
			for k = 1, 3 do
				local a = k * 2.1
				B.bench(folders.props, CFrame.lookAt(c + V(math.cos(a) * 11, 0, math.sin(a) * 11), c))
			end
		elseif sq.kind == "gate" then
			refs.gateSquare = c
			for _, sx in { -1, 1 } do
				W.well(folders.props, c + V(sx * 26, 0, -8))
				B.cart(folders.props, CF(c + V(sx * 30, 0, 14)) * ANG(0, sx * 0.6, 0))
				W.banner(folders.props, CF(c + V(sx * 16, 0, 30)), rgb(40, 60, 140), Palette.metal.gold)
			end
		else
			W.well(folders.props, c)
			for _ = 1, 2 do
				B.cart(folders.props, CF(c + V(rng:float(-14, 14), 0, rng:float(-14, 14))) * ANG(0, rng:angle(), 0))
			end
		end
		W.yield(counter)
	end
	-- the Breakout fight happens around the gate plaza
	refs.lowerMarket = refs.lowerSquare
	refs.lowerSquare = refs.gateSquare or refs.lowerSquare or SQUARES[#SQUARES].pos
	B.statue(folders.props, V(0, TIERS[2].y, 200), math.pi)

	-- street lamps along the ring streets and the radial roads
	for _, st in STREETS do
		local segs = math.floor(2 * math.pi * st.r / 46)
		for i = 0, segs - 1 do
			local a = i / segs * math.pi * 2
			local side = if i % 2 == 0 then 1 else -1
			local p = polar(a, st.r + side * (st.w + 1.5), st.y)
			if roadClear(p, 2) and clearOfSquares(p, -4) then
				Land.lamp(folders.props, p, i % 3 == 0)
			end
		end
	end
	for _, a in ROADS do
		for r = 250, 1370, 40 do
			for _, s in { -1, 1 } do
				local dx, dz = math.sin(a), math.cos(a)
				local x = dx * r + dz * (ROAD_W + 2.5) * s
				local z = dz * r - dx * (ROAD_W + 2.5) * s
				local nearEdge = false
				for _, t in TIERS do
					if math.abs(r - t.r) < RAMP + 4 then
						nearEdge = true
					end
				end
				if not nearEdge and math.abs(r - Capital.INNER_WALL_R) > 30 then
					Land.lamp(folders.props, V(x, tierHeight(r), z), (r // 40) % 3 == 0)
				end
			end
		end
	end

	-- the walls ------------------------------------------------------------------
	B.greatWall(folders.city, V(0, TIERS[4].y, 0), Capital.INNER_WALL_R, 40, 10, { gates = ROADS, gateWidth = 24, gateHeight = 26, segment = 38, cannons = false, name = "InnerWall", color = rgb(176, 170, 158) })
	local great = B.greatWall(folders.city, V(0, 12, 0), Capital.WALL_R, Capital.WALL_H, Capital.WALL_T, { gates = ROADS, gateWidth = 30, gateHeight = 60, segment = 52, name = "GreatWall", banner = rgb(40, 60, 140), emblem = Palette.metal.gold })
	refs.greatGates = great.gates
	refs.wallTop = 12 + Capital.WALL_H
	-- stairs up the inside of the wall next to the south gate
	do
		local c0 = V(46, TIERS[4].y, Capital.WALL_R - 26)
		local c = CFrame.lookAt(c0, c0 + V(1, 0, 0))
		for i = 0, 44 do
			W.solid(folders.city, V(6, 3.4, 5), c * CF(0, 1.7 + i * 3.1, -i * 2.8), Palette.shade(stone, 1 - (i % 2) * 0.05), M.Slate)
		end
	end
	-- bridges over the moat at every gate
	for _, a in ROADS do
		local dir = V(math.sin(a), 0, math.cos(a))
		local a0 = dir * (Land.MOAT_R - 46)
		local b0 = dir * (Land.MOAT_R + 46)
		B.bridge(folders.city, V(a0.X, Land.OUTER_Y, a0.Z), V(b0.X, Land.OUTER_Y, b0.Z), ROAD_W * 2 + 2, { rise = 4 })
	end

	-- farmland just outside the wall (the lower fields), farmsteads and windmills
	local farmSpots = {}
	local P = Land.P
	for _ = 1, 60 do
		local a = rng:angle()
		local r = rng:float(Land.MOAT_R + 70, 2050)
		local x, z = math.sin(a) * r, math.cos(a) * r
		local p = V(x, 0, z)
		if roadClear(p, 26) and Land.hashDist(P.riverHash, x, z) > 60 and farFrom(p, farmSpots, 70) then
			local y = surface(x, z)
			local cf = CF(x, y - 0.2, z) * ANG(0, a + rng:float(-0.2, 0.2), 0)
			local w, d = rng:int(36, 60), rng:int(28, 46)
			N.field(folders.fields, cf, w, d, rng:pick({ "wheat", "wheat", "green", "flax" }), rng)
			table.insert(farmSpots, p)
			W.fence(folders.fields, (cf * CF(-w / 2, 0, d / 2 + 2)).Position, (cf * CF(w / 2, 0, d / 2 + 2)).Position)
			if rng:chance(0.4) then
				B.haystack(folders.fields, (cf * CF(w / 2 + 6, 0, 0)).Position)
			end
		end
		W.yield(counter)
	end
	local farmsteads = 0
	for _ = 1, 60 do
		if farmsteads >= 12 then
			break
		end
		local a = rng:angle()
		local r = rng:float(Land.MOAT_R + 90, 2000)
		local x, z = math.sin(a) * r, math.cos(a) * r
		local p = V(x, 0, z)
		if roadClear(p, 24) and Land.hashDist(P.riverHash, x, z) > 60 and farFrom(p, farmSpots, 50) then
			local y = surface(x, z)
			local cf = CF(x, y, z) * ANG(0, rng:angle(), 0)
			if farmsteads % 4 == 0 then
				B.windmill(folders.houses, V(x, y, z), rng:angle())
			else
				local fw, fd = rng:int(12, 15), 11
				local house = B.halfTimber(folders.houses, cf, { rng = rng, floors = 1, w = fw, d = fd })
				S.Interiors.register(house, { kind = "cottage", cf = cf, w = fw, d = fd, floors = 1, fh = 9, plinth = 1.2, t = 0.8, seed = rng:int(1, 1e6) })
				B.longhouse(folders.houses, cf * CF(22, 0, 6) * ANG(0, 0.3, 0), { rng = rng, turf = rng:chance(0.5), shields = false, name = "Barn" })
				B.cart(folders.props, cf * CF(-10, 0, -10) * ANG(0, 0.6, 0))
				-- a small pen
				local pc2 = cf * CF(-4, 0, 22)
				local pw2, pd2 = 18, 14
				local cs = { (pc2 * CF(-pw2 / 2, 0, -pd2 / 2)).Position, (pc2 * CF(pw2 / 2, 0, -pd2 / 2)).Position, (pc2 * CF(pw2 / 2, 0, pd2 / 2)).Position, (pc2 * CF(-pw2 / 2, 0, pd2 / 2)).Position }
				for k = 1, 4 do
					W.fence(folders.farms, cs[k], cs[k % 4 + 1])
				end
				local kind = rng:pick({ "sheep", "pig", "cow", "goat" })
				for _ = 1, rng:int(3, 5) do
					S.Fauna.animal(folders.farms, kind, pc2 * CF(rng:float(-6, 6), 0, rng:float(-4, 4)) * ANG(0, rng:angle(), 0), rng, { wander = 5 })
				end
			end
			table.insert(farmSpots, p)
			farmsteads += 1
		end
	end
	refs.burstPoint = V(0, surface(0, 1640), 1640)
	refs.fieldsSpawn = CFrame.lookAt(refs.burstPoint + V(0, 3, 0), V(0, refs.burstPoint.Y + 3, 0))

	-- the countryside ring: villages, forests, rocks, flowers, bridges, landmarks
	Land.dress(folders, rng:fork("dress"), refs, function(x, z)
		return (surface(x, z))
	end)

	-- ambient crowds for the city (the story switches them on when it's peaceful)
	local function streetPoints(st, step: number)
		local pts = {}
		local segs = math.floor(2 * math.pi * st.r / step)
		for i = 0, segs - 1 do
			table.insert(pts, polar(i / segs * math.pi * 2, st.r, st.y))
		end
		return pts
	end
	refs.townSets = {}
	local function defineSet(name, center, radius, points, count, extra)
		local set = { name = name, center = center, radius = radius, points = points, count = count, level = 8, ask = true, askEvery = 110, enabled = false }
		for k, v in extra or {} do
			set[k] = v
		end
		S.Townlife.define(set)
		table.insert(refs.townSets, name)
	end
	local lowPts = streetPoints(STREETS[4], 50)
	for _, p in streetPoints(STREETS[3], 50) do
		table.insert(lowPts, p)
	end
	defineSet("cityLower", V(0, TIERS[4].y, 0), 1300, lowPts, 16, { races = { "Human", "Human", "Beastkin" }, outfits = { "peasant", "peasant", "peasant", "merchant" } })
	local midPts = streetPoints(STREETS[2], 40)
	for _, sq in SQUARES do
		if sq.r == 690 then
			for k = 1, 6 do
				local a = k / 6 * math.pi * 2
				table.insert(midPts, V(sq.pos.X + math.cos(a) * sq.R * 0.6, TIERS[3].y, sq.pos.Z + math.sin(a) * sq.R * 0.6))
			end
		end
	end
	defineSet("cityMiddle", V(0, TIERS[3].y, 0), 880, midPts, 14, {})
	defineSet("cityUpper", V(0, TIERS[2].y, 0), 470, streetPoints(STREETS[1], 36), 8, { outfits = { "noble", "noble", "merchant" }, races = { "Human" } })
	if refs.marketCenter then
		local mpts = {}
		for k = 1, 10 do
			local a = k / 10 * math.pi * 2
			table.insert(mpts, refs.marketCenter + V(math.cos(a) * 34, 0, math.sin(a) * 34))
		end
		defineSet("market", refs.marketCenter, 80, mpts, 8, { vendors = refs.marketVendors })
	end

	-- gates & markers
	refs.middleGate = V(0, TIERS[3].y + 2, TIERS[3].r + 4)
	refs.upperGate = V(0, TIERS[2].y + 2, TIERS[2].r + 4)
	refs.lowerVillageEdge = V(0, TIERS[4].y + 2, Capital.WALL_R - 60)
	refs.southGate = V(0, Land.OUTER_Y + 2, Capital.WALL_R + 24)
	for _, a in ROADS do
		local p = V(math.sin(a) * (TIERS[2].r + RAMP + 6), 0, math.cos(a) * (TIERS[2].r + RAMP + 6))
		local fwd = V(math.sin(a), 0, math.cos(a))
		local side = fwd:Cross(V(0, 1, 0))
		for _, s in { -1, 1 } do
			W.tower(folders.city, V(p.X, TIERS[3].y, p.Z) + side * s * (ROAD_W + 6), 4, 20, stone, rgb(40, 60, 140))
		end
	end
	refs.center = V(0, TIERS[1].y, 0)
	refs.titanStand = V(-420, 0, -420)
	refs.terrainKey = job.key
	return refs
end

return Capital
