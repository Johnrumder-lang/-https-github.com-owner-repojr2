--!nonstrict
-- Furniture and small props for the prologue interiors. Every builder takes a
-- CityKit builder `B` and a local frame `F` standing on the floor under the
-- item's centre, with F.LookVector = the item's front (local -Z is "front").
-- Sitting furniture returns the rig ROOT CFrame for Anim's "Sit"/"Type" poses
-- (torso lowered 1 stud, legs horizontal): root.y = seat top + 2.5.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Kit = require(Shared.Kit)
local CityKit = require(script.Parent.CityKit)

local IK = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB
local Mt = CityKit.M

IK.SIT_ABOVE_SEAT = 2.5

-- Dining chair: legs, seat with cushion, back posts, rails and spindles.
function IK.chair(B, F: CFrame, wood: Color3, cushion: Color3?)
	local legT = 0.26
	for _, sx in { -1, 1 } do
		-- front legs
		B:lbox(F, sx * 0.85 - legT / 2, sx * 0.85 + legT / 2, 0, 1.92, -0.85 - legT / 2, -0.85 + legT / 2, wood, Mt.wood)
		-- rear legs run up into the back posts
		B:lbox(F, sx * 0.85 - legT / 2, sx * 0.85 + legT / 2, 0, 5.1, 0.85 - legT / 2, 0.85 + legT / 2, wood, Mt.wood)
		-- side stretchers
		B:lbox(F, sx * 0.85 - 0.08, sx * 0.85 + 0.08, 0.7, 0.86, -0.72, 0.72, wood, Mt.wood)
	end
	B:lbox(F, -1.05, 1.05, 1.92, 2.07, -1.05, 1.05, wood, Mt.wood) -- seat board
	B:lbox(F, -0.93, 0.93, 2.07, 2.2, -0.95, 0.8, cushion or rgb(150, 60, 50), Mt.fabric) -- cushion
	B:lbox(F, -0.72, 0.72, 4.55, 5.0, 0.76, 0.96, wood, Mt.wood) -- top rail
	B:lbox(F, -0.72, 0.72, 3.2, 3.42, 0.8, 0.92, wood, Mt.wood) -- mid rail
	for _, sx in { -0.36, 0, 0.36 } do
		B:lbox(F, sx - 0.07, sx + 0.07, 3.42, 4.55, 0.82, 0.9, wood, Mt.wood)
	end
	return F * CF(0, 2.2 + IK.SIT_ABOVE_SEAT, 0.3)
end

-- Office chair: 5-star base with casters, gas lift, cushioned seat and back, arms.
function IK.officeChair(B, F: CFrame, fabric: Color3?, turn: number?)
	local G = F * ANG(0, turn or 0, 0)
	local dark = rgb(34, 34, 38)
	local fab = fabric or rgb(40, 44, 56)
	for k = 0, 4 do
		local a = k * math.pi * 2 / 5 + 0.3
		local L = G * ANG(0, a, 0)
		B:deco(V(0.26, 0.18, 1.5), L * CF(0, 0.52, -0.78), dark, Mt.metal)
		B:cyl(0.22, 0.34, L * CF(0, 0.2, -1.45), rgb(20, 20, 22), Mt.rubber)
	end
	B:cyl(0.36, 0.55, G * CF(0, 0.5, 0) * ANG(0, 0, math.pi / 2), dark, Mt.metal)
	B:cyl(1.3, 0.3, G * CF(0, 1.25, 0) * ANG(0, 0, math.pi / 2), rgb(150, 150, 156), Mt.metal)
	B:cyl(0.55, 0.42, G * CF(0, 0.85, 0) * ANG(0, 0, math.pi / 2), dark, Mt.plastic)
	B:lbox(G, -0.5, 0.5, 1.72, 1.9, -0.5, 0.5, dark, Mt.metal) -- mechanism
	B:lbox(G, -1.1, 1.1, 1.9, 2.2, -1.1, 1.0, fab, Mt.fabric) -- seat
	B:lbox(G, -1.0, 1.0, 1.84, 1.9, -1.0, 0.9, dark, Mt.plastic) -- seat shell
	B:lbox(G, -0.18, 0.18, 1.9, 3.05, 1.0, 1.22, dark, Mt.metal) -- spine
	B:lbox(G, -1.0, 1.0, 2.9, 5.3, 1.0, 1.32, fab, Mt.fabric) -- backrest
	B:lbox(G, -0.92, 0.92, 3.0, 5.2, 1.32, 1.42, dark, Mt.plastic) -- back shell
	B:lbox(G, -0.7, 0.7, 3.2, 3.9, 0.9, 1.0, Color3.new(fab.R * 0.85, fab.G * 0.85, fab.B * 0.85), Mt.fabric) -- lumbar
	for _, sx in { -1, 1 } do
		B:lbox(G, sx * 1.2 - 0.1, sx * 1.2 + 0.1, 2.0, 3.1, 0.0, 0.25, dark, Mt.metal)
		B:lbox(G, sx * 1.2 - 0.17, sx * 1.2 + 0.17, 3.1, 3.28, -0.75, 0.55, dark, Mt.leather)
	end
	return G * CF(0, 2.2 + IK.SIT_ABOVE_SEAT, 0.3)
end

-- Plain table: top, legs, short aprons (long sides left open for knees).
function IK.table(B, F: CFrame, w: number, d: number, h: number, top: Color3, legC: Color3?, mat: Enum.Material?)
	local t = 0.25
	B:lbox(F, -w / 2, w / 2, h - t, h, -d / 2, d / 2, top, mat or Mt.wood, true)
	local lc = legC or top
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local x, z = sx * (w / 2 - 0.45), sz * (d / 2 - 0.45)
			B:lbox(F, x - 0.18, x + 0.18, 0, h - t, z - 0.18, z + 0.18, lc, mat or Mt.wood, true)
		end
		B:lbox(F, sx * (w / 2 - 0.45) - 0.1, sx * (w / 2 - 0.45) + 0.1, h - t - 0.5, h - t, -d / 2 + 0.6, d / 2 - 0.6, lc, mat or Mt.wood)
	end
end

-- Potted plant with layered blocky leaves.
function IK.plant(B, pos: Vector3, scale: number?, potC: Color3?)
	local s = scale or 1
	local pot = potC or rgb(186, 170, 150)
	B:box(pos.X - 0.9 * s, pos.X + 0.9 * s, pos.Y, pos.Y + 1.7 * s, pos.Z - 0.9 * s, pos.Z + 0.9 * s, pot, Mt.concrete, true)
	B:box(pos.X - 1.0 * s, pos.X + 1.0 * s, pos.Y + 1.7 * s, pos.Y + 1.9 * s, pos.Z - 1.0 * s, pos.Z + 1.0 * s, pot, Mt.concrete)
	B:box(pos.X - 0.8 * s, pos.X + 0.8 * s, pos.Y + 1.9 * s, pos.Y + 1.96 * s, pos.Z - 0.8 * s, pos.Z + 0.8 * s, rgb(60, 44, 32), Mt.ground)
	B:deco(V(0.2 * s, 2.2 * s, 0.2 * s), CF(pos + V(0, 2.9 * s, 0)), rgb(80, 64, 40), Mt.wood)
	local greens = { rgb(58, 110, 56), rgb(72, 128, 62), rgb(48, 94, 50), rgb(88, 140, 70) }
	for i = 1, 9 do
		local a = i * 2.39
		local r = (0.3 + (i % 3) * 0.35) * s
		local y = (2.6 + (i % 4) * 0.55) * s
		local leaf = V(1.4 * s, 0.25 * s, 0.7 * s)
		B:deco(leaf, CF(pos + V(math.cos(a) * r, y, math.sin(a) * r)) * ANG(0, -a, 0) * ANG(0, 0, 0.35 + (i % 2) * 0.3), greens[(i % #greens) + 1], Mt.leafy)
	end
end

-- Row of books standing on a shelf: F at the shelf's front-left, books run along +X.
function IK.books(B, F: CFrame, length: number, maxH: number, depth: number, rng)
	local cols = { rgb(150, 40, 40), rgb(40, 70, 130), rgb(210, 190, 140), rgb(40, 100, 70), rgb(120, 90, 60), rgb(30, 30, 34), rgb(190, 120, 50), rgb(90, 60, 110), rgb(220, 220, 214) }
	local x = 0.05
	while x < length - 0.3 do
		local w = rng:float(0.22, 0.45)
		if x + w > length - 0.05 then
			break
		end
		local h = rng:float(maxH * 0.65, maxH * 0.95)
		local lean = if rng:chance(0.08) then 0.25 else 0
		B:deco(V(w, h, depth * rng:float(0.75, 0.95)), F * CF(x + w / 2, h / 2, -depth / 2) * ANG(0, 0, lean), rng:pick(cols), Mt.cardboard)
		x += w + 0.02
		if rng:chance(0.12) then
			x += rng:float(0.3, 0.8)
		end
	end
end

-- Ceiling light: metal rim + Neon diffuser + PointLight (hangs below `pos`, pos = ceiling underside).
function IK.ceilingLight(B, pos: Vector3, color: Color3?, range: number?, bright: number?, shadows: boolean?, size: number?)
	local s = size or 2.4
	B:box(pos.X - s / 2 - 0.15, pos.X + s / 2 + 0.15, pos.Y - 0.25, pos.Y, pos.Z - s / 2 - 0.15, pos.Z + s / 2 + 0.15, rgb(200, 200, 204), Mt.metal)
	local d = B:flat(V(s, 0.12, s), CF(pos + V(0, -0.31, 0)), rgb(255, 244, 222), Mt.neon)
	Kit.pointLight(d, color or rgb(255, 228, 190), range or 26, bright or 1.1, shadows)
	return d
end

-- Pendant lamp on a cord.
function IK.pendant(B, pos: Vector3, drop: number, color: Color3?)
	B:deco(V(0.08, drop, 0.08), CF(pos + V(0, -drop / 2, 0)), rgb(30, 30, 30), Mt.plastic)
	local p = pos + V(0, -drop, 0)
	B:deco(V(1.4, 0.7, 1.4), CF(p + V(0, -0.2, 0)), rgb(40, 44, 46), Mt.metal)
	B:deco(V(1.8, 0.25, 1.8), CF(p + V(0, -0.65, 0)), rgb(40, 44, 46), Mt.metal)
	local bulb = B:flat(V(1.2, 0.1, 1.2), CF(p + V(0, -0.82, 0)), rgb(255, 226, 170), Mt.neon)
	Kit.pointLight(bulb, color or rgb(255, 210, 150), 18, 1.2)
	return bulb
end

-- Curtains + rod for a window opening in a wall. F: frame at the window's
-- bottom centre on the INSIDE wall face, LookVector pointing into the room.
function IK.curtains(B, F: CFrame, w: number, h: number, color: Color3, rng)
	B:lbox(F, -w / 2 - 1.2, w / 2 + 1.2, h + 0.9, h + 1.05, -0.55, -0.4, rgb(60, 60, 64), Mt.metal)
	for _, side in { -1, 1 } do
		local cx = side * (w / 2 + 0.2)
		local cw = rng:float(1.5, 2.1)
		B:lbox(F, cx - cw / 2, cx + cw / 2, -0.9, h + 0.85, -0.5, -0.3, color, Mt.fabric)
		-- folds
		for i = -1, 1 do
			B:lbox(F, cx + i * cw * 0.3 - 0.12, cx + i * cw * 0.3 + 0.12, -0.9, h + 0.8, -0.62, -0.5, Color3.new(color.R * 0.86, color.G * 0.86, color.B * 0.86), Mt.fabric)
		end
	end
end

-- Radiator under a window. F on the floor at the wall face, LookVector into the room.
function IK.radiator(B, F: CFrame, w: number)
	local c = rgb(226, 226, 222)
	B:lbox(F, -w / 2, w / 2, 0.9, 1.1, -0.55, -0.15, c, Mt.metal)
	B:lbox(F, -w / 2, w / 2, 3.1, 3.3, -0.55, -0.15, c, Mt.metal)
	local n = math.floor(w / 0.45)
	for i = 0, n - 1 do
		local x = -w / 2 + 0.2 + i * (w - 0.4) / math.max(1, n - 1)
		B:lbox(F, x - 0.13, x + 0.13, 1.1, 3.1, -0.6, -0.1, c, Mt.metal)
	end
	B:lbox(F, w / 2 - 0.3, w / 2 - 0.1, 0.1, 0.9, -0.4, -0.2, c, Mt.metal)
end

-- Framed picture / poster on a wall. F at the picture centre on the wall face,
-- LookVector away from the wall.
function IK.picture(B, F: CFrame, w: number, h: number, frame: Color3, art: { Color3 })
	B:lbox(F, -w / 2, w / 2, -h / 2, h / 2, -0.12, 0, frame, Mt.wood)
	B:lbox(F, -w / 2 + 0.2, w / 2 - 0.2, -h / 2 + 0.2, h / 2 - 0.2, -0.17, -0.12, art[1], Mt.plastic)
	-- simple blocky "print": horizon + blocks
	if art[2] then
		B:lbox(F, -w / 2 + 0.2, w / 2 - 0.2, -h / 2 + 0.2, -h / 2 + 0.2 + (h - 0.4) * 0.4, -0.2, -0.12, art[2], Mt.plastic)
	end
	if art[3] then
		B:lbox(F, -w * 0.18, w * 0.12, -h * 0.1, h * 0.25, -0.22, -0.12, art[3], Mt.plastic)
	end
end

-- Mug (with handle).
function IK.mug(B, pos: Vector3, color: Color3, turn: number?)
	B:post(0.55, 0.42, pos, color, Mt.plastic)
	B:deco(V(0.1, 0.32, 0.22), CF(pos + V(0, 0.28, 0)) * ANG(0, turn or 0, 0) * CF(0.26, 0, 0), color, Mt.plastic)
	B:disc(0.34, 0.03, pos + V(0, 0.5, 0), rgb(70, 44, 26), Mt.plastic)
end

-- Soda can.
function IK.can(B, pos: Vector3, color: Color3, lying: boolean?)
	if lying then
		B:cyl(0.5, 0.26, CF(pos + V(0, 0.13, 0)) * ANG(0, 0.7, 0), color, Mt.foil)
	else
		B:post(0.5, 0.26, pos, color, Mt.foil)
	end
end

-- Pizza box (lid half open).
function IK.pizzaBox(B, F: CFrame)
	local c = rgb(196, 162, 112)
	B:lbox(F, -1.2, 1.2, 0, 0.3, -1.2, 1.2, c, Mt.cardboard)
	B:deco(V(2.4, 0.06, 2.4), F * CF(0, 0.3, 1.2) * ANG(math.rad(-110), 0, 0) * CF(0, 0, -1.2), c, Mt.cardboard)
	B:disc(1.9, 0.05, (F * CF(0, 0.31, 0)).Position, rgb(210, 150, 70), Mt.fabric)
	B:lbox(F, -0.5, -0.1, 0.33, 0.37, -0.2, 0.3, rgb(170, 50, 40), Mt.fabric)
end

-- Floor lamp: base, pole, fabric shade, Neon bulb.
function IK.floorLamp(B, pos: Vector3, color: Color3?)
	B:disc(1.3, 0.15, pos + V(0, 0.08, 0), rgb(40, 40, 42), Mt.metal)
	B:post(6.4, 0.16, pos, rgb(40, 40, 42), Mt.metal)
	B:post(1.5, 1.8, pos + V(0, 6.1, 0), rgb(236, 226, 200), Mt.fabric)
	local bulb = B:flat(V(0.8, 0.3, 0.8), CF(pos + V(0, 6.2, 0)), rgb(255, 230, 180), Mt.neon)
	Kit.pointLight(bulb, color or rgb(255, 205, 140), 16, 0.9)
	return bulb
end

-- Table lamp.
function IK.tableLamp(B, pos: Vector3, shade: Color3?)
	B:disc(0.7, 0.1, pos + V(0, 0.05, 0), rgb(50, 50, 52), Mt.metal)
	B:post(1.1, 0.12, pos, rgb(170, 150, 110), Mt.metal)
	B:post(0.9, 1.1, pos + V(0, 1.0, 0), shade or rgb(236, 226, 200), Mt.fabric)
	local bulb = B:flat(V(0.5, 0.2, 0.5), CF(pos + V(0, 1.2, 0)), rgb(255, 225, 170), Mt.neon)
	Kit.pointLight(bulb, rgb(255, 200, 140), 12, 0.8)
	return bulb
end

-- Stack of papers.
function IK.papers(B, pos: Vector3, n: number, turn: number?)
	for i = 0, n - 1 do
		B:deco(V(1.1, 0.05, 1.45), CF(pos + V(0, 0.03 + i * 0.06, 0)) * ANG(0, (turn or 0) + (i % 3 - 1) * 0.06, 0), if i % 4 == 3 then rgb(236, 226, 180) else rgb(244, 244, 240), Mt.fabric)
	end
end

-- Laundry heap.
function IK.laundry(B, pos: Vector3, rng)
	local cols = { rgb(60, 70, 110), rgb(200, 200, 196), rgb(40, 40, 44), rgb(150, 40, 40), rgb(90, 110, 80) }
	for i = 1, 5 do
		B:deco(V(rng:float(1.0, 1.8), rng:float(0.25, 0.45), rng:float(0.8, 1.4)), CF(pos + V(rng:float(-0.6, 0.6), 0.15 + i * 0.12, rng:float(-0.5, 0.5))) * ANG(rng:float(-0.2, 0.2), rng:float(0, 3), rng:float(-0.2, 0.2)), rng:pick(cols), Mt.fabric)
	end
end

return IK
