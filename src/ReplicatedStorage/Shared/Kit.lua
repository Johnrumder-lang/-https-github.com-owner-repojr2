--!nonstrict
-- Part building helpers used by rigs, weapons and the world generators.
local Kit = {}

local SMOOTH = Enum.SurfaceType.Smooth
local PLASTIC = Enum.Material.SmoothPlastic

local function apply(p: BasePart, props)
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
end

function Kit.part(parent: Instance?, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = SMOOTH
	p.BottomSurface = SMOOTH
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or PLASTIC
	apply(p, props)
	p.Parent = parent
	return p
end

-- Decorative part: no collision, no queries, no touch events (cheap).
function Kit.deco(parent: Instance?, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = SMOOTH
	p.BottomSurface = SMOOTH
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or PLASTIC
	apply(p, props)
	p.Parent = parent
	return p
end

function Kit.wedge(parent: Instance?, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props): WedgePart
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.TopSurface = SMOOTH
	p.BottomSurface = SMOOTH
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or PLASTIC
	apply(p, props)
	p.Parent = parent
	return p
end

function Kit.ball(parent: Instance?, d: number, pos: Vector3, color: Color3, material: Enum.Material?, props): Part
	local p = Kit.part(nil, Vector3.new(d, d, d), CFrame.new(pos), color, material, props)
	p.Shape = Enum.PartType.Ball
	p.Parent = parent
	return p
end

-- Cylinder whose axis runs along the CFrame's X axis.
function Kit.cyl(parent: Instance?, length: number, d: number, cf: CFrame, color: Color3, material: Enum.Material?, props): Part
	local p = Kit.part(nil, Vector3.new(length, d, d), cf, color, material, props)
	p.Shape = Enum.PartType.Cylinder
	p.Parent = parent
	return p
end

-- Vertical cylinder standing on `base` (centre of bottom face).
function Kit.column(parent: Instance?, height: number, d: number, base: Vector3, color: Color3, material: Enum.Material?, props): Part
	return Kit.cyl(parent, height, d, CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, material, props)
end

function Kit.model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Kit.folder(name: string, parent: Instance?): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Kit.weld(a: BasePart, b: BasePart): WeldConstraint
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
	return w
end

-- Rigid weld that keeps the current offset between two parts.
function Kit.hardWeld(p0: BasePart, p1: BasePart): Weld
	local w = Instance.new("Weld")
	w.Part0 = p0
	w.Part1 = p1
	w.C0 = p0.CFrame:ToObjectSpace(p1.CFrame)
	w.C1 = CFrame.identity
	w.Parent = p0
	return w
end

function Kit.attach(part: BasePart, name: string, cf: CFrame?): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = cf or CFrame.identity
	a.Parent = part
	return a
end

function Kit.pointLight(part: BasePart, color: Color3, range: number, brightness: number?, shadows: boolean?): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1
	l.Shadows = shadows or false
	l.Parent = part
	return l
end

function Kit.spotLight(part: BasePart, color: Color3, range: number, brightness: number, angle: number, face: Enum.NormalId?): SpotLight
	local l = Instance.new("SpotLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Angle = angle
	l.Face = face or Enum.NormalId.Front
	l.Shadows = true
	l.Parent = part
	return l
end

function Kit.prompt(part: BasePart, action: string, object: string?, hold: number?, dist: number?): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object or ""
	pp.HoldDuration = hold or 0
	pp.MaxActivationDistance = dist or 9
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.Style = Enum.ProximityPromptStyle.Custom
	pp.Parent = part
	return pp
end

local function seq(a: number, b: number?)
	return NumberSequence.new(a, b or a)
end

function Kit.emitter(part: Instance, props): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.LightEmission = 0.4
	e.Rate = 10
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(1, 3)
	e.Size = seq(0.3, 0)
	for k, v in props or {} do
		(e :: any)[k] = v
	end
	e.Parent = part
	return e
end

-- Square "cubic" particles use this blank texture.
Kit.SQUARE = "rbxasset://textures/SurfacesDefault.png"
Kit.SPARK = "rbxasset://textures/particles/sparkles_main.dds"
Kit.SMOKE = "rbxasset://textures/particles/smoke_main.dds"
Kit.FIRE = "rbxasset://textures/particles/fire_main.dds"

function Kit.fire(part: BasePart, color: Color3?, scale: number?): ParticleEmitter
	local s = scale or 1
	local c = color or Color3.fromRGB(255, 140, 40)
	return Kit.emitter(part, {
		Texture = Kit.FIRE,
		Color = ColorSequence.new(c, Color3.fromRGB(255, 60, 20)),
		LightEmission = 1,
		Rate = 22,
		Lifetime = NumberRange.new(0.4, 0.9),
		Speed = NumberRange.new(2 * s, 5 * s),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * s), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		SpreadAngle = Vector2.new(14, 14),
		Acceleration = Vector3.new(0, 4 * s, 0),
		RotSpeed = NumberRange.new(-90, 90),
		Rotation = NumberRange.new(0, 360),
	})
end

function Kit.label(part: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?, bg: Color3?, pixelsPerStud: number?): SurfaceGui
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = pixelsPerStud or 30
	sg.LightInfluence = 0
	sg.Brightness = 1.4
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = if bg then 0 else 1
	t.BackgroundColor3 = bg or Color3.new()
	t.TextColor3 = color
	t.Font = font or Enum.Font.Arcade
	t.TextScaled = true
	t.Text = text
	t.Parent = sg
	sg.Parent = part
	return sg
end

-- Sets a batch of parts to ignore physics queries & touches (for cosmetic sets).
function Kit.cosmetic(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = false
			d.CanTouch = false
		end
	end
end

-- Moves every BasePart in `model` into a fresh folder so they can be removed together.
function Kit.clear(container: Instance?)
	if container then
		for _, c in container:GetChildren() do
			c:Destroy()
		end
	end
end

return Kit
