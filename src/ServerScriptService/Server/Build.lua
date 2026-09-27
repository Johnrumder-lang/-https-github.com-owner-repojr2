--!nonstrict
-- ARCHITECTURE KIT. Medieval-European / Norse buildings in the cubic style:
-- half-timbered town houses, stone mansions, longhouses, churches, windmills,
-- watchtowers, palisades, the Great Wall with gatehouses, bridges, docks,
-- longships and village props. Every builder takes a base CFrame at ground level;
-- the building's FRONT faces the CFrame's -Z (LookVector).
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Kit = require(Shared.Kit)
local Palette = require(Shared.Palette)
local RNG = require(Shared.RNG)
local S = require(script.Parent.S)

local B = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB
local M = Enum.Material

B.PLASTER = { rgb(236, 228, 208), rgb(228, 216, 190), rgb(240, 234, 222), rgb(222, 206, 178), rgb(232, 214, 196), rgb(214, 204, 186), rgb(236, 222, 180) }
B.BEAMS = { rgb(74, 50, 34), rgb(60, 42, 30), rgb(88, 58, 38), rgb(52, 38, 30) }
B.ROOFS = { rgb(150, 70, 50), rgb(120, 56, 44), rgb(170, 90, 60), rgb(90, 84, 90), rgb(70, 80, 100), rgb(110, 76, 56), rgb(136, 60, 40) }
B.STONE = { rgb(168, 162, 150), rgb(150, 146, 138), rgb(180, 174, 160), rgb(140, 136, 130) }
B.SHUTTERS = { rgb(60, 90, 60), rgb(40, 70, 110), rgb(120, 40, 36), rgb(90, 70, 50), rgb(70, 60, 80) }

local function solid(parent, size, cf, color, mat, props)
	return Kit.part(parent, size, cf, color, mat, props)
end
local function deco(parent, size, cf, color, mat, props)
	local p = Kit.deco(parent, size, cf, color, mat, props)
	if not (props and props.CastShadow ~= nil) and size.X * size.Y * size.Z < 60 then
		p.CastShadow = false
	end
	return p
end
local function wedge(parent, size, cf, color, mat, props)
	return Kit.wedge(parent, size, cf, color, mat, props)
end
B.solid, B.deco, B.wedge = solid, deco, wedge

local function rngOf(o)
	return o.rng or RNG.new(math.random(1, 1e6))
end

-- Gable roof over a rectangle (ridge along local X). Returns the ridge height.
-- span = full depth to cover (z), len = length along x, y0 = eave height.
function B.gableRoof(m, cf, len: number, span: number, y0: number, pitch: number, color: Color3, mat: Enum.Material, opts)
	opts = opts or {}
	local oh = opts.overhang or 1.2
	local hs = span / 2 + oh
	local rise = hs * math.tan(pitch)
	local L = hs / math.cos(pitch)
	local thick = opts.thick or 0.9
	for _, side in { -1, 1 } do
		local c = cf * CF(0, y0 + rise / 2 + thick * 0.4, side * hs / 2) * ANG(side * pitch, 0, 0)
		solid(m, V(len + 2 * (opts.endOverhang or oh), thick, L + 0.1), c, if side < 0 then color else Palette.shade(color, 0.92), mat)
	end
	-- gable triangles (filled with `gable` colour)
	if opts.gable then
		local ghs = span / 2
		local grise = ghs * math.tan(pitch)
		for _, x in { -len / 2 + 0.4, len / 2 - 0.4 } do
			wedge(m, V(0.8, grise, ghs), cf * CF(x, y0 + grise / 2, -ghs / 2), opts.gable, opts.gableMat or M.Plaster)
			wedge(m, V(0.8, grise, ghs), cf * CF(x, y0 + grise / 2, ghs / 2) * ANG(0, math.pi, 0), opts.gable, opts.gableMat or M.Plaster)
		end
	end
	if opts.ridge ~= false then
		deco(m, V(len + 2 * (opts.endOverhang or oh) + 0.2, 0.6, 0.7), cf * CF(0, y0 + rise + thick * 0.55, 0), opts.ridgeColor or Palette.shade(color, 0.7), mat)
	end
	return y0 + rise
end

-- A glazed window with frame (+ optional shutters and flower box) on a wall face.
-- `face` is a CFrame on the wall surface whose -Z points out of the building.
local GLASS = rgb(96, 122, 140)
local function window(m, face: CFrame, w: number, h: number, frame: Color3, shutter: Color3?, box: boolean?)
	deco(m, V(w + 0.6, h + 0.6, 0.16), face * CF(0, 0, -0.08), frame, M.WoodPlanks)
	deco(m, V(w, h, 0.18), face * CF(0, 0, -0.14), GLASS, M.Glass, { Transparency = 0.1, Reflectance = 0.15 })
	if shutter then
		for _, s in { -1, 1 } do
			deco(m, V(w * 0.5, h + 0.2, 0.18), face * CF(s * (w * 0.75 + 0.35), 0, -0.14), shutter, M.WoodPlanks)
		end
	end
	if box then
		deco(m, V(w + 0.8, 0.5, 0.7), face * CF(0, -h / 2 - 0.45, -0.4), Palette.wood[2], M.WoodPlanks)
		deco(m, V(w + 0.6, 0.35, 0.5), face * CF(0, -h / 2 - 0.05, -0.4), Palette.jitter(rgb(210, 70, 80), 0.3, math.random()), M.Grass)
	end
end
B.window = window

-- ------------------------------------------------------------------ half-timbered house
-- opts: {w, d, floors, fh, wall, beam, roof, roofMat, stoneBase, jetty, rng, sign, chimney, name}
function B.halfTimber(parent: Instance, cf: CFrame, o)
	o = o or {}
	local rng = rngOf(o)
	local w, d = o.w or 14, o.d or 12
	local floors = o.floors or 2
	local fh = o.fh or 9
	local jet = if floors > 1 then (o.jetty or 0.8) else 0
	local wall = o.wall or rng:pick(B.PLASTER)
	local beam = o.beam or rng:pick(B.BEAMS)
	local roofC = o.roof or rng:pick(B.ROOFS)
	local roofMat = o.roofMat or rng:pick({ M.ClayRoofTiles, M.RoofShingles, M.ClayRoofTiles })
	local stoneC = rng:pick(B.STONE)
	local shutter = if rng:chance(0.6) then rng:pick(B.SHUTTERS) else nil
	local m = Kit.model(o.name or "House", parent)
	local plinth = 1.2
	solid(m, V(w + 0.8, plinth, d + 0.8), cf * CF(0, plinth / 2, 0), stoneC, M.Cobblestone)
	local t = 0.8
	local doorW, doorH = 3.6, 6.2
	for f = 0, floors - 1 do
		local y = plinth + f * fh
		local fd = d + 2 * jet * math.min(f, 1) * (if f > 0 then 1 else 0)
		local stone = f == 0 and (o.stoneBase or (floors >= 2 and rng:chance(0.5)))
		local wc, wm = if stone then stoneC else wall, if stone then M.Cobblestone else M.Plaster
		local zf, zb = -fd / 2, fd / 2
		if f == 0 then
			local side = (w - doorW) / 2
			solid(m, V(side, fh, t), cf * CF(-(doorW / 2 + side / 2), y + fh / 2, zf + t / 2), wc, wm)
			solid(m, V(side, fh, t), cf * CF(doorW / 2 + side / 2, y + fh / 2, zf + t / 2), wc, wm)
			solid(m, V(doorW, fh - doorH, t), cf * CF(0, y + doorH + (fh - doorH) / 2, zf + t / 2), wc, wm)
		else
			solid(m, V(w, fh, t), cf * CF(0, y + fh / 2, zf + t / 2), wc, wm)
		end
		solid(m, V(w, fh, t), cf * CF(0, y + fh / 2, zb - t / 2), wc, wm)
		solid(m, V(t, fh, fd - 2 * t), cf * CF(-w / 2 + t / 2, y + fh / 2, 0), wc, wm)
		solid(m, V(t, fh, fd - 2 * t), cf * CF(w / 2 - t / 2, y + fh / 2, 0), wc, wm)
		-- timber frame
		deco(m, V(w + 0.3, 0.55, fd + 0.3), cf * CF(0, y + fh - 0.1, 0), beam, M.WoodPlanks)
		if not stone then
			deco(m, V(w + 0.25, 0.45, fd + 0.25), cf * CF(0, y + 0.35, 0), beam, M.WoodPlanks)
			for _, x in { -w / 2, w / 2 } do
				for _, z in { zf, zb } do
					deco(m, V(0.7, fh, 0.7), cf * CF(x, y + fh / 2, z), beam, M.WoodPlanks)
				end
			end
			local n = math.max(1, math.floor(w / 6))
			for i = 1, n do
				local x = -w / 2 + i * w / (n + 1)
				if not (f == 0 and math.abs(x) < doorW / 2 + 0.6) then
					deco(m, V(0.45, fh - 0.6, 0.2), cf * CF(x, y + fh / 2, zf - 0.08), beam, M.WoodPlanks)
				end
				deco(m, V(0.45, fh - 0.6, 0.2), cf * CF(x, y + fh / 2, zb + 0.08), beam, M.WoodPlanks)
			end
			-- diagonal braces in the outer bays
			if f > 0 or floors == 1 then
				local diag = math.sqrt((fh * 0.8) ^ 2 + (w / (n + 1)) ^ 2)
				local ang = math.atan2(w / (n + 1), fh * 0.8)
				for _, sx in { -1, 1 } do
					local x = sx * (w / 2 - w / (n + 1) / 2)
					deco(m, V(0.4, diag, 0.16), cf * CF(x, y + fh / 2, zf - 0.1) * ANG(0, 0, sx * ang), beam, M.WoodPlanks)
				end
			end
			end
		-- windows
		local wy = y + fh * 0.55
		local slots = if w >= 16 then { -0.3, 0.3 } else { -0.28, 0.28 }
		for _, k in slots do
			if not (f == 0 and math.abs(k * w) < doorW / 2 + 1.4) then
				window(m, cf * CF(k * w, wy, zf), 2.0, 2.6, beam, shutter, f > 0 and rng:chance(0.5))
			end
		end
		if f == floors - 1 then
			window(m, cf * CF(rng:float(-0.25, 0.25) * w, wy, zb) * ANG(0, math.pi, 0), 1.8, 2.4, beam, nil)
		end
		if f > 0 then
			window(m, cf * CF(-w / 2, wy, 0) * ANG(0, math.pi / 2, 0), 1.6, 2.2, beam, nil)
			window(m, cf * CF(w / 2, wy, 0) * ANG(0, -math.pi / 2, 0), 1.6, 2.2, beam, nil)
		end
		end
	-- door + lintel + lamp
	local door = deco(m, V(doorW - 0.5, doorH - 0.2, 0.3), cf * CF(0, plinth + (doorH - 0.2) / 2, -d / 2 - 0.05), Palette.wood[4], M.WoodPlanks)
	door.Name = "Door"
	deco(m, V(doorW + 0.8, 0.6, 0.5), cf * CF(0, plinth + doorH + 0.3, -d / 2 - 0.1), beam, M.WoodPlanks)
	deco(m, V(0.14, 0.14, 0.12), cf * CF(doorW / 2 - 0.8, plinth + doorH / 2, -d / 2 - 0.25), Palette.metal.dark, M.Metal)
	if rng:chance(0.4) then
		local lamp = deco(m, V(0.6, 0.8, 0.6), cf * CF(doorW / 2 + 0.9, plinth + doorH - 0.4, -d / 2 - 0.5), rgb(255, 196, 120), M.Neon)
		if rng:chance(0.35) then
			Kit.pointLight(lamp, rgb(255, 180, 110), 18, 0.8)
		end
	end
	-- roof
	local top = plinth + floors * fh
	local topD = d + (if floors > 1 then 2 * jet else 0)
	local pitch = math.rad(o.pitch or rng:float(46, 56))
	local ridgeY = B.gableRoof(m, cf, w, topD, top, pitch, roofC, roofMat, { gable = wall, overhang = 1.2 })
	-- a timber king post on the gable ends
	for _, x in { -w / 2 - 0.05, w / 2 + 0.05 } do
		deco(m, V(0.2, (ridgeY - top) * 0.9, 0.45), cf * CF(x, top + (ridgeY - top) * 0.45, 0), beam, M.WoodPlanks)
	end
	-- chimney
	if o.chimney ~= false and rng:chance(0.7) then
		local cx = rng:float(-w * 0.3, w * 0.3)
		local cz = topD * 0.18 * (if rng:chance(0.5) then 1 else -1)
		local chH = ridgeY - top + 2.5
		local ch = solid(m, V(1.8, chH, 1.8), cf * CF(cx, top + chH / 2, cz), rgb(150, 86, 70), M.Brick)
		deco(m, V(2.2, 0.4, 2.2), cf * CF(cx, top + chH + 0.2, cz), rgb(90, 86, 84), M.Slate)
		if rng:chance(0.45) then
			Kit.emitter(ch, { Texture = Kit.SMOKE, Color = ColorSequence.new(rgb(120, 118, 122)), LightEmission = 0, Rate = 3, Speed = NumberRange.new(3, 5), Lifetime = NumberRange.new(4, 6), Size = NumberSequence.new(1.6, 5), Transparency = NumberSequence.new(0.45, 1), Acceleration = V(1.2, 1.5, 0), EmissionDirection = Enum.NormalId.Top })
		end
	end
	-- shop sign
	if o.sign then
		deco(m, V(0.2, 0.2, 2.2), cf * CF(w / 2 - 1.2, plinth + fh - 1.2, -d / 2 - 1.1), Palette.metal.dark, M.Metal)
		deco(m, V(0.2, 1.6, 1.8), cf * CF(w / 2 - 1.2, plinth + fh - 2.2, -d / 2 - 1.5), o.signColor or rgb(150, 110, 60), M.WoodPlanks)
	end
	return m, (cf * CF(0, 0, -d / 2 - 3)).Position
end

-- ------------------------------------------------------------------ terraced row (v4)
-- A row of `units` narrow town houses sharing side walls and one long roof: the
-- dense streets of a big city at a fraction of the parts of separate houses.
-- Every unit is its own sub-model (named "House", with its own "Door") so it can
-- be entered and furnished on its own. Front faces the frame's -Z.
-- opts: {units, unitW, d, floors, fh, style = "timber"|"cottage"|"stone", rng, roof}
-- returns (model, units = {{model, door (street point), cf (unit ground frame), w}})
local STONE_WALLS = { rgb(206, 198, 184), rgb(196, 190, 178), rgb(214, 206, 190), rgb(186, 180, 170), rgb(200, 188, 168) }
function B.terrace(parent: Instance, cf: CFrame, o)
	o = o or {}
	local rng = rngOf(o)
	local units = o.units or 4
	local uw = o.unitW or 9
	local d = o.d or 12
	local floors = o.floors or 2
	local fh = o.fh or 9
	local style = o.style or "timber"
	local W = units * uw
	local H = floors * fh
	local m = Kit.model(o.name or "Terrace", parent)
	local plinth = 1.2
	local t = 0.8
	local stoneC = rng:pick(B.STONE)
	local roofC = o.roof or (if style == "stone" then rng:pick({ rgb(60, 70, 110), rgb(70, 70, 80), rgb(56, 80, 70), rgb(96, 60, 52) }) else rng:pick(B.ROOFS))
	local roofMat = if style == "stone" then M.Slate else rng:pick({ M.ClayRoofTiles, M.RoofShingles, M.ClayRoofTiles })
	local beam = rng:pick(B.BEAMS)
	local wm = if style == "stone" then M.Limestone else M.Plaster
	local endC = if style == "stone" then rng:pick(STONE_WALLS) else rng:pick(B.PLASTER)
	solid(m, V(W + 0.8, plinth, d + 0.8), cf * CF(0, plinth / 2, 0), stoneC, M.Cobblestone)
	-- back wall, gable-end walls, party walls between the units
	solid(m, V(W, H, t), cf * CF(0, plinth + H / 2, d / 2 - t / 2), endC, wm)
	for _, sx in { -1, 1 } do
		solid(m, V(t, H, d - 2 * t), cf * CF(sx * (W / 2 - t / 2), plinth + H / 2, 0), endC, wm)
	end
	for u = 1, units - 1 do
		solid(m, V(0.6, H, d - 2 * t), cf * CF(-W / 2 + u * uw, plinth + H / 2, 0), Palette.shade(endC, 0.95), M.Plaster)
	end
	-- storey lines (timber rows get beams, stone rows a cornice)
	for f = 1, floors do
		deco(m, V(W + 0.3, 0.5, 0.3), cf * CF(0, plinth + f * fh - 0.2, -d / 2 - 0.1), if style == "stone" then Palette.shade(endC, 1.1) else beam, if style == "stone" then M.Limestone else M.WoodPlanks)
	end
	local doorW, doorH = 3.2, 6.2
	local out = {}
	for u = 1, units do
		local ux = -W / 2 + (u - 0.5) * uw
		local um = Kit.model("House", m)
		local wallC = if style == "stone" then rng:pick(STONE_WALLS) else rng:pick(B.PLASTER)
		local side = (uw - doorW) / 2
		local zf = -d / 2 + t / 2
		-- the door sits a little off-centre; a window takes the other side
		local off = (if u % 2 == 0 then 1 else -1) * math.min(1.2, side * 0.3)
		local dl, dr = side + off, side - off
		solid(um, V(dl, fh, t), cf * CF(ux - uw / 2 + dl / 2, plinth + fh / 2, zf), wallC, wm)
		solid(um, V(dr, fh, t), cf * CF(ux + uw / 2 - dr / 2, plinth + fh / 2, zf), wallC, wm)
		solid(um, V(doorW, fh - doorH, t), cf * CF(ux + off, plinth + doorH + (fh - doorH) / 2, zf), wallC, wm)
		if floors > 1 then
			solid(um, V(uw, (floors - 1) * fh, t), cf * CF(ux, plinth + fh + (floors - 1) * fh / 2, zf), wallC, wm)
		end
		local door = deco(um, V(doorW - 0.5, doorH - 0.2, 0.3), cf * CF(ux + off, plinth + (doorH - 0.2) / 2, -d / 2 - 0.05), rng:pick({ Palette.wood[4], rgb(70, 40, 30), rgb(60, 70, 90), rgb(90, 50, 40) }), M.WoodPlanks)
		door.Name = "Door"
		-- windows: one downstairs beside the door, two on every upper floor
		local winX = ux - off * 2.4
		if uw >= 8.5 then
			deco(um, V(1.8, 2.4, 0.2), cf * CF(winX, plinth + fh * 0.55, -d / 2 - 0.08), GLASS, M.Glass, { Transparency = 0.1, Reflectance = 0.15 })
		end
		for f = 1, floors - 1 do
			local wy = plinth + f * fh + fh * 0.55
			for _, k in { -0.24, 0.24 } do
				deco(um, V(1.7, 2.5, 0.2), cf * CF(ux + k * uw, wy, -d / 2 - 0.08), GLASS, M.Glass, { Transparency = 0.1, Reflectance = 0.15 })
			end
			deco(um, V(uw * 0.8, 0.3, 0.5), cf * CF(ux, wy - 1.4, -d / 2 - 0.2), if style == "stone" then Palette.shade(wallC, 1.1) else beam, M.WoodPlanks)
			-- a flower box now and then
			if rng:chance(0.3) then
				deco(um, V(uw * 0.5, 0.35, 0.5), cf * CF(ux, wy - 1.1, -d / 2 - 0.45), Palette.jitter(rgb(210, 70, 80), 0.3, rng:float()), M.Grass)
			end
		end
		if style ~= "stone" then
			deco(um, V(0.5, H, 0.3), cf * CF(ux - uw / 2, plinth + H / 2, -d / 2 - 0.12), beam, M.WoodPlanks)
		end
		if u % 2 == 1 and rng:chance(0.8) then
			local chH = 6
			local ch = solid(um, V(1.6, chH, 1.6), cf * CF(ux + uw * 0.3, plinth + H + chH / 2 + 1, d * 0.2), rgb(150, 86, 70), M.Brick)
			if rng:chance(0.25) then
				Kit.emitter(ch, { Texture = Kit.SMOKE, Color = ColorSequence.new(rgb(120, 118, 122)), LightEmission = 0, Rate = 2, Speed = NumberRange.new(3, 5), Lifetime = NumberRange.new(4, 6), Size = NumberSequence.new(1.6, 5), Transparency = NumberSequence.new(0.45, 1), Acceleration = V(1.2, 1.5, 0), EmissionDirection = Enum.NormalId.Top })
			end
		end
		if o.sign and u == 1 then
			deco(um, V(0.2, 1.6, 1.8), cf * CF(ux + uw / 2 - 1.2, plinth + fh - 2.2, -d / 2 - 1.5), o.signColor or rgb(150, 110, 60), M.WoodPlanks)
		end
		table.insert(out, { model = um, door = (cf * CF(ux + off, 0, -d / 2 - 3)).Position, cf = cf * CF(ux, 0, 0), w = uw })
	end
	local pitch = math.rad(o.pitch or rng:float(42, 52))
	B.gableRoof(m, cf, W, d, plinth + H, pitch, roofC, roofMat, { gable = endC, gableMat = wm, overhang = 1.0 })
	return m, out
end

-- ------------------------------------------------------------------ stone mansion (upper city)
function B.stoneHouse(parent: Instance, cf: CFrame, o)
	o = o or {}
	local rng = rngOf(o)
	local w, d = o.w or 18, o.d or 15
	local floors = o.floors or 3
	local fh = o.fh or 10
	local stone = o.wall or rng:pick({ rgb(206, 198, 184), rgb(196, 190, 178), rgb(214, 206, 190), rgb(186, 180, 170) })
	local trim = Palette.shade(stone, 1.12)
	local roofC = o.roof or rng:pick({ rgb(60, 70, 110), rgb(70, 70, 80), rgb(56, 80, 70), rgb(110, 50, 44) })
	local m = Kit.model(o.name or "Mansion", parent)
	local plinth = 1.6
	solid(m, V(w + 1.2, plinth, d + 1.2), cf * CF(0, plinth / 2, 0), Palette.shade(stone, 0.8), M.Slate)
	local H = floors * fh
	local t = 1
	local doorW, doorH = 4.4, 7.4
	local side = (w - doorW) / 2
	solid(m, V(side, H, t), cf * CF(-(doorW / 2 + side / 2), plinth + H / 2, -d / 2 + t / 2), stone, M.Limestone)
	solid(m, V(side, H, t), cf * CF(doorW / 2 + side / 2, plinth + H / 2, -d / 2 + t / 2), stone, M.Limestone)
	solid(m, V(doorW, H - doorH, t), cf * CF(0, plinth + doorH + (H - doorH) / 2, -d / 2 + t / 2), stone, M.Limestone)
	solid(m, V(w, H, t), cf * CF(0, plinth + H / 2, d / 2 - t / 2), stone, M.Limestone)
	solid(m, V(t, H, d - 2 * t), cf * CF(-w / 2 + t / 2, plinth + H / 2, 0), stone, M.Limestone)
	solid(m, V(t, H, d - 2 * t), cf * CF(w / 2 - t / 2, plinth + H / 2, 0), stone, M.Limestone)
	for f = 0, floors - 1 do
		solid(m, V(w - 0.4, 0.5, d - 0.4), cf * CF(0, plinth + f * fh + 0.25, 0), Palette.wood[1], M.WoodPlanks)
		if f > 0 then
			deco(m, V(w + 0.5, 0.5, d + 0.5), cf * CF(0, plinth + f * fh, 0), trim, M.Limestone)
		end
		local wy = plinth + f * fh + fh * 0.55
		for _, k in { -0.34, 0, 0.34 } do
			if not (f == 0 and k == 0) then
				window(m, cf * CF(k * w, wy, -d / 2), 1.8, 3.6, trim, nil)
				deco(m, V(2.6, 0.5, 0.5), cf * CF(k * w, wy + 2.2, -d / 2 - 0.2), trim, M.Limestone)
			end
			window(m, cf * CF(k * w, wy, d / 2) * ANG(0, math.pi, 0), 1.8, 3.6, trim, nil)
		end
		window(m, cf * CF(-w / 2, wy, 0) * ANG(0, math.pi / 2, 0), 1.8, 3.4, trim, nil)
		window(m, cf * CF(w / 2, wy, 0) * ANG(0, -math.pi / 2, 0), 1.8, 3.4, trim, nil)
	end
	-- corner quoins
	for _, x in { -w / 2, w / 2 } do
		for _, z in { -d / 2, d / 2 } do
			deco(m, V(1.3, H, 1.3), cf * CF(x, plinth + H / 2, z), trim, M.Limestone)
		end
	end
	-- cornice + balcony over the door
	deco(m, V(w + 1.2, 0.9, d + 1.2), cf * CF(0, plinth + H + 0.1, 0), trim, M.Limestone)
	solid(m, V(doorW + 3, 0.6, 2.4), cf * CF(0, plinth + fh, -d / 2 - 1.2), trim, M.Limestone)
	deco(m, V(doorW + 3, 1.4, 0.3), cf * CF(0, plinth + fh + 1, -d / 2 - 2.3), Palette.metal.dark, M.Metal)
	local door = deco(m, V(doorW - 0.6, doorH - 0.3, 0.3), cf * CF(0, plinth + (doorH - 0.3) / 2, -d / 2 - 0.05), rgb(70, 40, 30), M.WoodPlanks)
	door.Name = "Door"
	deco(m, V(doorW + 1, 0.8, 0.6), cf * CF(0, plinth + doorH + 0.4, -d / 2 - 0.1), trim, M.Limestone)
	-- steps
	deco(m, V(doorW + 2, 0.5, 1.6), cf * CF(0, 0.25, -d / 2 - 1.2), Palette.shade(stone, 0.85), M.Slate)
	-- hipped-ish roof: steep gable + stepped ends
	local ridgeY = B.gableRoof(m, cf, w - 2, d, plinth + H + 0.5, math.rad(40), roofC, M.Slate, { gable = trim, gableMat = M.Limestone, endOverhang = 1 })
	for _, x in { -1, 1 } do
		for i = 0, 2 do
			local s = 1 - i * 0.3
			deco(m, V(1.4, (ridgeY - plinth - H) * s, d * s), cf * CF(x * (w / 2 - 0.6 - i * 0.9), plinth + H + 0.5 + (ridgeY - plinth - H) * s / 2, 0), Palette.shade(roofC, 0.95), M.Slate)
		end
	end
	for _, x in { -w * 0.3, w * 0.3 } do
		solid(m, V(1.6, 5, 1.6), cf * CF(x, ridgeY - 1, d * 0.1), Palette.shade(stone, 0.9), M.Brick)
	end
	return m, (cf * CF(0, 0, -d / 2 - 3.5)).Position
end

-- ------------------------------------------------------------------ Norse longhouse
-- opts: {len, w, wallH, turf, wall, rng, shields}
function B.longhouse(parent: Instance, cf: CFrame, o)
	o = o or {}
	local rng = rngOf(o)
	local L, W = o.len or rng:int(26, 36), o.w or rng:int(11, 14)
	local wallH = o.wallH or 5.5
	local wood = o.wall or rng:pick({ rgb(96, 66, 42), rgb(84, 58, 38), rgb(110, 76, 48) })
	local roofC = if o.turf ~= false then Palette.jitter(rgb(90, 130, 60), 0.15, rng:float()) else rgb(196, 170, 96)
	local roofMat = if o.turf ~= false then M.Grass else M.Fabric
	local m = Kit.model(o.name or "Longhouse", parent)
	-- the long axis is local Z; the door is on the -Z gable end
	solid(m, V(W + 1, 0.8, L + 1), cf * CF(0, 0.4, 0), rgb(120, 112, 100), M.Cobblestone)
	for _, sx in { -1, 1 } do
		solid(m, V(1, wallH, L), cf * CF(sx * (W / 2 - 0.5), 0.8 + wallH / 2, 0), wood, M.WoodPlanks)
		-- vertical posts along the walls
		for i = 0, 4 do
			deco(m, V(0.6, wallH + 0.4, 0.6), cf * CF(sx * (W / 2 + 0.05), 0.8 + wallH / 2, -L / 2 + i * L / 4), Palette.shade(wood, 0.75), M.WoodPlanks)
		end
	end
	local doorW, doorH = 3.4, 5
	local side = (W - doorW) / 2
	for _, z in { -L / 2 + 0.5, L / 2 - 0.5 } do
		if z < 0 then
			solid(m, V(side, wallH, 1), cf * CF(-(doorW / 2 + side / 2), 0.8 + wallH / 2, z), wood, M.WoodPlanks)
			solid(m, V(side, wallH, 1), cf * CF(doorW / 2 + side / 2, 0.8 + wallH / 2, z), wood, M.WoodPlanks)
		else
			solid(m, V(W, wallH, 1), cf * CF(0, 0.8 + wallH / 2, z), wood, M.WoodPlanks)
		end
	end
	-- roof along Z: rotate the gable helper 90 degrees
	local rcf = cf * ANG(0, math.pi / 2, 0)
	local pitch = math.rad(52)
	local ridgeY = B.gableRoof(m, rcf, L, W, 0.8 + wallH - 0.3, pitch, roofC, roofMat, { overhang = 1.6, endOverhang = 0.6, thick = 1.2, gable = wood, gableMat = M.WoodPlanks, ridgeColor = Palette.shade(roofC, 0.8) })
	-- crossed barge boards at both gable peaks (dragon style)
	for _, z in { -L / 2 - 0.6, L / 2 + 0.6 } do
		for _, sx in { -1, 1 } do
			deco(m, V(0.5, 5.5, 0.5), cf * CF(sx * 0.9, ridgeY - 0.6, z) * ANG(0, 0, sx * 0.62), Palette.shade(wood, 0.7), M.WoodPlanks)
		end
		deco(m, V(0.6, 0.6, 0.6), cf * CF(0, ridgeY + 1.6, z), Palette.shade(wood, 0.7), M.WoodPlanks)
	end
	-- porch
	for _, sx in { -1, 1 } do
		solid(m, V(0.7, 5.2, 0.7), cf * CF(sx * 2.4, 0.8 + 2.6, -L / 2 - 3.5), Palette.shade(wood, 0.8), M.WoodPlanks)
	end
	deco(m, V(6.2, 0.6, 4.6), cf * CF(0, 0.8 + 5.4, -L / 2 - 2) * ANG(-0.2, 0, 0), roofC, roofMat)
	local door = deco(m, V(doorW - 0.4, doorH - 0.2, 0.3), cf * CF(0, 0.8 + (doorH - 0.2) / 2, -L / 2 - 0.05), rgb(60, 40, 28), M.WoodPlanks)
	door.Name = "Door"
	-- painted shields on the long walls
	if o.shields ~= false then
		for _, sx in { -1, 1 } do
			for i = 1, 3 do
				local col = rng:pick({ rgb(170, 30, 36), rgb(40, 70, 140), rgb(220, 190, 70), rgb(236, 232, 220), rgb(40, 110, 60) })
				Kit.cyl(m, 0.3, 2.6, cf * CF(sx * (W / 2 + 0.25), 0.8 + wallH * 0.55, -L / 2 + i * L / 4), col, M.WoodPlanks, { CanCollide = false })
			end
		end
	end
	-- smoke hole
	local hole = deco(m, V(1.4, 1.2, 2.2), cf * CF(0, ridgeY + 0.2, 0), Palette.shade(wood, 0.6), M.WoodPlanks)
	if rng:chance(0.6) then
		Kit.emitter(hole, { Texture = Kit.SMOKE, Color = ColorSequence.new(rgb(120, 118, 122)), LightEmission = 0, Rate = 3, Speed = NumberRange.new(2, 4), Lifetime = NumberRange.new(4, 6), Size = NumberSequence.new(2, 6), Transparency = NumberSequence.new(0.5, 1), Acceleration = V(1, 1.4, 0), EmissionDirection = Enum.NormalId.Top })
	end
	return m, (cf * CF(0, 0, -L / 2 - 5)).Position
end

-- ------------------------------------------------------------------ church
function B.church(parent: Instance, cf: CFrame, o)
	o = o or {}
	local rng = rngOf(o)
	local stone = o.wall or rgb(200, 194, 180)
	local roofC = o.roof or rgb(80, 86, 96)
	local m = Kit.model("Church", parent)
	local W, L, H = 18, 34, 15
	solid(m, V(W + 1.5, 1.2, L + 1.5), cf * CF(0, 0.6, 0), Palette.shade(stone, 0.8), M.Slate)
	for _, sx in { -1, 1 } do
		solid(m, V(1.2, H, L), cf * CF(sx * (W / 2 - 0.6), 1.2 + H / 2, 0), stone, M.Limestone)
		for i = 1, 4 do
			local z = -L / 2 + i * L / 5
			deco(m, V(0.2, 6, 2), cf * CF(sx * (W / 2 + 0.02), 1.2 + H * 0.55, z), rgb(120, 150, 200), M.Glass, { Transparency = 0.15 })
			deco(m, V(1.2, H + 1, 1.2), cf * CF(sx * (W / 2 + 0.4), 1.2 + (H + 1) / 2, z - L / 10), Palette.shade(stone, 0.92), M.Limestone)
		end
	end
	solid(m, V(W, H, 1.2), cf * CF(0, 1.2 + H / 2, L / 2 - 0.6), stone, M.Limestone)
	local ridge = B.gableRoof(m, cf * ANG(0, math.pi / 2, 0), L, W, 1.2 + H, math.rad(50), roofC, M.Slate, { gable = stone, gableMat = M.Limestone, overhang = 1 })
	-- bell tower on the front
	local tw = 11
	local tH = H + 24
	local tz = -L / 2 - tw / 2 + 1
	solid(m, V(tw, tH, tw), cf * CF(0, 1.2 + tH / 2, tz), stone, M.Limestone)
	for _, n in { V(0, 0, -1), V(1, 0, 0), V(-1, 0, 0) } do
		deco(m, V(if n.X ~= 0 then 0.3 else 4, 6, if n.Z ~= 0 then 0.3 else 4), cf * CF(n * (tw / 2 + 0.05) + V(0, 1.2 + tH - 5, tz)), rgb(20, 18, 22))
	end
	local rose = deco(m, V(4.4, 4.4, 0.3), cf * CF(0, 1.2 + H * 0.7, tz - tw / 2 - 0.1) * ANG(0, 0, math.pi / 4), rgb(170, 60, 90), M.Glass, { Transparency = 0.1 })
	deco(m, V(3.4, 3.4, 0.35), cf * CF(0, 1.2 + H * 0.7, tz - tw / 2 - 0.12), rgb(90, 140, 220), M.Glass, { Transparency = 0.1 })
	-- stepped spire
	for i = 0, 6 do
		local s = tw + 1 - i * 1.6
		deco(m, V(s, 3, s), cf * CF(0, 1.2 + tH + 1.5 + i * 3, tz), Palette.shade(roofC, 1 - i * 0.03), M.Slate)
	end
	deco(m, V(0.4, 5, 0.4), cf * CF(0, 1.2 + tH + 23, tz), Palette.metal.gold, M.Metal)
	deco(m, V(2.4, 0.4, 0.4), cf * CF(0, 1.2 + tH + 24, tz), Palette.metal.gold, M.Metal)
	local door = deco(m, V(4, 7, 0.4), cf * CF(0, 1.2 + 3.5, tz - tw / 2 - 0.05), rgb(70, 42, 30), M.WoodPlanks)
	door.Name = "Door"
	deco(m, V(5.4, 1, 0.6), cf * CF(0, 1.2 + 7.5, tz - tw / 2 - 0.1), Palette.shade(stone, 1.1), M.Limestone)
	return m, (cf * CF(0, 0, tz - tw / 2 - 4)).Position
end

-- ------------------------------------------------------------------ windmill (sails spin on clients: tag "Rotor")
function B.windmill(parent: Instance, pos: Vector3, facing: number?, o)
	o = o or {}
	local m = Kit.model("Windmill", parent)
	local cf = CF(pos) * ANG(0, facing or 0, 0)
	local wall = o.wall or rgb(226, 214, 190)
	solid(m, V(11, 5, 11), cf * CF(0, 2.5, 0), rgb(150, 144, 132), M.Cobblestone)
	for i = 0, 2 do
		local s = 10 - i * 1.6
		solid(m, V(s, 7, s), cf * CF(0, 5 + 3.5 + i * 7, 0), Palette.shade(wall, 1 - i * 0.04), M.Plaster)
		deco(m, V(s + 0.3, 0.5, s + 0.3), cf * CF(0, 5 + i * 7, 0), rgb(80, 56, 38), M.WoodPlanks)
	end
	local top = 5 + 21
	B.gableRoof(m, cf * ANG(0, math.pi / 2, 0), 7.2, 6.4, top, math.rad(48), rgb(110, 56, 44), M.RoofShingles, { overhang = 0.8, gable = rgb(90, 64, 44), gableMat = M.WoodPlanks })
	deco(m, V(2.4, 3, 0.3), cf * CF(0, 7, -5.6), rgb(70, 44, 30), M.WoodPlanks).Name = "Door"
	for _, y in { 12, 19 } do
		window(m, cf * CF(0, y, -(10 - (y - 12) / 7 * 1.6) / 2), 1.2, 1.6, rgb(80, 56, 38), nil)
	end
	local hubPos = cf * CF(0, top + 1.5, -4.8)
	local rotor = Kit.model("Sails", m)
	local hub = deco(rotor, V(1.6, 1.6, 1.6), hubPos, rgb(70, 50, 36), M.WoodPlanks)
	for i = 0, 3 do
		local a = hubPos * ANG(0, 0, i * math.pi / 2)
		deco(rotor, V(0.5, 15, 0.5), a * CF(0, 7.5, -0.4), rgb(90, 64, 44), M.WoodPlanks)
		deco(rotor, V(3.4, 11, 0.14), a * CF(1.9, 8.8, -0.5), rgb(236, 230, 214), M.Fabric)
		for k = 0, 3 do
			deco(rotor, V(3.6, 0.2, 0.2), a * CF(1.9, 4 + k * 3.2, -0.6), rgb(90, 64, 44), M.WoodPlanks)
		end
	end
	rotor.WorldPivot = hubPos
	rotor:SetAttribute("Speed", o.speed or 0.5)
	CollectionService:AddTag(rotor, "Rotor")
	return m
end

-- ------------------------------------------------------------------ watchtower
function B.watchtower(parent: Instance, pos: Vector3, o)
	o = o or {}
	local m = Kit.model("Watchtower", parent)
	local h = o.height or 18
	local wood = o.wood or rgb(100, 70, 46)
	for _, x in { -2.6, 2.6 } do
		for _, z in { -2.6, 2.6 } do
			solid(m, V(1, h, 1), CF(pos + V(x, h / 2, z)), wood, M.WoodPlanks)
		end
	end
	solid(m, V(7.6, 0.8, 7.6), CF(pos + V(0, h - 3, 0)), Palette.shade(wood, 1.1), M.WoodPlanks)
	for _, o2 in { V(3.6, 0, 0), V(-3.6, 0, 0), V(0, 0, 3.6), V(0, 0, -3.6) } do
		solid(m, if o2.X ~= 0 then V(0.4, 2.4, 7.6) else V(7.6, 2.4, 0.4), CF(pos + o2 + V(0, h - 1.4, 0)), wood, M.WoodPlanks)
	end
	for i = 0, 2 do
		local s = 9 - i * 2.8
		deco(m, V(s, 1.6, s), CF(pos + V(0, h + 0.8 + i * 1.6, 0)), Palette.shade(rgb(110, 60, 44), 1 - i * 0.05), M.RoofShingles)
	end
	-- ladder
	for i = 0, math.floor((h - 3) / 1.5) do
		deco(m, V(1.6, 0.2, 0.2), CF(pos + V(0, 1 + i * 1.5, -3.2)), wood, M.WoodPlanks)
	end
	deco(m, V(0.2, h - 3, 0.2), CF(pos + V(-0.8, (h - 3) / 2, -3.2)), wood, M.WoodPlanks)
	deco(m, V(0.2, h - 3, 0.2), CF(pos + V(0.8, (h - 3) / 2, -3.2)), wood, M.WoodPlanks)
	if o.torch ~= false then
		S.World.torch(m, CF(pos + V(3, h - 2.6, -3)))
	end
	return m, pos + V(0, h - 2, 0)
end

-- ------------------------------------------------------------------ palisade
-- pts: list of ground points (a polyline). gaps: {index = true} skips a segment.
function B.palisade(parent: Instance, pts, height: number?, o)
	o = o or {}
	local m = Kit.model("Palisade", parent)
	local h = height or 9
	local wood = o.wood or rgb(104, 74, 48)
	local step = o.step or 2.1
	for i = 1, #pts - 1 do
		if not (o.gaps and o.gaps[i]) then
			local a, b = pts[i], pts[i + 1]
			local d = b - a
			local len = V(d.X, 0, d.Z).Magnitude
			local n = math.max(1, math.floor(len / step))
			local dir = V(d.X, 0, d.Z).Unit
			local yaw = math.atan2(-dir.X, -dir.Z)
			for k = 0, n - 1 do
				local p = a + d * ((k + 0.5) / n)
				local hh = h + ((k * 7 + i * 3) % 5) * 0.3
				local g = if o.groundY then V(p.X, o.groundY(p.X, p.Z), p.Z) else (S.World.ground(p) or p)
				local c = CF(p.X, g.Y + hh / 2 - 1, p.Z) * ANG(0, yaw, 0)
				solid(m, V(step - 0.1, hh, 1.6), c, Palette.shade(wood, 0.92 + ((k + i) % 3) * 0.05), M.WoodPlanks)
				deco(m, V(step * 0.72, step * 0.72, 1.5), c * CF(0, hh / 2, 0) * ANG(0, 0, math.pi / 4), Palette.shade(wood, 0.8), M.WoodPlanks)
			end
			-- walkway rail on the inside
			if o.rail then
				deco(m, V(0.4, 0.4, len), CFrame.lookAt((a + b) / 2 + V(0, h - 3, 0), b + V(0, h - 3, 0)) * CF(1.2, 0, 0), Palette.shade(wood, 0.8), M.WoodPlanks)
			end
		end
	end
	return m
end

-- ------------------------------------------------------------------ the Great Wall
-- A ring wall around `center`. gates: list of angles (0 = +Z). Returns {gates = {{pos, angle, film}}}
function B.greatWall(parent: Instance, center: Vector3, radius: number, height: number, thick: number, o)
	o = o or {}
	local m = Kit.model(o.name or "GreatWall", parent)
	local stone = o.color or rgb(182, 174, 160)
	local dark = Palette.shade(stone, 0.8)
	local light = Palette.shade(stone, 1.08)
	local gates = o.gates or {}
	local gateW = o.gateWidth or 26
	local circ = 2 * math.pi * radius
	local segs = math.max(12, math.floor(circ / (o.segment or 48)))
	local segLen = circ / segs
	local refs = { gates = {} }
	-- a segment is dropped when any part of it overlaps a gate opening
	local function nearGate(a: number): boolean
		for _, g in gates do
			local diff = math.abs(((a - g + math.pi) % (2 * math.pi)) - math.pi)
			if diff * radius < gateW / 2 + segLen / 2 + 2 then
				return true
			end
		end
		return false
	end
	local baseY = center.Y
	for i = 0, segs - 1 do
		local a0 = i / segs * math.pi * 2
		local a1 = (i + 1) / segs * math.pi * 2
		local am = (a0 + a1) / 2
		if not nearGate(am) then
			local p0 = center + V(math.sin(a0) * radius, 0, math.cos(a0) * radius)
			local p1 = center + V(math.sin(a1) * radius, 0, math.cos(a1) * radius)
			local mid = (p0 + p1) / 2
			local len = (p1 - p0).Magnitude + 0.6
			local c = CFrame.lookAt(V(mid.X, baseY, mid.Z), V(p1.X, baseY, p1.Z))
			-- slightly battered (wider at the bottom)
			solid(m, V(thick + 4, height * 0.18, len + 1), c * CF(0, height * 0.09, 0), dark, M.Slate)
			solid(m, V(thick, height, len), c * CF(0, height / 2, 0), if i % 2 == 0 then stone else Palette.shade(stone, 0.97), M.Slate)
			for _, k in { 0.35, 0.62 } do
				deco(m, V(thick + 0.6, 1.2, len + 0.2), c * CF(0, height * k, 0), light, M.Limestone)
			end
			-- parapet on the outside edge (+X of a lookAt along the ring) + merlons
			local outX = thick / 2 - 1
			solid(m, V(2, 3.2, len), c * CF(outX, height + 1.6, 0), light, M.Limestone)
			for k = 0, math.floor(len / 7) - 1 do
				solid(m, V(2, 2.4, 3), c * CF(outX, height + 4.4, -len / 2 + 2 + k * 7), light, M.Limestone)
			end
			solid(m, V(1.2, 2.2, len), c * CF(-thick / 2 + 0.6, height + 1.1, 0), light, M.Limestone)
			-- inner buttresses every other segment
			if i % 2 == 0 then
				solid(m, V(6, height * 0.92, 8), c * CF(-(thick / 2 + 3), height * 0.46, 0), Palette.shade(stone, 0.93), M.Slate)
			end
			-- cannons every few segments, pointing out
			if o.cannons ~= false and i % 5 == 0 then
				local cc = c * CF(thick / 2 - 4, height + 1.2, 0)
				Kit.cyl(m, 5, 1.3, cc * CF(0.8, 0, 0), Palette.metal.dark, M.Metal, { CanCollide = false })
				deco(m, V(3, 1.4, 2.4), cc * CF(-0.6, -0.6, 0), Palette.wood[4], M.WoodPlanks)
			end
		end
	end
	-- gatehouses
	for _, g in gates do
		local dir = V(math.sin(g), 0, math.cos(g))
		local p = center + dir * radius
		local c = CFrame.lookAt(V(p.X, baseY, p.Z), V(p.X, baseY, p.Z) + dir)
		local gh = Kit.model("Gatehouse", m)
		-- the towers are wide enough to close the gap left by the dropped segments
		local towerW = math.max(14, segLen + 6)
		for _, sx in { -1, 1 } do
			local tp = c * CF(sx * (gateW / 2 + towerW / 2), 0, 0)
			solid(gh, V(towerW, height + 16, thick + 10), tp * CF(0, (height + 16) / 2, 0), Palette.shade(stone, 0.95), M.Slate)
			for _, k in { 0.3, 0.55, 0.8 } do
				deco(gh, V(towerW + 1, 1.2, thick + 11), tp * CF(0, height * k, 0), light, M.Limestone)
			end
			for k = -1, 1 do
				solid(gh, V(3, 3, 3), tp * CF(k * 5, height + 17.5, -(thick + 10) / 2 + 1.5), light, M.Limestone)
			end
			deco(gh, V(3, 6, 0.4), tp * CF(0, height * 0.7, (thick + 10) / 2 + 0.1), rgb(20, 18, 22))
			deco(gh, V(3, 6, 0.4), tp * CF(0, height * 0.7, -(thick + 10) / 2 - 0.1), rgb(20, 18, 22))
		end
		-- lintel above the gate + portcullis bars (raised) + arch trim
		local archH = o.gateHeight or math.min(height * 0.45, 60)
		solid(gh, V(gateW + 2, height - archH + 6, thick + 6), c * CF(0, archH + (height - archH + 6) / 2, 0), stone, M.Slate)
		deco(gh, V(gateW + 3, 2, thick + 7), c * CF(0, archH + 1, 0), light, M.Limestone)
		for k = -4, 4 do
			deco(gh, V(0.6, archH * 0.3, 0.6), c * CF(k * gateW / 9, archH - archH * 0.15, 0), Palette.metal.dark, M.Metal)
		end
		deco(gh, V(gateW, 0.6, 0.6), c * CF(0, archH * 0.7, 0), Palette.metal.dark, M.Metal)
		-- banners
		for _, sx in { -1, 1 } do
			deco(gh, V(6, 18, 0.3), c * CF(sx * (gateW / 2 + towerW / 2), height - 12, -(thick + 10) / 2 - 0.3), o.banner or rgb(150, 30, 36), M.Fabric)
			deco(gh, V(2.4, 2.4, 0.35), c * CF(sx * (gateW / 2 + towerW / 2), height - 8, -(thick + 10) / 2 - 0.4), o.emblem or Palette.metal.gold, M.Metal)
		end
		table.insert(refs.gates, { pos = p, angle = g, cf = c, height = archH })
	end
	refs.model = m
	return refs
end

-- ------------------------------------------------------------------ bridge
function B.bridge(parent: Instance, a: Vector3, b: Vector3, width: number, o)
	o = o or {}
	local m = Kit.model("Bridge", parent)
	local stone = o.color or rgb(160, 154, 144)
	local flat = V(b.X - a.X, 0, b.Z - a.Z)
	local len = flat.Magnitude
	local c = CFrame.lookAt(a, a + flat)
	local rise = o.rise or math.min(6, len * 0.12)
	local n = 6
	for i = 0, n - 1 do
		local t0, t1 = i / n, (i + 1) / n
		local y0 = math.sin(t0 * math.pi) * rise
		local y1 = math.sin(t1 * math.pi) * rise
		local p0 = V(0, y0, -t0 * len)
		local p1 = V(0, y1, -t1 * len)
		local mid = (p0 + p1) / 2
		local segLen = (p1 - p0).Magnitude + 0.3
		local sc = c * CFrame.lookAt(mid, p1)
		solid(m, V(width, 1.2, segLen), sc, stone, M.Cobblestone)
		for _, sx in { -1, 1 } do
			solid(m, V(1, 2.4, segLen), sc * CF(sx * (width / 2 - 0.5), 1.8, 0), Palette.shade(stone, 1.05), M.Limestone)
		end
	end
	-- piers
	for _, t in { 0.3, 0.7 } do
		local y = math.sin(t * math.pi) * rise
		solid(m, V(width - 2, y + 12, 4), c * CF(0, y - 6.5, -t * len), Palette.shade(stone, 0.85), M.Slate)
	end
	return m
end

-- ------------------------------------------------------------------ dock + longship
function B.dock(parent: Instance, cf: CFrame, len: number, width: number?)
	local m = Kit.model("Dock", parent)
	local w = width or 8
	local wood = rgb(110, 80, 52)
	solid(m, V(w, 0.8, len), cf * CF(0, 0, -len / 2), wood, M.WoodPlanks)
	for i = 0, math.floor(len / 8) do
		for _, sx in { -1, 1 } do
			solid(m, V(1, 10, 1), cf * CF(sx * (w / 2 - 0.3), -4.5, -i * 8), Palette.shade(wood, 0.8), M.WoodPlanks)
		end
	end
	for _, sx in { -1, 1 } do
		deco(m, V(0.8, 2, 0.8), cf * CF(sx * (w / 2 - 0.4), 1.4, -len + 1), Palette.shade(wood, 0.7), M.WoodPlanks)
	end
	return m
end

function B.longship(parent: Instance, cf: CFrame, o)
	o = o or {}
	local rng = rngOf(o)
	local m = Kit.model("Longship", parent)
	local L = o.len or 38
	local hull = o.hull or rgb(92, 64, 42)
	local dark = Palette.shade(hull, 0.75)
	-- hull: keel + two strakes per side, stepped outward
	solid(m, V(2.4, 1.6, L - 6), cf * CF(0, 0, 0), dark, M.WoodPlanks)
	for k, off in { { 2.2, 1.2 }, { 3.4, 2.6 } } do
		for _, sx in { -1, 1 } do
			solid(m, V(1, 1.6, L - 4 - k * 2), cf * CF(sx * off[1], off[2], 0) * ANG(0, 0, -sx * 0.25), if k == 1 then hull else Palette.shade(hull, 1.1), M.WoodPlanks)
		end
	end
	solid(m, V(6.6, 0.5, L - 10), cf * CF(0, 1.9, 0), Palette.shade(hull, 1.15), M.WoodPlanks)
	-- rising prow and stern
	for _, sz in { -1, 1 } do
		local base = cf * CF(0, 1, sz * (L / 2 - 3))
		local seg = base
		for i = 1, 5 do
			seg = seg * CF(0, 1.3, sz * 1.1) * ANG(sz * -0.28, 0, 0)
			solid(m, V(1.6 - i * 0.12, 1.8, 1.6), seg, if i % 2 == 0 then dark else hull, M.WoodPlanks)
		end
		if sz < 0 then
			-- dragon head
			local h = seg * CF(0, 1, -0.6)
			solid(m, V(1.2, 1.2, 2.2), h, dark, M.WoodPlanks)
			deco(m, V(0.2, 0.8, 0.8), h * CF(0.6, 0.6, 0.4) * ANG(0.5, 0, 0), dark, M.WoodPlanks)
			deco(m, V(0.2, 0.8, 0.8), h * CF(-0.6, 0.6, 0.4) * ANG(0.5, 0, 0), dark, M.WoodPlanks)
			deco(m, V(0.2, 0.2, 0.1), h * CF(0.5, 0.2, -0.9), rgb(220, 40, 30), M.Neon)
			deco(m, V(0.2, 0.2, 0.1), h * CF(-0.5, 0.2, -0.9), rgb(220, 40, 30), M.Neon)
		end
	end
	-- shields along the gunwale
	local cols = { rgb(170, 30, 36), rgb(236, 232, 220), rgb(40, 70, 140), rgb(220, 190, 70) }
	for i = 0, 7 do
		for _, sx in { -1, 1 } do
			Kit.cyl(m, 0.3, 2.2, cf * CF(sx * 4.2, 3.4, -L / 2 + 6 + i * (L - 12) / 7) * ANG(0, 0, sx * 0.25), cols[(i % #cols) + 1], M.WoodPlanks, { CanCollide = false })
		end
	end
	-- mast, yard and a striped sail
	solid(m, V(0.8, 20, 0.8), cf * CF(0, 11, 0), dark, M.WoodPlanks)
	deco(m, V(16, 0.6, 0.6), cf * CF(0, 19, 0), dark, M.WoodPlanks)
	local sa, sb = o.sail or rgb(170, 36, 40), rgb(236, 230, 214)
	for i = 0, 4 do
		deco(m, V(3, 11, 0.14), cf * CF(-6 + i * 3, 13.2, -0.6), if i % 2 == 0 then sa else sb, M.Fabric)
	end
	return m
end

-- ------------------------------------------------------------------ props
function B.cart(parent: Instance, cf: CFrame)
	local m = Kit.model("Cart", parent)
	local wood = rgb(120, 86, 54)
	solid(m, V(4, 0.5, 6), cf * CF(0, 2.2, 0), wood, M.WoodPlanks)
	for _, sx in { -1, 1 } do
		solid(m, V(0.3, 1.2, 6), cf * CF(sx * 1.85, 3, 0), Palette.shade(wood, 0.9), M.WoodPlanks)
		Kit.cyl(m, 0.4, 3.4, cf * CF(sx * 2.3, 1.7, 0.8), Palette.shade(wood, 0.75), M.WoodPlanks)
		deco(m, V(0.3, 0.3, 4.5), cf * CF(sx * 1.2, 2, -5), wood, M.WoodPlanks)
	end
	solid(m, V(0.3, 1.2, 4), cf * CF(0, 3, 2.85) * ANG(0, math.pi / 2, 0), Palette.shade(wood, 0.9), M.WoodPlanks)
	if math.random() < 0.6 then
		deco(m, V(3.2, 1.2, 4.6), cf * CF(0, 3.1, 0.2), rgb(214, 186, 100), M.Grass)
	end
	return m
end

function B.haystack(parent: Instance, pos: Vector3, s: number?)
	local k = s or 1
	local hay = rgb(214, 184, 96)
	for i = 0, 2 do
		local w = (6 - i * 1.8) * k
		solid(parent, V(w, 2.2 * k, w), CF(pos + V(0, (1.1 + i * 2.2) * k, 0)) * ANG(0, i * 0.4, 0), Palette.shade(hay, 1 - i * 0.05), M.Grass)
	end
end

function B.hayBale(parent: Instance, cf: CFrame)
	return solid(parent, V(3, 2, 2), cf * CF(0, 1, 0), rgb(214, 184, 96), M.Grass)
end

function B.woodpile(parent: Instance, cf: CFrame)
	local m = Kit.model("Woodpile", parent)
	for row = 0, 2 do
		for i = 0, 3 - row do
			Kit.cyl(m, 4, 1, cf * CF(-1.5 + i * 1 + row * 0.5, 0.5 + row * 0.85, 0) * ANG(0, math.pi / 2, 0), Palette.jitter(rgb(130, 94, 60), 0.1, math.random()), M.WoodPlanks, { CanCollide = false })
		end
	end
	return m
end

function B.laundry(parent: Instance, a: Vector3, b: Vector3)
	local m = Kit.model("Laundry", parent)
	for _, p in { a, b } do
		solid(m, V(0.5, 7, 0.5), CF(p + V(0, 3.5, 0)), Palette.wood[3], M.WoodPlanks)
	end
	local mid = (a + b) / 2 + V(0, 6.5, 0)
	local len = (b - a).Magnitude
	deco(m, V(0.08, 0.08, len), CFrame.lookAt(mid, b + V(0, 6.5, 0)), rgb(220, 220, 210))
	local dir = (b - a).Unit
	for i = 1, 3 do
		deco(m, V(0.08, 2.2, 1.8), CFrame.lookAt(a + dir * (len * i / 4) + V(0, 5.3, 0), a + dir * (len * i / 4) + V(0, 5.3, 0) + dir) * ANG(0, math.pi / 2, 0), Palette.jitter(rgb(210, 200, 180), 0.25, math.random()), M.Fabric)
	end
	return m
end

function B.signpost(parent: Instance, pos: Vector3, yaw: number)
	local m = Kit.model("Signpost", parent)
	solid(m, V(0.5, 6, 0.5), CF(pos + V(0, 3, 0)), Palette.wood[2], M.WoodPlanks)
	deco(m, V(3, 0.8, 0.2), CF(pos + V(0, 5, 0)) * ANG(0, yaw, 0) * CF(1.2, 0, 0), Palette.wood[1], M.WoodPlanks)
	deco(m, V(3, 0.8, 0.2), CF(pos + V(0, 4, 0)) * ANG(0, yaw + 2.2, 0) * CF(1.2, 0, 0), Palette.wood[3], M.WoodPlanks)
	return m
end

function B.bench(parent: Instance, cf: CFrame)
	solid(parent, V(4, 0.4, 1.2), cf * CF(0, 1.6, 0), Palette.wood[1], M.WoodPlanks)
	for _, sx in { -1.6, 1.6 } do
		deco(parent, V(0.4, 1.4, 1), cf * CF(sx, 0.7, 0), Palette.wood[4], M.WoodPlanks)
	end
end

function B.fountain(parent: Instance, pos: Vector3, o)
	o = o or {}
	local m = Kit.model("Fountain", parent)
	local stone = o.color or rgb(196, 190, 178)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		solid(m, V(4.6, 2, 1.2), CF(pos + V(math.cos(a) * 5.4, 1, math.sin(a) * 5.4)) * ANG(0, -a + math.pi / 2, 0), stone, M.Limestone)
	end
	deco(m, V(9.6, 0.3, 9.6), CF(pos + V(0, 1.4, 0)), rgb(70, 130, 180), M.Glass, { Transparency = 0.25 })
	solid(m, V(1.6, 5, 1.6), CF(pos + V(0, 2.5, 0)), stone, M.Limestone)
	solid(m, V(4, 0.6, 4), CF(pos + V(0, 4.4, 0)), stone, M.Limestone)
	local top = solid(m, V(1, 1.6, 1), CF(pos + V(0, 5.6, 0)), stone, M.Limestone)
	Kit.emitter(top, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(rgb(200, 230, 255)), LightEmission = 0.3, Rate = 30, Speed = NumberRange.new(5, 7), Lifetime = NumberRange.new(0.6, 0.9), Size = NumberSequence.new(0.35, 0.1), Transparency = NumberSequence.new(0.2, 1), Acceleration = V(0, -18, 0), SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Top })
	return m
end

function B.stall(parent: Instance, cf: CFrame, color: Color3, rng)
	local m = Kit.model("Stall", parent)
	for _, x in { -3.2, 3.2 } do
		for _, z in { -2.2, 2.2 } do
			solid(m, V(0.5, 6.4, 0.5), cf * CF(x, 3.2, z), Palette.wood[2], M.WoodPlanks)
		end
	end
	solid(m, V(7.4, 1, 4.8), cf * CF(0, 2.6, 0), Palette.wood[1], M.WoodPlanks)
	for i = 0, 3 do
		deco(m, V(1.9, 0.3, 5.6), cf * CF(-2.85 + i * 1.9, 6.5 - 0.0, 0) * ANG(0.14, 0, 0), if i % 2 == 0 then color else rgb(236, 230, 214), M.Fabric)
	end
	local goods = { rgb(220, 60, 50), rgb(240, 200, 60), rgb(120, 200, 80), rgb(200, 120, 60), rgb(160, 110, 70) }
	for i = 1, 5 do
		deco(m, V(1.2, 0.7, 1.2), cf * CF(-2.6 + i * 1.05, 3.45, rng:float(-1.4, 1.4)), rng:pick(goods), M.SmoothPlastic)
	end
	deco(m, V(1.4, 1, 1.4), cf * CF(4.4, 0.5, 1), Palette.wood[2], M.WoodPlanks)
	return m
end

function B.statue(parent: Instance, pos: Vector3, yaw: number, o)
	o = o or {}
	local m = Kit.model("Statue", parent)
	local stone = o.color or rgb(170, 176, 170)
	local c = CF(pos) * ANG(0, yaw, 0)
	solid(m, V(6, 5, 6), c * CF(0, 2.5, 0), Palette.shade(stone, 0.85), M.Slate)
	solid(m, V(6.6, 0.8, 6.6), c * CF(0, 5.2, 0), Palette.shade(stone, 1.05), M.Limestone)
	local s = o.scale or 2.2
	solid(m, V(1, 2, 1) * s, c * CF(-0.5 * s, 5.6 + s, 0), stone, M.Marble)
	solid(m, V(1, 2, 1) * s, c * CF(0.5 * s, 5.6 + s, 0), stone, M.Marble)
	solid(m, V(2, 2, 1) * s, c * CF(0, 5.6 + 3 * s, 0), stone, M.Marble)
	solid(m, V(1.25, 1.25, 1.25) * s, c * CF(0, 5.6 + 4.62 * s, 0), stone, M.Marble)
	solid(m, V(1, 2, 1) * s, c * CF(-1.5 * s, 5.6 + 3 * s, 0), stone, M.Marble)
	solid(m, V(1, 2, 1) * s, c * CF(1.5 * s, 5.6 + 3.9 * s, -0.4 * s) * ANG(0.9, 0, 0), stone, M.Marble)
	solid(m, V(0.3, 5, 0.3) * s, c * CF(1.5 * s, 5.6 + 5.6 * s, -1.5 * s) * ANG(0.2, 0, 0), Palette.shade(stone, 0.9), M.Marble)
	return m
end

return B
