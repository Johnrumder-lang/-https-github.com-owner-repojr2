--!nonstrict
-- Life in the landscape, all client-side:
--  * Critters: farm animals graze, wander inside their pens, walk (legs swing),
--    peck and wag their tails. The server builds them once and never moves them.
--  * Sway: flowers, reeds, crops and leaf clusters bend in the wind near the camera.
--  * Cull: far-away props, houses and fields are parked outside the workspace so a
--    huge world renders like a small one (they come back as you approach).
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ambient = {}
local cam = workspace.CurrentCamera
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
