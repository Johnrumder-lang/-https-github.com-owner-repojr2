--!nonstrict
-- Shared building helpers for the modern-city prologue (apartment, office,
-- streets, club). A builder `B` wraps a parent + RNG and jitters every colour a
-- little so no surface is perfectly flat. All helpers take axis-aligned boxes in
-- world space or boxes in a local frame (facades, furniture).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Kit = require(Shared.Kit)
local Palette = require(Shared.Palette)

local CityKit = {}
CityKit.__index = CityKit

local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB
local M = Enum.Material

CityKit.ROAD_Y = 0.2 -- asphalt top
CityKit.WALK_Y = 0.8 -- sidewalk top
CityKit.FLOOR_Y = 1.2 -- ground-floor interiors

-- materials (textured only)
CityKit.M = {
	brick = M.Brick,
	concrete = M.Concrete,
	plaster = M.Plaster,
	planks = M.WoodPlanks,
	wood = M.Wood,
	metal = M.Metal,
	glass = M.Glass,
	fabric = M.Fabric,
	carpet = M.Carpet,
	marble = M.Marble,
	granite = M.Granite,
	tiles = M.CeramicTiles,
	pavement = M.Pavement,
	asphalt = M.Asphalt,
	leather = M.Leather,
	plastic = M.Plastic,
	slate = M.Slate,
	limestone = M.Limestone,
	basalt = M.Basalt,
	diamond = M.DiamondPlate,
	rust = M.CorrodedMetal,
	neon = M.Neon,
	grass = M.Grass,
	ground = M.Ground,
	rubber = M.Rubber,
	foil = M.Foil,
	cardboard = M.Cardboard,
	leafy = M.LeafyGrass,
	pebble = M.Pebble,
	shingles = M.RoofShingles,
	cobble = M.Cobblestone,
}

function CityKit.new(parent: Instance, rng)
	local self = setmetatable({}, CityKit)
	self.parent = parent
	self.rng = rng
	self.jitterAmt = 0.05
	return self
end

-- Same RNG, different parent.
function CityKit:into(parent: Instance)
	local b = setmetatable({}, CityKit)
	b.parent = parent
	b.rng = self.rng
	b.jitterAmt = self.jitterAmt
	return b
end

function CityKit:model(name: string)
	return self:into(Kit.model(name, self.parent))
end

function CityKit:jit(c: Color3, a: number?): Color3
	return Palette.jitter(c, a or self.jitterAmt, self.rng:float())
end

local function tiny(size: Vector3): boolean
	return size.X * size.Y * size.Z < 0.6 or math.max(size.X, size.Y, size.Z) < 1.2
end

-- Walkable / colliding part.
function CityKit:solid(size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, props): Part
	return Kit.part(self.parent, size, cf, self:jit(color), mat or M.Plastic, props)
end

-- Cosmetic part: no collision, no queries; tiny parts cast no shadow.
function CityKit:deco(size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, props): Part
	local p = Kit.deco(self.parent, size, cf, self:jit(color), mat or M.Plastic, props)
	if tiny(size) then
		p.CastShadow = false
	end
	return p
end

-- Exact colour (no jitter): signs, lights, screens.
function CityKit:flat(size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, props): Part
	local p = Kit.deco(self.parent, size, cf, color, mat or M.Plastic, props)
	p.CastShadow = false
	return p
end

-- Cylinder along the CFrame's X axis.
function CityKit:cyl(length: number, d: number, cf: CFrame, color: Color3, mat: Enum.Material?, solid: boolean?): Part
	local p = if solid then self:solid(V(length, d, d), cf, color, mat) else self:deco(V(length, d, d), cf, color, mat)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Vertical cylinder standing on `base`.
function CityKit:post(height: number, d: number, base: Vector3, color: Color3, mat: Enum.Material?, solid: boolean?): Part
	return self:cyl(height, d, CF(base + V(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, mat, solid)
end

-- Horizontal disc (e.g. plate, manhole) centred at `pos`.
function CityKit:disc(d: number, thick: number, pos: Vector3, color: Color3, mat: Enum.Material?, solid: boolean?): Part
	return self:cyl(thick, d, CF(pos) * CFrame.Angles(0, 0, math.pi / 2), color, mat, solid)
end

function CityKit:ball(d: number, pos: Vector3, color: Color3, mat: Enum.Material?): Part
	local p = self:deco(V(d, d, d), CF(pos), color, mat)
	p.Shape = Enum.PartType.Ball
	return p
end

function CityKit:wedge(size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, solid: boolean?): WedgePart
	local p = Kit.wedge(self.parent, size, cf, self:jit(color), mat or M.Plastic)
	if not solid then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	return p
end

-- Axis-aligned box from bounds.
function CityKit:box(x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, color: Color3, mat: Enum.Material?, solid: boolean?): Part
	local size = V(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	local cf = CF((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	if solid then
		return self:solid(size, cf, color, mat)
	end
	return self:deco(size, cf, color, mat)
end

-- Box in a local frame F (bounds in F's axes).
function CityKit:lbox(F: CFrame, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, color: Color3, mat: Enum.Material?, solid: boolean?): Part
	local size = V(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	local cf = F * CF((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	if solid then
		return self:solid(size, cf, color, mat)
	end
	return self:deco(size, cf, color, mat)
end

-- Text on a part face (signs).
function CityKit:label(part: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?, bg: Color3?, ppi: number?): SurfaceGui
	local sg = Kit.label(part, face, text, color, font or Enum.Font.GothamBold, bg, ppi or 20)
	return sg
end

-- A display face with a TextLabel named "Time" (clocks, alarm clock).
function CityKit:clockFace(part: BasePart, text: string, color: Color3, bg: Color3, font: Enum.Font?): TextLabel
	local sg = Instance.new("SurfaceGui")
	sg.Name = "ClockFace"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 60
	sg.LightInfluence = 0
	sg.Brightness = 1.6
	local t = Instance.new("TextLabel")
	t.Name = "Time"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = bg
	t.BackgroundTransparency = 0
	t.BorderSizePixel = 0
	t.TextColor3 = color
	t.Font = font or Enum.Font.Code
	t.TextScaled = true
	t.Text = text
	t.Parent = sg
	sg.Parent = part
	return t
end

-- Spreadsheet / screen content (exported as coloured rects for the renderer).
function CityKit:screen(part: BasePart, kind: string, seed: number)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Screen"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(160, 100)
	sg.LightInfluence = 0
	sg.Brightness = 1.2
	local function rect(x, y, w, h, c)
		local f = Instance.new("Frame")
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(w, h)
		f.BackgroundColor3 = c
		f.BorderSizePixel = 0
		f.Parent = sg
		return f
	end
	if kind == "sheet" then
		rect(0, 0, 160, 100, rgb(232, 238, 236))
		rect(0, 0, 160, 9, rgb(33, 115, 70))
		rect(0, 9, 160, 6, rgb(210, 214, 216))
		for r = 0, 8 do
			for c = 0, 4 do
				local shade = if r == 0 then rgb(190, 214, 196) else rgb(252, 252, 252)
				if (r + c + seed) % 7 == 0 and r > 0 then
					shade = rgb(255, 242, 160)
				end
				rect(3 + c * 31, 18 + r * 9, 29, 7, shade)
			end
		end
		-- a little bar chart in the corner
		for i = 0, 3 do
			local h = 6 + ((seed * 7 + i * 13) % 14)
			rect(120 + i * 8, 96 - h, 6, h, rgb(60, 120, 200))
		end
	elseif kind == "mail" then
		rect(0, 0, 160, 100, rgb(240, 242, 246))
		rect(0, 0, 160, 10, rgb(40, 90, 170))
		rect(0, 10, 40, 90, rgb(220, 226, 236))
		for r = 0, 8 do
			rect(44, 14 + r * 9, 112, 7, if r % 3 == seed % 3 then rgb(210, 228, 250) else rgb(255, 255, 255))
		end
	elseif kind == "tv" then
		rect(0, 0, 160, 100, rgb(18, 24, 40))
	end
	sg.Parent = part
	return sg
end

-- Registers a light/neon part that switches with day/night.
-- dayColor/dayMat are used when off, nightColor/Neon when on.
function CityKit.nightPart(refs, part: BasePart, dayColor: Color3, nightColor: Color3, dayMat: Enum.Material?, dayTransparency: number?)
	part:SetAttribute("DayColor", dayColor)
	part:SetAttribute("NightColor", nightColor)
	part:SetAttribute("DayMat", (dayMat or M.Glass).Name)
	part:SetAttribute("DayT", dayTransparency or 0)
	part.Color = dayColor
	part.Material = dayMat or M.Glass
	part.Transparency = dayTransparency or 0
	table.insert(refs.neon, part)
	return part
end

-- Builds a wall slab along X or Z with rectangular holes.
-- axis = "x": wall runs along X from a0 to a1 at z in [t0, t1].
-- holes: { {a0, a1, y0, y1}, ... } in the running coordinate.
function CityKit:holedWall(axis: string, a0: number, a1: number, t0: number, t1: number, y0: number, y1: number, holes, color: Color3, mat: Enum.Material?, solid: boolean?)
	table.sort(holes, function(p, q)
		return p[1] < q[1]
	end)
	local parts = {}
	local function seg(b0, b1, c0, c1)
		if b1 - b0 < 0.01 or c1 - c0 < 0.01 then
			return
		end
		local p
		if axis == "x" then
			p = self:box(b0, b1, c0, c1, t0, t1, color, mat, solid)
		else
			p = self:box(t0, t1, c0, c1, b0, b1, color, mat, solid)
		end
		table.insert(parts, p)
	end
	local cur = a0
	for _, h in holes do
		seg(cur, h[1], y0, y1)
		seg(h[1], h[2], y0, h[3])
		seg(h[1], h[2], h[4], y1)
		cur = h[2]
	end
	seg(cur, a1, y0, y1)
	return parts
end

return CityKit
