--!nonstrict
-- THE ASHEN FIELD - the PvP arena. A golden-hour autumn meadow on a plateau: a
-- sunken ring of flagstones inside a circle of monoliths, broken colonnades and
-- arches, a ruined watchtower, rock outcrops, burning braziers and autumn trees,
-- ringed by cliffs and far mountains. Built for fast movement: ramps, ledges,
-- pillars to wall-jump off, a tower to slam down from.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Kit = require(Shared.Kit)
local Palette = require(Shared.Palette)
local RNG = require(Shared.RNG)
local S = require(script.Parent.S)
local K = require(script.Parent.DungeonKit)
local P = require(script.Parent.DungeonProps)
local N = require(script.Parent.Nature)

local Arena = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB
local M = Enum.Material

Arena.ORIGIN = V(0, 0, 3000)
local HALF = 300 -- playable half size
local RING = 96 -- arena ring radius

local THEME = {
	name = "The Ashen Field",
	wall = { rgb(112, 104, 94), rgb(104, 97, 88), rgb(120, 111, 100), rgb(98, 92, 86) },
	floor = { rgb(96, 90, 82), rgb(88, 83, 76), rgb(104, 97, 88), rgb(92, 86, 80) },
	trim = { rgb(136, 126, 110), rgb(128, 119, 104), rgb(144, 133, 116) },
	vault = { rgb(100, 94, 86) },
	rock = { rgb(92, 88, 82), rgb(84, 80, 76), rgb(100, 95, 88) },
	statue = { rgb(150, 142, 128), rgb(140, 134, 122) },
	mat = M.Cobblestone,
	wallMat = M.Cobblestone,
	trimMat = M.Limestone,
	floorMat = M.Slate,
	roughMat = M.Rock,
	glow = rgb(255, 150, 70),
	grateGlow = rgb(255, 120, 50),
	accent = rgb(122, 26, 32),
	banner = rgb(120, 26, 30),
	emblem = rgb(176, 146, 86),
	water = rgb(60, 80, 90),
	flavor = "ruin",
}

local function noise(x, z, f, seed)
	return math.noise(x * f, z * f, seed)
end

-- ground height (local coordinates, 0 = arena floor)
local function heightAt(x: number, z: number, seed: number): number
	local r = math.sqrt(x * x + z * z)
	local h = 4 + noise(x, z, 1 / 120, seed) * 10 + noise(x, z, 1 / 45, seed + 3) * 3
	-- the sunken ring is flat; a rim rises around it
	if r < RING then
		return 0
	elseif r < RING + 24 then
		local k = (r - RING) / 24
		return math.max(0, h) * k * k + (1 - k) * 0
	end
	-- cliffs at the edge
	local edge = math.max(math.abs(x), math.abs(z))
	if edge > HALF - 30 then
		h += (edge - (HALF - 30)) * 2.2
	end
	return math.max(0, h)
end

function Arena.build(seed: number)
	seed = seed or 1
	local rng = RNG.new(seed):fork("arena")
	local root = S.World.sub("Arena")
	local O = Arena.ORIGIN
	local ctx = K.context(root, rng, THEME)
	ctx.maxShadows = 8
	local pal = Palette.biomes.Autumn
	local refs: any = { spawns = {}, center = O, theme = THEME }

	-- ground: coarse heightfield
	local cell = 12
	local n = math.floor(HALF * 2 / cell)
	local ground = Kit.folder("Ground", root)
	local grassCols = { rgb(150, 124, 62), rgb(138, 112, 56), rgb(162, 134, 70), rgb(126, 104, 54), rgb(112, 92, 60) }
	S.World.heightfield({
		nx = n,
		nz = n,
		cell = cell,
		step = 1,
		base = -30,
		origin = O - V(HALF, 0, HALF),
		parent = ground,
		height = function(ix, iz)
			local x = -HALF + (ix - 0.5) * cell
			local z = -HALF + (iz - 0.5) * cell
			return heightAt(x, z, seed)
		end,
		color = function(ix, iz, h)
			local x = -HALF + (ix - 0.5) * cell
			local z = -HALF + (iz - 0.5) * cell
			local r = math.sqrt(x * x + z * z)
			if r < RING + 4 then
				return 5
			end
			if h > 22 then
				return 6
			end
			local v = noise(x, z, 1 / 30, seed + 9)
			return if v > 0.25 then 3 elseif v > 0 then 1 elseif v > -0.25 then 2 else 4
		end,
		palette = { grassCols[1], grassCols[2], grassCols[3], grassCols[4], rgb(96, 90, 82), rgb(104, 98, 90) },
		material = function(k)
			return if k == 5 then M.Slate elseif k == 6 then M.Rock else M.Grass
		end,
	})

	-- the ring: flagstones, a raised border, a central rune dais
	K.floor(ctx, O.X - RING, O.Z - RING, O.X + RING, O.Z + RING, O.Y + 0.02, { tile = 8 })
	for i = 0, 47 do
		local a = i / 48 * math.pi * 2
		local p = O + V(math.cos(a) * (RING + 2), 0, math.sin(a) * (RING + 2))
		K.solid(ctx, V(13.2, 2.2, 4), CF(p + V(0, 1.1, 0)) * ANG(0, -a + math.pi / 2, 0), K.pj(ctx, THEME.trim, 0.06), THEME.trimMat)
	end
	-- dais with rune circle
	K.solid(ctx, V(36, 1.6, 36), CF(O + V(0, 0.8, 0)), K.pj(ctx, THEME.trim, 0.04), THEME.trimMat)
	K.solid(ctx, V(26, 1.4, 26), CF(O + V(0, 2.3, 0)) * ANG(0, math.pi / 4, 0), K.pj(ctx, THEME.floor, 0.04), THEME.floorMat)
	S.World.circle(root, O + V(0, 3.05, 0), 9, rgb(255, 120, 60), true)
	for _, d in { V(1, 0, 0), V(-1, 0, 0), V(0, 0, 1), V(0, 0, -1) } do
		K.stairs(ctx, O + d * 18 + V(0, 0, 0), -d, 10, 1.6, 3, { sides = false })
	end

	-- monolith circle (wall-jump fodder) and braziers
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2 + math.pi / 12
		local p = O + V(math.cos(a) * (RING - 14), 0, math.sin(a) * (RING - 14))
		local h = rng:float(16, 30)
		if i % 3 == 0 then
			K.pillar(ctx, p, 6, h + 10, { broken = h, bands = 7 })
		else
			local mono = K.solid(ctx, V(7, h, 3.5), CF(p + V(0, h / 2, 0)) * ANG(0, -a, rng:float(-0.05, 0.05)), K.pj(ctx, THEME.rock, 0.08), M.Basalt)
			mono.Name = "Monolith"
			K.deco(ctx, V(7.4, 1.2, 3.9), CF(p + V(0, h * 0.62, 0)) * ANG(0, -a, 0), K.pj(ctx, THEME.trim, 0.05), THEME.trimMat)
			-- glowing rune strip
			K.deco(ctx, V(0.6, h * 0.45, 3.7), CF(p + V(0, h * 0.35, 0)) * ANG(0, -a, 0), rgb(255, 120, 60), M.Neon, { Transparency = 0.35 })
		end
		if i % 2 == 1 then
			P.brazier(ctx, O + V(math.cos(a + 0.26) * (RING - 6), 0, math.sin(a + 0.26) * (RING - 6)), 1.2, i % 4 == 1)
		end
	end
	-- spawn points around the ring, facing the dais
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local p = O + V(math.cos(a) * (RING - 30), 3, math.sin(a) * (RING - 30))
		table.insert(refs.spawns, CFrame.lookAt(p, V(O.X, p.Y, O.Z)))
	end

	-- broken colonnades + arches just outside the ring (high ground, parkour)
	for c = 0, 3 do
		local a0 = c / 4 * math.pi * 2 + rng:float(-0.2, 0.2)
		local r = RING + 36
		local base = O + V(math.cos(a0) * r, 0, math.sin(a0) * r)
		local gy = heightAt(base.X - O.X, base.Z - O.Z, seed)
		local tang = V(-math.sin(a0), 0, math.cos(a0))
		local count = rng:int(4, 6)
		local tall = rng:float(30, 44)
		K.solid(ctx, V(count * 16 + 12, 3, 18), CFrame.lookAt(base + V(0, gy + 1.5, 0), base + V(0, gy + 1.5, 0) + tang), K.pj(ctx, THEME.floor, 0.05), THEME.floorMat)
		for i = 0, count - 1 do
			local p = base + tang * ((i - (count - 1) / 2) * 16) + V(0, gy + 3, 0)
			local broken = if rng:chance(0.4) then rng:float(8, tall * 0.7) else nil
			K.pillar(ctx, p, 5, tall, { broken = broken, bands = 9 })
			if not broken and i < count - 1 and rng:chance(0.7) then
				local q = p + tang * 16
				K.arch(ctx, p + V(0, tall - 6, 0), q + V(0, tall - 6, 0), 5, 5, {})
				-- walkable lintel on top
				K.solid(ctx, V(16, 2, 6), CFrame.lookAt((p + q) / 2 + V(0, tall + 0.2, 0), (p + q) / 2 + V(0, tall + 0.2, 0) + tang), K.pj(ctx, THEME.trim, 0.05), THEME.trimMat)
			end
		end
		P.rubble(ctx, base + V(0, gy + 3, 0) - tang * 20, 10, 12, THEME.rock, THEME.roughMat)
	end

	-- the ruined watchtower (slam platform)
	do
		local a = rng:angle()
		local p = O + V(math.cos(a) * (RING + 70), 0, math.sin(a) * (RING + 70))
		local gy = heightAt(p.X - O.X, p.Z - O.Z, seed)
		local w, h = 26, 72
		local b = p + V(0, gy, 0)
		-- hollow square tower with a spiral of ledges inside, broken crown
		for s = 0, 3 do
			local ang = s * math.pi / 2
			local n0 = V(math.cos(ang), 0, math.sin(ang))
			local t0 = V(-n0.Z, 0, n0.X)
			local hh = h - (if s == 1 then 22 elseif s == 3 then 9 else 0)
			local wall = K.solid(ctx, V(w, hh, 3), CFrame.lookAt(b + n0 * (w / 2) + V(0, hh / 2, 0), b + n0 * (w / 2) + V(0, hh / 2, 0) + n0), K.pj(ctx, THEME.wall, 0.06), THEME.wallMat)
			wall.Name = "TowerWall"
			for y = 12, hh - 4, 14 do
				K.deco(ctx, V(w + 1, 1.2, 3.8), CFrame.lookAt(b + n0 * (w / 2) + V(0, y, 0), b + n0 * (w / 2) + V(0, y, 0) + n0), K.pj(ctx, THEME.trim, 0.05), THEME.trimMat)
			end
			-- crenellations
			for i = -2, 2, 2 do
				K.solid(ctx, V(3, 3.5, 3.4), CF(b + n0 * (w / 2) + t0 * (i * 4.5) + V(0, hh + 1.75, 0)), K.pj(ctx, THEME.trim, 0.05), THEME.trimMat)
			end
		end
		-- door gap is left by the stairs: ledges spiralling up inside
		for i = 0, 16 do
			local ang = i * 0.9
			local lp = b + V(math.cos(ang) * 7, 3 + i * 4, math.sin(ang) * 7)
			K.solid(ctx, V(8, 1.4, 8), CF(lp), K.pj(ctx, THEME.floor, 0.05), THEME.floorMat)
		end
		K.solid(ctx, V(w - 2, 2, w - 2), CF(b + V(0, h - 8, 0)), K.pj(ctx, THEME.floor, 0.05), THEME.floorMat)
		-- entrance ramp outside to the first ledge level
		K.solid(ctx, V(10, 1.4, 22), CF(b + V(0, 5, -w / 2 - 10)) * ANG(-0.36, 0, 0), K.pj(ctx, THEME.floor, 0.05), THEME.floorMat)
		P.banner(ctx, CF(b + V(0, h * 0.7, -w / 2 - 1.8)) * ANG(0, math.pi, 0), 6, 16, THEME.banner, THEME.emblem)
		refs.tower = b + V(0, h - 6, 0)
	end

	-- a kneeling knight statue facing the dais (landmark)
	do
		local a = rng:angle()
		local p = O + V(math.cos(a) * (RING + 24), 0, math.sin(a) * (RING + 24))
		local gy = heightAt(p.X - O.X, p.Z - O.Z, seed)
		K.solid(ctx, V(12, 4, 12), CF(p + V(0, gy + 2, 0)), K.pj(ctx, THEME.trim, 0.05), THEME.trimMat)
		P.knight(ctx, CFrame.lookAt(p + V(0, gy + 4, 0), V(O.X, p.Y + gy + 4, O.Z)), 3.2)
	end

	-- nature: autumn groves (clustered), bushes, rocks, grass tufts (outside the ring)
	local nat = Kit.folder("Nature", root)
	local groves = {}
	for _ = 1, 9 do
		local a = rng:angle()
		local r = rng:float(RING + 60, HALF - 40)
		table.insert(groves, V(math.cos(a) * r, 0, math.sin(a) * r))
	end
	for i = 1, 330 do
		local x, z
		if i % 3 ~= 0 then
			local g = groves[rng:int(1, #groves)]
			x = g.X + rng:float(-38, 38)
			z = g.Z + rng:float(-38, 38)
		else
			x = rng:float(-HALF + 20, HALF - 20)
			z = rng:float(-HALF + 20, HALF - 20)
		end
		x = math.clamp(x, -HALF + 16, HALF - 16)
		z = math.clamp(z, -HALF + 16, HALF - 16)
		local r = math.sqrt(x * x + z * z)
		if r > RING + 28 then
			local y = heightAt(x, z, seed)
			local pos = O + V(x, y, z)
			local roll = rng:float()
			if roll < 0.5 then
				N.oak(nat, pos, rng, rng:float(1.1, 2), pal)
			elseif roll < 0.62 then
				N.birch(nat, pos, rng, rng:float(1, 1.6), pal)
			elseif roll < 0.72 then
				N.dead(nat, pos, rng, rng:float(1, 1.6), pal)
			elseif roll < 0.9 then
				N.bush(nat, pos, rng, pal, rng:float(1.5, 3))
			else
				N.rocks(nat, pos, rng:float(6, 16), THEME.rock[1], rng, true)
			end
		end
	end
	-- grass tufts and fallen leaves
	for _ = 1, 700 do
		local x = rng:float(-HALF + 10, HALF - 10)
		local z = rng:float(-HALF + 10, HALF - 10)
		local r = math.sqrt(x * x + z * z)
		if r > RING + 6 then
			local y = heightAt(x, z, seed)
			local p = O + V(x, y, z)
			local c = grassCols[rng:int(1, #grassCols)]
			local h = rng:float(1.2, 2.6)
			Kit.deco(nat, V(0.25, h, 0.25), CF(p + V(0, h / 2, 0)) * ANG(rng:float(-0.3, 0.3), rng:angle(), rng:float(-0.3, 0.3)), Palette.shade(c, 1.1), M.Grass, { CastShadow = false })
			Kit.deco(nat, V(0.25, h * 0.8, 0.25), CF(p + V(0.4, h * 0.4, 0.2)) * ANG(rng:float(-0.4, 0.4), rng:angle(), rng:float(-0.4, 0.4)), c, M.Grass, { CastShadow = false })
		end
	end
	-- ruined curtain walls of an old keep along the rim (cover, wall jumps)
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2 + rng:float(-0.2, 0.2)
		local r = rng:float(RING + 50, RING + 110)
		local c = V(math.cos(a) * r, 0, math.sin(a) * r)
		local y = heightAt(c.X, c.Z, seed)
		local tang = V(-math.sin(a), 0, math.cos(a))
		local L = rng:float(30, 60)
		local H = rng:float(14, 26)
		local cf = CFrame.lookAt(O + c + V(0, y + H / 2 - 1, 0), O + c + V(0, y + H / 2 - 1, 0) + tang) * ANG(0, math.pi / 2, 0)
		K.solid(ctx, V(L, H, 5), cf, K.pj(ctx, THEME.wall, 0.06), THEME.wallMat)
		K.deco(ctx, V(L + 0.6, 1.2, 5.6), cf * CF(0, -H / 2 + 1.5, 0), K.pj(ctx, THEME.trim, 0.05), THEME.trimMat)
		K.deco(ctx, V(L + 0.6, 1, 5.6), cf * CF(0, H * 0.18, 0), K.pj(ctx, THEME.trim, 0.05), THEME.trimMat)
		local x = -L / 2 + 2
		while x < L / 2 - 2 do
			if rng:chance(0.75) then
				K.solid(ctx, V(3, rng:float(2.5, 4), 5.2), cf * CF(x, H / 2 + 1.5, 0), K.pj(ctx, THEME.trim, 0.06), THEME.trimMat)
			end
			x += 5
		end
		-- a breach and rubble
		P.rubble(ctx, O + c + V(0, y, 0) + Vector3.new(tang.Z, 0, -tang.X) * 6, 8, 10, THEME.rock, THEME.roughMat)
		if rng:chance(0.5) then
			P.banner(ctx, cf * CF(rng:float(-L / 3, L / 3), H * 0.1, 2.8), 4, 10, THEME.banner, THEME.emblem)
		end
	end
	-- fallen columns lying in the grass
	for _ = 1, 10 do
		local a = rng:angle()
		local r = rng:float(RING + 20, HALF - 60)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local y = heightAt(x, z, seed)
		local len = rng:float(14, 26)
		local cf = CF(O + V(x, y + 2, z)) * ANG(0, rng:angle(), 0)
		K.solid(ctx, V(len, 4, 4), cf, K.pj(ctx, THEME.wall, 0.06), THEME.wallMat)
		for k = -1, 1, 2 do
			K.deco(ctx, V(1, 4.8, 4.8), cf * CF(k * len * 0.3, 0, 0), K.pj(ctx, THEME.trim, 0.05), THEME.trimMat)
		end
		P.moss(ctx, O + V(x, y + 4.05, z), len * 0.6, 3, 3)
	end
	-- big rock outcrops (like the reference: flat grey slabs in the grass)
	for _ = 1, 14 do
		local a = rng:angle()
		local r = rng:float(RING + 40, HALF - 50)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local y = heightAt(x, z, seed)
		local w = rng:float(18, 40)
		K.solid(ctx, V(w, rng:float(4, 9), w * rng:float(0.5, 0.9)), CF(O + V(x, y + 1, z)) * ANG(rng:float(-0.08, 0.08), rng:angle(), rng:float(-0.08, 0.08)), K.pj(ctx, THEME.rock, 0.08), M.Slate)
	end
	-- far mountains + walls you can't pass
	for i = 0, 17 do
		local a = i / 18 * math.pi * 2
		local r = HALF + 140
		N.mountain(root, O + V(math.cos(a) * r, -10, math.sin(a) * r), rng:float(110, 170), rng:float(120, 220), rng, pal, nil)
	end
	for _, d in { V(1, 0, 0), V(-1, 0, 0), V(0, 0, 1), V(0, 0, -1) } do
		local w = Instance.new("Part")
		w.Anchored = true
		w.Transparency = 1
		w.CanQuery = false
		w.Size = if d.X ~= 0 then V(4, 400, HALF * 2) else V(HALF * 2, 400, 4)
		w.CFrame = CF(O + d * (HALF - 4) + V(0, 150, 0))
		w.Name = "EdgeWall"
		w.Parent = root
	end
	local killFloor = Instance.new("Part")
	killFloor.Anchored = true
	killFloor.Transparency = 1
	killFloor.CanCollide = true
	killFloor.Size = V(HALF * 2, 4, HALF * 2)
	killFloor.CFrame = CF(O + V(0, -40, 0))
	killFloor.Name = "SafetyFloor"
	killFloor.Parent = root
	refs.parts = ctx.n
	return refs
end

return Arena
