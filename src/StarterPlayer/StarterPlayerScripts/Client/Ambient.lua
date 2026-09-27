--!nonstrict
-- Life in the landscape, all client-side:
--  * Critters: farm animals graze, wander inside their pens, walk (legs swing),
--    peck and wag their tails. The server builds them once and never moves them.
--  * Sway: flowers, reeds, crops and leaf clusters bend in the wind near the camera.
--  * Cull: far-away props, houses and fields are parked outside the workspace so a
--    huge world renders like a small one (they come back as you approach).
--  * Grass: the land is built from parts, so grass is planted around the camera on
--    grassy ground (client-only, recycled as you move): swaying tufts and flowers
--    close by, bigger clumps out to the horizon.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ambient = {}
local cam = workspace.CurrentCamera
local function Util_flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
end
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles

-- ------------------------------------------------------------------ critters
local HEAD = { Head = true, Snout = true, Eye = true, Ear = true, Horn = true, Beak = true, Comb = true }
local critters = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function register(m: Model)
	if critters[m] or not m:IsA("Model") then
		return
	end
	local pivot = m:GetPivot()
	local groups = { legs = {}, head = nil, tail = nil }
	local parts = {}
	local legPivots = {}
	local bird = m:GetAttribute("Bird") == true
	-- leg pivot points first (hooves follow their leg)
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			local idx = p.Name:match("^Leg(%d)$")
			if idx then
				local rest = pivot:ToObjectSpace(p.CFrame)
				legPivots[tonumber(idx)] = (rest * CF(0, p:GetAttribute("Pivot") or p.Size.Y / 2, 0)).Position
			end
		end
	end
	local headPivot, tailPivot = nil, nil
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			local rest = pivot:ToObjectSpace(p.CFrame)
			if p.Name == "Head" then
				local pv = p:GetAttribute("Pivot") or p.Size.Z / 2
				headPivot = if bird then (rest * CF(0, -pv, 0)).Position else (rest * CF(0, 0, pv)).Position
			elseif p.Name == "Tail" then
				tailPivot = (rest * CF(0, p:GetAttribute("Pivot") or p.Size.Y / 2, 0)).Position
			end
		end
	end
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			local rest = pivot:ToObjectSpace(p.CFrame)
			local leg = p.Name:match("^Leg(%d)$") or p.Name:match("^Hoof(%d)$")
			local g = nil
			if leg then
				g = { kind = "leg", i = tonumber(leg), at = legPivots[tonumber(leg)] }
			elseif HEAD[p.Name] and headPivot then
				g = { kind = "head", at = headPivot }
			elseif p.Name == "Tail" and tailPivot then
				g = { kind = "tail", at = tailPivot }
			end
			table.insert(parts, { p = p, rest = rest, g = g })
		end
	end
	local home = m:GetAttribute("Home") or pivot.Position
	critters[m] = {
		m = m,
		parts = parts,
		pos = pivot.Position,
		yaw = select(2, pivot:ToEulerAnglesYXZ()),
		home = home,
		wander = m:GetAttribute("Wander") or 10,
		speed = m:GetAttribute("Speed") or 2,
		bird = bird,
		state = "idle",
		timer = math.random() * 5,
		phase = math.random() * 10,
		groundY = pivot.Position.Y,
		rayT = 0,
		graze = 0,
		sleep = false,
	}
end

local function unregister(m)
	critters[m] = nil
end

local function stepCritter(c, dt: number, now: number)
	c.timer -= dt
	local moving = false
	if c.state == "idle" then
		-- graze / peck on and off
		c.graze = math.max(0, math.sin(now * (if c.bird then 3.2 else 0.7) + c.phase))
		if c.timer <= 0 then
			local a = math.random() * math.pi * 2
			local r = math.sqrt(math.random()) * c.wander
			c.target = c.home + V(math.cos(a) * r, 0, math.sin(a) * r)
			c.state = "walk"
			c.timer = 8
		end
	else
		local to = c.target - c.pos
		local flat = V(to.X, 0, to.Z)
		if flat.Magnitude < 0.6 or c.timer <= 0 then
			c.state = "idle"
			c.timer = if c.bird then 1 + math.random() * 3 else 3 + math.random() * 7
		else
			moving = true
			local want = math.atan2(-flat.X, -flat.Z)
			local diff = (want - c.yaw + math.pi) % (2 * math.pi) - math.pi
			c.yaw += math.clamp(diff, -dt * 2.5, dt * 2.5)
			local step = math.min(flat.Magnitude, c.speed * dt * (if math.abs(diff) > 1 then 0.3 else 1))
			local dir = V(-math.sin(c.yaw), 0, -math.cos(c.yaw))
			c.pos += dir * step
			c.graze = math.max(0, c.graze - dt * 3)
			c.rayT -= dt
			if c.rayT <= 0 then
				c.rayT = 0.25
				local hit = workspace:Raycast(c.pos + V(0, 6, 0), V(0, -20, 0), rayParams)
				if hit then
					c.groundY = hit.Position.Y
				end
			end
		end
	end
	c.pos = V(c.pos.X, c.pos.Y + (c.groundY - c.pos.Y) * math.min(1, dt * 8), c.pos.Z)
	if moving then
		c.phase += dt * c.speed * (if c.bird then 5 else 2.2)
	end
	local root = CF(c.pos) * ANG(0, c.yaw, 0)
	local swing = if moving then math.sin(c.phase * 2) * 0.55 else 0
	local bob = if moving and c.bird then math.abs(math.sin(c.phase * 2)) * 0.12 else 0
	root *= CF(0, bob, 0)
	local headDip = c.graze * (if c.bird then 0.9 else 0.75)
	local tailWag = math.sin(now * 5 + c.phase) * 0.35
	for _, e in c.parts do
		local g = e.g
		local cf
		if g and g.at then
			local rot
			if g.kind == "leg" then
				local s = if (g.i == 1 or g.i == 4) then swing else -swing
				rot = ANG(s, 0, 0)
			elseif g.kind == "head" then
				rot = ANG(-headDip, 0, 0)
			else
				rot = ANG(0, 0, tailWag)
			end
			cf = root * CF(g.at) * rot * CF(-g.at) * e.rest
		else
			cf = root * e.rest
		end
		e.p.CFrame = cf
	end
end

-- ------------------------------------------------------------------ sway
local swayers = {}
local function addSway(p: Instance)
	if not p:IsA("BasePart") or swayers[p] then
		return
	end
	local h = p:GetAttribute("SwayPivot") or p.Size.Y / 2
	local rest = p.CFrame
	swayers[p] = {
		rest = rest,
		pivot = (rest * CF(0, -h, 0)).Position,
		amp = p:GetAttribute("SwayA") or 0.12,
		phase = (rest.Position.X * 0.13 + rest.Position.Z * 0.07) % 6.28,
	}
end

-- ------------------------------------------------------------------ grass
-- The land is parts, so the client plants grass around the camera wherever the
-- ground is grassy and recycles it as you move: a dense NEAR ring of tufts
-- (three pointed wedge blades each, a few with a wildflower, swaying in the
-- wind) and a sparse FAR ring of bigger clumps out to the horizon, so the whole
-- map reads as a meadow wherever you go.
local NEAR = { n = 420, r = 95, budget = 26 }
local FAR = { n = 520, r = 320, inner = 80, budget = 16 }
local SWAY_R = 55
local tuftFolder: Folder? = nil
local near, far = {}, {}
local grassParams = RaycastParams.new()
grassParams.FilterType = Enum.RaycastFilterType.Include
grassParams.IgnoreWater = true
local GRASSY = { [Enum.Material.Grass] = true, [Enum.Material.LeafyGrass] = true }
local FLOWERS = { Color3.fromRGB(250, 240, 120), Color3.fromRGB(245, 245, 250), Color3.fromRGB(220, 90, 110), Color3.fromRGB(150, 120, 230), Color3.fromRGB(255, 170, 70) }
local HIDE = CF(0, -5000, 0)
local lastGrassAt = 0 -- os.clock() of the last grass tuft planted (= we're outdoors)

local function grassPart(class: string, mat: Enum.Material): BasePart
	local p = Instance.new(class) :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = mat
	p.CFrame = HIDE
	p.Parent = tuftFolder
	return p
end

local function makeTuft(nBlades: number, far: boolean)
	local t = { blades = {}, placed = false, far = far }
	for k = 1, nBlades do
		t.blades[k] = grassPart("WedgePart", if far then Enum.Material.Grass else Enum.Material.SmoothPlastic)
	end
	if not far then
		t.flower = grassPart("Part", Enum.Material.SmoothPlastic)
		t.flower.Shape = Enum.PartType.Ball
	end
	return t
end

local function unplant(t)
	t.placed = false
	for _, b in t.blades do
		b.CFrame = HIDE
	end
	if t.flower then
		t.flower.CFrame = HIDE
	end
end

-- a blade: two back-to-back wedges would double the parts, so each blade is one
-- wedge (a right triangle seen from the side) and the tuft's yaws cover the rest
local function bladeCF(t, k: number, sw: number): CFrame
	local b = t.spec[k]
	return CF(t.pos) * ANG(0, b.yaw, 0) * ANG(b.lean + sw, 0, sw * 0.35) * CF(0, b.h / 2, 0)
end

local function plant(t, cp: Vector3, look: Vector3, ring)
	local map = workspace:FindFirstChild("World")
	map = map and map:FindFirstChild("Map")
	if not map then
		return
	end
	local a = math.random() * math.pi * 2
	local r
	if t.far then
		r = math.sqrt(ring.inner * ring.inner + math.random() * (ring.r * ring.r - ring.inner * ring.inner))
	else
		r = math.sqrt(math.random()) * ring.r
	end
	local off = V(math.cos(a) * r, 0, math.sin(a) * r)
	-- mostly in front of the camera, where you look
	if off:Dot(look) < 0 and math.random() < 0.55 then
		off = -off
	end
	grassParams.FilterDescendantsInstances = { workspace:FindFirstChild("World") :: Instance }
	local top = math.max(cp.Y + 300, 700)
	local hit = workspace:Raycast(V(cp.X + off.X, top, cp.Z + off.Z), V(0, -top - 400, 0), grassParams)
	if not hit or hit.Instance.Parent ~= map or not GRASSY[hit.Material] or hit.Normal.Y < 0.9 then
		return
	end
	local col = hit.Instance.Color
	local lush = if hit.Material == Enum.Material.LeafyGrass then 0.85 else 1
	t.pos = hit.Position
	t.phase = math.random() * 6.28
	t.placed = true
	lastGrassAt = os.clock()
	t.spec = t.spec or {}
	local n = #t.blades
	local yaw0 = math.random() * math.pi
	for k, b in t.blades do
		local h = if t.far then (1.6 + math.random() * 1.4) * lush else (1.1 + math.random() * 1.5) * lush
		local w = if t.far then 2.4 + math.random() * 1.6 else 0.35 + math.random() * 0.35
		local dry = not t.far and math.random() < 0.08
		local g = 1.02 + math.random() * 0.22
		b.Size = Vector3.new(0.06, h, w)
		b.Color = if dry then Color3.fromRGB(196, 186, 110) else Color3.new(math.min(1, col.R * (0.95 + math.random() * 0.2)), math.min(1, col.G * g), math.min(1, col.B * 0.95))
		t.spec[k] = { yaw = yaw0 + (k - 1) * math.pi * 2 / n + (math.random() - 0.5) * 0.5, lean = (math.random() - 0.5) * 0.5, h = h }
		b.CFrame = bladeCF(t, k, 0)
	end
	if t.flower then
		if math.random() < 0.12 then
			local fh = 1.2 + math.random() * 1.1
			t.flowerH = fh
			t.flower.Size = Vector3.one * (0.3 + math.random() * 0.2)
			t.flower.Color = FLOWERS[math.random(1, #FLOWERS)]
			t.flower.CFrame = CF(t.pos + V(0, fh, 0))
		else
			t.flowerH = nil
			t.flower.CFrame = HIDE
		end
	end
end

local swayParts, swayCFs = {}, {}
local function stepGrass(now: number)
	local cp = cam.CFrame.Position
	local look = Util_flat(cam.CFrame.LookVector)
	local gust = 0.6 + 0.4 * math.sin(now * 0.37) * math.sin(now * 0.23 + 1)
	table.clear(swayParts)
	table.clear(swayCFs)
	-- near tufts: recycle, sway the closest
	local budget = NEAR.budget
	for _, t in near do
		if t.placed then
			local dx, dz = t.pos.X - cp.X, t.pos.Z - cp.Z
			local d2 = dx * dx + dz * dz
			if d2 > (NEAR.r + 12) ^ 2 then
				unplant(t)
			elseif d2 < SWAY_R * SWAY_R then
				-- the wind rolls across the field (phase from the position)
				local sw = (math.sin(now * 2.1 + t.phase + t.pos.X * 0.05) * 0.2 + 0.12) * gust
				for k, b in t.blades do
					table.insert(swayParts, b)
					table.insert(swayCFs, bladeCF(t, k, sw))
				end
				if t.flowerH then
					table.insert(swayParts, t.flower)
					table.insert(swayCFs, CF(t.pos + V(math.sin(sw) * t.flowerH * 0.9, t.flowerH, 0)))
				end
			end
		end
		if not t.placed and budget > 0 then
			budget -= 1
			plant(t, cp, look, NEAR)
		end
	end
	if #swayParts > 0 then
		workspace:BulkMoveTo(swayParts, swayCFs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	-- far clumps: static, recycled at both edges of the ring
	budget = FAR.budget
	for _, t in far do
		if t.placed then
			local dx, dz = t.pos.X - cp.X, t.pos.Z - cp.Z
			local d2 = dx * dx + dz * dz
			if d2 > (FAR.r + 30) ^ 2 or d2 < (FAR.inner - 30) ^ 2 then
				unplant(t)
			end
		end
		if not t.placed and budget > 0 then
			budget -= 1
			plant(t, cp, look, FAR)
		end
	end
end

-- ------------------------------------------------------------------ life
-- Where grass grows, the air is alive too: flocks of birds cross the sky in V
-- formations by day, butterflies flutter over the meadow, and at night fireflies
-- drift above the grass. All client-side and recycled (no server cost).
local Lighting = game:GetService("Lighting")
local lifeFolder: Folder? = nil
local flocks, flutter, fireflies = {}, {}, {}
local lifeParts, lifeCFs = {}, {}

local function lifePart(size: Vector3, color: Color3, mat: Enum.Material?): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.CFrame = HIDE
	p.Parent = lifeFolder
	return p
end

local function nightK(): number
	local c = Lighting.ClockTime
	if c >= 20 or c <= 5 then
		return 1
	elseif c > 18.5 then
		return (c - 18.5) / 1.5
	elseif c < 6.5 then
		return 1 - (c - 5) / 1.5
	end
	return 0
end

local function makeFlock()
	local f = { birds = {}, active = false }
	local col = if math.random() < 0.5 then Color3.fromRGB(40, 38, 42) else Color3.fromRGB(236, 234, 228)
	for i = 1, 9 do
		local b = {
			body = lifePart(V(0.5, 0.4, 1.3), col),
			l = lifePart(V(1.9, 0.08, 0.8), col),
			r = lifePart(V(1.9, 0.08, 0.8), col),
			i = i,
			phase = math.random() * 6.28,
		}
		table.insert(f.birds, b)
	end
	return f
end

local function launchFlock(f, cp: Vector3)
	local a = math.random() * math.pi * 2
	local dir = V(math.cos(a), 0, math.sin(a))
	local side = V(-dir.Z, 0, dir.X)
	f.dir = dir
	f.speed = 26 + math.random() * 16
	f.pos = cp - dir * 480 + side * (math.random() - 0.5) * 360 + V(0, 70 + math.random() * 90, 0)
	f.left = 1000 / f.speed
	f.active = true
	f.n = math.random(5, 9)
end

local function stepFlock(f, dt: number, now: number)
	f.pos += f.dir * f.speed * dt
	f.left -= dt
	local rot = CFrame.lookAt(V(), f.dir)
	for _, b in f.birds do
		if b.i > f.n or f.left <= 0 then
			b.body.CFrame, b.l.CFrame, b.r.CFrame = HIDE, HIDE, HIDE
			continue
		end
		-- a V: the leader in front, the rest trailing on alternate sides
		local rank = math.floor(b.i / 2)
		local sx = if b.i % 2 == 0 then 1 else -1
		local p = f.pos + rot:VectorToWorldSpace(V(sx * rank * 4.5, math.sin(now * 0.7 + b.phase) * 1.2, rank * 5))
		local glide = math.sin(now * 0.4 + b.phase) > 0.55
		local flap = if glide then 0.08 else math.sin(now * 9 + b.phase) * 0.7
		local base = CF(p) * rot
		table.insert(lifeParts, b.body)
		table.insert(lifeCFs, base)
		table.insert(lifeParts, b.l)
		table.insert(lifeCFs, base * CF(-0.25, 0.1, 0) * ANG(0, 0, flap) * CF(-0.95, 0, 0))
		table.insert(lifeParts, b.r)
		table.insert(lifeCFs, base * CF(0.25, 0.1, 0) * ANG(0, 0, -flap) * CF(0.95, 0, 0))
	end
	if f.left <= 0 then
		f.active = false
	end
end

local BUTTERFLY = { Color3.fromRGB(250, 220, 70), Color3.fromRGB(245, 245, 250), Color3.fromRGB(240, 130, 60), Color3.fromRGB(130, 170, 250), Color3.fromRGB(230, 120, 200) }
local function makeFlutter()
	local col = BUTTERFLY[math.random(1, #BUTTERFLY)]
	return { l = lifePart(V(0.45, 0.03, 0.4), col), r = lifePart(V(0.45, 0.03, 0.4), col), placed = false, phase = math.random() * 6.28 }
end

local function makeFirefly()
	return { p = lifePart(V(0.22, 0.22, 0.22), Color3.fromRGB(210, 255, 120), Enum.Material.Neon), placed = false, phase = math.random() * 6.28 }
end

-- a spot above a planted near tuft (the grass already knows where the ground is)
local function meadowSpot(): Vector3?
	for _ = 1, 6 do
		local t = near[math.random(1, #near)]
		if t and t.placed then
			return t.pos
		end
	end
	return nil
end

local function stepLife(dt: number, now: number)
	table.clear(lifeParts)
	table.clear(lifeCFs)
	local cp = cam.CFrame.Position
	local outdoors = os.clock() - lastGrassAt < 3
	local nk = nightK()
	-- birds (by day)
	for _, f in flocks do
		if f.active then
			stepFlock(f, dt, now)
		elseif outdoors and nk < 0.5 and math.random() < dt / 9 then
			launchFlock(f, cp)
		end
	end
	-- butterflies (by day) and fireflies (by night) over the meadow
	for _, b in flutter do
		local want = outdoors and nk < 0.4
		if b.placed and (not want or (b.home - cp).Magnitude > 70) then
			b.placed = false
			b.l.CFrame, b.r.CFrame = HIDE, HIDE
		elseif not b.placed and want then
			local s = meadowSpot()
			if s then
				b.home = s
				b.placed = true
			end
		end
		if b.placed then
			local t = now + b.phase
			local p = b.home + V(math.sin(t * 0.7) * 4, 1.4 + math.sin(t * 1.3) * 0.8, math.cos(t * 0.53) * 4)
			local base = CFrame.lookAt(p, p + V(math.cos(t * 0.7), 0, -math.sin(t * 0.53)))
			local flap = math.sin(now * 22 + b.phase) * 0.9
			table.insert(lifeParts, b.l)
			table.insert(lifeCFs, base * ANG(0, 0, flap) * CF(-0.22, 0, 0))
			table.insert(lifeParts, b.r)
			table.insert(lifeCFs, base * ANG(0, 0, -flap) * CF(0.22, 0, 0))
		end
	end
	for _, f in fireflies do
		local want = outdoors and nk > 0.5
		if f.placed and (not want or (f.home - cp).Magnitude > 80) then
			f.placed = false
			f.p.CFrame = HIDE
		elseif not f.placed and want then
			local s = meadowSpot()
			if s then
				f.home = s + V(math.random() * 6 - 3, 0, math.random() * 6 - 3)
				f.placed = true
			end
		end
		if f.placed then
			local t = now * 0.6 + f.phase
			table.insert(lifeParts, f.p)
			table.insert(lifeCFs, CF(f.home + V(math.sin(t) * 2.5, 1.2 + math.sin(t * 1.7) * 0.9, math.cos(t * 0.8) * 2.5)))
			f.p.Transparency = 0.2 + 0.8 * (0.5 + 0.5 * math.sin(now * 2.3 + f.phase * 3)) ^ 3
		end
	end
	if #lifeParts > 0 then
		workspace:BulkMoveTo(lifeParts, lifeCFs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- ------------------------------------------------------------------ cull
local CULL = { Props = 1050, Fields = 900, Houses = 1500, Farms = 900 }
local CELL = 256
local hold = Instance.new("Folder")
hold.Name = "CullHold"
hold.Parent = ReplicatedStorage
local cells = {} -- key -> {items = {{inst, parent}}, hidden, x, z, dist}
local known = setmetatable({}, { __mode = "k" })

local function cellOf(inst: Instance): Vector3?
	if inst:IsA("Model") then
		local ok, cf = pcall(inst.GetPivot, inst)
		return if ok then cf.Position else nil
	elseif inst:IsA("BasePart") then
		return inst.Position
	end
	return nil
end

local function track(folder: Instance, dist: number)
	for _, ch in folder:GetChildren() do
		if not known[ch] then
			local p = cellOf(ch)
			if p then
				known[ch] = true
				local ix, iz = math.floor(p.X / CELL), math.floor(p.Z / CELL)
				local key = ix .. ":" .. iz .. ":" .. dist
				local c = cells[key]
				if not c then
					c = { items = {}, hidden = false, x = (ix + 0.5) * CELL, z = (iz + 0.5) * CELL, dist = dist }
					cells[key] = c
				end
				table.insert(c.items, { ch, folder })
				if c.hidden then
					ch.Parent = hold
				end
			end
		end
	end
end

local function cullTick()
	local world = workspace:FindFirstChild("World")
	if world then
		for name, dist in CULL do
			local f = world:FindFirstChild(name)
			if f then
				track(f, dist)
			end
		end
	end
	local cp = cam.CFrame.Position
	for key, c in cells do
		local dx, dz = c.x - cp.X, c.z - cp.Z
		local d = math.sqrt(dx * dx + dz * dz)
		local hide = d > c.dist + 80
		local show = d < c.dist
		local alive = 0
		for i = #c.items, 1, -1 do
			local it = c.items[i]
			local inst, parent = it[1], it[2]
			if not parent:IsDescendantOf(workspace) then
				-- the world was torn down on the server: drop our parked copy too
				if inst.Parent == hold then
					inst:Destroy()
				end
				table.remove(c.items, i)
			elseif inst.Parent ~= hold and inst.Parent ~= parent then
				table.remove(c.items, i)
			else
				alive += 1
				if hide and inst.Parent == parent then
					inst.Parent = hold
				elseif show and inst.Parent == hold then
					inst.Parent = parent
				end
			end
		end
		if hide then
			c.hidden = true
		elseif show then
			c.hidden = false
		end
		if alive == 0 then
			cells[key] = nil
		end
	end
end

function Ambient.init()
	for _, m in CollectionService:GetTagged("Critter") do
		task.spawn(register, m)
	end
	CollectionService:GetInstanceAddedSignal("Critter"):Connect(function(m)
		task.defer(register, m)
	end)
	CollectionService:GetInstanceRemovedSignal("Critter"):Connect(unregister)
	for _, p in CollectionService:GetTagged("Sway") do
		addSway(p)
	end
	CollectionService:GetInstanceAddedSignal("Sway"):Connect(function(p)
		task.defer(addSway, p)
	end)
	CollectionService:GetInstanceRemovedSignal("Sway"):Connect(function(p)
		swayers[p] = nil
	end)
	local tf = Instance.new("Folder")
	tf.Name = "GrassTufts"
	tf.Parent = workspace
	tuftFolder = tf
	for _ = 1, NEAR.n do
		table.insert(near, makeTuft(3, false))
	end
	for _ = 1, FAR.n do
		table.insert(far, makeTuft(2, true))
	end
	local lf = Instance.new("Folder")
	lf.Name = "Wildlife"
	lf.Parent = workspace
	lifeFolder = lf
	for _ = 1, 3 do
		table.insert(flocks, makeFlock())
	end
	for _ = 1, 14 do
		table.insert(flutter, makeFlutter())
	end
	for _ = 1, 40 do
		table.insert(fireflies, makeFirefly())
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 / 30 then
			return
		end
		local step = acc
		acc = 0
		local now = os.clock()
		local cp = cam.CFrame.Position
		for m, c in critters do
			if not m.Parent then
				critters[m] = nil
			else
				local d = (c.pos - cp).Magnitude
				if d < 260 then
					stepCritter(c, step, now)
				end
			end
		end
		pcall(stepGrass, now)
		pcall(stepLife, step, now)
		-- wind: a slow gust envelope over a steady sway
		local gust = 0.6 + 0.4 * math.sin(now * 0.37) * math.sin(now * 0.23 + 1)
		for p, s in swayers do
			if not p.Parent then
				swayers[p] = nil
			else
				local dx, dz = s.pivot.X - cp.X, s.pivot.Z - cp.Z
				if dx * dx + dz * dz < 140 * 140 then
					local a = s.amp * gust
					local rx = math.sin(now * 1.9 + s.phase) * a
					local rz = math.sin(now * 1.3 + s.phase * 1.7) * a * 0.6 + a * 0.4
					p.CFrame = CF(s.pivot) * ANG(rx, 0, rz) * CF(-s.pivot) * s.rest
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.6)
			local ok, err = pcall(cullTick)
			if not ok then
				warn("[Ambient] cull: " .. tostring(err))
			end
		end
	end)
end

return Ambient
