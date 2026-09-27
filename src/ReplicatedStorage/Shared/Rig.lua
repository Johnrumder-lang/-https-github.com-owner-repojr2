--!nonstrict
-- Cubic R6 rig builder. Builds every humanoid in the game: players, villagers,
-- knights, monsters, demons, skeletons, gods. Standard R6 part names + Motor6D
-- names so the ragdoll, the procedural animator, gear and the viewmodel work on
-- all of them.
--
-- No z-fighting: clothing either recolours the limb itself ("paint") or is a
-- shell that clears the surface below it by a fixed step. Shells sit on fixed
-- layers (studs out from the limb face): torso T1..T4, arms A1..A4, legs L1..L4.
-- Flat plates are HALF thick so they end between two layers. Arm layers are
-- offset from torso layers, so shells that overlap at the shoulders and hips
-- never share a plane. Base garments stay inside Gear armour (limb shells <= 1.08,
-- torso <= 2.14 x 1.14), and every outfit piece is registered by slot so gear of
-- that slot hides it (see hookGear). test/rigs_zfight.luau audits all rigs.
local CollectionService = game:GetService("CollectionService")
local Palette = require(script.Parent.Palette)

local Rig = {}

local HEAD = 1.25
local HH = HEAD / 2
local SMOOTH = Enum.SurfaceType.Smooth
local PLASTIC = Enum.Material.SmoothPlastic
local FAB = Enum.Material.Fabric
local LEA = Enum.Material.Leather
local MET = Enum.Material.Metal
local RUST = Enum.Material.CorrodedMetal
local MAIL = Enum.Material.DiamondPlate
local BONE = Enum.Material.Limestone
local SLATE = Enum.Material.Slate
local NEON = Enum.Material.Neon
local ICE = Enum.Material.Glacier
local WOOD = Enum.Material.Wood
local rgb = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles

local T1, T2, T3, T4 = 0.07, 0.13, 0.19, 0.25
local A1, A2, A3, A4 = 0.04, 0.1, 0.16, 0.22
local L1, L2, L3 = 0.04, 0.1, 0.16
local HALF = 0.03

Rig.JOINTS = {
	RootJoint = { "HumanoidRootPart", "Torso", CF(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CF(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
	Neck = { "Torso", "Head", CF(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CF(0, -HEAD / 2, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
	["Right Shoulder"] = { "Torso", "Right Arm", CF(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CF(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	["Left Shoulder"] = { "Torso", "Left Arm", CF(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CF(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
	["Right Hip"] = { "Torso", "Right Leg", CF(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CF(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	["Left Hip"] = { "Torso", "Left Leg", CF(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CF(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
}
Rig.JOINT_ORDER = { "RootJoint", "Neck", "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip" }
Rig.LIMBS = { "Head", "Torso", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
Rig.SLOTS = { "Head", "Chest", "Hands", "Legs", "Feet", "Cloak" }

-- ------------------------------------------------------------------ part helpers
-- While an outfit is built every new deco is registered under the current gear
-- slot, so armour of that slot can hide the clothes it covers.
local REG = nil
local SLOT = nil
local NAME = nil -- name override (hair parts are "Hair" so helmets hide them)
local function slot(s)
	local prev = SLOT
	SLOT = s
	return prev
end

local function limb(model: Model, name: string, size: Vector3, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = false
	p.TopSurface = SMOOTH
	p.BottomSurface = SMOOTH
	p.Size = size
	p.Color = color
	p.Material = mat or PLASTIC
	p.CanCollide = (name == "Torso" or name == "Head")
	p.Parent = model
	return p
end

local function add(parent: BasePart, size: Vector3, offset: CFrame, color: Color3, mat: Enum.Material?, props): Part
	local p = Instance.new("Part")
	p.Name = NAME or "Deco"
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = SMOOTH
	p.BottomSurface = SMOOTH
	p.Size = size
	p.CFrame = parent.CFrame * offset
	p.Color = color
	p.Material = mat or PLASTIC
	p.CastShadow = size.X + size.Y + size.Z > 0.9
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
	local w = Instance.new("WeldConstraint")
	w.Part0 = parent
	w.Part1 = p
	w.Parent = p
	p.Parent = parent
	if REG and SLOT then
		table.insert(REG[SLOT], p)
	end
	return p
end

local function addWedge(parent: BasePart, size: Vector3, offset: CFrame, color: Color3, mat: Enum.Material?): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = NAME or "Deco"
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Size = size
	p.CFrame = parent.CFrame * offset
	p.Color = color
	p.Material = mat or PLASTIC
	p.CastShadow = false
	local w = Instance.new("WeldConstraint")
	w.Part0 = parent
	w.Part1 = p
	w.Parent = p
	p.Parent = parent
	if REG and SLOT then
		table.insert(REG[SLOT], p)
	end
	return p
end
Rig.add = add
Rig.addWedge = addWedge

local function Kit_attach(part: BasePart, name: string, cf: CFrame): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = cf
	a.Parent = part
	return a
end

local function shade(c: Color3, f: number): Color3
	return Palette.shade(c, f)
end
local function mix(a: Color3, b: Color3, t: number): Color3
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

-- box by limb-local bounds
local function box(parent, x0, x1, y0, y1, z0, z1, c, m, props)
	if x0 > x1 then
		x0, x1 = x1, x0
	end
	return add(parent, V(x1 - x0, y1 - y0, z1 - z0), CF((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), c, m, props)
end
-- mirrored box: x given in "outward" coordinates (s = 1 right side, -1 left side)
local function sbox(parent, s, x0, x1, y0, y1, z0, z1, c, m, props)
	if s < 0 then
		x0, x1 = -x1, -x0
	end
	return box(parent, x0, x1, y0, y1, z0, z1, c, m, props)
end
-- shell around the torso / a limb between two heights, `o` out from every side face
local function band(t, y0, y1, o, c, m)
	return box(t, -1 - o, 1 + o, y0, y1, -0.5 - o, 0.5 + o, c, m)
end
local function lband(l, y0, y1, o, c, m)
	return box(l, -0.5 - o, 0.5 + o, y0, y1, -0.5 - o, 0.5 + o, c, m)
end
-- plate lying on layer o of the front (-Z) / back (+Z) face (torso and limbs are 1 deep)
local function front(t, x0, x1, y0, y1, o, c, m, th)
	return box(t, x0, x1, y0, y1, -0.5 - o - (th or HALF), -0.5 - o, c, m)
end
local function back(t, x0, x1, y0, y1, o, c, m, th)
	return box(t, x0, x1, y0, y1, 0.5 + o, 0.5 + o + (th or HALF), c, m)
end
-- a block from point a to point b (bones, claws, horns, straps); t across, t2 depth
local function seg(parent, a: Vector3, b: Vector3, t: number, c, m, t2: number?)
	local d = b - a
	local len = d.Magnitude
	if len < 1e-3 then
		return nil
	end
	local up = d / len
	local ref = if math.abs(up.Z) < 0.95 then V(0, 0, 1) else V(1, 0, 0)
	local right = up:Cross(ref).Unit
	return add(parent, V(t, len, t2 or t), CFrame.fromMatrix((a + b) / 2, right, up), c, m)
end
-- tapering chain of segments through points
local function chain(parent, pts, w0: number, w1: number, c, m, flat: number?)
	local n = #pts - 1
	for i = 1, n do
		local k = if n > 1 then (i - 1) / (n - 1) else 0
		local w = w0 + (w1 - w0) * k
		local a, b = pts[i], pts[i + 1]
		local dir = (b - a).Unit
		seg(parent, if i > 1 then a - dir * w * 0.35 else a, b, w, c, m, if flat then w * flat else nil)
	end
end
local function spike(parent, base: Vector3, dir: Vector3, len: number, w: number, c, m, n: number?)
	local k = n or 2
	local u = dir.Unit
	local pts = {}
	for i = 0, k do
		pts[i + 1] = base + u * (len * i / k)
	end
	chain(parent, pts, w, w * 0.4, c, m)
end
-- a bending chain (horns, tails): the direction turns by `bend` radians about `axis`
local function curve(parent, base: Vector3, dir: Vector3, axis: Vector3, bend: number, len: number, w0: number, w1: number, c, m, n: number)
	local pts = { base }
	local pos = base
	local dd = dir.Unit
	local rot = CFrame.fromAxisAngle(axis.Unit, bend / n)
	for _ = 1, n do
		pos += dd * (len / n)
		table.insert(pts, pos)
		dd = rot * dd
	end
	chain(parent, pts, w0, w1, c, m)
end

-- ------------------------------------------------------------------ pixel faces
-- 12x12 pixel faces drawn with a SurfaceGui on the head's front.
-- . = skin   b = brow   l = lash/eye outline   p = iris   h = eye highlight
-- w = eye white   m = mouth   t = teeth   n = nose shade   x = black
-- k = dark socket   r = blush   s = eyelid (skin shade)   g = glowing eye
-- d = contour shade (under-eye, cheek)   u = lip shade
local FACES = {
	neutral = { "............", "............", "............", "..bbb..bbb..", "..lll..lll..", "..wph..wph..", "..ppp..ppp..", "............", "......n.....", "............", ".....mm.....", "............" },
	calm = { "............", "............", "............", "..bbb..bbb..", "............", "..lll..lll..", "..pph..pph..", "............", "......n.....", "............", ".....mm.....", "............" },
	angry = { "............", "............", "..b......b..", "...bb..bb...", "..lll..lll..", "..wpp..ppw..", "...p....p...", "............", "......n.....", "............", "....mmmm....", "....u..u...." },
	happy = { "............", "............", "............", "..bbb..bbb..", "...l....l...", "..l.l..l.l..", "............", ".r........r.", "......n.....", "....m..m....", ".....mm.....", "............" },
	scared = { "............", "............", "..bbb..bbb..", "............", "..lll..lll..", "..wpw..wpw..", "..www..www..", "............", "......n.....", ".....mm.....", ".....mm.....", "............" },
	smug = { "............", "............", "............", "..bbb..bbb..", "............", "..sss..sss..", "..lll..lll..", "..pph..pph..", "......n.....", "............", ".......mm...", "......m....." },
	dead = { "............", "............", "............", "............", "..x.x..x.x..", "...x....x...", "..x.x..x.x..", "............", "......n.....", "............", "....mmmm....", "............" },
	sleep = { "............", "............", "............", "..bbb..bbb..", "............", "............", "..lll..lll..", "............", "......n.....", "............", ".....mm.....", "............" },
	monster = { "............", "............", "..b......b..", "...bb..bb...", "..ggg..ggg..", "..ggg..ggg..", "..kkk..kkk..", "............", "............", "..tmtmtmtm..", "..mmmmmmmm..", "............" },
	skull = { "............", "............", "............", "..kkk..kkk..", "..kgk..kgk..", "..kkk..kkk..", "............", ".....kk.....", "............", "...tttttt...", "...t.t.t.t..", "............" },
	hollow = { "............", "............", "............", "............", "..kkk..kkk..", "..kgk..kgk..", "..kkk..kkk..", "............", "............", "............", "............", "............" },
	god = { "............", "............", "............", "..bbb..bbb..", "..ggg..ggg..", "..ggg..ggg..", "............", "............", "......n.....", "............", "....m..m....", ".....mm....." },
	anchor = { "............", "............", "............", "..bbb..bbb..", "..lll..lll..", "..wph..wph..", "..ppp..ppp..", "............", "......n.....", "....mmmm....", "....tttt....", "............" },
	determined = { "............", "............", "..bb....bb..", "...bb..bb...", "..lll..lll..", "..wph..wph..", "..ppp..ppp..", "............", "......n.....", "............", "....mmm.....", "............" },
	sad = { "............", "............", "............", "...bb..bb...", "..b......b..", "..lll..lll..", "..wph..wph..", "..ppp..ppp..", "......n.....", "............", ".....mm.....", "....m..m...." },
	grim = { "............", "............", "............", "..bbb..bbb..", "..lll..lll..", "..wpp..ppw..", "..ddd..ddd..", "............", "......n.....", "............", "....mmmm....", "............" },
	-- the wandering giants: blank staring eyes and a grin far too wide
	titan = { "............", "............", "..bbb..bbb..", "............", "..www..www..", "..wpw..wpw..", "..www..www..", "......n.....", ".m........m.", ".mtttttttttm", "..mmmmmmmm..", "............" },
}
Rig.FACES = FACES
local FACE_N = 12
local FACE_PX = 10

function Rig.setFace(head: BasePart, mood: string, colors)
	for _, g in head:GetChildren() do
		if g:IsA("SurfaceGui") and (g.Name == "Face" or g.Name == "FaceGlow") then
			g:Destroy()
		end
	end
	colors = colors or {}
	local rows = FACES[mood] or FACES.neutral
	local skin = head.Color
	local map = {
		b = colors.brow or rgb(40, 30, 26),
		l = rgb(22, 18, 20),
		p = colors.eye or rgb(60, 44, 36),
		h = rgb(252, 252, 255),
		w = rgb(236, 234, 228),
		m = colors.mouth or shade(skin, 0.5),
		t = rgb(238, 232, 214),
		n = shade(skin, 0.82),
		x = rgb(10, 10, 12),
		k = rgb(18, 14, 18),
		r = mix(skin, rgb(230, 110, 120), 0.45),
		s = shade(skin, 0.78),
		d = shade(skin, 0.86),
		u = shade(skin, 0.72),
	}
	local canvas = Vector2.new(FACE_N * FACE_PX, FACE_N * FACE_PX)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Face"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = canvas
	sg.LightInfluence = 1
	local glow: SurfaceGui? = nil
	for y = 1, FACE_N do
		local row = rows[y] or ""
		local x = 1
		while x <= FACE_N do
			local ch = row:sub(x, x)
			if ch == "" or ch == "." then
				x += 1
			else
				-- merge horizontal runs of the same pixel into one frame
				local len = 1
				while x + len <= FACE_N and row:sub(x + len, x + len) == ch do
					len += 1
				end
				local f = Instance.new("Frame")
				f.BorderSizePixel = 0
				f.Size = UDim2.fromOffset(len * FACE_PX, FACE_PX)
				f.Position = UDim2.fromOffset((x - 1) * FACE_PX, (y - 1) * FACE_PX)
				if ch == "g" then
					if not glow then
						local g = Instance.new("SurfaceGui")
						g.Name = "FaceGlow"
						g.Face = Enum.NormalId.Front
						g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
						g.CanvasSize = canvas
						g.LightInfluence = 0
						g.Brightness = 3
						g.ZOffset = 1
						g.Parent = head
						glow = g
					end
					f.BackgroundColor3 = colors.glow or rgb(255, 40, 40)
					f.Parent = glow
				else
					f.BackgroundColor3 = map[ch] or map.m
					f.Parent = sg
				end
				x += len
			end
		end
	end
	sg.Parent = head
end

-- ------------------------------------------------------------------ hair
-- Hair shells: cap +0.06 (top +0.12), sides +0.09, back +0.16, fringe +0.12.
-- Head gear hides parts named "Hair", so hats are named "Hair" as well.
local function hairPart(p)
	p.Name = "Hair"
	return p
end
local function hbox(head, x0, x1, y0, y1, z0, z1, c, m)
	return hairPart(box(head, x0, x1, y0, y1, z0, z1, c, m))
end
local function hsbox(head, s, x0, x1, y0, y1, z0, z1, c, m)
	return hairPart(sbox(head, s, x0, x1, y0, y1, z0, z1, c, m))
end
local function hadd(head, size, cf, c, m)
	return hairPart(add(head, size, cf, c, m))
end

local function hoodParts(head: BasePart, c: Color3, deep: boolean?)
	local dk = shade(c, 0.6)
	hbox(head, -HH - 0.14, HH + 0.14, HH - 0.06, HH + 0.16, -HH - 0.14, HH + 0.14, c, FAB)
	for _, s in { 1, -1 } do
		hsbox(head, s, HH - 0.02, HH + 0.11, -HH - 0.2, HH - 0.02, if deep then -HH - 0.22 else -HH - 0.11, HH + 0.02, c, FAB)
	end
	hbox(head, -HH - 0.08, HH + 0.08, -HH - 0.28, HH - 0.02, HH - 0.04, HH + 0.2, shade(c, 0.9), FAB)
	hadd(head, V(0.55, 0.42, 0.55), CF(0, HH + 0.02, HH + 0.26) * ANG(-0.75, 0, 0) * ANG(0, math.pi / 4, 0), shade(c, 0.95), FAB)
	-- the shadowed rim of the opening
	hbox(head, -HH + 0.02, HH - 0.02, HH - 0.16, HH - 0.05, -HH - 0.11, -HH + 0.05, dk, FAB)
	if deep then
		for _, s in { 1, -1 } do
			hsbox(head, s, HH - 0.12, HH + 0.03, -HH - 0.24, -0.1, -HH - 0.2, -HH + 0.1, dk, FAB)
		end
	end
end

local function hood(head: BasePart, c: Color3, deep: boolean?)
	local prev = NAME
	NAME = "Hair"
	hoodParts(head, c, deep)
	NAME = prev
end

local function hairStyles(head: BasePart, style: string, c: Color3)
	if style == "bald" or style == "none" then
		return
	end
	if style == "hood" then
		hood(head, c)
		return
	end
	local dark = shade(c, 0.8)
	local lite = shade(c, 1.12)
	local function cap(o, top)
		hbox(head, -HH - o, HH + o, HH - 0.14, HH + (top or 0.12), -HH - o, HH + o + 0.02, c)
	end
	local function backP(low, zBack, cc)
		hbox(head, -HH - 0.03, HH + 0.03, low, HH - 0.1, HH - 0.2, HH + (zBack or 0.16), cc or dark)
	end
	local function sides(low, cc)
		for _, s in { 1, -1 } do
			hsbox(head, s, HH - 0.02, HH + 0.09, low, HH - 0.1, -HH + 0.1, HH - 0.15, cc or c)
		end
	end
	-- fringe: list of { x0, x1, bottom }
	local function fringe(pieces, cc)
		for _, f in pieces do
			hbox(head, f[1], f[2], f[3], HH + 0.1, -HH - 0.12, -HH + 0.02, cc or c)
		end
	end
	local function tuft(size, pos, rot, cc)
		hadd(head, size, CF(pos) * rot, cc or c)
	end
	if style == "buzz" then
		local b = shade(c, 0.9)
		hbox(head, -HH - 0.05, HH + 0.05, HH - 0.1, HH + 0.06, -HH - 0.05, HH + 0.05, b)
		hbox(head, -HH - 0.03, HH + 0.03, -0.05, HH - 0.06, HH - 0.2, HH + 0.1, shade(b, 0.9))
		sides(0.1, b)
		return
	end
	if style == "mohawk" then
		hbox(head, -HH - 0.03, HH + 0.03, 0.0, HH - 0.02, HH - 0.2, HH + 0.06, shade(c, 0.7))
		for i = 0, 4 do
			local z = -HH + 0.12 + i * 0.28
			local ht = ({ 0.28, 0.42, 0.5, 0.42, 0.3 })[i + 1]
			tuft(V(if i % 2 == 0 then 0.24 else 0.3, ht, 0.3), V(0, HH + ht / 2 - 0.02, z), ANG(-0.12 * (i - 2), 0, 0), if i % 2 == 0 then c else lite)
		end
		return
	end
	if style == "topknot" then
		hbox(head, -HH - 0.05, HH + 0.05, HH - 0.12, HH + 0.06, -HH - 0.05, HH + 0.07, dark)
		hbox(head, -HH - 0.03, HH + 0.03, -0.1, HH - 0.08, HH - 0.2, HH + 0.1, dark)
		tuft(V(0.42, 0.34, 0.42), V(0, HH + 0.2, 0.12), ANG(0, math.pi / 4, 0))
		tuft(V(0.46, 0.08, 0.46), V(0, HH + 0.1, 0.12), ANG(0, math.pi / 4, 0), rgb(70, 44, 30))
		tuft(V(0.28, 0.3, 0.3), V(0, HH + 0.46, 0.2), ANG(-0.4, 0.3, 0), lite)
		return
	end
	if style == "undercut" then
		hbox(head, -HH - 0.04, HH + 0.04, -0.05, HH - 0.1, -HH + 0.1, HH + 0.05, shade(c, 0.65))
		hbox(head, -HH + 0.05, HH - 0.05, HH - 0.14, HH + 0.24, -HH - 0.08, HH + 0.06, c)
		tuft(V(0.9, 0.2, 0.7), V(0.12, HH + 0.24, -0.25), ANG(0.18, 0.1, -0.22), lite)
		tuft(V(0.5, 0.28, 0.36), V(0.34, HH + 0.02, -HH - 0.06), ANG(0.35, 0, -0.35))
		return
	end
	if style == "slick" then
		cap(0.06, 0.1)
		backP(-0.3)
		sides(0.05)
		tuft(V(1.2, 0.16, 1.1), V(0, HH + 0.18, 0.06), ANG(-0.12, 0, 0), lite)
		tuft(V(1.0, 0.14, 0.4), V(0, HH + 0.18, -0.5), ANG(0.25, 0, 0))
		return
	end
	-- styles sharing the full cap
	local wild = style == "wild"
	cap(if wild then 0.08 else 0.06)
	if style == "short" then
		backP(-0.25)
		sides(0.0)
		fringe({ { -0.66, -0.18, 0.36 }, { -0.18, 0.28, 0.42 }, { 0.28, 0.66, 0.46 } })
		tuft(V(0.55, 0.16, 0.6), V(0.18, HH + 0.16, -0.12), ANG(0.12, 0.35, 0.12), lite)
	elseif style == "long" then
		backP(-HH - 0.85)
		hbox(head, -0.45, 0.45, -HH - 1.15, -HH - 0.8, HH - 0.16, HH + 0.1, shade(dark, 0.95))
		for _, s in { 1, -1 } do
			hsbox(head, s, HH - 0.02, HH + 0.09, -HH - 0.12, HH - 0.1, -HH + 0.1, HH - 0.15, c)
		end
		fringe({ { -0.66, -0.05, 0.36 }, { 0.05, 0.66, 0.36 } })
	elseif style == "messy" then
		backP(-0.3)
		sides(-0.05)
		fringe({ { -0.66, -0.25, 0.34 }, { -0.25, 0.1, 0.44 }, { 0.1, 0.66, 0.38 } })
		tuft(V(0.5, 0.26, 0.5), V(0.3, HH + 0.2, -0.2), ANG(0.3, 0.5, 0.35))
		tuft(V(0.45, 0.28, 0.45), V(-0.3, HH + 0.18, 0.2), ANG(-0.25, -0.4, -0.35), lite)
		tuft(V(0.4, 0.3, 0.4), V(0.05, HH + 0.2, 0.45), ANG(-0.5, 0.2, 0.1), dark)
		tuft(V(0.36, 0.3, 0.3), V(HH + 0.1, HH - 0.05, 0.1), ANG(0.1, 0, -0.6))
		tuft(V(0.36, 0.3, 0.3), V(-HH - 0.1, HH - 0.02, -0.15), ANG(-0.1, 0.2, 0.6), dark)
	elseif style == "bun" then
		backP(-0.2)
		sides(0.02)
		fringe({ { -0.66, -0.02, 0.44 }, { -0.02, 0.66, 0.4 } })
		tuft(V(0.52, 0.48, 0.48), V(0, HH + 0.12, HH + 0.24), ANG(0.5, 0, 0) * ANG(0, math.pi / 4, 0), dark)
		tuft(V(0.56, 0.1, 0.56), V(0, HH + 0.02, HH + 0.14), ANG(0.9, 0, 0) * ANG(0, math.pi / 4, 0), rgb(120, 40, 40))
	elseif style == "ponytail" then
		backP(-0.12)
		sides(0.02)
		fringe({ { -0.66, 0.05, 0.4 }, { 0.05, 0.66, 0.46 } })
		tuft(V(0.3, 0.14, 0.3), V(0, 0.2, HH + 0.22), ANG(0.3, 0, 0), rgb(70, 44, 30))
		chain(head, { V(0, 0.26, HH + 0.24), V(0, -0.25, HH + 0.36), V(0, -0.95, HH + 0.3), V(0, -1.35, HH + 0.2) }, 0.34, 0.2, dark)
	elseif style == "spiky" then
		backP(-0.2)
		sides(0.05)
		fringe({ { -0.66, -0.2, 0.4 }, { -0.2, 0.25, 0.34 }, { 0.25, 0.66, 0.42 } })
		local dirs = { V(0.2, 1, -0.5), V(-0.5, 1, -0.2), V(0.6, 1, 0.1), V(-0.3, 1, 0.6), V(0.35, 0.8, 0.8), V(0, 1, 0.1) }
		local bases = { V(0.15, HH + 0.05, -0.3), V(-0.35, HH + 0.05, -0.1), V(0.4, HH + 0.05, 0.1), V(-0.2, HH + 0.05, 0.35), V(0.2, HH, 0.45), V(0, HH + 0.08, 0.05) }
		for i = 1, 6 do
			spike(head, bases[i], dirs[i], 0.5, 0.3, if i % 2 == 0 then lite else c, PLASTIC, 2)
		end
	elseif style == "braids" then
		backP(-0.35)
		sides(-0.05)
		fringe({ { -0.66, -0.04, 0.42 }, { 0.04, 0.66, 0.42 } })
		for _, s in { 1, -1 } do
			for i = 0, 3 do
				tuft(V(0.22, 0.3, 0.22), V(s * (HH + 0.03), -0.2 - i * 0.28, -0.1 - i * 0.07), ANG(0.18, 0, if i % 2 == 0 then 0.2 else -0.2), if i % 2 == 0 then c else dark)
			end
			tuft(V(0.18, 0.12, 0.18), V(s * (HH + 0.03), -1.3, -0.35), ANG(0.2, 0.5, 0), rgb(150, 110, 60))
		end
	elseif wild then
		backP(-HH - 0.7, 0.2)
		for _, s in { 1, -1 } do
			hsbox(head, s, HH - 0.02, HH + 0.2, -HH - 0.35, HH - 0.1, -HH + 0.16, HH + 0.1, c)
			tuft(V(0.3, 0.6, 0.5), V(s * (HH + 0.2), -0.2, 0.3), ANG(0.2, 0, s * 0.3), dark)
		end
		fringe({ { -0.62, -0.2, 0.34 }, { -0.2, 0.2, 0.4 }, { 0.2, 0.62, 0.32 } })
		for i = -2, 2 do
			tuft(V(0.36, 0.4, 0.36), V(i * 0.26, HH + 0.22, -0.05 + (i % 2) * 0.3), ANG(0.3 * (if i % 2 == 0 then 1 else -1), 0.3 * i, -i * 0.22), if i % 2 == 0 then c else lite)
		end
	else
		backP(-0.25)
		sides(0.0)
		fringe({ { -0.66, 0.0, 0.4 }, { 0.0, 0.66, 0.44 } })
	end
end

local function hair(head: BasePart, style: string, c: Color3)
	local prev = NAME
	NAME = "Hair"
	hairStyles(head, style, c)
	NAME = prev
end

local function beard(head: BasePart, style: string, c: Color3, skin: Color3)
	local dk = shade(c, 0.88)
	local function jaw()
		for _, s in { 1, -1 } do
			sbox(head, s, HH - 0.02, HH + 0.07, -HH - 0.02, 0.05, -HH - 0.02, 0.15, c)
		end
		box(head, -0.55, 0.55, -HH - 0.28, -0.5, -HH - 0.1, 0.05, c)
	end
	local function stache(cc)
		box(head, -0.34, 0.34, -0.37, -0.29, -HH - 0.08, -HH + 0.04, cc or c)
		for _, s in { 1, -1 } do
			sbox(head, s, 0.26, 0.38, -0.5, -0.33, -HH - 0.08, -HH + 0.04, cc or c)
		end
	end
	if style == "full" then
		jaw()
		stache(dk)
	elseif style == "long" then
		jaw()
		stache(dk)
		box(head, -0.44, 0.44, -HH - 0.9, -HH - 0.22, -HH - 0.07, -HH + 0.2, shade(c, 0.95))
		box(head, -0.26, 0.26, -HH - 1.2, -HH - 0.85, -HH - 0.04, -HH + 0.17, dk)
	elseif style == "ancient" then
		jaw()
		stache(dk)
		box(head, -0.46, 0.46, -HH - 1.4, -HH - 0.22, -HH - 0.07, -HH + 0.2, shade(c, 0.96))
		box(head, -0.34, 0.34, -HH - 2.6, -HH - 1.35, -HH - 0.04, -HH + 0.17, shade(c, 0.9))
		box(head, -0.2, 0.2, -HH - 3.5, -HH - 2.55, -HH - 0.01, -HH + 0.14, shade(c, 0.84))
		box(head, -0.36, 0.36, -HH - 1.46, -HH - 1.34, -HH - 0.1, -HH + 0.23, Palette.metal.gold, MET)
	elseif style == "goatee" then
		stache(c)
		box(head, -0.18, 0.18, -HH - 0.24, -0.52, -HH - 0.1, -HH + 0.08, c)
	elseif style == "stubble" then
		local st = mix(skin, c, 0.45)
		for _, s in { 1, -1 } do
			sbox(head, s, HH - 0.01, HH + 0.05, -HH - 0.01, -0.15, -HH - 0.03, 0.08, st)
		end
		box(head, -0.52, 0.52, -HH - 0.02, -0.53, -HH - 0.05, -HH + 0.2, st)
		box(head, -0.3, 0.3, -0.37, -0.31, -HH - 0.05, -HH + 0.02, st)
	elseif style == "mustache" then
		stache(c)
	elseif style == "braided" then
		jaw()
		stache(dk)
		box(head, -0.2, 0.2, -HH - 0.95, -HH - 0.24, -HH - 0.07, -HH + 0.15, shade(c, 0.94))
		box(head, -0.24, 0.24, -HH - 0.72, -HH - 0.6, -HH - 0.1, -HH + 0.18, Palette.metal.gold, MET)
		box(head, -0.14, 0.14, -HH - 1.15, -HH - 0.9, -HH - 0.04, -HH + 0.12, dk)
	end
end

-- ------------------------------------------------------------------ garment kit
local function paint(p, part: BasePart, c: Color3, m: Enum.Material?)
	part.Color = c
	part.Material = m or FAB
	p.painted[part.Name] = true
end
local function bareLimb(p, part: BasePart)
	part.Color = p.skin
	part.Material = p.skinMat
	p.painted[part.Name] = nil
end

local function sleeves(p, c, m, bottom: number, cuff: Color3?, cuffH: number?, o: number?)
	local off = o or A1
	for _, a in p.arms do -- right arm first: the viewmodel samples its first sleeve
		lband(a.part, bottom, 1 + off, off, c, m)
	end
	if cuff then
		for _, a in p.arms do
			lband(a.part, bottom - 0.03, bottom + (cuffH or 0.14), off + 0.06, cuff, m)
		end
	end
end

local function gloves(p, c, top: number, m, o: number?)
	local prev = slot("Hands")
	for _, a in p.arms do
		lband(a.part, -1.04, top, o or A2, c, m or LEA)
	end
	slot(prev)
end

-- boots: shaft up to `top` (leg-local), a wider foot with a toe, a sole
local function boots(p, c: Color3, top: number, o)
	o = o or {}
	local prev = slot("Feet")
	local m = o.mat or LEA
	local sole = o.sole or shade(c, 0.5)
	for _, l in p.legs do
		local g = l.part
		if top > -0.6 then
			lband(g, -0.64, top, L2, c, m)
		end
		box(g, -0.63, 0.63, -0.95, -0.6, -0.5 - L2 - 0.18, 0.63, c, m)
		box(g, -0.66, 0.66, -1.04, -0.93, -0.5 - L2 - 0.24, 0.66, sole, o.soleMat or LEA)
		if o.cuff then
			lband(g, top - 0.16, top + 0.03, L3, o.cuff, o.cuffMat or m)
		end
		if o.strap then
			lband(g, -0.5, -0.4, L3, o.strap, LEA)
		end
		if o.toe then
			box(g, -0.52, 0.52, -0.9, -0.66, -0.5 - L2 - 0.21, -0.5 - L2 - 0.1, o.toe, MET)
		end
		if o.lace then
			front(g, -0.26, 0.26, -0.92, -0.62, L2 + 0.18, o.lace, FAB, 0.03)
		end
	end
	slot(prev)
end

local function belt(t, y0, y1, o, c, buckle: Color3?, m)
	band(t, y0, y1, o, c, m or LEA)
	if buckle then
		local cy = (y0 + y1) / 2
		local hy = (y1 - y0) / 2 + 0.04
		front(t, -0.17, 0.17, cy - hy, cy + hy, o, buckle, MET, 0.05)
		front(t, -0.08, 0.08, cy - hy + 0.06, cy + hy - 0.06, o + 0.05, shade(c, 0.8), m or LEA, 0.025)
	end
end

local function pouch(t, x: number, y: number, o: number, c: Color3)
	box(t, x - 0.19, x + 0.19, y - 0.24, y + 0.1, -0.5 - o - 0.22, -0.5 - o, c, LEA)
	box(t, x - 0.21, x + 0.21, y - 0.04, y + 0.13, -0.5 - o - 0.25, -0.5 - o, shade(c, 0.78), LEA)
end

-- ring of four bars around the neck (collars, gorgets, scarves, iron collars)
local function neckRing(t, y0: number, y1: number, r: number, th: number, c: Color3, m)
	box(t, -r - th, r + th, y0, y1, -r - th, -r, c, m)
	box(t, -r - th, r + th, y0, y1, r, r + th, c, m)
	for _, s in { 1, -1 } do
		sbox(t, s, r, r + th, y0, y1, -r, r, c, m)
	end
end

-- shoulder mantle: a shell over the shoulders whose top stays just above the torso
local function mantle(t, y0: number, o: number, c: Color3, m)
	return band(t, y0, 1.01, o, c, m)
end

-- cape / cloak hanging behind: three folds, a shoulder drape, clasps, trim or tatters
local function cape(p, c: Color3, len: number, o)
	o = o or {}
	local prev = slot("Cloak")
	local t = p.torso
	local z0 = o.z0 or (0.5 + T2)
	local bottom = 1 - len
	local panels = {
		{ -1.06, -0.32, bottom + 0.1, z0, z0 + 0.09 },
		{ -0.34, 0.34, bottom - 0.08, z0 + 0.03, z0 + 0.15 },
		{ 0.32, 1.06, bottom + 0.04, z0, z0 + 0.09 },
	}
	for i, pn in panels do
		box(t, pn[1], pn[2], pn[3], if i == 2 then 1.0 else 1.02, pn[4], pn[5], if i == 2 then shade(c, 0.9) else c, FAB)
		if o.tatter then
			local w = (pn[2] - pn[1]) / 3
			for k = 0, 2, 2 do
				local x = pn[1] + w * (k + 0.5)
				local ln = 0.18 + ((i * 3 + k) % 4) * 0.1
				add(t, V(w * 0.9, ln, pn[5] - pn[4] - 0.02), CF(x, pn[3] - ln / 2 + 0.04, (pn[4] + pn[5]) / 2) * ANG(0.06, 0, 0.05 * (k - 1)), shade(c, 0.85), FAB)
			end
		elseif o.trim then
			box(t, pn[1] - 0.02, pn[2] + 0.02, pn[3] - 0.03, pn[3] + 0.12, pn[4] - 0.03, pn[5] + 0.03, o.trim, if o.trimMat then o.trimMat else FAB)
		end
	end
	-- drape over the shoulders (kept off the arms)
	box(t, -0.88, 0.88, 0.9, 1.1, 0.2, z0 + 0.12, shade(c, 1.05), FAB)
	if o.clasp then
		for _, s in { 1, -1 } do
			sbox(t, s, 0.48, 0.66, 0.68, 0.84, -0.5 - T3 - 0.05, -0.5 - T3, o.clasp, MET)
		end
	end
	slot(prev)
end

-- robe: painted torso, a skirt shell on the hips, and per-leg lower panels that
-- move with the legs (so walking does not tear the silhouette)
local function robe(p, c: Color3, o)
	o = o or {}
	local t = p.torso
	paint(p, t, c, FAB)
	band(t, -1.75, -0.86, T3, c, FAB)
	local bottom = o.bottom or -0.9
	for _, l in p.legs do
		sbox(l.part, l.s, -0.52, 0.5 + T3, bottom, 0.3, -0.5 - T3, 0.5 + T3, c, FAB)
		if o.tatter then
			for k, z in { -0.5 - T3 - 0.015, 0.5 + T3 + 0.015 } do
				for j = 0, 1 do
					local x = -0.25 + j * 0.5
					local ln = 0.2 + ((k + j) % 3) * 0.12
					add(l.part, V(0.34, ln, 0.03), CF(l.s * x, bottom - ln / 2 + 0.05, z) * ANG(0, 0, 0.1 * (j - 0.5)), shade(c, 0.8), FAB)
				end
			end
		elseif o.hem then
			sbox(l.part, l.s, -0.54, 0.5 + T3 + 0.03, bottom - 0.03, bottom + 0.14, -0.5 - T3 - 0.03, 0.5 + T3 + 0.03, o.hem, FAB)
		end
	end
	if o.trim then
		front(t, -0.1, 0.1, -0.8, 0.98, 0, o.trim, o.trimMat or FAB, 0.05)
		front(t, -0.13, 0.13, -1.75, -0.86, T3, o.trim, o.trimMat or FAB)
		back(t, -0.13, 0.13, -1.75, -0.86, T3, o.trim, o.trimMat or FAB)
	end
end

local function bellSleeves(p, c: Color3, trim: Color3?)
	for _, a in p.arms do
		lband(a.part, -0.28, 1 + A2, A2, c, FAB)
	end
	for _, a in p.arms do
		lband(a.part, -0.74, -0.25, A4, shade(c, 0.94), FAB)
		if trim then
			lband(a.part, -0.78, -0.66, A4 + 0.03, trim, FAB)
		end
	end
end

local function tabard(t, c: Color3, top: number, bottom: number, w: number, o: number, trim: Color3?)
	front(t, -w, w, bottom, top, o, c, FAB)
	back(t, -w, w, bottom, top, o, c, FAB)
	if trim then
		front(t, -w - 0.02, w + 0.02, bottom - 0.04, bottom + 0.1, o + HALF, trim, FAB)
		back(t, -w - 0.02, w + 0.02, bottom - 0.04, bottom + 0.1, o + HALF, trim, FAB)
	end
end

local function strawHat(head: BasePart)
	local straw = rgb(214, 184, 110)
	hbox(head, -1.05, 1.05, HH + 0.02, HH + 0.09, -1.05, 1.05, straw, FAB)
	hbox(head, -0.72, 0.72, HH + 0.09, HH + 0.42, -0.72, 0.72, shade(straw, 0.96), FAB)
	hbox(head, -0.75, 0.75, HH + 0.1, HH + 0.2, -0.75, 0.75, rgb(130, 46, 38), FAB)
	hbox(head, -0.54, 0.54, HH + 0.42, HH + 0.48, -0.54, 0.54, shade(straw, 1.05), FAB)
end

local function helmetKettle(p, c: Color3, m)
	local head = p.head
	local prev = slot("Head")
	hbox(head, -0.74, 0.74, HH - 0.05, HH + 0.36, -0.74, 0.74, c, m or MET)
	hbox(head, -0.98, 0.98, HH - 0.07, HH + 0.02, -0.98, 0.98, shade(c, 0.9), m or MET)
	hbox(head, -0.77, 0.77, HH + 0.1, HH + 0.18, -0.77, 0.77, shade(c, 0.75), m or MET)
	hbox(head, -0.12, 0.12, HH + 0.36, HH + 0.46, -0.12, 0.12, shade(c, 0.8), m or MET)
	slot(prev)
end

-- closed great helm; covers the whole head (hair and face stay inside)
local function greatHelm(p, c: Color3, d)
	local head = p.head
	local prev = slot("Head")
	local m = d.armorMat or MET
	local o = 0.1
	local slitC = d.visorGlow or rgb(14, 12, 14)
	hbox(head, -HH - o, HH + o, -HH - 0.08, HH + o, -HH - o, HH + o, c, m)
	hbox(head, -0.52, 0.52, 0.06, 0.2, -HH - o - 0.03, -HH - o + 0.02, slitC, if d.visorGlow then NEON else PLASTIC)
	hbox(head, -0.62, 0.62, 0.2, 0.56, -HH - o - 0.06, -HH - o + 0.02, shade(c, 1.06), m)
	hbox(head, -0.62, 0.62, -0.62, 0.06, -HH - o - 0.06, -HH - o + 0.02, shade(c, 0.94), m)
	hbox(head, -0.05, 0.05, -0.62, 0.06, -HH - o - 0.1, -HH - o - 0.06, shade(c, 1.1), m)
	for i = 0, 2 do
		hbox(head, 0.2, 0.3, -0.35 + i * 0.12, -0.29 + i * 0.12, -HH - o - 0.08, -HH - o - 0.06, rgb(14, 12, 14))
	end
	hbox(head, -0.08, 0.08, HH + o, HH + o + 0.12, -0.55, 0.62, shade(c, 0.82), m)
	if d.plume ~= false then
		local pc = d.plume or d.accent or rgb(140, 30, 36)
		for i, pt in { { 0.2, 0.3, -0.25 }, { 0.36, 0.34, 0.1 }, { 0.3, 0.3, 0.45 } } do
			hadd(head, V(({ 0.22, 0.28, 0.1 })[i], pt[2], pt[1] + 0.3), CF(0, HH + o + 0.12 + pt[2] / 2 - i * 0.04, pt[3]) * ANG(-0.25 * i, 0, 0), shade(pc, 1 - i * 0.08), FAB)
		end
	end
	if d.spiked then
		local pn = NAME
		NAME = "Hair"
		for _, s in { 1, -1 } do
			spike(head, V(s * (HH + 0.05), HH - 0.05, 0), V(s, 0.5, 0.1), 0.45, 0.18, shade(c, 0.8), m, 2)
		end
		NAME = pn
	end
	slot(prev)
end

-- open-faced helm (skull knights, soldiers): skull cap, cheek guards, nasal
local function openHelm(p, c: Color3, m)
	local head = p.head
	local prev = slot("Head")
	hbox(head, -HH - 0.09, HH + 0.09, 0.25, HH + 0.1, -HH - 0.09, HH + 0.09, c, m)
	hbox(head, -0.1, 0.1, -0.12, 0.3, -HH - 0.13, -HH - 0.08, shade(c, 0.9), m)
	for _, s in { 1, -1 } do
		hsbox(head, s, HH - 0.02, HH + 0.07, -0.55, 0.3, -HH - 0.07, 0.25, shade(c, 0.85), m)
	end
	hbox(head, -HH - 0.12, HH + 0.12, 0.22, 0.34, -HH - 0.12, HH + 0.12, shade(c, 0.7), m)
	hbox(head, -0.07, 0.07, HH + 0.1, HH + 0.2, -0.5, 0.55, shade(c, 0.8), m)
	slot(prev)
end

local function crown(p, gold: Color3, gem: Color3)
	local head = p.head
	local prev = slot("Head")
	hbox(head, -0.77, 0.77, HH - 0.06, HH + 0.14, -0.77, 0.77, gold, MET)
	for _, pt in { { 0, -1 }, { 0.5, -1 }, { -0.5, -1 }, { 0, 1 }, { 0.5, 1 }, { -0.5, 1 } } do
		hbox(head, pt[1] - 0.09, pt[1] + 0.09, HH + 0.14, HH + 0.42, pt[2] * 0.77 - 0.08, pt[2] * 0.77 + 0.08, gold, MET)
	end
	for _, s in { 1, -1 } do
		hbox(head, s * 0.77 - 0.08, s * 0.77 + 0.08, HH + 0.14, HH + 0.36, -0.09, 0.09, gold, MET)
	end
	hbox(head, -0.1, 0.1, HH - 0.02, HH + 0.12, -0.81, -0.77, gem, NEON)
	for _, s in { 1, -1 } do
		hbox(head, s * 0.42 - 0.06, s * 0.42 + 0.06, HH + 0.0, HH + 0.1, -0.8, -0.77, rgb(60, 120, 220), NEON)
	end
	slot(prev)
end

local function halo(head: BasePart, c: Color3, r: number)
	local n = 12
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		local p = add(head, V(0.28, 0.28, 0.28), CF(0, HH + 0.55, 0.45) * CF(math.cos(a) * r, 0, math.sin(a) * r) * ANG(0, -a, 0), c, NEON)
		p.CastShadow = false
	end
end

-- ------------------------------------------------------------------ outfits
local OUT = {}
local WHITE = rgb(236, 234, 228)

function OUT.casual(p, d)
	local tee = d.shirt
	paint(p, p.torso, tee, FAB)
	for _, a in p.arms do
		lband(a.part, 0.18, 1 + A1, A1, tee, FAB)
	end
	for _, a in p.arms do
		lband(a.part, 0.15, 0.28, A2, shade(tee, 0.88), FAB)
	end
	front(p.torso, -0.34, 0.34, 0.84, 0.98, 0, shade(tee, 0.75), FAB, 0.05)
	paint(p, p.rl, d.pants, FAB)
	paint(p, p.ll, d.pants, FAB)
	belt(p.torso, -1.03, -0.86, T1, rgb(40, 32, 28), rgb(170, 170, 176))
	for _, l in p.legs do
		sbox(l.part, l.s, 0.1, 0.4, 0.55, 0.85, -0.5 - L1, -0.5, shade(d.pants, 0.85), FAB)
	end
	boots(p, d.shoes, -0.62, { sole = rgb(236, 236, 236), mat = FAB, soleMat = PLASTIC, lace = rgb(236, 236, 236) })
end

local function openCoat(p, c: Color3, m, bottom: number, gap: number, lapel: Color3?)
	local t = p.torso
	box(t, -1 - T1, -gap, bottom, 1 + T1, -0.5 - T1, 0.5 + T1, c, m)
	box(t, gap, 1 + T1, bottom, 1 + T1, -0.5 - T1, 0.5 + T1, c, m)
	box(t, -gap, gap, bottom, 1 + T1, 0.2, 0.5 + T1, c, m)
	if lapel then
		for _, s in { 1, -1 } do
			add(t, V(0.3, 0.62, 0.04), CF(s * (gap + 0.14), 0.68, -0.5 - T1 - 0.02) * ANG(0, 0, s * 0.32), lapel, m)
		end
	end
end

function OUT.jacket(p, d)
	local j = d.jacket or rgb(30, 30, 36)
	paint(p, p.torso, d.shirt, FAB)
	sleeves(p, j, LEA, -0.45, shade(j, 0.7), 0.16)
	openCoat(p, j, LEA, -1.12, 0.24, shade(j, 1.25))
	for _, s in { 1, -1 } do
		front(p.torso, s * 0.45 - 0.2, s * 0.45 + 0.2, -0.85, -0.5, T1, shade(j, 0.8), LEA)
	end
	front(p.torso, -0.3, 0.3, 0.8, 0.98, 0, shade(d.shirt, 0.75), FAB, 0.05)
	paint(p, p.rl, d.pants, FAB)
	paint(p, p.ll, d.pants, FAB)
	boots(p, d.shoes, -0.62, { sole = rgb(236, 236, 236), mat = FAB, soleMat = PLASTIC, lace = shade(d.shoes, 1.3) })
end

function OUT.office(p, d)
	local shirt = d.shirt
	local tie = d.accent or rgb(170, 30, 40)
	paint(p, p.torso, shirt, FAB)
	if d.blazer then
		for _, a in p.arms do
			lband(a.part, -0.38, 1 + A2, A2, d.blazer, FAB)
		end
		for _, a in p.arms do
			lband(a.part, -0.52, -0.36, A1, shirt, FAB)
		end
	else
		sleeves(p, shirt, FAB, -0.5, shade(shirt, 0.92), 0.14)
	end
	front(p.torso, -0.1, 0.1, -0.45, 0.82, 0, tie, FAB, 0.05)
	front(p.torso, -0.14, 0.14, 0.76, 0.96, 0, shade(tie, 0.85), FAB, 0.08)
	for _, s in { 1, -1 } do
		add(p.torso, V(0.3, 0.16, 0.03), CF(s * 0.24, 0.9, -0.515) * ANG(0, 0, s * 0.55), shade(shirt, 0.9), FAB)
	end
	if d.blazer then
		local b = d.blazer
		openCoat(p, b, FAB, -1.22, 0.3, shade(b, 1.25))
		for i = 0, 1 do
			front(p.torso, 0.32, 0.42, -0.55 - i * 0.3, -0.45 - i * 0.3, T1, rgb(30, 30, 30), PLASTIC)
		end
		front(p.torso, -0.85, -0.5, 0.35, 0.45, T1, WHITE, FAB)
	end
	paint(p, p.rl, d.pants, FAB)
	paint(p, p.ll, d.pants, FAB)
	belt(p.torso, -0.98, -0.84, 0.04, rgb(30, 26, 24), rgb(200, 190, 150))
	boots(p, rgb(24, 22, 22), -0.62, { sole = rgb(14, 12, 12) })
end

function OUT.suit(p, d)
	d.blazer = d.blazer or rgb(30, 32, 40)
	OUT.office(p, d)
end

function OUT.bouncer(p, d)
	d.shirt = rgb(20, 20, 22)
	OUT.casual(p, d)
	local head = p.head
	box(head, -0.52, 0.52, -0.02, 0.2, -HH - 0.07, -HH - 0.02, rgb(10, 10, 12), PLASTIC)
	for _, s in { 1, -1 } do
		sbox(head, s, 0.08, 0.46, 0.0, 0.18, -HH - 0.09, -HH - 0.07, rgb(40, 44, 60), PLASTIC, { Reflectance = 0.3 })
	end
end

function OUT.peasant(p, d)
	local s = d.shirt
	local t = p.torso
	paint(p, t, s, FAB)
	band(t, -1.42, -0.82, T1, shade(s, 0.95), FAB)
	sleeves(p, shade(s, 1.05), FAB, -0.3, shade(s, 0.88), 0.18)
	front(t, -0.08, 0.08, 0.3, 0.98, 0, shade(s, 0.55), FAB, 0.05)
	for i = 0, 1 do
		for _, sg in { 1, -1 } do
			add(t, V(0.3, 0.05, 0.03), CF(0, 0.48 + i * 0.24, -0.565) * ANG(0, 0, sg * 0.45), rgb(200, 180, 140), FAB)
		end
	end
	belt(t, -0.92, -0.72, T2, rgb(84, 58, 38), if d.apron then nil else rgb(150, 130, 90))
	pouch(t, -0.72, -0.88, T2, rgb(110, 80, 50))
	paint(p, p.rl, d.pants, FAB)
	paint(p, p.ll, d.pants, FAB)
	local prev = slot("Legs")
	for _, l in p.legs do
		lband(l.part, -0.66, -0.12, L1, rgb(196, 184, 160), FAB)
		for i = 0, 1 do
			add(l.part, V(1.2, 0.06, 1.2), CF(0, -0.5 + i * 0.26, 0) * ANG(0, 0, if i == 0 then 0.22 else -0.22), rgb(96, 70, 46), LEA)
		end
	end
	slot(prev)
	boots(p, rgb(74, 52, 34), -0.62)
	if d.apron then
		front(t, -0.5, 0.5, -1.75, 0.5, T2, d.apron, FAB)
		for _, sg in { 1, -1 } do
			front(t, sg * 0.43 - 0.05, sg * 0.43 + 0.05, 0.5, 1.0, T2, shade(d.apron, 0.9), FAB)
		end
	end
	if d.strawHat then
		strawHat(p.head)
	end
end

function OUT.farmer(p, d)
	local shirt = d.shirt
	local t = p.torso
	paint(p, t, shirt, FAB)
	sleeves(p, shirt, FAB, 0.1, shade(shirt, 0.88), 0.18)
	local strap = rgb(80, 60, 40)
	for _, s in { 1, -1 } do
		front(t, s * 0.45 - 0.09, s * 0.45 + 0.09, -1.0, 0.98, 0, strap, LEA, 0.05)
		front(t, s * 0.45 - 0.1, s * 0.45 + 0.1, 0.4, 0.55, 0.05, rgb(170, 150, 90), MET, 0.03)
	end
	add(t, V(0.18, 2.3, 0.05), CF(0, 0, 0.525) * ANG(0, 0, 0.42), strap, LEA)
	add(t, V(0.18, 2.3, 0.05), CF(0, 0, 0.525) * ANG(0, 0, -0.42), strap, LEA)
	front(t, -0.2, 0.2, 0.92, 0.99, 0, shade(shirt, 0.75), FAB, 0.05)
	paint(p, p.rl, d.pants, FAB)
	paint(p, p.ll, d.pants, FAB)
	band(t, -1.06, -0.9, T1, d.pants, FAB)
	front(p.rl, -0.28, 0.3, -0.25, 0.2, 0, shade(d.pants, 1.25), FAB, 0.05)
	back(p.ll, -0.2, 0.28, 0.2, 0.6, 0, shade(d.pants, 0.8), FAB, 0.05)
	boots(p, rgb(70, 48, 32), -0.3, { cuff = rgb(60, 40, 28) })
	if d.strawHat ~= false then
		strawHat(p.head)
	end
end

function OUT.merchant(p, d)
	local s = d.shirt
	local coat = d.accent or rgb(100, 60, 120)
	local gold = Palette.metal.gold
	paint(p, p.torso, s, FAB)
	sleeves(p, coat, FAB, -0.42, shade(coat, 0.75), 0.18)
	openCoat(p, coat, FAB, -1.62, 0.28)
	for _, sg in { 1, -1 } do
		front(p.torso, sg * 0.28, sg * 0.28 + sg * 0.12, -1.62, 1.0, T1, gold, FAB)
	end
	belt(p.torso, -0.9, -0.66, T2, shade(coat, 0.6), gold, FAB)
	front(p.torso, -0.95, -0.72, -1.3, -0.95, T2, shade(coat, 0.6), FAB)
	pouch(p.torso, 0.62, -0.84, T2, rgb(130, 96, 60))
	front(p.torso, 0.56, 0.68, -1.1, -1.04, T2 + 0.22, gold, MET, 0.04)
	paint(p, p.rl, d.pants, FAB)
	paint(p, p.ll, d.pants, FAB)
	boots(p, rgb(60, 40, 28), -0.25, { cuff = rgb(90, 60, 40) })
	local head = p.head
	local prev = slot("Head")
	local hat = rgb(60, 40, 30)
	hbox(head, -0.95, 0.95, HH - 0.02, HH + 0.06, -0.95, 0.95, hat, FAB)
	hbox(head, -0.72, 0.72, HH + 0.06, HH + 0.4, -0.72, 0.72, shade(hat, 1.1), FAB)
	hbox(head, -0.75, 0.75, HH + 0.08, HH + 0.18, -0.75, 0.75, coat, FAB)
	hadd(head, V(0.08, 0.7, 0.14), CF(0.6, HH + 0.45, 0.3) * ANG(-0.5, 0, -0.35), rgb(200, 60, 50), FAB)
	slot(prev)
	for _, a in p.arms do
		sbox(a.part, a.s, -0.2, 0.2, -0.96, -0.88, -0.56, -0.5, gold, MET)
	end
end

function OUT.prisoner(p, d)
	local rag = d.shirt
	local t = p.torso
	paint(p, t, rag, FAB)
	for _, pt in { { -0.5, 0.3 }, { 0.35, -0.45 }, { -0.2, -0.6 } } do
		front(t, pt[1] - 0.14, pt[1] + 0.14, pt[2] - 0.12, pt[2] + 0.12, 0, shade(rag, 0.62), FAB, 0.05)
	end
	back(t, 0.1, 0.5, 0.2, 0.55, 0, shade(rag, 0.7), FAB, 0.05)
	lband(p.ra, 0.3, 1 + A1, A1, rag, FAB)
	lband(p.la, 0.5, 1 + A1, A1, rag, FAB)
	front(p.ra, -0.3, 0.1, 0.12, 0.32, A1, rag, FAB)
	belt(t, -0.95, -0.82, T1, rgb(150, 128, 90), nil, FAB)
	bareLimb(p, p.rl)
	bareLimb(p, p.ll)
	for i, l in p.legs do
		local g = l.part
		lband(g, if i == 1 then -0.25 else -0.05, 1.0, L1, d.pants, FAB)
		front(g, -0.3, 0.1, if i == 1 then -0.4 else -0.2, if i == 1 then -0.22 else -0.02, L1, d.pants, FAB)
	end
	local prev = slot("Hands")
	for _, a in p.arms do
		lband(a.part, -0.72, -0.5, A2, rgb(70, 70, 76), RUST)
		add(a.part, V(0.1, 0.22, 0.06), CF(0, -0.84, -0.64) * ANG(0, 0, 0.3), rgb(80, 80, 86), RUST)
	end
	slot(prev)
end

function OUT.thrall(p, d)
	local rag = d.shirt or rgb(140, 124, 100)
	local t = p.torso
	paint(p, t, rag, FAB)
	band(t, -1.35, -0.82, T1, shade(rag, 0.92), FAB)
	for i, x in { -0.7, -0.1, 0.5 } do
		front(t, x - 0.16, x + 0.16, -1.35 - 0.12 * i, -1.1, T1, shade(rag, 0.85), FAB)
	end
	front(t, 0.2, 0.5, 0.1, 0.4, 0, shade(rag, 0.65), FAB, 0.05)
	neckRing(t, 0.95, 1.1, 0.64, 0.1, Palette.metal.dark, RUST)
	box(t, -0.08, 0.08, 0.78, 0.97, -0.77, -0.72, Palette.metal.dark, RUST)
	lband(p.ra, 0.35, 1 + A1, A1, rag, FAB)
	lband(p.la, 0.3, 1 + A1, A1, rag, FAB)
	belt(t, -0.95, -0.8, T2, rgb(120, 100, 70), nil, FAB)
	paint(p, p.rl, d.pants, FAB)
	paint(p, p.ll, d.pants, FAB)
	local prev = slot("Feet")
	for _, l in p.legs do
		lband(l.part, -0.8, -0.1, L1, rgb(170, 156, 130), FAB)
		box(l.part, -0.5 - L2, 0.5 + L2, -1.02, -0.78, -0.5 - L2 - 0.08, 0.5 + L2, p.skin, p.skinMat)
	end
	slot(prev)
end

function OUT.hero(p, d)
	local s = d.shirt
	local t = p.torso
	local strap = rgb(64, 44, 30)
	local metal = rgb(150, 140, 120)
	paint(p, t, s, FAB)
	sleeves(p, shade(s, 1.12), FAB, -0.45)
	-- coat tails split at the front
	box(t, -1 - T1, -0.1, -1.6, -0.8, -0.5 - T1, 0.5 + T1, shade(s, 1.08), FAB)
	box(t, 0.1, 1 + T1, -1.6, -0.8, -0.5 - T1, 0.5 + T1, shade(s, 1.08), FAB)
	box(t, -0.1, 0.1, -1.6, -0.8, 0.2, 0.5 + T1, shade(s, 1.08), FAB)
	-- harness crossing chest and back
	for _, z in { -0.525, 0.525 } do
		add(t, V(0.2, 2.45, 0.05), CF(0, 0, z) * ANG(0, 0, 0.62), strap, LEA)
		add(t, V(0.2, 2.45, 0.05), CF(0, 0, z) * ANG(0, 0, -0.62), strap, LEA)
	end
	box(t, -0.13, 0.13, 0.04, 0.3, -0.6, -0.54, metal, MET)
	belt(t, -0.95, -0.72, T2, strap, rgb(200, 170, 90))
	pouch(t, 0.65, -0.9, T2, rgb(80, 56, 36))
	pouch(t, -0.7, -0.9, T2, rgb(80, 56, 36))
	back(t, 0.3, 0.46, -1.3, -0.62, T2, rgb(40, 30, 24), LEA, 0.1)
	-- scarf around the neck with a tail behind
	local sc = d.accent or rgb(160, 30, 40)
	neckRing(t, 0.88, 1.08, 0.64, 0.12, sc, FAB)
	add(t, V(0.34, 1.1, 0.07), CF(-0.38, 0.4, 0.82) * ANG(0.12, 0, 0.12), shade(sc, 0.85), FAB)
	-- bracers and fingerless gloves
	local prev = slot("Hands")
	for _, a in p.arms do
		lband(a.part, -0.62, -0.06, A2, rgb(70, 50, 34), LEA)
		lband(a.part, -0.28, -0.18, A3, strap, LEA)
		lband(a.part, -1.04, -0.6, A1, rgb(34, 28, 26), LEA)
	end
	slot(prev)
	paint(p, p.rl, d.pants, FAB)
	paint(p, p.ll, d.pants, FAB)
	boots(p, rgb(44, 32, 24), 0.1, { cuff = rgb(60, 44, 32), strap = strap })
	if d.awakened then
		local g = d.glow or rgb(140, 230, 255)
		for _, sg in { 1, -1 } do
			front(t, sg * 0.45 - 0.04, sg * 0.45 + 0.04, -0.6, 0.8, 0, g, NEON, 0.07)
		end
		for _, a in p.arms do
			lband(a.part, 0.18, 0.26, A2, g, NEON)
		end
		cape(p, rgb(20, 20, 28), 2.9, { trim = g, trimMat = NEON, z0 = 0.5 + T2 + 0.03 })
	end
end

function OUT.guard(p, d)
	local mail = rgb(126, 130, 138)
	local tab = d.accent or rgb(40, 60, 140)
	local t = p.torso
	paint(p, t, mail, MAIL)
	band(t, -1.45, -0.82, T1, shade(mail, 0.9), MAIL)
	tabard(t, tab, 0.86, -1.55, 0.52, T1, shade(tab, 0.7))
	front(t, -0.2, 0.2, 0.1, 0.55, T1 + HALF, Palette.metal.gold, MET)
	front(t, -0.05, 0.05, 0.0, 0.66, T1 + 2 * HALF, shade(Palette.metal.gold, 0.8), MET)
	belt(t, -0.95, -0.74, T2 + HALF, rgb(60, 44, 30), Palette.metal.iron)
	sleeves(p, mail, MAIL, -0.45)
	neckRing(t, 0.86, 1.06, 0.64, 0.1, shade(tab, 0.8), FAB)
	gloves(p, rgb(70, 50, 34), -0.4)
	paint(p, p.rl, d.pants, FAB)
	paint(p, p.ll, d.pants, FAB)
	boots(p, rgb(50, 40, 34), -0.2, { cuff = rgb(40, 32, 26) })
	helmetKettle(p, Palette.metal.iron)
end

function OUT.soldier(p, d)
	local gam = d.shirt or rgb(190, 176, 146)
	local t = p.torso
	local line = shade(gam, 0.78)
	paint(p, t, gam, FAB)
	for i = 0, 2 do
		front(t, -0.94, 0.94, 0.5 - i * 0.44, 0.56 - i * 0.44, 0, line, FAB, 0.04)
		back(t, -0.94, 0.94, 0.5 - i * 0.44, 0.56 - i * 0.44, 0, line, FAB, 0.04)
	end
	front(t, -0.03, 0.03, -0.8, 0.98, 0.04, line, FAB)
	band(t, -1.5, -0.82, T1, gam, FAB)
	band(t, -1.2, -1.14, T2, line, FAB)
	neckRing(t, 0.86, 1.08, 0.64, 0.12, shade(gam, 0.92), FAB)
	if d.accent then
		tabard(t, d.accent, 0.86, -1.62, 0.5, T2, shade(d.accent, 0.7))
	end
	belt(t, -0.95, -0.74, T3, rgb(66, 44, 30), Palette.metal.iron)
	sleeves(p, gam, FAB, -0.48)
	for _, a in p.arms do
		lband(a.part, 0.3, 0.36, A2, line, FAB)
		lband(a.part, -0.15, -0.09, A2, line, FAB)
	end
	gloves(p, rgb(80, 58, 38), -0.44)
	paint(p, p.rl, d.pants, FAB)
	paint(p, p.ll, d.pants, FAB)
	local prev = slot("Legs")
	for _, l in p.legs do
		lband(l.part, -0.66, 0.1, L1, rgb(150, 136, 110), FAB)
		for i = 0, 2 do
			add(l.part, V(1.2, 0.06, 1.2), CF(0, -0.5 + i * 0.22, 0) * ANG(0, 0, if i % 2 == 0 then 0.2 else -0.2), rgb(90, 64, 42), LEA)
		end
	end
	slot(prev)
	boots(p, rgb(64, 44, 30), -0.62)
end

function OUT.knight(p, d)
	local steel = d.metal or Palette.metal.steel
	local dk = shade(steel, 0.72)
	local m = d.armorMat or MET
	local tab = d.accent or rgb(40, 60, 140)
	local trim = d.trim or Palette.metal.gold
	local t = p.torso
	paint(p, t, shade(steel, 0.55), MAIL)
	-- breastplate, ridge, fauld lames, mail skirt, tassets
	box(t, -1 - T1, 1 + T1, -0.32, 1 + T1, -0.5 - T1, 0.5 + T1, steel, m)
	front(t, -0.07, 0.07, -0.3, 0.96, T1, shade(steel, 1.12), m)
	band(t, -0.54, -0.3, T2, dk, m)
	band(t, -0.77, -0.52, T1, steel, m)
	band(t, -1.35, -0.77, T1, shade(steel, 0.5), MAIL)
	for _, s in { 1, -1 } do
		front(t, s * 0.06, s * 0.96, -1.42, -0.7, T1, steel, m)
	end
	neckRing(t, 0.86, 1.14, 0.64, 0.1, dk, m)
	if d.runes then
		for _, s in { 1, -1 } do
			front(t, s * 0.4 - 0.03, s * 0.4 + 0.03, -0.2, 0.8, T1, d.runes, NEON, 0.05)
		end
	end
	for _, a in p.arms do
		local ar, s = a.part, a.s
		lband(ar, 0.3, 1 + A1, A1, shade(steel, 0.5), MAIL)
		lband(ar, 0.42, 1 + A4, A4, steel, m)
		lband(ar, 0.2, 0.48, A3, dk, m)
		lband(ar, 0.38, 0.46, A4 + 0.03, trim, MET)
		sbox(ar, s, 0.5 + A4, 0.5 + A4 + 0.04, 0.8, 0.92, -0.32, -0.2, trim, MET)
		sbox(ar, s, 0.5 + A4, 0.5 + A4 + 0.04, 0.8, 0.92, 0.2, 0.32, trim, MET)
		lband(ar, -0.6, 0.3, A2, steel, m)
		sbox(ar, s, 0.5 + A2, 0.5 + A3 + 0.03, -0.26, 0.04, -0.28, 0.28, dk, m)
		if d.spiked then
			spike(ar, V(s * 0.3, 1.2, 0), V(s * 0.6, 1, 0), 0.6, 0.22, dk, m, 2)
		end
	end
	local prev = slot("Hands")
	for _, a in p.arms do
		lband(a.part, -1.04, -0.56, A3, dk, m)
		front(a.part, -0.4, 0.4, -1.0, -0.8, A3, steel, m, 0.06)
		lband(a.part, -0.62, -0.5, A4, steel, m)
	end
	slot("Legs")
	paint(p, p.rl, shade(steel, 0.5), MAIL)
	paint(p, p.ll, shade(steel, 0.5), MAIL)
	for _, l in p.legs do
		lband(l.part, 0.02, 0.98, L1, steel, m)
		front(l.part, -0.34, 0.34, -0.18, 0.2, L1, dk, m, 0.12)
		lband(l.part, -0.66, -0.1, L2, steel, m)
		if d.spiked then
			spike(l.part, V(0, 0.02, -0.6), V(0, 0.3, -1), 0.35, 0.16, dk, m, 1)
		end
	end
	slot(prev)
	boots(p, dk, -0.62, { toe = steel, sole = shade(dk, 0.6), mat = m })
	if d.tabard ~= false then
		tabard(t, tab, 0.86, -1.65, 0.5, T2, trim)
		front(t, -0.2, 0.2, 0.15, 0.55, T2 + HALF, trim, MET)
		front(t, -0.05, 0.05, 0.02, 0.68, T2 + 2 * HALF, shade(trim, 0.8), MET)
	end
	belt(t, -0.98, -0.78, T3, rgb(40, 30, 24), trim)
	greatHelm(p, steel, d)
	if d.cape ~= false then
		cape(p, if d.capeColor then d.capeColor else tab, 3.1, { trim = if d.tattered then nil else trim, tatter = d.tattered, z0 = 0.5 + T3 + 0.03, clasp = trim })
	end
end

function OUT.mage(p, d)
	local c = d.shirt
	local trim = d.accent or Palette.metal.gold
	robe(p, c, { trim = trim, hem = trim })
	bellSleeves(p, c, trim)
	belt(p.torso, -0.98, -0.8, T4, shade(c, 0.65), nil, FAB)
	front(p.torso, 0.28, 0.5, -1.6, -0.98, T4, shade(c, 0.65), FAB)
	mantle(p.torso, 0.45, T3, shade(c, 0.88), FAB)
	box(p.torso, -0.72, 0.72, 0.92, 1.48, 0.66, 0.76, trim, FAB)
	for _, s in { 1, -1 } do
		sbox(p.torso, s, 0.66, 0.76, 0.92, 1.3, 0.1, 0.66, trim, FAB)
	end
	boots(p, rgb(50, 36, 30), -0.62)
	if d.hat ~= false then
		local head = p.head
		local prev = slot("Head")
		hbox(head, -1.0, 1.0, HH + 0.02, HH + 0.09, -1.0, 1.0, c, FAB)
		local pos = V(0, HH + 0.09, 0)
		local sizes = { 1.46, 1.06, 0.72, 0.42 }
		for i, w in sizes do
			local hgt = 0.36
			local rot = ANG(0.14 * i, 0, -0.06 * i)
			hadd(head, V(w, hgt, w), CF(pos) * rot * CF(0, hgt / 2, 0), if i % 2 == 0 then shade(c, 0.92) else c, FAB)
			pos = (CF(pos) * rot * CF(0, hgt * 0.9, 0)).Position
		end
		hbox(head, -0.78, 0.78, HH + 0.09, HH + 0.2, -0.78, 0.78, trim, FAB)
		slot(prev)
	end
end

function OUT.archmage(p, d)
	d.hat = false
	OUT.mage(p, d)
	local trim = d.accent or Palette.metal.gold
	local head = p.head
	local prev = slot("Head")
	hbox(head, -0.77, 0.77, 0.52, 0.6, -0.77, 0.77, trim, MET)
	hbox(head, -0.09, 0.09, 0.47, 0.65, -0.81, -0.77, rgb(120, 220, 255), NEON)
	slot(prev)
	for _, s in { 1, -1 } do
		for i = 0, 2 do
			front(p.torso, s * 0.35 - 0.06, s * 0.35 + 0.06, -1.6 + i * 0.25, -1.48 + i * 0.25, T3, trim, FAB)
		end
	end
	for i = 0, 2 do
		local a = i * 2.1
		local cr = add(p.torso, V(0.36, 0.5, 0.36), CF(math.cos(a) * 1.8, 1.4 + (i % 2) * 0.4, 1.0 + math.sin(a) * 0.4) * ANG(0.6, a, 0.6), rgb(140, 210, 255), NEON)
		cr.CastShadow = false
	end
end

function OUT.king(p, d)
	local c = d.shirt or rgb(150, 24, 34)
	local fur = rgb(240, 238, 230)
	local gold = Palette.metal.gold
	local t = p.torso
	robe(p, c, { trim = gold, hem = fur })
	sleeves(p, c, FAB, -0.42, fur, 0.2, A2)
	mantle(t, 0.4, T4, fur, FAB)
	for _, pt in { { -0.7, 0.62 }, { -0.25, 0.5 }, { 0.25, 0.62 }, { 0.7, 0.5 }, { 0, 0.8 } } do
		front(t, pt[1] - 0.05, pt[1] + 0.05, pt[2] - 0.06, pt[2] + 0.06, T4, rgb(24, 22, 24), FAB, 0.02)
	end
	for i = -2, 2 do
		front(t, i * 0.2 - 0.07, i * 0.2 + 0.07, 0.22 + math.abs(i) * 0.1, 0.34 + math.abs(i) * 0.1, T4, gold, MET, 0.04)
	end
	front(t, -0.12, 0.12, -0.06, 0.2, T4, gold, MET, 0.06)
	belt(t, -0.95, -0.76, T4, shade(c, 0.6), gold, FAB)
	cape(p, c, 3.4, { trim = fur, z0 = 0.5 + T4 + 0.03, clasp = gold })
	boots(p, rgb(50, 30, 26), -0.62)
	crown(p, gold, rgb(220, 30, 60))
	for _, a in p.arms do
		sbox(a.part, a.s, -0.2, 0.2, -0.96, -0.88, -0.56, -0.5, gold, MET)
	end
end

function OUT.noble(p, d)
	local c = d.shirt
	local ac = d.accent or Palette.metal.gold
	local t = p.torso
	paint(p, t, c, FAB)
	front(t, -0.1, 0.1, -0.8, 0.95, 0, shade(c, 0.75), FAB, 0.05)
	for i = 0, 3 do
		front(t, -0.05, 0.05, 0.62 - i * 0.4, 0.72 - i * 0.4, 0.05, Palette.metal.gold, MET, 0.03)
	end
	band(t, -1.3, -0.82, T1, shade(c, 0.9), FAB)
	neckRing(t, 0.9, 1.12, 0.64, 0.14, WHITE, FAB)
	add(t, V(0.3, 2.5, 0.04), CF(0, 0.05, -0.5 - T1 - 0.02) * ANG(0, 0, 0.72), ac, FAB)
	add(t, V(0.3, 2.5, 0.04), CF(0, 0.05, 0.5 + T1 + 0.02) * ANG(0, 0, -0.72), ac, FAB)
	sleeves(p, shade(c, 0.9), FAB, -0.45, WHITE, 0.16)
	for _, a in p.arms do
		lband(a.part, 0.45, 1 + A3, A3, shade(c, 1.15), FAB)
		for k = -1, 1 do
			front(a.part, k * 0.3 - 0.05, k * 0.3 + 0.05, 0.5, 1.1, A3, ac, FAB)
		end
	end
	belt(t, -0.96, -0.78, T2, rgb(40, 30, 26), Palette.metal.gold)
	paint(p, p.rl, d.pants, FAB)
	paint(p, p.ll, d.pants, FAB)
	boots(p, rgb(36, 28, 24), 0.05, { cuff = rgb(60, 44, 34) })
	local prev = slot("Cloak")
	add(t, V(1.1, 2.1, 0.08), CF(-0.5, 0.0, 0.5 + T2 + 0.06) * ANG(0.06, 0, 0.1), shade(ac, 0.7), FAB)
	add(t, V(0.6, 0.3, 1.34), CF(-0.95, 0.98, 0.0) * ANG(0, 0, 0.15), shade(ac, 0.7), FAB)
	slot(prev)
end

function OUT.cultist(p, d)
	local c = d.shirt or rgb(30, 22, 30)
	local trim = d.accent or rgb(150, 20, 30)
	local t = p.torso
	robe(p, c, { tatter = true, trim = trim })
	bellSleeves(p, c)
	mantle(t, 0.35, T3, shade(c, 0.85), FAB)
	belt(t, -0.94, -0.84, T4, rgb(110, 96, 70), nil, FAB)
	front(t, -0.34, -0.26, -1.55, -0.84, T4, rgb(110, 96, 70), FAB)
	front(t, -0.4, -0.2, -1.72, -1.52, T4 + HALF, trim, if d.sigilGlow then NEON else MET)
	for _, s in { 1, -1 } do
		front(t, s * 0.6 - 0.05, s * 0.6 + 0.05, -0.7, 0.35, 0.0, trim, FAB, 0.05)
	end
	local prev = slot("Head")
	hood(p.head, c, true)
	slot(prev)
	boots(p, rgb(30, 24, 24), -0.62)
end

function OUT.barbarian(p, d)
	local skin = p.skin
	local fur = d.furMantle or d.accent or rgb(110, 84, 60)
	local leather = rgb(84, 58, 38)
	local t = p.torso
	bareLimb(p, t)
	p.painted.Torso = nil
	for _, s in { 1, -1 } do
		front(t, s * 0.08, s * 0.88, 0.25, 0.82, 0, shade(skin, 0.94), p.skinMat, 0.06)
		front(t, s * 0.06, s * 0.4, -0.35, 0.12, 0, shade(skin, 0.94), p.skinMat, 0.05)
	end
	add(t, V(0.2, 2.5, 0.05), CF(0, 0.05, -0.57) * ANG(0, 0, 0.66), leather, LEA)
	add(t, V(0.2, 2.5, 0.05), CF(0, 0.05, 0.525) * ANG(0, 0, -0.66), leather, LEA)
	box(t, 0.28, 0.5, 0.36, 0.58, -0.64, -0.58, Palette.metal.iron, MET)
	if not d.noMantle then
		mantle(t, 0.55, T3, fur, FAB)
		for i, pt in { { -0.85, 0.2 }, { -0.35, 0.3 }, { 0.3, 0.25 }, { 0.8, 0.3 } } do
			add(t, V(0.5, 0.36, 1.45), CF(pt[1], 0.95 + pt[2] * 0.3, 0.02) * ANG(0, 0.2 * i, (i % 2 - 0.5) * 0.4), shade(fur, 0.9 + (i % 2) * 0.15), FAB)
		end
	else
		box(t, -0.5, -0.1, 0.62, 0.72, -0.64, -0.56, rgb(222, 214, 190), BONE)
		box(t, 0.1, 0.5, 0.62, 0.72, -0.64, -0.56, rgb(222, 214, 190), BONE)
	end
	belt(t, -0.98, -0.7, T2, leather, Palette.metal.iron)
	front(t, -0.42, 0.42, -1.85, -0.9, T2 + HALF, shade(leather, 0.9), LEA)
	back(t, -0.42, 0.42, -1.75, -0.9, T2, shade(leather, 0.9), LEA)
	band(t, -1.38, -0.85, T1, fur, FAB)
	for i, x in { -0.8, -0.2, 0.5 } do
		front(t, x - 0.18, x + 0.18, -1.5 - (i % 2) * 0.12, -1.3, T1, shade(fur, 0.85), FAB)
	end
	local prev = slot("Hands")
	for _, a in p.arms do
		lband(a.part, -0.78, -0.2, A2, leather, LEA)
		for k = -1, 1, 2 do
			front(a.part, k * 0.22 - 0.06, k * 0.22 + 0.06, -0.55, -0.43, A2, Palette.metal.iron, MET, 0.04)
		end
	end
	slot(prev)
	paint(p, p.rl, d.pants or rgb(70, 52, 40), LEA)
	paint(p, p.ll, d.pants or rgb(70, 52, 40), LEA)
	prev = slot("Legs")
	for _, l in p.legs do
		lband(l.part, -0.6, 0.15, L1, rgb(150, 130, 100), FAB)
		for i = 0, 2 do
			add(l.part, V(1.2, 0.06, 1.2), CF(0, -0.45 + i * 0.22, 0) * ANG(0, 0, if i % 2 == 0 then 0.22 else -0.22), leather, LEA)
		end
	end
	slot(prev)
	boots(p, rgb(70, 50, 36), -0.45, { cuff = fur, cuffMat = FAB })
end

function OUT.robeGod(p, d)
	local c = d.shirt or rgb(250, 248, 240)
	local gold = d.accent or Palette.metal.gold
	local t = p.torso
	robe(p, c, { trim = gold, hem = gold, trimMat = MET })
	bellSleeves(p, c, gold)
	add(t, V(0.7, 2.6, 0.05), CF(0.1, -0.1, -0.5 - T1 - 0.025) * ANG(0, 0, 0.55), shade(c, 0.94), FAB)
	add(t, V(0.7, 2.6, 0.05), CF(0.1, -0.1, 0.5 + T1 + 0.025) * ANG(0, 0, -0.55), shade(c, 0.94), FAB)
	belt(t, -0.98, -0.8, T4, gold, nil, MET)
	for _, a in p.arms do
		lband(a.part, 0.4, 1 + A4, A4, gold, MET)
		lband(a.part, 0.36, 0.46, A4 + 0.03, shade(gold, 0.8), MET)
	end
	neckRing(t, 0.9, 1.08, 0.64, 0.12, gold, MET)
	boots(p, shade(gold, 0.8), -0.62, { mat = MET })
end

function OUT.cloak(p, d)
	local black = d.shirt or rgb(12, 12, 16)
	local t = p.torso
	robe(p, black, { tatter = true })
	sleeves(p, shade(black, 1.2), FAB, -0.62)
	for _, a in p.arms do
		lband(a.part, -0.66, 0.2, A3, black, FAB)
	end
	mantle(t, 0.2, T4, shade(black, 1.35), FAB)
	cape(p, black, 3.5, { tatter = true, z0 = 0.5 + T4 + 0.03 })
	local prev = slot("Head")
	hood(p.head, black, true)
	slot(prev)
end

function OUT.viking(p, d)
	local tunic = d.shirt
	local trim = d.accent or rgb(170, 60, 40)
	local t = p.torso
	paint(p, t, tunic, FAB)
	band(t, -1.5, -0.82, T1, tunic, FAB)
	band(t, -1.54, -1.4, T2, trim, FAB)
	for _, s in { 1, -1 } do
		add(t, V(0.12, 0.6, 0.03), CF(s * 0.16, 0.72, -0.515) * ANG(0, 0, s * 0.35), trim, FAB)
	end
	front(t, -0.4, 0.4, 0.9, 0.98, 0, trim, FAB, 0.05)
	belt(t, -0.95, -0.74, T2, rgb(70, 46, 30), Palette.metal.bronze)
	add(t, V(0.16, 0.7, 0.1), CF(-0.35, -1.05, -0.5 - T2 - 0.06) * ANG(0, 0, -0.5), rgb(60, 40, 28), LEA)
	box(t, -0.3, -0.1, -0.64, -0.58, -0.5 - T2 - 0.14, -0.5 - T2, rgb(120, 90, 60), WOOD)
	pouch(t, 0.66, -0.92, T2, rgb(96, 66, 42))
	sleeves(p, tunic, FAB, -0.5, trim, 0.14)
	paint(p, p.rl, d.pants, FAB)
	paint(p, p.ll, d.pants, FAB)
	local prev = slot("Legs")
	for _, l in p.legs do
		lband(l.part, -0.66, 0.05, L1, rgb(190, 176, 150), FAB)
		for i = 0, 3 do
			add(l.part, V(1.2, 0.06, 1.2), CF(0, -0.55 + i * 0.18, 0) * ANG(0, 0, if i % 2 == 0 then 0.2 else -0.2), rgb(110, 76, 48), LEA)
		end
	end
	slot(prev)
	boots(p, rgb(80, 54, 34), -0.62)
	if d.furMantle then
		mantle(t, 0.5, T3, d.furMantle, FAB)
		for i, x in { -0.75, -0.25, 0.25, 0.75 } do
			add(t, V(0.46, 0.3, 1.42), CF(x, 0.98 + (i % 2) * 0.04, 0.02) * ANG(0, 0.15 * i, (i % 2 - 0.5) * 0.3), shade(d.furMantle, 0.92 + (i % 2) * 0.14), FAB)
		end
	end
	box(t, 0.5, 0.74, 0.6, 0.84, -0.5 - T3 - 0.06, -0.5 - T3, Palette.metal.bronze, MET)
end

function OUT.jarl(p, d)
	d.furMantle = d.furMantle or rgb(120, 96, 72)
	OUT.viking(p, d)
	local gold = Palette.metal.gold
	for _, a in p.arms do
		lband(a.part, 0.15, 0.27, A2, gold, MET)
		lband(a.part, -0.05, 0.07, A2, gold, MET)
	end
	cape(p, d.accent or rgb(130, 30, 34), 3.2, { trim = gold, z0 = 0.5 + T3 + 0.03 })
	box(p.torso, -0.74, -0.5, 0.6, 0.84, -0.5 - T3 - 0.06, -0.5 - T3, gold, MET)
end

function OUT.scout(p, d)
	local jacket = d.jacket or rgb(120, 82, 52)
	local pale = rgb(226, 222, 210)
	local strap = rgb(40, 32, 28)
	local t = p.torso
	paint(p, t, pale, FAB)
	sleeves(p, jacket, LEA, -0.45, shade(jacket, 0.8), 0.16)
	box(t, -1 - T1, 1 + T1, 0.02, 1 + T1, -0.5 - T1, 0.5 + T1, jacket, LEA)
	for _, s in { 1, -1 } do
		add(t, V(0.4, 0.3, 0.04), CF(s * 0.42, 0.82, -0.5 - T1 - 0.02) * ANG(0, 0, s * 0.5), shade(jacket, 1.15), LEA)
	end
	belt(t, -0.3, -0.16, T1, strap, nil)
	belt(t, -0.92, -0.76, T1, strap, Palette.metal.iron)
	for _, s in { 1, -1 } do
		front(t, s * 0.52 - 0.06, s * 0.52 + 0.06, -0.95, 1.0, T1, strap, LEA)
		back(t, s * 0.52 - 0.06, s * 0.52 + 0.06, -0.95, 1.0, T1, strap, LEA)
	end
	paint(p, p.rl, pale, FAB)
	paint(p, p.ll, pale, FAB)
	local prev = slot("Legs")
	for _, l in p.legs do
		lband(l.part, 0.5, 0.6, L1, strap, LEA)
		lband(l.part, 0.05, 0.15, L1, strap, LEA)
	end
	slot(prev)
	boots(p, rgb(46, 34, 28), 0.05, { cuff = rgb(36, 28, 24), strap = strap })
	if d.cloak ~= false then
		local cc = d.cloakColor or rgb(56, 86, 58)
		cape(p, cc, 2.9, { z0 = 0.5 + T2 })
		mantle(t, 0.62, T3, shade(cc, 1.05), FAB)
	end
end

function OUT.skeleton(p, d)
	-- bones are built by the undead pass; this only adds armour and trappings
	local t = p.torso
	if d.armor then
		local a = d.armor
		local dk = shade(a, 0.7)
		box(t, -0.72, 0.72, 0.3, 0.98, -0.52, -0.42, a, RUST)
		front(t, -0.06, 0.06, 0.34, 0.94, 0.02, shade(a, 1.12), RUST, 0.04)
		box(t, -0.6, 0.6, 0.02, 0.3, -0.5, -0.4, dk, RUST)
		box(t, -0.64, 0.64, 0.34, 0.96, 0.38, 0.48, dk, RUST)
		belt(t, -0.96, -0.82, -0.14, rgb(60, 44, 32), shade(a, 1.1))
		local tab = d.accent or rgb(70, 20, 24)
		for k, z in { -0.4, 0.4 } do
			local ln = 0.8 + (k % 2) * 0.25
			add(t, V(0.6, ln, 0.04), CF(0.04 * k, -0.92 - ln / 2, z) * ANG(0, 0, 0.05 * (k - 1.5)), shade(tab, 0.8 + (k % 2) * 0.2), FAB)
		end
		for _, ar in p.arms do
			sbox(ar.part, ar.s, -0.28, 0.46, 0.7, 1.08, -0.36, 0.36, a, RUST)
			sbox(ar.part, ar.s, -0.12, 0.52, 0.48, 0.74, -0.32, 0.32, dk, RUST)
			sbox(ar.part, ar.s, 0.46, 0.5, 0.82, 0.96, -0.1, 0.1, shade(a, 1.2), RUST)
			box(ar.part, -0.2, 0.2, -0.64, -0.14, -0.2, 0.2, dk, RUST)
		end
		for _, l in p.legs do
			front(l.part, -0.2, 0.2, -0.72, -0.1, -0.3, a, RUST, 0.08)
		end
		openHelm(p, a, RUST)
	end
	if d.hooded then
		local prev = slot("Head")
		hood(p.head, d.hooded, true)
		slot(prev)
		cape(p, d.hooded, 1.6, { tatter = true, z0 = 0.5 })
	end
	if d.quiver then
		add(t, V(0.4, 1.4, 0.4), CF(0.3, 0.2, 0.62) * ANG(0, 0, -0.35), rgb(80, 56, 36), LEA)
		for i = -1, 1 do
			add(t, V(0.05, 0.4, 0.05), CF(0.62 + i * 0.07, 0.98 + i * 0.03, 0.68) * ANG(0, 0, -0.35), rgb(200, 190, 170), PLASTIC)
		end
		add(t, V(0.12, 2.4, 0.05), CF(0, 0.05, -0.36) * ANG(0, 0, 0.62), rgb(70, 50, 34), LEA)
		box(p.la, -0.2, 0.2, -0.62, -0.2, -0.2, 0.2, rgb(80, 56, 36), LEA)
	end
end

function OUT.bare(p, d) end

-- ------------------------------------------------------------------ skeleton
local function skull(p, B: Color3, glow: Color3)
	local head = p.head
	local J = shade(B, 0.84)
	local D = rgb(24, 18, 20)
	local TT = shade(B, 1.06)
	box(head, -0.54, 0.54, -0.04, 0.6, -0.46, 0.56, B, BONE)
	box(head, -0.44, 0.44, 0.6, 0.7, -0.36, 0.46, B, BONE)
	box(head, -0.56, 0.56, 0.2, 0.34, -0.62, -0.4, B, BONE)
	for _, s in { 1, -1 } do
		sbox(head, s, 0.07, 0.42, -0.08, 0.2, -0.52, -0.4, D, PLASTIC)
		local e = sbox(head, s, 0.17, 0.33, 0.0, 0.13, -0.56, -0.5, glow, NEON)
		e.CastShadow = false
		table.insert(p.eyes, e)
		sbox(head, s, 0.42, 0.56, -0.12, 0.2, -0.58, -0.3, B, BONE)
		sbox(head, s, 0.12, 0.54, -0.24, -0.08, -0.6, -0.36, B, BONE)
		sbox(head, s, 0.34, 0.46, -0.6, -0.2, -0.12, 0.1, J, BONE)
	end
	box(head, -0.07, 0.07, -0.08, 0.2, -0.6, -0.4, B, BONE)
	box(head, -0.1, 0.1, -0.26, -0.08, -0.5, -0.36, D, PLASTIC)
	box(head, -0.38, 0.38, -0.34, -0.24, -0.58, -0.2, B, BONE)
	box(head, -0.34, 0.34, -0.56, -0.32, -0.5, -0.1, D, PLASTIC)
	for _, x in { -0.22, 0, 0.22 } do
		box(head, x - 0.07, x + 0.07, -0.44, -0.33, -0.55, -0.45, TT, BONE)
	end
	box(head, -0.4, 0.4, -0.64, -0.54, -0.56, 0.08, B, BONE)
	for _, x in { -0.16, 0.16 } do
		box(head, x - 0.06, x + 0.06, -0.55, -0.46, -0.53, -0.43, TT, BONE)
	end
end

local function boneTorso(p, B: Color3)
	local t = p.torso
	local J = shade(B, 0.84)
	for i = 0, 1 do
		box(t, -0.11, 0.11, 0.95 + i * 0.3, 1.13 + i * 0.3, 0.08, 0.3, J, BONE)
	end
	for i = 0, 4 do
		local y = 0.8 - i * 0.32
		box(t, -0.12, 0.12, y - 0.1, y + 0.1, 0.12, 0.36, if i % 2 == 0 then B else J, BONE)
	end
	for i, y in { 0.62, 0.34, 0.06 } do
		local w = ({ 0.74, 0.8, 0.7 })[i]
		for _, s in { 1, -1 } do
			seg(t, V(s * 0.12, y + 0.06, 0.3), V(s * w, y, 0.02), 0.09, B, BONE)
			seg(t, V(s * w, y + 0.02, 0.04), V(s * 0.1, y - 0.12, -0.36), 0.09, B, BONE)
		end
	end
	box(t, -0.09, 0.09, -0.12, 0.8, -0.44, -0.32, B, BONE)
	for _, s in { 1, -1 } do
		seg(t, V(s * 0.08, 0.9, -0.34), V(s * 0.95, 0.98, -0.02), 0.09, B, BONE)
		add(t, V(0.5, 0.36, 0.12), CF(s * 0.45, -0.74, 0.08) * ANG(0, s * 0.5, s * -0.25), B, BONE)
	end
	box(t, -0.16, 0.16, -0.95, -0.6, 0.1, 0.34, J, BONE)
	box(t, -0.34, 0.34, -1.02, -0.9, -0.34, -0.22, B, BONE)
end

local function boneArm(p, part: BasePart, s: number, B: Color3)
	local J = shade(B, 0.84)
	box(part, -0.17, 0.17, 0.68, 0.98, -0.17, 0.17, J, BONE)
	box(part, -0.1, 0.1, 0.02, 0.7, -0.1, 0.1, B, BONE)
	box(part, -0.15, 0.15, -0.14, 0.06, -0.14, 0.14, J, BONE)
	sbox(part, s, 0.02, 0.12, -0.72, -0.1, -0.12, -0.02, B, BONE)
	sbox(part, s, -0.12, -0.02, -0.72, -0.1, 0.02, 0.12, B, BONE)
	box(part, -0.15, 0.15, -0.86, -0.7, -0.13, 0.13, J, BONE)
	for _, x in { -0.09, 0.09 } do
		seg(part, V(x, -0.84, -0.04), V(x, -1.1, -0.16), 0.07, B, BONE)
	end
end

local function boneLeg(p, part: BasePart, s: number, B: Color3)
	local J = shade(B, 0.84)
	seg(part, V(-s * 0.1, 0.94, 0), V(0, 0.04, -0.02), 0.2, B, BONE)
	box(part, -0.16, 0.16, -0.12, 0.08, -0.24, 0.12, J, BONE)
	box(part, -0.09, 0.09, -0.82, -0.1, -0.14, 0.04, B, BONE)
	sbox(part, s, 0.1, 0.17, -0.78, -0.14, -0.02, 0.06, J, BONE)
	box(part, -0.14, 0.14, -0.92, -0.8, -0.12, 0.12, J, BONE)
	box(part, -0.16, 0.16, -1.0, -0.9, -0.42, 0.14, B, BONE)
	box(part, -0.14, 0.14, -1.0, -0.93, -0.56, -0.42, J, BONE)
end

-- ------------------------------------------------------------------ race & monster features
local function claws(p, n: number, len: number, c: Color3, curl: number?)
	for _, a in p.arms do
		for i = 1, n do
			local x = (i - (n + 1) / 2) * (0.72 / n)
			local b = V(x, -0.9, -0.26)
			chain(a.part, { b, b + V(x * 0.1, -len * 0.55, -0.06), b + V(x * 0.25, -len, -len * (curl or 0.35)) }, 0.13, 0.06, c, SLATE)
		end
	end
end
local function toeClaws(p, c: Color3)
	for _, l in p.legs do
		for _, x in { -0.25, 0, 0.25 } do
			seg(l.part, V(x, -0.9, -0.48), V(x * 1.1, -1.0, -0.78), 0.1, c, SLATE)
		end
	end
end
local function backSpikes(t, n: number, y0: number, y1: number, len: number, w: number, c: Color3, z: number?)
	for i = 1, n do
		local y = y0 + (y1 - y0) * (i - 1) / math.max(1, n - 1)
		spike(t, V(0, y, z or 0.42), V(0, 0.55, 1), len * (1 - (i - 1) / n * 0.4), w, c, SLATE, 2)
	end
end
-- 3D monster face: brow ridge, dark sockets with glowing eyes, a fanged maw
local function monsterFace(p, d, o)
	o = o or {}
	p.noFace = true
	local head = p.head
	local sk = head.Color
	local glow = d.glowEye or d.glow or rgb(255, 60, 40)
	local dark = rgb(16, 10, 14)
	local tooth = o.tooth or rgb(226, 218, 196)
	box(head, -0.66, 0.66, 0.16, 0.34, -HH - 0.12, -HH + 0.1, shade(sk, 0.75), p.skinMat)
	local eyes = o.eyes or { { 0.2, 0.38, 0.0, 0.12 } }
	for _, s in { 1, -1 } do
		sbox(head, s, 0.1, 0.48, -0.08, 0.16, -HH - 0.05, -HH + 0.05, dark)
		for _, e in eyes do
			local g = sbox(head, s, e[1], e[2], e[3], e[4], -HH - 0.08, -HH - 0.03, glow, NEON)
			g.CastShadow = false
			table.insert(p.eyes, g)
		end
	end
	local my = o.mawTop or -0.18
	box(head, -0.48, 0.48, -0.56, my, -HH - 0.06, -HH + 0.05, rgb(46, 10, 16))
	local nf = o.fangs or 4
	for i = 1, nf do
		local x = -0.36 + (i - 1) * (0.72 / math.max(1, nf - 1))
		box(head, x - 0.05, x + 0.05, my - (if i % 2 == 0 then 0.14 else 0.2), my + 0.02, -HH - 0.1, -HH - 0.04, tooth, BONE)
	end
	for i = 1, nf - 1 do
		local x = -0.3 + (i - 1) * (0.6 / math.max(1, nf - 2))
		box(head, x - 0.04, x + 0.04, -0.56, -0.42, -HH - 0.14, -HH - 0.07, tooth, BONE)
	end
	box(head, -0.5, 0.5, -HH - 0.08, -0.54, -HH - 0.1, 0.1, shade(sk, 0.82), p.skinMat)
end

local function horns(head: BasePart, c: Color3, big: boolean?, curl: number?)
	local s0 = if big then 1.35 else 1
	for _, s in { 1, -1 } do
		curve(head, V(s * 0.36, HH - 0.08, -0.12), V(s * 0.55, 1, 0.1), V(1, 0, 0), curl or 1.4, 0.95 * s0, 0.26 * s0, 0.09 * s0, c, SLATE, if big then 4 else 3)
	end
end

local function batWings(t, c: Color3, span: number)
	local bone = shade(c, 0.7)
	for _, s in { 1, -1 } do
		local root = V(s * 0.45, 0.65, 0.58)
		local wrist = V(s * (0.9 + span * 0.35), 1.35 + span * 0.25, 1.05)
		seg(t, root, wrist, 0.14, bone, SLATE)
		local tips = { V(s * (1.0 + span), 1.6 + span * 0.35, 1.25), V(s * (1.05 + span * 0.95), 0.55 + span * 0.1, 1.3), V(s * (0.8 + span * 0.55), -0.35, 1.15) }
		for i, tip in tips do
			seg(t, wrist, tip, 0.08, bone, SLATE)
			local nxt = if i < #tips then tips[i + 1] else root + V(0, -1.0, 0.1)
			local cen = (wrist + tip + nxt) / 3
			local wv = (tip - nxt).Magnitude
			local up = ((tip + nxt) / 2 - wrist)
			local hgt = up.Magnitude
			if hgt > 1e-3 then
				local u = up / hgt
				local r = (tip - nxt).Unit
				local nrm = r:Cross(u)
				if nrm.Magnitude > 1e-3 then
					r = u:Cross(nrm.Unit)
					local cf = CFrame.fromMatrix(cen + u * (hgt * 0.1) + nrm.Unit * 0.06, r, u)
					add(t, V(wv * 0.8, hgt * 0.95, 0.04), cf, c, LEA, { CastShadow = false })
				end
			end
		end
	end
end

local RACE = {}

function RACE.Elf(p, d)
	local head = p.head
	for _, s in { 1, -1 } do
		sbox(head, s, HH - 0.02, HH + 0.13, -0.12, 0.18, -0.05, 0.16, p.skin, p.skinMat)
		seg(head, V(s * (HH + 0.08), 0.12, 0.05), V(s * (HH + 0.4), 0.42, 0.2), 0.12, p.skin, p.skinMat, 0.16)
		seg(head, V(s * (HH + 0.36), 0.38, 0.18), V(s * (HH + 0.58), 0.62, 0.28), 0.07, shade(p.skin, 0.96), p.skinMat, 0.1)
	end
end

function RACE.Goblin(p, d)
	local head = p.head
	local sk = p.skin
	local inner = mix(sk, rgb(200, 110, 110), 0.4)
	for _, s in { 1, -1 } do
		chain(head, { V(s * (HH - 0.02), 0.08, 0.05), V(s * (HH + 0.35), 0.16, 0.12), V(s * (HH + 0.75), 0.3, 0.22), V(s * (HH + 1.02), 0.44, 0.3) }, 0.32, 0.08, sk, p.skinMat, 0.35)
		seg(head, V(s * (HH + 0.1), 0.12, 0.02), V(s * (HH + 0.6), 0.24, 0.12), 0.16, inner, p.skinMat, 0.06)
		add(head, V(0.34, 0.08, 0.1), CF(s * 0.28, 0.3, -HH - 0.03) * ANG(0, 0, s * 0.35), shade(sk, 0.62), p.skinMat)
		box(head, s * 0.22 - 0.035, s * 0.22 + 0.035, -0.54, -0.4, -HH - 0.07, -HH - 0.01, rgb(230, 222, 190), BONE)
	end
	seg(head, V(0, 0.04, -HH + 0.02), V(0, -0.14, -HH - 0.34), 0.2, shade(sk, 0.92), p.skinMat, 0.2)
	seg(head, V(0, -0.12, -HH - 0.3), V(0, -0.3, -HH - 0.33), 0.12, shade(sk, 0.88), p.skinMat)
	box(head, 0.28, 0.36, -0.2, -0.12, -HH - 0.04, -HH, shade(sk, 0.75), p.skinMat)
end

function RACE.Orc(p, d)
	local head = p.head
	local sk = p.skin
	local ivory = rgb(236, 228, 200)
	box(head, -0.5, 0.5, -HH - 0.08, -0.46, -HH - 0.1, -HH + 0.15, shade(sk, 0.9), p.skinMat)
	box(head, -0.58, 0.58, 0.18, 0.32, -HH - 0.1, -HH + 0.05, shade(sk, 0.72), p.skinMat)
	box(head, -0.15, 0.15, -0.3, -0.08, -HH - 0.08, -HH + 0.02, shade(sk, 0.85), p.skinMat)
	for _, s in { 1, -1 } do
		chain(head, { V(s * 0.3, -0.5, -HH - 0.06), V(s * 0.33, -0.3, -HH - 0.14), V(s * 0.4, -0.1, -HH - 0.1) }, 0.14, 0.07, ivory, BONE)
		seg(head, V(s * (HH - 0.02), 0.05, 0.05), V(s * (HH + 0.32), 0.18, 0.18), 0.16, sk, p.skinMat, 0.1)
	end
end

function RACE.Demon(p, d)
	local head = p.head
	local hornC = d.hornColor or d.accent or rgb(40, 30, 30)
	horns(head, hornC, d.bigHorns or (d.scale and d.scale > 1.2), d.hornCurl)
	for _, s in { 1, -1 } do
		seg(head, V(s * (HH - 0.02), 0.08, 0.05), V(s * (HH + 0.3), 0.3, 0.18), 0.13, p.skin, p.skinMat, 0.08)
	end
	local t = p.torso
	chain(t, { V(0, -0.85, 0.46), V(0, -1.2, 0.95), V(0, -1.75, 1.3), V(0, -2.25, 1.35) }, 0.2, 0.1, p.skin, p.skinMat)
	add(t, V(0.34, 0.34, 0.06), CF(0, -2.42, 1.36) * ANG(0, 0, math.pi / 4), shade(hornC, 1.1), SLATE)
end

function RACE.Lizard(p, d)
	local head = p.head
	local t = p.torso
	local sk = p.skin
	local dk = shade(sk, 0.72)
	local tooth = rgb(236, 230, 206)
	box(head, -0.36, 0.36, -0.34, -0.1, -HH - 0.78, -HH + 0.1, sk, p.skinMat)
	box(head, -0.22, 0.22, -0.1, 0.02, -HH - 0.6, -HH + 0.05, dk, p.skinMat)
	box(head, -0.32, 0.32, -0.52, -0.34, -HH - 0.64, -HH + 0.1, shade(sk, 0.86), p.skinMat)
	for _, s in { 1, -1 } do
		sbox(head, s, 0.1, 0.2, -0.1, -0.06, -HH - 0.74, -HH - 0.66, rgb(20, 20, 20))
		for k = 0, 3 do
			sbox(head, s, 0.24, 0.3, -0.42, -0.34, -HH - 0.72 + k * 0.17, -HH - 0.66 + k * 0.17, tooth, BONE)
		end
		add(head, V(0.5, 0.5, 0.06), CF(s * (HH + 0.12), -0.02, 0.3) * ANG(0, s * 0.6, 0), dk, p.skinMat)
	end
	for i = 0, 3 do
		spike(head, V(0.05, HH - 0.02, -0.35 + i * 0.3), V(0, 1, 0.7), 0.5 - i * 0.08, 0.22, dk, SLATE, 1)
	end
	backSpikes(t, 4, 0.8, -0.4, 0.36, 0.16, dk, 0.5)
	chain(t, { V(0, -0.85, 0.42), V(0, -1.3, 1.0), V(0, -1.9, 1.6), V(0, -2.4, 2.2), V(0, -2.7, 2.8) }, 0.55, 0.14, sk, p.skinMat)
	if p.outfit == "bare" then
		for i = 0, 2 do
			front(t, -0.42, 0.42, 0.45 - i * 0.45, 0.8 - i * 0.45, 0, mix(sk, rgb(230, 220, 170), 0.45), p.skinMat, 0.05)
		end
	end
	claws(p, 3, 0.35, rgb(230, 222, 200), 0.3)
end

local BEAST_INNER = rgb(236, 170, 168)
function RACE.Beastkin(p, d)
	local head = p.head
	local t = p.torso
	local kind = d.beast or "wolf"
	local c = p.hairC
	local lite = shade(c, 1.15)
	for _, s in { 1, -1 } do
		if kind == "rabbit" then
			add(head, V(0.26, 0.62, 0.14), CF(s * 0.26, HH + 0.36, 0.05) * ANG(0, 0, -s * 0.1), c, PLASTIC)
			add(head, V(0.22, 0.46, 0.14), CF(s * 0.33, HH + 0.88, 0.1) * ANG(0.25, 0, -s * 0.18), c, PLASTIC)
			add(head, V(0.14, 0.5, 0.03), CF(s * 0.26, HH + 0.38, -0.035) * ANG(0, 0, -s * 0.1), BEAST_INNER, PLASTIC)
		elseif kind == "bear" or kind == "boar" then
			sbox(head, s, 0.3, 0.63, HH + 0.04, HH + 0.28, -0.03, 0.14, c)
			sbox(head, s, 0.38, 0.54, HH + 0.1, HH + 0.21, -0.06, -0.03, BEAST_INNER)
		else
			local tall = if kind == "fox" then 1.25 else if kind == "cat" then 0.8 else 1
			sbox(head, s, 0.18, 0.56, HH + 0.06, HH + 0.06 + 0.22 * tall, -0.04, 0.12, c)
			sbox(head, s, 0.24, 0.5, HH + 0.06 + 0.22 * tall, HH + 0.06 + 0.38 * tall, -0.04, 0.12, c)
			sbox(head, s, 0.3, 0.44, HH + 0.06 + 0.38 * tall, HH + 0.06 + 0.52 * tall, -0.04, 0.12, if kind == "fox" then rgb(40, 30, 28) else c)
			sbox(head, s, 0.26, 0.48, HH + 0.14, HH + 0.06 + 0.36 * tall, -0.07, -0.04, BEAST_INNER)
			sbox(head, s, HH - 0.02, HH + 0.14, -0.38, -0.12, -0.4, -0.08, lite)
		end
	end
	local nose = rgb(30, 24, 26)
	if kind == "wolf" then
		box(head, -0.28, 0.28, -0.46, -0.1, -HH - 0.34, -HH + 0.05, shade(c, 1.08))
		box(head, -0.12, 0.12, -0.18, -0.06, -HH - 0.38, -HH - 0.3, nose)
		box(head, -0.22, 0.22, -0.37, -0.33, -HH - 0.37, -HH - 0.3, nose)
	elseif kind == "fox" then
		box(head, -0.24, 0.24, -0.44, -0.12, -HH - 0.25, -HH + 0.05, lite)
		box(head, -0.15, 0.15, -0.4, -0.18, -HH - 0.42, -HH - 0.2, shade(lite, 1.05))
		box(head, -0.08, 0.08, -0.24, -0.16, -HH - 0.45, -HH - 0.4, nose)
	elseif kind == "boar" then
		box(head, -0.34, 0.34, -0.48, -0.14, -HH - 0.22, -HH + 0.05, shade(c, 1.05))
		box(head, -0.26, 0.26, -0.44, -0.18, -HH - 0.26, -HH - 0.2, BEAST_INNER)
		for _, s in { 1, -1 } do
			sbox(head, s, 0.06, 0.16, -0.36, -0.26, -HH - 0.28, -HH - 0.24, nose)
			chain(head, { V(s * 0.3, -0.44, -HH - 0.12), V(s * 0.36, -0.22, -HH - 0.24) }, 0.09, 0.06, rgb(236, 230, 210), BONE)
		end
	elseif kind == "bear" then
		box(head, -0.32, 0.32, -0.48, -0.12, -HH - 0.24, -HH + 0.05, shade(c, 1.15))
		box(head, -0.14, 0.14, -0.22, -0.1, -HH - 0.28, -HH - 0.22, nose)
	elseif kind == "cat" then
		box(head, -0.07, 0.07, -0.2, -0.12, -HH - 0.05, -HH, rgb(210, 130, 140))
	end
	if kind == "wolf" then
		chain(t, { V(0, -0.8, 0.5), V(0, -1.1, 0.85), V(0, -1.6, 1.05), V(0, -2.0, 1.0) }, 0.36, 0.24, c)
	elseif kind == "fox" then
		chain(t, { V(0, -0.8, 0.5), V(0, -1.1, 0.9), V(0, -1.55, 1.15) }, 0.42, 0.36, c)
		box(t, -0.2, 0.2, -1.95, -1.5, 1.0, 1.4, rgb(236, 232, 224))
	elseif kind == "cat" then
		chain(t, { V(0, -0.85, 0.5), V(0, -1.3, 0.9), V(0, -1.1, 1.35), V(0, -0.55, 1.5) }, 0.16, 0.12, c)
	elseif kind == "bear" then
		add(t, V(0.32, 0.26, 0.32), CF(0, -0.82, 0.6) * ANG(0.4, math.pi / 4, 0.3), c)
	elseif kind == "boar" then
		chain(t, { V(0, -0.85, 0.5), V(0, -1.05, 0.72), V(0.1, -0.9, 0.85) }, 0.09, 0.07, c)
	elseif kind == "rabbit" then
		add(t, V(0.38, 0.34, 0.38), CF(0, -0.8, 0.66) * ANG(0.4, math.pi / 4, 0.3), rgb(240, 238, 232))
	end
end

-- generic pit monster (race Monster without a kind)
function RACE.Monster(p, d)
	local bone = rgb(222, 214, 196)
	claws(p, 3, 0.5, bone)
	backSpikes(p.torso, 3, 0.8, -0.2, 0.5, 0.22, shade(p.skin, 0.55))
	toeClaws(p, bone)
	monsterFace(p, d)
end

-- ---------------------------------------------------------------- monster kinds
local KIND = {}

function KIND.crawler(p, d)
	local head, t = p.head, p.torso
	local sk = p.skin
	local bone = rgb(206, 196, 184)
	local dark = rgb(20, 10, 22)
	local glow = d.glowEye or d.glow or rgb(210, 120, 255)
	p.noFace = true
	box(head, -0.5, 0.5, -0.2, 0.5, -HH - 0.35, -HH + 0.2, shade(sk, 0.9), p.skinMat)
	box(head, -0.44, 0.44, 0.02, 0.4, -HH - 0.37, -HH - 0.3, dark)
	for _, e in { { 0.12, 0.3 }, { 0.3, 0.22 }, { 0.22, 0.08 } } do
		for _, s in { 1, -1 } do
			local g = box(head, s * e[1] - 0.06, s * e[1] + 0.06, e[2] - 0.05, e[2] + 0.05, -HH - 0.4, -HH - 0.34, glow, NEON)
			g.CastShadow = false
			table.insert(p.eyes, g)
		end
	end
	box(head, -0.42, 0.42, -0.6, -0.2, -HH - 0.2, -HH + 0.1, rgb(40, 8, 20))
	for _, x in { -0.3, -0.1, 0.1, 0.3 } do
		box(head, x - 0.035, x + 0.035, -0.46, -0.2, -HH - 0.28, -HH - 0.21, bone, BONE)
	end
	for _, s in { 1, -1 } do
		chain(head, { V(s * 0.4, -0.35, -HH - 0.15), V(s * 0.32, -0.55, -HH - 0.38), V(s * 0.12, -0.62, -HH - 0.5) }, 0.12, 0.05, bone, BONE)
	end
	for i = 0, 2 do
		spike(head, V(0, HH - 0.05, -0.1 + i * 0.28), V(0, 0.8, 1), 0.45 - i * 0.1, 0.16, shade(sk, 0.6), SLATE, 1)
	end
	for i, y in { 0.62, 0.36, 0.1, -0.16 } do
		for _, s in { 1, -1 } do
			add(t, V(0.8 - i * 0.06, 0.09, 0.07), CF(s * 0.44, y, -0.535) * ANG(0, 0, s * -0.25), bone, BONE)
		end
	end
	front(t, -0.08, 0.08, -0.25, 0.82, 0, bone, BONE, 0.09)
	front(t, -0.6, 0.6, -0.95, -0.34, 0, shade(sk, 0.55), p.skinMat, 0.04)
	back(t, -0.7, 0.7, 0.1, 1.0, 0, shade(sk, 0.85), p.skinMat, 0.18)
	backSpikes(t, 5, 0.9, -0.6, 0.55, 0.2, shade(sk, 0.5), 0.6)
	claws(p, 3, 0.85, bone, 0.4)
	for _, a in p.arms do
		spike(a.part, V(0, -0.05, 0.45), V(0, -0.3, 1), 0.45, 0.16, bone, BONE, 2)
		spike(a.part, V(a.s * 0.15, 0.95, 0), V(a.s * 0.3, 1, 0.2), 0.4, 0.18, shade(sk, 0.5), SLATE, 1)
	end
	for _, l in p.legs do
		spike(l.part, V(0, 0.0, -0.45), V(0, 0.3, -1), 0.35, 0.16, bone, BONE, 1)
	end
	toeClaws(p, bone)
end

function KIND.ghoul(p, d)
	local head, t = p.head, p.torso
	local sk = p.skin
	local rib = shade(sk, 1.25)
	local rag = d.rag or rgb(70, 62, 52)
	p.noFace = true
	local glow = d.glowEye or d.glow or rgb(180, 255, 120)
	box(head, -0.62, 0.62, 0.18, 0.3, -HH - 0.08, -HH + 0.06, shade(sk, 0.72), p.skinMat)
	for _, s in { 1, -1 } do
		sbox(head, s, 0.1, 0.46, -0.08, 0.18, -HH - 0.04, -HH + 0.05, rgb(14, 12, 12))
		local g = sbox(head, s, 0.2, 0.32, 0.02, 0.1, -HH - 0.06, -HH - 0.02, glow, NEON)
		g.CastShadow = false
		table.insert(p.eyes, g)
		sbox(head, s, 0.4, 0.6, -0.4, -0.12, -HH - 0.04, -HH + 0.06, shade(sk, 0.7), p.skinMat)
	end
	box(head, -0.34, 0.34, -0.72, -0.2, -HH - 0.06, -HH + 0.05, rgb(34, 10, 12))
	box(head, -0.38, 0.38, -0.86, -0.72, -HH - 0.1, -HH + 0.12, shade(sk, 0.85), p.skinMat)
	for _, x in { -0.24, -0.08, 0.08, 0.24 } do
		box(head, x - 0.04, x + 0.04, -0.4, -0.2, -HH - 0.09, -HH - 0.04, rgb(210, 200, 170), BONE)
		box(head, x - 0.035, x + 0.035, -0.72, -0.58, -HH - 0.09, -HH - 0.04, rgb(200, 190, 160), BONE)
	end
	for i, pt in { { -0.35, 0.3 }, { 0.2, 0.5 }, { 0.45, 0.1 } } do
		seg(head, V(pt[1], HH + 0.02, pt[2] - 0.2), V(pt[1] * 1.3, -0.1 - i * 0.25, pt[2] + 0.45), 0.07, rgb(40, 40, 36))
	end
	for _, y in { 0.6, 0.36, 0.12 } do
		for _, s in { 1, -1 } do
			add(t, V(0.72, 0.09, 0.06), CF(s * 0.46, y, -0.53) * ANG(0, 0, s * -0.3), rib, p.skinMat)
		end
	end
	front(t, -0.07, 0.07, 0.0, 0.8, 0, rib, p.skinMat, 0.08)
	front(t, -0.55, 0.55, -0.85, -0.2, 0, shade(sk, 0.6), p.skinMat, 0.03)
	for i = 0, 4 do
		back(t, -0.1, 0.1, 0.72 - i * 0.36, 0.86 - i * 0.36, 0, rib, p.skinMat, 0.08)
	end
	for _, s in { 1, -1 } do
		seg(t, V(s * 0.1, 0.92, -0.52), V(s * 0.9, 0.98, -0.5), 0.08, rib, p.skinMat)
	end
	band(t, -0.98, -0.88, T1, rgb(110, 94, 70), FAB)
	for i, x in { -0.6, -0.15, 0.3, 0.7 } do
		local ln = 0.5 + (i % 3) * 0.2
		add(t, V(0.34, ln, 0.04), CF(x, -1.0 - ln / 2, -0.5 - T1 - 0.03) * ANG(0, 0, (i % 2 - 0.5) * 0.12), shade(rag, 0.9 + (i % 2) * 0.15), FAB)
		add(t, V(0.34, ln * 0.8, 0.04), CF(x, -1.0 - ln * 0.4, 0.5 + T1 + 0.03) * ANG(0, 0, (i % 2 - 0.5) * -0.12), shade(rag, 0.85), FAB)
	end
	for _, a in p.arms do
		box(a.part, -0.52, 0.52, -0.2, 0.0, -0.52, 0.52, shade(sk, 0.9), p.skinMat)
	end
	claws(p, 4, 0.7, rgb(60, 54, 44), 0.3)
	for _, l in p.legs do
		lband(l.part, 0.1, 1.0, L1, rag, FAB)
		front(l.part, -0.26, 0.26, -0.16, 0.12, 0, shade(sk, 0.85), p.skinMat, 0.06)
	end
	toeClaws(p, rgb(60, 54, 44))
end

function KIND.brute(p, d)
	local head, t = p.head, p.torso
	local sk = p.skin
	local plate = d.plate or rgb(46, 40, 50)
	local ivory = rgb(222, 212, 186)
	p.noFace = true
	local glow = d.glowEye or d.glow or rgb(255, 80, 80)
	box(head, -0.7, 0.7, 0.1, 0.36, -HH - 0.16, -HH + 0.1, shade(sk, 0.7), p.skinMat)
	for _, s in { 1, -1 } do
		sbox(head, s, 0.14, 0.42, -0.08, 0.1, -HH - 0.04, -HH + 0.05, rgb(16, 10, 14))
		local g = sbox(head, s, 0.2, 0.34, -0.04, 0.06, -HH - 0.07, -HH - 0.02, glow, NEON)
		g.CastShadow = false
		table.insert(p.eyes, g)
		chain(head, { V(s * 0.36, -0.36, -HH - 0.22), V(s * 0.4, -0.08, -HH - 0.32), V(s * 0.46, 0.1, -HH - 0.28) }, 0.16, 0.08, ivory, BONE)
		spike(head, V(s * 0.3, HH, -0.1), V(s * 0.4, 1, 0.3), 0.35, 0.18, plate, SLATE, 1)
	end
	box(head, -0.56, 0.56, -0.72, -0.3, -HH - 0.25, -HH + 0.2, shade(sk, 0.86), p.skinMat)
	box(head, -0.46, 0.46, -0.32, -0.2, -HH - 0.2, -HH + 0.05, rgb(40, 10, 14))
	for _, x in { -0.3, -0.1, 0.1, 0.3 } do
		box(head, x - 0.05, x + 0.05, -0.3, -0.2, -HH - 0.25, -HH - 0.2, ivory, BONE)
	end
	for _, a in p.arms do
		local s = a.s
		add(a.part, V(1.55, 0.72, 1.5), CF(s * 0.1, 0.98, 0) * ANG(0, 0, s * 0.22), plate, SLATE)
		spike(a.part, V(s * 0.25, 1.3, -0.25), V(s * 0.5, 1, -0.2), 0.6, 0.24, shade(plate, 0.8), SLATE, 2)
		spike(a.part, V(s * 0.4, 1.2, 0.3), V(s * 0.8, 0.7, 0.4), 0.5, 0.2, shade(plate, 0.8), SLATE, 2)
		lband(a.part, -0.98, -0.1, A3, shade(sk, 0.92), p.skinMat)
		for k = -1, 1 do
			front(a.part, k * 0.3 - 0.07, k * 0.3 + 0.07, -0.95, -0.8, A3, ivory, BONE, 0.1)
		end
		lband(a.part, -0.6, -0.4, A4, rgb(80, 70, 66), RUST)
		add(a.part, V(0.14, 0.26, 0.08), CF(s * 0.2, -0.75, 0.78) * ANG(0.3, 0, 0.4), rgb(90, 80, 74), RUST)
	end
	back(t, -0.95, 0.95, 0.1, 1.05, 0, plate, SLATE, 0.14)
	back(t, -0.8, 0.8, -0.35, 0.3, 0.14, shade(plate, 0.9), SLATE, 0.12)
	back(t, -0.6, 0.6, -0.8, -0.2, 0.26, shade(plate, 0.8), SLATE, 0.1)
	backSpikes(t, 3, 0.9, 0.0, 0.6, 0.26, shade(plate, 0.75), 0.62)
	front(t, -0.75, 0.75, -1.0, -0.1, 0, shade(sk, 1.06), p.skinMat, 0.2)
	for _, s in { 1, -1 } do
		front(t, s * 0.08, s * 0.9, 0.2, 0.85, 0, shade(sk, 0.94), p.skinMat, 0.1)
	end
	band(t, -1.05, -0.9, T4, rgb(70, 52, 40), LEA)
	front(t, -0.5, 0.5, -1.9, -1.0, T4, rgb(62, 46, 36), LEA)
	for _, l in p.legs do
		front(l.part, -0.4, 0.4, -0.2, 0.25, 0, plate, SLATE, 0.14)
	end
	toeClaws(p, ivory)
end

function KIND.gnasher(p, d)
	local head, t = p.head, p.torso
	local sk = p.skin
	local tooth = rgb(230, 220, 200)
	local gum = rgb(90, 14, 30)
	local glow = d.glowEye or d.glow or rgb(255, 60, 200)
	p.noFace = true
	box(head, -0.62, 0.62, -0.18, 0.28, -HH - 0.62, -HH + 0.1, shade(sk, 0.95), p.skinMat)
	box(head, -0.55, 0.55, -0.72, -0.48, -HH - 0.5, -HH + 0.1, shade(sk, 0.85), p.skinMat)
	box(head, -0.5, 0.5, -0.5, -0.16, -HH - 0.45, -HH + 0.05, gum)
	for i = 0, 5 do
		local x = -0.45 + i * 0.18
		box(head, x - 0.05, x + 0.05, -0.42, -0.16, -HH - 0.58, -HH - 0.5, tooth, BONE)
	end
	for i = 0, 4 do
		local x = -0.36 + i * 0.18
		box(head, x - 0.05, x + 0.05, -0.5, -0.28, -HH - 0.46, -HH - 0.38, tooth, BONE)
	end
	for _, e in { { 0.22, 0.2 }, { 0.44, 0.12 } } do
		for _, s in { 1, -1 } do
			local g = box(head, s * e[1] - 0.07, s * e[1] + 0.07, e[2] - 0.05, e[2] + 0.05, -HH - 0.66, -HH - 0.6, glow, NEON)
			g.CastShadow = false
			table.insert(p.eyes, g)
		end
	end
	box(head, -0.6, 0.6, 0.28, 0.38, -HH - 0.5, -HH + 0.05, shade(sk, 0.7), p.skinMat)
	for i = 0, 5 do
		local a = -1.1 + i * 0.44
		spike(head, V(math.sin(a) * 0.45, HH - 0.1, 0.3), V(math.sin(a) * 0.8, 0.9, 0.9), 0.7 - math.abs(a) * 0.15, 0.22, shade(sk, 0.5), SLATE, 2)
	end
	backSpikes(t, 5, 0.9, -0.7, 0.7, 0.26, shade(sk, 0.5), 0.5)
	for i, y in { 0.55, 0.25, -0.05 } do
		for _, s in { 1, -1 } do
			add(t, V(0.8, 0.1, 0.07), CF(s * 0.45, y, -0.535) * ANG(0, 0, s * -0.28), shade(tooth, 0.85 - i * 0.03), BONE)
		end
	end
	claws(p, 4, 1.0, tooth, 0.45)
	for _, a in p.arms do
		spike(a.part, V(0, 0.2, 0.45), V(0, -0.2, 1), 0.5, 0.18, shade(sk, 0.5), SLATE, 2)
	end
	chain(t, { V(0, -0.8, 0.45), V(0, -1.3, 1.0), V(0, -1.8, 1.6), V(0, -2.3, 2.2) }, 0.4, 0.14, shade(sk, 0.9), p.skinMat)
	toeClaws(p, tooth)
end

local function houndHead(p, d, big: number)
	local head = p.head
	local sk = p.skin
	local fang = rgb(236, 228, 206)
	local glow = d.glowEye or d.glow or rgb(255, 180, 60)
	p.noFace = true
	box(head, -0.62, 0.62, 0.18, 0.3, -HH - 0.08, -HH + 0.06, shade(sk, 0.72), p.skinMat)
	box(head, -0.34 * big, 0.34 * big, -0.32, 0.12, -HH - 0.6 * big, -HH + 0.05, shade(sk, 0.95), p.skinMat)
	box(head, -0.28 * big, 0.28 * big, -0.52, -0.32, -HH - 0.5 * big, -HH + 0.05, shade(sk, 0.82), p.skinMat)
	box(head, -0.14, 0.14, -0.02, 0.14, -HH - 0.64 * big, -HH - 0.58 * big, rgb(22, 18, 20))
	box(head, -0.3 * big, 0.3 * big, -0.36, -0.3, -HH - 0.58 * big, -HH - 0.08, d.fire or rgb(40, 8, 12), if d.fire then NEON else PLASTIC)
	for _, s in { 1, -1 } do
		local g = sbox(head, s, 0.14, 0.42, -0.02, 0.15, -HH - 0.06, -HH - 0.01, glow, NEON)
		g.CastShadow = false
		table.insert(p.eyes, g)
		box(head, s * 0.19 * big - 0.04, s * 0.19 * big + 0.04, -0.46, -0.3, -HH - 0.5 * big - 0.04, -HH - 0.5 * big + 0.03, fang, BONE)
		box(head, s * 0.12 * big - 0.035, s * 0.12 * big + 0.035, -0.38, -0.22, -HH - 0.6 * big - 0.03, -HH - 0.6 * big + 0.04, fang, BONE)
		chain(head, { V(s * 0.36, HH - 0.05, 0.1), V(s * 0.5, HH + 0.3, 0.3), V(s * 0.52, HH + 0.45, 0.55) }, 0.3, 0.1, shade(sk, 0.85), p.skinMat, 0.4)
	end
end

local function furRuff(t, c: Color3, big: number)
	for i, pt in { { -0.7, 0.95, 0.1 }, { 0.7, 0.95, 0.1 }, { -0.3, 1.02, 0.4 }, { 0.3, 1.02, 0.4 }, { 0, 0.85, 0.62 }, { 0, 0.4, 0.62 } } do
		add(t, V(0.72 * big, 0.5 * big, 0.62 * big), CF(pt[1], pt[2], pt[3]) * ANG(0.3, 0.3 * i, (i % 2 - 0.5) * 0.5), shade(c, 0.88 + (i % 3) * 0.1), FAB)
	end
end

function KIND.hound(p, d)
	local t = p.torso
	local sk = p.skin
	local fire = d.fire
	houndHead(p, d, 1.1)
	furRuff(t, shade(sk, 0.7), 1.05)
	front(t, -0.6, 0.6, -0.9, 0.7, 0, shade(sk, 1.3), p.skinMat, 0.06)
	for i = 0, 2 do
		front(t, -0.5 + i * 0.04, 0.5 - i * 0.04, 0.45 - i * 0.4, 0.51 - i * 0.4, 0.06, shade(sk, 1.05), p.skinMat, 0.04)
	end
	for i = 0, 5 do
		local y = 1.05 - i * 0.28
		spike(t, V((i % 2 - 0.5) * 0.3, y, 0.45), V((i % 2 - 0.5) * 0.4, 0.8, 1), 0.7 - i * 0.06, 0.24, if fire then (if i % 2 == 0 then fire else rgb(255, 210, 80)) else shade(sk, 0.55), if fire then NEON else SLATE, 2)
	end
	chain(t, { V(0, -0.8, 0.5), V(0, -1.0, 0.95), V(0, -1.4, 1.35), V(0, -1.9, 1.5) }, 0.26, 0.12, shade(sk, 0.9), p.skinMat)
	for _, a in p.arms do
		add(a.part, V(0.5, 0.6, 0.5), CF(a.s * 0.4, 0.0, 0.35) * ANG(0.5, 0, a.s * 0.45), shade(sk, 0.75), FAB)
	end
	claws(p, 3, 0.55, rgb(230, 222, 200))
	toeClaws(p, rgb(230, 222, 200))
	for _, l in p.legs do
		spike(l.part, V(0, -0.2, 0.45), V(0, 0.3, 1), 0.35, 0.14, shade(sk, 0.6), SLATE, 1)
	end
	if fire then
		for _, s in { 1, -1 } do
			seg(t, V(s * 0.3, 0.95, -0.56), V(s * 0.6, 0.35, -0.56), 0.07, fire, NEON, 0.04)
			seg(t, V(s * 0.6, 0.35, -0.56), V(s * 0.25, -0.2, -0.56), 0.07, fire, NEON, 0.04)
			seg(t, V(s * 0.25, -0.2, -0.56), V(s * 0.5, -0.85, -0.56), 0.06, fire, NEON, 0.04)
			sbox(t, s, 1.0, 1.04, -0.6, 0.4, -0.08, -0.03, fire, NEON)
		end
		for _, a in p.arms do
			seg(a.part, V(a.s * 0.52, 0.6, -0.1), V(a.s * 0.52, -0.3, 0.15), 0.07, fire, NEON, 0.04)
			seg(a.part, V(a.s * 0.1, -0.4, -0.52), V(a.s * -0.2, -0.85, -0.52), 0.06, fire, NEON, 0.04)
		end
		for _, l in p.legs do
			seg(l.part, V(l.s * 0.52, 0.6, -0.2), V(l.s * 0.52, -0.4, 0.2), 0.07, fire, NEON, 0.04)
		end
	end
end

function KIND.werewolf(p, d)
	local t = p.torso
	local fur = p.hairC
	local sk = p.skin
	houndHead(p, d, 1.2)
	t.Color = fur
	t.Material = FAB
	furRuff(t, fur, 1.3)
	front(t, -0.55, 0.55, -0.6, 0.72, 0, shade(fur, 1.35), FAB, 0.08)
	for i = 0, 1 do
		front(t, -0.45, 0.45, -0.4 + i * 0.5, -0.34 + i * 0.5, 0.08, shade(fur, 1.15), FAB, 0.04)
	end
	for _, a in p.arms do
		lband(a.part, -0.5, 1.0 + A2, A2, fur, FAB)
		add(a.part, V(0.4, 0.5, 0.36), CF(a.s * 0.45, -0.1, 0.4) * ANG(0.4, 0, a.s * 0.4), shade(fur, 0.85), FAB)
	end
	claws(p, 3, 0.7, rgb(40, 36, 34), 0.4)
	paint(p, p.rl, fur, FAB)
	paint(p, p.ll, fur, FAB)
	for i, l in p.legs do
		lband(l.part, if i == 1 then 0.0 else 0.2, 1.0, L1, d.pants or rgb(70, 60, 50), FAB)
	end
	chain(t, { V(0, -0.8, 0.5), V(0, -1.1, 0.9), V(0, -1.6, 1.15), V(0, -2.0, 1.1) }, 0.38, 0.26, fur, FAB)
	toeClaws(p, rgb(40, 36, 34))
	local _ = sk
end

function KIND.wraith(p, d)
	local head = p.head
	local glow = d.glowEye or d.glow or rgb(190, 110, 255)
	p.noFace = true
	head.Color = rgb(6, 4, 10)
	for _, s in { 1, -1 } do
		local g = add(head, V(0.26, 0.09, 0.05), CF(s * 0.24, 0.08, -HH - 0.025) * ANG(0, 0, s * -0.25), glow, NEON)
		g.CastShadow = false
		table.insert(p.eyes, g)
	end
	for _, a in p.arms do
		bareLimb(p, a.part)
		a.part.Color = rgb(20, 16, 26)
		for i = 1, 4 do
			local x = (i - 2.5) * 0.18
			chain(a.part, { V(x, -0.9, -0.2), V(x * 1.2, -1.3, -0.3), V(x * 1.3, -1.6, -0.5) }, 0.08, 0.04, rgb(30, 26, 36), SLATE)
		end
	end
	for _, l in p.legs do
		l.part.Transparency = 1
	end
	for _, part in REG.Feet do
		part.Transparency = 1
	end
	for i = 0, 2 do
		local w = add(p.torso, V(0.3, 1.1, 0.04), CF(-0.6 + i * 0.6, -3.1, (i - 1) * 0.3) * ANG(0.1 * i, 0.4 * i, 0.1), glow, NEON, { Transparency = 0.6, CastShadow = false })
		w.Name = "Wisp"
	end
end

function KIND.fungoid(p, d)
	local head, t = p.head, p.torso
	local capC = d.shirt or rgb(176, 50, 48)
	local spot = rgb(236, 230, 214)
	local gill = rgb(206, 186, 156)
	local stem = p.skin
	local glow = d.glowEye or d.glow or rgb(140, 255, 200)
	p.noFace = true
	t.Color = stem
	for _, l in p.legs do
		l.part.Color = shade(stem, 0.92)
	end
	-- a huge stepped cap sitting low over the head
	box(head, -1.5, 1.5, 0.22, 0.27, -1.5, 1.5, gill)
	box(head, -1.56, 1.56, 0.27, 0.56, -1.56, 1.56, capC)
	box(head, -1.3, 1.3, 0.56, 0.9, -1.3, 1.3, shade(capC, 1.06))
	box(head, -0.96, 0.96, 0.9, 1.16, -0.96, 0.96, shade(capC, 1.1))
	box(head, -0.52, 0.52, 1.16, 1.3, -0.52, 0.52, shade(capC, 1.14))
	for _, sp in { { 0.55, -0.45, 0.9 }, { -0.5, 0.35, 0.9 }, { 0.15, 0.6, 1.16 }, { -0.2, -0.3, 1.16 }, { 0.8, 0.5, 0.56 }, { -0.9, -0.6, 0.56 }, { 0.2, -1.0, 0.56 } } do
		box(head, sp[1] - 0.13, sp[1] + 0.13, sp[3], sp[3] + 0.04, sp[2] - 0.13, sp[2] + 0.13, spot)
	end
	for _, sp in { { 0.8, -1 }, { -0.6, -1 }, { 0.1, 1 }, { -0.9, 1 } } do
		box(head, sp[1] - 0.15, sp[1] + 0.15, 0.34, 0.5, sp[2] * 1.56 - 0.03, sp[2] * 1.56 + 0.03, spot)
	end
	-- three glowing pinprick eyes in the shadow of the cap, a gash of a mouth
	for _, x in { -0.26, 0, 0.26 } do
		local g = box(head, x - 0.05, x + 0.05, 0.02 + math.abs(x) * 0.3, 0.12 + math.abs(x) * 0.3, -HH - 0.04, -HH + 0.02, glow, NEON)
		g.CastShadow = false
		table.insert(p.eyes, g)
	end
	box(head, -0.2, 0.2, -0.36, -0.3, -HH - 0.03, -HH + 0.02, rgb(40, 30, 26))
	-- the ring (annulus) around the stalk's neck
	neckRing(t, 0.9, 1.04, 0.64, 0.14, gill, PLASTIC)
	-- smaller mushrooms and glowing spore sacs growing out of the body
	for i, pt in { { 0.75, 1.0, 0.1 }, { -0.8, 0.95, -0.1 }, { 0.4, 0.3, 0.74 }, { -0.45, -0.4, 0.72 } } do
		local sc = 0.62 - i * 0.08
		box(t, pt[1] - 0.06, pt[1] + 0.06, pt[2] - 0.18, pt[2], pt[3] - 0.06, pt[3] + 0.06, gill)
		box(t, pt[1] - sc / 2, pt[1] + sc / 2, pt[2], pt[2] + 0.16, pt[3] - sc / 2, pt[3] + sc / 2, shade(capC, 0.9))
		box(t, pt[1] - sc / 3, pt[1] + sc / 3, pt[2] + 0.16, pt[2] + 0.24, pt[3] - sc / 3, pt[3] + sc / 3, shade(capC, 1.0))
	end
	for _, pt in { { -0.45, 0.35 }, { 0.5, -0.35 }, { -0.1, -0.72 } } do
		local g = front(t, pt[1] - 0.12, pt[1] + 0.12, pt[2] - 0.12, pt[2] + 0.12, 0, glow, NEON, 0.12)
		g.CastShadow = false
	end
	-- fibrous stalk
	for _, x in { -0.62, -0.2, 0.25, 0.66 } do
		front(t, x - 0.05, x + 0.05, -0.95, 0.85, 0, shade(stem, 0.84), PLASTIC, 0.04)
		back(t, x - 0.05, x + 0.05, -0.95, 0.85, 0, shade(stem, 0.84), PLASTIC, 0.04)
	end
	back(t, -0.5, 0.5, 0.2, 0.9, 0.04, shade(capC, 0.8), PLASTIC, 0.14)
	-- root feet
	for _, l in p.legs do
		for _, x in { -0.35, 0.05, 0.4 } do
			seg(l.part, V(x, -0.85, -0.2), V(x * 1.6, -1.0, -0.62), 0.12, rgb(100, 80, 60), LEA)
		end
	end
	for _, a in p.arms do
		seg(a.part, V(0, -0.9, -0.1), V(a.s * 0.1, -1.25, -0.3), 0.16, rgb(100, 80, 60), LEA)
	end
end

function KIND.imp(p, d)
	local t = p.torso
	local sk = p.skin
	monsterFace(p, d, { fangs = 5, mawTop = -0.2 })
	batWings(t, shade(sk, 0.55), 1.3)
	front(t, -0.6, 0.6, -0.9, 0.1, 0, shade(sk, 1.1), p.skinMat, 0.14)
	claws(p, 3, 0.35, rgb(30, 24, 24))
	for _, part in REG.Feet do
		part:Destroy()
	end
	table.clear(REG.Feet)
	for _, l in p.legs do
		box(l.part, -0.58, 0.58, -1.04, -0.62, -0.62, 0.58, rgb(34, 24, 24), SLATE)
	end
end

function KIND.hellbrute(p, d)
	local t = p.torso
	local sk = p.skin
	local lava = d.glow or rgb(255, 150, 40)
	local plate = rgb(34, 26, 28)
	monsterFace(p, d, { fangs = 4 })
	for _, s in { 1, -1 } do
		seg(t, V(s * 0.2, 0.85, -0.53), V(s * 0.7, 0.3, -0.53), 0.07, lava, NEON, 0.05)
		seg(t, V(s * 0.7, 0.3, -0.53), V(s * 0.3, -0.3, -0.53), 0.07, lava, NEON, 0.05)
		seg(t, V(s * 0.3, -0.3, -0.53), V(s * 0.55, -0.8, -0.53), 0.06, lava, NEON, 0.05)
	end
	for _, a in p.arms do
		local s = a.s
		add(a.part, V(1.5, 0.65, 1.45), CF(s * 0.1, 0.98, 0) * ANG(0, 0, s * 0.2), plate, SLATE)
		for k = 0, 1 do
			spike(a.part, V(s * (0.1 + k * 0.3), 1.28, -0.2 + k * 0.4), V(s * 0.4, 1, 0), 0.6, 0.22, shade(plate, 1.2), SLATE, 2)
		end
		seg(a.part, V(s * 0.52, 0.2, -0.3), V(s * 0.52, -0.5, 0.2), 0.07, lava, NEON, 0.05)
		for k = 0, 2 do
			add(a.part, V(1.34, 0.14, 1.34), CF(0, -0.2 - k * 0.2, 0) * ANG(0, 0, if k % 2 == 0 then 0.15 else -0.15), rgb(70, 64, 62), RUST)
		end
	end
	for _, part in REG.Feet do
		part:Destroy()
	end
	table.clear(REG.Feet)
	for _, l in p.legs do
		box(l.part, -0.58, 0.58, -1.04, -0.62, -0.62, 0.58, rgb(24, 18, 18), SLATE)
		seg(l.part, V(l.s * 0.52, 0.6, -0.2), V(l.s * 0.52, -0.2, 0.2), 0.06, lava, NEON, 0.04)
	end
	backSpikes(t, 4, 0.9, -0.5, 0.7, 0.26, plate, 0.5)
end

function KIND.troll(p, d)
	local head, t = p.head, p.torso
	local sk = p.skin
	local fur = p.hairC
	local ice = d.ice or rgb(170, 220, 255)
	seg(head, V(0, 0.08, -HH + 0.02), V(0, -0.28, -HH - 0.34), 0.26, shade(sk, 0.9), p.skinMat, 0.22)
	for i, pt in { { -0.7, 1.0, 0.2 }, { 0.7, 1.0, 0.2 }, { 0, 0.9, 0.6 }, { -0.4, 0.3, 0.6 }, { 0.4, 0.4, 0.6 } } do
		add(t, V(0.8, 0.55, 0.6), CF(pt[1], pt[2], pt[3]) * ANG(0.3, 0.25 * i, (i % 2 - 0.5) * 0.5), shade(fur, 0.88 + (i % 3) * 0.08), FAB)
	end
	for i, pt in { { 0.3, 0.9, 0.75, 0.3 }, { -0.4, 0.6, 0.75, -0.4 }, { 0.1, 0.1, 0.72, 0.1 } } do
		add(t, V(0.3, 0.9 - i * 0.12, 0.3), CF(pt[1], pt[2], pt[3]) * ANG(0.7, pt[4], 0.3 * i), ice, ICE)
	end
	for _, a in p.arms do
		add(a.part, V(0.34, 0.8, 0.34), CF(a.s * 0.3, 1.25, 0.1) * ANG(0.2, 0, a.s * -0.5), ice, ICE)
		lband(a.part, -1.03, -0.16, A3, shade(sk, 0.94), p.skinMat)
		add(a.part, V(1.3, 0.4, 1.3), CF(0, 0.1, 0) * ANG(0, 0.4, 0.2), shade(fur, 0.9), FAB)
	end
	claws(p, 3, 0.35, rgb(60, 54, 50))
end

function KIND.giant(p, d)
	local head, t = p.head, p.torso
	local sk = t.Color
	local sh = shade(sk, 0.9)
	for _, s in { 1, -1 } do
		front(t, s * 0.06, s * 0.9, 0.28, 0.86, 0, sh, PLASTIC, 0.07)
		sbox(head, s, HH - 0.02, HH + 0.1, -0.12, 0.24, -0.02, 0.22, shade(sk, 0.94))
		seg(t, V(s * 0.1, 0.93, -0.51), V(s * 0.85, 0.97, -0.51), 0.06, shade(sk, 0.85), PLASTIC, 0.04)
	end
	for r = 0, 2 do
		for _, s in { 1, -1 } do
			front(t, s * 0.05, s * 0.36, -0.82 + r * 0.32, -0.56 + r * 0.32, 0, shade(sk, 0.93), PLASTIC, 0.05)
		end
	end
	for _, a in p.arms do
		lband(a.part, 0.5, 1.07, 0.07, shade(sk, 0.96), PLASTIC)
	end
	box(head, -0.11, 0.11, -0.26, 0.04, -HH - 0.14, -HH + 0.02, shade(sk, 0.93))
	box(head, -0.16, 0.16, -0.3, -0.2, -HH - 0.12, -HH + 0.02, shade(sk, 0.88))
	for _, leg in p.legs do
		front(leg.part, -0.32, 0.32, -0.2, 0.12, 0, shade(leg.part.Color, 0.9), PLASTIC, 0.06)
		back(leg.part, -0.34, 0.34, -0.7, -0.1, 0, shade(leg.part.Color, 0.92), PLASTIC, 0.06)
	end
end

-- ------------------------------------------------------------------ extras
local EXTRA = {}
function EXTRA.horns(p, d)
	horns(p.head, rgb(30, 26, 28), true)
end
function EXTRA.wings(p, d)
	batWings(p.torso, rgb(30, 18, 26), 1.6)
end
function EXTRA.eyepatch(p, d)
	local head = p.head
	box(head, 0.12, 0.48, -0.04, 0.24, -HH - 0.06, -HH - 0.02, rgb(15, 15, 15), LEA)
	add(head, V(1.3, 0.05, 1.3), CF(0, 0.22, 0) * ANG(0, 0, 0.32), rgb(20, 20, 20), LEA)
end
function EXTRA.glasses(p, d)
	local head = p.head
	local frame = rgb(24, 22, 22)
	box(head, -0.52, 0.52, 0.19, 0.24, -HH - 0.07, -HH - 0.02, frame)
	for _, s in { 1, -1 } do
		sbox(head, s, 0.1, 0.46, -0.1, 0.19, -HH - 0.05, -HH - 0.02, rgb(180, 220, 240), PLASTIC, { Transparency = 0.55 })
		sbox(head, s, 0.08, 0.48, -0.14, -0.1, -HH - 0.07, -HH - 0.02, frame)
		sbox(head, s, 0.52, 0.56, 0.19, 0.24, -HH - 0.07, 0.1, frame)
	end
end
function EXTRA.headband(p, d)
	local head = p.head
	box(head, -HH - 0.14, HH + 0.14, 0.33, 0.44, -HH - 0.14, HH + 0.14, d.accent or rgb(170, 30, 40), FAB)
	add(head, V(0.2, 0.5, 0.05), CF(0.2, 0.1, HH + 0.2) * ANG(0.2, 0, 0.3), shade(d.accent or rgb(170, 30, 40), 0.85), FAB)
end
function EXTRA.giant(p, d)
	KIND.giant(p, d)
end
function EXTRA.tatters(p, d)
	local t = p.torso
	local c = shade(t.Color, 0.8)
	for i, x in { -0.75, -0.3, 0.15, 0.6 } do
		local ln = 0.35 + (i % 3) * 0.15
		add(t, V(0.3, ln, 0.03), CF(x, -1.52 - ln / 2, -0.5 - T2 - 0.02) * ANG(0, 0, (i % 2 - 0.5) * 0.15), c, FAB)
		add(t, V(0.3, ln * 0.8, 0.03), CF(x + 0.1, -1.52 - ln * 0.4, 0.5 + T2 + 0.02) * ANG(0, 0, (i % 2 - 0.5) * -0.15), c, FAB)
	end
end
function EXTRA.corpse(p, d)
	local head = p.head
	local sk = p.skin
	local frost = rgb(210, 230, 240)
	for _, s in { 1, -1 } do
		sbox(head, s, 0.44, 0.64, -0.42, -0.14, -HH - 0.04, -HH + 0.04, shade(sk, 0.72))
	end
	for _, a in p.arms do
		lband(a.part, 0.72, 1 + A2 + 0.03, A2 + 0.03, frost, ICE)
		chain(a.part, { V(0.2, -0.95, -0.2), V(0.22, -1.2, -0.35) }, 0.07, 0.05, rgb(60, 60, 58), SLATE)
		chain(a.part, { V(-0.2, -0.95, -0.2), V(-0.22, -1.2, -0.35) }, 0.07, 0.05, rgb(60, 60, 58), SLATE)
	end
end
function EXTRA.runes(p, d)
	local t = p.torso
	local g = d.glow or d.accent or rgb(120, 255, 160)
	for _, s in { 1, -1 } do
		local r = front(t, s * 0.62 - 0.03, s * 0.62 + 0.03, -1.65, -0.9, T3 + HALF, g, NEON, 0.02)
		r.CastShadow = false
		front(t, s * 0.62 - 0.1, s * 0.62 + 0.1, -1.3, -1.25, T3 + HALF, g, NEON, 0.02)
	end
end
function EXTRA.bones(p, d)
	local t = p.torso
	local bone = rgb(222, 214, 190)
	box(t, 0.5, 0.82, -1.1, -0.8, -0.5 - T4 - 0.3, -0.5 - T4, bone, BONE)
	box(t, 0.56, 0.64, -1.02, -0.94, -0.5 - T4 - 0.32, -0.5 - T4 - 0.3, rgb(20, 16, 16))
	box(t, 0.68, 0.76, -1.02, -0.94, -0.5 - T4 - 0.32, -0.5 - T4 - 0.3, rgb(20, 16, 16))
	for _, a in p.arms do
		for k = 0, 1 do
			spike(a.part, V(a.s * (0.1 + k * 0.25), 1.1, -0.1 + k * 0.2), V(a.s * 0.3, 1, 0.1), 0.5 - k * 0.12, 0.14, bone, BONE, 1)
		end
	end
end
function EXTRA.chains(p, d)
	local t = p.torso
	local iron = rgb(70, 70, 74)
	for i = 0, 5 do
		add(t, V(0.16, 0.26, 0.06), CF(-0.9 + i * 0.36, 0.6 - i * 0.28, -0.72) * ANG(0, 0, 0.9 + (i % 2) * 0.6), iron, RUST)
	end
end

-- ------------------------------------------------------------------ gear coverage
-- Outfit decos registered per slot hide while armour of that slot is worn.
local function hookGear(model: Model, reg, orig)
	local function sync()
		local cov = {}
		local g = model:FindFirstChild("Gear")
		if g then
			for _, c in g:GetChildren() do
				local s = string.match(c.Name, "^Gear_(%a+)$")
				if s then
					cov[s] = true
				end
			end
		end
		for s, list in reg do
			local hide = cov[s] == true
			local o = orig[s]
			for i, part in list do
				local want = if hide then 1 else o[i]
				if part.Transparency ~= want then
					part.Transparency = want
				end
			end
		end
	end
	model.ChildAdded:Connect(function(c)
		if c.Name == "Gear" then
			c.ChildAdded:Connect(sync)
			sync()
		end
	end)
	model.ChildRemoved:Connect(function(c)
		if c.Name == "Gear" then
			sync()
		end
	end)
	return sync
end

-- ------------------------------------------------------------------ build
export type RigDesc = {
	name: string?,
	race: string?,
	beast: string?,
	monster: string?, -- body plan for enemies: crawler, ghoul, brute, gnasher, hound, werewolf, wraith, fungoid, imp, hellbrute, troll
	skin: Color3?,
	skinMat: Enum.Material?,
	hair: Color3?,
	hairStyle: string?,
	beard: string?,
	shirt: Color3?,
	pants: Color3?,
	shoes: Color3?,
	accent: Color3?,
	outfit: string?,
	mood: string?,
	eye: Color3?,
	glow: Color3?,
	scale: number?,
	hunch: boolean?,
	health: number?,
	walkSpeed: number?,
	blood: string?,
	awakened: boolean?,
	player: boolean?,
	halo: Color3?,
	glowEye: Color3?,
	extras: { string }?,
}

function Rig.build(d: RigDesc): Model
	d = d or {}
	local race = d.race or "Human"
	local outfit = d.outfit or "peasant"
	local skin = d.skin or Palette.skin[2]
	local hairC = d.hair or Palette.hair[2]
	local shirt = d.shirt or Palette.cloth[1]
	local pants = d.pants or Palette.cloth[5]
	local shoesC = d.shoes or rgb(40, 32, 28)

	if race == "Orc" then
		skin = d.skin or rgb(96, 128, 70)
	elseif race == "Goblin" then
		skin = d.skin or rgb(122, 148, 70)
	elseif race == "Demon" then
		skin = d.skin or rgb(140, 34, 40)
	elseif race == "Lizard" then
		skin = d.skin or rgb(70, 128, 96)
	elseif race == "Undead" then
		skin = d.skin or rgb(214, 206, 182)
	elseif race == "Elf" then
		skin = d.skin or rgb(246, 226, 208)
	end
	local und = race == "Undead" or outfit == "skeleton"
	local skinMat = (d :: any).skinMat or (if race == "Monster" or race == "Lizard" then LEA else PLASTIC)

	local model = Instance.new("Model")
	model.Name = d.name or race
	local hrp = limb(model, "HumanoidRootPart", V(2, 2, 1), skin)
	hrp.Transparency = 1
	hrp.CanCollide = false
	hrp.CFrame = CF(0, 3, 0)
	local torso = limb(model, "Torso", V(2, 2, 1), shirt, FAB)
	local head = limb(model, "Head", V(HEAD, HEAD, HEAD), skin, if race == "Monster" then skinMat else PLASTIC)
	local ra = limb(model, "Right Arm", V(1, 2, 1), skin, skinMat)
	local la = limb(model, "Left Arm", V(1, 2, 1), skin, skinMat)
	local rl = limb(model, "Right Leg", V(1, 2, 1), pants, FAB)
	local ll = limb(model, "Left Leg", V(1, 2, 1), pants, FAB)
	local parts = { HumanoidRootPart = hrp, Torso = torso, Head = head, ["Right Arm"] = ra, ["Left Arm"] = la, ["Right Leg"] = rl, ["Left Leg"] = ll }

	for _, jn in Rig.JOINT_ORDER do
		local j = Rig.JOINTS[jn]
		local p0, p1 = parts[j[1]], parts[j[2]]
		p1.CFrame = p0.CFrame * j[3] * j[4]:Inverse()
		local m = Instance.new("Motor6D")
		m.Name = jn
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = j[3]
		m.C1 = j[4]
		m.Parent = p0
	end

	Kit_attach(hrp, "RootAttachment", CFrame.identity)
	Kit_attach(ra, "RightGripAttachment", CF(0, -1, 0) * ANG(-math.pi / 2, 0, 0))
	Kit_attach(la, "LeftGripAttachment", CF(0, -1, 0) * ANG(-math.pi / 2, 0, 0))
	Kit_attach(head, "HatAttachment", CF(0, HEAD / 2, 0))
	Kit_attach(torso, "BodyBackAttachment", CF(0, 0, 0.5))

	local p = {
		hrp = hrp,
		torso = torso,
		head = head,
		ra = ra,
		la = la,
		rl = rl,
		ll = ll,
		arms = { { part = ra, s = 1 }, { part = la, s = -1 } },
		legs = { { part = rl, s = 1 }, { part = ll, s = -1 } },
		skin = skin,
		skinMat = skinMat,
		hairC = hairC,
		race = race,
		outfit = outfit,
		painted = {},
		eyes = {},
		noFace = false,
	}
	-- clothing outfits dress the torso and legs by default; bare bodies keep skin
	if outfit ~= "bare" and outfit ~= "skeleton" then
		p.painted.Torso = true
		p.painted["Right Leg"] = true
		p.painted["Left Leg"] = true
	elseif outfit == "bare" then
		torso.Color = d.shirt or skin
		torso.Material = skinMat
		rl.Color = d.pants or shade(skin, 0.94)
		ll.Color = rl.Color
		rl.Material = skinMat
		ll.Material = skinMat
	end
	local od = {
		shirt = shirt,
		pants = pants,
		shoes = shoesC,
		accent = d.accent,
		awakened = d.awakened,
		glow = d.glow,
		apron = nil,
		strawHat = false,
		blazer = nil,
		jacket = nil,
	}
	for k, v in d :: any do
		if od[k] == nil then
			od[k] = v
		end
	end

	-- outfit (registered per gear slot)
	local reg = {}
	for _, s in Rig.SLOTS do
		reg[s] = {}
	end
	REG = reg
	SLOT = "Chest"
	local fn = OUT[outfit] or OUT.peasant
	local ok, err = pcall(fn, p, od)
	if not ok then
		warn("[Rig] outfit " .. tostring(outfit) .. ": " .. tostring(err))
	end
	SLOT = nil

	-- body plan: skeleton, race features, monster kind
	local kind = d.monster
	local extras = d.extras or {}
	local ok2, err2 = pcall(function()
		if und then
			local B = if race == "Undead" then skin else rgb(214, 206, 182)
			local glow = d.glowEye or d.glow or rgb(120, 200, 255)
			head.Transparency = 1
			p.noFace = true
			skull(p, B, glow)
			if not p.painted.Torso then
				torso.Transparency = 1
				boneTorso(p, B)
			end
			for _, a in p.arms do
				if not p.painted[a.part.Name] then
					a.part.Transparency = 1
					boneArm(p, a.part, a.s, B)
				end
			end
			for _, l in p.legs do
				if not p.painted[l.part.Name] then
					l.part.Transparency = 1
					boneLeg(p, l.part, l.s, B)
				end
			end
		elseif kind and KIND[kind] then
			if race == "Demon" or race == "Orc" or race == "Goblin" then
				RACE[race](p, od)
			end
			KIND[kind](p, od)
		elseif RACE[race] then
			RACE[race](p, od)
		end
	end)
	if not ok2 then
		warn("[Rig] body " .. tostring(race) .. "/" .. tostring(kind) .. ": " .. tostring(err2))
	end
	REG = nil

	-- hair & beard
	local hs = d.hairStyle or "short"
	local covered = outfit == "cultist" or outfit == "cloak" or outfit == "knight" or und or p.noFace and race == "Monster"
	if not covered and kind ~= "fungoid" and kind ~= "wraith" then
		hair(head, hs, hairC)
	end
	if d.beard and not und and outfit ~= "knight" then
		beard(head, d.beard, if d.hair then shade(hairC, 1.05) else hairC, skin)
	end
	if d.halo then
		halo(head, d.halo, 1.0)
	end
	for _, ex in extras :: { string } do
		local f = EXTRA[ex]
		if f and not (ex == "horns" and race == "Demon") then
			local okx, errx = pcall(f, p, od)
			if not okx then
				warn("[Rig] extra " .. ex .. ": " .. tostring(errx))
			end
		end
	end

	-- face
	local glowC = d.glowEye or d.glow
	if not p.noFace then
		local mood = d.mood or "neutral"
		if race == "Undead" then
			mood = "skull"
		end
		Rig.setFace(head, mood, { brow = shade(hairC, 0.8), eye = d.eye, glow = glowC })
		if d.glowEye then
			local e = add(head, V(0.2, 0.2, 0.06), CF(0.28, 0.1, -HEAD / 2 - 0.03), d.glowEye, NEON)
			e.Name = "GlowEye"
			local l = Instance.new("PointLight")
			l.Color = d.glowEye
			l.Range = 8
			l.Brightness = 3
			l.Parent = e
		end
	elseif #p.eyes > 0 then
		if d.glowEye then
			for _, e in p.eyes do
				e.Color = d.glowEye
			end
		end
		p.eyes[1].Name = "GlowEye"
		if d.glowEye or (d.scale and d.scale > 1.5) then
			local l = Instance.new("PointLight")
			l.Color = p.eyes[1].Color
			l.Range = 8
			l.Brightness = 2
			l.Parent = p.eyes[1]
		end
	end

	-- humanoid
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.MaxHealth = d.health or 100
	hum.Health = hum.MaxHealth
	hum.WalkSpeed = d.walkSpeed or 16
	hum.UseJumpPower = true
	hum.JumpPower = 50
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.NameDisplayDistance = 0
	hum.Parent = model

	model.PrimaryPart = hrp
	model:SetAttribute("Race", race)
	model:SetAttribute("Blood", d.blood or (if race == "Monster" then "purple" elseif race == "Undead" then "bone" elseif race == "Goblin" or race == "Lizard" then "green" elseif race == "Demon" then "black" else "red"))
	if d.hunch then
		model:SetAttribute("Hunch", true)
	end
	-- armour hides the outfit pieces it covers (also for gear applied later)
	local orig = {}
	local any = false
	for s, list in reg do
		orig[s] = {}
		for i, part in list do
			orig[s][i] = part.Transparency
			any = true
		end
	end
	local sync = if any then hookGear(model, reg, orig) else nil
	if (d :: any).gear then
		local okg, errg = pcall(function()
			require(script.Parent.Gear).apply(model, (d :: any).gear)
		end)
		if not okg then
			warn("[Rig] gear: " .. tostring(errg))
		end
		if sync then
			sync()
		end
		-- NPC armour never changes: drop what it covers instead of keeping it hidden
		if not d.player then
			for _, list in reg do
				for _, part in list do
					if part.Parent and part.Transparency >= 1 then
						part:Destroy()
					end
				end
			end
			for _, h in head:GetChildren() do
				if h:IsA("BasePart") and h.Name == "Hair" and h:GetAttribute("HiddenByGear") then
					h:Destroy()
				end
			end
		end
	end
	if d.scale and math.abs(d.scale - 1) > 0.01 then
		model:ScaleTo(d.scale)
	end
	CollectionService:AddTag(model, "Rig")
	return model
end

-- Welds a weapon/item model to a hand. The model's PrimaryPart is the grip; blade along +Y.
function Rig.hold(rig: Model, item: Model, hand: string?)
	local arm = rig:FindFirstChild(if hand == "Left" then "Left Arm" else "Right Arm") :: BasePart
	local grip = item.PrimaryPart
	if not arm or not grip then
		return
	end
	for _, d in item:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	local scale = rig:GetScale()
	local w = Instance.new("Weld")
	w.Name = "HandWeld"
	w.Part0 = arm
	w.Part1 = grip
	w.C0 = CF(0, -0.95 * scale, -0.05 * scale) * ANG(-math.pi / 2, 0, 0)
	w.Parent = arm
	if math.abs(scale - 1) > 0.01 then
		item:ScaleTo(scale)
	end
	item.Parent = rig
	return w
end

-- Body-plan builders (Shared/Beasts registers the trait monsters here) and the
-- primitive helpers they use.
Rig.KIND = KIND
Rig.helpers = {
	box = box,
	sbox = sbox,
	seg = seg,
	chain = chain,
	spike = spike,
	curve = curve,
	front = front,
	back = back,
	band = band,
	lband = lband,
	claws = claws,
	toeClaws = toeClaws,
	horns = horns,
	batWings = batWings,
	backSpikes = backSpikes,
	monsterFace = monsterFace,
	shade = shade,
	HH = HH,
}

-- Random look generator for NPCs.
local RACE_SKINS = {
	Goblin = { rgb(122, 148, 70), rgb(104, 132, 62), rgb(136, 150, 84), rgb(96, 120, 70) },
	Orc = { rgb(96, 128, 70), rgb(84, 112, 64), rgb(110, 124, 80), rgb(78, 100, 72), rgb(120, 110, 90) },
	Demon = { rgb(140, 34, 40), rgb(120, 28, 36), rgb(96, 30, 44), rgb(150, 60, 50), rgb(70, 30, 40) },
	Lizard = { rgb(70, 128, 96), rgb(84, 120, 70), rgb(60, 104, 110), rgb(110, 120, 70) },
	Elf = { rgb(246, 226, 208), rgb(236, 210, 186), rgb(214, 186, 160), rgb(180, 150, 130) },
	Monster = { rgb(70, 40, 90), rgb(80, 70, 100), rgb(90, 104, 84), rgb(60, 40, 50), rgb(100, 60, 50) },
}
function Rig.randomLook(rng, race: string?, outfit: string?)
	local r = race or "Human"
	local d: RigDesc = {
		race = r,
		skin = rng:pick(Palette.skin),
		hair = rng:pick(Palette.hair),
		hairStyle = rng:pick({ "short", "short", "long", "messy", "bun", "ponytail", "spiky", "bald", "buzz", "slick", "braids", "topknot", "wild", "undercut" }),
		shirt = rng:pick(Palette.cloth),
		pants = rng:pick(Palette.cloth),
		outfit = outfit or "peasant",
		mood = "neutral",
	}
	if rng:chance(0.35) then
		d.beard = rng:pick({ "full", "goatee", "stubble", "mustache", "braided" })
	end
	local skins = RACE_SKINS[r]
	if skins then
		d.skin = rng:pick(skins)
	end
	if r == "Beastkin" then
		d.beast = rng:pick({ "wolf", "cat", "fox", "rabbit", "bear", "boar" })
	elseif r == "Undead" then
		d.skin = rng:pick({ rgb(214, 206, 182), rgb(200, 192, 168), rgb(222, 216, 198) })
		d.beard = nil
	end
	if r == "Dwarf" then
		d.race = "Human"
		d.beard = rng:pick({ "full", "long" })
		d.scale = 0.8
	end
	return d
end

return Rig
