--!nonstrict
-- TRAIT MONSTERS. Every run rolls its own bestiary: each species gets three traits
-- that never contradict each other (fast + small + air = a darting bird, big +
-- ground + destructive = a stomping beast, fire + floating + elemental = a little
-- fire spirit ...). The traits decide the body plan, the looks, the moves and the
-- numbers; a threat rating from the numbers decides where a species may appear.
--
--   Beasts.species(rng, opts)        -> def (same shape as Enemies.DEFS entries)
--   Beasts.roster(seed, n)           -> list of species for a run, weakest first
--   Beasts.pick(roster, rng, lo, hi) -> a species whose tier fits [lo, hi]
--   Beasts.boss(rng, level, opts)    -> a random boss def (the canon bosses stay canon)
--   Beasts.describe(def)             -> "fast · small · air"
-- The look (def.look, monster = "beast") is built by Beasts.decorate, registered as
-- a Rig body plan, so every trait monster is still a normal R6 rig (animator,
-- ragdoll, combat all just work).
local Palette = require(script.Parent.Palette)
local Rig = require(script.Parent.Rig)
local Enemies = require(script.Parent.Enemies)
local RNG = require(script.Parent.RNG)

local Beasts = {}
local rgb = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local M = Enum.Material
local A = Enemies.A
local atk = Enemies.atk

-- ------------------------------------------------------------------ traits
Beasts.TRAITS = {
	tiny = "size",
	small = "size",
	big = "size",
	huge = "size",
	ground = "move",
	air = "move",
	floating = "move",
	fast = "tempo",
	slow = "tempo",
	fire = "element",
	frost = "element",
	storm = "element",
	poison = "element",
	void = "element",
	stone = "element",
	destructive = "nature",
	predator = "nature",
	armored = "nature",
	spitter = "nature",
	caster = "nature",
	swarm = "nature",
	elemental = "nature",
}
local CATS = {
	size = { "tiny", "small", "big", "huge" },
	move = { "ground", "ground", "air", "floating" },
	tempo = { "fast", "slow" },
	element = { "fire", "frost", "storm", "poison", "void", "stone" },
	nature = { "destructive", "predator", "armored", "spitter", "caster", "swarm", "elemental" },
}
local CAT_WEIGHT = { { "size", 3 }, { "move", 1.8 }, { "tempo", 2 }, { "element", 2.6 }, { "nature", 3.2 } }

-- pairs that make no sense together
local CONFLICT = {
	{ "huge", "air" },
	{ "huge", "floating" },
	{ "huge", "fast" },
	{ "huge", "swarm" },
	{ "big", "swarm" },
	{ "tiny", "destructive" },
	{ "tiny", "armored" },
	{ "slow", "air" },
	{ "slow", "predator" },
	{ "stone", "air" },
	{ "stone", "fast" },
	{ "swarm", "elemental" },
	{ "air", "armored" },
	{ "tiny", "elemental" },
}
local function conflicts(set, t: string): boolean
	for _, c in CONFLICT do
		if (c[1] == t and set[c[2]]) or (c[2] == t and set[c[1]]) then
			return true
		end
	end
	return false
end

local function rollTraits(rng, forced)
	local picked, byCat = {}, {}
	local list = {}
	for _, t in forced or {} do
		if Beasts.TRAITS[t] and not byCat[Beasts.TRAITS[t]] and not conflicts(picked, t) then
			picked[t] = true
			byCat[Beasts.TRAITS[t]] = t
			table.insert(list, t)
		end
	end
	local guard = 0
	while #list < 3 and guard < 60 do
		guard += 1
		local cat = rng:weighted(CAT_WEIGHT)
		if not byCat[cat] then
			local t = rng:pick(CATS[cat])
			if not conflicts(picked, t) then
				picked[t] = true
				byCat[cat] = t
				table.insert(list, t)
			end
		end
	end
	-- elementals always have an element
	if byCat.nature == "elemental" and not byCat.element then
		local t = rng:pick({ "fire", "frost", "storm", "void", "stone" })
		picked[t] = true
		byCat.element = t
	end
	return {
		list = list,
		set = picked,
		size = byCat.size or "medium",
		move = byCat.move or "ground",
		tempo = byCat.tempo or "normal",
		element = byCat.element,
		nature = byCat.nature,
	}
end
Beasts.rollTraits = rollTraits

-- ------------------------------------------------------------------ body plans
local function planOf(tr, rng): string
	if tr.move == "air" then
		return "bird"
	elseif tr.move == "floating" then
		if tr.nature == "elemental" or tr.nature == "caster" or (tr.element and rng:chance(0.6)) then
			return "spirit"
		end
		return "gazer"
	end
	if tr.nature == "elemental" then
		return "golem"
	elseif tr.nature == "armored" then
		return if tr.size == "tiny" or tr.size == "small" then "critter" else "shell"
	elseif tr.nature == "swarm" or tr.size == "tiny" then
		return "critter"
	elseif tr.size == "huge" or tr.nature == "destructive" then
		return if rng:chance(0.7) then "beast" else "golem"
	elseif tr.nature == "predator" or tr.tempo == "fast" then
		return "stalker"
	elseif tr.nature == "caster" or tr.nature == "spitter" then
		return "horror"
	elseif tr.size == "big" then
		return rng:pick({ "beast", "horror", "shell" })
	end
	return rng:pick({ "stalker", "horror", "beast", "critter" })
end

-- ------------------------------------------------------------------ looks
local ELEMENT_LOOK = {
	fire = { skins = { rgb(52, 32, 28), rgb(72, 36, 26), rgb(40, 28, 28), rgb(96, 40, 24) }, glow = rgb(255, 120, 40), accent = rgb(255, 176, 70), blood = "black", hide = "basalt" },
	frost = { skins = { rgb(186, 212, 228), rgb(148, 178, 204), rgb(214, 228, 238), rgb(120, 150, 180) }, glow = rgb(150, 225, 255), accent = rgb(240, 250, 255), blood = "blue", hide = "crystal" },
	storm = { skins = { rgb(46, 54, 76), rgb(60, 68, 94), rgb(32, 38, 58), rgb(70, 60, 96) }, glow = rgb(120, 215, 255), accent = rgb(230, 240, 255), blood = "purple", hide = "scale" },
	poison = { skins = { rgb(88, 112, 54), rgb(98, 84, 122), rgb(72, 98, 62), rgb(120, 110, 50) }, glow = rgb(170, 255, 70), accent = rgb(210, 240, 90), blood = "green", hide = "flesh" },
	void = { skins = { rgb(24, 18, 32), rgb(36, 22, 48), rgb(18, 14, 22), rgb(44, 28, 60) }, glow = rgb(175, 85, 255), accent = rgb(90, 40, 150), blood = "void", hide = "chitin" },
	stone = { skins = { rgb(112, 106, 100), rgb(94, 88, 82), rgb(130, 120, 106), rgb(80, 82, 88) }, glow = rgb(255, 200, 120), accent = rgb(160, 150, 136), blood = "green", hide = "rock" },
}
local NATURAL = {
	skins = { rgb(92, 70, 52), rgb(64, 58, 54), rgb(110, 84, 58), rgb(80, 40, 36), rgb(60, 76, 52), rgb(120, 100, 76), rgb(46, 42, 46), rgb(138, 118, 92), rgb(70, 52, 70), rgb(100, 60, 40) },
	glows = { rgb(255, 220, 90), rgb(255, 70, 60), rgb(180, 255, 120), rgb(255, 150, 60), rgb(220, 120, 255) },
	patterns = { rgb(30, 26, 24), rgb(200, 190, 170), rgb(150, 40, 36), rgb(236, 226, 206) },
}
local HIDE_MAT = {
	fur = M.Fabric,
	scale = M.Leather,
	chitin = M.SmoothPlastic,
	flesh = M.Leather,
	rock = M.Slate,
	basalt = M.Basalt,
	crystal = M.SmoothPlastic,
	feather = M.Fabric,
}

local SIZE = {
	tiny = { scale = 0.5, hp = 0.35, dmg = 0.55, speed = 1.18, xp = 0.45 },
	small = { scale = 0.75, hp = 0.62, dmg = 0.8, speed = 1.1, xp = 0.7 },
	medium = { scale = 1.0, hp = 1.0, dmg = 1.0, speed = 1.0, xp = 1.0 },
	big = { scale = 1.45, hp = 2.1, dmg = 1.35, speed = 0.9, xp = 2.0 },
	huge = { scale = 2.25, hp = 4.4, dmg = 1.8, speed = 0.74, xp = 4.2 },
}

local NAME_EL = {
	fire = { "Cinder", "Ember", "Scorch", "Ash", "Pyre" },
	frost = { "Rime", "Frost", "Hoar", "Glacial", "Pale" },
	storm = { "Thunder", "Static", "Storm", "Gale", "Volt" },
	poison = { "Blight", "Venom", "Rot", "Bile", "Fester" },
	void = { "Gloom", "Hollow", "Null", "Umbral", "Abyssal" },
	stone = { "Crag", "Grave", "Granite", "Flint", "Basalt" },
}
local NAME_NAT = {
	destructive = { "Ruin", "Wrecking", "Crushing", "Rampant" },
	predator = { "Feral", "Razor", "Hunting", "Bloodfang" },
	armored = { "Iron", "Plated", "Bulwark", "Scaled" },
	spitter = { "Spitting", "Retching", "Acrid" },
	caster = { "Chanting", "Weird", "Sigil" },
	swarm = { "Teeming", "Hive", "Skittering" },
	elemental = { "Living", "Wrathful", "Primal" },
}
local NAME_SIZE = { tiny = { "Lesser", "Wee", "Runt" }, huge = { "Titanic", "Colossal", "Elder" }, big = { "Great", "Hulking", "Bloated" } }
local NOUN = {
	bird = { "Shrike", "Harpy", "Wing", "Kite", "Screecher", "Gullet" },
	beast = { "Behemoth", "Tusker", "Mauler", "Ox", "Hulk", "Boar" },
	stalker = { "Stalker", "Prowler", "Fang", "Lurker", "Hound" },
	critter = { "Tick", "Mite", "Scuttler", "Crawler", "Weevil" },
	shell = { "Shellback", "Carapace", "Tortoise", "Crab" },
	spirit = { "Wisp", "Spirit", "Shade", "Elemental", "Mote" },
	gazer = { "Gazer", "Drifter", "Eye", "Jelly", "Bloat" },
	golem = { "Golem", "Colossus", "Sentinel", "Construct" },
	horror = { "Horror", "Fiend", "Ghoul", "Wretch", "Maw" },
}

local function speciesName(rng, tr, plan): string
	local adj
	if tr.element and rng:chance(0.7) then
		adj = rng:pick(NAME_EL[tr.element])
	elseif tr.nature and NAME_NAT[tr.nature] and rng:chance(0.7) then
		adj = rng:pick(NAME_NAT[tr.nature])
	elseif NAME_SIZE[tr.size] then
		adj = rng:pick(NAME_SIZE[tr.size])
	else
		adj = rng:pick({ "Grim", "Pale", "Crooked", "Gaunt", "Wretched", "Rabid" })
	end
	return adj .. " " .. rng:pick(NOUN[plan])
end

-- ------------------------------------------------------------------ moves
local PROJ = {
	fire = { speed = 64, gravity = 4, size = 1.3, color = rgb(255, 120, 40), style = "fire", explode = 7 },
	frost = { speed = 96, gravity = 10, size = 0.9, color = rgb(170, 230, 255), style = "orb" },
	storm = { speed = 130, gravity = 0, size = 0.8, color = rgb(140, 220, 255), style = "orb" },
	poison = { speed = 60, gravity = 40, size = 1.1, color = rgb(160, 240, 70), style = "orb", explode = 6 },
	void = { speed = 58, gravity = 0, size = 1.1, color = rgb(170, 80, 255), style = "orb", homing = 1.3 },
	stone = { speed = 72, gravity = 40, size = 1.5, color = rgb(120, 110, 100), style = "rock", explode = 6 },
	none = { speed = 80, gravity = 26, size = 0.8, color = rgb(190, 200, 140), style = "orb" },
}

local function projFor(tr)
	local p = table.clone(PROJ[tr.element or "none"])
	return p
end

-- scale an attack to the body: bigger reach for bigger bodies, tempo changes windups
local function fit(a, sc: number, tempo: string)
	local o = table.clone(a)
	local k = sc ^ 0.8
	o.range = (o.range or 6) * k
	if o.minRange then
		o.minRange = o.minRange * k
	end
	if o.aoe then
		o.aoe = o.aoe * k
	end
	if o.shock then
		o.shock = o.shock * k
	end
	local tk = if tempo == "fast" then 0.78 elseif tempo == "slow" then 1.25 else 1
	o.w = (o.w or 0.4) * tk
	o.r = (o.r or 0.4) * tk
	return o
end

local function movesFor(tr, plan: string, sc: number)
	local list = {}
	local T = tr.tempo
	local function add(a)
		table.insert(list, fit(a, sc, T))
	end
	local projectile = projFor(tr)
	if plan == "bird" then
		add(atk(A.claw, { id = "Peck", anim = "ClawR", range = 6, dmg = 0.8 }))
		add(atk(A.pounce, { id = "Dive", anim = "Dive", range = 34, minRange = 5, lunge = 95, dmg = 1.3, kind = "lunge", cd = 2.5 }))
		if tr.element or tr.nature == "spitter" then
			add(atk(A.bolt, { id = "Spit", anim = "Spit", range = 70, minRange = 6, proj = projectile, cd = 2 }))
		end
	elseif plan == "spirit" then
		add(atk(A.bolt, { id = "Bolt", anim = "Cast", proj = projectile, cd = 1.1 }))
		add(atk(A.nova, { id = "Pulse", aoe = 11, dmg = 1.2 }))
		if tr.size == "big" then
			add(atk(A.slash, { id = "Lash", anim = "ClawR" }))
		end
	elseif plan == "gazer" then
		add(atk(A.bolt, { id = "Gaze", anim = "Spit", proj = projectile, cd = 1.4 }))
		add(atk(A.sweep, { id = "Tentacles", anim = "Sweep", range = 9, dmg = 1.1, cd = 3.5 }))
		add(atk(A.grab, { id = "Grasp", anim = "Grab", range = 7, cd = 7 }))
	elseif plan == "beast" then
		add(atk(A.claw, { id = "Bite", anim = "QBite", range = 7, dmg = 1.1 }))
		add(atk(A.pounce, { id = "Charge", anim = "QCharge", range = 24, minRange = 8, lunge = 72, dmg = 1.5, kind = "heavy", cd = 5 }))
		add(atk(A.stomp, { id = "Stomp", anim = "QStomp", aoe = 11, dmg = 1.35, cd = 5 }))
		if tr.nature == "destructive" then
			add(atk(A.roar, { id = "Roar", anim = "QBite", cd = 14 }))
		end
	elseif plan == "stalker" then
		add(atk(A.claw, { id = "Bite", anim = "QBite", range = 6.5, w = 0.3 }))
		add(atk(A.clawL, { id = "Snap", anim = "QBite", range = 6.5, w = 0.26, dmg = 0.8 }))
		add(atk(A.pounce, { id = "Pounce", anim = "QPounce", range = 20, minRange = 7, lunge = 88, dmg = 1.3 }))
	elseif plan == "critter" then
		add(atk(A.claw, { id = "Bite", anim = "QBite", range = 5, w = 0.26, dmg = 0.9 }))
		add(atk(A.pounce, { id = "Leap", anim = "QPounce", range = 14, minRange = 5, lunge = 70, dmg = 1.0, cd = 2.5 }))
	elseif plan == "shell" then
		add(atk(A.claw, { id = "Pinch", anim = "QBite", range = 7 }))
		add(atk(A.pounce, { id = "Ram", anim = "QCharge", range = 20, minRange = 7, lunge = 60, dmg = 1.4, kind = "heavy", cd = 4.5 }))
		add(atk(A.sweep, { id = "Spin", anim = "Sweep", range = 9, dmg = 1.2, cd = 5 }))
	elseif plan == "golem" then
		add(atk(A.slash, { id = "Smash", anim = "SlashR", dmg = 1.1 }))
		add(atk(A.slam, { id = "Slam", dmg = 1.6, shock = 13 }))
		add(atk(A.throw, { id = "Hurl", proj = if tr.element then projectile else nil }))
		add(atk(A.stomp, { id = "Stomp", aoe = 12 }))
	else -- horror
		add(A.claw)
		add(A.clawL)
		add(atk(A.pounce, { dmg = 1.15 }))
	end
	-- nature extras
	local quadAnim = plan == "beast" or plan == "stalker" or plan == "critter" or plan == "shell"
	local ranged = plan == "bird" or plan == "gazer" or plan == "spirit"
	if tr.nature == "spitter" and not ranged then
		add(atk(A.bolt, { id = "Spit", anim = if quadAnim then "QBite" else "Spit", proj = projectile, range = 60, cd = 2.2 }))
	elseif tr.nature == "caster" and not ranged then
		add(atk(A.bolt, { id = "Hex", anim = "Cast", proj = projectile, cd = 1.6 }))
		add(atk(A.nova, { id = "Nova", aoe = 10 }))
	end
	if tr.element and not ranged and tr.nature ~= "spitter" and tr.nature ~= "caster" then
		-- every elemental body gets one elemental move
		add(atk(A.bolt, { id = "Breath", anim = if quadAnim then "QBite" else "Spit", proj = projectile, range = 50, cd = 4.5, weight = 1.2 }))
	end
	return list
end

-- ------------------------------------------------------------------ species
local function shade(c: Color3, f: number): Color3
	return Palette.shade(c, f)
end

function Beasts.species(rng, opts)
	opts = opts or {}
	local tr = rollTraits(rng, opts.traits)
	local plan = opts.plan or planOf(tr, rng)
	local sz = SIZE[tr.size]
	local el = tr.element and ELEMENT_LOOK[tr.element]
	-- colours / hide
	local skin = if el then rng:pick(el.skins) else rng:pick(NATURAL.skins)
	skin = Palette.jitter(skin, 0.08, rng:float())
	local glow = if el then el.glow else rng:pick(NATURAL.glows)
	local hide
	if el then
		hide = el.hide
	elseif plan == "bird" then
		hide = "feather"
	elseif plan == "critter" or plan == "shell" then
		hide = "chitin"
	elseif plan == "stalker" or plan == "beast" then
		hide = rng:pick({ "fur", "fur", "scale" })
	else
		hide = rng:pick({ "flesh", "scale" })
	end
	local pattern = rng:pick({ "none", "stripes", "spots", "bands", "belly" })
	local look = {
		race = "Monster",
		monster = "beast",
		outfit = "bare",
		hairStyle = "bald",
		mood = "monster",
		plan = plan,
		skin = skin,
		shirt = skin,
		pants = shade(skin, 0.9),
		skinMat = HIDE_MAT[hide],
		hide = hide,
		glow = glow,
		accent = if el then el.accent else shade(skin, 1.35),
		pattern = pattern,
		patternColor = if el then shade(skin, 0.6) else rng:pick(NATURAL.patterns),
		belly = shade(skin, 1.3),
		element = tr.element,
		eyes = rng:pick({ 2, 2, 2, 3, 4, 6 }),
		horns = rng:pick({ "none", "none", "pair", "curl", "crown", "tusks" }),
		tail = rng:pick({ "whip", "club", "spiked", "stub", "fan" }),
		spikes = tr.nature == "armored" or tr.nature == "destructive" or rng:chance(0.35),
		mane = hide == "fur" and rng:chance(0.5),
		legsN = if plan == "critter" then rng:pick({ 4, 6, 8 }) else 4,
		scale = sz.scale * rng:float(0.92, 1.1),
		hunch = plan == "horror" or plan == "golem",
		seed = rng:int(1, 1000000),
	}
	-- numbers
	local hp, dmg, speed, xp = 55 * sz.hp, 11 * sz.dmg, 17 * sz.speed, 12 * sz.xp
	local armor, posture = 0, 70 * sz.hp
	if tr.tempo == "fast" then
		speed *= 1.38
		hp *= 0.85
	elseif tr.tempo == "slow" then
		speed *= 0.66
		hp *= 1.3
		dmg *= 1.25
	end
	if tr.nature == "armored" then
		hp *= 1.35
		armor = 0.25
		posture *= 1.7
	elseif tr.nature == "destructive" then
		dmg *= 1.3
		posture *= 1.3
	elseif tr.nature == "predator" then
		speed *= 1.12
		dmg *= 1.1
	elseif tr.nature == "swarm" then
		hp *= 0.6
		dmg *= 0.8
	elseif tr.nature == "elemental" then
		hp *= 1.2
	end
	if tr.move == "air" then
		hp *= 0.75
		speed *= 1.15
	elseif tr.move == "floating" then
		hp *= 0.9
	end
	if tr.element == "stone" then
		armor = math.max(armor, 0.12)
	end
	local attacks = movesFor(tr, plan, look.scale)
	local ai = "melee"
	if tr.move == "air" then
		ai = "flyer"
	elseif tr.move == "floating" then
		ai = "floater"
	elseif tr.nature == "caster" or tr.nature == "spitter" then
		ai = if plan == "horror" then "caster" else "melee"
	end
	-- threat: how dangerous the numbers + moves are (1 = crawler-ish, 5 = nightmare)
	local threat = (hp / 55) ^ 0.55 * (dmg / 11) ^ 0.8 * (speed / 17) ^ 0.5 * (1 + #attacks * 0.08) * (if tr.move ~= "ground" then 1.15 else 1)
	local tier = math.clamp(math.floor(threat * 1.6 + 0.5), 1, 5)
	local name = opts.name or speciesName(rng, tr, plan)
	local def = {
		name = name,
		team = "monster",
		beast = true,
		blood = if el then el.blood else rng:pick({ "purple", "green", "purple", "red" }),
		hp = math.floor(hp + 0.5),
		dmg = dmg,
		speed = speed,
		aggro = if tr.nature == "predator" then 120 else 95,
		xp = math.floor(xp * (0.8 + tier * 0.25) + 0.5),
		gold = { math.floor(1 + tier), math.floor(4 + tier * 3) },
		ai = ai,
		keepAway = if ai == "caster" then 24 else nil,
		blink = tr.element == "void" and plan ~= "beast",
		poise = tr.size == "huge" or tr.nature == "armored" and tr.size ~= "small",
		posture = posture,
		armor = armor,
		look = look,
		attacks = attacks,
		traits = tr.list,
		plan = plan,
		element = tr.element,
		size = tr.size,
		move = tr.move,
		swarm = tr.nature == "swarm",
		hover = if tr.move == "air" then 11 elseif tr.move == "floating" then 3.2 else nil,
		threat = threat,
		tier = tier,
	}
	return def
end

function Beasts.describe(def): string
	return table.concat(def.traits or {}, " · ")
end

-- A run's bestiary: n species, at least a few flyers/floaters, weakest first.
local rosterCache = {}
function Beasts.roster(seed: number, n: number?)
	local key = tostring(seed) .. ":" .. tostring(n or 20)
	if rosterCache[key] then
		return rosterCache[key]
	end
	local count = n or 20
	local base = RNG.new(seed):fork("bestiary")
	local list = {}
	local names = {}
	for i = 1, count do
		local rng = base:fork("species", i)
		local forced = nil
		if i <= 2 then
			forced = { "air" }
		elseif i <= 4 then
			forced = { "floating" }
		elseif i == 5 then
			forced = { "big", "ground", "destructive" }
		elseif i == 6 then
			forced = { "small", "fast" }
		end
		local def = Beasts.species(rng, { traits = forced })
		-- unique names inside one world
		local guard = 0
		while names[def.name] and guard < 6 do
			guard += 1
			def.name = speciesName(rng, { element = def.element, nature = nil, size = def.size }, def.plan)
		end
		names[def.name] = true
		def.id = "Beast" .. i
		table.insert(list, def)
	end
	table.sort(list, function(a, b)
		return a.threat < b.threat
	end)
	rosterCache[key] = list
	return list
end

-- A species with a tier inside [lo, hi] (widens the band when nothing fits).
function Beasts.pick(roster, rng, lo: number, hi: number, filter)
	for widen = 0, 4 do
		local fits = {}
		for _, d in roster do
			if d.tier >= lo - widen and d.tier <= hi + widen and (not filter or filter(d)) then
				table.insert(fits, d)
			end
		end
		if #fits > 0 then
			return rng:pick(fits)
		end
	end
	return roster[1]
end

-- Random bosses: a big body, boss numbers, roars and minions. Canon bosses (the
-- Pit Warden, the Archmage, the Evil, the God) stay hand-made.
local EPITHET = { "the Unfed", "Who Walks Below", "the Last Mouth", "of the Deep Hollow", "the Crowned Rot", "Worldgnawer", "the Patient Dark", "Bonequeen", "the Hundred-Eyed", "the Burning Gate" }
local BOSS_PRE = { "Gor", "Vex", "Mal", "Thra", "Kul", "Zar", "Ruk", "Bel", "Skar", "Nex", "Dra", "Umb", "Ossa", "Yth" }
local BOSS_SUF = { "moth", "gorath", "zul", "akar", "oth", "mira", "venna", "ax", "ulgar", "yss", "ethra" }
function Beasts.boss(rng, level: number?, opts)
	opts = opts or {}
	local traits = { rng:pick({ "big", "huge" }), rng:pick({ "destructive", "predator", "armored", "elemental", "caster" }) }
	if rng:chance(0.7) then
		table.insert(traits, rng:pick(CATS.element))
	end
	local def = Beasts.species(rng, { traits = opts.traits or traits })
	def.name = rng:pick(BOSS_PRE) .. rng:pick(BOSS_SUF) .. ", " .. rng:pick(EPITHET)
	def.hp = math.floor(def.hp * (opts.hpMult or 7.5))
	def.dmg *= 1.3
	def.xp = math.floor(def.xp * 9)
	def.gold = { def.gold[1] * 10, def.gold[2] * 12 }
	def.boss = opts.miniboss ~= true
	def.miniboss = opts.miniboss == true
	def.poise = true
	def.posture = def.posture * 3
	def.aggro = 220
	def.look = table.clone(def.look)
	def.look.scale = math.max(def.look.scale, 2.0) * (if opts.miniboss then 0.85 else 1.05)
	def.look.glowEye = rgb(255, 60, 50)
	def.attacks = table.clone(def.attacks)
	table.insert(def.attacks, atk(A.roar, { id = "BossRoar", cd = 16, anim = if def.plan == "beast" or def.plan == "stalker" or def.plan == "shell" or def.plan == "critter" then "QBite" else "Roar" }))
	table.insert(def.attacks, fit(atk(A.slam, { id = "Quake", anim = if def.plan == "beast" or def.plan == "shell" then "QStomp" else "Slam", shock = 20, dmg = 1.7, cd = 7 }), 1, "normal"))
	def.summonSelf = true
	return def
end

-- ------------------------------------------------------------------ bodies
-- Built as a Rig body plan (Rig.build calls this with its part table p).
local H = Rig.helpers
local box, seg, chain, spike = H.box, H.seg, H.chain, H.spike
local HH = H.HH
local add = Rig.add
local NEON = M.Neon

local function hideAll(parts)
	for _, part in parts do
		part.Transparency = 1
		for _, c in part:GetChildren() do
			if c:IsA("BasePart") then
				c.Transparency = 1
			end
		end
	end
end

local function glowPart(g: BasePart)
	g.CastShadow = false
	return g
end

-- glowing eyes on the front of a head part
local function eyesOn(p, head: BasePart, n: number, glow: Color3, y: number, z: number, spread: number?)
	local sp = spread or 0.3
	local rows = if n >= 6 then 3 elseif n >= 4 then 2 else 1
	local per = math.max(1, math.floor(n / rows + 0.5))
	for r = 1, rows do
		for i = 1, per do
			local x = if per == 1 then 0 else (i - (per + 1) / 2) * (sp * 2 / math.max(per - 1, 1))
			local yy = y - (r - 1) * 0.16
			local g = glowPart(box(head, x - 0.07, x + 0.07, yy - 0.05, yy + 0.05, z - 0.05, z, glow, NEON))
			table.insert(p.eyes, g)
		end
	end
end

local function pattern(p, d, t: BasePart, quad: boolean)
	local pc = d.patternColor or rgb(30, 26, 24)
	local mat = p.skinMat
	if d.pattern == "stripes" then
		for i = 0, 3 do
			local y = -0.9 + i * 0.6
			if quad then
				box(t, -1.02, 1.02, y - 0.1, y + 0.1, 0.9, 1.3, pc, mat)
			else
				box(t, -1.02, 1.02, y - 0.08, y + 0.08, -0.53, 0.53, pc, mat)
			end
		end
	elseif d.pattern == "spots" then
		local r = RNG.new(d.seed or 1)
		for _ = 1, 6 do
			local x, y = r:float(-0.8, 0.8), r:float(-0.9, 0.9)
			local s = r:float(0.15, 0.3)
			if quad then
				box(t, x - s, x + s, y - s, y + s, 1.24, 1.3, pc, mat)
			else
				box(t, x - s, x + s, y - s, y + s, 0.5, 0.56, pc, mat)
			end
		end
	elseif d.pattern == "bands" then
		for _, l in p.legs do
			H.lband(l.part, -0.4, -0.2, 0.05, pc, mat)
		end
		for _, a in p.arms do
			H.lband(a.part, -0.4, -0.2, 0.05, pc, mat)
		end
	elseif d.pattern == "belly" then
		if quad then
			box(t, -0.8, 0.8, -0.9, 0.9, -0.62, -0.5, d.belly, mat)
		else
			box(t, -0.7, 0.7, -0.9, 0.8, -0.56, -0.5, d.belly, mat)
		end
	end
end

local function elementFx(p, d, part: BasePart, strength: number)
	local el = d.element
	if not el then
		return
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = "ElementFX"
	e.LightEmission = 0.8
	e.Rate = 6 * strength
	e.Lifetime = NumberRange.new(0.4, 0.9)
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * strength), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(d.glow, shade(d.glow, 0.6))
	if el == "fire" then
		e.Texture = "rbxasset://textures/particles/fire_main.dds"
		e.Acceleration = V(0, 5, 0)
	elseif el == "poison" then
		e.Texture = "rbxasset://textures/SurfacesDefault.png"
		e.Acceleration = V(0, -3, 0)
	else
		e.Texture = "rbxasset://textures/SurfacesDefault.png"
		e.Acceleration = V(0, 1.5, 0)
		e.RotSpeed = NumberRange.new(-90, 90)
	end
	e.Parent = part
	local l = Instance.new("PointLight")
	l.Color = d.glow
	l.Range = 9 * strength
	l.Brightness = 1.2
	l.Shadows = false
	l.Parent = part
end

-- glowing cracks (fire, storm, void, stone)
local function cracks(t: BasePart, d, quad: boolean)
	if d.element ~= "fire" and d.element ~= "storm" and d.element ~= "void" and d.element ~= "stone" then
		return
	end
	local g = d.glow
	local z = if quad then 1.28 else -0.54
	for _, s in { 1, -1 } do
		glowPart(seg(t, V(s * 0.2, 0.8, z), V(s * 0.7, 0.2, z), 0.07, g, NEON, 0.04))
		glowPart(seg(t, V(s * 0.7, 0.2, z), V(s * 0.3, -0.4, z), 0.07, g, NEON, 0.04))
		glowPart(seg(t, V(s * 0.3, -0.4, z), V(s * 0.6, -0.9, z), 0.06, g, NEON, 0.04))
	end
end

local function hornsOn(head: BasePart, d, quad: boolean)
	local c = rgb(222, 212, 190)
	if d.element == "void" then
		c = rgb(30, 24, 34)
	elseif d.element == "frost" then
		c = rgb(220, 240, 255)
	end
	local up = if quad then V(0, 0.4, 1) else V(0, 1, 0.2)
	if d.horns == "pair" then
		for _, s in { 1, -1 } do
			spike(head, V(s * 0.4, HH - 0.1, 0), V(s * 0.6, up.Y, up.Z), 0.9, 0.2, c, M.Slate, 3)
		end
	elseif d.horns == "curl" then
		H.horns(head, c, true, 2.2)
	elseif d.horns == "crown" then
		for i = -2, 2 do
			spike(head, V(i * 0.2, HH - 0.05, 0.1), V(i * 0.3, 1, 0.3), 0.5 - math.abs(i) * 0.08, 0.13, c, M.Slate, 2)
		end
	elseif d.horns == "tusks" then
		for _, s in { 1, -1 } do
			H.curve(head, V(s * 0.3, -0.35, -HH - 0.2), V(s * 0.3, 0.4, -1), V(1, 0, 0), -1.2, 0.8, 0.14, 0.06, c, M.Slate, 3)
		end
	end
end

-- tail from a point going in direction dir
local function tailOn(t: BasePart, d, from: Vector3, dir: Vector3, up: Vector3, len: number, w: number)
	local c = d.skin
	local pts = { from }
	local pos = from
	for i = 1, 4 do
		pos += dir * (len / 4) + up * (if i < 3 then 0.12 else -0.08) * len
		table.insert(pts, pos)
	end
	chain(t, pts, w, w * 0.35, shade(c, 0.95), d.skinMat)
	local tip = pts[#pts]
	if d.tail == "club" then
		box(t, tip.X - w, tip.X + w, tip.Y - w, tip.Y + w, tip.Z - w, tip.Z + w, shade(c, 0.7), M.Slate)
	elseif d.tail == "spiked" then
		for i = 2, #pts do
			spike(t, pts[i], up, 0.35 * w / 0.3, 0.1, rgb(220, 210, 190), M.Slate, 1)
		end
	elseif d.tail == "fan" then
		for k = -1, 1 do
			seg(t, tip, tip + dir * 0.6 + up:Cross(dir).Unit * k * 0.5, 0.12, d.accent, d.skinMat, 0.04)
		end
	end
end

local PLAN = {}

-- four-legged bodies: in torso space +Y is forward, +Z is the back (up), -Z the belly
local function quadBody(p, d, bulk: number, legBulk: number, lean: boolean?)
	local t = p.torso
	local sk = d.skin
	local mat = p.skinMat
	local model = t.Parent
	if model then
		model:SetAttribute("Quad", true)
	end
	-- body mass (wider, longer, a raised back)
	local w = 1.1 * bulk
	box(t, -w, w, -1.35 * bulk, 1.25 * bulk, -0.5 * bulk, 0.7 * bulk + 0.35, sk, mat)
	box(t, -w * 0.85, w * 0.85, -1.1 * bulk, 1.0 * bulk, 0.7 * bulk + 0.35, 0.95 * bulk + 0.35, shade(sk, 0.92), mat)
	box(t, -w * 0.8, w * 0.8, -1.1, 1.0, -0.62 * bulk, -0.5 * bulk, d.belly or shade(sk, 1.2), mat)
	-- neck / shoulders toward the head
	box(t, -0.7 * bulk, 0.7 * bulk, 0.8 * bulk, 1.5 * bulk, -0.2, 0.75 * bulk, shade(sk, 0.96), mat)
	-- legs: thicker limbs and feet (arms are the front legs)
	for _, list in { p.arms, p.legs } do
		for _, l in list do
			local lb = legBulk
			box(l.part, -0.55 * lb, 0.55 * lb, -0.3, 1.0, -0.55 * lb, 0.55 * lb, shade(sk, 0.94), mat)
			box(l.part, -0.5 * lb, 0.5 * lb, -1.0, -0.3, -0.5 * lb, 0.5 * lb, shade(sk, 0.88), mat)
			local foot = if d.hide == "fur" or d.hide == "flesh" then shade(sk, 0.55) else rgb(40, 34, 30)
			box(l.part, -0.6 * lb, 0.6 * lb, -1.05, -0.8, -0.65 * lb, 0.45 * lb, foot, M.Slate)
			if not lean then
				-- claws
				for _, x in { -0.3, 0, 0.3 } do
					seg(l.part, V(x * lb, -0.95, -0.6 * lb), V(x * lb, -1.02, -0.85 * lb), 0.1, rgb(226, 216, 196), M.Slate)
				end
			end
		end
	end
	if lean then
		-- slender: ribs and a tucked waist
		for i = 0, 2 do
			box(t, -w * 1.02, w * 1.02, 0.4 - i * 0.35, 0.5 - i * 0.35, -0.3, 0.6, shade(sk, 1.15), mat)
		end
	end
	pattern(p, d, t, true)
	cracks(t, d, true)
	if d.spikes then
		for i = 0, 4 do
			local y = 1.0 - i * 0.5
			spike(t, V(0, y, 0.95 * bulk + 0.35), V(0, -0.25, 1), (0.7 - i * 0.06) * bulk, 0.22, shade(sk, 0.6), M.Slate, 2)
		end
	end
	if d.mane then
		for i, pt in { { -0.6, 1.2, 0.6 }, { 0.6, 1.2, 0.6 }, { 0, 1.35, 0.9 }, { -0.5, 1.0, -0.1 }, { 0.5, 1.0, -0.1 } } do
			add(t, V(0.8, 0.6, 0.7) * bulk, CF(pt[1] * bulk, pt[2] * bulk, pt[3]) * ANG(0.3, 0.25 * i, 0), shade(d.patternColor or sk, 0.8 + (i % 3) * 0.1), M.Fabric)
		end
	end
	tailOn(t, d, V(0, -1.3 * bulk, 0.5), V(0, -1, 0), V(0, 0, 1), (if d.tail == "stub" then 0.8 else 2.6) * bulk, 0.34 * bulk)
end

-- a beast head: snout, jaw, eyes (head space: -Z is the face)
local function quadHead(p, d, snout: number, maw: boolean)
	local head = p.head
	local sk = d.skin
	local mat = p.skinMat
	p.noFace = true
	head.Color = sk
	head.Material = mat
	box(head, -0.66, 0.66, 0.1, 0.4, -HH - 0.1, HH, shade(sk, 0.85), mat) -- brow
	box(head, -0.45, 0.45, -0.35, 0.15, -HH - snout, -HH + 0.1, sk, mat) -- snout
	box(head, -0.42, 0.42, -0.62, -0.38, -HH - snout * 0.9, -HH + 0.1, shade(sk, 0.8), mat) -- jaw
	box(head, -0.4, 0.4, -0.38, -0.33, -HH - snout * 0.92, -HH, rgb(40, 8, 16)) -- mouth
	box(head, -0.12, 0.12, 0.02, 0.14, -HH - snout - 0.04, -HH - snout + 0.02, rgb(20, 16, 18)) -- nose
	if maw then
		for i = 0, 3 do
			local x = -0.3 + i * 0.2
			box(head, x - 0.04, x + 0.04, -0.46, -0.3, -HH - snout * 0.9 + 0.02, -HH - snout * 0.9 + 0.1, rgb(236, 228, 206), M.Slate)
		end
	end
	eyesOn(p, head, d.eyes or 2, d.glowEye or d.glow, 0.24, -HH - 0.02, 0.36)
	-- ears
	if d.hide == "fur" then
		for _, s in { 1, -1 } do
			chain(head, { V(s * 0.4, HH - 0.05, 0.1), V(s * 0.55, HH + 0.35, 0.25), V(s * 0.55, HH + 0.55, 0.45) }, 0.3, 0.08, shade(sk, 0.85), mat, 0.4)
		end
	end
	hornsOn(head, d, true)
end

function PLAN.beast(p, d)
	quadBody(p, d, 1.25, 1.35, false)
	quadHead(p, d, 0.8, true)
	-- heavy shoulder hump
	box(p.torso, -1.0, 1.0, 0.3, 1.3, 0.9, 1.7, shade(d.skin, 0.9), p.skinMat)
end

function PLAN.stalker(p, d)
	quadBody(p, d, 0.95, 0.85, true)
	quadHead(p, d, 1.0, true)
end

function PLAN.critter(p, d)
	quadBody(p, d, 0.9, 0.7, true)
	local t = p.torso
	-- chitin segments and extra legs
	local sk = d.skin
	for i = 0, 2 do
		box(t, -1.05 + i * 0.05, 1.05 - i * 0.05, -1.2 + i * 0.85, -0.5 + i * 0.85, 0.6, 1.1, shade(sk, 0.85 + i * 0.1), p.skinMat)
	end
	local extra = math.max(0, (d.legsN or 4) - 4)
	for i = 1, extra do
		local s = if i % 2 == 0 then 1 else -1
		local y = 0.6 - math.floor((i - 1) / 2) * 0.8
		chain(t, { V(s * 0.9, y, -0.1), V(s * 1.9, y + 0.1, 0.5), V(s * 2.3, y, -1.9) }, 0.2, 0.08, shade(sk, 0.7), p.skinMat)
	end
	local head = p.head
	p.noFace = true
	head.Color = sk
	head.Material = p.skinMat
	-- mandibles
	for _, s in { 1, -1 } do
		chain(head, { V(s * 0.35, -0.35, -HH), V(s * 0.45, -0.5, -HH - 0.4), V(s * 0.15, -0.55, -HH - 0.7) }, 0.14, 0.06, rgb(40, 30, 26), M.Slate)
	end
	eyesOn(p, head, math.max(d.eyes or 4, 4), d.glow, 0.25, -HH - 0.02, 0.35)
	-- antennae
	for _, s in { 1, -1 } do
		chain(head, { V(s * 0.25, HH, -0.3), V(s * 0.5, HH + 0.7, -0.9), V(s * 0.7, HH + 0.9, -1.5) }, 0.06, 0.03, shade(sk, 0.6), M.SmoothPlastic)
	end
end

function PLAN.shell(p, d)
	quadBody(p, d, 1.1, 1.2, false)
	quadHead(p, d, 0.55, true)
	local t = p.torso
	local sh = if d.element then d.accent else shade(d.skin, 0.6)
	-- a stepped shell with ridges
	box(t, -1.45, 1.45, -1.6, 1.4, 1.0, 1.5, sh, M.Slate)
	box(t, -1.2, 1.2, -1.3, 1.1, 1.5, 1.95, shade(sh, 1.1), M.Slate)
	box(t, -0.8, 0.8, -0.9, 0.7, 1.95, 2.3, shade(sh, 1.2), M.Slate)
	for i = -1, 1 do
		box(t, i * 0.7 - 0.08, i * 0.7 + 0.08, -1.5, 1.3, 1.5, 1.6, shade(sh, 0.7), M.Slate)
	end
	if d.spikes then
		for _, pt in { { -0.9, 0.6 }, { 0.9, 0.6 }, { -0.9, -0.6 }, { 0.9, -0.6 }, { 0, 0 } } do
			spike(t, V(pt[1], pt[2], 1.9), V(pt[1] * 0.3, 0, 1), 0.6, 0.24, rgb(220, 210, 190), M.Slate, 2)
		end
	end
end

function PLAN.bird(p, d)
	local t, head = p.torso, p.head
	local sk = d.skin
	local mat = p.skinMat
	local model = t.Parent
	if model then
		model:SetAttribute("Flying", true)
	end
	p.noFace = true
	-- round feathered body with a pale breast
	box(t, -1.05, 1.05, -1.1, 1.0, -0.6, 0.62, sk, mat)
	box(t, -0.8, 0.8, -0.8, 0.8, -0.66, -0.6, d.belly or shade(sk, 1.3), mat)
	pattern(p, d, t, false)
	-- head: crest and beak
	head.Color = sk
	head.Material = mat
	local beakC = if d.element == "void" then rgb(30, 26, 34) else rgb(214, 170, 70)
	box(head, -0.2, 0.2, -0.2, 0.08, -HH - 0.55, -HH + 0.05, beakC, M.SmoothPlastic)
	box(head, -0.12, 0.12, -0.25, -0.05, -HH - 0.8, -HH - 0.5, shade(beakC, 0.8), M.SmoothPlastic)
	eyesOn(p, head, math.min(d.eyes or 2, 4), d.glow, 0.18, -HH - 0.02, 0.36)
	for i = -1, 1 do
		add(head, V(0.12, 0.9 - math.abs(i) * 0.2, 0.3), CF(i * 0.18, HH + 0.35, 0.25) * ANG(-0.7, 0, i * 0.2), d.accent, mat)
	end
	-- wings on the arms: feathers sweep back from the arm's rear edge
	for _, a in p.arms do
		a.part.Color = shade(sk, 0.9)
		a.part.Material = mat
		for i = 0, 4 do
			local len = 2.1 - i * 0.22
			add(a.part, V(0.08, len, 0.55), CF(0, 0.2 - i * 0.12 - len * 0.2, 0.5 + i * 0.42), if i % 2 == 0 then shade(sk, 0.85) else d.accent, mat)
		end
		add(a.part, V(0.1, 0.6, 1.8), CF(0, -0.9, 1.3), shade(sk, 0.7), mat)
	end
	-- tail feathers
	for k = -1, 1 do
		add(t, V(0.45, 1.6, 0.08), CF(k * 0.4, -1.6, 0.45) * ANG(0.9, 0, k * 0.25), if k == 0 then d.accent else shade(sk, 0.8), mat)
	end
	-- thin legs with talons (the real leg blocks are hidden)
	for _, l in p.legs do
		l.part.Transparency = 1
		seg(l.part, V(0, 0.9, 0), V(0, -0.6, 0.1), 0.2, beakC, M.SmoothPlastic)
		for _, x in { -0.2, 0, 0.2 } do
			seg(l.part, V(0, -0.6, 0.1), V(x, -0.95, -0.35), 0.1, rgb(40, 36, 30), M.Slate)
		end
	end
	elementFx(p, d, t, 0.7)
end

function PLAN.spirit(p, d)
	local t, head = p.torso, p.head
	local g = d.glow
	local shell = if d.element == "stone" then rgb(100, 94, 88) elseif d.element == "frost" then rgb(200, 230, 245) elseif d.element == "fire" then rgb(46, 30, 28) else shade(d.skin, 0.8)
	local shellMat = if d.element == "frost" then M.Glacier elseif d.element == "fire" then M.Basalt else M.Slate
	local model = t.Parent
	if model then
		model:SetAttribute("Hover", true)
	end
	p.noFace = true
	hideAll({ t, head, p.ra, p.la, p.rl, p.ll })
	-- a glowing core wrapped in drifting shell plates
	glowPart(add(t, V(1.2, 1.2, 1.2), CF(0, 0.2, 0) * ANG(0.6, 0.6, 0), g, NEON))
	glowPart(add(t, V(0.8, 0.8, 0.8), CF(0, 0.2, 0) * ANG(0.2, 1.1, 0.4), shade(g, 1.4), NEON, { Transparency = 0.3 }))
	local r = RNG.new(d.seed or 7)
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2
		local off = V(math.cos(a) * 0.95, r:float(-0.7, 1.0), math.sin(a) * 0.7)
		add(t, V(r:float(0.4, 0.8), r:float(0.4, 0.9), r:float(0.3, 0.6)), CF(off) * ANG(r:float(0, 3), r:float(0, 3), r:float(0, 3)), Palette.jitter(shell, 0.1, r:float()), shellMat)
	end
	-- a mask for a face
	add(head, V(0.9, 0.9, 0.2), CF(0, 0, -0.2), shade(shell, 1.1), shellMat)
	eyesOn(p, head, math.min(d.eyes or 2, 3), rgb(255, 255, 255), 0.1, -0.31, 0.25)
	-- floating fists
	for _, a in p.arms do
		add(a.part, V(0.7, 0.7, 0.7), CF(0, -0.8, 0) * ANG(0.5, 0.5, 0), shell, shellMat)
		glowPart(add(a.part, V(0.3, 0.3, 0.3), CF(0, -0.8, 0) * ANG(0.2, 0.9, 0.3), g, NEON))
		add(a.part, V(0.5, 0.5, 0.5), CF(0, 0.2, 0) * ANG(0.3, 0.2, 0.8), shell, shellMat)
	end
	-- wisps trailing below
	for i = 0, 2 do
		glowPart(add(t, V(0.3, 1.2, 0.05), CF(-0.5 + i * 0.5, -1.8, (i - 1) * 0.2) * ANG(0.1 * i, 0.4 * i, 0.1), g, NEON, { Transparency = 0.55 }))
	end
	elementFx(p, d, t, 1.2)
end

function PLAN.gazer(p, d)
	local t, head = p.torso, p.head
	local sk = d.skin
	local mat = p.skinMat
	local model = t.Parent
	if model then
		model:SetAttribute("Hover", true)
	end
	p.noFace = true
	hideAll({ head, p.ra, p.la, p.rl, p.ll })
	-- a floating bloated body, one huge eye
	t.Transparency = 1
	box(t, -1.2, 1.2, -0.9, 1.3, -1.1, 1.1, sk, mat)
	box(t, -0.95, 0.95, 1.3, 1.6, -0.9, 0.9, shade(sk, 0.9), mat)
	box(t, -0.95, 0.95, -1.2, -0.9, -0.9, 0.9, shade(sk, 0.85), mat)
	box(t, -0.72, 0.72, -0.4, 0.95, -1.18, -1.1, rgb(236, 232, 222), M.SmoothPlastic)
	local iris = glowPart(box(t, -0.36, 0.36, -0.05, 0.6, -1.22, -1.17, d.glow, NEON))
	table.insert(p.eyes, iris)
	box(t, -0.14, 0.14, 0.14, 0.42, -1.25, -1.21, rgb(10, 8, 10))
	pattern(p, d, t, false)
	-- small side eyes
	for _, s in { 1, -1 } do
		glowPart(box(t, s * 0.9 - 0.12, s * 0.9 + 0.12, 0.9, 1.1, -1.12, -1.08, d.glow, NEON))
	end
	-- tentacles hanging from the belly (the arms swing two of them)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		local base = V(math.cos(a) * 0.7, -1.1, math.sin(a) * 0.6)
		chain(t, { base, base + V(0.1, -1.0, 0.1), base + V(-0.15, -1.9, 0.25), base + V(0.1, -2.6, 0.1) }, 0.28, 0.08, shade(sk, 0.8), mat)
	end
	for _, arm in p.arms do
		chain(arm.part, { V(0, 0.6, 0), V(arm.s * 0.2, -0.6, -0.2), V(arm.s * 0.1, -1.6, -0.5) }, 0.26, 0.08, shade(sk, 0.75), mat)
	end
	elementFx(p, d, t, 1)
end

function PLAN.golem(p, d)
	local t, head = p.torso, p.head
	local stoneC = if d.element == "frost" then rgb(190, 220, 236) elseif d.element == "fire" then rgb(56, 44, 42) elseif d.element == "void" then rgb(36, 30, 44) else shade(d.skin, 1.05)
	local mat = if d.element == "frost" then M.Glacier elseif d.element == "fire" then M.Basalt else M.Slate
	p.noFace = true
	for _, part in { t, head, p.ra, p.la, p.rl, p.ll } do
		part.Color = stoneC
		part.Material = mat
	end
	-- boulder torso and huge shoulders
	box(t, -1.25, 1.25, -0.6, 1.2, -0.72, 0.8, stoneC, mat)
	box(t, -1.0, 1.0, -1.05, -0.5, -0.6, 0.62, shade(stoneC, 0.9), mat)
	for _, a in p.arms do
		box(a.part, -0.75, 0.75, 0.2, 1.35, -0.75, 0.75, shade(stoneC, 0.92), mat)
		box(a.part, -0.7, 0.7, -1.2, -0.45, -0.7, 0.7, shade(stoneC, 1.08), mat) -- fists
	end
	for _, l in p.legs do
		box(l.part, -0.62, 0.62, -1.05, 0.2, -0.62, 0.62, shade(stoneC, 0.95), mat)
	end
	-- a small head sunk between the shoulders
	box(head, -0.5, 0.5, -0.3, 0.3, -HH - 0.1, -HH + 0.2, shade(stoneC, 0.7), mat)
	eyesOn(p, head, math.min(d.eyes or 2, 3), d.glow, 0.0, -HH - 0.12, 0.26)
	cracks(t, d, false)
	if d.element == "frost" then
		for i = 1, 4 do
			add(t, V(0.3, 0.9 - i * 0.1, 0.3), CF(-0.9 + i * 0.5, 1.2, 0.3) * ANG(0.5, 0, (i - 2.5) * 0.3), rgb(200, 240, 255), M.Glacier)
		end
	end
	elementFx(p, d, t, 1)
end

function PLAN.horror(p, d)
	local t = p.torso
	local sk = d.skin
	H.monsterFace(p, d, { fangs = 4 + (d.seed or 1) % 3 })
	H.claws(p, 3, 0.7, rgb(220, 210, 190), 0.4)
	H.toeClaws(p, rgb(220, 210, 190))
	pattern(p, d, t, false)
	cracks(t, d, false)
	if d.spikes then
		H.backSpikes(t, 4, 0.9, -0.5, 0.6, 0.22, shade(sk, 0.55), 0.55)
	end
	hornsOn(p.head, d, false)
	if d.tail ~= "stub" then
		tailOn(t, d, V(0, -0.8, 0.5), V(0, -0.45, 1).Unit, V(0, 1, 0), 2.4, 0.3)
	end
	if d.element then
		elementFx(p, d, t, 0.8)
	end
	-- extra eyes glow on the chest for many-eyed horrors
	if (d.eyes or 2) >= 4 then
		for i = 1, 3 do
			glowPart(H.front(t, -0.45 + i * 0.22 - 0.06, -0.45 + i * 0.22 + 0.06, 0.3, 0.42, 0, d.glow, NEON, 0.04))
		end
	end
end

Rig.KIND.beast = function(p, d)
	local f = PLAN[d.plan or "horror"] or PLAN.horror
	f(p, d)
	p.noFace = true
	-- element glow on the eyes
	if d.glowEye then
		for _, e in p.eyes do
			if e and e:IsA("BasePart") then
				e.Color = d.glowEye
			end
		end
	end
end

return Beasts
