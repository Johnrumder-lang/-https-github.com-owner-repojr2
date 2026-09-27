--!nonstrict
-- NATURE KIT. Cubic trees (oak, pine, birch, willow, dead), the giant trees of
-- the old forests, bushes, rock clusters, cubic mountains with snow caps, crop
-- fields, reeds and logs. Positions are ground points.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Kit = require(Shared.Kit)
local Palette = require(Shared.Palette)
local S = require(script.Parent.S)

local N = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB
local M = Enum.Material

local function solid(parent, size, cf, color, mat, props)
	return Kit.part(parent, size, cf, color, mat, props)
end
local function deco(parent, size, cf, color, mat, props)
	return Kit.deco(parent, size, cf, color, mat, props)
end

local function leafCluster(m, center: Vector3, size: number, cols, rng, count: number, flat: number?)
	for i = 1, count do
		local off = V(rng:float(-1, 1), rng:float(-0.4, 0.6) * (flat or 1), rng:float(-1, 1)) * size * 0.45
		local s = size * rng:float(0.55, 0.95)
		deco(m, V(s, s * rng:float(0.6, 0.85), s), CF(center + off) * ANG(0, rng:angle(), 0), Palette.shade(cols[rng:int(1, #cols)], rng:float(0.92, 1.08)), M.Grass, { CastShadow = true })
	end
end

-- Trees are tall: every trunk height is multiplied by this (v4 trees were
-- barely three heads taller than you)
N.TALL = 1.55

-- broadleaf tree with a slightly leaning two-part trunk and a clustered crown
function N.oak(parent: Instance, pos: Vector3, rng, scale: number?, pal)
	local s = scale or rng:float(0.9, 1.5)
	pal = pal or Palette.biomes.Meadow
	local m = Kit.model("Tree", parent)
	local h = 8 * s * N.TALL
	if pal.lod then
		-- forest interior: 4 parts instead of 11
		solid(m, V(1.8 * s, h + 1, 1.8 * s), CF(pos + V(0, h / 2, 0)) * ANG(0, rng:angle(), 0), pal.trunk, M.WoodPlanks)
		leafCluster(m, pos + V(0, h + 1.5 * s, 0), 9.5 * s, pal.leaves, rng, 3)
		return m
	end
	local lean = ANG(rng:float(-0.06, 0.06), rng:angle(), rng:float(-0.06, 0.06))
	solid(m, V(1.9 * s, h * 0.55, 1.9 * s), CF(pos + V(0, h * 0.27, 0)) * lean, pal.trunk, M.WoodPlanks)
	solid(m, V(1.5 * s, h * 0.55, 1.5 * s), CF(pos + V(0, h * 0.7, 0)) * lean * ANG(0, 0.4, 0), Palette.shade(pal.trunk, 1.08), M.WoodPlanks)
	-- root flare
	deco(m, V(2.8 * s, 0.9 * s, 2.8 * s), CF(pos + V(0, 0.45 * s, 0)) * ANG(0, 0.8, 0), Palette.shade(pal.trunk, 0.9), M.WoodPlanks)
	-- two branches
	for i = 1, 2 do
		local a = rng:angle()
		deco(m, V(0.8 * s, 4 * s, 0.8 * s), CF(pos + V(0, h * 0.75, 0)) * ANG(0, a, 0) * ANG(0, 0, 0.8) * CF(0, 2 * s, 0), pal.trunk, M.WoodPlanks)
	end
	leafCluster(m, pos + V(0, h + 1.5 * s, 0), 9.5 * s, pal.leaves, rng, rng:int(5, 7))
	-- a lower skirt of leaves so the tall crown doesn't float on a bare pole
	leafCluster(m, pos + V(0, h * 0.72, 0), 7 * s, pal.leaves, rng, 2, 0.6)
	if rng:chance(0.2) then
		deco(m, V(0.7, 0.7, 0.7) * s, CF(pos + V(2.4 * s, h - 0.4, 1.2 * s)), rgb(220, 40, 40))
	end
	return m
end

-- conifer: stacked, alternately rotated tiers (snow caps in cold lands)
function N.pine(parent: Instance, pos: Vector3, rng, scale: number?, pal, snow: boolean?)
	local s = scale or rng:float(0.9, 1.6)
	pal = pal or Palette.biomes.Meadow
	local m = Kit.model("Pine", parent)
	local h = 14 * s * N.TALL
	solid(m, V(1.5 * s, h, 1.5 * s), CF(pos + V(0, h / 2, 0)), pal.trunk, M.WoodPlanks)
	local tiers = if pal.lod then 3 else 7
	local step = (if pal.lod then 6.2 else 2.9) * s * (N.TALL / 1.55)
	local dark = pal.pine or Palette.shade(pal.leaves[1], 0.72)
	for i = 0, tiers - 1 do
		local w = (10 - i * (if pal.lod then 2.9 else 1.25)) * s
		local y = h * 0.22 + i * step
		local c = deco(m, V(w, 2.6 * s, w), CF(pos + V(0, y, 0)) * ANG(0, (i % 2) * 0.785 + rng:float(-0.1, 0.1), 0), Palette.shade(dark, 1 + (i % 2) * 0.08), M.Grass, { CastShadow = true })
		if snow then
			deco(m, V(w * 0.8, 0.6 * s, w * 0.8), c.CFrame * CF(0, 1.5 * s, 0), rgb(245, 248, 255), M.Snow)
		end
	end
	deco(m, V(1.6 * s, 3.2 * s, 1.6 * s), CF(pos + V(0, h * 0.22 + tiers * step, 0)), dark, M.Grass)
	return m
end

function N.birch(parent: Instance, pos: Vector3, rng, scale: number?, pal)
	local s = scale or rng:float(0.9, 1.3)
	pal = pal or Palette.biomes.Meadow
	local m = Kit.model("Birch", parent)
	local h = 12 * s * N.TALL
	solid(m, V(1.1 * s, h, 1.1 * s), CF(pos + V(0, h / 2, 0)), rgb(236, 232, 222), M.SmoothPlastic)
	for i = 1, 4 do
		deco(m, V(1.14 * s, 0.25 * s, 0.6 * s), CF(pos + V(0, h * (0.15 + i * 0.17), 0)) * ANG(0, i * 1.3, 0) * CF(0, 0, 0.3 * s), rgb(40, 38, 36))
	end
	local cols = { Palette.shade(pal.leaves[1], 1.15), rgb(170, 190, 80), Palette.shade(pal.leaves[#pal.leaves], 1.1) }
	leafCluster(m, pos + V(0, h * 0.85, 0), 6.5 * s, cols, rng, 4, 1.8)
	return m
end

function N.willow(parent: Instance, pos: Vector3, rng, scale: number?, pal)
	local s = scale or rng:float(0.9, 1.3)
	pal = pal or Palette.biomes.Meadow
	local m = Kit.model("Willow", parent)
	local h = 8 * s * math.sqrt(N.TALL)
	solid(m, V(2 * s, h, 2 * s), CF(pos + V(0, h / 2, 0)), pal.trunk, M.WoodPlanks)
	deco(m, V(11, 3, 11) * s, CF(pos + V(0, h + 1, 0)), pal.leaves[1], M.Grass)
	local drapes = if pal.lod then 4 else 10
	for i = 1, drapes do
		local a = i / drapes * math.pi * 2
		deco(m, V(1.3, rng:float(4, 7), 1.3) * s, CF(pos + V(math.cos(a) * 5 * s, h - 2 * s, math.sin(a) * 5 * s)), pal.leaves[(i % #pal.leaves) + 1], M.Grass)
	end
	return m
end

function N.dead(parent: Instance, pos: Vector3, rng, scale: number?, pal)
	local s = scale or rng:float(0.9, 1.4)
	pal = pal or Palette.biomes.Meadow
	local m = Kit.model("DeadTree", parent)
	local h = 10 * s * N.TALL
	solid(m, V(1.4, h, 1.4) * V(s, 1, s), CF(pos + V(0, h / 2, 0)) * ANG(0, 0, rng:float(-0.1, 0.1)), Palette.shade(pal.trunk, 0.8), M.WoodPlanks)
	for i = 1, 4 do
		local a = rng:angle()
		deco(m, V(0.7, 4.5, 0.7) * s, CF(pos + V(0, h * (0.45 + i * 0.12), 0)) * ANG(0, a, 0) * ANG(0, 0, 0.9) * CF(0, 2 * s, 0), Palette.shade(pal.trunk, 0.75), M.WoodPlanks)
	end
	return m
end

-- A tree from the old forests: 150-300 studs tall, trunks wide enough to walk around
-- for a minute, branches you could stand on.
function N.giant(parent: Instance, pos: Vector3, rng, scale: number?, pal)
	local s = scale or rng:float(0.8, 1.25)
	pal = pal or Palette.biomes.Meadow
	local m = Kit.model("GiantTree", parent)
	local H = 220 * s
	local R = 11 * s
	local bark = Palette.shade(pal.trunk, 0.95)
	local segs = 4
	for i = 0, segs - 1 do
		local w = R * 2 * (1 - i * 0.12)
		local h = H / segs
		solid(m, V(w, h + 1, w), CF(pos + V(0, h * i + h / 2, 0)) * ANG(0, i * 0.35 + rng:float(-0.1, 0.1), 0), Palette.shade(bark, 1 + (i % 2) * 0.06), M.WoodPlanks, { CastShadow = true })
		-- bark ridges
		deco(m, V(w * 1.04, h * 0.9, w * 0.3), CF(pos + V(0, h * i + h / 2, 0)) * ANG(0, i * 0.35 + 0.8, 0), Palette.shade(bark, 0.85), M.WoodPlanks)
	end
	-- root buttresses
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + rng:float(-0.2, 0.2)
		local dir = V(math.sin(a), 0, math.cos(a))
		local len = R * rng:float(1.4, 2)
		deco(m, V(R * 0.5, R * 1.1, len), CFrame.lookAt(pos + dir * (R * 0.6 + len * 0.3) + V(0, R * 0.35, 0), pos + dir * 100 + V(0, R * 0.35, 0)) * ANG(-0.35, 0, 0), Palette.shade(bark, 0.9), M.WoodPlanks)
	end
	-- big horizontal branches with canopy clumps at the ends
	local cols = { pal.leaves[1], pal.leaves[2] or pal.leaves[1], Palette.shade(pal.leaves[1], 0.85) }
	for i = 1, rng:int(4, 6) do
		local a = rng:angle()
		local y = H * rng:float(0.35, 0.8)
		local len = R * rng:float(2.4, 3.6)
		local dir = V(math.sin(a), 0, math.cos(a))
		local base = pos + V(0, y, 0)
		solid(m, V(R * 0.45, R * 0.45, len), CFrame.lookAt(base + dir * len / 2, base + dir * len + V(0, len * 0.18, 0)), bark, M.WoodPlanks)
		local tip = base + dir * len + V(0, len * 0.18, 0)
		leafCluster(m, tip + V(0, R * 0.6, 0), R * 3.2, cols, rng, 3, 0.5)
	end
	-- crown
	leafCluster(m, pos + V(0, H + R * 0.5, 0), R * 5, cols, rng, 5, 0.5)
	return m
end

function N.bush(parent: Instance, pos: Vector3, rng, pal, size: number?)
	local s = size or rng:float(1.6, 3.2)
	pal = pal or Palette.biomes.Meadow
	for i = 1, rng:int(2, 3) do
		local k = s * rng:float(0.6, 1)
		deco(parent, V(k * 1.3, k, k * 1.3), CF(pos + V(rng:float(-1, 1) * s * 0.4, k * 0.45, rng:float(-1, 1) * s * 0.4)) * ANG(0, rng:angle(), 0), Palette.shade(pal.leaves[rng:int(1, #pal.leaves)], rng:float(0.85, 1)), M.Grass)
	end
	if rng:chance(0.25) then
		deco(parent, V(0.4, 0.4, 0.4), CF(pos + V(0.5, s * 0.9, 0.3)), pal.flowers and pal.flowers[1] or rgb(240, 80, 90))
	end
end

function N.rocks(parent: Instance, pos: Vector3, size: number, color: Color3, rng, mossy: boolean?)
	local m = Kit.model("Rocks", parent)
	for i = 1, rng:int(2, 4) do
		local s = size * rng:float(0.45, 1)
		local p = solid(m, V(s, s * rng:float(0.55, 0.95), s * rng:float(0.7, 1.15)), CF(pos + V(rng:float(-1, 1) * size * 0.45, s * 0.28, rng:float(-1, 1) * size * 0.45)) * ANG(rng:float(-0.3, 0.3), rng:angle(), rng:float(-0.3, 0.3)), Palette.jitter(color, 0.08, rng:float()), M.Slate)
		if mossy and rng:chance(0.6) then
			deco(m, V(p.Size.X * 0.9, 0.3, p.Size.Z * 0.9), p.CFrame * CF(0, p.Size.Y / 2, 0), rgb(84, 130, 60), M.Grass)
		end
	end
	return m
end

-- Blocky mountain: stacked, shrinking, jittered boxes with a snow cap above `snowLine`.
function N.mountain(parent: Instance, pos: Vector3, radius: number, height: number, rng, pal, snowLine: number?)
	local m = Kit.model("Mountain", parent)
	pal = pal or Palette.biomes.Meadow
	local rock = pal.rock
	local layers = math.clamp(math.floor(height / 40), 3, 9)
	local lh = height / layers
	for i = 0, layers - 1 do
		local k = 1 - i / layers
		local w = radius * 2 * (0.25 + 0.75 * k)
		local off = V(rng:float(-1, 1), 0, rng:float(-1, 1)) * radius * 0.12 * (1 - k)
		local y = pos.Y + lh * i + lh / 2
		local snow = snowLine and y > snowLine
		local col = if snow then rgb(240, 244, 250) else Palette.shade(rock, 0.85 + (i % 2) * 0.08)
		solid(m, V(w, lh + 0.5, w * rng:float(0.8, 1.1)), CF(V(pos.X, y, pos.Z) + off) * ANG(0, rng:float(-0.3, 0.3) + i * 0.15, 0), col, if snow then M.Snow else M.Slate, { CastShadow = false })
	end
	return m
end

-- Crop field: dark soil + rows of crop strips. rect = {cf, w, d}. crop: "wheat" | "green" | "flax"
function N.field(parent: Instance, cf: CFrame, w: number, d: number, crop: string?, rng)
	local m = Kit.model("Field", parent)
	local soil = rgb(104, 76, 52)
	solid(m, V(w, 0.6, d), cf * CF(0, 0.3, 0), soil, M.Ground)
	local col = if crop == "green" then rgb(96, 160, 64) elseif crop == "flax" then rgb(150, 150, 210) else rgb(222, 190, 90)
	local h = if crop == "green" then 1.2 else 2.4
	local rows = math.max(2, math.floor(w / 3.2))
	for i = 0, rows - 1 do
		local x = -w / 2 + (i + 0.5) * w / rows
		deco(m, V(1.5, h, d - 1.5), cf * CF(x, 0.6 + h / 2, 0), Palette.shade(col, 0.94 + (i % 2) * 0.08), M.Grass, { CastShadow = false })
	end
	return m
end

function N.reeds(parent: Instance, pos: Vector3, rng)
	for i = 1, rng:int(4, 7) do
		local h = rng:float(2, 4)
		deco(parent, V(0.25, h, 0.25), CF(pos + V(rng:float(-1.5, 1.5), h / 2, rng:float(-1.5, 1.5))) * ANG(rng:float(-0.15, 0.15), 0, rng:float(-0.15, 0.15)), rgb(120, 140, 70), M.Grass, { CastShadow = false })
	end
end

function N.log(parent: Instance, pos: Vector3, rng, pal)
	pal = pal or Palette.biomes.Meadow
	local len = rng:float(6, 12)
	local d = rng:float(1.4, 2.4)
	local p = Kit.cyl(parent, len, d, CF(pos + V(0, d / 2, 0)) * ANG(0, rng:angle(), 0), Palette.shade(pal.trunk, 0.9), M.WoodPlanks)
	if rng:chance(0.5) then
		deco(parent, V(len * 0.6, 0.2, d * 0.7), p.CFrame * CF(0, d / 2, 0), rgb(84, 130, 60), M.Grass)
	end
	return p
end

function N.stump(parent: Instance, pos: Vector3, rng, pal)
	pal = pal or Palette.biomes.Meadow
	local d = rng:float(1.6, 2.6)
	return solid(parent, V(d, rng:float(1, 2), d), CF(pos + V(0, 0.6, 0)) * ANG(0, rng:angle(), 0), pal.trunk, M.WoodPlanks)
end

-- Picks a tree kind for a biome and plants it.
function N.tree(parent: Instance, pos: Vector3, kind: string, rng, scale: number?, pal)
	if kind == "pine" then
		return N.pine(parent, pos, rng, scale, pal, pal and pal.snow)
	elseif kind == "birch" then
		return N.birch(parent, pos, rng, scale, pal)
	elseif kind == "willow" then
		return N.willow(parent, pos, rng, scale, pal)
	elseif kind == "dead" then
		return N.dead(parent, pos, rng, scale, pal)
	elseif kind == "giant" then
		return N.giant(parent, pos, rng, scale, pal)
	elseif kind == "oak" then
		return N.oak(parent, pos, rng, scale, pal)
	end
	return S.World.tree(parent, pos, kind, rng, scale, pal)
end

return N
