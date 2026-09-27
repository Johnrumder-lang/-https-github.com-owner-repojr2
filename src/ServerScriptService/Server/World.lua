--!nonstrict
-- World building core: greedy-meshed cubic terrain, props, buildings, walls,
-- towers, destructible parts. Scene builders (World*.luau) use these.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Kit = require(Shared.Kit)
local Palette = require(Shared.Palette)
local Util = require(Shared.Util)
local RNG = require(Shared.RNG)
local S = require(script.Parent.S)

local World = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB
local SM = Enum.Material.SmoothPlastic

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

-- ------------------------------------------------------------------ folders
function World.root(): Folder
	local w = workspace:FindFirstChild("World")
	if not w then
		w = Kit.folder("World", workspace)
	end
	return w :: Folder
end

function World.sub(name: string): Folder
	local r = World.root()
	local f = r:FindFirstChild(name)
	if not f then
		f = Kit.folder(name, r)
	end
	return f :: Folder
end

function World.clear()
	local w = workspace:FindFirstChild("World")
	if w then
		w:Destroy()
	end
	World.root()
end

function World.yield(counter)
	counter.n += 1
	if counter.n % 400 == 0 then
		task.wait()
	end
end

-- ------------------------------------------------------------------ queries
function World.ground(pos: Vector3, parent: Instance?): (Vector3?, Vector3?)
	rayParams.FilterDescendantsInstances = if parent then { parent } else { World.sub("Map"), workspace.Terrain }
	local r = workspace:Raycast(pos + V(0, 400, 0), V(0, -1200, 0), rayParams)
	if r then
		return r.Position, r.Normal
	end
	return nil, nil
end

-- ------------------------------------------------------------------ destruction
function World.breakPart(p: BasePart, impulse: Vector3?)
	if not p.Parent or not p.Anchored then
		return
	end
	CollectionService:RemoveTag(p, "Breakable")
	local imp = impulse or V(0, 20, 0)
	local size = p.Size
	local pieces = {}
	if size.X * size.Y * size.Z > 30 and size.X < 40 and size.Y < 40 and size.Z < 40 then
		-- split into a 2x2x2 grid of cubes
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local q = Instance.new("Part")
					q.Size = size / 2
					q.CFrame = p.CFrame * CF(x * size.X / 4, y * size.Y / 4, z * size.Z / 4)
					q.Color = Palette.jitter(p.Color, 0.1, math.random())
					q.Material = p.Material
					q.TopSurface = Enum.SurfaceType.Smooth
					q.BottomSurface = Enum.SurfaceType.Smooth
					q.Parent = p.Parent
					table.insert(pieces, q)
				end
			end
		end
		p:Destroy()
	else
		table.insert(pieces, p)
	end
	for _, q in pieces do
		q.Anchored = false
		q.CanCollide = true
		CollectionService:AddTag(q, "Physical")
		q.AssemblyLinearVelocity = imp + V(math.random() - 0.5, math.random(), math.random() - 0.5) * imp.Magnitude * 0.5
		q.AssemblyAngularVelocity = V(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 10
		task.delay(8 + math.random() * 3, function()
			if q.Parent then
				q:Destroy()
			end
		end)
	end
end

function World.breakable(p: BasePart)
	CollectionService:AddTag(p, "Breakable")
	return p
end

-- ------------------------------------------------------------------ terrain
-- opts: {parent, origin (corner, world XZ + y=0), nx, nz, cell, step, base,
--        height(ix,iz)->studs, color(ix,iz,h)->palette index, palette={Color3...},
--        material(idx)->Enum.Material?, skip(ix,iz)->bool}
function World.heightfield(opts)
	local nx, nz, cell = opts.nx, opts.nz, opts.cell
	local step = opts.step or 2
	local base = opts.base or -40
	local parent = opts.parent or World.sub("Map")
	local H, K = {}, {}
	for ix = 1, nx do
		H[ix] = {}
		K[ix] = {}
		for iz = 1, nz do
			if opts.skip and opts.skip(ix, iz) then
				H[ix][iz] = false
			else
				local h = opts.height(ix, iz)
				local q = math.floor(h / step + 0.5) * step
				H[ix][iz] = q
				K[ix][iz] = opts.color(ix, iz, q)
			end
		end
	end
	local used = {}
	for ix = 1, nx do
		used[ix] = {}
	end
	-- Roblox clamps part sizes at 2048 studs: never merge a run longer than that
	local maxRun = opts.maxRun or math.max(1, math.floor(2040 / cell))
	local count = { n = 0 }
	local parts = 0
	for iz = 1, nz do
		for ix = 1, nx do
			local h = H[ix][iz]
			if h ~= false and not used[ix][iz] then
				local k = K[ix][iz]
				-- grow in x
				local w = 1
				while w < maxRun and ix + w <= nx and not used[ix + w][iz] and H[ix + w][iz] == h and K[ix + w][iz] == k do
					w += 1
				end
				-- grow in z
				local d = 1
				local ok = true
				while ok and d < maxRun and iz + d <= nz do
					for x = ix, ix + w - 1 do
						if used[x][iz + d] or H[x][iz + d] ~= h or K[x][iz + d] ~= k then
							ok = false
							break
						end
					end
					if ok then
						d += 1
					end
				end
				for x = ix, ix + w - 1 do
					for z = iz, iz + d - 1 do
						used[x][z] = true
					end
				end
				local height = h - base
				if height > 0.2 then
					local sx, sz = w * cell, d * cell
					local cx = opts.origin.X + (ix - 1) * cell + sx / 2
					local cz = opts.origin.Z + (iz - 1) * cell + sz / 2
					local color = opts.palette[k] or opts.palette[1]
					local mat = if opts.material then opts.material(k) else SM
					local p = Instance.new("Part")
					p.Anchored = true
					p.TopSurface = Enum.SurfaceType.Smooth
					p.BottomSurface = Enum.SurfaceType.Smooth
					p.Size = V(sx, height, sz)
					p.CFrame = CF(cx, base + height / 2, cz)
					p.Color = color
					p.Material = mat
					p.CastShadow = height < 60
					p.Parent = parent
					parts += 1
					World.yield(count)
				end
			end
		end
	end
	return parts, H
end

-- ------------------------------------------------------------------ props
local function deco(parent, size, cf, color, mat, props)
	return Kit.deco(parent, size, cf, color, mat, props)
end
local function solid(parent, size, cf, color, mat, props)
	return Kit.part(parent, size, cf, color, mat, props)
end
World.deco = deco
World.solid = solid

function World.tree(parent: Instance, pos: Vector3, kind: string, rng, scale: number?, biome)
	local s = scale or rng:float(0.8, 1.35)
	local pal = biome or Palette.biomes.Meadow
	local m = Kit.model("Tree", parent)
	if kind == "pine" then
		local h = 10 * s
		solid(m, V(1.6, h, 1.6) * V(s, 1, s), CF(pos + V(0, h / 2, 0)), pal.trunk)
		for i = 0, 3 do
			local w = (8 - i * 1.8) * s
			deco(m, V(w, 2.6 * s, w), CF(pos + V(0, h * 0.35 + i * 2.6 * s, 0)) * ANG(0, rng:float(0, 1.5), 0), pal.leaves[(i % #pal.leaves) + 1])
		end
		if pal.grass[1].R > 0.85 then
			deco(m, V(2.4 * s, 1 * s, 2.4 * s), CF(pos + V(0, h * 0.35 + 4 * 2.6 * s, 0)), rgb(245, 248, 255))
		end
	elseif kind == "dead" then
		local h = 9 * s
		solid(m, V(1.4, h, 1.4) * V(s, 1, s), CF(pos + V(0, h / 2, 0)) * ANG(0, 0, rng:float(-0.1, 0.1)), pal.trunk)
		for i = 1, 3 do
			local a = rng:angle()
			deco(m, V(0.8, 4.5, 0.8) * s, CF(pos + V(0, h * (0.5 + i * 0.12), 0)) * ANG(0, a, 0) * ANG(0, 0, 0.9) * CF(0, 2 * s, 0), Palette.shade(pal.trunk, 0.9))
		end
	elseif kind == "cactus" then
		local h = 7 * s
		local g = rgb(80, 150, 70)
		solid(m, V(1.6, h, 1.6), CF(pos + V(0, h / 2, 0)), g)
		for _, side in { 1, -1 } do
			if rng:chance(0.7) then
				deco(m, V(1.1, 1.1, 1.1) * V(2.2, 1, 1), CF(pos + V(side * 1.5, h * 0.5, 0)), g)
				deco(m, V(1.1, 2.8, 1.1), CF(pos + V(side * 2.2, h * 0.5 + 1.8, 0)), g)
			end
		end
	elseif kind == "willow" then
		local h = 8 * s
		solid(m, V(1.8, h, 1.8) * V(s, 1, s), CF(pos + V(0, h / 2, 0)), pal.trunk)
		deco(m, V(10, 3, 10) * s, CF(pos + V(0, h + 1, 0)), pal.leaves[1])
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			deco(m, V(1.2, 5, 1.2) * s, CF(pos + V(math.cos(a) * 4.5 * s, h - 1.5 * s, math.sin(a) * 4.5 * s)), pal.leaves[(i % #pal.leaves) + 1])
		end
	elseif kind == "crystal" then
		local col = pal.leaves[rng:int(1, #pal.leaves)]
		for i = 1, rng:int(2, 4) do
			local h = rng:float(4, 11) * s
			local c = deco(m, V(1.6, h, 1.6) * s, CF(pos + V(rng:float(-2, 2), h / 2 - 0.5, rng:float(-2, 2))) * ANG(rng:float(-0.3, 0.3), rng:angle(), rng:float(-0.3, 0.3)), col, Enum.Material.Neon, { Transparency = 0.15 })
			if i == 1 then
				Kit.pointLight(c, col, 14, 1.2)
			end
		end
	elseif kind == "mushroom" then
		local h = rng:float(6, 12) * s
		solid(m, V(1.6, h, 1.6) * V(s, 1, s), CF(pos + V(0, h / 2, 0)), pal.trunk)
		local cap = pal.leaves[rng:int(1, #pal.leaves)]
		deco(m, V(9, 2.2, 9) * s, CF(pos + V(0, h + 0.8, 0)), cap)
		deco(m, V(6, 1.4, 6) * s, CF(pos + V(0, h + 2.4, 0)), cap)
		for i = 1, 4 do
			deco(m, V(1, 0.4, 1) * s, CF(pos + V(rng:float(-3, 3), h + 3.2, rng:float(-3, 3))), rgb(255, 255, 240))
		end
		local glow = deco(m, V(6, 0.4, 6) * s, CF(pos + V(0, h - 0.4, 0)), rgb(160, 255, 200), Enum.Material.Neon, { Transparency = 0.4 })
		Kit.pointLight(glow, rgb(150, 255, 200), 16, 0.8)
	else -- oak
		local h = 7 * s
		solid(m, V(1.8, h, 1.8) * V(s, 1, s), CF(pos + V(0, h / 2, 0)), pal.trunk)
		local n = rng:int(4, 7)
		for i = 1, n do
			local off = V(rng:float(-3, 3), rng:float(-0.5, 3.5), rng:float(-3, 3)) * s
			local size = rng:float(3.6, 6) * s
			deco(m, V(size, size * 0.85, size), CF(pos + V(0, h + 1, 0) + off) * ANG(0, rng:float(0, 1.5), 0), pal.leaves[rng:int(1, #pal.leaves)])
		end
		if rng:chance(0.3) then
			deco(m, V(0.7, 0.7, 0.7) * s, CF(pos + V(2.2 * s, h - 0.2, 1 * s)), rgb(220, 40, 40))
		end
	end
	return m
end

function World.rock(parent: Instance, pos: Vector3, size: number, color: Color3, rng)
	local m = Kit.model("Rock", parent)
	for i = 1, rng:int(1, 3) do
		local s = size * rng:float(0.5, 1)
		solid(m, V(s, s * rng:float(0.6, 1), s * rng:float(0.7, 1.1)), CF(pos + V(rng:float(-1, 1) * size * 0.4, s * 0.3, rng:float(-1, 1) * size * 0.4)) * ANG(rng:float(-0.3, 0.3), rng:angle(), rng:float(-0.3, 0.3)), Palette.jitter(color, 0.1, rng:float()), Enum.Material.Slate)
	end
	return m
end

function World.flowers(parent: Instance, pos: Vector3, rng, pal)
	for i = 1, rng:int(2, 5) do
		local p = pos + V(rng:float(-2, 2), 0, rng:float(-2, 2))
		deco(parent, V(0.15, 0.8, 0.15), CF(p + V(0, 0.4, 0)), rgb(60, 130, 50))
		deco(parent, V(0.45, 0.45, 0.45), CF(p + V(0, 0.95, 0)), pal.flowers[rng:int(1, #pal.flowers)])
	end
end

function World.grass(parent: Instance, pos: Vector3, rng, color: Color3)
	for i = 1, rng:int(3, 6) do
		local h = rng:float(0.8, 1.8)
		deco(parent, V(0.25, h, 0.25), CF(pos + V(rng:float(-1.5, 1.5), h / 2, rng:float(-1.5, 1.5))) * ANG(rng:float(-0.25, 0.25), 0, rng:float(-0.25, 0.25)), Palette.shade(color, rng:float(0.9, 1.2)), SM, { CastShadow = false })
	end
end

function World.torch(parent: Instance, cf: CFrame, color: Color3?)
	local stick = deco(parent, V(0.4, 2, 0.4), cf * CF(0, 1, 0), rgb(80, 56, 36))
	local head = deco(parent, V(0.7, 0.6, 0.7), cf * CF(0, 2.2, 0), rgb(50, 36, 26))
	Kit.fire(head, color, 0.6)
	Kit.pointLight(head, color or rgb(255, 150, 70), 22, 1.6, true)
	return head
end

function World.lantern(parent: Instance, pos: Vector3, color: Color3?)
	local post = solid(parent, V(0.6, 7, 0.6), CF(pos + V(0, 3.5, 0)), rgb(50, 40, 34))
	deco(parent, V(2, 0.4, 0.4), CF(pos + V(0.7, 6.8, 0)), rgb(50, 40, 34))
	local lamp = deco(parent, V(0.9, 1.1, 0.9), CF(pos + V(1.4, 6.1, 0)), color or rgb(255, 200, 120), Enum.Material.Neon)
	Kit.pointLight(lamp, color or rgb(255, 190, 110), 24, 1.2, true)
	return lamp
end

function World.crate(parent: Instance, cf: CFrame, size: number?)
	local s = size or 2.4
	local p = solid(parent, V(s, s, s), cf * CF(0, s / 2, 0), Palette.wood[1], Enum.Material.WoodPlanks)
	World.breakable(p)
	return p
end

function World.barrel(parent: Instance, cf: CFrame)
	local p = solid(parent, V(2, 2.6, 2), cf * CF(0, 1.3, 0), Palette.wood[2], Enum.Material.WoodPlanks)
	deco(p, V(2.1, 0.2, 2.1), cf * CF(0, 0.6, 0), Palette.metal.dark, Enum.Material.Metal)
	deco(p, V(2.1, 0.2, 2.1), cf * CF(0, 2.0, 0), Palette.metal.dark, Enum.Material.Metal)
	World.breakable(p)
	return p
end

function World.fence(parent: Instance, a: Vector3, b: Vector3, color: Color3?)
	local c = color or Palette.wood[3]
	local d = b - a
	local len = d.Magnitude
	local n = math.max(1, math.floor(len / 5))
	for i = 0, n do
		local p = a + d * (i / n)
		solid(parent, V(0.6, 3.2, 0.6), CF(p + V(0, 1.6, 0)), c, Enum.Material.WoodPlanks)
	end
	local mid = (a + b) / 2
	for _, y in { 1.2, 2.5 } do
		solid(parent, V(0.3, 0.4, len), CFrame.lookAt(mid + V(0, y, 0), b + V(0, y, 0)), c, Enum.Material.WoodPlanks)
	end
end

function World.campfire(parent: Instance, pos: Vector3)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		deco(parent, V(0.8, 0.6, 0.8), CF(pos + V(math.cos(a) * 1.4, 0.3, math.sin(a) * 1.4)), rgb(100, 100, 104))
	end
	for i = 1, 3 do
		deco(parent, V(0.5, 0.5, 2.4), CF(pos + V(0, 0.4, 0)) * ANG(0, i * 1.05, 0.2), rgb(90, 60, 40))
	end
	local core = deco(parent, V(1, 0.6, 1), CF(pos + V(0, 0.6, 0)), rgb(255, 140, 40), Enum.Material.Neon)
	Kit.fire(core, rgb(255, 150, 50), 1)
	Kit.pointLight(core, rgb(255, 150, 70), 30, 2, true)
end

function World.tent(parent: Instance, cf: CFrame, color: Color3)
	Kit.wedge(parent, V(6, 5, 4), cf * CF(0, 2.5, -2), color, Enum.Material.Fabric)
	Kit.wedge(parent, V(6, 5, 4), cf * CF(0, 2.5, 2) * ANG(0, math.pi, 0), color, Enum.Material.Fabric)
end

function World.banner(parent: Instance, cf: CFrame, color: Color3, emblem: Color3?)
	deco(parent, V(0.3, 9, 0.3), cf * CF(0, 4.5, 0), rgb(60, 44, 30))
	deco(parent, V(2.6, 0.25, 0.25), cf * CF(0, 8.8, 0), rgb(60, 44, 30))
	local cloth = deco(parent, V(2.4, 4.2, 0.12), cf * CF(0, 6.5, 0.2), color, Enum.Material.Fabric)
	if emblem then
		deco(parent, V(1, 1, 0.14), cf * CF(0, 6.8, 0.2), emblem, Enum.Material.Neon)
	end
	return cloth
end

function World.stall(parent: Instance, cf: CFrame, color: Color3, rng)
	for _, x in { -3, 3 } do
		for _, z in { -2, 2 } do
			solid(parent, V(0.5, 6, 0.5), cf * CF(x, 3, z), Palette.wood[2], Enum.Material.WoodPlanks)
		end
	end
	solid(parent, V(7, 1, 4.6), cf * CF(0, 2.6, 0), Palette.wood[1], Enum.Material.WoodPlanks)
	deco(parent, V(7.6, 0.3, 5.4), cf * CF(0, 6.1, 0) * ANG(0.12, 0, 0), color, Enum.Material.Fabric)
	for i = 1, 6 do
		deco(parent, V(0.8, 0.8, 0.8), cf * CF(rng:float(-3, 3), 3.5, rng:float(-1.8, 1.8)), rng:pick({ rgb(220, 60, 50), rgb(240, 200, 60), rgb(120, 200, 80), rgb(200, 120, 60) }))
	end
end

function World.well(parent: Instance, pos: Vector3)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		solid(parent, V(2, 2.2, 1.2), CF(pos + V(math.cos(a) * 2.6, 1.1, math.sin(a) * 2.6)) * ANG(0, -a, 0), Palette.stone[1], Enum.Material.Cobblestone)
	end
	deco(parent, V(4, 0.2, 4), CF(pos + V(0, 0.5, 0)), rgb(40, 90, 140), Enum.Material.Glass, { Transparency = 0.3 })
	for _, x in { -2.8, 2.8 } do
		solid(parent, V(0.5, 6, 0.5), CF(pos + V(x, 3, 0)), Palette.wood[2])
	end
	deco(parent, V(6.4, 0.5, 3.6), CF(pos + V(0, 6.2, 0)) * ANG(0, 0, 0), Palette.wood[4], Enum.Material.WoodPlanks)
end

function World.water(parent: Instance, cf: CFrame, size: Vector3, color: Color3, lava: boolean?)
	local p = Kit.part(parent, size, cf, color, if lava then Enum.Material.Neon else Enum.Material.Glass, { CanCollide = false, Transparency = if lava then 0 else 0.35, CastShadow = false })
	p.Name = if lava then "Lava" else "Water"
	if lava then
		CollectionService:AddTag(p, "Lava")
		Kit.pointLight(p, color, 30, 1.2)
	end
	return p
end

-- ------------------------------------------------------------------ buildings
-- Cubic house with stepped roof. opts: {w, d, floors, wall, roof, trim, rng, style, open}
function World.house(parent: Instance, cf: CFrame, opts)
	local rng = opts.rng
	local w, d = opts.w or 16, opts.d or 12
	local floors = opts.floors or 1
	local fh = opts.floorHeight or 10
	local wall = opts.wall or rgb(220, 205, 180)
	local roof = opts.roof or rgb(140, 60, 44)
	local trim = opts.trim or Palette.wood[4]
	local mat = opts.wallMat or Enum.Material.Plaster
	local m = Kit.model(opts.name or "House", parent)
	local t = 1
	local H = floors * fh
	-- floor
	solid(m, V(w, 1, d), cf * CF(0, 0.5, 0), opts.floor or Palette.wood[1], Enum.Material.WoodPlanks)
	-- walls: front has a door gap
	local doorW = 4
	local sideW = (w - doorW) / 2
	solid(m, V(sideW, H, t), cf * CF(-(doorW / 2 + sideW / 2), H / 2 + 1, -d / 2 + t / 2), wall, mat)
	solid(m, V(sideW, H, t), cf * CF((doorW / 2 + sideW / 2), H / 2 + 1, -d / 2 + t / 2), wall, mat)
	solid(m, V(doorW, H - 7, t), cf * CF(0, 7 + (H - 7) / 2 + 1, -d / 2 + t / 2), wall, mat)
	solid(m, V(w, H, t), cf * CF(0, H / 2 + 1, d / 2 - t / 2), wall, mat)
	solid(m, V(t, H, d - 2 * t), cf * CF(-w / 2 + t / 2, H / 2 + 1, 0), wall, mat)
	solid(m, V(t, H, d - 2 * t), cf * CF(w / 2 - t / 2, H / 2 + 1, 0), wall, mat)
	-- timber frame / corner posts
	for _, x in { -w / 2, w / 2 } do
		for _, z in { -d / 2, d / 2 } do
			deco(m, V(1.2, H + 0.4, 1.2), cf * CF(x, H / 2 + 1, z), trim, Enum.Material.WoodPlanks)
		end
	end
	for f = 1, floors do
		deco(m, V(w + 0.4, 0.6, d + 0.4), cf * CF(0, f * fh + 1, 0), trim, Enum.Material.WoodPlanks)
		if f < floors then
			solid(m, V(w - 2, 0.6, d - 2), cf * CF(0, f * fh + 1, 0), Palette.wood[1], Enum.Material.WoodPlanks)
		end
	end
	-- windows
	for f = 0, floors - 1 do
		local y = f * fh + 5.5
		for _, side in { -1, 1 } do
			if f > 0 or true then
				deco(m, V(2.4, 2.4, t + 0.1), cf * CF(side * w * 0.3, y, -d / 2 + t / 2), rgb(255, 220, 150), Enum.Material.Neon, { Transparency = 0.4 })
				deco(m, V(3, 0.4, t + 0.4), cf * CF(side * w * 0.3, y - 1.4, -d / 2 + t / 2), trim, Enum.Material.WoodPlanks)
			end
			deco(m, V(t + 0.1, 2.4, 2.4), cf * CF(side * (w / 2 - t / 2), y, 0), rgb(255, 220, 150), Enum.Material.Neon, { Transparency = 0.45 })
		end
	end
	-- door
	local door = solid(m, V(doorW - 0.4, 6.8, 0.4), cf * CF(0, 4.4, -d / 2 + 0.3), Palette.wood[4], Enum.Material.WoodPlanks)
	door.Name = "Door"
	if opts.open then
		door.CanCollide = false
		door.Transparency = 1
	end
	-- stepped roof along x axis
	local steps = math.max(3, math.floor(d / 3))
	for i = 0, steps - 1 do
		local k = i / steps
		local rw = d * (1 - k) + 1.6
		deco(m, V(w + 1.6, 1.4, rw), cf * CF(0, H + 1.7 + i * 1.3, 0), Palette.shade(roof, 1 - i * 0.04), Enum.Material.SmoothPlastic)
	end
	solid(m, V(w + 1.6, 0.8, d + 1.6), cf * CF(0, H + 1.2, 0), roof)
	-- chimney
	if rng:chance(0.6) then
		local cx = rng:float(-w * 0.3, w * 0.3)
		local ch = deco(m, V(2, 5, 2), cf * CF(cx, H + 4, d * 0.2), Palette.stone[1], Enum.Material.Brick)
		if opts.smoke ~= false and rng:chance(0.5) then
			Kit.emitter(ch, { Texture = Kit.SMOKE, Color = ColorSequence.new(rgb(90, 90, 95)), LightEmission = 0, Rate = 4, Speed = NumberRange.new(3, 5), Lifetime = NumberRange.new(3, 5), Size = NumberSequence.new(1.5, 4), Transparency = NumberSequence.new(0.5, 1), Acceleration = V(1, 2, 0) })
		end
	end
	-- a little interior
	if opts.interior ~= false then
		solid(m, V(4, 2.4, 3), cf * CF(w * 0.2, 2.2, d * 0.15), Palette.wood[2], Enum.Material.WoodPlanks)
		deco(m, V(3, 1.2, 6), cf * CF(-w * 0.3, 1.6, d * 0.2), rgb(200, 70, 60), Enum.Material.Fabric)
		local l = deco(m, V(0.8, 0.8, 0.8), cf * CF(0, H - 1, 0), rgb(255, 200, 130), Enum.Material.Neon)
		Kit.pointLight(l, rgb(255, 190, 120), 18, 0.8)
	end
	return m, (cf * CF(0, 0, -d / 2 - 3)).Position
end

-- Castle wall between two points with crenellations and a walkway.
function World.wall(parent: Instance, a: Vector3, b: Vector3, height: number, thick: number, color: Color3, mat: Enum.Material?)
	local d = b - a
	local len = d.Magnitude
	if len < 1 then
		return
	end
	local cf = CFrame.lookAt((a + b) / 2, b)
	local m = mat or Enum.Material.Cobblestone
	solid(parent, V(thick, height, len), cf * CF(0, height / 2, 0), color, m)
	local n = math.floor(len / 4)
	for i = 0, n - 1 do
		if i % 2 == 0 then
			for _, side in { -1, 1 } do
				solid(parent, V(1.2, 2.4, 2), cf * CF(side * (thick / 2 - 0.6), height + 1.2, -len / 2 + i * 4 + 2), Palette.shade(color, 0.95), m)
			end
		end
	end
end

function World.tower(parent: Instance, pos: Vector3, half: number, height: number, color: Color3, roof: Color3?, mat: Enum.Material?)
	local m = Kit.model("Tower", parent)
	local mt = mat or Enum.Material.Cobblestone
	solid(m, V(half * 2, height, half * 2), CF(pos + V(0, height / 2, 0)), color, mt)
	solid(m, V(half * 2 + 2, 1.5, half * 2 + 2), CF(pos + V(0, height + 0.75, 0)), Palette.shade(color, 0.9), mt)
	for i = -1, 1, 2 do
		for j = -1, 1 do
			solid(m, V(1.6, 2.4, 1.6), CF(pos + V(i * (half + 0.2), height + 2.7, j * half * 0.7)), color, mt)
			solid(m, V(1.6, 2.4, 1.6), CF(pos + V(j * half * 0.7, height + 2.7, i * (half + 0.2))), color, mt)
		end
	end
	if roof then
		local steps = 6
		for i = 0, steps - 1 do
			local s = (half * 2 + 2) * (1 - i / steps)
			deco(m, V(s, 2.2, s), CF(pos + V(0, height + 2.5 + i * 2.2, 0)), Palette.shade(roof, 1 - i * 0.05))
		end
		local tip = deco(m, V(0.4, 4, 0.4), CF(pos + V(0, height + 2.5 + steps * 2.2 + 2, 0)), Palette.metal.gold, Enum.Material.Metal)
	end
	-- windows (glowing slits)
	for y = 10, height - 6, 12 do
		for _, dir in { V(1, 0, 0), V(-1, 0, 0), V(0, 0, 1), V(0, 0, -1) } do
			deco(m, V(if dir.X ~= 0 then 0.4 else 1, 3, if dir.Z ~= 0 then 0.4 else 1), CF(pos + V(0, y, 0) + dir * (half + 0.05)), rgb(255, 200, 120), Enum.Material.Neon, { Transparency = 0.3 })
		end
	end
	return m
end

function World.stairs(parent: Instance, from: Vector3, to: Vector3, width: number, color: Color3, mat: Enum.Material?)
	local d = to - from
	local flat = V(d.X, 0, d.Z)
	local rise = d.Y
	local n = math.max(1, math.ceil(math.abs(rise) / 1.2))
	local stepLen = flat.Magnitude / n
	local cf = CFrame.lookAt(from, from + (if flat.Magnitude > 0.01 then flat else V(0, 0, -1)))
	for i = 0, n - 1 do
		local y = rise * (i + 1) / n
		solid(parent, V(width, math.max(1, math.abs(y)), stepLen + 0.05), cf * CF(0, y / 2, -(i + 0.5) * stepLen), Palette.shade(color, if i % 2 == 0 then 1 else 0.94), mat or Enum.Material.Cobblestone)
	end
end

-- Flat platform helper.
function World.floor(parent: Instance, cf: CFrame, size: Vector3, color: Color3, mat: Enum.Material?)
	return solid(parent, size, cf, color, mat)
end

-- Magic circle on the floor (ritual chamber, portals).
function World.circle(parent: Instance, center: Vector3, r: number, color: Color3, spin: boolean?)
	local m = Kit.model("MagicCircle", parent)
	local n = math.floor(r * 3)
	for i = 1, n do
		local a = i / n * math.pi * 2
		deco(m, V(0.6, 0.12, 1.2), CF(center + V(math.cos(a) * r, 0.06, math.sin(a) * r)) * ANG(0, -a, 0), color, Enum.Material.Neon)
		if i % 3 == 0 then
			deco(m, V(0.5, 0.12, 0.5), CF(center + V(math.cos(a) * r * 0.7, 0.06, math.sin(a) * r * 0.7)), color, Enum.Material.Neon)
		end
	end
	for i = 0, 5 do
		local a1 = i / 6 * math.pi * 2
		local a2 = (i + 2) / 6 * math.pi * 2
		local p1 = center + V(math.cos(a1) * r * 0.9, 0.07, math.sin(a1) * r * 0.9)
		local p2 = center + V(math.cos(a2) * r * 0.9, 0.07, math.sin(a2) * r * 0.9)
		deco(m, V(0.3, 0.12, (p2 - p1).Magnitude), CFrame.lookAt((p1 + p2) / 2, p2), color, Enum.Material.Neon)
	end
	local core = deco(m, V(1, 0.1, 1), CF(center + V(0, 0.05, 0)), color, Enum.Material.Neon, { Transparency = 1 })
	Kit.pointLight(core, color, r * 2.2, 2)
	if spin then
		CollectionService:AddTag(m, "Spin")
	end
	return m
end

-- Portal / travel gate.
function World.portal(parent: Instance, cf: CFrame, color: Color3, label: string?)
	local m = Kit.model("Portal", parent)
	solid(m, V(2, 16, 2), cf * CF(-6, 8, 0), Palette.stone[4], Enum.Material.Slate)
	solid(m, V(2, 16, 2), cf * CF(6, 8, 0), Palette.stone[4], Enum.Material.Slate)
	solid(m, V(14, 2, 2), cf * CF(0, 17, 0), Palette.stone[4], Enum.Material.Slate)
	local film = deco(m, V(10, 14, 0.3), cf * CF(0, 8.5, 0), color, Enum.Material.ForceField, { Transparency = 0.1 })
	film.Name = "Film"
	Kit.pointLight(film, color, 30, 2)
	if label then
		local sign = deco(m, V(8, 1.6, 0.3), cf * CF(0, 19.5, 0), rgb(20, 18, 24))
		Kit.label(sign, Enum.NormalId.Front, label, color, Enum.Font.Arcade, nil, 20)
		Kit.label(sign, Enum.NormalId.Back, label, color, Enum.Font.Arcade, nil, 20)
	end
	return m, film
end

return World
