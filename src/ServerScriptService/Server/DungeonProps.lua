--!nonstrict
-- Prop library for the underground: bones, skeletons, sarcophagi, coffins, cages,
-- chains, banners, statues, altars, candles, braziers, torches, chandeliers,
-- rubble, cobwebs, weapon racks, bookshelves, spikes, puddles, roots, moss,
-- drips, crystals, fungus, mine / forge gear and the Warden's throne.
-- Every function takes the DungeonKit context first; `cf` is a floor-level
-- CFrame whose LookVector is the prop's front.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Kit = require(Shared.Kit)
local Palette = require(Shared.Palette)
local K = require(script.Parent.DungeonKit)
local S = require(script.Parent.S)

local P = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB
local M = Enum.Material

local BONE = rgb(204, 194, 168)
local BONE_D = rgb(168, 156, 128)
local SOCKET = rgb(26, 20, 18)
local IRON = rgb(56, 54, 58)
local RUST = rgb(90, 62, 46)
local WOOD = rgb(86, 60, 40)
local WOOD_D = rgb(60, 42, 28)
local WAX = rgb(222, 208, 176)
local GOLD = rgb(170, 140, 80)
local MOSS = rgb(78, 104, 54)
local WEB = rgb(196, 196, 200)
P.BONE, P.IRON, P.WOOD, P.GOLD, P.MOSS = BONE, IRON, WOOD, GOLD, MOSS

local function d(ctx, size, cf, color, mat, props)
	return K.deco(ctx, size, cf, color, mat, props)
end
local function s(ctx, size, cf, color, mat, props)
	return K.solid(ctx, size, cf, color, mat, props)
end
local function j(ctx, c, a)
	return K.j(ctx, c, a or 0.08)
end

-- a box stretched between two points
local function limb(ctx, a: Vector3, b: Vector3, t: number, color: Color3, mat)
	local len = (b - a).Magnitude
	if len < 0.05 then
		return nil
	end
	return d(ctx, V(t, t, len + t * 0.4), CFrame.lookAt((a + b) / 2, b), color, mat or M.Limestone)
end
P.limb = limb

-- ------------------------------------------------------------------ bones
function P.skull(ctx, cf: CFrame, sc: number?, cheap: boolean?)
	local k = sc or 1
	local c = j(ctx, BONE, 0.06)
	d(ctx, V(1, 0.9, 1.1) * k, cf * CF(0, 0.5 * k, 0), c, M.Limestone)
	if cheap then
		d(ctx, V(0.7, 0.22, 0.1) * k, cf * CF(0, 0.52 * k, -0.57 * k), SOCKET, M.Slate)
		return
	end
	d(ctx, V(0.28, 0.26, 0.1) * k, cf * CF(-0.24 * k, 0.55 * k, -0.57 * k), SOCKET, M.Slate)
	d(ctx, V(0.28, 0.26, 0.1) * k, cf * CF(0.24 * k, 0.55 * k, -0.57 * k), SOCKET, M.Slate)
	d(ctx, V(0.14, 0.18, 0.1) * k, cf * CF(0, 0.33 * k, -0.57 * k), SOCKET, M.Slate)
	d(ctx, V(0.8, 0.28, 0.62) * k, cf * CF(0, 0.08 * k, -0.24 * k), Palette.shade(c, 0.94), M.Limestone)
end

function P.bone(ctx, cf: CFrame, len: number)
	local c = j(ctx, BONE, 0.08)
	d(ctx, V(0.26, 0.26, len), cf * CF(0, 0.14, 0), c, M.Limestone)
	d(ctx, V(0.46, 0.36, 0.34), cf * CF(0, 0.18, -len / 2), c, M.Limestone)
	d(ctx, V(0.46, 0.36, 0.34), cf * CF(0, 0.18, len / 2), c, M.Limestone)
end

function P.bonePile(ctx, pos: Vector3, r: number, n: number, skulls: number?)
	local rng = ctx.rng
	for i = 1, n do
		local p = pos + V(rng:float(-r, r), 0, rng:float(-r, r))
		P.bone(ctx, CF(p + V(0, rng:float(0, 0.3), 0)) * ANG(rng:float(-0.3, 0.3), rng:angle(), rng:float(-0.2, 0.2)), rng:float(1.2, 2.2))
	end
	for i = 1, (skulls or math.max(1, math.floor(n / 4))) do
		local p = pos + V(rng:float(-r * 0.7, r * 0.7), rng:float(0, 0.3), rng:float(-r * 0.7, r * 0.7))
		P.skull(ctx, CF(p) * ANG(rng:float(-0.4, 0.3), rng:angle(), rng:float(-0.3, 0.3)), rng:float(0.8, 1.05), i > 2)
	end
end

-- full skeleton. pose: "sit" (against a wall behind +Z), "lie", "slump" (face down)
-- opts {reach = Vector3 world point the right hand reaches toward}
function P.skeleton(ctx, cf: CFrame, pose: string?, opts)
	opts = opts or {}
	local rng = ctx.rng
	local c = j(ctx, BONE, 0.05)
	local function w(x, y, z)
		return cf:PointToWorldSpace(V(x, y, z))
	end
	local pelvis, neck, head, shL, shR, hipL, hipR, elL, elR, haL, haR, knL, knR, anL, anR
	if pose == "lie" then
		pelvis = w(0, 0.3, 0)
		neck = w(0, 0.35, 2.4)
		head = w(0.1, 0.1, 3.1)
		shL, shR = w(-0.75, 0.35, 2.1), w(0.75, 0.35, 2.1)
		hipL, hipR = w(-0.35, 0.25, 0), w(0.35, 0.25, 0)
		elL, elR = w(-1.3, 0.2, 1.1), w(1.2, 0.2, 1.0)
		haL, haR = w(-1.4, 0.12, 0.1), w(1.6, 0.12, 0.3)
		knL, knR = w(-0.45, 0.25, -1.6), w(0.55, 0.25, -1.55)
		anL, anR = w(-0.5, 0.2, -3.1), w(0.8, 0.2, -3.0)
	else
		pelvis = w(0, 0.45, 0.2)
		neck = w(0.05, 2.55, 0.95)
		head = w(0.25, 2.6, 0.45)
		shL, shR = w(-0.75, 2.2, 0.85), w(0.75, 2.25, 0.85)
		hipL, hipR = w(-0.38, 0.4, 0.05), w(0.38, 0.4, 0.05)
		elL, elR = w(-1.05, 1.1, 0.55), w(1.1, 1.15, 0.35)
		haL, haR = w(-1.15, 0.2, -0.1), w(1.35, 0.2, -0.6)
		knL, knR = w(-0.55, 1.15, -1.45), w(0.5, 0.45, -1.8)
		anL, anR = w(-0.6, 0.2, -2.6), w(0.6, 0.2, -3.3)
		if opts.reach then
			local rv = opts.reach
			elR = w(1.25, 1.0, -0.2)
			haR = V(rv.X, cf.Position.Y + 0.25, rv.Z)
			local dir = (haR - elR)
			if dir.Magnitude > 1.3 then
				haR = elR + dir.Unit * 1.3
			end
		end
	end
	-- spine (3 vertebra blocks) + pelvis + ribs
	for i = 0, 2 do
		local a = pelvis:Lerp(neck, i / 3)
		local b = pelvis:Lerp(neck, (i + 1) / 3)
		limb(ctx, a, b, 0.32, Palette.shade(c, 0.95))
	end
	local up = (neck - pelvis).Unit
	local side = (shR - shL).Unit
	local fwd = side:Cross(up).Unit * -1
	d(ctx, V(1.25, 0.55, 0.6), CFrame.fromMatrix(pelvis, side, up, -fwd), c, M.Limestone)
	for i = 1, 4 do
		local p = pelvis:Lerp(neck, 0.45 + i * 0.12)
		local wd = 1.25 - math.abs(i - 2.5) * 0.18
		local cfR = CFrame.fromMatrix(p, side, up, -fwd)
		d(ctx, V(wd, 0.16, 0.16), cfR * CF(0, 0, -0.42), c, M.Limestone)
		d(ctx, V(0.16, 0.16, 0.8), cfR * CF(-wd / 2 + 0.08, 0, -0.05), c, M.Limestone)
		d(ctx, V(0.16, 0.16, 0.8), cfR * CF(wd / 2 - 0.08, 0, -0.05), c, M.Limestone)
	end
	limb(ctx, shL, shR, 0.22, c)
	-- head (tilted)
	local hcf = CFrame.lookAt(head, head + fwd * 2 - up * 0.8) * ANG(0, 0, rng:float(-0.35, 0.35))
	P.skull(ctx, hcf * CF(0, -0.5, 0), 1)
	-- arms and legs
	limb(ctx, shL, elL, 0.24, c)
	limb(ctx, elL, haL, 0.21, c)
	limb(ctx, shR, elR, 0.24, c)
	limb(ctx, elR, haR, 0.21, c)
	d(ctx, V(0.36, 0.14, 0.45), CFrame.lookAt(haL, haL + (haL - elL)) * CF(0, 0, -0.2), c, M.Limestone)
	d(ctx, V(0.36, 0.14, 0.45), CFrame.lookAt(haR, haR + (haR - elR)) * CF(0, 0, -0.2), c, M.Limestone)
	limb(ctx, hipL, knL, 0.3, c)
	limb(ctx, knL, anL, 0.27, c)
	limb(ctx, hipR, knR, 0.3, c)
	limb(ctx, knR, anR, 0.27, c)
	d(ctx, V(0.38, 0.2, 0.75), CFrame.lookAt(anL + V(0, 0.05, 0), anL + fwd + V(0, 0.05, 0)) * CF(0, 0, -0.25), c, M.Limestone)
	d(ctx, V(0.38, 0.2, 0.75), CFrame.lookAt(anR + V(0, 0.05, 0), anR + fwd + V(0, 0.05, 0)) * CF(0, 0, -0.25), c, M.Limestone)
	if opts.rags then
		-- rotten cloth over the ribs
		d(ctx, V(1.4, 1.2, 0.2), CFrame.fromMatrix(pelvis:Lerp(neck, 0.55), side, up, -fwd) * CF(0, 0, -0.52), opts.rags, M.Fabric)
	end
end

-- ------------------------------------------------------------------ tombs
function P.sarcophagus(ctx, cf: CFrame, opts)
	opts = opts or {}
	local th = ctx.theme
	local rng = ctx.rng
	local stone = K.pj(ctx, th.trim or th.wall, 0.05)
	local mat = th.trimMat or M.Limestone
	s(ctx, V(8.2, 0.7, 4), cf * CF(0, 0.3, 0), Palette.shade(stone, 0.9), mat)
	s(ctx, V(7.4, 2.4, 3.3), cf * CF(0, 1.85, 0), stone, mat)
	-- carved side panels
	for _, x in { -2, 2 } do
		d(ctx, V(2.6, 1.3, 0.16), cf * CF(x, 1.9, -1.7), Palette.shade(stone, 0.85), mat)
		d(ctx, V(2.6, 1.3, 0.16), cf * CF(x, 1.9, 1.7), Palette.shade(stone, 0.85), mat)
	end
	local lidOpen = opts.open or rng:chance(0.22)
	local lidCF = cf * CF(0, 3.45, 0)
	if lidOpen then
		lidCF = cf * CF(rng:float(-0.8, 0.8), 3.3, rng:sign() * 1.6) * ANG(rng:float(-0.25, 0.25), rng:float(-0.4, 0.4), rng:float(0.05, 0.15))
		d(ctx, V(6.6, 0.2, 2.6), cf * CF(0, 3.1, 0), SOCKET, M.Slate)
		P.skull(ctx, cf * CF(-2.2, 3.05, 0) * ANG(-0.6, 0.3, 0), 0.9)
		P.bone(ctx, cf * CF(0.5, 3.0, 0.4) * ANG(0, 1.3, 0.3), 1.8)
	end
	d(ctx, V(7.9, 0.8, 3.8), lidCF, Palette.shade(stone, 1.05), mat)
	if not lidOpen or rng:chance(0.5) then
		-- effigy of a knight on the lid
		local e = lidCF * CF(0, 0.4, 0)
		local ec = Palette.shade(stone, 1.1)
		d(ctx, V(4.6, 0.7, 1.5), e * CF(-0.3, 0.35, 0), ec, mat)
		d(ctx, V(1.1, 0.9, 1.1), e * CF(2.6, 0.45, 0), ec, mat)
		d(ctx, V(0.3, 0.3, 0.9), e * CF(2.6, 1, 0), ec, mat)
		d(ctx, V(3.4, 0.25, 0.3), e * CF(0.2, 0.85, 0), Palette.shade(ec, 0.92), mat)
		d(ctx, V(0.3, 0.3, 1.4), e * CF(1.7, 0.85, 0), Palette.shade(ec, 0.92), mat)
		d(ctx, V(1.4, 0.5, 0.6), e * CF(-2.6, 0.3, -0.35), ec, mat)
		d(ctx, V(1.4, 0.5, 0.6), e * CF(-2.6, 0.3, 0.35), ec, mat)
	end
end

function P.coffin(ctx, cf: CFrame, open: boolean?)
	local c = j(ctx, WOOD_D, 0.1)
	s(ctx, V(2.3, 1.4, 4.4), cf * CF(0, 0.7, -0.8), c, M.WoodPlanks)
	s(ctx, V(1.7, 1.3, 2.2), cf * CF(0, 0.65, 2.4), c, M.WoodPlanks)
	local lid = if open then cf * CF(1.4, 0.3, 0.2) * ANG(0, 0.35, 1.3) else cf * CF(0, 1.5, 0)
	d(ctx, V(2.4, 0.25, 6.6), lid, Palette.shade(c, 1.1), M.WoodPlanks)
	d(ctx, V(2.45, 0.3, 0.3), cf * CF(0, 1.1, -2.2), IRON, M.CorrodedMetal)
	d(ctx, V(1.75, 0.3, 0.3), cf * CF(0, 1.1, 2.4), IRON, M.CorrodedMetal)
	if open then
		d(ctx, V(2.0, 0.12, 5.8), cf * CF(0, 1.42, 0.2), SOCKET, M.Slate)
		P.skull(ctx, cf * CF(0, 1.3, -2.3) * ANG(-1.1, 0, 0), 0.85, true)
	end
end

-- ------------------------------------------------------------------ iron
function P.chain(ctx, top: Vector3, bottom: Vector3, link: number?)
	local L = link or 1.5
	local len = (top - bottom).Magnitude
	local n = math.min(40, math.max(1, math.floor(len / (L * 0.8))))
	local c = j(ctx, IRON, 0.05)
	for i = 0, n - 1 do
		local p = top:Lerp(bottom, (i + 0.5) / n)
		local sz = if i % 2 == 0 then V(0.22, L, 0.55) else V(0.55, L, 0.22)
		d(ctx, sz, CFrame.lookAt(p, p + (bottom - top).Unit) * ANG(math.pi / 2, 0, 0), c, M.Metal)
	end
end

-- cage; hanging = y of the ceiling to hang from (or nil for a floor cage)
function P.cage(ctx, pos: Vector3, hangFrom: number?, prisoner: boolean?)
	local rng = ctx.rng
	local c = j(ctx, IRON, 0.06)
	local w, h = 3.6, 5.2
	local base = pos
	local rot = ANG(0, rng:angle(), 0)
	if hangFrom then
		rot = rot * ANG(rng:float(-0.06, 0.06), 0, rng:float(-0.06, 0.06))
	end
	local cf = CF(base) * rot
	local mk = if hangFrom then d else s
	mk(ctx, V(w, 0.3, w), cf * CF(0, 0.15, 0), c, M.CorrodedMetal)
	d(ctx, V(w, 0.3, w), cf * CF(0, h, 0), c, M.CorrodedMetal)
	d(ctx, V(1.4, 0.8, 1.4), cf * CF(0, h + 0.5, 0), c, M.CorrodedMetal)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			d(ctx, V(0.3, h, 0.3), cf * CF(x * (w / 2 - 0.15), h / 2, z * (w / 2 - 0.15)), c, M.Metal)
		end
	end
	for i = 1, 2 do
		local o = -w / 2 + i * w / 3
		d(ctx, V(0.16, h, 0.16), cf * CF(o, h / 2, -w / 2 + 0.1), c, M.Metal)
		d(ctx, V(0.16, h, 0.16), cf * CF(o, h / 2, w / 2 - 0.1), c, M.Metal)
		d(ctx, V(0.16, h, 0.16), cf * CF(-w / 2 + 0.1, h / 2, o), c, M.Metal)
		d(ctx, V(0.16, h, 0.16), cf * CF(w / 2 - 0.1, h / 2, o), c, M.Metal)
	end
	d(ctx, V(w + 0.1, 0.2, w + 0.1), cf * CF(0, h * 0.55, 0), c, M.Metal)
	if prisoner then
		P.skull(ctx, cf * CF(0.4, 0.3, 0.3) * ANG(0.3, 1, 0.2), 0.9)
		P.bone(ctx, cf * CF(-0.5, 0.3, 0) * ANG(0, 0.5, 0), 1.8)
		P.bone(ctx, cf * CF(0.3, 0.3, -0.8) * ANG(0, 2.1, 0), 1.5)
		limb(ctx, cf * V(-0.8, 0.4, 0.8), cf * V(-0.3, 1.9, 1.3), 0.3, BONE)
	end
	if hangFrom then
		P.chain(ctx, V(base.X, hangFrom, base.Z), base + V(0, h + 0.9, 0))
	end
end

-- ------------------------------------------------------------------ cloth
-- banner hanging on a wall. cf: top-centre of the rod, LookVector away from the wall
function P.banner(ctx, cf: CFrame, w: number, h: number, color: Color3, emblem: Color3?)
	local rng = ctx.rng
	d(ctx, V(w + 1.2, 0.3, 0.3), cf * CF(0, 0, -0.55), IRON, M.Metal)
	d(ctx, V(0.3, 0.3, 0.6), cf * CF(-w / 2 - 0.4, 0, -0.3), IRON, M.Metal)
	d(ctx, V(0.3, 0.3, 0.6), cf * CF(w / 2 + 0.4, 0, -0.3), IRON, M.Metal)
	local c = K.j(ctx, color, 0.1)
	local main = h * rng:float(0.62, 0.8)
	d(ctx, V(w, main, 0.14), cf * CF(0, -main / 2 - 0.1, -0.7), c, M.Fabric)
	-- torn tails
	local tails = 3
	for i = 1, tails do
		local tw = w / tails
		local tl = (h - main) * rng:float(0.3, 1.1)
		d(ctx, V(tw - 0.1, tl, 0.12), cf * CF(-w / 2 + (i - 0.5) * tw, -main - tl / 2, -0.7 + (i % 2) * 0.03), Palette.shade(c, rng:float(0.85, 1)), M.Fabric)
	end
	-- trim + emblem
	d(ctx, V(w + 0.1, 0.35, 0.18), cf * CF(0, -0.4, -0.72), GOLD, M.Fabric)
	if emblem then
		-- a skull sigil over two crossed bones
		local ey = -main * 0.42
		local k = w * 0.36
		d(ctx, V(k, k * 0.9, 0.06), cf * CF(0, ey + k * 0.2, -0.8), emblem, M.Fabric)
		d(ctx, V(k * 0.62, k * 0.34, 0.06), cf * CF(0, ey - k * 0.38, -0.8), emblem, M.Fabric)
		d(ctx, V(k * 0.24, k * 0.22, 0.08), cf * CF(-k * 0.2, ey + k * 0.2, -0.81), c, M.Fabric)
		d(ctx, V(k * 0.24, k * 0.22, 0.08), cf * CF(k * 0.2, ey + k * 0.2, -0.81), c, M.Fabric)
		d(ctx, V(w * 0.8, w * 0.07, 0.05), cf * CF(0, ey - k * 0.9, -0.79) * ANG(0, 0, 0.55), emblem, M.Fabric)
		d(ctx, V(w * 0.8, w * 0.07, 0.05), cf * CF(0, ey - k * 0.9, -0.785) * ANG(0, 0, -0.55), emblem, M.Fabric)
	end
end

function P.cobweb(ctx, corner: Vector3, a: Vector3, b: Vector3, size: number)
	-- a, b: unit directions along the two surfaces away from the corner
	local mid = corner + (a + b) * (size * 0.35)
	local span = (a - b).Unit
	local nrm = a:Cross(b).Unit
	local cf = CFrame.fromMatrix(mid, span, nrm)
	d(ctx, V(size * 1.3, 0.04, size * 0.5), cf, WEB, M.Fabric, { Transparency = 0.55, CastShadow = false })
	d(ctx, V(size * 0.8, 0.04, size * 0.3), cf * CF(0, 0.02, size * 0.12), WEB, M.Fabric, { Transparency = 0.45, CastShadow = false })
	limb(ctx, corner + a * size, corner + b * size * 0.9, 0.05, WEB, M.Fabric)
end

-- ------------------------------------------------------------------ statues
function P.knight(ctx, cf: CFrame, sc: number?, opts)
	opts = opts or {}
	local k = sc or 1
	local th = ctx.theme
	local stone = opts.color or K.pj(ctx, th.statue or th.trim or th.wall, 0.04)
	local mat = opts.mat or M.Marble
	local plinthH = (opts.plinth or 1.8) * k
	if opts.plinth ~= 0 then
		s(ctx, V(4.2, plinthH, 4.4) * V(k, 1, k), cf * CF(0, plinthH / 2, 0), Palette.shade(stone, 0.85), th.trimMat or mat)
		d(ctx, V(4.8, 0.5 * k, 5) * V(k, 1, k), cf * CF(0, 0.25 * k, 0), Palette.shade(stone, 0.8), th.trimMat or mat)
	end
	local b = cf * CF(0, plinthH, 0)
	local function box(x, y, z, sx, sy, sz, rx, ry, rz, c)
		d(ctx, V(sx, sy, sz) * k, b * CF(x * k, y * k, z * k) * ANG(rx or 0, ry or 0, rz or 0), c or stone, mat)
	end
	-- kneeling legs: left knee down, right knee up (front is -Z)
	box(-0.5, 0.35, 0.9, 0.8, 0.7, 1.8, 0, 0, 0) -- left shin on the ground (back)
	box(-0.5, 1.0, 0.1, 0.85, 1.6, 0.9, 0.25, 0, 0) -- left thigh (vertical-ish)
	box(0.5, 1.45, -0.7, 0.85, 0.8, 1.7, 0, 0, 0) -- right thigh (forward)
	box(0.5, 0.75, -1.45, 0.8, 1.5, 0.8) -- right shin
	box(0.5, 0.15, -1.75, 0.9, 0.3, 1.3) -- right foot
	-- torso + armour
	box(0, 2.9, 0.1, 2.1, 2.4, 1.3, -0.12, 0, 0)
	box(0, 2.2, 0.15, 2.3, 0.4, 1.45, -0.12, 0, 0, Palette.shade(stone, 0.9)) -- belt
	box(-1.25, 3.7, 0.05, 1.0, 0.8, 1.4, 0, 0, 0.25) -- pauldrons
	box(1.25, 3.7, 0.05, 1.0, 0.8, 1.4, 0, 0, -0.25)
	-- head bowed
	box(0, 4.55, -0.25, 1.15, 1.25, 1.2, 0.4, 0, 0)
	box(0, 5.2, -0.1, 0.25, 0.5, 1.2, 0.4, 0, 0) -- crest
	box(0, 4.5, -0.85, 0.8, 0.12, 0.05, 0.4, 0, 0, Palette.shade(stone, 0.5)) -- visor slit
	-- arms to the pommel
	box(-0.85, 3.1, -0.55, 0.55, 0.55, 1.5, 0.6, 0.35, 0)
	box(0.85, 3.1, -0.55, 0.55, 0.55, 1.5, 0.6, -0.35, 0)
	box(0, 2.75, -1.25, 0.8, 0.5, 0.5)
	-- sword planted point down
	box(0, 1.45, -1.35, 0.4, 2.8, 0.14, 0, 0, 0, Palette.shade(stone, 1.08))
	box(0, 2.9, -1.35, 1.8, 0.26, 0.3)
	box(0, 3.25, -1.35, 0.26, 0.6, 0.26)
	-- cape
	box(0, 2.3, 0.95, 2.2, 3.4, 0.3, 0.18, 0, 0, Palette.shade(stone, 0.93))
	if opts.candles then
		P.candles(ctx, (cf * CF(1.6 * k, plinthH, -1.6 * k)).Position, 3, 0.5, true)
	end
end

-- ------------------------------------------------------------------ fire
function P.candles(ctx, pos: Vector3, n: number, r: number, light: boolean?, range: number?)
	local rng = ctx.rng
	local tallest = nil
	local th = 0
	for i = 1, n do
		local p = pos + V(rng:float(-r, r), 0, rng:float(-r, r))
		local h = rng:float(0.4, 1.6)
		local w = rng:float(0.28, 0.46)
		d(ctx, V(w, h, w), CF(p + V(0, h / 2, 0)), j(ctx, WAX, 0.05), M.Limestone)
		d(ctx, V(w + 0.2, 0.12, w + 0.16), CF(p + V(0.03, 0.06, 0.02)), j(ctx, WAX, 0.04), M.Limestone)
		if rng:chance(0.4) then
			d(ctx, V(0.1, h * 0.5, 0.1), CF(p + V(w / 2, h * 0.6, 0)), j(ctx, WAX, 0.03), M.Limestone)
		end
		local f = d(ctx, V(0.14, 0.26, 0.14), CF(p + V(0, h + 0.15, 0)), rgb(255, 196, 110), M.Neon)
		if h > th then
			th = h
			tallest = f
		end
	end
	if light and tallest then
		K.light(ctx, tallest, rgb(255, 170, 90), range or 14, 1.2)
	end
	return tallest
end

function P.candelabra(ctx, pos: Vector3, h: number?)
	local hh = h or 6
	local c = j(ctx, IRON, 0.06)
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3
		limb(ctx, pos + V(math.cos(a) * 1.1, 0.1, math.sin(a) * 1.1), pos + V(0, 0.9, 0), 0.2, c, M.Metal)
	end
	d(ctx, V(0.28, hh, 0.28), CF(pos + V(0, hh / 2, 0)), c, M.Metal)
	d(ctx, V(2.6, 0.2, 0.2), CF(pos + V(0, hh - 0.4, 0)), c, M.Metal)
	d(ctx, V(0.2, 0.2, 2.6), CF(pos + V(0, hh - 0.4, 0)), c, M.Metal)
	local top = nil
	for _, o in { V(0, 0, 0), V(1.2, 0, 0), V(-1.2, 0, 0), V(0, 0, 1.2), V(0, 0, -1.2) } do
		local ch = if o.Magnitude < 0.1 then 1.2 else 0.8
		d(ctx, V(0.5, 0.2, 0.5), CF(pos + o + V(0, hh - 0.2, 0)), c, M.Metal)
		d(ctx, V(0.3, ch, 0.3), CF(pos + o + V(0, hh + ch / 2 - 0.1, 0)), j(ctx, WAX, 0.04), M.Limestone)
		local f = d(ctx, V(0.14, 0.28, 0.14), CF(pos + o + V(0, hh + ch + 0.05, 0)), rgb(255, 196, 110), M.Neon)
		if o.Magnitude < 0.1 then
			top = f
		end
	end
	K.light(ctx, top, rgb(255, 165, 85), 20, 1.5)
end

function P.brazier(ctx, pos: Vector3, sc: number?, shadows: boolean?, color: Color3?)
	local k = sc or 1
	local c = j(ctx, IRON, 0.05)
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3 + 0.4
		limb(ctx, pos + V(math.cos(a) * 1.6 * k, 0.1, math.sin(a) * 1.6 * k), pos + V(math.cos(a) * 0.9 * k, 3.1 * k, math.sin(a) * 0.9 * k), 0.3 * k, c, M.Metal)
	end
	s(ctx, V(0.9, 3, 0.9) * k, CF(pos + V(0, 1.5 * k, 0)), c, M.Metal)
	d(ctx, V(2.2, 0.6, 2.2) * k, CF(pos + V(0, 3.1 * k, 0)), c, M.CorrodedMetal)
	d(ctx, V(3, 0.8, 3) * k, CF(pos + V(0, 3.7 * k, 0)), c, M.CorrodedMetal)
	for _, o in { V(1.5, 0, 0), V(-1.5, 0, 0), V(0, 0, 1.5), V(0, 0, -1.5) } do
		d(ctx, V(0.3, 0.6, 0.3) * k, CF(pos + o * k + V(0, 4.3 * k, 0)), c, M.Metal)
	end
	local glow = color or rgb(255, 120, 40)
	local coal = d(ctx, V(2.4, 0.4, 2.4) * k, CF(pos + V(0, 4.15 * k, 0)), glow, M.Neon)
	local e = Kit.fire(coal, color or rgb(255, 140, 50), 1.1 * k)
	e.Rate = 26
	K.light(ctx, coal, if color then color else rgb(255, 140, 60), 34 * math.sqrt(k), 2.2, shadows)
	return coal
end

-- wall torch in an iron sconce. pos: point on the wall surface, n: into the room
function P.torch(ctx, pos: Vector3, n: Vector3, color: Color3?)
	local c = j(ctx, IRON, 0.05)
	local cf = CFrame.lookAt(pos, pos + n)
	d(ctx, V(1.1, 1.8, 0.25), cf * CF(0, -0.2, -0.1), c, M.CorrodedMetal)
	d(ctx, V(0.3, 0.3, 1.5), cf * CF(0, -0.7, -0.8) * ANG(0.5, 0, 0), c, M.Metal)
	d(ctx, V(0.8, 0.5, 0.8), cf * CF(0, 0, -1.35), c, M.Metal)
	d(ctx, V(0.34, 1.5, 0.34), cf * CF(0, 0.45, -1.4) * ANG(-0.18, 0, 0), j(ctx, WOOD, 0.1), M.Wood)
	d(ctx, V(0.5, 0.45, 0.5), cf * CF(0, 1.2, -1.55) * ANG(-0.18, 0, 0), rgb(40, 28, 20), M.Fabric)
	return K.flame(ctx, (cf * CF(0, 1.35, -1.6)).Position, 1, color, true, 24, 1.7)
end

function P.chandelier(ctx, top: Vector3, drop: number, r: number?)
	local rr = r or 4
	local c = j(ctx, IRON, 0.05)
	local ring = top - V(0, drop, 0)
	P.chain(ctx, top, ring + V(0, 2.5, 0), 2)
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		limb(ctx, ring + V(0, 2.5, 0), ring + V(math.cos(a) * rr, 0, math.sin(a) * rr), 0.15, c, M.Metal)
	end
	local seg = 8
	local mid = nil
	for i = 0, seg - 1 do
		local a0 = i / seg * math.pi * 2
		local a1 = (i + 1) / seg * math.pi * 2
		local p0 = ring + V(math.cos(a0) * rr, 0, math.sin(a0) * rr)
		local p1 = ring + V(math.cos(a1) * rr, 0, math.sin(a1) * rr)
		limb(ctx, p0, p1, 0.3, c, M.Metal)
		d(ctx, V(0.35, 0.9, 0.35), CF(p0 + V(0, 0.55, 0)), j(ctx, WAX, 0.04), M.Limestone)
		local f = d(ctx, V(0.16, 0.3, 0.16), CF(p0 + V(0, 1.15, 0)), rgb(255, 196, 110), M.Neon)
		if i == 0 then
			mid = f
		end
	end
	local core = d(ctx, V(0.3, 0.3, 0.3), CF(ring + V(0, 1, 0)), rgb(255, 196, 110), M.Neon, { Transparency = 1 })
	K.light(ctx, core, rgb(255, 165, 90), 38, 1.9)
	local _ = mid
end

-- ------------------------------------------------------------------ ruins
function P.rubble(ctx, pos: Vector3, r: number, n: number, pal, mat)
	local rng = ctx.rng
	local th = ctx.theme
	for i = 1, n do
		local sz = rng:float(0.6, 2.6)
		local p = pos + V(rng:float(-r, r), sz * 0.3, rng:float(-r, r))
		local size = V(sz * rng:float(0.8, 1.5), sz * rng:float(0.5, 1), sz)
		local cf = CF(p) * ANG(rng:float(-0.5, 0.5), rng:angle(), rng:float(-0.5, 0.5))
		if sz > 2.2 then
			s(ctx, size, cf, K.pj(ctx, pal or th.wall, 0.1), mat or th.wallMat or th.mat)
		else
			d(ctx, size, cf, K.pj(ctx, pal or th.wall, 0.1), mat or th.wallMat or th.mat)
		end
	end
end

function P.brokenColumn(ctx, pos: Vector3, w: number, h: number)
	local rng = ctx.rng
	local th = ctx.theme
	K.pillar(ctx, pos, w, h, { broken = h, noFlutes = w < 5 })
	-- fallen drums
	local a = rng:angle()
	local dir = V(math.cos(a), 0, math.sin(a))
	for i = 1, rng:int(1, 3) do
		local p = pos + dir * (w + 1 + i * (w * 0.9)) + V(rng:float(-1, 1), w / 2 - 0.3, rng:float(-1, 1))
		s(ctx, V(w * 0.95, w * 0.95, w * rng:float(0.7, 1.2)), CF(p) * CFrame.lookAt(V(), dir) * ANG(0, 0, rng:float(-0.3, 0.3)), K.pj(ctx, th.wall, 0.08), th.wallMat or th.mat)
	end
	P.rubble(ctx, pos + dir * (w * 0.8), w * 0.6, 4)
end

-- ------------------------------------------------------------------ furniture
function P.altar(ctx, cf: CFrame, cloth: Color3?)
	local th = ctx.theme
	local stone = K.pj(ctx, th.trim or th.wall, 0.04)
	local mat = th.trimMat or M.Limestone
	s(ctx, V(8, 0.8, 4.6), cf * CF(0, 0.4, 0), Palette.shade(stone, 0.9), mat)
	s(ctx, V(6.4, 3, 3.2), cf * CF(0, 2.3, 0), stone, mat)
	d(ctx, V(7, 0.6, 3.8), cf * CF(0, 4.1, 0), Palette.shade(stone, 1.06), mat)
	for _, x in { -2.2, 0, 2.2 } do
		d(ctx, V(1.4, 2.2, 0.2), cf * CF(x, 2.3, -1.65), Palette.shade(stone, 0.84), mat)
	end
	local cl = cloth or th.accent
	d(ctx, V(2.2, 0.1, 3.9), cf * CF(0, 4.45, 0), cl, M.Fabric)
	d(ctx, V(2.2, 2.4, 0.1), cf * CF(0, 3.3, -1.97), cl, M.Fabric)
	d(ctx, V(2.3, 0.2, 0.12), cf * CF(0, 2.1, -1.98), GOLD, M.Fabric)
	P.candles(ctx, (cf * CF(-2.6, 4.4, 0)).Position, 6, 0.7, true, 16)
	P.candles(ctx, (cf * CF(2.6, 4.4, 0)).Position, 5, 0.7, false)
	P.skull(ctx, cf * CF(0, 4.5, 0.4) * ANG(0, math.pi, 0), 1.1)
	-- open book
	d(ctx, V(0.9, 0.18, 1.3), cf * CF(-0.9, 4.55, -0.6) * ANG(0, 0, 0.12), rgb(210, 196, 160), M.Fabric)
	d(ctx, V(0.9, 0.18, 1.3), cf * CF(-1.8, 4.55, -0.6) * ANG(0, 0, -0.12), rgb(206, 190, 150), M.Fabric)
end

function P.weaponRack(ctx, cf: CFrame)
	local rng = ctx.rng
	local w = j(ctx, WOOD, 0.1)
	for _, x in { -2.4, 2.4 } do
		s(ctx, V(0.5, 5, 0.5), cf * CF(x, 2.5, 0), w, M.Wood)
	end
	d(ctx, V(5.4, 0.4, 0.4), cf * CF(0, 4.2, 0), w, M.Wood)
	d(ctx, V(5.4, 0.4, 0.4), cf * CF(0, 1.2, -0.3), w, M.Wood)
	for i = 1, 4 do
		local x = -2.4 + i * 0.96
		local kind = rng:int(1, 3)
		local lean = ANG(-0.14, 0, rng:float(-0.05, 0.05))
		if kind == 1 then -- sword
			d(ctx, V(0.3, 3.4, 0.1), cf * CF(x, 2.6, -0.2) * lean, rgb(150, 150, 156), M.Metal)
			d(ctx, V(1.1, 0.2, 0.2), cf * CF(x, 4.35, 0.0) * lean, IRON, M.Metal)
			d(ctx, V(0.2, 0.8, 0.2), cf * CF(x, 4.85, 0.05) * lean, WOOD_D, M.Fabric)
		elseif kind == 2 then -- spear
			d(ctx, V(0.2, 5.6, 0.2), cf * CF(x, 2.9, -0.1) * lean, w, M.Wood)
			d(ctx, V(0.35, 1, 0.12), cf * CF(x, 6.1, 0.2) * lean, rgb(140, 140, 146), M.Metal)
		else -- axe
			d(ctx, V(0.22, 4, 0.22), cf * CF(x, 2.2, -0.2) * lean, w, M.Wood)
			d(ctx, V(0.14, 1, 1.1), cf * CF(x, 3.9, -0.5) * lean, rgb(130, 130, 136), M.Metal)
		end
	end
end

function P.bookshelf(ctx, cf: CFrame, w: number?, h: number?)
	local rng = ctx.rng
	local W, H = w or 6, h or 9
	local wood = j(ctx, WOOD_D, 0.08)
	s(ctx, V(W, H, 0.4), cf * CF(0, H / 2, 0.8), Palette.shade(wood, 0.8), M.WoodPlanks)
	s(ctx, V(0.4, H, 2), cf * CF(-W / 2, H / 2, 0), wood, M.WoodPlanks)
	s(ctx, V(0.4, H, 2), cf * CF(W / 2, H / 2, 0), wood, M.WoodPlanks)
	local shelves = math.floor(H / 2.2)
	for i = 0, shelves do
		local y = 0.2 + i * (H - 0.4) / shelves
		d(ctx, V(W, 0.3, 2), cf * CF(0, y, 0), wood, M.WoodPlanks)
		if i < shelves then
			local x = -W / 2 + 0.3
			while x < W / 2 - 0.6 do
				local bw = rng:float(0.5, 1.4)
				if x + bw > W / 2 - 0.3 then
					break
				end
				if rng:chance(0.82) then
					local bh = rng:float(1.1, 1.8)
					local col = rng:pick({ rgb(92, 34, 30), rgb(52, 60, 44), rgb(70, 52, 34), rgb(40, 42, 60), rgb(110, 88, 60), rgb(64, 30, 40) })
					d(ctx, V(bw - 0.06, bh, 1.5), cf * CF(x + bw / 2, y + 0.15 + bh / 2, 0.1) * ANG(0, 0, if rng:chance(0.15) then 0.25 else 0), j(ctx, col, 0.1), M.Fabric)
				end
				x += bw
			end
		end
	end
	if rng:chance(0.5) then
		P.cobweb(ctx, (cf * CF(W / 2 - 0.2, H - 0.2, 0.6)).Position, -cf.RightVector, -cf.UpVector, 2)
	end
end

function P.spikes(ctx, pos: Vector3, r: number, n: number)
	local rng = ctx.rng
	for i = 1, n do
		local p = pos + V(rng:float(-r, r), 0, rng:float(-r, r))
		local h = rng:float(2, 4.5)
		d(ctx, V(0.45, h, 0.45), CF(p + V(0, h / 2, 0)) * ANG(rng:float(-0.2, 0.2), math.pi / 4, rng:float(-0.2, 0.2)), j(ctx, RUST, 0.1), M.CorrodedMetal)
		d(ctx, V(0.2, 0.9, 0.2), CF(p + V(0, h + 0.2, 0)) * ANG(0, math.pi / 4, 0), j(ctx, IRON, 0.1), M.Metal)
	end
end

function P.puddle(ctx, pos: Vector3, r: number, color: Color3?)
	local rng = ctx.rng
	local c = color or rgb(40, 50, 58)
	for i = 1, 3 do
		local w = r * rng:float(0.6, 1.2)
		d(ctx, V(w * 2, 0.06, w * rng:float(1.2, 2)), CF(pos + V(rng:float(-r, r) * 0.4, 0.05 + i * 0.03, rng:float(-r, r) * 0.4)) * ANG(0, rng:angle(), 0), c, M.Glass, { Transparency = 0.3, CastShadow = false })
	end
end

function P.drip(ctx, top: Vector3, bottomY: number)
	local len = top.Y - bottomY
	if len < 2 then
		return
	end
	local rng = ctx.rng
	d(ctx, V(0.12, len, 0.12), CF(top.X, bottomY + len / 2, top.Z), rgb(150, 170, 190), M.Glass, { Transparency = 0.6, CastShadow = false })
	d(ctx, V(0.5, 0.8, 0.5), CF(top - V(0, 0.4, 0)), rgb(110, 120, 120), M.Rock)
	P.puddle(ctx, V(top.X, bottomY, top.Z), rng:float(0.8, 1.6), rgb(50, 62, 70))
end

-- roots crawling down a wall. top: start point on the wall, n: wall normal (into room)
function P.roots(ctx, top: Vector3, n: Vector3, len: number)
	local rng = ctx.rng
	local c = j(ctx, rgb(70, 52, 36), 0.1)
	local along = V(-n.Z, 0, n.X)
	local function vine(p: Vector3, remaining: number, t: number, depth: number)
		while remaining > 0 do
			local seg = math.min(remaining, rng:float(2.5, 5))
			local q = p + V(0, -seg, 0) + along * rng:float(-1.5, 1.5) + n * rng:float(-0.1, 0.25)
			limb(ctx, p, q, t, c, M.Wood)
			if depth < 2 and rng:chance(0.3) then
				vine(q, remaining * 0.5, t * 0.6, depth + 1)
			end
			p = q
			remaining -= seg
			t = math.max(0.2, t * 0.88)
		end
	end
	vine(top + n * 0.3, len, rng:float(0.5, 0.9), 0)
end

function P.moss(ctx, pos: Vector3, sx: number, sz: number, n: number?)
	local rng = ctx.rng
	for i = 1, n or 3 do
		local w = sx * rng:float(0.3, 0.7)
		local dd = sz * rng:float(0.3, 0.7)
		d(ctx, V(w, rng:float(0.1, 0.25), dd), CF(pos + V(rng:float(-sx, sx) * 0.3, 0.05 + i * 0.02, rng:float(-sz, sz) * 0.3)) * ANG(0, rng:float(-0.4, 0.4), 0), K.j(ctx, MOSS, 0.12), if rng:chance(0.5) then M.LeafyGrass else M.Grass)
	end
end

-- ------------------------------------------------------------------ caverns
function P.stalagmite(ctx, pos: Vector3, h: number, w: number, down: boolean?)
	local rng = ctx.rng
	local th = ctx.theme
	local n = 3
	for i = 0, n - 1 do
		local f = 1 - i / n
		local hh = h / n + 0.5
		local y = (i + 0.5) * h / n
		local p = if down then pos - V(0, y, 0) else pos + V(0, y, 0)
		local mk = if down or i > 0 then d else s
		mk(ctx, V(w * f, hh, w * f * rng:float(0.8, 1.1)), CF(p) * ANG(rng:float(-0.06, 0.06), rng:angle(), rng:float(-0.06, 0.06)), K.pj(ctx, th.rock or th.wall, 0.1), th.roughMat or M.Rock)
	end
end

function P.crystal(ctx, pos: Vector3, sc: number, color: Color3, light: boolean?)
	local rng = ctx.rng
	local th = ctx.theme
	d(ctx, V(2.2, 0.8, 2.2) * sc, CF(pos + V(0, 0.3 * sc, 0)) * ANG(0, rng:angle(), 0), K.pj(ctx, th.rock or th.wall, 0.1), M.Rock)
	local main = nil
	for i = 1, rng:int(3, 5) do
		local h = rng:float(2, 5.5) * sc * (if i == 1 then 1.3 else 1)
		local w = rng:float(0.6, 1.1) * sc
		local p = pos + V(rng:float(-0.8, 0.8) * sc, h * 0.4, rng:float(-0.8, 0.8) * sc)
		local c = d(ctx, V(w, h, w), CF(p) * ANG(rng:float(-0.45, 0.45), rng:angle(), rng:float(-0.45, 0.45)), Palette.shade(color, rng:float(0.8, 1.05)), M.Neon, { Transparency = 0.12 })
		if i == 1 then
			main = c
		end
	end
	if light and main then
		K.light(ctx, main, color, 20 * math.sqrt(sc), 1.4)
	end
end

function P.mushroom(ctx, pos: Vector3, sc: number, glow: Color3, light: boolean?)
	local rng = ctx.rng
	local k = sc
	local stem = rgb(190, 184, 160)
	local h = rng:float(4, 7) * k
	local lean = ANG(rng:float(-0.12, 0.12), rng:angle(), rng:float(-0.12, 0.12))
	local base = CF(pos) * lean
	s(ctx, V(1.1, h, 1.1) * V(k, 1, k), base * CF(0, h / 2, 0), j(ctx, stem, 0.06), M.Limestone)
	local cap = rng:pick({ rgb(70, 60, 80), rgb(60, 72, 70), rgb(84, 64, 56) })
	d(ctx, V(5.2, 1, 5.2) * k, base * CF(0, h + 0.2 * k, 0), j(ctx, cap, 0.08), M.Slate)
	d(ctx, V(3.4, 0.9, 3.4) * k, base * CF(0, h + 1.1 * k, 0), j(ctx, cap, 0.08), M.Slate)
	local g = d(ctx, V(4.8, 0.2, 4.8) * k, base * CF(0, h - 0.4 * k, 0), glow, M.Neon, { Transparency = 0.15 })
	for i = 1, 4 do
		d(ctx, V(0.5, 0.25, 0.5) * k, base * CF(rng:float(-1.8, 1.8) * k, h + 0.75 * k, rng:float(-1.8, 1.8) * k), Palette.shade(glow, 0.9), M.Neon)
	end
	if light then
		K.light(ctx, g, glow, 22 * math.sqrt(k), 1.3)
	end
end

function P.shrooms(ctx, pos: Vector3, r: number, n: number, glow: Color3, light: boolean?)
	local rng = ctx.rng
	local first = nil
	for i = 1, n do
		local p = pos + V(rng:float(-r, r), 0, rng:float(-r, r))
		local h = rng:float(0.4, 1.4)
		d(ctx, V(0.25, h, 0.25), CF(p + V(0, h / 2, 0)), rgb(186, 180, 160), M.Limestone)
		local cw = rng:float(0.6, 1.3)
		local c = d(ctx, V(cw, 0.3, cw), CF(p + V(0, h + 0.1, 0)), Palette.shade(glow, rng:float(0.8, 1.05)), M.Neon)
		first = first or c
	end
	if light and first then
		K.light(ctx, first, glow, 14, 1)
	end
end

-- ------------------------------------------------------------------ mines
function P.timberFrame(ctx, pos: Vector3, span: number, h: number, alongX: boolean)
	local rng = ctx.rng
	local w = j(ctx, WOOD, 0.1)
	local across = if alongX then V(0, 0, 1) else V(1, 0, 0)
	local post = V(1.2, h, 1.2)
	for _, sg in { -1, 1 } do
		s(ctx, post, CF(pos + across * (sg * span / 2) + V(0, h / 2, 0)) * ANG(0, 0, rng:float(-0.03, 0.03)), j(ctx, WOOD, 0.1), M.Wood)
		limb(ctx, pos + across * (sg * span / 2) + V(0, h - 3.2, 0), pos + across * (sg * (span / 2 - 2.6)) + V(0, h - 0.6, 0), 0.6, w, M.Wood)
	end
	local beam = if alongX then V(1.4, 1.4, span + 2) else V(span + 2, 1.4, 1.4)
	d(ctx, beam, CF(pos + V(0, h + 0.5, 0)) * ANG(if rng:chance(0.2) then 0.04 else 0, 0, 0), w, M.Wood)
end

function P.rails(ctx, a: Vector3, b: Vector3)
	local dir = (b - a)
	local len = dir.Magnitude
	local u = dir.Unit
	local side = V(-u.Z, 0, u.X)
	local cf = CFrame.lookAt((a + b) / 2, b)
	for _, sg in { -1, 1 } do
		d(ctx, V(0.25, 0.3, len), cf * CF(sg * 1.2, 0.35, 0), rgb(70, 64, 60), M.Metal)
	end
	local n = math.floor(len / 2.4)
	for i = 0, n do
		local p = a + u * (i * 2.4 + 0.6)
		d(ctx, V(3.4, 0.25, 0.7), CFrame.lookAt(p + V(0, 0.12, 0), p + V(0, 0.12, 0) + u) * ANG(0, ctx.rng:float(-0.06, 0.06), 0), j(ctx, WOOD_D, 0.1), M.Wood)
	end
	local _ = side
end

function P.minecart(ctx, cf: CFrame, ore: Color3?)
	local c = j(ctx, RUST, 0.1)
	s(ctx, V(3, 2, 4.4), cf * CF(0, 1.7, 0), c, M.CorrodedMetal)
	d(ctx, V(3.3, 0.3, 4.7), cf * CF(0, 2.75, 0), IRON, M.Metal)
	d(ctx, V(2.6, 0.3, 4.0), cf * CF(0, 2.6, 0), rgb(40, 36, 34), M.Slate)
	for _, x in { -1.4, 1.4 } do
		for _, z in { -1.4, 1.4 } do
			d(ctx, V(0.3, 1.1, 1.1), cf * CF(x, 0.55, z), IRON, M.Metal)
		end
	end
	if ore then
		for i = 1, 4 do
			d(ctx, V(0.8, 0.8, 0.8), cf * CF(ctx.rng:float(-0.8, 0.8), 2.9, ctx.rng:float(-1.4, 1.4)) * ANG(ctx.rng:angle(), ctx.rng:angle(), 0), ore, M.Neon)
		end
	end
end

function P.lanternPost(ctx, pos: Vector3, color: Color3?)
	local w = j(ctx, WOOD, 0.1)
	s(ctx, V(0.6, 7, 0.6), CF(pos + V(0, 3.5, 0)), w, M.Wood)
	d(ctx, V(2.2, 0.35, 0.35), CF(pos + V(0.8, 6.8, 0)), w, M.Wood)
	d(ctx, V(0.9, 0.2, 0.9), CF(pos + V(1.6, 6.2, 0)), IRON, M.Metal)
	local l = d(ctx, V(0.6, 0.8, 0.6), CF(pos + V(1.6, 5.7, 0)), color or rgb(255, 190, 110), M.Neon)
	d(ctx, V(0.9, 0.2, 0.9), CF(pos + V(1.6, 5.2, 0)), IRON, M.Metal)
	K.light(ctx, l, color or rgb(255, 170, 90), 22, 1.4)
end

-- ------------------------------------------------------------------ forge
function P.anvil(ctx, cf: CFrame)
	s(ctx, V(1.8, 2, 1.8), cf * CF(0, 1, 0), j(ctx, WOOD_D, 0.1), M.Wood)
	d(ctx, V(1.2, 0.6, 1), cf * CF(0, 2.3, 0), IRON, M.Metal)
	d(ctx, V(2.6, 0.8, 1.2), cf * CF(0, 3, 0), j(ctx, IRON, 0.05), M.Metal)
	d(ctx, V(0.9, 0.5, 0.6), cf * CF(1.7, 3.1, 0), j(ctx, IRON, 0.05), M.Metal)
	d(ctx, V(0.3, 0.3, 1.6), cf * CF(-0.4, 3.55, 0.1) * ANG(0, 0.5, 0), WOOD_D, M.Wood)
	d(ctx, V(0.7, 0.5, 0.5), cf * CF(-0.4, 3.6, -0.6) * ANG(0, 0.5, 0), IRON, M.Metal)
end

function P.forge(ctx, cf: CFrame, glow: Color3)
	local th = ctx.theme
	local st = K.pj(ctx, th.trim or th.wall, 0.05)
	s(ctx, V(8, 5, 5), cf * CF(0, 2.5, 0), st, th.trimMat or M.Brick)
	d(ctx, V(8.6, 0.8, 5.6), cf * CF(0, 5.2, 0), Palette.shade(st, 0.9), th.trimMat or M.Brick)
	local mouth = d(ctx, V(4, 2.2, 0.3), cf * CF(0, 2.2, -2.45), glow, M.Neon)
	d(ctx, V(5, 0.6, 0.6), cf * CF(0, 3.6, -2.6), IRON, M.Metal)
	s(ctx, V(3.4, 12, 3.4), cf * CF(0, 11, 0.6), Palette.shade(st, 0.95), th.trimMat or M.Brick)
	local e = Kit.fire(mouth, glow, 0.9)
	e.Rate = 16
	K.light(ctx, mouth, rgb(255, 120, 50), 30, 2.2)
	P.anvil(ctx, cf * CF(0, 0, -6) * ANG(0, 0.3, 0))
end

function P.cauldron(ctx, pos: Vector3, glow: Color3)
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3
		limb(ctx, pos + V(math.cos(a) * 1.6, 0, math.sin(a) * 1.6), pos + V(math.cos(a) * 1.2, 1.6, math.sin(a) * 1.2), 0.3, IRON, M.Metal)
	end
	s(ctx, V(3.4, 2, 3.4), CF(pos + V(0, 2.4, 0)), j(ctx, IRON, 0.05), M.CorrodedMetal)
	d(ctx, V(3.8, 0.4, 3.8), CF(pos + V(0, 3.5, 0)), IRON, M.Metal)
	local g = d(ctx, V(3, 0.2, 3), CF(pos + V(0, 3.62, 0)), glow, M.Neon)
	K.light(ctx, g, glow, 16, 1.4)
end

-- ------------------------------------------------------------------ monuments
-- the Pit Warden's throne (front = -Z). k ~ 2.5
function P.throne(ctx, cf: CFrame, k: number, glow: Color3)
	local th = ctx.theme
	local st = K.pj(ctx, th.trim or th.wall, 0.04)
	local dark = Palette.shade(st, 0.7)
	local mat = th.trimMat or M.Basalt
	local function box(x, y, z, sx, sy, sz, c, solid, m)
		local f = if solid then s else d
		return f(ctx, V(sx, sy, sz) * k, cf * CF(x * k, y * k, z * k), c or st, m or mat)
	end
	box(0, 1.2, 0, 7, 2.4, 6, dark, true)
	box(0, 2.9, 0.4, 5.6, 1, 4.6, st, true)
	box(0, 8, 2.4, 6, 10, 1.4, st, true)
	box(0, 13.6, 2.4, 3.6, 1.6, 1.2, dark)
	for _, x in { -2.3, 2.3 } do
		box(x, 4.4, 0.3, 1, 2.4, 4.6, dark, true)
		box(x, 5.8, -1.6, 1.4, 0.8, 1.4, st)
		P.skull(ctx, cf * CF(x * k, 6.2 * k, -1.6 * k) * ANG(0, 0, 0), 0.9 * k)
		-- spikes along the back
		box(x * 1.35, 12.5, 2.4, 0.8, 7, 0.8, dark)
		box(x * 1.35, 16.6, 2.4, 0.4, 1.6, 0.4, dark)
	end
	box(0, 15.6, 2.4, 0.8, 3.2, 0.8, dark)
	-- glowing eye-rune in the backrest
	box(0, 9.6, 1.6, 2.4, 2.4, 0.12, glow, false, M.Neon)
	d(ctx, V(1.4, 1.4, 0.14) * k, cf * CF(0, 9.6 * k, 1.58 * k) * ANG(0, 0, math.pi / 4), dark, mat)
	box(0, 9.6, 1.55, 0.4, 1.2, 0.12, glow, false, M.Neon)
	box(0, 7, 1.6, 0.35, 2.4, 0.12, glow, false, M.Neon)
	-- chains hanging from the arms
	P.chain(ctx, (cf * CF(-2.3 * k, 5 * k, -1.2 * k)).Position, (cf * CF(-2.6 * k, 0.4, -2.6 * k)).Position, 1.2)
	P.chain(ctx, (cf * CF(2.3 * k, 5 * k, -1.2 * k)).Position, (cf * CF(2.6 * k, 0.4, -2.6 * k)).Position, 1.2)
end

-- tall rune obelisk
function P.obelisk(ctx, pos: Vector3, h: number, glow: Color3)
	local th = ctx.theme
	local st = K.pj(ctx, th.trim or th.wall, 0.05)
	local mat = th.trimMat or M.Basalt
	s(ctx, V(5, 1.6, 5), CF(pos + V(0, 0.8, 0)), Palette.shade(st, 0.85), mat)
	s(ctx, V(3, h, 3), CF(pos + V(0, 1.6 + h / 2, 0)), st, mat)
	d(ctx, V(2, 2, 2), CF(pos + V(0, 1.6 + h + 0.6, 0)) * ANG(0, math.pi / 4, 0), st, mat)
	for i = 0, 3 do
		local a = i * math.pi / 2
		local n = V(math.sin(a), 0, math.cos(a))
		local rc = d(ctx, if math.abs(n.X) > 0.5 then V(0.1, h * 0.6, 0.4) else V(0.4, h * 0.6, 0.1), CF(pos + n * 1.53 + V(0, 1.6 + h * 0.5, 0)), glow, M.Neon)
		if i == 0 then
			K.light(ctx, rc, glow, 18, 1.2)
		end
	end
end

-- wooden bench (cathedral pews)
function P.pew(ctx, cf: CFrame, len: number, broken: boolean?)
	local w = j(ctx, WOOD_D, 0.1)
	local tilt = if broken then ANG(ctx.rng:float(-0.2, 0.2), 0, ctx.rng:float(-0.25, 0.25)) else CF()
	s(ctx, V(len, 0.4, 1.6), cf * CF(0, 1.6, 0) * tilt, w, M.WoodPlanks)
	d(ctx, V(len, 1.8, 0.3), cf * CF(0, 2.6, 0.8) * tilt, Palette.shade(w, 0.92), M.WoodPlanks)
	for _, x in { -len / 2 + 0.4, len / 2 - 0.4 } do
		d(ctx, V(0.4, 1.6, 1.6), cf * CF(x, 0.8, 0), w, M.WoodPlanks)
	end
end

function P.crates(ctx, cf: CFrame)
	local rng = ctx.rng
	local W = S.World
	local n = rng:int(1, 3)
	for i = 1, n do
		local o = cf * CF(rng:float(-1.5, 1.5) * i, 0, rng:float(-1.5, 1.5))
		if rng:chance(0.5) then
			W.barrel(ctx.geo, o * ANG(0, rng:angle(), 0))
		else
			local sz = rng:float(2.2, 3.2)
			W.crate(ctx.geo, o * ANG(0, rng:angle(), 0), sz)
			if rng:chance(0.35) then
				W.crate(ctx.geo, o * CF(0, sz, 0) * ANG(0, rng:angle(), 0), sz * 0.8)
			end
		end
	end
end

return P
