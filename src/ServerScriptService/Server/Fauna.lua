--!nonstrict
-- Farm animals in the cubic style: cows, sheep, pigs, goats, horses, chickens,
-- geese, rabbits. The server only builds them (anchored, tagged "Critter");
-- every client animates the ones near it (Client/Critters: grazing, wandering
-- inside their pen, walking legs, pecking heads, wagging tails).
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Kit = require(Shared.Kit)
local Palette = require(Shared.Palette)

local Fauna = {}
local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB
local M = Enum.Material

Fauna.KINDS = { "cow", "sheep", "pig", "goat", "horse", "chicken", "goose", "rabbit" }
Fauna.SMALL = { "chicken", "piglet", "lamb", "goose", "rabbit", "duckling", "cat", "kid" }

local function part(m, name, size, cf, color, mat)
	local p = Kit.deco(m, size, cf, color, mat or M.SmoothPlastic)
	p.Name = name
	if size.X * size.Y * size.Z < 2 then
		p.CastShadow = false
	end
	return p
end

-- A four-legged body plan. d = {len, w, h, legH, legW, head, neck, color, belly, face, tail, horns, spots, wool, snout, mane}
local function quad(m, base: CFrame, d)
	local legH = d.legH
	local bodyY = legH + d.h / 2
	local body = part(m, "Body", V(d.w, d.h, d.len), base * CF(0, bodyY, 0), d.color, d.mat)
	if d.wool then
		part(m, "Wool", V(d.w + 0.5, d.h + 0.4, d.len + 0.3), base * CF(0, bodyY + 0.1, 0), d.wool, M.Fabric)
	end
	if d.belly then
		part(m, "Belly", V(d.w * 0.8, 0.2, d.len * 0.7), base * CF(0, legH + 0.05, 0), d.belly)
	end
	if d.spots then
		for i = 1, 3 do
			local sx = (i % 2 == 0) and 1 or -1
			part(m, "Spot", V(0.06, d.h * 0.5, d.len * 0.25), base * CF(sx * (d.w / 2 + 0.02), bodyY + (i - 2) * 0.2, (i - 2) * d.len * 0.3), d.spots)
		end
	end
	-- legs (pivot = top of the leg; the client swings them about it)
	local lx, lz = d.w / 2 - d.legW / 2, d.len / 2 - d.legW / 2 - 0.1
	for i, o in { { -lx, -lz }, { lx, -lz }, { -lx, lz }, { lx, lz } } do
		local leg = part(m, "Leg" .. i, V(d.legW, legH, d.legW), base * CF(o[1], legH / 2, o[2]), d.legColor or Palette.shade(d.color, 0.85))
		leg:SetAttribute("Pivot", legH / 2)
		part(m, "Hoof" .. i, V(d.legW + 0.04, 0.25, d.legW + 0.04), base * CF(o[1], 0.12, o[2]), d.hoof or rgb(40, 34, 30)).Name = "Hoof" .. i
	end
	-- neck + head at the front (-Z)
	local hs = d.head
	local neck = d.neck or 0
	local headCF = base * CF(0, bodyY + d.h * 0.25 + neck * 0.6, -d.len / 2 - hs.Z / 2 + 0.2 - neck * 0.3)
	if neck > 0 then
		part(m, "Neck", V(hs.X * 0.7, neck + 0.4, hs.X * 0.7), base * CF(0, bodyY + d.h * 0.1 + neck * 0.3, -d.len / 2 + 0.1) * CFrame.Angles(0.5, 0, 0), d.color, d.mat)
	end
	local head = part(m, "Head", hs, headCF, d.headColor or d.color, d.mat)
	head:SetAttribute("Pivot", hs.Z / 2)
	if d.snout then
		part(m, "Snout", V(hs.X * 0.7, hs.Y * 0.45, 0.35), headCF * CF(0, -hs.Y * 0.2, -hs.Z / 2 - 0.15), d.snout)
	end
	for _, sx in { -1, 1 } do
		part(m, "Eye", V(0.14, 0.14, 0.06), headCF * CF(sx * hs.X * 0.3, hs.Y * 0.18, -hs.Z / 2 - 0.02), rgb(20, 18, 18))
		part(m, "Ear", V(0.4, 0.14, 0.26), headCF * CF(sx * (hs.X / 2 + 0.15), hs.Y * 0.35, hs.Z * 0.15), d.earColor or d.color)
		if d.horns then
			part(m, "Horn", V(0.14, 0.55, 0.14), headCF * CF(sx * hs.X * 0.3, hs.Y / 2 + 0.25, hs.Z * 0.1) * CFrame.Angles(0, 0, -sx * 0.4), d.horns)
		end
	end
	if d.mane then
		part(m, "Mane", V(0.3, 0.5, d.len * 0.5), base * CF(0, bodyY + d.h / 2 + 0.2, -d.len * 0.25), d.mane)
	end
	if d.tail then
		local tail = part(m, "Tail", V(0.2, d.tail, 0.2), base * CF(0, bodyY + d.h * 0.2 - d.tail / 2, d.len / 2 + 0.1), d.tailColor or Palette.shade(d.color, 0.8))
		tail:SetAttribute("Pivot", d.tail / 2)
	end
end

local function bird(m, base: CFrame, d)
	local body = part(m, "Body", V(d.w, d.h, d.len), base * CF(0, d.legH + d.h / 2, 0), d.color)
	part(m, "Wing", V(d.w + 0.1, d.h * 0.6, d.len * 0.7), base * CF(0, d.legH + d.h * 0.55, 0.05), Palette.shade(d.color, 0.9))
	local headCF = base * CF(0, d.legH + d.h + d.head.Y * 0.3 + (d.neck or 0), -d.len / 2 + d.head.Z / 2)
	if d.neck then
		part(m, "Neck", V(d.head.X * 0.7, d.neck + 0.2, d.head.X * 0.7), base * CF(0, d.legH + d.h + d.neck / 2, -d.len / 2 + d.head.Z / 2), d.color)
	end
	local head = part(m, "Head", d.head, headCF, d.color)
	head:SetAttribute("Pivot", d.head.Y / 2 + (d.neck or 0))
	part(m, "Beak", V(d.head.X * 0.5, d.head.Y * 0.3, 0.3), headCF * CF(0, -0.02, -d.head.Z / 2 - 0.12), d.beak)
	if d.comb then
		part(m, "Comb", V(0.1, 0.22, d.head.Z * 0.7), headCF * CF(0, d.head.Y / 2 + 0.1, 0), d.comb)
	end
	for _, sx in { -1, 1 } do
		part(m, "Eye", V(0.08, 0.08, 0.08), headCF * CF(sx * d.head.X / 2, d.head.Y * 0.15, -d.head.Z * 0.2), rgb(20, 18, 18))
	end
	for i, sx in { -1, 1 } do
		local leg = part(m, "Leg" .. i, V(0.1, d.legH, 0.1), base * CF(sx * d.w * 0.22, d.legH / 2, 0.05), d.beak)
		leg:SetAttribute("Pivot", d.legH / 2)
	end
	part(m, "Tail", V(d.w * 0.6, d.h * 0.5, 0.3), base * CF(0, d.legH + d.h * 0.8, d.len / 2 + 0.1) * CFrame.Angles(-0.5, 0, 0), Palette.shade(d.color, 0.85)):SetAttribute("Pivot", 0.1)
end

local PLANS = {
	cow = function(rng)
		local c = rng:pick({ rgb(240, 238, 232), rgb(120, 80, 54), rgb(60, 50, 46), rgb(200, 170, 130) })
		return "quad", { len = 4.2, w = 2.1, h = 2.1, legH = 1.9, legW = 0.55, head = V(1.3, 1.3, 1.5), color = c, spots = if rng:chance(0.6) then rgb(40, 36, 34) else nil, snout = rgb(230, 180, 170), horns = rgb(236, 228, 200), tail = 1.8, belly = rgb(240, 200, 190) }, 3.2
	end,
	sheep = function(rng)
		return "quad", { len = 2.8, w = 1.7, h = 1.5, legH = 1.1, legW = 0.35, head = V(0.8, 0.9, 1.0), color = rgb(236, 232, 220), wool = Palette.jitter(rgb(240, 236, 224), 0.05, rng:float()), mat = M.Fabric, headColor = rgb(50, 44, 40), earColor = rgb(50, 44, 40), legColor = rgb(50, 44, 40), tail = 0.5 }, 2.6
	end,
	lamb = function(rng)
		return "quad", { len = 1.6, w = 1.0, h = 0.9, legH = 0.7, legW = 0.22, head = V(0.55, 0.6, 0.65), color = rgb(240, 238, 230), wool = rgb(246, 244, 236), mat = M.Fabric, headColor = rgb(236, 230, 220), legColor = rgb(80, 70, 64), tail = 0.3 }, 1.6
	end,
	pig = function(rng)
		return "quad", { len = 2.6, w = 1.7, h = 1.5, legH = 0.8, legW = 0.4, head = V(1.2, 1.1, 1.0), color = rng:pick({ rgb(240, 170, 170), rgb(226, 150, 140), rgb(120, 90, 80) }), snout = rgb(250, 190, 190), tail = 0.4 }, 2.4
	end,
	piglet = function(rng)
		return "quad", { len = 1.3, w = 0.9, h = 0.8, legH = 0.4, legW = 0.22, head = V(0.7, 0.65, 0.6), color = rgb(244, 178, 176), snout = rgb(252, 196, 196), tail = 0.25 }, 1.6
	end,
	goat = function(rng)
		return "quad", { len = 2.4, w = 1.3, h = 1.3, legH = 1.3, legW = 0.3, head = V(0.8, 0.9, 1.1), color = rng:pick({ rgb(236, 230, 220), rgb(140, 110, 80), rgb(80, 70, 64) }), horns = rgb(90, 80, 70), tail = 0.4, neck = 0.6 }, 2.8
	end,
	kid = function(rng)
		return "quad", { len = 1.3, w = 0.8, h = 0.8, legH = 0.8, legW = 0.2, head = V(0.55, 0.6, 0.7), color = rgb(236, 230, 220), tail = 0.25, neck = 0.3 }, 1.6
	end,
	horse = function(rng)
		local c = rng:pick({ rgb(120, 80, 50), rgb(60, 44, 36), rgb(230, 226, 220), rgb(150, 110, 70) })
		return "quad", { len = 4.4, w = 1.9, h = 2.1, legH = 2.8, legW = 0.5, head = V(1.0, 1.1, 2.0), neck = 1.6, color = c, mane = Palette.shade(c, 0.5), tail = 2.2, tailColor = Palette.shade(c, 0.5) }, 4.5
	end,
	cat = function(rng)
		return "quad", { len = 1.3, w = 0.6, h = 0.6, legH = 0.5, legW = 0.18, head = V(0.6, 0.55, 0.5), color = rng:pick({ rgb(230, 150, 60), rgb(40, 38, 40), rgb(200, 196, 190), rgb(120, 110, 100) }), tail = 1.0 }, 2
	end,
	rabbit = function(rng)
		return "quad", { len = 1.0, w = 0.7, h = 0.7, legH = 0.25, legW = 0.2, head = V(0.55, 0.55, 0.55), color = rng:pick({ rgb(236, 232, 226), rgb(150, 120, 90), rgb(90, 80, 74) }), tail = 0.2, earColor = rgb(236, 200, 200) }, 3.5
	end,
	chicken = function(rng)
		return "bird", { len = 1.0, w = 0.8, h = 0.8, legH = 0.5, head = V(0.4, 0.5, 0.45), color = rng:pick({ rgb(244, 240, 232), rgb(170, 100, 50), rgb(60, 50, 44) }), beak = rgb(240, 180, 60), comb = rgb(220, 40, 40) }, 1.6
	end,
	duckling = function(rng)
		return "bird", { len = 0.6, w = 0.5, h = 0.45, legH = 0.2, head = V(0.3, 0.32, 0.32), color = rgb(250, 220, 90), beak = rgb(240, 150, 50) }, 1.4
	end,
	goose = function(rng)
		return "bird", { len = 1.5, w = 1.0, h = 0.9, legH = 0.6, head = V(0.4, 0.45, 0.6), neck = 0.9, color = rgb(244, 242, 238), beak = rgb(240, 150, 50) }, 1.8
	end,
}

-- Builds one animal standing at `cf` (on the ground). opts: {wander, anchored=true, tag=true}
function Fauna.animal(parent: Instance, kind: string, cf: CFrame, rng, opts)
	opts = opts or {}
	local plan = PLANS[kind] or PLANS.sheep
	local shape, d, speed = plan(rng)
	local m = Kit.model(kind, parent)
	if shape == "bird" then
		bird(m, cf, d)
	else
		quad(m, cf, d)
	end
	local body = m:FindFirstChild("Body")
	m.PrimaryPart = body
	m.WorldPivot = cf
	m:SetAttribute("Kind", kind)
	m:SetAttribute("Speed", speed)
	m:SetAttribute("Wander", opts.wander or 10)
	m:SetAttribute("Home", cf.Position)
	m:SetAttribute("Bird", shape == "bird")
	if opts.tag ~= false then
		CollectionService:AddTag(m, "Critter")
	end
	return m
end

-- A saddled riding horse (the summoned mount, see Server/Mounts): the horse plan
-- plus blanket, saddle, stirrups, girth, bridle and reins. Standing at `cf` (the
-- hooves on the ground, facing -Z). Returns the model and the saddle-top height.
function Fauna.steed(parent: Instance?, cf: CFrame, rng, opts)
	opts = opts or {}
	local c = rng:pick({ rgb(120, 80, 50), rgb(60, 44, 36), rgb(236, 232, 226), rgb(150, 110, 70), rgb(46, 42, 44), rgb(176, 150, 120) })
	local hair = if c.R > 0.85 then rgb(206, 200, 190) else Palette.shade(c, 0.45)
	local d = { len = 4.6, w = 1.9, h = 2.1, legH = 2.8, legW = 0.5, head = V(1.0, 1.1, 2.0), neck = 1.7, color = c, mane = hair, tail = 2.4, tailColor = hair, hoof = rgb(34, 30, 28) }
	local m = Kit.model("Horse", parent)
	quad(m, cf, d)
	local top = d.legH + d.h -- the back, above the hooves
	local cloth = rng:pick({ rgb(150, 30, 34), rgb(40, 60, 120), rgb(40, 90, 50), rgb(90, 40, 100), rgb(30, 30, 34) })
	local gold = rgb(214, 170, 70)
	local leather = rgb(84, 52, 32)
	local iron = rgb(150, 150, 158)
	part(m, "Blanket", V(d.w + 0.12, 0.08, 1.9), cf * CF(0, top + 0.04, 0.35), cloth, M.Fabric)
	for _, sx in { -1, 1 } do
		part(m, "Blanket", V(0.08, 1.0, 1.9), cf * CF(sx * (d.w / 2 + 0.06), top - 0.46, 0.35), cloth, M.Fabric)
		part(m, "Trim", V(0.1, 0.1, 1.94), cf * CF(sx * (d.w / 2 + 0.07), top - 0.94, 0.35), gold, M.Metal)
		part(m, "Strap", V(0.08, 1.6, 0.14), cf * CF(sx * (d.w / 2 + 0.14), top - 0.8, 0.3), leather, M.Leather)
		part(m, "Stirrup", V(0.12, 0.12, 0.42), cf * CF(sx * (d.w / 2 + 0.16), top - 1.62, 0.3), iron, M.Metal)
		-- saddlebags behind the saddle
		part(m, "Bag", V(0.4, 0.7, 0.8), cf * CF(sx * (d.w / 2 + 0.22), top - 0.3, 1.55), Palette.shade(leather, 1.15), M.Leather)
	end
	part(m, "Saddle", V(1.5, 0.32, 1.5), cf * CF(0, top + 0.24, 0.35), leather, M.Leather)
	part(m, "Cantle", V(1.3, 0.45, 0.28), cf * CF(0, top + 0.5, 1.05), leather, M.Leather)
	part(m, "Pommel", V(0.45, 0.45, 0.28), cf * CF(0, top + 0.5, -0.35), Palette.shade(leather, 0.8), M.Leather)
	part(m, "Bedroll", V(1.4, 0.36, 0.36), cf * CF(0, top + 0.28, 1.45), rng:pick({ rgb(120, 110, 90), rgb(80, 90, 70) }), M.Fabric)
	part(m, "Girth", V(d.w + 0.1, 0.1, 0.3), cf * CF(0, d.legH + 0.02, -0.1), leather, M.Leather)
	local head = m:FindFirstChild("Head") :: BasePart
	if head then
		local hs = d.head
		local hcf = head.CFrame
		part(m, "Bridle", V(hs.X + 0.08, 0.14, 0.14), hcf * CF(0, -hs.Y * 0.1, -hs.Z * 0.3), leather, M.Leather)
		part(m, "Bridle", V(hs.X + 0.08, 0.14, 0.14), hcf * CF(0, hs.Y * 0.3, hs.Z * 0.2), leather, M.Leather)
		part(m, "Forelock", V(0.5, 0.16, 0.5), hcf * CF(0, hs.Y / 2 + 0.06, hs.Z * 0.25), hair)
		for _, sx in { -1, 1 } do
			local a = (hcf * CF(sx * (hs.X / 2 + 0.06), -hs.Y * 0.1, -hs.Z * 0.3)).Position
			local b = (cf * CF(sx * 0.3, top + 0.55, -0.35)).Position
			local mid = (a + b) / 2 - V(0, 0.25, 0)
			part(m, "Rein", V(0.06, 0.06, (a - mid).Magnitude), CFrame.lookAt((a + mid) / 2, mid), rgb(60, 38, 24), M.Leather)
			part(m, "Rein", V(0.06, 0.06, (b - mid).Magnitude), CFrame.lookAt((b + mid) / 2, mid), rgb(60, 38, 24), M.Leather)
			part(m, "Bit", V(0.1, 0.18, 0.18), hcf * CF(sx * (hs.X / 2 + 0.05), -hs.Y * 0.1, -hs.Z * 0.3), iron, M.Metal)
		end
	end
	local bodyY = d.legH + d.h / 2
	-- a destrier wears barding: a steel chanfron and plates over the chest and flanks
	if opts.barding then
		local steel = rgb(170, 172, 180)
		local head2 = m:FindFirstChild("Head") :: BasePart
		if head2 then
			local hs = d.head
			part(m, "Chanfron", V(hs.X + 0.12, 0.2, hs.Z * 0.8), head2.CFrame * CF(0, hs.Y / 2 + 0.05, -hs.Z * 0.05), steel, M.Metal).Name = "Bridle"
			part(m, "Spike", V(0.18, 0.5, 0.18), head2.CFrame * CF(0, hs.Y / 2 + 0.3, -hs.Z * 0.2), gold, M.Metal).Name = "Bridle"
		end
		part(m, "Peytral", V(d.w + 0.2, d.h * 0.7, 0.2), cf * CF(0, bodyY - 0.1, -d.len / 2 - 0.05), steel, M.Metal)
		for _, sx in { -1, 1 } do
			part(m, "Crinet", V(0.16, d.h * 0.6, 1.2), cf * CF(sx * (d.w / 2 + 0.12), bodyY + 0.1, -d.len / 2 + 0.7), steel, M.Metal)
			part(m, "Flank", V(0.14, d.h * 0.55, 1.3), cf * CF(sx * (d.w / 2 + 0.1), bodyY - 0.2, d.len / 2 - 0.8), steel, M.Metal)
		end
	end
	-- a fuller mane down the neck
	for i = 0, 3 do
		part(m, "Mane", V(0.34, 0.5, 0.5), cf * CF(0, bodyY + d.h * 0.5 + 0.35 + i * 0.3, -d.len / 2 + 0.2 - i * 0.28) * CFrame.Angles(0.5, 0, 0), hair)
	end
	m.PrimaryPart = m:FindFirstChild("Body") :: BasePart
	m.WorldPivot = cf
	m:SetAttribute("Kind", "horse")
	return m, top + 0.4
end

-- A small animal carried in the arms (welded to the torso), for farmers.
function Fauna.carried(rig: Model, kind: string, rng)
	local torso = rig:FindFirstChild("Torso") :: BasePart
	if not torso then
		return nil
	end
	local plan = PLANS[kind] or PLANS.chicken
	local shape, d = plan(rng)
	local m = Kit.model("Carried", rig)
	-- sideways across the forearms
	local base = torso.CFrame * CF(0, -0.9 - d.legH, -1.25) * CFrame.Angles(0, math.pi / 2, 0)
	if shape == "bird" then
		bird(m, base, d)
	else
		quad(m, base, d)
	end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true
			Kit.weld(p, torso)
		end
	end
	rig:SetAttribute("Pose", "Carry")
	return m
end

return Fauna
