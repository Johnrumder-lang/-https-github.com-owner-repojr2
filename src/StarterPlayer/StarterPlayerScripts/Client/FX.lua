--!nonstrict
-- Client VFX: cubic blood, sparks, shockwaves, damage numbers, health bars,
-- speech bubbles, telegraphs. Everything freezes during time stop.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Palette = require(Shared.Palette)
local Util = require(Shared.Util)
local C = require(script.Parent.C)

local FX = {}
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local folder: any = nil
local holder: any = nil
local frozen = false
local frozenParts = {} -- [part] = velocity
local live = {} -- ring buffer of debris cubes
local MAX_CUBES = 380
local rng = Random.new()
local rgb = Color3.fromRGB

local function getFolder()
	if folder and folder.Parent then
		return folder
	end
	folder = Instance.new("Folder")
	folder.Name = "ClientFX"
	folder.Parent = workspace
	holder = Instance.new("Part")
	holder.Name = "FXHolder"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new()
	holder.Parent = folder
	return folder
end

local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function attachAt(pos: Vector3): Attachment
	getFolder()
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = holder
	return a
end

local function fxPartPlain(color: Color3, _t: number?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- ------------------------------------------------------------------ cubes
local function cube(pos: Vector3, size: number, color: Color3, vel: Vector3?, life: number, opts)
	getFolder()
	opts = opts or {}
	local p = Instance.new("Part")
	p.Size = Vector3.one * size
	p.Color = color
	p.Material = opts.material or Enum.Material.SmoothPlastic
	p.CanCollide = opts.collide ~= false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CustomPhysicalProperties = PhysicalProperties.new(0.05, 0.4, 0.1, 1, 1)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber() * 6, rng:NextNumber() * 6, rng:NextNumber() * 6)
	if opts.transparency then
		p.Transparency = opts.transparency
	end
	if opts.anchored then
		p.Anchored = true
	elseif frozen then
		p.Anchored = true
		frozenParts[p] = vel or Vector3.zero
	else
		p.Anchored = false
	end
	p.Parent = folder
	if not p.Anchored and vel then
		p.AssemblyLinearVelocity = vel
		p.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-10, 10), rng:NextNumber(-10, 10))
	end
	table.insert(live, p)
	if #live > MAX_CUBES then
		local old = table.remove(live, 1)
		if old then
			frozenParts[old] = nil
			old:Destroy()
		end
	end
	task.delay(life, function()
		if p.Parent and not frozenParts[p] then
			tween(p, 0.4, { Size = Vector3.one * 0.05, Transparency = 1 })
			Debris:AddItem(p, 0.45)
		elseif p.Parent then
			-- still frozen: retry later
			task.delay(1, function()
				if p.Parent then
					p:Destroy()
				end
			end)
		end
	end)
	return p
end
FX.cube = cube

function FX.setFrozen(on: boolean)
	frozen = on
	if on then
		for _, p in live do
			if p.Parent and not p.Anchored then
				frozenParts[p] = p.AssemblyLinearVelocity
				p.Anchored = true
			end
		end
	else
		for p, v in frozenParts do
			if p.Parent then
				p.Anchored = false
				p.AssemblyLinearVelocity = v
				p.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12), rng:NextNumber(-12, 12))
			end
		end
		frozenParts = {}
	end
end

local function flatSquare(pos: Vector3, size: number, color: Color3, life: number)
	getFolder()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, cam, player.Character }
	local r = workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -14, 0), params)
	if not r or r.Instance:IsDescendantOf(workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Entities") or folder) then
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = Vector3.new(size, 0.08, size)
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CFrame = CFrame.new(r.Position + r.Normal * 0.05) * CFrame.Angles(0, rng:NextNumber() * 6, 0)
	p.Parent = folder
	task.delay(life, function()
		if p.Parent then
			tween(p, 2, { Transparency = 1 })
			Debris:AddItem(p, 2.1)
		end
	end)
end

-- ------------------------------------------------------------------ wall / floor blood
-- Blood sticks: every real hit throws a few rays along the knockback; where they meet
-- a wall or floor a flat splat is painted (with drips running down walls). Splats
-- live a long time and are recycled oldest-first.
local splats = {}
local MAX_SPLATS = 220
local splatParams = RaycastParams.new()
splatParams.FilterType = Enum.RaycastFilterType.Exclude
splatParams.IgnoreWater = true
local lastFilterAt = 0
local function refreshSplatFilter()
	if os.clock() - lastFilterAt < 1 then
		return
	end
	lastFilterAt = os.clock()
	local list = { getFolder(), cam }
	for _, m in game:GetService("CollectionService"):GetTagged("Rig") do
		table.insert(list, m)
	end
	local fx = workspace:FindFirstChild("FX")
	if fx then
		table.insert(list, fx)
	end
	splatParams.FilterDescendantsInstances = list
end

local function addSplat(p: BasePart)
	p.Parent = folder
	table.insert(splats, p)
	if #splats > MAX_SPLATS then
		local old = table.remove(splats, 1)
		if old then
			old:Destroy()
		end
	end
	task.delay(45 + rng:NextNumber() * 20, function()
		if p.Parent then
			tween(p, 3, { Transparency = 1 })
			Debris:AddItem(p, 3.1)
		end
	end)
end

local function paint(hitPos: Vector3, normal: Vector3, size: number, color: Color3)
	local base = CFrame.lookAt(hitPos + normal * 0.03, hitPos + normal * 2) * CFrame.Angles(0, 0, rng:NextNumber() * math.pi * 2)
	-- a blocky splat: a main square and a couple of offset squares (cubic, like the rest)
	for i = 1, 3 do
		local sz = size * (if i == 1 then 1 else rng:NextNumber(0.3, 0.6))
		local off = if i == 1 then Vector3.zero else Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), 0) * size * 0.6
		local sp = fxPartPlain(Palette.jitter(color, 0.12, rng:NextNumber()), 0.04 + i * 0.002)
		sp.Size = Vector3.new(sz, sz * rng:NextNumber(0.6, 1.1), 0.05)
		sp.CFrame = base * CFrame.new(off.X, off.Y, i * 0.004)
		addSplat(sp)
	end
	-- drips on walls
	if math.abs(normal.Y) < 0.5 and rng:NextNumber() < 0.7 then
		local down = (Vector3.new(0, -1, 0) - normal * normal:Dot(Vector3.new(0, -1, 0)))
		if down.Magnitude > 0.1 then
			down = down.Unit
			for _ = 1, rng:NextInteger(1, 2) do
				local len = rng:NextNumber(0.8, 3) * math.max(size, 0.6)
				local side = normal:Cross(down).Unit * rng:NextNumber(-size * 0.35, size * 0.35)
				local d = fxPartPlain(Palette.shade(color, 0.85), 0.03)
				d.Size = Vector3.new(rng:NextNumber(0.09, 0.18), len, 0.04)
				local top = hitPos + normal * 0.04 + side
				d.CFrame = CFrame.fromMatrix(top + down * len / 2, normal:Cross(down).Unit, -down)
				addSplat(d)
				-- drips crawl down a little over time
				d.Size = Vector3.new(d.Size.X, len * 0.3, 0.04)
				d.CFrame = CFrame.fromMatrix(top + down * len * 0.15, normal:Cross(down).Unit, -down)
				tween(d, rng:NextNumber(1.5, 3.5), { Size = Vector3.new(d.Size.X, len, 0.04), CFrame = CFrame.fromMatrix(top + down * len / 2, normal:Cross(down).Unit, -down) }, Enum.EasingStyle.Sine)
			end
		end
	end
end

function FX.splatter(pos: Vector3, dir: Vector3, color: Color3, n: number, reach: number?)
	if not C.settings.blood then
		return
	end
	refreshSplatFilter()
	local d0 = if dir.Magnitude > 0.01 then dir.Unit else Vector3.new(0, -1, 0)
	local dist = reach or 16
	for i = 1, n do
		-- most rays follow the hit, a few fall to the floor under the victim
		local v
		if i % 3 == 0 then
			v = Vector3.new(rng:NextNumber(-0.4, 0.4), -1, rng:NextNumber(-0.4, 0.4))
		else
			v = d0 + Vector3.new(rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.5, 0.35), rng:NextNumber(-0.6, 0.6))
		end
		local r = workspace:Raycast(pos, v.Unit * dist, splatParams)
		if r and r.Instance and r.Instance.Transparency < 0.9 then
			local k = 1 - r.Distance / dist
			task.delay(r.Distance / 60, function()
				paint(r.Position, r.Normal, 0.5 + k * 1.3 + rng:NextNumber() * 0.5, color)
			end)
		end
	end
end

function FX.blood(pos: Vector3, dir: Vector3, color: Color3, count: number, speed: number, frozenHit: boolean?)
	if not C.settings.blood then
		color = rgb(230, 230, 230)
	end
	for i = 1, count do
		local spread = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.2, 1), rng:NextNumber(-1, 1)) * 0.75
		local v = (dir + spread).Unit * speed * rng:NextNumber(0.4, 1.1) + Vector3.new(0, rng:NextNumber(4, 14), 0)
		local p0 = pos
		if frozen or frozenHit then
			p0 = pos + v * rng:NextNumber(0.015, 0.09)
		end
		cube(p0, rng:NextNumber(0.18, 0.5), Palette.jitter(color, 0.18, rng:NextNumber()), v, rng:NextNumber(2.5, 4.5))
	end
	if not (frozen or frozenHit) and count >= 3 then
		FX.splatter(pos, dir, Palette.shade(color, 0.75), math.clamp(math.floor(count / 2), 2, 10))
		if count >= 8 then
			flatSquare(pos + Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5)), rng:NextNumber(1.4, 3), Palette.shade(color, 0.6), 30)
		end
	end
end

function FX.burst(pos: Vector3, color: Color3, count: number, speed: number, size: number?, neon: boolean?, life: number?)
	for _ = 1, count do
		local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.3, 1), rng:NextNumber(-1, 1)).Unit * speed * rng:NextNumber(0.5, 1)
		cube(pos, (size or 0.35) * rng:NextNumber(0.6, 1.3), color, v, life or rng:NextNumber(0.6, 1.4), { material = if neon then Enum.Material.Neon else nil, collide = not neon })
	end
end

function FX.flash(pos: Vector3, color: Color3, size: number, t: number?)
	getFolder()
	-- cubic flash: a spinning neon cube that blows up and fades (plus a white core)
	local core = Instance.new("Part")
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.CastShadow = false
	core.Material = Enum.Material.Neon
	core.Color = color:Lerp(Color3.new(1, 1, 1), 0.7)
	core.Size = Vector3.one * size * 0.18
	core.CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber() * 6, rng:NextNumber() * 6, rng:NextNumber() * 6)
	core.Parent = folder
	tween(core, (t or 0.25) * 0.7, { Size = Vector3.one * size * 0.45, Transparency = 1, CFrame = core.CFrame * CFrame.Angles(0.8, 0.8, 0) })
	Debris:AddItem(core, (t or 0.25) + 0.05)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.one * size * 0.3
	p.Transparency = 0.35
	p.CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber() * 6, rng:NextNumber() * 6, rng:NextNumber() * 6)
	p.Parent = folder
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = size * 3
	l.Brightness = 4
	l.Parent = p
	tween(p, t or 0.25, { Size = Vector3.one * size * 0.8, Transparency = 1, CFrame = p.CFrame * CFrame.Angles(0.6, -0.6, 0.3) })
	tween(l, t or 0.25, { Brightness = 0 })
	Debris:AddItem(p, (t or 0.25) + 0.05)
end

function FX.ring(pos: Vector3, radius: number, color: Color3, t: number?, height: number?)
	getFolder()
	local n = math.clamp(math.floor(radius * 1.6), 12, 48)
	local dur = t or 0.5
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Size = Vector3.new(0.9, height or 0.9, 0.9)
		p.CFrame = CFrame.lookAt(pos + dir * 1.5, pos + dir * 3)
		p.Parent = folder
		tween(p, dur, { CFrame = CFrame.lookAt(pos + dir * radius, pos + dir * (radius + 1)) * CFrame.new(0, 0.5, 0), Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 }, Enum.EasingStyle.Quart)
		Debris:AddItem(p, dur + 0.05)
	end
	local disc = Instance.new("Part")
	disc.Shape = Enum.PartType.Cylinder
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Material = Enum.Material.ForceField
	disc.Color = color
	disc.Size = Vector3.new(0.4, 2, 2)
	disc.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	disc.Parent = folder
	tween(disc, dur, { Size = Vector3.new(0.4, radius * 2, radius * 2), Transparency = 1 }, Enum.EasingStyle.Quart)
	Debris:AddItem(disc, dur + 0.05)
end

-- ------------------------------------------------------------------ billboards
local function billboard(pos: Vector3, size: UDim2, life: number)
	local a = attachAt(pos)
	local bb = Instance.new("BillboardGui")
	bb.Adornee = a
	bb.Size = size
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 250
	bb.Parent = a
	Debris:AddItem(a, life)
	return bb, a
end

local frozenNumbers = {} -- [model] = {bb, label, total, n}
function FX.number(pos: Vector3, amount: number, opts)
	if not C.settings.damageNumbers then
		return
	end
	opts = opts or {}
	local big = opts.crit or opts.released
	local bb, a = billboard(pos + Vector3.new(rng:NextNumber(-1, 1), 1.5, rng:NextNumber(-1, 1)), UDim2.fromOffset(if big then 220 else 140, if big then 70 else 44), 1.6)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.Arcade
	t.TextScaled = true
	t.TextStrokeTransparency = 0
	t.TextStrokeColor3 = Color3.new(0, 0, 0)
	local txt = tostring(math.max(1, math.floor(amount + 0.5)))
	if opts.hits and opts.hits > 1 then
		txt ..= "  x" .. opts.hits
	end
	t.Text = txt
	t.TextColor3 = if opts.released then rgb(255, 60, 70) elseif opts.crit then rgb(255, 220, 60) elseif opts.player then rgb(255, 90, 90) else rgb(255, 255, 255)
	t.Parent = bb
	local up = if big then 4.5 else 3
	tween(a, 1.2, { WorldPosition = a.WorldPosition + Vector3.new(0, up, 0) }, Enum.EasingStyle.Quint)
	if big then
		t.Size = UDim2.fromScale(1.6, 1.6)
		t.Position = UDim2.fromScale(-0.3, -0.3)
		tween(t, 0.25, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Back)
	end
	task.delay(0.8, function()
		tween(t, 0.6, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
end

function FX.frozenNumber(model: Instance?, pos: Vector3, amount: number)
	if not model then
		FX.number(pos, amount, {})
		return
	end
	local e = frozenNumbers[model]
	if not e or not e.bb.Parent then
		local bb = billboard(pos + Vector3.new(0, 3.5, 0), UDim2.fromOffset(180, 50), 30)
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.Arcade
		t.TextScaled = true
		t.TextStrokeTransparency = 0
		t.TextColor3 = rgb(210, 210, 215)
		t.Parent = bb
		e = { bb = bb, label = t, total = 0, n = 0 }
		frozenNumbers[model] = e
	end
	e.total += amount
	e.n += 1
	e.label.Text = string.format("%d  x%d", math.floor(e.total + 0.5), e.n)
	e.label.Size = UDim2.fromScale(1.3, 1.3)
	e.label.Position = UDim2.fromScale(-0.15, -0.15)
	tween(e.label, 0.12, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0) })
end

local function clearFrozenNumber(model)
	local e = model and frozenNumbers[model]
	if e then
		frozenNumbers[model] = nil
		if e.bb and e.bb.Parent then
			local a = e.bb.Adornee
			if a then
				a:Destroy()
			end
		end
	end
end

local function textPop(pos: Vector3, text: string, color: Color3, size: number?)
	local bb, a = billboard(pos, UDim2.fromOffset(200 * (size or 1), 50 * (size or 1)), 1.4)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.Arcade
	t.TextScaled = true
	t.TextStrokeTransparency = 0
	t.Text = text
	t.TextColor3 = color
	t.Parent = bb
	tween(a, 1.2, { WorldPosition = pos + Vector3.new(0, 3, 0) }, Enum.EasingStyle.Quint)
	task.delay(0.7, function()
		tween(t, 0.6, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
end
FX.textPop = textPop

-- health bars over NPCs
local bars = {}
local function healthBar(model: Model)
	if not model or not model.Parent or model:GetAttribute("Boss") or game:GetService("Players"):GetPlayerFromCharacter(model) then
		return
	end
	local head = model:FindFirstChild("Head") or model.PrimaryPart
	if not head then
		return
	end
	local b = bars[model]
	if not b or not b.gui.Parent then
		local gui = Instance.new("BillboardGui")
		gui.Adornee = head
		gui.Size = UDim2.fromOffset(120, 26)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 2.2 * model:GetScale(), 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 140
		gui.LightInfluence = 0
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Size = UDim2.new(1, 0, 0, 12)
		name.Font = Enum.Font.Arcade
		name.TextSize = 12
		name.TextColor3 = Color3.new(1, 1, 1)
		name.TextStrokeTransparency = 0.3
		local lvl = model:GetAttribute("Level")
		name.Text = (model:GetAttribute("DisplayName") or model.Name) .. (if lvl then "  Lv" .. lvl else "")
		name.Parent = gui
		local back = Instance.new("Frame")
		back.Size = UDim2.new(1, 0, 0, 9)
		back.Position = UDim2.fromOffset(0, 14)
		back.BackgroundColor3 = Color3.new(0.08, 0.02, 0.04)
		back.BorderSizePixel = 0
		back.Parent = gui
		local st = Instance.new("UIStroke")
		st.Thickness = 1.5
		st.Color = Color3.new(0, 0, 0)
		st.Parent = back
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = rgb(230, 50, 60)
		fill.BorderSizePixel = 0
		fill.Parent = back
		gui.Parent = head
		b = { gui = gui, fill = fill, until_ = 0 }
		bars[model] = b
	end
	b.until_ = os.clock() + 5
	b.gui.Enabled = true
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for model, b in bars do
		if not model.Parent or not b.gui.Parent then
			bars[model] = nil
		else
			local hum = model:FindFirstChildOfClass("Humanoid")
			local hp, max = 1, 1
			if hum then
				hp, max = hum.Health, hum.MaxHealth
			else
				hp, max = model:GetAttribute("Hp") or 1, model:GetAttribute("MaxHp") or 1
			end
			b.fill.Size = UDim2.fromScale(math.clamp(hp / math.max(max, 1), 0, 1), 1)
			if now > b.until_ or hp <= 0 then
				b.gui.Enabled = false
			end
		end
	end
end)

-- Talking: flip a character's mouth open/closed for `dur` seconds.
local talking = setmetatable({}, { __mode = "k" })
function FX.talk(model: Model?, dur: number)
	local head = model and model:FindFirstChild("Head")
	local face = head and head:FindFirstChild("Face")
	if not face then
		return
	end
	local closed, open = {}, {}
	for _, f in face:GetChildren() do
		if f.Name == "Mouth" then
			table.insert(closed, f)
		elseif f.Name == "MouthOpen" then
			table.insert(open, f)
		end
	end
	if #open == 0 then
		return
	end
	local token = {}
	talking[model] = token
	task.spawn(function()
		local t0 = os.clock()
		local isOpen = false
		while os.clock() - t0 < dur and talking[model] == token and face.Parent do
			isOpen = not isOpen
			for _, f in closed do
				f.Visible = not isOpen
			end
			for _, f in open do
				f.Visible = isOpen
			end
			task.wait(if isOpen then 0.07 + math.random() * 0.08 else 0.05 + math.random() * 0.12)
		end
		if talking[model] == token then
			for _, f in closed do
				f.Visible = true
			end
			for _, f in open do
				f.Visible = false
			end
		end
	end)
end

-- The rig that is speaking a dialogue line: nearest character with that name.
function FX.speaker(name: string?): Model?
	if not name or name == "" or name == "You" then
		return nil
	end
	local best, bd = nil, 160
	local cp = workspace.CurrentCamera.CFrame.Position
	for _, m in CollectionService:GetTagged("Rig") do
		if m:IsA("Model") and (m.Name == name or m:GetAttribute("DisplayName") == name) and m ~= Players.LocalPlayer.Character then
			local ok, cf = pcall(m.GetPivot, m)
			if ok then
				local d = (cf.Position - cp).Magnitude
				if d < bd then
					best, bd = m, d
				end
			end
		end
	end
	return best
end

function FX.shout(model: Model?, text: string, dur: number?)
	if not model then
		return
	end
	FX.talk(model, math.min(dur or 3, 0.5 + #text * 0.045))
	local head = model:FindFirstChild("Head") or model.PrimaryPart
	if not head then
		return
	end
	local old = head:FindFirstChild("Shout")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Shout"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(260, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.4 * model:GetScale(), 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	local panel = Instance.new("Frame")
	panel.AutomaticSize = Enum.AutomaticSize.XY
	panel.Size = UDim2.fromOffset(0, 0)
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.fromScale(0.5, 1)
	panel.BackgroundColor3 = rgb(250, 250, 250)
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Color = Color3.new(0, 0, 0)
	st.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = panel
	local t = Instance.new("TextLabel")
	t.AutomaticSize = Enum.AutomaticSize.XY
	t.Size = UDim2.fromOffset(0, 0)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.Arcade
	t.TextSize = 16
	t.TextColor3 = Color3.new(0, 0, 0)
	t.Text = text
	t.Parent = panel
	gui.Parent = head
	Debris:AddItem(gui, dur or 2.6)
end

function FX.highlight(model: Instance?, color: Color3, t: number, fill: number?)
	if not model or not model.Parent then
		return
	end
	local h = Instance.new("Highlight")
	h.FillColor = color
	h.OutlineColor = color
	h.FillTransparency = fill or 0.35
	h.OutlineTransparency = 0.2
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	tween(h, t, { FillTransparency = 1, OutlineTransparency = 1 })
	Debris:AddItem(h, t + 0.05)
end

function FX.fadeModel(model: Instance?)
	if not model then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			tween(d, 1.1, { LocalTransparencyModifier = 1 })
		elseif d:IsA("SurfaceGui") then
			d.Enabled = false
		end
	end
end

-- dark aura on bosses that "farm aura"
local auraFx = {}
task.spawn(function()
	while true do
		task.wait(0.25)
		for _, m in game:GetService("CollectionService"):GetTagged("Rig") do
			local a = m:GetAttribute("Aura")
			if a then
				local e = auraFx[m]
				if not e or not e.Parent then
					local torso = m:FindFirstChild("Torso")
					if torso then
						e = Instance.new("ParticleEmitter")
						e.Texture = "rbxasset://textures/particles/smoke_main.dds"
						e.Color = ColorSequence.new(rgb(20, 0, 6), rgb(120, 0, 20))
						e.LightEmission = 0.2
						e.Lifetime = NumberRange.new(0.5, 1)
						e.Speed = NumberRange.new(2, 6)
						e.SpreadAngle = Vector2.new(180, 180)
						e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) })
						e.Transparency = NumberSequence.new(0.3, 1)
						e.Acceleration = Vector3.new(0, 6, 0)
						e.Parent = torso
						auraFx[m] = e
					end
				end
				if e then
					e.Rate = 4 + a * 0.9
				end
			end
		end
		for m, e in auraFx do
			if not m.Parent then
				auraFx[m] = nil
			end
		end
	end
end)

-- ------------------------------------------------------------------ misc visuals
local speedGui: any = nil
-- Ultrakill-style speed lines: thin bright streaks that rush from the screen edges
-- toward the centre. One persistent pool (no per-frame instances). FX.setSpeed(k)
-- is fed every frame by the Controller (k 0..1); FX.speedLines(t) is a short burst.
local SPEED_N = 40
local speedLines = {}
local speedK, burstUntil, burstK = 0, 0, 0
local function ensureSpeedGui()
	if speedGui and speedGui.Parent then
		return
	end
	speedGui = Instance.new("ScreenGui")
	speedGui.Name = "SpeedLines"
	speedGui.IgnoreGuiInset = true
	speedGui.ResetOnSpawn = false
	speedGui.DisplayOrder = 2
	speedGui.Enabled = false
	speedGui.Parent = player:WaitForChild("PlayerGui")
	speedLines = {}
	for i = 1, SPEED_N do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BackgroundTransparency = 1
		f.Parent = speedGui
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.1), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = f
		table.insert(speedLines, {
			f = f,
			g = g,
			a = (i / SPEED_N) * math.pi * 2 + rng:NextNumber(-0.06, 0.06),
			p = rng:NextNumber(),
			v = rng:NextNumber(1.6, 2.6),
			w = rng:NextNumber(1, 2.4),
		})
	end
end

function FX.setSpeed(k: number)
	speedK = math.clamp(k or 0, 0, 1)
end

function FX.speedLines(t: number)
	burstUntil = os.clock() + (t or 0.25)
	burstK = 0.85
end

local function stepSpeedLines(dt: number)
	local k = speedK
	if os.clock() < burstUntil then
		k = math.max(k, burstK * math.clamp((burstUntil - os.clock()) / 0.25, 0, 1))
	end
	if k < 0.02 then
		if speedGui then
			speedGui.Enabled = false
		end
		return
	end
	ensureSpeedGui()
	speedGui.Enabled = true
	local vp = cam.ViewportSize
	local cx, cy = vp.X / 2, vp.Y / 2
	local R = math.sqrt(cx * cx + cy * cy)
	for _, l in speedLines do
		l.p += dt * l.v * (0.8 + k)
		if l.p > 1 then
			l.p -= 1
			l.a = rng:NextNumber() * math.pi * 2
			l.v = rng:NextNumber(1.6, 2.6)
		end
		-- radial position: from beyond the edge (1.15) inward to 0.55 of the half-diagonal
		local r = (1.15 - l.p * 0.6) * R
		local len = (0.1 + 0.22 * k) * R
		local dx, dy = math.cos(l.a), math.sin(l.a)
		local f = l.f
		f.Position = UDim2.fromOffset(cx + dx * r, cy + dy * r)
		f.Size = UDim2.fromOffset(len, l.w * (0.7 + k * 0.6))
		f.Rotation = math.deg(math.atan2(dy, dx))
		-- fade in when entering, out near the inner end; stronger with speed
		local fade = math.sin(math.clamp(l.p, 0, 1) * math.pi)
		f.BackgroundTransparency = 1 - math.clamp(fade * k * 0.75, 0, 0.75)
	end
end
RunService.RenderStepped:Connect(stepSpeedLines)

function FX.puff(pos: Vector3)
	for _ = 1, 8 do
		local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0, 0.3), rng:NextNumber(-1, 1)).Unit * rng:NextNumber(6, 14)
		cube(pos, rng:NextNumber(0.3, 0.6), rgb(230, 230, 235), v, 0.6, { collide = false, transparency = 0.3 })
	end
end

function FX.parrySpark()
	local tip = C.Viewmodel.tipPosition()
	local p = tip or (cam.CFrame * CFrame.new(0, -0.5, -3)).Position
	FX.burst(p, rgb(255, 240, 180), 14, 26, 0.18, true, 0.35)
	FX.flash(p, rgb(255, 250, 220), 4, 0.15)
end

function FX.zap(from: Vector3, to: Vector3, color: Color3)
	getFolder()
	local segs = 6
	local prev = from
	for i = 1, segs do
		local t = i / segs
		local p = from:Lerp(to, t) + (if i < segs then Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) else Vector3.zero)
		local d = (p - prev).Magnitude
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Material = Enum.Material.Neon
		part.Color = color
		part.Size = Vector3.new(0.2, 0.2, d)
		part.CFrame = CFrame.lookAt((p + prev) / 2, p)
		part.Parent = folder
		tween(part, 0.18, { Transparency = 1 })
		Debris:AddItem(part, 0.2)
		prev = p
	end
end

-- ------------------------------------------------------------------ anime layer
-- Slash crescents, spark streaks, dust, impact frames and focus lines.
local TAU = math.pi * 2
local function fxPart(color: Color3, mat: Enum.Material?, transp: number?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = mat or Enum.Material.Neon
	p.Color = color
	p.Transparency = transp or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- A crescent ribbon through `pts` (local to `base()`), lying in the plane with
-- `normal`. Thick in the middle, sharp at both ends; white core + coloured glow.
-- `base` is re-evaluated every frame (camera-glued slashes) or once (world).
function FX.ribbon(pts, normal: Vector3, width: number, color: Color3, life: number?, base: (() -> CFrame)?)
	getFolder()
	local dur = life or 0.2
	local n = #pts
	if n < 2 then
		return
	end
	local segs = {}
	local core = color:Lerp(Color3.new(1, 1, 1), 0.72)
	for i = 1, n - 1 do
		local a, b = pts[i], pts[i + 1]
		local d = b - a
		local len = d.Magnitude
		if len > 1e-3 then
			local t = (i - 0.5) / (n - 1)
			local w = width * (0.12 + 0.88 * math.sin(math.pi * (t ^ 0.8)) ^ 0.6)
			local tangent = d / len
			local side = tangent:Cross(normal)
			if side.Magnitude < 1e-3 then
				side = tangent:Cross(Vector3.yAxis)
			end
			side = side.Unit
			local up = side:Cross(tangent)
			local cf = CFrame.fromMatrix((a + b) / 2, side, up)
			for layer = 1, 2 do
				local glow = layer == 1
				local p = fxPart(if glow then color else core, Enum.Material.Neon, if glow then 0.45 else 0.08)
				p.Size = Vector3.new(w * (if glow then 1.7 else 1), 0.06, len + 0.08)
				p.Parent = folder
				table.insert(segs, { part = p, cf = cf * CFrame.new(0, if glow then -0.02 else 0, 0), w = p.Size.X })
			end
		end
	end
	local t0 = os.clock()
	local fixed = if base then nil else CFrame.new()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - t0) / dur
		if k >= 1 then
			conn:Disconnect()
			for _, s in segs do
				s.part:Destroy()
			end
			return
		end
		local b = fixed or (base :: any)()
		local fade = k ^ 1.6
		for idx, s in segs do
			local glow = idx % 2 == 1
			s.part.CFrame = b * s.cf
			s.part.Transparency = (if glow then 0.45 else 0.08) + (1 - (if glow then 0.45 else 0.08)) * fade
			s.part.Size = Vector3.new(s.w * (1 - fade * 0.7), 0.06, s.part.Size.Z)
		end
	end)
end

-- arc points on a circle in the plane spanned by u (theta=0) and v (theta=pi/2)
local function arcPoints(center: Vector3, u: Vector3, v: Vector3, r: number, a0: number, a1: number, n: number)
	local pts = {}
	for i = 0, n do
		local a = a0 + (a1 - a0) * i / n
		table.insert(pts, center + (u * math.cos(a) + v * math.sin(a)) * r)
	end
	return pts
end
FX.arcPoints = arcPoints

-- world-space slash for NPC / other players' attacks
function FX.slashWorld(origin: Vector3, dir: Vector3, anim: string?, range: number, scale: number, color: Color3?, heavy: boolean?)
	local fwd = Util.flatUnit(dir)
	if fwd.Magnitude < 0.5 then
		return
	end
	local right = fwd:Cross(Vector3.yAxis).Unit
	local up = Vector3.yAxis
	local col = color or (if heavy then rgb(255, 70, 60) else rgb(235, 240, 255))
	local r = math.max(range * 0.75, 3 * scale)
	local w = (if heavy then 1.6 else 1.1) * math.max(scale, 0.8)
	local c = origin + up * 0.4 * scale
	anim = anim or "SlashR"
	if anim == "Thrust" or anim == "Pounce" then
		FX.ribbon({ c + fwd * 1.5 * scale, c + fwd * (range * 0.55), c + fwd * range }, right, w * 0.7, col, 0.16)
	elseif anim == "Overhead" or anim == "Slam" then
		local tiltR = right * 0.18
		FX.ribbon(arcPoints(c + fwd * 0.5, (up + tiltR).Unit, fwd, r, -0.2, math.pi * 0.75, 12), right, w * 1.2, col, 0.22)
	elseif anim == "Sweep" then
		FX.ribbon(arcPoints(c - up * 2.2 * scale, right, fwd, r * 1.1, -0.3, math.pi + 0.3, 16), up, w * 1.3, col, 0.24)
	elseif anim == "ClawR" or anim == "ClawL" then
		local s = if anim == "ClawR" then 1 else -1
		for k = -1, 1 do
			local o = c + up * k * 0.7 * scale
			FX.ribbon(arcPoints(o, (right * s + up * 0.35).Unit, fwd, r * 0.8, 0.3, math.pi * 0.7, 7), (up - right * s * 0.35).Unit, w * 0.45, rgb(255, 230, 230), 0.14)
		end
	else
		local s = if anim == "SlashL" then -1 else 1
		local tilt = up * 0.28 * s
		FX.ribbon(arcPoints(c, (right * s + tilt).Unit, fwd, r, -0.15, math.pi + 0.15, 14), (up - right * s * 0.28).Unit, w, col, 0.2)
	end
end

-- thin glowing streaks flying out from a hit
function FX.sparks(pos: Vector3, dir: Vector3, color: Color3, count: number, speed: number?, len: number?)
	getFolder()
	local sp = speed or 40
	local d0 = if dir.Magnitude > 0.01 then dir.Unit else Vector3.yAxis
	for _ = 1, count do
		local v = (d0 + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 1), rng:NextNumber(-1, 1)) * 0.9).Unit
		local l = (len or 1.6) * rng:NextNumber(0.6, 1.4)
		local p = fxPart(color, Enum.Material.Neon, 0)
		p.Size = Vector3.new(0.09, 0.09, l)
		p.CFrame = CFrame.lookAt(pos, pos + v) * CFrame.new(0, 0, -l / 2)
		p.Parent = folder
		local travel = sp * rng:NextNumber(0.08, 0.16)
		tween(p, rng:NextNumber(0.12, 0.22), { CFrame = CFrame.lookAt(pos + v * travel, pos + v * (travel + 1)) * CFrame.new(0, 0, -l / 2), Size = Vector3.new(0.02, 0.02, l * 0.3), Transparency = 1 }, Enum.EasingStyle.Quad)
		Debris:AddItem(p, 0.25)
	end
end

-- a burst of soft dust / steam puffs (particle based: no physics cost)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
function FX.dust(pos: Vector3, count: number, color: Color3?, size: number?, speed: number?, up: number?)
	local a = attachAt(pos)
	local e = Instance.new("ParticleEmitter")
	-- square puffs (cubic dust) instead of round smoke
	e.Texture = "rbxasset://textures/SurfacesDefault.png"
	e.Color = ColorSequence.new(color or rgb(200, 190, 175))
	e.LightEmission = 0
	e.LightInfluence = 1
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.6, 1.3)
	e.Speed = NumberRange.new((speed or 10) * 0.4, speed or 10)
	e.SpreadAngle = Vector2.new(180, 20)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Acceleration = Vector3.new(0, up or 2, 0)
	e.Drag = 3
	local s = size or 3
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * 0.4), NumberSequenceKeypoint.new(1, s * 1.6) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = a
	e:Emit(count)
	Debris:AddItem(a, 1.6)
	-- plus a few real cubes that tumble out
	for _ = 1, math.min(math.floor(count / 3), 6) do
		local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.1, 0.8), rng:NextNumber(-1, 1)).Unit * (speed or 10) * rng:NextNumber(0.4, 1)
		cube(pos, (s * 0.12) * rng:NextNumber(0.6, 1.3), Palette.jitter(color or rgb(200, 190, 175), 0.1, rng:NextNumber()), v, rng:NextNumber(0.5, 1.1), { collide = false, transparency = 0.2 })
	end
end

-- anime impact frame: one white frame, one black frame
local impactCC: any = nil
function FX.impactFrame(strength: number?)
	if C.settings.impactFrames == false then
		return
	end
	if not impactCC or not impactCC.Parent then
		impactCC = Instance.new("ColorCorrectionEffect")
		impactCC.Name = "ImpactCC"
		impactCC.Enabled = false
		impactCC.Parent = game:GetService("Lighting")
	end
	local s = math.clamp(strength or 1, 0.3, 1.5)
	impactCC.Enabled = true
	impactCC.Saturation = -1
	impactCC.Brightness = 0.32 * s
	impactCC.Contrast = 1.5 * s
	impactCC.TintColor = Color3.new(1, 1, 1)
	task.delay(0.035, function()
		impactCC.Brightness = -0.28 * s
		impactCC.Contrast = 2.4 * s
		impactCC.TintColor = rgb(255, 228, 228)
		task.delay(0.045, function()
			impactCC.Enabled = false
		end)
	end)
end

-- radial focus lines (manga "speed lines" pointing at the centre of the screen)
local focusGui: any = nil
function FX.focusLines(t: number?, color: Color3?, count: number?)
	if not focusGui or not focusGui.Parent then
		focusGui = Instance.new("ScreenGui")
		focusGui.Name = "FocusLines"
		focusGui.IgnoreGuiInset = true
		focusGui.ResetOnSpawn = false
		focusGui.DisplayOrder = 3
		focusGui.Parent = player:WaitForChild("PlayerGui")
	end
	local dur = t or 0.35
	local vp = cam.ViewportSize
	local aspect = vp.X / math.max(vp.Y, 1)
	for _ = 1, count or 34 do
		local a = rng:NextNumber() * TAU
		local r0 = rng:NextNumber(0.4, 0.54)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BorderSizePixel = 0
		f.BackgroundColor3 = color or Color3.new(1, 1, 1)
		f.BackgroundTransparency = rng:NextNumber(0.1, 0.4)
		f.Size = UDim2.new(rng:NextNumber(0.18, 0.4), 0, 0, rng:NextInteger(2, 5))
		-- on an ellipse that fits the screen, each line pointing at the centre
		f.Rotation = math.deg(math.atan2(math.sin(a), math.cos(a) * aspect))
		f.Position = UDim2.fromScale(0.5 + math.cos(a) * r0, 0.5 + math.sin(a) * r0)
		f.Parent = focusGui
		tween(f, dur, { Position = UDim2.fromScale(0.5 + math.cos(a) * (r0 - 0.08), 0.5 + math.sin(a) * (r0 - 0.08)), BackgroundTransparency = 1, Size = UDim2.new(f.Size.X.Scale * 0.6, 0, 0, 1) })
		Debris:AddItem(f, dur + 0.05)
	end
end

-- dash-stab: a razor line through the victim along the dash, a white flash on the
-- body; the blood comes a beat later with the server's hit (anime "already cut")
function FX.dashCut(pos: Vector3, dir: Vector3, model: Instance?)
	getFolder()
	local d = if dir.Magnitude > 0.01 then dir.Unit else Vector3.new(0, 0, -1)
	local len = 22
	local line = fxPart(Color3.new(1, 1, 1), Enum.Material.Neon, 0)
	line.Size = Vector3.new(0.5, 0.5, 2)
	line.CFrame = CFrame.lookAt(pos, pos + d)
	line.Parent = folder
	tween(line, 0.07, { Size = Vector3.new(0.35, 0.35, len) }, Enum.EasingStyle.Quint)
	task.delay(0.07, function()
		tween(line, 0.28, { Size = Vector3.new(0.02, 0.02, len * 1.1), Transparency = 1 })
	end)
	Debris:AddItem(line, 0.4)
	local glow = fxPart(rgb(255, 60, 70), Enum.Material.Neon, 0.35)
	glow.Size = Vector3.new(1.2, 0.12, len * 0.8)
	glow.CFrame = CFrame.lookAt(pos, pos + d) * CFrame.Angles(0, 0, rng:NextNumber(-0.6, 0.6))
	glow.Parent = folder
	tween(glow, 0.35, { Size = Vector3.new(0.05, 0.05, len), Transparency = 1 })
	Debris:AddItem(glow, 0.4)
	FX.highlight(model, Color3.new(1, 1, 1), 0.18, 0.05)
	FX.sparks(pos, d, rgb(255, 255, 255), 10, 60, 2.4)
	-- cubic shards burst sideways out of the cut
	local side = d:Cross(Vector3.yAxis)
	if side.Magnitude < 0.1 then
		side = Vector3.xAxis
	end
	side = side.Unit
	for i = 1, 8 do
		local v = (side * (if i % 2 == 0 then 1 else -1) + Vector3.new(0, rng:NextNumber(0, 0.8), 0) + d * rng:NextNumber(-0.3, 0.6)).Unit * rng:NextNumber(18, 34)
		cube(pos, rng:NextNumber(0.15, 0.3), rgb(255, 250, 240), v, 0.35, { material = Enum.Material.Neon, collide = false })
	end
end

-- afterimages: translucent copies of the body left behind by a dash
function FX.afterimage(model: Instance?, t: number?)
	if not model or not model:IsA("Model") then
		return
	end
	getFolder()
	local dur = t or 0.35
	for _, name in { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
		local src = model:FindFirstChild(name)
		if src and src:IsA("BasePart") then
			local g = fxPart(rgb(150, 190, 255), Enum.Material.Neon, 0.55)
			g.Size = src.Size
			g.CFrame = src.CFrame
			g.Parent = folder
			tween(g, dur, { Transparency = 1, Size = src.Size * 0.9 })
			Debris:AddItem(g, dur + 0.05)
		end
	end
end

-- ground cracks: dark flat shards radiating from a heavy landing
function FX.cracks(pos: Vector3, radius: number)
	getFolder()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, cam, player.Character }
	local r = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0), params)
	if not r then
		return
	end
	for i = 1, 7 do
		local a = i / 7 * TAU + rng:NextNumber(-0.3, 0.3)
		local len = radius * rng:NextNumber(0.4, 0.9)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = fxPart(rgb(30, 26, 24), Enum.Material.Slate, 0.1)
		p.Size = Vector3.new(0.35, 0.08, len)
		p.CFrame = CFrame.lookAt(r.Position + dir * len / 2 + Vector3.new(0, 0.04, 0), r.Position + dir * len + Vector3.new(0, 0.04, 0))
		p.Parent = folder
		task.delay(2.5, function()
			tween(p, 1, { Transparency = 1 })
		end)
		Debris:AddItem(p, 3.6)
	end
end

-- windmill sails and other "Rotor" models spin on the client
local function spinRotors()
	local CS = game:GetService("CollectionService")
	local last = os.clock()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = now - last
		last = now
		if frozen or (C.timeStop and C.timeStop.active) then
			return
		end
		local camPos = cam.CFrame.Position
		for _, m in CS:GetTagged("Rotor") do
			if m:IsA("Model") and m.Parent then
				local pv = m.WorldPivot
				if (pv.Position - camPos).Magnitude < 700 then
					m:PivotTo(pv * CFrame.Angles(0, 0, (m:GetAttribute("Speed") or 0.5) * dt))
				end
			end
		end
	end)
end

-- ------------------------------------------------------------------ events
local handlers = {}

function handlers.Hit(d)
	local blood = Palette.blood[d.blood] or Palette.blood.red
	local dmg = d.dmg or 10
	local pos = d.pos
	if not pos then
		return
	end
	local isMe = d.target == player.Character
	if d.frozen then
		FX.blood(pos, d.dir or Vector3.yAxis, blood, math.clamp(math.floor(dmg / 5), 3, 10), 24, true)
		FX.frozenNumber(d.target, pos, dmg)
		FX.highlight(d.target, Color3.new(1, 1, 1), 0.08, 0.2)
		return
	end
	if d.released then
		clearFrozenNumber(d.target)
		FX.blood(pos, d.dir or Vector3.yAxis, blood, math.clamp(math.floor(dmg / 3), 8, 40), 40)
		FX.flash(pos, rgb(255, 255, 255), 6, 0.18)
		FX.sparks(pos, d.dir or Vector3.yAxis, rgb(255, 255, 255), 14, 70, 3)
		FX.sparks(pos, d.dir or Vector3.yAxis, blood, 10, 50, 2)
		FX.number(pos, dmg, { released = true, hits = d.hits })
		if (cam.CFrame.Position - pos).Magnitude < 60 then
			C.Controller.shake(math.clamp(dmg / 40, 1, 4), 0.3)
		end
	else
		local n = math.clamp(math.floor(dmg / 6), 2, 16) + (if d.heavy then 6 else 0)
		FX.blood(pos, d.dir or Vector3.yAxis, blood, n, if d.heavy then 36 else 24)
		-- anime hit: a white spark star + streaks of blood along the cut
		local dir = d.dir or Vector3.yAxis
		FX.sparks(pos, dir, rgb(255, 250, 235), if d.heavy or d.crit then 9 else 5, if d.heavy then 60 else 40, if d.heavy then 2.4 else 1.5)
		FX.sparks(pos, dir, blood, if d.heavy then 6 else 3, 30, 1.2)
		if d.crit or d.heavy then
			FX.flash(pos, rgb(255, 255, 255), if d.heavy then 5 else 3.5, 0.1)
		end
		if not isMe then
			FX.number(pos, dmg, { crit = d.crit })
		end
		if d.crit and not isMe and (cam.CFrame.Position - pos).Magnitude < 40 then
			FX.impactFrame(0.6)
		end
	end
	if d.element then
		FX.burst(pos, Palette.element[d.element] or Color3.new(1, 1, 1), 6, 14, 0.25, true, 0.5)
	end
	if not isMe then
		FX.highlight(d.target, Color3.new(1, 1, 1), 0.12, 0.3)
		if d.target and d.target:IsA("Model") then
			healthBar(d.target)
		end
		C.Audio.play("Flesh", { pos = pos, vol = 0.7 })
	end
end

function handlers.Parry(d)
	FX.burst(d.pos, rgb(255, 245, 190), 16, 30, 0.2, true, 0.35)
	FX.flash(d.pos, rgb(255, 250, 220), 6, 0.16)
	FX.sparks(d.pos, Vector3.yAxis, rgb(255, 235, 150), 18, 70, 2.2)
	if (cam.CFrame.Position - d.pos).Magnitude < 30 then
		FX.impactFrame(0.8)
		FX.focusLines(0.3)
	end
	C.Audio.play("Parry", { pos = d.pos, pitch = if d.npc then 0.9 else 1.2 })
	if d.npc then
		textPop(d.pos + Vector3.new(0, 1, 0), "PARRIED", rgb(255, 120, 120), 0.8)
	end
end

function handlers.Block(d)
	FX.burst(d.pos, rgb(220, 220, 230), 8, 16, 0.18, true, 0.3)
	C.Audio.play("Block", { pos = d.pos })
end

function handlers.Dodge(d)
	textPop(d.pos + Vector3.new(0, 3, 0), d.text or "DODGE", rgb(140, 230, 255), 0.8)
end

function handlers.Break(d)
	textPop(d.pos, "BREAK!", rgb(255, 230, 90), 1.3)
	FX.sparks(d.pos, Vector3.yAxis, rgb(255, 230, 120), 16, 60, 2.5)
	if (cam.CFrame.Position - d.pos).Magnitude < 40 then
		FX.focusLines(0.35, rgb(255, 240, 200))
	end
	FX.ring(d.pos - Vector3.new(0, 2, 0), 8, rgb(255, 230, 120), 0.4)
	C.Audio.play("Glass", { pos = d.pos, pitch = 1.3 })
end

function handlers.Death(d)
	local blood = Palette.blood[d.blood] or Palette.blood.red
	FX.blood(d.pos, Vector3.yAxis, blood, if d.boss then 60 else 18, if d.boss then 50 else 28)
	local sc = d.scale or 1
	if sc > 1.6 then
		-- big bodies hit the ground in a cloud of dust (giants steam away)
		FX.dust(d.pos - Vector3.new(0, 2 * sc, 0), math.floor(8 + sc * 4), rgb(190, 180, 165), 2 + sc, 8 + sc * 3, 1)
		if d.giant then
			FX.dust(d.pos, 26, rgb(245, 245, 245), 3 + sc, 6, 10)
		end
	end
	if d.boss then
		FX.flash(d.pos, rgb(255, 255, 255), 30, 0.6)
		FX.ring(d.pos - Vector3.new(0, 3, 0), 40, rgb(255, 255, 255), 0.9)
		C.Controller.shake(4, 0.8)
	end
end

function handlers.Fade(d)
	FX.fadeModel(d.target)
end

-- outline a monster through walls (objective stragglers)
function handlers.Reveal(d)
	local m = d.target
	if not m or not m.Parent then
		return
	end
	local h = Instance.new("Highlight")
	h.FillColor = rgb(255, 60, 60)
	h.OutlineColor = rgb(255, 230, 230)
	h.FillTransparency = 0.7
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = m
	Debris:AddItem(h, d.t or 8)
end

function handlers.Shout(d)
	FX.shout(d.target, d.text, d.dur)
end

function handlers.Telegraph(d)
	local col = if d.kind == "heavy" then rgb(255, 40, 40) elseif d.kind == "sweep" then rgb(255, 220, 40) else rgb(190, 80, 255)
	FX.highlight(d.target, col, math.max(d.t or 0.5, 0.3), 0.45)
	local m = d.target
	local r = m and m.PrimaryPart
	if r then
		local label = if d.kind == "heavy" then "!" elseif d.kind == "sweep" then "SLIDE" else "GRAB"
		textPop(r.Position + Vector3.new(0, 4.5 * m:GetScale(), 0), label, col, if d.kind == "heavy" then 1.2 else 0.8)
		if d.kind == "sweep" then
			FX.ring(r.Position - Vector3.new(0, 2.6 * m:GetScale(), 0), 10 * m:GetScale(), col, d.t or 0.6, 0.3)
		end
	end
	C.Audio.play("Magic", { pos = r and r.Position, pitch = if d.kind == "heavy" then 0.5 else 0.8 })
end

function handlers.Shockwave(d)
	FX.ring(d.pos, d.radius or 10, d.color or rgb(255, 200, 150), 0.5)
	FX.burst(d.pos + Vector3.new(0, 1, 0), rgb(150, 140, 130), 8, 26, 0.5, false, 1.2)
	FX.dust(d.pos + Vector3.new(0, 1, 0), 14, rgb(190, 180, 165), (d.radius or 10) * 0.35, (d.radius or 10) * 1.4, 1)
	if (d.radius or 10) >= 10 then
		FX.cracks(d.pos + Vector3.new(0, 1, 0), d.radius or 10)
	end
	if (cam.CFrame.Position - d.pos).Magnitude < (d.radius or 10) * 4 then
		C.Controller.shake(2, 0.3)
	end
	C.Audio.play("Explosion", { pos = d.pos, pitch = 0.6 })
end

function handlers.Teleport(d)
	local col = d.color or rgb(160, 120, 255)
	if d.from then
		FX.burst(d.from, col, 12, 20, 0.3, true, 0.5)
		FX.flash(d.from, col, 5, 0.2)
	end
	if d.to then
		FX.burst(d.to, col, 12, 20, 0.3, true, 0.5)
		FX.flash(d.to, col, 5, 0.2)
	end
	C.Audio.play("Teleport", { pos = d.to or d.from })
end

function handlers.LevelUp(d)
	for i = 0, 2 do
		task.delay(i * 0.18, function()
			FX.ring(d.pos - Vector3.new(0, 2.5 - i * 1.5, 0), 7, rgb(255, 220, 90), 0.6)
		end)
	end
	FX.burst(d.pos, rgb(255, 230, 120), 24, 20, 0.3, true, 1)
	C.Audio.play("LevelUp", { pos = d.pos })
end

function handlers.Gold(d)
	for _ = 1, math.clamp(math.floor(d.amount / 5), 3, 16) do
		local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(1, 2), rng:NextNumber(-1, 1)) * 10
		cube(d.pos, 0.35, rgb(255, 210, 60), v, 1.2, { material = Enum.Material.Metal })
	end
	textPop(d.pos + Vector3.new(0, 2, 0), "+" .. d.amount .. "g", rgb(255, 215, 80), 0.7)
end

function handlers.Pickup(d)
	FX.burst(d.pos + Vector3.new(0, 2, 0), d.color or rgb(255, 255, 255), 14, 14, 0.25, true, 0.7)
	C.Audio.play("Pickup", { pos = d.pos })
end

function handlers.Chest(d)
	FX.burst(d.pos + Vector3.new(0, 1.5, 0), d.color or rgb(255, 220, 120), 20, 18, 0.3, true, 0.9)
	FX.flash(d.pos + Vector3.new(0, 1.5, 0), d.color or rgb(255, 220, 120), 8, 0.4)
	C.Audio.play("Chest", { pos = d.pos })
end

function handlers.Heal(d)
	for _ = 1, 16 do
		local p = d.pos + Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(-2.5, 1), rng:NextNumber(-2, 2))
		cube(p, 0.3, rgb(120, 255, 140), Vector3.new(0, rng:NextNumber(6, 12), 0), 0.8, { material = Enum.Material.Neon, collide = false })
	end
end

function handlers.Zap(d)
	FX.zap(d.from, d.to, rgb(140, 210, 255))
end

function handlers.Splat(d)
	FX.blood(d.pos, Vector3.yAxis, d.color or rgb(100, 230, 100), 26, 30)
end

function handlers.Squish(d) end

-- another player's swing: a world-space crescent in front of them
function handlers.Swing(d)
	local m = d.model
	local r = m and m.PrimaryPart
	if not r then
		return
	end
	local look = r.CFrame.LookVector
	FX.slashWorld(r.Position + look * 1.5, look, if d.heavy then "Overhead" else (if math.random() < 0.5 then "SlashR" else "SlashL"), if d.heavy then 9 else 7, m:GetScale(), if d.heavy then rgb(255, 200, 120) else nil, d.heavy)
end

-- an NPC's melee strike
function handlers.Slash(d)
	if not d.pos or not d.dir then
		return
	end
	if (cam.CFrame.Position - d.pos).Magnitude > 220 then
		return
	end
	FX.slashWorld(d.pos, d.dir, d.anim, d.range or 7, d.scale or 1, d.color, d.heavy)
	if d.giant then
		FX.dust(d.pos - Vector3.new(0, 2 * (d.scale or 1), 0), 8, rgb(190, 180, 165), 4, 14, 1)
	end
end

function handlers.Upgrade(d)
	local col = Palette.rarity[d.rarity] or rgb(255, 220, 120)
	for i = 0, 2 do
		task.delay(i * 0.12, function()
			FX.ring(d.pos - Vector3.new(0, 2.4 - i, 0), 5 + i * 2, col, 0.5)
		end)
	end
	FX.sparks(d.pos, Vector3.yAxis, rgb(255, 200, 90), 22, 50, 1.6)
	FX.flash(d.pos, col, 6, 0.3)
	C.Audio.play("Chest", { pos = d.pos, pitch = 1.3 })
end

function handlers.Sound(d)
	C.Audio.play(d.name, { pos = d.pos, pitch = d.pitch, vol = d.vol })
end

function handlers.Dust(d)
	FX.dust(d.pos, d.count or 12, d.color, d.size, d.speed, d.up)
end

function handlers.Explosion(d)
	FX.flash(d.pos, d.color or rgb(255, 150, 60), (d.radius or 8) * 1.5, 0.3)
	FX.dust(d.pos, 12, rgb(90, 80, 72), (d.radius or 8) * 0.5, (d.radius or 8) * 1.6, 3)
	FX.sparks(d.pos, Vector3.yAxis, d.color or rgb(255, 170, 80), 14, 70, 2)
	FX.ring(d.pos, d.radius or 8, d.color or rgb(255, 150, 60), 0.4)
	FX.burst(d.pos, rgb(60, 55, 50), 16, 30, 0.5, false, 1.5)
	C.Audio.play("Explosion", { pos = d.pos })
	if (cam.CFrame.Position - d.pos).Magnitude < 60 then
		C.Controller.shake(2.5, 0.35)
	end
end

-- ------------------------------------------------------------------ spells
local FIRE_TEX = "rbxasset://textures/particles/fire_main.dds"
local SPARK_TEX = "rbxasset://textures/particles/sparkles_main.dds"
local function disc(pos: Vector3, r: number, color: Color3, transp: number, h: number?, mat: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = mat or Enum.Material.Neon
	part.Color = color
	part.Transparency = transp
	part.Size = Vector3.new(h or 0.08, r * 2, r * 2)
	part.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	part.Parent = folder
	return part
end

local function emitter(parent: Instance, props)
	local e = Instance.new("ParticleEmitter")
	e.Texture = props.tex or FIRE_TEX
	e.LightEmission = props.light or 1
	e.Color = props.color or ColorSequence.new(rgb(255, 200, 120), rgb(200, 30, 20))
	e.Size = props.size or NumberSequence.new(3, 0.5)
	e.Transparency = props.transp or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = props.life or NumberRange.new(0.4, 0.9)
	e.Speed = props.speed or NumberRange.new(10, 30)
	e.SpreadAngle = props.spread or Vector2.new(20, 20)
	e.Acceleration = props.acc or Vector3.new(0, 10, 0)
	e.Rate = 0
	e.RotSpeed = NumberRange.new(-120, 120)
	e.Rotation = NumberRange.new(0, 360)
	e.EmissionDirection = props.dir or Enum.NormalId.Top
	e.Parent = parent
	return e
end

-- a blood-fire rune drawn on the ground, spinning, before it erupts
function handlers.Rune(d)
	getFolder()
	local pos: Vector3, r: number, delay: number = d.pos, d.radius or 10, d.delay or 0.65
	local col = d.color or rgb(255, 60, 40)
	local base = pos + Vector3.new(0, 0.12, 0)
	local outer = disc(base, r, col, 0.35)
	local inner = disc(base + Vector3.new(0, 0.03, 0), r * 0.9, rgb(40, 6, 6), 0.25, 0.08, Enum.Material.SmoothPlastic)
	local ring2 = disc(base + Vector3.new(0, 0.06, 0), r * 0.62, col, 0.45)
	local core = disc(base + Vector3.new(0, 0.09, 0), r * 0.54, rgb(30, 4, 4), 0.2, 0.08, Enum.Material.SmoothPlastic)
	local glyphs = {}
	for i = 1, 14 do
		local g = Instance.new("Part")
		g.Anchored = true
		g.CanCollide = false
		g.CanQuery = false
		g.CanTouch = false
		g.CastShadow = false
		g.Material = Enum.Material.Neon
		g.Color = rgb(255, 150, 90)
		g.Size = Vector3.new(r * 0.08, 0.1, r * (if i % 2 == 0 then 0.18 else 0.1))
		g.Parent = folder
		table.insert(glyphs, g)
	end
	local light = Instance.new("PointLight")
	light.Color = col
	light.Range = r * 2.2
	light.Brightness = 0
	light.Parent = outer
	local orb = Instance.new("Part")
	orb.Shape = Enum.PartType.Ball
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.CanTouch = false
	orb.Material = Enum.Material.Neon
	orb.Color = rgb(255, 170, 90)
	orb.Size = Vector3.one * 0.5
	orb.CFrame = CFrame.new(base + Vector3.new(0, 1.2, 0))
	orb.Parent = folder
	local fire = emitter(orb, { size = NumberSequence.new(1.6, 0.3), speed = NumberRange.new(2, 6), life = NumberRange.new(0.3, 0.6) })
	fire.Rate = 40
	local t0 = os.clock()
	local conn
	local done = false
	conn = RunService.RenderStepped:Connect(function()
		if done then
			return
		end
		if not outer.Parent or not orb.Parent then
			done = true
			conn:Disconnect()
			return
		end
		local t = os.clock() - t0
		local k = math.clamp(t / delay, 0, 1)
		for i, g in glyphs do
			local a = (i / #glyphs) * math.pi * 2 + t * 2.2
			local rr = r * 0.76
			g.CFrame = CFrame.new(base + Vector3.new(math.cos(a) * rr, 0.14, math.sin(a) * rr)) * CFrame.Angles(0, -a, 0)
			g.Transparency = 0.2 + 0.3 * math.sin(t * 20 + i)
		end
		ring2.CFrame = CFrame.new(base + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, -t * 3, math.pi / 2)
		orb.Size = Vector3.one * (0.5 + k * r * 0.22)
		light.Brightness = 1 + k * 4
		if t > delay + 0.05 then
			done = true
			conn:Disconnect()
			for _, g in glyphs do
				g:Destroy()
			end
			fire.Enabled = false
			for _, pp in { outer, inner, ring2, core, orb } do
				tween(pp, 0.5, { Transparency = 1 })
				Debris:AddItem(pp, 0.55)
			end
		end
	end)
end

-- the rune's eruption: a pillar of fire that throws everyone into the air
function handlers.Eruption(d)
	getFolder()
	local pos: Vector3, r: number = d.pos, d.radius or 10
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(r * 1.4, 1, r * 1.4)
	anchor.CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0))
	anchor.Parent = folder
	local pillar = emitter(anchor, {
		size = NumberSequence.new({ NumberSequenceKeypoint.new(0, r * 0.55), NumberSequenceKeypoint.new(1, r * 0.15) }),
		speed = NumberRange.new(45, 90),
		life = NumberRange.new(0.45, 0.9),
		spread = Vector2.new(8, 8),
		acc = Vector3.new(0, 30, 0),
		color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(255, 240, 190)), ColorSequenceKeypoint.new(0.3, rgb(255, 120, 40)), ColorSequenceKeypoint.new(1, rgb(120, 10, 10)) }),
	})
	pillar:Emit(70)
	local embers = emitter(anchor, { tex = SPARK_TEX, size = NumberSequence.new(0.5, 0), speed = NumberRange.new(30, 80), life = NumberRange.new(0.8, 1.8), spread = Vector2.new(60, 60), acc = Vector3.new(0, -30, 0), color = ColorSequence.new(rgb(255, 200, 120), rgb(255, 60, 30)) })
	embers:Emit(60)
	local smoke = emitter(anchor, { tex = SMOKE, light = 0, size = NumberSequence.new(r * 0.5, r * 0.9), speed = NumberRange.new(6, 16), life = NumberRange.new(1, 2), spread = Vector2.new(70, 70), acc = Vector3.new(0, 6, 0), color = ColorSequence.new(rgb(60, 40, 36), rgb(20, 16, 16)), transp = NumberSequence.new(0.35, 1) })
	smoke:Emit(20)
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 120, 60)
	light.Range = r * 4
	light.Brightness = 8
	light.Parent = anchor
	tween(light, 0.8, { Brightness = 0 })
	Debris:AddItem(anchor, 2.5)
	FX.flash(pos + Vector3.new(0, 3, 0), rgb(255, 160, 80), r * 1.6, 0.3)
	FX.ring(pos + Vector3.new(0, 0.3, 0), r * 1.2, rgb(255, 90, 50), 0.45)
	FX.dust(pos, 14, rgb(90, 70, 60), r * 0.4, r * 2, 2)
	FX.cracks(pos, r * 0.8)
	C.Audio.play("Explosion", { pos = pos, pitch = 0.7 })
	C.Audio.play("Rune", { pos = pos, pitch = 0.8 })
	local dist = (cam.CFrame.Position - pos).Magnitude
	if dist < 80 then
		C.Controller.shake(math.clamp(3.2 - dist / 30, 0.6, 3.2), 0.4)
	end
end

-- chain lightning: bright forked bolts through every victim
function handlers.StormWeb(d)
	getFolder()
	local chain = d.chain or {}
	for i, link in chain do
		task.delay((i - 1) * 0.05, function()
			for _ = 1, 2 do
				FX.zap(link.from, link.to, if i % 2 == 0 then rgb(170, 230, 255) else rgb(90, 170, 255))
			end
			FX.sparks(link.to, Vector3.yAxis, rgb(170, 230, 255), 10, 40, 1.5)
			FX.flash(link.to, rgb(140, 210, 255), 6, 0.18)
			C.Audio.play("Lightning", { pos = link.to, pitch = 0.5 + i * 0.08 })
		end)
	end
	if #chain == 0 and d.origin then
		FX.flash(d.origin, rgb(140, 210, 255), 5, 0.2)
	end
end

function handlers.Debris(d)
	FX.burst(d.pos, d.color or rgb(140, 130, 120), d.count or 20, d.speed or 30, d.size or 0.8, false, 3)
end

function handlers.Flash(d)
	FX.flash(d.pos, d.color or Color3.new(1, 1, 1), d.size or 20, d.t or 0.4)
end

function handlers.Text(d)
	textPop(d.pos, d.text, d.color or Color3.new(1, 1, 1), d.size)
end

-- telegraphed ground circle that fills up, then disappears
function handlers.Circle(d)
	getFolder()
	local pos, r, t = d.pos, d.radius or 8, d.t or 1
	local col = d.color or rgb(255, 40, 40)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = col
	ring.Transparency = 0.55
	ring.Size = Vector3.new(0.2, r * 2, r * 2)
	ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = folder
	local fill = ring:Clone()
	fill.Transparency = 0.25
	fill.Size = Vector3.new(0.25, 0.5, 0.5)
	fill.Parent = folder
	tween(fill, t, { Size = Vector3.new(0.25, r * 2, r * 2) }, Enum.EasingStyle.Linear)
	Debris:AddItem(ring, t + 0.05)
	Debris:AddItem(fill, t + 0.05)
end

function handlers.Pillar(d)
	local col = d.color or rgb(255, 230, 140)
	local r = d.radius or 6
	getFolder()
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = col
	p.Size = Vector3.new(r * 1.6, 120, r * 1.6)
	p.CFrame = CFrame.new(d.pos + Vector3.new(0, 60, 0))
	p.Transparency = 0.1
	p.Parent = folder
	tween(p, 0.45, { Size = Vector3.new(0.3, 120, 0.3), Transparency = 1 })
	Debris:AddItem(p, 0.5)
	FX.ring(d.pos, r, col, 0.4)
	FX.burst(d.pos, col, 10, 24, 0.35, true, 0.6)
	C.Audio.play("Explosion", { pos = d.pos, pitch = 1.4, vol = 0.7 })
	if (cam.CFrame.Position - d.pos).Magnitude < 40 then
		C.Controller.shake(1.2, 0.2)
	end
end

function handlers.Bubble(d)
	getFolder()
	local s = Instance.new("Part")
	s.Shape = Enum.PartType.Ball
	s.Anchored = true
	s.CanCollide = false
	s.CanQuery = false
	s.CanTouch = false
	s.Material = Enum.Material.ForceField
	s.Color = d.color or rgb(190, 120, 255)
	s.Size = Vector3.one * (d.radius or 8) * 2
	s.CFrame = CFrame.new(d.pos + Vector3.new(0, 2, 0))
	s.Parent = folder
	tween(s, 0.8, { Size = Vector3.one * 0.5, Transparency = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	Debris:AddItem(s, 0.85)
	C.Audio.play("Magic", { pos = d.pos, pitch = 0.5 })
end

function handlers.Laser(d)
	getFolder()
	local col = d.color or rgb(255, 40, 60)
	local len = d.len or 80
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = col
	beam.Size = Vector3.new(1.6, 1.6, len)
	beam.Parent = folder
	local l = Instance.new("PointLight")
	l.Color = col
	l.Range = 30
	l.Brightness = 3
	l.Parent = beam
	local t0 = os.clock()
	local dur = d.dur or 1.5
	local t = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not C.timeStop.active then
			t += dt
		end
		local k = math.clamp(t / dur, 0, 1)
		local yaw = d.yaw0 + (d.yaw1 - d.yaw0) * k
		local dir = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
		local o = d.from + Vector3.new(0, d.height or 0, 0)
		beam.CFrame = CFrame.lookAt(o + dir * len / 2, o + dir * len) * CFrame.Angles(0, 0, t * 6)
		beam.Size = Vector3.new(1.6 + math.sin(t * 40) * 0.3, 1.6 + math.sin(t * 40) * 0.3, len)
		if k >= 1 then
			conn:Disconnect()
			tween(beam, 0.2, { Transparency = 1, Size = Vector3.new(0.1, 0.1, len) })
			Debris:AddItem(beam, 0.25)
		end
	end)
	C.Audio.play("Laser", { pos = d.from, pitch = 0.6, vol = 1 })
end

function handlers.Ringwave(d)
	getFolder()
	local col = d.color or rgb(255, 40, 60)
	local maxR = d.max or 80
	local speed = d.speed or 40
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = col
	ring.Transparency = 0.1
	ring.Parent = folder
	local r = 1
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not C.timeStop.active then
			r += speed * dt
		end
		ring.Size = Vector3.new(3, r * 2, r * 2)
		ring.CFrame = CFrame.new(d.pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Transparency = 0.1 + (r / maxR) * 0.6
		if r >= maxR then
			conn:Disconnect()
			ring:Destroy()
		end
	end)
	-- inner cut-out so only the edge is solid-looking: a dark inner disc
	C.Audio.play("Rumble", { pos = d.pos, pitch = 0.6 })
end

function handlers.Well(d)
	getFolder()
	local core = Instance.new("Part")
	core.Shape = Enum.PartType.Ball
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.Material = Enum.Material.Neon
	core.Color = rgb(0, 0, 0)
	core.Size = Vector3.one * 0.5
	core.CFrame = CFrame.new(d.pos + Vector3.new(0, 3, 0))
	core.Parent = folder
	local halo = core:Clone()
	halo.Material = Enum.Material.ForceField
	halo.Color = rgb(120, 40, 200)
	halo.Parent = folder
	tween(core, 0.6, { Size = Vector3.one * 7 }, Enum.EasingStyle.Back)
	tween(halo, 0.6, { Size = Vector3.one * 14 }, Enum.EasingStyle.Back)
	task.delay(d.dur or 5, function()
		tween(core, 0.4, { Size = Vector3.one * 0.2 })
		tween(halo, 0.4, { Size = Vector3.one * 0.2, Transparency = 1 })
		Debris:AddItem(core, 0.45)
		Debris:AddItem(halo, 0.45)
	end)
	task.spawn(function()
		local t = 0
		while t < (d.dur or 5) do
			local a = math.random() * math.pi * 2
			local p = d.pos + Vector3.new(math.cos(a) * 30, math.random(0, 8), math.sin(a) * 30)
			local c = cube(p, 0.4, rgb(90, 30, 160), (d.pos + Vector3.new(0, 3, 0) - p).Unit * 30, 1, { material = Enum.Material.Neon, collide = false })
			task.wait(0.05)
			t += 0.05
		end
	end)
end

function FX.init()
	getFolder()
	spinRotors()
	Net.on("FX", function(kind, d)
		local h = handlers[kind]
		if h and type(d) == "table" then
			local ok, err = pcall(h, d)
			if not ok then
				warn("[FX] " .. kind .. ": " .. tostring(err))
			end
		end
	end)
end

return FX
