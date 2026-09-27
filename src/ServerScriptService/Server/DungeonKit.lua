--!nonstrict
-- Low-level builders for the underground (WorldPit): a build context, jittered
-- stone colours, wall-local boxes, masonry walls with plinths / string courses /
-- pilasters / door frames, flagstone floors, stepped vaults, pillars, stepped
-- arches, stairs with smooth invisible ramps.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Kit = require(Shared.Kit)
local Palette = require(Shared.Palette)

local K = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local UP = V(0, 1, 0)

-- ------------------------------------------------------------------ context
-- ctx = {folder, geo, dec, rng, theme, n, lights, shadows}
function K.context(folder: Instance, rng, theme)
	local ctx = {
		folder = folder,
		geo = Kit.folder("Structure", folder),
		dec = Kit.folder("Decor", folder),
		lit = Kit.folder("Lights", folder),
		rng = rng,
		theme = theme,
		n = 0,
		lights = 0,
		shadows = 0,
		maxShadows = 8,
	}
	return ctx
end

local function tick(ctx)
	ctx.n += 1
	if ctx.n % 1500 == 0 then
		task.wait()
	end
end
K.tick = tick

-- jittered colour (deterministic from the ctx rng)
function K.j(ctx, c: Color3, amt: number?): Color3
	return Palette.jitter(c, amt or 0.08, ctx.rng:float())
end

-- pick + jitter from a palette list
function K.pj(ctx, list, amt: number?): Color3
	return Palette.jitter(list[ctx.rng:int(1, #list)], amt or 0.08, ctx.rng:float())
end

function K.solid(ctx, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, props): Part
	tick(ctx)
	return Kit.part(ctx.geo, size, cf, color, mat or ctx.theme.mat, props)
end

function K.deco(ctx, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, props): Part
	tick(ctx)
	local p = Kit.deco(ctx.dec, size, cf, color, mat or ctx.theme.mat, props)
	if size.X < 2.5 and size.Y < 2.5 and size.Z < 2.5 then
		p.CastShadow = false
	end
	return p
end

-- invisible collision (smooth ramps, blockers)
function K.ghost(ctx, size: Vector3, cf: CFrame): Part
	tick(ctx)
	return Kit.part(ctx.geo, size, cf, Color3.new(0.3, 0.3, 0.3), Enum.Material.Slate, { Transparency = 1, CastShadow = false })
end

function K.wedge(ctx, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, props, solid: boolean?): WedgePart
	tick(ctx)
	local w = Kit.wedge(if solid then ctx.geo else ctx.dec, size, cf, color, mat or ctx.theme.mat, props)
	if not solid then
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
	end
	return w
end

-- axis-aligned box from min/max corners
function K.box(ctx, a: Vector3, b: Vector3, color: Color3, mat: Enum.Material?, solid: boolean?, props): Part
	local lo = V(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	local hi = V(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	local size = hi - lo
	if solid then
		return K.solid(ctx, size, CF((lo + hi) / 2), color, mat, props)
	end
	return K.deco(ctx, size, CF((lo + hi) / 2), color, mat, props)
end

-- ------------------------------------------------------------------ lights
local WARM = Color3.fromRGB(255, 150, 70)
K.WARM = WARM

function K.light(ctx, part: BasePart, color: Color3?, range: number?, brightness: number?, shadows: boolean?)
	local sh = false
	if shadows and ctx.shadows < ctx.maxShadows then
		sh = true
		ctx.shadows += 1
	end
	ctx.lights += 1
	return Kit.pointLight(part, color or WARM, range or 22, brightness or 1.6, sh)
end

function K.flame(ctx, pos: Vector3, scale: number?, color: Color3?, light: boolean?, range: number?, brightness: number?, shadows: boolean?)
	local s = scale or 1
	local core = K.deco(ctx, V(0.5, 0.75, 0.5) * s, CF(pos + V(0, 0.3 * s, 0)), color or Color3.fromRGB(255, 170, 70), Enum.Material.Neon)
	core.CastShadow = false
	local e = Kit.fire(core, color or Color3.fromRGB(255, 150, 60), 0.55 * s)
	e.Rate = 14
	if light ~= false then
		K.light(ctx, core, WARM, range or 22, brightness or 1.6, shadows)
	end
	return core
end

-- ------------------------------------------------------------------ wall-local frame
-- A wall frame: origin `a` (floor level point on the wall line), along-axis `u`
-- (unit, axis aligned), inward normal `n` (unit, axis aligned). Coordinates:
-- s along u, y up from the floor (y0), d into the room (d<0 is inside the wall).
function K.frame(a: Vector3, u: Vector3, n: Vector3, y0: number)
	return { a = V(a.X, y0, a.Z), u = u, n = n, y0 = y0, alongX = math.abs(u.X) > 0.5, rot = math.abs(u.X) < 0.999 and math.abs(u.Z) < 0.999 }
end

local function fsize(fr, ls: number, ly: number, ld: number): Vector3
	if fr.alongX then
		return V(ls, ly, ld)
	end
	return V(ld, ly, ls)
end
K.fsize = fsize

function K.fpos(fr, s: number, y: number, d: number): Vector3
	return fr.a + fr.u * s + fr.n * d + V(0, y, 0)
end

-- box in frame coordinates
function K.fbox(ctx, fr, s0: number, s1: number, y0: number, y1: number, d0: number, d1: number, color: Color3, mat: Enum.Material?, solid: boolean?, props)
	if s1 - s0 < 0.05 or y1 - y0 < 0.05 or d1 - d0 < 0.02 then
		return nil
	end
	local c = fr.a + fr.u * ((s0 + s1) / 2) + fr.n * ((d0 + d1) / 2) + V(0, (y0 + y1) / 2, 0)
	if fr.rot then
		local cf = CFrame.fromMatrix(c, fr.u, UP)
		local sz = V(s1 - s0, y1 - y0, d1 - d0)
		if solid then
			return K.solid(ctx, sz, cf, color, mat, props)
		end
		return K.deco(ctx, sz, cf, color, mat, props)
	end
	local size = fsize(fr, s1 - s0, y1 - y0, d1 - d0)
	if solid then
		return K.solid(ctx, size, CF(c), color, mat, props)
	end
	return K.deco(ctx, size, CF(c), color, mat, props)
end

-- intervals [0,L] minus gaps {{s0,s1}}
local function subtract(L: number, gaps)
	local out = { { 0, L } }
	for _, g in gaps do
		local nxt = {}
		for _, iv in out do
			if g[2] <= iv[1] or g[1] >= iv[2] then
				table.insert(nxt, iv)
			else
				if g[1] > iv[1] then
					table.insert(nxt, { iv[1], g[1] })
				end
				if g[2] < iv[2] then
					table.insert(nxt, { g[2], iv[2] })
				end
			end
		end
		out = nxt
	end
	return out
end
K.subtract = subtract

-- a run of course blocks between s0 and s1 at height band [y0,y1]
local function course(ctx, fr, s0, s1, y0, y1, lmin, lmax, dmin, dmax, cover, pal, mat)
	local rng = ctx.rng
	local s = s0 + rng:float(0, lmin * 0.6)
	if s - s0 > 0.4 and rng:chance(cover) then
		K.fbox(ctx, fr, s0, s, y0, y1, -0.2, rng:float(dmin, dmax), K.pj(ctx, pal, 0.1), mat)
	end
	while s < s1 - 0.3 do
		local len = rng:float(lmin, lmax)
		local e = math.min(s1, s + len)
		if s1 - e < lmin * 0.4 then
			e = s1
		end
		if rng:chance(cover) then
			K.fbox(ctx, fr, s, e, y0, y1, -0.2, rng:float(dmin, dmax), K.pj(ctx, pal, 0.1), mat)
		end
		s = e
	end
end
K.course = course

-- ------------------------------------------------------------------ masonry wall
-- opts: {height (to top), spring (cornice height), thick, doors={{c,w,h}},
--        style = "ashlar"|"rough"|"brick", pilasters = spacing or nil,
--        torches = true, torchY, onPilaster(ctx, fr, s) callback, noBack}
-- returns list of pilaster s positions
function K.wall(ctx, fr, L: number, opts)
	local th = ctx.theme
	local rng = ctx.rng
	local H = opts.height
	local hs = opts.spring or H
	local T = opts.thick or 4
	local doors = opts.doors or {}
	local style = opts.style or th.wallStyle or "ashlar"
	local wallPal = th.wall
	local trimPal = th.trim or th.wall
	local mat = if style == "rough" then (th.roughMat or Enum.Material.Rock) else (th.wallMat or th.mat)
	local gaps = {}
	for _, d in doors do
		table.insert(gaps, { d.c - d.w / 2, d.c + d.w / 2 })
	end
	local ivs = subtract(L, gaps)
	-- structural backing (extends T past both ends to close the corners)
	if not opts.noBack then
		for _, iv in ivs do
			local s0 = if iv[1] <= 0.01 then -T else iv[1]
			local s1 = if iv[2] >= L - 0.01 then L + T else iv[2]
			K.fbox(ctx, fr, s0, s1, -3, H + 2, -T, 0, K.pj(ctx, wallPal, 0.05), mat, true)
		end
		for _, d in doors do
			K.fbox(ctx, fr, d.c - d.w / 2, d.c + d.w / 2, d.h, H + 2, -T, 0, K.pj(ctx, wallPal, 0.05), mat, true)
		end
	end
	-- face intervals above door tops (for upper courses)
	local e0 = opts.trim0 or opts.trim or 2
	local e1 = opts.trim1 or opts.trim or 2
	local function ivsAt(y0, y1)
		local g = { { -1000, e0 }, { L - e1, L + 1000 } }
		for _, d in doors do
			if y0 < d.h + 3.5 then
				table.insert(g, { d.c - d.w / 2 - 2.2, d.c + d.w / 2 + 2.2 })
			end
		end
		return subtract(L, g)
	end
	if style == "rough" then
		-- natural rock: big irregular slabs sticking out
		local y = 0
		while y < hs - 1 do
			local hh = rng:float(5, 10)
			for _, iv in ivsAt(y, y + hh) do
				local s = iv[1]
				while s < iv[2] - 1 do
					local len = rng:float(6, 16)
					local e = math.min(iv[2], s + len)
					if rng:chance(0.75) then
						local dep = rng:float(0.4, 2.6)
						local p = K.fbox(ctx, fr, s, e, y - rng:float(0, 1.5), math.min(hs, y + hh + rng:float(0, 2)), -0.5, dep, K.pj(ctx, wallPal, 0.12), mat)
						if p and rng:chance(0.35) then
							p.CFrame = p.CFrame * ANG(rng:float(-0.08, 0.08), rng:float(-0.05, 0.05), rng:float(-0.08, 0.08))
						end
					end
					s = e
				end
			end
			y += hh
		end
		return {}
	end
	-- plinth
	for _, iv in ivsAt(0, 3) do
		course(ctx, fr, iv[1], iv[2], -0.2, 2.2, 5, 10, 0.85, 1.0, 1, trimPal, th.trimMat or mat)
		K.fbox(ctx, fr, iv[1], iv[2], 2.2, 2.8, -0.2, 0.55, K.pj(ctx, trimPal, 0.05), th.trimMat or mat)
	end
	-- lower courses (close to the eye: small blocks)
	local low = math.min(hs - 2, opts.lowTop or 13)
	local y = 2.8
	local rowH = if style == "brick" then 1.8 elseif opts.coarse then 3.6 else 3
	while y < low - 0.5 do
		local y1 = math.min(low, y + rowH)
		for _, iv in ivsAt(y, y1) do
			if style == "brick" then
				course(ctx, fr, iv[1], iv[2], y, y1, 2.6, 4.2, 0.06, 0.2, 0.8, wallPal, mat)
			else
				if opts.coarse then
					course(ctx, fr, iv[1], iv[2], y, y1, 5, 11, 0.08, 0.32, 0.85, wallPal, mat)
				else
					course(ctx, fr, iv[1], iv[2], y, y1, 4, 9, 0.08, 0.32, 0.9, wallPal, mat)
				end
			end
		end
		y = y1
	end
	-- string course
	local function band(yb, hgt, dep)
		for _, iv in ivsAt(yb, yb + hgt) do
			K.fbox(ctx, fr, iv[1], iv[2], yb, yb + hgt, -0.2, dep, K.pj(ctx, trimPal, 0.04), th.trimMat or mat)
		end
	end
	band(low - 0.4, 0.4, 0.4)
	band(low, 0.9, 0.7)
	-- upper courses: big ashlar, partial cover (recessed joints show the backing)
	y = low + 0.9
	while y < hs - 2.5 do
		local y1 = math.min(hs - 2.5, y + rng:float(4.5, 7))
		for _, iv in ivsAt(y, y1) do
			course(ctx, fr, iv[1], iv[2], y, y1, 9, 20, 0.1, 0.3, if opts.coarse then 0.55 else 0.66, wallPal, mat)
		end
		y = y1
	end
	-- cornice at the springing line
	if hs < H - 1 or opts.cornice then
		band(hs - 2.5, 0.8, 0.5)
		band(hs - 1.7, 0.9, 1.0)
		band(hs - 0.8, 0.8, 1.6)
	end
	-- door frames: jambs, voussoir ring, keystone, corbelled head
	for _, d in doors do
		local l, r = d.c - d.w / 2, d.c + d.w / 2
		local tc = K.pj(ctx, trimPal, 0.05)
		K.fbox(ctx, fr, l - 2, l, -0.2, d.h, -0.2, 1.3, tc, th.trimMat or mat)
		K.fbox(ctx, fr, r, r + 2, -0.2, d.h, -0.2, 1.3, tc, th.trimMat or mat)
		K.fbox(ctx, fr, l - 2.6, l + 0.4, -0.2, 3, -0.2, 1.8, tc, th.trimMat or mat)
		K.fbox(ctx, fr, r - 0.4, r + 2.6, -0.2, 3, -0.2, 1.8, tc, th.trimMat or mat)
		K.fbox(ctx, fr, l - 2, r + 2, d.h, d.h + 1.8, -0.2, 1.3, K.pj(ctx, trimPal, 0.05), th.trimMat or mat)
		K.fbox(ctx, fr, l - 1.2, r + 1.2, d.h + 1.8, d.h + 3.2, -0.2, 0.9, K.pj(ctx, trimPal, 0.05), th.trimMat or mat)
		K.fbox(ctx, fr, d.c - 1.3, d.c + 1.3, d.h - 0.6, d.h + 4.2, -0.2, 1.7, K.pj(ctx, trimPal, 0.05), th.trimMat or mat)
		-- corbelled "arch" inside the opening
		local cw = math.min(3, d.w * 0.14)
		for _, side in { -1, 1 } do
			local e = if side < 0 then l else r
			local function cb(w0, y0, y1)
				local a0 = if side < 0 then e else e - w0
				local a1 = if side < 0 then e + w0 else e
				K.fbox(ctx, fr, a0, a1, y0, y1, -T - 0.1, 0.4, K.pj(ctx, trimPal, 0.05), th.trimMat or mat)
			end
			cb(cw, d.h - 2, d.h)
			cb(cw * 0.5, d.h - 4, d.h - 2)
		end
	end
	-- pilasters
	local pil = {}
	if opts.pilasters then
		local sp = opts.pilasters
		local n = math.max(1, math.floor(L / sp))
		local step = L / n
		for i = 1, n - 1 do
			local s = i * step
			local ok = true
			for _, d in doors do
				if math.abs(s - d.c) < d.w / 2 + 5 then
					ok = false
				end
			end
			if ok and (opts.pilasterOk == nil or opts.pilasterOk(s)) then
				table.insert(pil, s)
				local c = K.pj(ctx, trimPal, 0.05)
				local top = opts.pilasterTop or hs
				K.fbox(ctx, fr, s - 2.3, s + 2.3, -0.2, 3.4, -0.2, 2.1, K.pj(ctx, trimPal, 0.05), th.trimMat or mat)
				K.fbox(ctx, fr, s - 1.6, s + 1.6, 3.4, top - 2.6, -0.2, 1.4, c, th.trimMat or mat)
				K.fbox(ctx, fr, s - 2.1, s + 2.1, top - 2.6, top - 1.2, -0.2, 2.0, K.pj(ctx, trimPal, 0.05), th.trimMat or mat)
				K.fbox(ctx, fr, s - 2.6, s + 2.6, top - 1.2, top, -0.2, 2.5, K.pj(ctx, trimPal, 0.05), th.trimMat or mat)
				if opts.onPilaster then
					opts.onPilaster(s, i)
				end
			end
		end
	end
	return pil
end

-- ------------------------------------------------------------------ floors
-- flagstone floor over [x0,x1]x[z0,z1] at top height y. opts {tile, cover, pal, mat, noSlab, thick}
function K.floor(ctx, x0: number, z0: number, x1: number, z1: number, y: number, opts)
	opts = opts or {}
	local th = ctx.theme
	local rng = ctx.rng
	local pal = opts.pal or th.floor
	local mat = opts.mat or th.floorMat or th.mat
	local thick = opts.thick or 4
	if not opts.noSlab then
		K.box(ctx, V(x0, y - thick, z0), V(x1, y, z1), K.pj(ctx, pal, 0.03), opts.slabMat or mat, true)
	end
	if opts.cover == 0 then
		return
	end
	local area = (x1 - x0) * (z1 - z0)
	local tile = opts.tile or math.clamp(math.sqrt(area / (opts.maxTiles or 210)), 4.5, 10)
	local cover = opts.cover or 0.85
	local alongX = (x1 - x0) >= (z1 - z0)
	-- rows run along the longer axis
	local r0, r1 = if alongX then z0 else x0, if alongX then z1 else x1
	local a0, a1 = if alongX then x0 else z0, if alongX then x1 else z1
	local r = r0
	while r < r1 - 0.2 do
		local rw = math.min(r1 - r, tile * rng:float(0.8, 1.2))
		if r1 - (r + rw) < tile * 0.4 then
			rw = r1 - r
		end
		local a = a0 + rng:float(0, tile * 0.5)
		while a < a1 - 0.2 do
			local len = math.min(a1 - a, tile * rng:float(0.8, 1.9))
			if a1 - (a + len) < tile * 0.4 then
				len = a1 - a
			end
			if rng:chance(cover) then
				local h = rng:float(0.08, 0.22)
				local g = 0.08
				local lo, hi
				if alongX then
					lo, hi = V(a + g, y - 0.3, r + g), V(a + len - g, y + h, r + rw - g)
				else
					lo, hi = V(r + g, y - 0.3, a + g), V(r + rw - g, y + h, a + len - g)
				end
				local p = K.box(ctx, lo, hi, K.pj(ctx, pal, 0.12), mat)
				if rng:chance(0.08) then
					p.CFrame = p.CFrame * ANG(rng:float(-0.03, 0.03), rng:float(-0.06, 0.06), rng:float(-0.03, 0.03))
				end
			end
			a += len
		end
		r += rw
	end
end

-- ------------------------------------------------------------------ vault
-- Stepped pointed vault over a rectangle: steps inward from all four walls
-- between the springing height hs and the top h (absolute Ys); a flat top slab
-- closes it. opts {steps, ribs = {positions along long axis}, hole = {x,z,r}}
function K.vault(ctx, x0: number, z0: number, x1: number, z1: number, ys: number, yt: number, opts)
	opts = opts or {}
	local th = ctx.theme
	local rng = ctx.rng
	local sx, sz = x1 - x0, z1 - z0
	local longX = sx >= sz
	local half = math.min(sx, sz) / 2
	local k = opts.steps or math.clamp(math.floor((yt - ys) / 5), 3, 8)
	local rise = yt - ys
	local insets = {}
	for i = 1, k do
		local f = i / k
		local t = 1.6 - math.sqrt(2.56 - 2.2 * f * f)
		insets[i] = half * t * (opts.depth or 0.86)
	end
	local pal = th.vault or th.wall
	local mat = th.wallMat or th.mat
	for i = 1, k do
		local yA = ys + (i - 1) * rise / k
		local yB = ys + i * rise / k
		local d = math.max(insets[i], 0.8 + i * 0.3)
		local c = K.pj(ctx, pal, 0.06)
		if longX then
			-- long walls (z0 / z1) span the whole length; short walls fit between
			K.box(ctx, V(x0 - 1, yA, z0 - 1), V(x1 + 1, yB, z0 + d), c, mat)
			K.box(ctx, V(x0 - 1, yA, z1 - d), V(x1 + 1, yB, z1 + 1), K.pj(ctx, pal, 0.06), mat)
			K.box(ctx, V(x0 - 1, yA, z0 + d), V(x0 + d * 0.7, yB, z1 - d), K.pj(ctx, pal, 0.06), mat)
			K.box(ctx, V(x1 - d * 0.7, yA, z0 + d), V(x1 + 1, yB, z1 - d), K.pj(ctx, pal, 0.06), mat)
		else
			K.box(ctx, V(x0 - 1, yA, z0 - 1), V(x0 + d, yB, z1 + 1), c, mat)
			K.box(ctx, V(x1 - d, yA, z0 - 1), V(x1 + 1, yB, z1 + 1), K.pj(ctx, pal, 0.06), mat)
			K.box(ctx, V(x0 + d, yA, z0 - 1), V(x1 - d, yB, z0 + d * 0.7), K.pj(ctx, pal, 0.06), mat)
			K.box(ctx, V(x0 + d, yA, z1 - d * 0.7), V(x1 - d, yB, z1 + 1), K.pj(ctx, pal, 0.06), mat)
		end
	end
	-- top slab (solid so nothing escapes), with an optional hole
	local hole = opts.hole
	local topC = Palette.shade(K.pj(ctx, pal, 0.05), 0.85)
	if hole then
		local hx0, hx1, hz0, hz1 = hole.x - hole.r, hole.x + hole.r, hole.z - hole.r, hole.z + hole.r
		K.box(ctx, V(x0 - 4, yt, z0 - 4), V(hx0, yt + 4, z1 + 4), topC, mat, true)
		K.box(ctx, V(hx1, yt, z0 - 4), V(x1 + 4, yt + 4, z1 + 4), topC, mat, true)
		K.box(ctx, V(hx0, yt, z0 - 4), V(hx1, yt + 4, hz0), topC, mat, true)
		K.box(ctx, V(hx0, yt, hz1), V(hx1, yt + 4, z1 + 4), topC, mat, true)
	else
		K.box(ctx, V(x0 - 4, yt, z0 - 4), V(x1 + 4, yt + 4, z1 + 4), topC, mat, true)
	end
	-- transverse ribs following the steps + a ridge beam
	local tc = th.trim or th.wall
	if opts.ribs then
		for _, p in opts.ribs do
			local c = K.pj(ctx, tc, 0.05)
			local inHole = hole and math.abs(p - (if longX then hole.x else hole.z)) < hole.r + 2
			for i = 1, k do
				local yA = ys + (i - 1) * rise / k
				local yB = ys + i * rise / k
				local d = math.max(insets[i], 0.8 + i * 0.3) + 0.9
				if longX then
					K.box(ctx, V(p - 1.3, yA - 0.7, z0 - 0.5), V(p + 1.3, yB, z0 + d), c, mat)
					K.box(ctx, V(p - 1.3, yA - 0.7, z1 - d), V(p + 1.3, yB, z1 + 0.5), c, mat)
				else
					K.box(ctx, V(x0 - 0.5, yA - 0.7, p - 1.3), V(x0 + d, yB, p + 1.3), c, mat)
					K.box(ctx, V(x1 - d, yA - 0.7, p - 1.3), V(x1 + 0.5, yB, p + 1.3), c, mat)
				end
			end
			if inHole then
				-- no beam across the shaft
			elseif longX then
				K.box(ctx, V(p - 1.3, yt - 1.4, z0 + insets[k]), V(p + 1.3, yt + 0.5, z1 - insets[k]), c, mat)
			else
				K.box(ctx, V(x0 + insets[k], yt - 1.4, p - 1.3), V(x1 - insets[k], yt + 0.5, p + 1.3), c, mat)
			end
		end
		if not hole then
			if longX then
				K.box(ctx, V(x0 + insets[k] * 0.7, yt - 1, (z0 + z1) / 2 - 1), V(x1 - insets[k] * 0.7, yt + 0.5, (z0 + z1) / 2 + 1), K.pj(ctx, tc, 0.05), mat)
			else
				K.box(ctx, V((x0 + x1) / 2 - 1, yt - 1, z0 + insets[k] * 0.7), V((x0 + x1) / 2 + 1, yt + 0.5, z1 - insets[k] * 0.7), K.pj(ctx, tc, 0.05), mat)
			end
		end
	end
	return insets
end

-- ------------------------------------------------------------------ pillars
-- square pillar with base, banded shaft and capital. opts {broken=height, noCap, pal, mat, bands}
function K.pillar(ctx, pos: Vector3, w: number, h: number, opts)
	opts = opts or {}
	local th = ctx.theme
	local rng = ctx.rng
	local pal = opts.pal or th.trim or th.wall
	local mat = opts.mat or th.trimMat or th.wallMat or th.mat
	local top = if opts.broken then opts.broken else h
	K.solid(ctx, V(w + 3, 2.2, w + 3), CF(pos + V(0, 1, 0)), K.pj(ctx, pal, 0.05), mat)
	K.deco(ctx, V(w + 1.6, 1.4, w + 1.6), CF(pos + V(0, 2.8, 0)), K.pj(ctx, pal, 0.05), mat)
	local shaftH = top - 3.5 - (if opts.broken or opts.noCap then 0 else 3.4)
	if shaftH > 0 then
		local shaft = K.solid(ctx, V(w, shaftH, w), CF(pos + V(0, 3.5 + shaftH / 2, 0)), K.pj(ctx, th.wall, 0.06), th.wallMat or th.mat)
		-- bands / flutes
		local bands = opts.bands or 14
		local y = 3.5 + bands
		while y < 3.5 + shaftH - 3 do
			K.deco(ctx, V(w + 1.0, 0.9, w + 1.0), CF(pos + V(0, y, 0)), K.pj(ctx, pal, 0.05), mat)
			y += bands
		end
		if w >= 6 and not opts.noFlutes then
			for _, dir in { V(1, 0, 0), V(-1, 0, 0), V(0, 0, 1), V(0, 0, -1) } do
				local sz = if math.abs(dir.X) > 0 then V(0.5, shaftH - 2, 1.4) else V(1.4, shaftH - 2, 0.5)
				K.deco(ctx, sz, CF(pos + dir * (w / 2 + 0.1) + V(0, 3.5 + shaftH / 2, 0)), Palette.shade(K.pj(ctx, th.wall, 0.05), 0.82), th.wallMat or th.mat)
			end
		end
		shaft.Name = "Pillar"
	end
	if opts.broken then
		-- jagged top
		for i = 1, 3 do
			local s = w * rng:float(0.3, 0.6)
			K.deco(ctx, V(s, rng:float(1, 3), s), CF(pos + V(rng:float(-w / 4, w / 4), top + rng:float(0, 1), rng:float(-w / 4, w / 4))) * ANG(rng:float(-0.4, 0.4), rng:angle(), rng:float(-0.4, 0.4)), K.pj(ctx, th.wall, 0.08), th.wallMat or th.mat)
		end
	elseif not opts.noCap then
		K.deco(ctx, V(w + 1.4, 1.4, w + 1.4), CF(pos + V(0, h - 2.7, 0)), K.pj(ctx, pal, 0.05), mat)
		K.solid(ctx, V(w + 3, 2, w + 3), CF(pos + V(0, h - 1, 0)), K.pj(ctx, pal, 0.05), mat)
	end
end

-- stepped arch between two points (a, b: springing points at the same Y), in the
-- vertical plane through them. thick = depth, rise above the springing line.
function K.arch(ctx, a: Vector3, b: Vector3, rise: number, thick: number, opts)
	opts = opts or {}
	local th = ctx.theme
	local pal = opts.pal or th.trim or th.wall
	local mat = opts.mat or th.trimMat or th.wallMat or th.mat
	local span = (b - a).Magnitude
	local u = (b - a).Unit
	local k = opts.steps or math.clamp(math.floor(span / 4), 3, 7)
	local band = opts.band or 2.2
	local cfBase = CFrame.lookAt(a, a + u) -- -Z along u
	local half = span / 2
	-- two-centred (pointed) profile, R = 1.25 * half-span
	local function hAt(f)
		return rise * math.sqrt(math.max(0, 2.5 * f - f * f)) / math.sqrt(1.5)
	end
	for i = 1, k do
		local f0 = (i - 1) / k
		local f1 = i / k
		local y0 = hAt(f0)
		local y1 = hAt(f1)
		local x0 = f0 * half
		local x1 = f1 * half
		local tk = thick + (if i % 2 == 0 then 0.25 else 0)
		for _, side in { 0, 1 } do
			local s0 = if side == 0 then x0 else span - x1
			local s1 = if side == 0 then x1 else span - x0
			local hgt = (y1 - y0) + band
			local c = cfBase * CF(0, y0 + hgt / 2, -(s0 + s1) / 2)
			K.deco(ctx, V(tk, hgt, s1 - s0), c, K.pj(ctx, pal, 0.06), mat)
		end
	end
	-- keystone
	K.deco(ctx, V(thick + 0.6, band + 1.6, 2), cfBase * CF(0, rise + band / 2 + 0.3, -half), K.pj(ctx, pal, 0.05), mat)
end

-- ------------------------------------------------------------------ stairs
-- Straight stair from `base` (centre of the bottom edge, floor level) climbing
-- `rise` along the unit axis `dir` over `run` studs. Visual steps are deco;
-- a smooth invisible wedge does the collision. opts {pal, mat, sides=true, solidSteps}
function K.stairs(ctx, base: Vector3, dir: Vector3, width: number, rise: number, run: number, opts)
	opts = opts or {}
	local th = ctx.theme
	local pal = opts.pal or th.floor
	local mat = opts.mat or th.floorMat or th.mat
	local n = math.max(1, math.ceil(rise / 1.05))
	local tread = run / n
	local side = V(-dir.Z, 0, dir.X)
	local function box(c: Vector3, along: number, across: number, h: number, color, m, solid)
		local size = if math.abs(dir.X) > 0.5 then V(along, h, across) else V(across, h, along)
		if solid then
			return K.solid(ctx, size, CF(c), color, m)
		end
		return K.deco(ctx, size, CF(c), color, m)
	end
	for i = 1, n do
		local top = rise * i / n
		local c = base + dir * ((i - 0.5) * tread) + V(0, (top - 0.6) / 2, 0)
		box(c, tread + 0.05, width, top + 0.6, K.pj(ctx, pal, 0.07), mat, opts.solidSteps)
		-- nosing
		if width > 4 then
			box(base + dir * ((i - 1) * tread + 0.3) + V(0, top - 0.15, 0), 0.6, width + 0.2, 0.36, K.pj(ctx, th.trim or pal, 0.05), th.trimMat or mat)
		end
	end
	if not opts.solidSteps then
		-- smooth ramp through the middle of every tread (WedgePart rises toward +Z)
		local mid = base + dir * (run / 2) + V(0, rise / 2, 0)
		local w = Instance.new("WedgePart")
		w.Anchored = true
		w.Size = V(width, rise, run)
		w.CFrame = CFrame.lookAt(mid, mid - dir)
		w.Transparency = 1
		w.CastShadow = false
		w.Color = Color3.new(0.3, 0.3, 0.3)
		w.Material = Enum.Material.Slate
		w.Name = "Ramp"
		w.Parent = ctx.geo
		tick(ctx)
	end
	if opts.sides ~= false then
		-- stepped side stringers
		for _, sgn in { -1, 1 } do
			for j = 0, 2 do
				local f0, f1 = j / 3, (j + 1) / 3
				local hh = rise * f1 + 1.4
				local c = base + side * (sgn * (width / 2 + 0.6)) + dir * (run * (f0 + f1) / 2) + V(0, hh / 2 - 0.3, 0)
				local size = if math.abs(dir.X) > 0.5 then V(run / 3 + 0.02, hh, 1.2) else V(1.2, hh, run / 3 + 0.02)
				K.solid(ctx, size, CF(c), K.pj(ctx, th.trim or pal, 0.05), th.trimMat or mat)
			end
		end
	end
end

-- ------------------------------------------------------------------ misc
-- sunken glow slab with an iron grate on top (floor grates)
function K.grate(ctx, pos: Vector3, sx: number, sz: number, glow: Color3, light: boolean?)
	local iron = ctx.theme.iron or Color3.fromRGB(58, 56, 60)
	local g = K.deco(ctx, V(sx - 0.4, 0.1, sz - 0.4), CF(pos + V(0, 0.07, 0)), glow, Enum.Material.Neon)
	g.CastShadow = false
	K.deco(ctx, V(sx, 0.3, 0.5), CF(pos + V(0, 0.2, -sz / 2 + 0.25)), iron, Enum.Material.CorrodedMetal)
	K.deco(ctx, V(sx, 0.3, 0.5), CF(pos + V(0, 0.2, sz / 2 - 0.25)), iron, Enum.Material.CorrodedMetal)
	K.deco(ctx, V(0.5, 0.3, sz), CF(pos + V(-sx / 2 + 0.25, 0.2, 0)), iron, Enum.Material.CorrodedMetal)
	K.deco(ctx, V(0.5, 0.3, sz), CF(pos + V(sx / 2 - 0.25, 0.2, 0)), iron, Enum.Material.CorrodedMetal)
	local nb = math.max(2, math.floor(sx / 1.2))
	for i = 1, nb - 1 do
		K.deco(ctx, V(0.22, 0.26, sz - 0.6), CF(pos + V(-sx / 2 + i * sx / nb, 0.2, 0)), iron, Enum.Material.Metal)
	end
	K.deco(ctx, V(sx - 0.6, 0.24, 0.22), CF(pos + V(0, 0.22, 0)), iron, Enum.Material.Metal)
	if light then
		K.light(ctx, g, glow, 14, 1.2)
	end
	return g
end

return K
