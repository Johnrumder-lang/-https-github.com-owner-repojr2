--!nonstrict
-- THE RANDOM STORY UI kit (v3): gothic dark-fantasy look built only from frames.
--   * layers: UI.layer(name, order) -> ScreenGui + a "Root" frame whose UIScale maps
--     the 1920x1080 reference layout onto any screen (1280x720 ... 2560x1440+).
--   * ornaments: diamonds, fading hairlines, flourishes, corner brackets, wings.
--   * widgets: panels, text, keycaps + key rows, buttons, souls-style bars.
--   * a tiny alpha animator (UI.fadeIn / fadeOut / fadeTo) that fades whole trees.
-- Nothing here reads ZIndex from a parent (ScreenGuis have none) and every helper
-- tolerates missing children.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local C = require(script.Parent.C)

local UI = {}
local player = Players.LocalPlayer
local COL = Config.Colors
UI.COL = COL
local rgb = Color3.fromRGB

-- ------------------------------------------------------------------ fonts
UI.GOTHIC = Enum.Font.GrenzeGotisch -- display: titles, rank words, boss names
UI.SERIF = Enum.Font.Fondamento -- flavour lines, subtitles
UI.NAME = Enum.Font.Merriweather -- item / speaker names
UI.BODY = Enum.Font.GothamMedium
UI.REG = Enum.Font.Gotham
UI.BOLD = Enum.Font.GothamBold
UI.BLACK = Enum.Font.GothamBlack
UI.PIXEL = Enum.Font.Arcade -- tiny pixel accents only
UI.TITLE = UI.GOTHIC -- legacy alias

-- ------------------------------------------------------------------ scaling
local CFG = Config.UI or {}
local REF_W, REF_H = CFG.refWidth or 1920, CFG.refHeight or 1080
UI.REF = Vector2.new(REF_W, REF_H)
UI.scale = 1
local roots = {}

local function viewport(): Vector2
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(REF_W, REF_H)
	if vp.X < 2 or vp.Y < 2 then
		return Vector2.new(REF_W, REF_H)
	end
	return vp
end
UI.viewport = viewport

local function computeScale(): number
	local vp = viewport()
	local s = math.min(vp.X / REF_W, vp.Y / REF_H)
	if s < 1 then
		s = s ^ (CFG.smallScreenBias or 0.85)
	end
	return math.clamp(s, 0.35, 4)
end
UI.scale = computeScale()

local function applyRoot(r, s: number)
	r.frame.Size = UDim2.fromScale(1 / s, 1 / s)
	r.uiscale.Scale = s
end

-- Screen size in reference ("design") pixels, e.g. 1920x1080 or 2560x1080 on ultrawide.
function UI.designSize(): Vector2
	local vp = viewport()
	return vp / UI.scale
end

function UI.refreshScale(force: boolean?)
	local s = computeScale()
	if not force and math.abs(s - UI.scale) < 0.0005 then
		return
	end
	UI.scale = s
	for i = #roots, 1, -1 do
		local r = roots[i]
		if r.frame.Parent then
			applyRoot(r, s)
		else
			table.remove(roots, i)
		end
	end
end

-- ------------------------------------------------------------------ basics
function UI.new(class: string, props, children)
	local o = Instance.new(class)
	if props then
		for k, v in props do
			if k ~= "Parent" then
				(o :: any)[k] = v
			end
		end
	end
	for _, c in children or {} do
		c.Parent = o
	end
	if props and props.Parent then
		o.Parent = props.Parent
	end
	return o
end

local guis = {}
function UI.screen(name: string, order: number?, ignoreInset: boolean?): ScreenGui
	local g = guis[name]
	if g and g.Parent then
		return g
	end
	local pg = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui")
	g = pg:FindFirstChild(name)
	if not (g and g:IsA("ScreenGui")) then
		g = Instance.new("ScreenGui")
		g.Name = name
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = if ignoreInset == nil then true else ignoreInset
		g.DisplayOrder = order or 1
		g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		g.Parent = pg
	end
	guis[name] = g
	return g
end

-- A full-screen frame scaled from the reference resolution.
function UI.root(parent: Instance, name: string?): Frame
	local s = UI.scale
	local f = UI.new("Frame", { Parent = parent, Name = name or "Root", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1 / s, 1 / s) })
	local sc = UI.new("UIScale", { Parent = f, Name = "Scale", Scale = s })
	table.insert(roots, { frame = f, uiscale = sc })
	return f
end

-- ScreenGui + its scaled root (created once, cached by name).
function UI.layer(name: string, order: number?): (ScreenGui, Frame)
	local g = UI.screen(name, order)
	local r = g:FindFirstChild("Root")
	if not (r and r:IsA("Frame")) then
		r = UI.root(g, "Root")
	end
	return g, r
end

function UI.frame(parent: Instance, props)
	props = props or {}
	return UI.new("Frame", {
		Parent = parent,
		Name = props.Name or "Frame",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = props.color or COL.Ink,
		BackgroundTransparency = if props.t ~= nil then props.t else 1,
		BorderSizePixel = 0,
		Rotation = props.Rotation or 0,
		ClipsDescendants = props.clip or false,
		Visible = if props.Visible == nil then true else props.Visible,
		ZIndex = props.ZIndex or 1,
		LayoutOrder = props.LayoutOrder or 0,
		AutomaticSize = props.auto or Enum.AutomaticSize.None,
	})
end

function UI.text(parent: Instance, text: string, props)
	props = props or {}
	local t = UI.new("TextLabel", {
		Parent = parent,
		Text = text or "",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundTransparency = if props.bgT ~= nil then props.bgT else 1,
		BackgroundColor3 = props.bg or COL.Ink,
		BorderSizePixel = 0,
		TextColor3 = props.color or COL.Bone,
		Font = props.font or UI.BODY,
		TextSize = props.size or 18,
		TextScaled = props.scaled or false,
		TextWrapped = props.wrap ~= false,
		TextXAlignment = props.x or Enum.TextXAlignment.Left,
		TextYAlignment = props.y or Enum.TextYAlignment.Center,
		TextStrokeTransparency = props.strokeT or 1,
		TextStrokeColor3 = props.strokeColor or Color3.new(0, 0, 0),
		RichText = props.rich or false,
		ZIndex = props.ZIndex or 1,
		Name = props.Name or "Text",
		TextTransparency = props.TextTransparency or 0,
		LineHeight = props.lineHeight or 1,
		AutomaticSize = props.auto or Enum.AutomaticSize.None,
		Visible = if props.Visible == nil then true else props.Visible,
		Rotation = props.Rotation or 0,
		LayoutOrder = props.LayoutOrder or 0,
	})
	return t
end

function UI.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?, contextual: boolean?)
	return UI.new("UIStroke", {
		Parent = parent,
		Color = color or COL.Gold,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = if contextual then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Miter,
	})
end

function UI.corner(parent: Instance, px: number?, scale: number?)
	return UI.new("UICorner", { Parent = parent, CornerRadius = UDim.new(scale or 0, px or 4) })
end

function UI.pad(parent: Instance, l: number, r: number?, t: number?, b: number?)
	return UI.new("UIPadding", {
		Parent = parent,
		PaddingLeft = UDim.new(0, l),
		PaddingRight = UDim.new(0, r or l),
		PaddingTop = UDim.new(0, t or l),
		PaddingBottom = UDim.new(0, b or t or l),
	})
end

function UI.list(parent: Instance, pad: number?, horizontal: boolean?, align, valign)
	return UI.new("UIListLayout", {
		Parent = parent,
		Padding = UDim.new(0, pad or 6),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = valign or Enum.VerticalAlignment.Top,
	})
end

function UI.nseq(points): NumberSequence
	local kp = {}
	for _, p in points do
		table.insert(kp, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(kp)
end

function UI.cseq(points): ColorSequence
	local kp = {}
	for _, p in points do
		table.insert(kp, ColorSequenceKeypoint.new(p[1], p[2]))
	end
	return ColorSequence.new(kp)
end

-- colors: nil | Color3 | {Color3, Color3} | {{t, Color3}, ...}; transp: nil | {{t, v}, ...}
function UI.gradient(parent: Instance, colors, transp, rotation: number?)
	local g = Instance.new("UIGradient")
	if typeof(colors) == "Color3" then
		g.Color = ColorSequence.new(colors)
	elseif type(colors) == "table" and #colors > 0 then
		if typeof(colors[1]) == "Color3" then
			g.Color = ColorSequence.new(colors[1], colors[2] or colors[1])
		else
			g.Color = UI.cseq(colors)
		end
	end
	if transp then
		g.Transparency = UI.nseq(transp)
	end
	g.Rotation = rotation or 0
	g.Parent = parent
	return g
end

UI.FADE_BOTH = { { 0, 1 }, { 0.22, 0 }, { 0.78, 0 }, { 1, 1 } }
UI.FADE_RIGHT = { { 0, 0 }, { 0.55, 0 }, { 1, 1 } }
UI.FADE_LEFT = { { 0, 1 }, { 0.45, 0 }, { 1, 0 } }

function UI.tween(o: Instance, t: number, props, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

function UI.measure(text: string, size: number, font: Enum.Font, width: number?): Vector2
	local ok, v = pcall(function()
		return TextService:GetTextSize(text, size, font, Vector2.new(width or 4000, 4000))
	end)
	if ok and typeof(v) == "Vector2" then
		return v
	end
	return Vector2.new(#text * size * 0.55, size)
end

-- ------------------------------------------------------------------ sounds (hooked to Audio)
function UI.sfx(name: string, opts)
	local a = C.Audio
	if type(a) == "table" and type(a.play) == "function" then
		a.play(name, opts)
	end
end
function UI.onHover()
	UI.sfx("Tick", { vol = 0.18, pitch = 1.7, spread = 0.05, ignoreTime = true })
end
function UI.onClick()
	UI.sfx("Click", { vol = 0.6, ignoreTime = true })
end

-- ------------------------------------------------------------------ ornaments
-- Horizontal hairline that fades out at its ends. props: {Size, Position, AnchorPoint,
-- color, thick, fade = "both"|"left"|"right"|"none", t, Name}
function UI.hline(parent: Instance, props)
	props = props or {}
	local f = UI.frame(parent, {
		Name = props.Name or "Line",
		Size = props.Size or UDim2.new(1, 0, 0, props.thick or 1),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		color = props.color or COL.Gold,
		t = props.t or 0,
		LayoutOrder = props.LayoutOrder,
		Visible = props.Visible,
	})
	local fade = props.fade or "both"
	if fade ~= "none" then
		UI.gradient(f, nil, if fade == "left" then UI.FADE_LEFT elseif fade == "right" then UI.FADE_RIGHT else UI.FADE_BOTH, 0)
	end
	return f
end

function UI.vline(parent: Instance, props)
	props = props or {}
	local f = UI.frame(parent, {
		Name = props.Name or "VLine",
		Size = props.Size or UDim2.new(0, props.thick or 1, 1, 0),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		color = props.color or COL.Gold,
		t = props.t or 0,
	})
	local fade = props.fade or "both"
	if fade ~= "none" then
		UI.gradient(f, nil, if fade == "top" then UI.FADE_LEFT elseif fade == "bottom" then UI.FADE_RIGHT else UI.FADE_BOTH, 90)
	end
	return f
end

-- A diamond (square rotated 45°). side = square side in px; visual height = side * 1.41.
-- props: {color, t, stroke, strokeT, thick, inner (Color3), innerT, Name, AnchorPoint}
function UI.diamond(parent: Instance, side: number, pos: UDim2, props)
	props = props or {}
	local d = UI.frame(parent, {
		Name = props.Name or "Diamond",
		Size = UDim2.fromOffset(side, side),
		Position = pos,
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		color = props.color or COL.Gold,
		t = if props.t ~= nil then props.t else 0,
		Rotation = 45,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
	})
	if props.stroke then
		UI.stroke(d, props.stroke, props.thick or 1, props.strokeT or 0)
	end
	if props.inner then
		local s = math.max(2, math.floor(side * (props.innerScale or 0.45)))
		UI.frame(d, { Name = "Inner", Size = UDim2.fromOffset(s, s), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), color = props.inner, t = props.innerT or 0 })
	end
	return d
end

-- Ornamental divider:  ——·—— ◇ ——·——   (or a one-sided version for left-aligned layouts)
-- props: {color, AnchorPoint, side = "left" (diamond at the left end), t, Name, dots}
function UI.flourish(parent: Instance, width: number, pos: UDim2, props)
	props = props or {}
	local col = props.color or COL.Gold
	local h = 16
	local holder = UI.frame(parent, { Name = props.Name or "Flourish", Size = UDim2.fromOffset(width, h), Position = pos, AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5), LayoutOrder = props.LayoutOrder })
	local t = props.t or 0
	if props.side == "left" then
		UI.diamond(holder, 7, UDim2.new(0, 5, 0.5, 0), { color = col, t = t })
		UI.diamond(holder, 3, UDim2.new(0, 16, 0.5, 0), { color = col, t = t })
		UI.hline(holder, { Size = UDim2.new(1, -24, 0, 1), Position = UDim2.new(0, 24, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), color = col, fade = "right", t = t })
		UI.hline(holder, { Size = UDim2.new(0.45, -24, 0, 1), Position = UDim2.new(0, 24, 0.5, 3), AnchorPoint = Vector2.new(0, 0.5), color = col, fade = "right", t = math.min(1, t + 0.45) })
		return holder
	end
	UI.diamond(holder, 8, UDim2.fromScale(0.5, 0.5), { color = col, t = t, inner = COL.Ink, innerScale = 0.35 })
	UI.diamond(holder, 3, UDim2.new(0.5, -14, 0.5, 0), { color = col, t = t })
	UI.diamond(holder, 3, UDim2.new(0.5, 14, 0.5, 0), { color = col, t = t })
	UI.hline(holder, { Size = UDim2.new(0.5, -22, 0, 1), Position = UDim2.new(0.5, -22, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), color = col, fade = "left", t = t })
	UI.hline(holder, { Size = UDim2.new(0.5, -22, 0, 1), Position = UDim2.new(0.5, 22, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), color = col, fade = "right", t = t })
	if props.dots ~= false then
		UI.diamond(holder, 4, UDim2.new(0.18, 0, 0.5, 0), { color = col, t = math.min(1, t + 0.3) })
		UI.diamond(holder, 4, UDim2.new(0.82, 0, 0.5, 0), { color = col, t = math.min(1, t + 0.3) })
	end
	return holder
end

-- Gothic corner brackets on a frame (8 thin frames). Returns the holder.
function UI.brackets(parent: Instance, color: Color3?, len: number?, thick: number?, inset: number?, t: number?)
	local col = color or COL.Gold
	local L, T, I = len or 12, thick or 1, inset or -3
	local h = UI.frame(parent, { Name = "Brackets", Size = UDim2.new(1, -2 * I, 1, -2 * I), Position = UDim2.fromOffset(I, I) })
	local tr = t or 0
	for _, c in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
		local a = Vector2.new(c[1], c[2])
		UI.frame(h, { Name = "H", Size = UDim2.fromOffset(L, T), Position = UDim2.fromScale(c[1], c[2]), AnchorPoint = a, color = col, t = tr })
		UI.frame(h, { Name = "V", Size = UDim2.fromOffset(T, L), Position = UDim2.fromScale(c[1], c[2]), AnchorPoint = a, color = col, t = tr })
	end
	return h
end

-- Feathered wing: n thin strokes fanning out from `origin` (offset px inside parent).
-- dir = -1 fans to the left, 1 to the right; spread in degrees; returns the holder.
function UI.wing(parent: Instance, origin: Vector2, dir: number, props)
	props = props or {}
	local col = props.color or COL.Gold
	local n = props.n or 4
	local len = props.len or 46
	local base = props.angle or -20 -- degrees above the horizontal
	local spread = props.spread or 16
	local h = UI.frame(parent, { Name = props.Name or "Wing", Size = UDim2.fromScale(1, 1) })
	for i = 1, n do
		local l = len * (1 - (i - 1) * 0.16)
		local a = math.rad(base - (i - 1) * spread)
		-- screen space: +x right, +y down; dir mirrors horizontally
		local dx, dy = math.cos(a) * dir, math.sin(a)
		local cx, cy = origin.X + dx * (l / 2 + (props.gap or 6)), origin.Y + dy * (l / 2 + (props.gap or 6))
		local rot = math.deg(math.atan2(dy, dx))
		local f = UI.frame(h, { Name = "Feather", Size = UDim2.fromOffset(l, props.thick or 2), Position = UDim2.fromOffset(cx, cy), AnchorPoint = Vector2.new(0.5, 0.5), color = col, t = props.t or 0, Rotation = rot })
		UI.gradient(f, nil, if dir > 0 then { { 0, 0 }, { 0.6, 0.1 }, { 1, 1 } } else { { 0, 1 }, { 0.4, 0.1 }, { 1, 0 } }, 0)
	end
	return h
end

-- Dark translucent panel with a hairline gold edge and corner brackets.
-- props: {color, t, edge, edgeT, brackets, bracketColor, Name, AnchorPoint, shade, clip}
function UI.panel(parent: Instance, size: UDim2, pos: UDim2, props)
	props = props or {}
	local f = UI.frame(parent, {
		Name = props.Name or "Panel",
		Size = size,
		Position = pos,
		AnchorPoint = props.AnchorPoint,
		color = props.color or COL.Ink2,
		t = if props.t ~= nil then props.t else (props.transparency or 0.14),
		clip = props.clip,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
		Visible = props.Visible,
	})
	if props.shade ~= false then
		UI.gradient(f, { Color3.new(1, 1, 1), rgb(150, 150, 150) }, nil, 90)
	end
	if props.edge ~= false then
		UI.stroke(f, if typeof(props.edge) == "Color3" then props.edge else COL.Gold, props.edgeSize or 1, props.edgeT or 0.62)
	end
	if props.brackets ~= false then
		UI.brackets(f, props.bracketColor or COL.Gold, props.bracketLen or 12, 1, -4, props.bracketT or 0.15)
	end
	return f, f
end

-- Big gothic display text with a vertical gradient, crisp outline and drop shadow.
-- props: UI.text props + {from, to, mid, outline, outlineT, shadow}
function UI.display(parent: Instance, text: string, props)
	props = props or {}
	props.font = props.font or UI.GOTHIC
	local holder = UI.frame(parent, { Name = props.Name or "Display", Size = props.Size or UDim2.fromScale(1, 1), Position = props.Position, AnchorPoint = props.AnchorPoint, LayoutOrder = props.LayoutOrder, Visible = props.Visible })
	local sub = table.clone(props)
	sub.Size = UDim2.fromScale(1, 1)
	sub.Position = UDim2.new()
	sub.AnchorPoint = Vector2.zero
	sub.Name = "Text"
	sub.Visible = true
	sub.Rotation = 0
	sub.LayoutOrder = 0
	if props.shadow ~= false then
		local sh = table.clone(sub)
		sh.Name = "Shadow"
		sh.Position = UDim2.fromOffset(props.shadowX or 3, props.shadowY or 5)
		sh.color = Color3.new(0, 0, 0)
		sh.TextTransparency = props.shadowT or 0.45
		sh.rich = props.rich
		UI.text(holder, text, sh)
	end
	local t = UI.text(holder, text, sub)
	if props.from then
		if props.mid then
			UI.gradient(t, { { 0, props.from }, { props.midAt or 0.5, props.mid }, { 1, props.to or props.mid } }, nil, 90)
		else
			UI.gradient(t, { props.from, props.to or props.from }, nil, 90)
		end
	end
	if props.outline ~= false then
		UI.stroke(t, props.outline or rgb(8, 4, 6), props.outlineSize or 1.5, props.outlineT or 0.2, true)
	end
	return holder, t
end

function UI.setDisplayText(holder: Instance, text: string)
	if not holder then
		return
	end
	for _, c in holder:GetChildren() do
		if c:IsA("TextLabel") then
			c.Text = text
		end
	end
end

-- ------------------------------------------------------------------ keycaps
-- props: {h (height), size (text size), light (bone cap with dark text), Name, LayoutOrder}
function UI.keycap(parent: Instance, key: string, pos: UDim2?, props)
	props = props or {}
	local h = props.h or 26
	local light = props.light == true
	local k = UI.text(parent, string.upper(key or "?"), {
		Name = props.Name or "Key",
		Size = UDim2.fromOffset(h, h),
		Position = pos or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		font = UI.BOLD,
		size = props.size or math.floor(h * 0.5),
		color = if light then COL.Ink else COL.Bone,
		x = Enum.TextXAlignment.Center,
		wrap = false,
		auto = Enum.AutomaticSize.X,
		bgT = 0.05,
		bg = if light then COL.Bone else COL.Ink3,
		LayoutOrder = props.LayoutOrder,
	})
	local px = math.max(5, math.floor(h * 0.26))
	UI.pad(k, px, nil, 0, 2)
	UI.stroke(k, if light then COL.GoldBright else COL.Bone, 1, if light then 0.2 else 0.55)
	UI.frame(k, { Name = "Base", Size = UDim2.new(1, px * 2, 0, 2), Position = UDim2.new(0, -px, 1, 2), AnchorPoint = Vector2.new(0, 1), color = if light then COL.GoldDeep else COL.Gold, t = if light then 0 else 0.35 })
	return k
end

-- Row of {key, label} pairs: [W A S D] move   [SPACE] jump ...
-- props: {h, size, gap, color, Name, Position, AnchorPoint, align}
function UI.keyRow(parent: Instance, pairs_, props)
	props = props or {}
	local h = props.h or 24
	local row = UI.frame(parent, {
		Name = props.Name or "KeyRow",
		Size = UDim2.fromOffset(0, h + 4),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		auto = Enum.AutomaticSize.X,
		LayoutOrder = props.LayoutOrder,
	})
	local lay = UI.list(row, props.gap or 22, true, props.align, Enum.VerticalAlignment.Center)
	lay.VerticalAlignment = Enum.VerticalAlignment.Center
	for i, p in pairs_ do
		local pair = UI.frame(row, { Name = "Pair", Size = UDim2.fromOffset(0, h + 4), auto = Enum.AutomaticSize.X, LayoutOrder = i })
		local pl = UI.list(pair, 7, true, nil, Enum.VerticalAlignment.Center)
		pl.VerticalAlignment = Enum.VerticalAlignment.Center
		local keys = if type(p[1]) == "table" then p[1] else { p[1] }
		for j, k in keys do
			UI.keycap(pair, k, nil, { h = h, light = props.light, LayoutOrder = j })
		end
		UI.text(pair, string.upper(p[2] or ""), {
			Name = "Label",
			Size = UDim2.fromOffset(0, h),
			auto = Enum.AutomaticSize.X,
			wrap = false,
			font = UI.BOLD,
			size = props.size or math.floor(h * 0.54),
			color = props.color or COL.BoneDim,
			strokeT = props.strokeT or 1,
			LayoutOrder = 50,
		})
	end
	return row
end

-- ------------------------------------------------------------------ buttons
-- kinds: "menu" (left aligned title-screen item), "primary" (blood red call to action),
-- "box" (default small boxed button), "ghost" (text only), "tab" (underlined tab).
-- Returns (TextButton, TextButton, api) where api = {set(selected), enable(on), text(s)}.
function UI.button(parent: Instance, text: string, size: UDim2, pos: UDim2, onClick, props)
	props = props or {}
	local kind = props.kind or "box"
	local b = UI.new("TextButton", {
		Parent = parent,
		Name = props.Name or text,
		Text = text,
		Size = size,
		Position = pos or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Font = props.font or (if kind == "primary" then UI.BLACK else UI.BOLD),
		TextSize = props.textSize or (if kind == "menu" then 21 elseif kind == "primary" then 22 else 16),
		TextColor3 = props.textColor or COL.Bone,
		TextXAlignment = if kind == "menu" then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		TextWrapped = false,
		RichText = props.rich or false,
		BackgroundColor3 = props.color or (if kind == "primary" then COL.Blood else COL.Ink),
		BackgroundTransparency = if kind == "ghost" or kind == "tab" then 1 elseif kind == "menu" then 0.45 elseif kind == "primary" then 0.05 else 0.25,
		LayoutOrder = props.LayoutOrder or 0,
		Visible = if props.Visible == nil then true else props.Visible,
		ZIndex = props.ZIndex or 1,
		Selectable = true,
	})
	local api: any = { button = b, selected = false, enabled = true }
	local stroke, accent, bullet, label, hl, under
	local baseT = b.BackgroundTransparency
	if kind == "menu" then
		-- the button keeps its Text (for input/tests) but draws it through a child label so
		-- the red selection gradient never tints the letters
		b.TextTransparency = 1
		stroke = UI.stroke(b, COL.Bone, 1, 0.86)
		hl = UI.frame(b, { Name = "Highlight", color = COL.Blood, t = 0.3, Visible = false, ZIndex = 1 })
		UI.gradient(hl, nil, { { 0, 0 }, { 0.7, 0.75 }, { 1, 1 } }, 0)
		accent = UI.frame(b, { Name = "Accent", Size = UDim2.new(0, 3, 1, 0), color = COL.BloodBright, t = 0, Visible = false, ZIndex = 2 })
		bullet = UI.diamond(b, 6, UDim2.new(0, 16, 0.5, 0), { color = COL.GoldBright, Name = "Bullet", ZIndex = 2 })
		bullet.Visible = false
		label = UI.text(b, text, { Name = "Label", Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(26, 0), font = b.Font, size = b.TextSize, color = props.textColor or COL.Bone, wrap = false, ZIndex = 3 })
		api.label = label
	elseif kind == "primary" then
		stroke = UI.stroke(b, COL.Gold, 1, 0.25)
		UI.gradient(b, { rgb(255, 255, 255), rgb(150, 150, 150) }, nil, 90)
		UI.brackets(b, COL.GoldBright, 8, 1, -4, 0.2)
	elseif kind == "tab" then
		under = UI.frame(b, { Name = "Under", Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1), color = COL.Blood, t = 0, Visible = false })
	elseif kind == "box" then
		stroke = UI.stroke(b, props.edge or COL.Gold, 1, 0.6)
	end
	if props.hint then
		UI.text(b, props.hint, { Name = "Hint", Size = UDim2.new(0, 160, 1, 0), Position = UDim2.new(1, -16, 0, 0), AnchorPoint = Vector2.new(1, 0), font = UI.BOLD, size = 12, color = COL.BoneFaint, x = Enum.TextXAlignment.Right, ZIndex = 3 })
	end
	local hover = false
	local function paint()
		local on = (api.selected or hover) and api.enabled
		if kind == "menu" then
			accent.Visible = on
			bullet.Visible = on
			hl.Visible = on
			b.BackgroundTransparency = baseT
			stroke.Color = if on then COL.BloodBright else COL.Bone
			stroke.Transparency = if on then 0.3 else 0.86
			label.TextColor3 = if not api.enabled then COL.BoneFaint elseif on then Color3.new(1, 1, 1) else (props.textColor or COL.Bone)
			UI.tween(label, 0.12, { Position = UDim2.fromOffset(if on then 36 else 26, 0) })
		elseif kind == "primary" then
			b.BackgroundColor3 = if not api.enabled then COL.Ink3 elseif on then COL.BloodBright else (props.color or COL.Blood)
			stroke.Transparency = if on then 0 else 0.25
			b.TextColor3 = if api.enabled then COL.Bone else COL.BoneFaint
		elseif kind == "tab" then
			under.Visible = api.selected
			b.TextColor3 = if api.selected then COL.Bone elseif hover then COL.BoneDim else COL.BoneFaint
		elseif kind == "ghost" then
			b.TextColor3 = if on then COL.Bone else (props.textColor or COL.BoneDim)
		else
			b.BackgroundColor3 = if on then (props.hover or COL.BloodDeep) else (props.color or COL.Ink)
			stroke.Transparency = if on then 0.1 else 0.6
			stroke.Color = if on then COL.GoldBright else (props.edge or COL.Gold)
			b.TextColor3 = if not api.enabled then COL.BoneFaint else (props.textColor or COL.Bone)
		end
	end
	api.paint = paint
	function api.set(on: boolean)
		api.selected = on
		paint()
	end
	function api.enable(on: boolean)
		api.enabled = on
		paint()
	end
	function api.text(s: string)
		b.Text = s
		if label then
			label.Text = s
		end
	end
	b.MouseEnter:Connect(function()
		hover = true
		paint()
		if api.enabled then
			UI.onHover()
		end
		if props.onHover then
			props.onHover()
		end
	end)
	b.MouseLeave:Connect(function()
		hover = false
		paint()
	end)
	b.MouseButton1Click:Connect(function()
		if not api.enabled and not props.clickDisabled then
			return
		end
		UI.onClick()
		if onClick then
			onClick()
		end
	end)
	paint()
	return b, b, api
end

-- ------------------------------------------------------------------ bars
-- Souls-style bar: back, damage trail, gradient fill, hairline frame, diamond end caps.
-- props: {Size, Position, AnchorPoint, fill = {top, bottom}, back, trail, frame, frameT,
--         caps, segments, Name}.  bar:set(frac) each frame, bar:update(dt) animates the trail.
function UI.soulsBar(parent: Instance, props)
	props = props or {}
	local holder = UI.frame(parent, {
		Name = props.Name or "Bar",
		Size = props.Size or UDim2.fromOffset(300, 14),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		color = props.back or rgb(22, 8, 10),
		t = props.backT or 0.12,
	})
	if props.frame ~= false then
		UI.stroke(holder, props.frame or COL.Gold, 1, props.frameT or 0.35)
	end
	local trail = UI.frame(holder, { Name = "Trail", Size = UDim2.fromScale(1, 1), color = props.trail or rgb(236, 206, 150), t = props.trailT or 0.1 })
	local fill = UI.frame(holder, { Name = "Fill", Size = UDim2.fromScale(1, 1), color = Color3.new(1, 1, 1), t = 0 })
	local fc = props.fill or { rgb(214, 44, 46), rgb(118, 12, 20) }
	local fillGrad = UI.gradient(fill, { fc[1], fc[2] }, nil, 90)
	-- glossy highlight on the top third
	UI.frame(fill, { Name = "Gloss", Size = UDim2.new(1, 0, 0.3, 0), color = Color3.new(1, 1, 1), t = 0.82 })
	local seg = props.segments or 0
	for i = 1, seg - 1 do
		UI.frame(holder, { Name = "Seg", Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromScale(i / seg, 0), color = Color3.new(0, 0, 0), t = 0.45 })
	end
	if props.caps ~= false then
		local capCol = props.capColor or COL.Gold
		UI.diamond(holder, props.capSize or 8, UDim2.new(0, -1, 0.5, 0), { color = COL.Ink, stroke = capCol, strokeT = 0.1, inner = capCol, innerScale = 0.4, Name = "CapL" })
		UI.diamond(holder, props.capSize or 8, UDim2.new(1, 1, 0.5, 0), { color = COL.Ink, stroke = capCol, strokeT = 0.1, inner = capCol, innerScale = 0.4, Name = "CapR" })
	end
	local bar: any = { holder = holder, fill = fill, trail = trail, value = 1, trailValue = 1, hold = 0, fillGrad = fillGrad }
	function bar:set(f: number, instant: boolean?)
		f = math.clamp(f or 0, 0, 1)
		if f ~= f then
			f = 0
		end
		if instant then
			self.trailValue = f
		elseif f < self.value - 0.0005 then
			self.hold = props.hold or 0.5
		elseif f > self.trailValue then
			self.trailValue = f
		end
		self.value = f
		fill.Size = UDim2.fromScale(f, 1)
		trail.Size = UDim2.fromScale(self.trailValue, 1)
	end
	function bar:update(dt: number)
		if self.trailValue > self.value then
			if self.hold > 0 then
				self.hold -= dt
			else
				local gap = self.trailValue - self.value
				self.trailValue = math.max(self.value, self.trailValue - math.max(0.18, gap * 2.8) * dt)
				trail.Size = UDim2.fromScale(self.trailValue, 1)
			end
		end
	end
	function bar:colors(top: Color3, bottom: Color3)
		fillGrad.Color = ColorSequence.new(top, bottom)
	end
	return bar
end

-- Legacy API: returns set(frac), holder, fill.
function UI.bar(parent: Instance, size: UDim2, pos: UDim2, color: Color3, back: Color3, segments: number?)
	local b = UI.soulsBar(parent, { Size = size, Position = pos, fill = { color, Color3.new(color.R * 0.6, color.G * 0.6, color.B * 0.6) }, back = back, segments = segments })
	return function(f)
		b:set(f)
	end, b.holder, b.fill
end

-- ------------------------------------------------------------------ alpha animator
-- Fades a whole subtree by scaling every transparency toward 1. The fully visible
-- state is captured the first time a tree is faded (UI.recapture after rebuilding it).
local baseOf = setmetatable({}, { __mode = "k" })
local alphaOf = setmetatable({}, { __mode = "k" })
local fades = {}

local function capture(root: Instance)
	local base = {}
	local function cap(o)
		local e = nil
		if o:IsA("GuiObject") then
			e = { BackgroundTransparency = o.BackgroundTransparency }
			if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
				e.TextTransparency = o.TextTransparency
				e.TextStrokeTransparency = o.TextStrokeTransparency
			elseif o:IsA("ImageLabel") or o:IsA("ImageButton") then
				e.ImageTransparency = o.ImageTransparency
			end
		elseif o:IsA("UIStroke") then
			e = { Transparency = o.Transparency }
		end
		if e then
			base[o] = e
		end
	end
	cap(root)
	for _, d in root:GetDescendants() do
		cap(d)
	end
	baseOf[root] = base
	return base
end

-- Only call while the tree is fully visible (its current values become the base).
function UI.recapture(root: Instance)
	baseOf[root] = nil
	alphaOf[root] = nil
end

function UI.setAlpha(root: Instance, a: number)
	local base = baseOf[root] or capture(root)
	a = math.clamp(a, 0, 1)
	for o, e in base do
		for k, v in e do
			(o :: any)[k] = 1 - (1 - v) * a
		end
	end
	alphaOf[root] = a
end

function UI.alpha(root: Instance): number
	local a = alphaOf[root]
	return if a == nil then 1 else a
end

function UI.fadeTo(root: Instance, target: number, duration: number?, onDone)
	if not root then
		return
	end
	local cur = UI.alpha(root)
	local dur = duration or 0.3
	if dur <= 0 or math.abs(cur - target) < 0.001 then
		UI.setAlpha(root, target)
		fades[root] = nil
		if onDone then
			task.spawn(onDone)
		end
		return
	end
	fades[root] = { from = cur, to = target, t = 0, dur = dur, done = onDone }
end

function UI.fadeIn(root: any, duration: number?)
	if not root then
		return
	end
	if not root.Visible or alphaOf[root] == nil then
		UI.setAlpha(root, 0)
	end
	root.Visible = true
	UI.fadeTo(root, 1, duration or 0.3)
end

function UI.fadeOut(root: any, duration: number?, destroy: boolean?)
	if not root then
		return
	end
	if not root.Visible then
		if destroy then
			root:Destroy()
		end
		return
	end
	UI.fadeTo(root, 0, duration or 0.3, function()
		if UI.alpha(root) <= 0.001 and fades[root] == nil then
			if destroy then
				root:Destroy()
			else
				root.Visible = false
			end
		end
	end)
end

function UI.isFading(root: Instance): boolean
	return fades[root] ~= nil
end

-- Kinetic "slam": text drops in from a big scale with a punch. Needs a UIScale child.
function UI.slam(o: any, from: number?, t: number?)
	local sc = o:FindFirstChild("Slam") or UI.new("UIScale", { Parent = o, Name = "Slam" })
	sc.Scale = from or 2.2
	UI.tween(sc, t or 0.28, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	if o:IsA("TextLabel") or o:IsA("TextButton") then
		o.TextTransparency = 1
		UI.tween(o, (t or 0.28) * 0.6, { TextTransparency = 0 })
	end
	return sc
end

RunService.RenderStepped:Connect(function(dt)
	UI.refreshScale()
	for root, f in fades do
		if not root.Parent then
			fades[root] = nil
			continue
		end
		f.t += dt
		local k = math.clamp(f.t / f.dur, 0, 1)
		local e = k * k * (3 - 2 * k)
		UI.setAlpha(root, f.from + (f.to - f.from) * e)
		if k >= 1 then
			fades[root] = nil
			if f.done then
				task.spawn(f.done)
			end
		end
	end
end)

function UI.init()
	UI.refreshScale(true)
end

return UI
