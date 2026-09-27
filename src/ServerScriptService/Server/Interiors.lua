--!nonstrict
-- Every house has an inside. Interiors are built lazily: when a player comes within
-- BUILD_R of a registered house its furniture (and upper floor + stairs) is built
-- and the front door swings open; beyond DROP_R it is torn down again, so a city
-- of hundreds of houses only ever carries a dozen furnished ones.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Kit = require(Shared.Kit)
local Palette = require(Shared.Palette)
local RNG = require(Shared.RNG)

local Interiors = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB
local M = Enum.Material

local BUILD_R = 75
local DROP_R = 120
Interiors.list = {}

local WOOD = { rgb(120, 84, 54), rgb(104, 72, 46), rgb(138, 98, 62), rgb(92, 64, 42) }
local CLOTH = { rgb(150, 50, 44), rgb(60, 90, 140), rgb(90, 120, 70), rgb(170, 140, 70), rgb(120, 70, 110), rgb(200, 190, 170) }

-- info: {kind, cf (ground, front = -Z), w, d, floors, fh, plinth, t, seed, upper = bool (add a floor + stairs)}
function Interiors.register(model: Model, info)
	info.model = model
	info.built = nil
	info.door = model:FindFirstChild("Door")
	if info.door then
		info.doorCF = info.door.CFrame
	end
	table.insert(Interiors.list, info)
	return info
end

-- ------------------------------------------------------------------ furniture
local function box(parent, F: CFrame, x0, x1, y0, y1, z0, z1, color: Color3, mat: Enum.Material?, solid: boolean?)
	local size = V(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	local cf = F * CF((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	if solid then
		return Kit.part(parent, size, cf, color, mat or M.WoodPlanks)
	end
	local p = Kit.deco(parent, size, cf, color, mat or M.WoodPlanks)
	if size.X * size.Y * size.Z < 4 then
		p.CastShadow = false
	end
	return p
end

local function tableAt(p, F: CFrame, x, z, w, d, wood)
	box(p, F, x - w / 2, x + w / 2, 2.6, 3.0, z - d / 2, z + d / 2, wood, M.WoodPlanks, true)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local lx, lz = x + sx * (w / 2 - 0.4), z + sz * (d / 2 - 0.4)
			box(p, F, lx - 0.2, lx + 0.2, 0, 2.6, lz - 0.2, lz + 0.2, Palette.shade(wood, 0.85))
		end
	end
end

local function stool(p, F: CFrame, x, z, wood)
	box(p, F, x - 0.7, x + 0.7, 1.5, 1.8, z - 0.7, z + 0.7, wood, M.WoodPlanks, true)
	box(p, F, x - 0.15, x + 0.15, 0, 1.5, z - 0.15, z + 0.15, Palette.shade(wood, 0.8))
end

local function bench(p, F: CFrame, x, z, len, wood, alongX: boolean)
	if alongX then
		box(p, F, x - len / 2, x + len / 2, 1.5, 1.85, z - 0.6, z + 0.6, wood, M.WoodPlanks, true)
		box(p, F, x - len / 2 + 0.3, x - len / 2 + 0.6, 0, 1.5, z - 0.5, z + 0.5, Palette.shade(wood, 0.8))
		box(p, F, x + len / 2 - 0.6, x + len / 2 - 0.3, 0, 1.5, z - 0.5, z + 0.5, Palette.shade(wood, 0.8))
	else
		box(p, F, x - 0.6, x + 0.6, 1.5, 1.85, z - len / 2, z + len / 2, wood, M.WoodPlanks, true)
	end
end

local function bed(p, F: CFrame, x, z, alongZ: boolean, wood, cloth)
	local w, l = 3.4, 6.4
	local sx, sz = if alongZ then w else l, if alongZ then l else w
	box(p, F, x - sx / 2, x + sx / 2, 0, 1.6, z - sz / 2, z + sz / 2, wood, M.WoodPlanks, true)
	box(p, F, x - sx / 2 + 0.2, x + sx / 2 - 0.2, 1.6, 2.2, z - sz / 2 + 0.2, z + sz / 2 - 0.2, rgb(230, 224, 206), M.Fabric)
	-- blanket over two thirds, pillow at the head
	if alongZ then
		box(p, F, x - sx / 2 + 0.1, x + sx / 2 - 0.1, 1.9, 2.35, z - sz / 2 + 0.1, z + sz * 0.15, cloth, M.Fabric)
		box(p, F, x - 1, x + 1, 2.2, 2.6, z + sz / 2 - 1.3, z + sz / 2 - 0.4, rgb(240, 236, 226), M.Fabric)
		box(p, F, x - sx / 2, x + sx / 2, 0, 3.6, z + sz / 2 - 0.3, z + sz / 2, Palette.shade(wood, 0.9))
	else
		box(p, F, x - sx / 2 + 0.1, x + sx * 0.15, 1.9, 2.35, z - sz / 2 + 0.1, z + sz / 2 - 0.1, cloth, M.Fabric)
		box(p, F, x + sx / 2 - 1.3, x + sx / 2 - 0.4, 2.2, 2.6, z - 1, z + 1, rgb(240, 236, 226), M.Fabric)
		box(p, F, x + sx / 2 - 0.3, x + sx / 2, 0, 3.6, z - sz / 2, z + sz / 2, Palette.shade(wood, 0.9))
	end
end

local function shelf(p, F: CFrame, x, z, w, h, facing: number, wood, rng)
	-- facing: +1 = against the back wall (front towards -Z), rotate with F otherwise
	local G = F * CF(x, 0, z) * ANG(0, facing, 0)
	box(p, G, -w / 2, w / 2, 0, h, -0.4, 0.4, Palette.shade(wood, 0.8), M.WoodPlanks, true)
	for i = 1, 3 do
		local y = i * h / 4
		box(p, G, -w / 2, w / 2, y - 0.1, y + 0.1, -0.9, 0.4, wood)
		for k = 1, rng:int(2, 4) do
			local gx = -w / 2 + 0.5 + rng:float(0, w - 1)
			local s = rng:float(0.4, 0.8)
			box(p, G, gx - s / 2, gx + s / 2, y + 0.1, y + 0.1 + s * rng:float(0.8, 1.5), -0.8, -0.8 + s, rng:pick({ rgb(150, 110, 70), rgb(80, 110, 80), rgb(160, 60, 50), rgb(210, 200, 170), rgb(70, 80, 120) }), M.SmoothPlastic)
		end
	end
end

local function fireplace(p, F: CFrame, x, zBack, stone)
	box(p, F, x - 2.6, x + 2.6, 0, 6.2, zBack - 2, zBack, stone, M.Cobblestone, true)
	box(p, F, x - 1.5, x + 1.5, 0.2, 2.8, zBack - 2.05, zBack - 1, rgb(24, 20, 20), M.Slate)
	box(p, F, x - 3, x + 3, 6.2, 6.6, zBack - 2.4, zBack, Palette.shade(stone, 1.1), M.Cobblestone)
	local ember = box(p, F, x - 0.9, x + 0.9, 0.2, 0.7, zBack - 1.9, zBack - 1.2, rgb(255, 140, 50), M.Neon)
	Kit.fire(ember, rgb(255, 150, 60), 0.5)
	Kit.pointLight(ember, rgb(255, 150, 80), 18, 1.4, false)
	-- chimney breast up to the ceiling
	box(p, F, x - 1.6, x + 1.6, 6.6, 12, zBack - 1.4, zBack, Palette.shade(stone, 0.95), M.Cobblestone)
end

local function lantern(p, F: CFrame, x, y, z)
	box(p, F, x - 0.05, x + 0.05, y, y + 1.4, z - 0.05, z + 0.05, rgb(40, 36, 34), M.Metal)
	local l = box(p, F, x - 0.35, x + 0.35, y - 0.7, y, z - 0.35, z + 0.35, rgb(255, 210, 140), M.Neon)
	Kit.pointLight(l, rgb(255, 196, 130), 20, 0.9, false)
end

local function barrel(p, F: CFrame, x, z)
	local b = box(p, F, x - 0.95, x + 0.95, 0, 2.5, z - 0.95, z + 0.95, rgb(120, 84, 50), M.WoodPlanks, true)
	box(p, F, x - 1, x + 1, 0.5, 0.7, z - 1, z + 1, rgb(50, 48, 50), M.Metal)
	box(p, F, x - 1, x + 1, 1.8, 2.0, z - 1, z + 1, rgb(50, 48, 50), M.Metal)
	return b
end

local function crate(p, F: CFrame, x, z, s)
	box(p, F, x - s / 2, x + s / 2, 0, s, z - s / 2, z + s / 2, rgb(150, 112, 70), M.WoodPlanks, true)
end

local function rug(p, F: CFrame, x, z, w, d, cloth)
	box(p, F, x - w / 2, x + w / 2, 0, 0.08, z - d / 2, z + d / 2, cloth, M.Fabric)
	box(p, F, x - w / 2 + 0.4, x + w / 2 - 0.4, 0.02, 0.1, z - d / 2 + 0.4, z + d / 2 - 0.4, Palette.shade(cloth, 1.25), M.Fabric)
end

local function mugs(p, F: CFrame, x, z, n, rng)
	for i = 1, n do
		local mx, mz = x + rng:float(-1.2, 1.2), z + rng:float(-0.6, 0.6)
		box(p, F, mx - 0.2, mx + 0.2, 3.0, 3.45, mz - 0.2, mz + 0.2, rng:pick({ rgb(180, 170, 150), rgb(120, 90, 60), rgb(140, 140, 150) }), M.SmoothPlastic)
	end
end

-- ------------------------------------------------------------------ room layouts
-- G = frame on the ground floor surface; bounds are the inner walls.
local function furnish(folder, info, G: CFrame, x0, x1, z0, z1, rng, level: number)
	local wood = rng:pick(WOOD)
	local cloth = rng:pick(CLOTH)
	local stone = rgb(140, 134, 126)
	local kind = info.kind
	local w, d = x1 - x0, z1 - z0
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	lantern(folder, G, cx, (info.fh or 9) - 1.6, cz)
	if level > 0 then
		-- upstairs: bedrooms
		bed(folder, G, x0 + 2.2, z1 - 3.6, true, wood, cloth)
		if w > 12 then
			bed(folder, G, x0 + 6.4, z1 - 3.6, true, wood, rng:pick(CLOTH))
		end
		crate(folder, G, x0 + 1.4, z0 + 1.6, 2)
		rug(folder, G, cx - 1, cz, math.min(6, w - 5), math.min(4, d - 4), cloth)
		return
	end
	if kind == "tavern" then
		-- bar along the back, barrels behind it, tables in front
		box(folder, G, x0 + 1, x1 - 1, 0, 3.4, z1 - 4.2, z1 - 3.2, wood, M.WoodPlanks, true)
		box(folder, G, x0 + 0.8, x1 - 0.8, 3.4, 3.7, z1 - 4.5, z1 - 3.0, Palette.shade(wood, 1.15), M.WoodPlanks)
		for i = 0, math.floor((w - 3) / 2.2) - 1 do
			barrel(folder, G, x0 + 1.6 + i * 2.2, z1 - 1.3)
		end
		mugs(folder, G, cx, z1 - 3.8, 4, rng)
		for i, px in { x0 + w * 0.25, x0 + w * 0.72 } do
			local pz = z0 + d * 0.38
			tableAt(folder, G, px, pz, 4, 3, wood)
			stool(folder, G, px - 2.6, pz, wood)
			stool(folder, G, px + 2.6, pz, wood)
			stool(folder, G, px, pz + 2.2, wood)
			mugs(folder, G, px, pz, 2 + i, rng)
		end
		lantern(folder, G, x0 + w * 0.25, (info.fh or 9) - 1.8, z0 + d * 0.38)
		return
	elseif kind == "smith" then
		local forge = box(folder, G, x1 - 5, x1 - 1, 0, 3.4, z1 - 4, z1 - 1, stone, M.Cobblestone, true)
		local coals = box(folder, G, x1 - 4.5, x1 - 1.5, 3.4, 3.8, z1 - 3.6, z1 - 1.4, rgb(255, 110, 40), M.Neon)
		Kit.fire(coals, rgb(255, 130, 50), 0.6)
		Kit.pointLight(coals, rgb(255, 120, 60), 22, 2, false)
		box(folder, G, x1 - 4, x1 - 2, 3.8, 11, z1 - 2.8, z1 - 1.4, Palette.shade(stone, 0.9), M.Cobblestone)
		-- anvil on a stump
		box(folder, G, cx - 0.8, cx + 0.8, 0, 2, cz - 0.8, cz + 0.8, wood, M.WoodPlanks, true)
		box(folder, G, cx - 1.2, cx + 1.2, 2, 2.9, cz - 0.6, cz + 0.6, rgb(60, 60, 66), M.Metal)
		box(folder, G, cx + 1.2, cx + 2, 2.4, 2.9, cz - 0.3, cz + 0.3, rgb(60, 60, 66), M.Metal)
		-- weapon rack on the side wall
		box(folder, G, x0 + 0.2, x0 + 0.6, 1, 6, z0 + 2, z1 - 2, wood)
		for i = 0, 3 do
			local rz = z0 + 3 + i * (d - 6) / 3
			box(folder, G, x0 + 0.7, x0 + 0.9, 1.2, 5.4, rz - 0.15, rz + 0.15, rgb(180, 180, 190), M.Metal)
		end
		barrel(folder, G, x0 + 1.4, z1 - 1.4)
		return
	elseif kind == "shop" then
		box(folder, G, x0 + 1, x1 - 1, 0, 3.2, cz - 0.6, cz + 0.6, wood, M.WoodPlanks, true)
		box(folder, G, x0 + 0.8, x1 - 0.8, 3.2, 3.5, cz - 0.9, cz + 0.9, Palette.shade(wood, 1.12), M.WoodPlanks)
		for i = 1, 4 do
			local gx = x0 + i * w / 5
			box(folder, G, gx - 0.5, gx + 0.5, 3.5, 4.2, cz - 0.4, cz + 0.4, rng:pick({ rgb(220, 60, 50), rgb(240, 200, 60), rgb(120, 200, 80), rgb(160, 110, 70) }), M.SmoothPlastic)
		end
		shelf(folder, G, cx, z1 - 0.5, math.min(w - 2, 8), 7, 0, wood, rng)
		crate(folder, G, x0 + 1.5, z0 + 1.6, 2.2)
		crate(folder, G, x0 + 1.4, z0 + 3.8, 1.6)
		return
	end
	-- a home (cottage / timber / stone)
	-- the fireplace keeps clear of the downstairs bed (east back corner)
	local fside = if info.upper then (if rng:chance(0.5) then -1 else 1) else -1
	fireplace(folder, G, cx + fside * math.min(2.5, w * 0.15), z1, stone)
	local tx = cx + (if rng:chance(0.5) then -1 else 1) * w * 0.15
	local tz = z0 + d * 0.45
	rug(folder, G, tx, tz, math.min(7, w - 4), math.min(5, d - 5), cloth)
	tableAt(folder, G, tx, tz, 4.2, 2.8, wood)
	if kind == "stone" then
		bench(folder, G, tx, tz - 2.2, 4, wood, true)
		bench(folder, G, tx, tz + 2.2, 4, wood, true)
	else
		stool(folder, G, tx - 2.7, tz, wood)
		stool(folder, G, tx + 2.7, tz, wood)
	end
	mugs(folder, G, tx, tz, rng:int(1, 3), rng)
	shelf(folder, G, x0 + 0.5, cz, math.min(d - 4, 6), 6.5, -math.pi / 2, wood, rng)
	if not info.upper then
		-- one-room cottage: the bed is downstairs
		bed(folder, G, x1 - 2.2, z1 - 4.4, true, wood, cloth)
	end
	barrel(folder, G, x1 - 1.4, z0 + 1.6)
	if rng:chance(0.6) then
		crate(folder, G, x1 - 1.3, z0 + 3.7, 1.8)
	end
end

local function build(info)
	local model = info.model
	local folder = Instance.new("Folder")
	folder.Name = "Interior"
	local rng = RNG.new(info.seed or 1)
	local F = info.cf
	local t = info.t or 0.8
	local plinth = info.plinth or 1.2
	local fh = info.fh or 9
	local x0, x1 = -info.w / 2 + t + 0.05, info.w / 2 - t - 0.05
	local z0, z1 = -info.d / 2 + t + 0.05, info.d / 2 - t - 0.05
	local G = F * CF(0, plinth, 0)
	local stairs = info.upper and (info.floors or 1) > 1
	furnish(folder, info, G, x0, if stairs then x1 - 3.3 else x1, z0, z1, rng, 0)
	if stairs then
		-- upper floor slab with a stairwell along the east wall, stairs rising back-to-front
		local wood = rng:pick(WOOD)
		local sw = 3
		box(folder, G, x0, x1 - sw, fh - 0.5, fh, z0, z1, Palette.shade(wood, 0.9), M.WoodPlanks, true)
		box(folder, G, x1 - sw, x1, fh - 0.5, fh, z0, z0 + 3, Palette.shade(wood, 0.9), M.WoodPlanks, true)
		local steps = 12
		local run = (z1 - 1) - (z0 + 3)
		for i = 0, steps - 1 do
			local y = (i + 1) * (fh / steps)
			local za = z1 - 1 - (i + 1) * run / steps
			box(folder, G, x1 - sw + 0.2, x1 - 0.1, y - 0.5, y, za, za + run / steps + 0.1, wood, M.WoodPlanks, true)
		end
		-- railing along the stairwell edge
		box(folder, G, x1 - sw - 0.2, x1 - sw, fh, fh + 3, z0 + 3, z1, Palette.shade(wood, 0.8))
		furnish(folder, info, G * CF(0, fh, 0), x0, x1 - sw - 0.4, z0, z1, rng, 1)
	end
	folder.Parent = model
	info.built = folder
	-- open the door (swings inward about its left edge)
	local door = info.door
	if door and door.Parent and info.doorCF then
		local hw = door.Size.X / 2
		door.CFrame = info.doorCF * CF(-hw, 0, 0) * ANG(0, math.rad(-100), 0) * CF(hw, 0, 0)
	end
end

local function drop(info)
	if info.built then
		info.built:Destroy()
		info.built = nil
	end
	local door = info.door
	if door and door.Parent and info.doorCF then
		door.CFrame = info.doorCF
	end
end

function Interiors.clear()
	for _, info in Interiors.list do
		drop(info)
	end
	Interiors.list = {}
end

task.spawn(function()
	while true do
		task.wait(0.35)
		local roots = {}
		for _, p in Players:GetPlayers() do
			local c = p.Character
			local r = c and c.PrimaryPart
			if r then
				table.insert(roots, r.Position)
			end
		end
		local budget = 3 -- houses built per tick (spreads the cost)
		for i = #Interiors.list, 1, -1 do
			local info = Interiors.list[i]
			if not info.model.Parent then
				table.remove(Interiors.list, i)
			else
				local pos = info.cf.Position
				local best = math.huge
				for _, r in roots do
					local dx, dz = r.X - pos.X, r.Z - pos.Z
					local dd = dx * dx + dz * dz
					if dd < best then
						best = dd
					end
				end
				if info.built and best > DROP_R * DROP_R then
					drop(info)
				elseif not info.built and best < BUILD_R * BUILD_R and budget > 0 then
					budget -= 1
					local ok, err = pcall(build, info)
					if not ok then
						warn("[Interiors] " .. tostring(err))
						info.built = info.built or Instance.new("Folder")
					end
				end
			end
		end
	end
end)

return Interiors
