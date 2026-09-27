--!nonstrict
-- Enemy archetypes. Shared so the client knows attack types for telegraphs.
-- Attack kinds:
--   normal      parryable, blockable
--   heavy       UNPARRYABLE (red flash) -> dash or get out of range
--   sweep       low sweep -> slide under it (or jump)
--   grab        unblockable grab -> dash away
--   lunge       closes distance fast, parryable
--   projectile  ranged, parry reflects it
--   aoe         ground burst around a point, dash out
local Palette = require(script.Parent.Palette)
local Enemies = {}
local rgb = Color3.fromRGB

local function atk(base, o)
	local t = table.clone(base)
	for k, v in o or {} do
		t[k] = v
	end
	return t
end

local A = {
	slash = { id = "Slash", anim = "SlashR", w = 0.45, a = 0.14, r = 0.5, range = 7, arc = 100, dmg = 1, kb = 16, kind = "normal", cd = 0, weight = 3 },
	backslash = { id = "Backslash", anim = "SlashL", w = 0.38, a = 0.14, r = 0.45, range = 7, arc = 100, dmg = 0.9, kb = 14, kind = "normal", cd = 0, weight = 2 },
	overhead = { id = "Overhead", anim = "Overhead", w = 0.6, a = 0.14, r = 0.6, range = 7.5, arc = 60, dmg = 1.35, kb = 22, kind = "normal", cd = 1.5, weight = 2 },
	thrust = { id = "Thrust", anim = "Thrust", w = 0.5, a = 0.14, r = 0.5, range = 10, arc = 40, dmg = 1.1, kb = 18, kind = "normal", cd = 0.5, weight = 3 },
	claw = { id = "Claw", anim = "ClawR", w = 0.34, a = 0.12, r = 0.35, range = 6, arc = 100, dmg = 1, kb = 10, kind = "normal", cd = 0, weight = 3 },
	clawL = { id = "ClawL", anim = "ClawL", w = 0.3, a = 0.12, r = 0.35, range = 6, arc = 100, dmg = 0.9, kb = 10, kind = "normal", cd = 0, weight = 2 },
	pounce = { id = "Pounce", anim = "Pounce", w = 0.55, a = 0.25, r = 0.5, range = 16, minRange = 7, arc = 70, dmg = 1.3, kb = 24, kind = "lunge", lunge = 70, cd = 3, weight = 2 },
	slam = { id = "Slam", anim = "Slam", w = 0.95, a = 0.16, r = 0.9, range = 9, arc = 80, dmg = 1.8, kb = 45, kind = "heavy", cd = 3, weight = 2, shock = 12 },
	sweep = { id = "Sweep", anim = "Sweep", w = 0.85, a = 0.2, r = 0.75, range = 10, arc = 200, dmg = 1.4, kb = 30, kind = "sweep", cd = 4, weight = 1.5 },
	grab = { id = "Grab", anim = "Grab", w = 0.75, a = 0.2, r = 0.8, range = 7, arc = 60, dmg = 1.6, kb = 50, kind = "grab", cd = 6, weight = 1 },
	shoot = { id = "Shoot", anim = "Shoot", w = 0.75, a = 0.1, r = 0.55, range = 90, minRange = 10, arc = 30, dmg = 0.9, kb = 8, kind = "projectile", cd = 0.8, weight = 3, proj = { speed = 110, gravity = 18, size = 0.35, color = rgb(160, 120, 80), style = "arrow" } },
	bolt = { id = "Bolt", anim = "Cast", w = 0.7, a = 0.12, r = 0.6, range = 80, minRange = 8, arc = 40, dmg = 1.1, kb = 14, kind = "projectile", cd = 1.2, weight = 3, proj = { speed = 70, gravity = 0, size = 1.1, color = rgb(160, 90, 255), style = "orb" } },
	fireball = { id = "Fireball", anim = "Cast", w = 0.8, a = 0.12, r = 0.6, range = 80, minRange = 8, arc = 40, dmg = 1.3, kb = 22, kind = "projectile", cd = 1.8, weight = 3, proj = { speed = 62, gravity = 4, size = 1.4, color = rgb(255, 120, 40), style = "fire", explode = 8 } },
	nova = { id = "Nova", anim = "CastUp", w = 1.1, a = 0.2, r = 0.8, range = 14, arc = 360, dmg = 1.5, kb = 40, kind = "aoe", cd = 6, weight = 1.5, aoe = 13 },
	throw = { id = "Throw", anim = "Throw", w = 0.7, a = 0.1, r = 0.6, range = 70, minRange = 12, arc = 30, dmg = 1.2, kb = 25, kind = "projectile", cd = 3, weight = 1.5, proj = { speed = 75, gravity = 40, size = 1.6, color = rgb(120, 110, 100), style = "rock", explode = 6 } },
	stomp = { id = "Stomp", anim = "Stomp", w = 0.8, a = 0.15, r = 0.7, range = 12, arc = 360, dmg = 1.3, kb = 38, kind = "aoe", cd = 5, weight = 1.5, aoe = 12 },
	kick = { id = "Kick", anim = "Kick", w = 0.35, a = 0.12, r = 0.45, range = 6, arc = 70, dmg = 0.8, kb = 34, kind = "normal", cd = 2, weight = 1 },
	roar = { id = "Roar", anim = "Roar", w = 0.6, a = 0.8, r = 0.5, range = 20, arc = 360, dmg = 0.2, kb = 55, kind = "aoe", cd = 12, weight = 0.6, aoe = 18 },
}
Enemies.A = A
Enemies.atk = atk

-- look helpers --------------------------------------------------------------
local function monsterLook(skin, extra)
	local d = {
		race = "Monster",
		skin = skin,
		shirt = Palette.shade(skin, 0.8),
		pants = Palette.shade(skin, 0.7),
		outfit = "bare",
		hairStyle = "bald",
		mood = "monster",
		hunch = true,
		glow = rgb(255, 230, 90),
	}
	for k, v in extra or {} do
		d[k] = v
	end
	return d
end

Enemies.DEFS = {
	-- ================================================================ THE PIT
	Crawler = {
		name = "Crawler", team = "monster", blood = "purple", hp = 32, dmg = 8, speed = 22, aggro = 90, xp = 9, gold = { 1, 4 }, ai = "melee",
		look = monsterLook(rgb(70, 40, 90), { monster = "crawler", scale = 0.85, glow = rgb(210, 120, 255) }),
		attacks = { A.claw, A.clawL, atk(A.pounce, { dmg = 1.2 }) },
	},
	Ghoul = {
		name = "Ghoul", team = "monster", blood = "green", hp = 58, dmg = 12, speed = 18, aggro = 90, xp = 15, gold = { 2, 6 }, ai = "melee",
		look = monsterLook(rgb(98, 110, 88), { monster = "ghoul", rag = rgb(70, 64, 56), pants = rgb(60, 56, 50), glow = rgb(180, 255, 120) }),
		attacks = { A.claw, A.clawL, atk(A.overhead, { anim = "ClawR", dmg = 1.4 }) },
	},
	PitBrute = {
		name = "Pit Brute", team = "monster", blood = "purple", hp = 240, dmg = 22, speed = 13, aggro = 90, xp = 60, gold = { 8, 16 }, ai = "melee", poise = true, posture = 140,
		look = monsterLook(rgb(80, 70, 100), { monster = "brute", scale = 1.55, glow = rgb(255, 80, 80) }), weapon = "bigclub",
		attacks = { atk(A.slash, { dmg = 1.0 }), A.slam, A.sweep },
	},
	BoneArcher = {
		name = "Bone Archer", team = "monster", blood = "bone", hp = 36, dmg = 11, speed = 15, aggro = 110, xp = 14, gold = { 2, 6 }, ai = "ranged", keepAway = 28,
		look = { race = "Undead", outfit = "skeleton", hairStyle = "bald", shirt = rgb(222, 216, 196), pants = rgb(222, 216, 196), glow = rgb(120, 200, 255), quiver = true, hooded = rgb(54, 46, 40) },
		weapon = "bow", attacks = { A.shoot, atk(A.kick, { dmg = 0.6 }) },
	},
	Slime = {
		name = "Void Slime", team = "monster", blood = "green", hp = 70, dmg = 10, speed = 14, aggro = 70, xp = 16, gold = { 1, 5 }, ai = "slime", slime = { size = 5, color = rgb(90, 220, 90), splits = 2 },
		attacks = {},
	},
	SlimeSmall = {
		name = "Slimelet", team = "monster", blood = "green", hp = 22, dmg = 6, speed = 16, aggro = 70, xp = 4, gold = { 0, 2 }, ai = "slime", slime = { size = 2.6, color = rgb(120, 240, 110), splits = 0 },
		attacks = {},
	},
	Shade = {
		name = "Shade", team = "monster", blood = "purple", hp = 44, dmg = 13, speed = 17, aggro = 100, xp = 18, gold = { 3, 8 }, ai = "caster", keepAway = 24, blink = true,
		look = { race = "Monster", monster = "wraith", outfit = "cultist", shirt = rgb(30, 20, 44), accent = rgb(140, 60, 255), skin = rgb(40, 24, 60), mood = "hollow", glow = rgb(190, 110, 255), sigilGlow = true },
		attacks = { A.bolt, atk(A.nova, { dmg = 1.0, aoe = 10 }) },
	},
	Gnasher = {
		name = "Gnasher, the Hungry Dark", team = "monster", blood = "purple", hp = 780, dmg = 18, speed = 24, aggro = 140, xp = 220, gold = { 40, 70 }, ai = "melee", miniboss = true, poise = true, posture = 260,
		look = monsterLook(rgb(50, 20, 60), { monster = "gnasher", scale = 2.1, glow = rgb(255, 60, 200) }),
		attacks = { atk(A.claw, { range = 9 }), atk(A.clawL, { range = 9 }), atk(A.pounce, { range = 26, dmg = 1.5, lunge = 90 }), atk(A.roar, { cd = 10 }), atk(A.sweep, { anim = "Sweep", range = 11 }) },
	},
	PitWarden = {
		name = "The Pit Warden", team = "monster", blood = "purple", hp = 2400, dmg = 26, speed = 15, aggro = 200, xp = 700, gold = { 120, 180 }, ai = "melee", boss = true, poise = true, posture = 420,
		look = { race = "Monster", outfit = "knight", metal = rgb(70, 60, 60), armorMat = Enum.Material.CorrodedMetal, accent = rgb(90, 20, 30), skin = rgb(60, 40, 50), scale = 2.4, mood = "monster", glow = rgb(255, 60, 40), spiked = true, visorGlow = rgb(255, 60, 40), tattered = true, plume = false },
		weapon = "chainflail",
		attacks = {
			atk(A.slash, { range = 11, dmg = 1.0 }),
			atk(A.overhead, { range = 12, dmg = 1.3, kind = "heavy", w = 0.85 }),
			atk(A.sweep, { range = 14, dmg = 1.3 }),
			atk(A.slam, { range = 12, shock = 22, dmg = 1.6 }),
			atk(A.grab, { range = 10, dmg = 1.4 }),
			{ id = "Summon", anim = "Roar", w = 0.8, a = 0.4, r = 0.6, range = 60, arc = 360, dmg = 0, kb = 0, kind = "summon", cd = 18, weight = 1, summon = { "Crawler", 3 } },
		},
	},

	-- ================================================================ VILLAGES
	Villager = {
		name = "Villager", team = "human", blood = "red", hp = 45, dmg = 9, speed = 17, aggro = 80, xp = 10, gold = { 2, 8 }, ai = "melee", flee = 0.35,
		look = "villager", weapon = { "pitchfork", "torch", "club", "axe" },
		attacks = { atk(A.thrust, { range = 9, dmg = 0.9 }), atk(A.slash, { dmg = 0.9 }), atk(A.overhead, { dmg = 1.1 }) },
	},
	BeastVillager = {
		name = "Beastfolk", team = "human", blood = "red", hp = 60, dmg = 11, speed = 21, aggro = 90, xp = 14, gold = { 3, 9 }, ai = "melee", flee = 0.25,
		look = "beastVillager",
		attacks = { A.claw, A.clawL, atk(A.pounce, { dmg = 1.1 }) },
	},
	Militia = {
		name = "Militia Guard", team = "human", blood = "red", hp = 85, dmg = 13, speed = 17, aggro = 110, xp = 20, gold = { 5, 12 }, ai = "melee", parryChance = 0.12,
		look = "guard", weapon = "spear",
		attacks = { atk(A.thrust, { range = 11 }), atk(A.thrust, { id = "Thrust2", w = 0.35, dmg = 0.8 }), atk(A.sweep, { range = 11, dmg = 1.0 }) },
	},
	VillageCaptain = {
		name = "Captain of the Watch", team = "human", blood = "red", hp = 620, dmg = 18, speed = 19, aggro = 130, xp = 180, gold = { 40, 60 }, ai = "melee", miniboss = true, parryChance = 0.3, posture = 220,
		look = "captain", weapon = "sword",
		attacks = { A.slash, A.backslash, atk(A.overhead, { kind = "heavy" }), atk(A.thrust, { range = 12, kind = "lunge", lunge = 60 }), A.kick },
	},
	HedgeMage = {
		name = "Hedge Mage", team = "human", blood = "red", hp = 50, dmg = 14, speed = 15, aggro = 110, xp = 22, gold = { 6, 14 }, ai = "caster", keepAway = 26,
		look = "hedgeMage", weapon = "staff",
		attacks = { A.fireball, atk(A.nova, { dmg = 1.0 }) },
	},

	-- ================================================================ ARENA
	ArenaHound = {
		name = "Arena Ravager", team = "monster", blood = "green", hp = 70, dmg = 13, speed = 26, aggro = 200, xp = 18, gold = { 3, 8 }, ai = "melee",
		look = monsterLook(rgb(120, 70, 40), { monster = "hound", scale = 0.95, glow = rgb(255, 180, 60) }),
		attacks = { A.claw, A.clawL, atk(A.pounce, { range = 20, lunge = 85 }) },
	},
	ArenaChampion = {
		name = "Bramorr, Champion of the Pit", team = "monster", blood = "red", hp = 1600, dmg = 24, speed = 17, aggro = 250, xp = 420, gold = { 80, 120 }, ai = "melee", boss = true, poise = true, posture = 380,
		look = { race = "Beastkin", beast = "boar", outfit = "barbarian", skin = rgb(160, 110, 80), hair = rgb(70, 46, 30), scale = 1.9, mood = "angry" },
		weapon = "axe",
		attacks = { atk(A.slash, { range = 10 }), atk(A.overhead, { range = 10, kind = "heavy", dmg = 1.6 }), atk(A.sweep, { range = 12 }), atk(A.pounce, { anim = "Thrust", range = 30, lunge = 95, dmg = 1.4, kind = "heavy" }), A.roar, atk(A.stomp, { aoe = 14 }) },
	},

	-- ================================================================ CASTLE
	RoyalKnight = {
		name = "Royal Knight", team = "human", blood = "red", hp = 160, dmg = 20, speed = 17, aggro = 130, xp = 45, gold = { 10, 20 }, ai = "melee", parryChance = 0.3, blockChance = 0.25, posture = 160, armor = 0.15,
		look = "knight", weapon = "sword",
		attacks = { A.slash, A.backslash, A.overhead, atk(A.thrust, { kind = "lunge", lunge = 55, range = 13 }), A.kick },
	},
	RoyalMage = {
		name = "Royal Magus", team = "human", blood = "red", hp = 110, dmg = 20, speed = 16, aggro = 140, xp = 45, gold = { 12, 22 }, ai = "caster", keepAway = 30, blink = true,
		look = "royalMage", weapon = "staff",
		attacks = { atk(A.bolt, { proj = { speed = 85, gravity = 0, size = 1.0, color = rgb(120, 200, 255), style = "orb", count = 3, spread = 12 } }), A.fireball, A.nova },
	},
	RoyalGuard = {
		name = "Beastkin Royal Guard", team = "human", blood = "red", hp = 190, dmg = 22, speed = 20, aggro = 130, xp = 50, gold = { 10, 22 }, ai = "melee", posture = 180, armor = 0.1,
		look = "beastGuard", weapon = "halberd",
		attacks = { atk(A.thrust, { range = 12 }), atk(A.sweep, { range = 13 }), atk(A.overhead, { range = 11, kind = "heavy" }) },
	},
	DemonMerc = {
		name = "Demon Mercenary", team = "human", blood = "black", hp = 210, dmg = 24, speed = 20, aggro = 140, xp = 60, gold = { 14, 26 }, ai = "melee", parryChance = 0.18, posture = 200,
		look = { race = "Demon", outfit = "barbarian", accent = rgb(40, 20, 20), mood = "angry", glow = rgb(255, 200, 60), hairStyle = "mohawk", hair = rgb(20, 20, 20) },
		weapon = "axe",
		attacks = { A.slash, A.backslash, atk(A.fireball, { range = 60, w = 0.6 }), atk(A.slam, { dmg = 1.4 }) },
	},

	-- ================================================================ OPEN WORLD
	Goblin = {
		name = "Goblin", team = "monster", blood = "green", hp = 40, dmg = 10, speed = 23, aggro = 90, xp = 12, gold = { 3, 9 }, ai = "melee",
		look = { race = "Goblin", outfit = "barbarian", scale = 0.72, mood = "angry", hairStyle = "bald", hunch = true, furMantle = rgb(84, 70, 52), pants = rgb(58, 46, 36) }, weapon = "dagger",
		attacks = { atk(A.slash, { w = 0.3, dmg = 0.8 }), atk(A.backslash, { w = 0.28 }), atk(A.pounce, { dmg = 1.0 }) },
	},
	GoblinShaman = {
		name = "Goblin Shaman", team = "monster", blood = "green", hp = 42, dmg = 12, speed = 18, aggro = 100, xp = 16, gold = { 4, 10 }, ai = "caster", keepAway = 24,
		look = { race = "Goblin", outfit = "cultist", shirt = rgb(62, 70, 40), accent = rgb(200, 220, 60), scale = 0.75, mood = "angry", hunch = true, sigilGlow = true, extras = { "bones" } }, weapon = "staff",
		attacks = { atk(A.bolt, { proj = { speed = 70, gravity = 0, size = 1.0, color = rgb(160, 255, 60), style = "orb" } }), A.nova },
	},
	Orc = {
		name = "Orc Raider", team = "monster", blood = "red", hp = 150, dmg = 20, speed = 17, aggro = 100, xp = 36, gold = { 6, 16 }, ai = "melee", posture = 150,
		look = { race = "Orc", outfit = "barbarian", scale = 1.18, mood = "angry", hairStyle = "mohawk", hair = rgb(20, 20, 20), furMantle = rgb(70, 58, 46), pants = rgb(52, 42, 34), extras = { "chains" } }, weapon = "axe",
		attacks = { A.slash, A.overhead, atk(A.slam, { dmg = 1.5 }), A.kick },
	},
	Bandit = {
		name = "Bandit", team = "human", blood = "red", hp = 75, dmg = 14, speed = 19, aggro = 100, xp = 18, gold = { 8, 20 }, ai = "melee", parryChance = 0.1,
		look = "bandit", weapon = "sword",
		attacks = { A.slash, A.backslash, A.kick },
	},
	BanditArcher = {
		name = "Bandit Archer", team = "human", blood = "red", hp = 55, dmg = 13, speed = 17, aggro = 120, xp = 18, gold = { 8, 18 }, ai = "ranged", keepAway = 32,
		look = "bandit", weapon = "bow",
		attacks = { A.shoot, A.kick },
	},
	SkeletonKnight = {
		name = "Skeleton Knight", team = "monster", blood = "bone", hp = 130, dmg = 18, speed = 15, aggro = 100, xp = 32, gold = { 5, 14 }, ai = "melee", parryChance = 0.15, posture = 140,
		look = { race = "Undead", outfit = "skeleton", armor = rgb(96, 92, 90), accent = rgb(70, 22, 26), hairStyle = "bald", glow = rgb(120, 220, 255) }, weapon = "sword",
		attacks = { A.slash, A.overhead, A.thrust },
	},
	Necromancer = {
		name = "Necromancer", team = "monster", blood = "red", hp = 90, dmg = 18, speed = 15, aggro = 120, xp = 40, gold = { 10, 24 }, ai = "caster", keepAway = 28, blink = true,
		look = { race = "Human", outfit = "cultist", shirt = rgb(24, 30, 26), accent = rgb(60, 150, 90), skin = rgb(176, 186, 176), mood = "grim", glow = rgb(80, 255, 140), sigilGlow = true, extras = { "bones", "runes" } }, weapon = "staff",
		attacks = { atk(A.bolt, { proj = { speed = 60, gravity = 0, size = 1.2, color = rgb(80, 255, 140), style = "orb", homing = 1.6 } }), { id = "Raise", anim = "CastUp", w = 1.0, a = 0.3, r = 0.6, range = 60, arc = 360, dmg = 0, kb = 0, kind = "summon", cd = 14, weight = 1, summon = { "SkeletonKnight", 2 } } },
	},
	Lizardman = {
		name = "Lizardfolk Warrior", team = "monster", blood = "green", hp = 110, dmg = 17, speed = 20, aggro = 100, xp = 28, gold = { 5, 14 }, ai = "melee", posture = 120,
		look = { race = "Lizard", outfit = "barbarian", accent = rgb(60, 50, 40), pants = rgb(60, 48, 36), mood = "angry", noMantle = true, extras = { "bones" } }, weapon = "spear",
		attacks = { atk(A.thrust, { range = 11 }), atk(A.sweep, { range = 11, dmg = 1.1 }), A.pounce },
	},
	FrostTroll = {
		name = "Frost Troll", team = "monster", blood = "blue", hp = 420, dmg = 28, speed = 14, aggro = 100, xp = 90, gold = { 12, 30 }, ai = "melee", poise = true, posture = 300,
		look = { race = "Orc", monster = "troll", skin = rgb(136, 164, 190), outfit = "barbarian", accent = rgb(220, 228, 236), scale = 1.7, mood = "angry", hairStyle = "wild", hair = rgb(222, 230, 238), hunch = true }, weapon = "bigclub",
		attacks = { A.slash, A.slam, A.sweep, A.throw },
	},
	Cultist = {
		name = "Cultist", team = "monster", blood = "red", hp = 80, dmg = 16, speed = 18, aggro = 100, xp = 22, gold = { 5, 14 }, ai = "melee",
		look = { race = "Human", outfit = "cultist", shirt = rgb(34, 24, 30), mood = "grim" }, weapon = "dagger",
		attacks = { atk(A.slash, { w = 0.32 }), atk(A.backslash, { w = 0.3 }), atk(A.pounce, { dmg = 1.1 }) },
	},
	CultPriest = {
		name = "Cult Priest", team = "monster", blood = "red", hp = 95, dmg = 19, speed = 15, aggro = 120, xp = 34, gold = { 8, 20 }, ai = "caster", keepAway = 26,
		look = { race = "Human", outfit = "cultist", shirt = rgb(60, 10, 16), accent = rgb(200, 160, 60), mood = "grim", glow = rgb(255, 200, 60), sigilGlow = true, extras = { "runes" } }, weapon = "staff",
		attacks = { A.fireball, A.nova },
	},
	Imp = {
		name = "Imp", team = "monster", blood = "black", hp = 48, dmg = 12, speed = 26, aggro = 100, xp = 16, gold = { 3, 8 }, ai = "melee", blink = true,
		look = { race = "Demon", monster = "imp", outfit = "bare", scale = 0.7, mood = "monster", glow = rgb(255, 220, 60), hairStyle = "bald", hunch = true },
		attacks = { A.claw, A.clawL, atk(A.fireball, { range = 50, dmg = 0.9, proj = { speed = 70, gravity = 0, size = 0.9, color = rgb(255, 120, 40), style = "fire" } }) },
	},
	DemonKnight = {
		name = "Demon Knight", team = "monster", blood = "black", hp = 320, dmg = 30, speed = 18, aggro = 120, xp = 85, gold = { 14, 34 }, ai = "melee", parryChance = 0.25, posture = 260, armor = 0.2,
		look = { race = "Demon", outfit = "knight", metal = rgb(52, 40, 44), accent = rgb(130, 18, 26), scale = 1.25, glow = rgb(255, 80, 40), spiked = true, visorGlow = rgb(255, 90, 40), runes = rgb(255, 90, 40), tattered = true, plume = false, capeColor = rgb(40, 14, 18), bigHorns = true }, weapon = "sword",
		attacks = { A.slash, A.backslash, atk(A.overhead, { kind = "heavy" }), atk(A.thrust, { kind = "lunge", lunge = 70, range = 14 }), atk(A.sweep, { range = 11 }) },
	},
	DemonCaster = {
		name = "Hellspeaker", team = "monster", blood = "black", hp = 160, dmg = 26, speed = 16, aggro = 130, xp = 60, gold = { 12, 28 }, ai = "caster", keepAway = 30, blink = true,
		look = { race = "Demon", outfit = "cultist", shirt = rgb(40, 10, 14), accent = rgb(160, 40, 24), glow = rgb(255, 120, 40), sigilGlow = true, mood = "monster", extras = { "runes" } }, weapon = "staff",
		attacks = { atk(A.fireball, { proj = { speed = 70, gravity = 2, size = 1.4, color = rgb(255, 80, 30), style = "fire", explode = 9, count = 3, spread = 14 } }), A.nova },
	},
	Hellbrute = {
		name = "Hellbrute", team = "monster", blood = "black", hp = 700, dmg = 34, speed = 15, aggro = 120, xp = 150, gold = { 20, 44 }, ai = "melee", poise = true, posture = 420,
		look = { race = "Demon", monster = "hellbrute", outfit = "barbarian", accent = rgb(30, 20, 20), furMantle = rgb(40, 30, 28), scale = 1.9, mood = "monster", glow = rgb(255, 160, 40), bigHorns = true, hornCurl = 2.4, hunch = true }, weapon = "bigclub",
		attacks = { A.slash, A.slam, A.sweep, A.grab, A.roar },
	},
	Werewolf = {
		name = "Werewolf", team = "monster", blood = "red", hp = 180, dmg = 22, speed = 27, aggro = 110, xp = 48, gold = { 6, 16 }, ai = "melee", posture = 160,
		look = { race = "Beastkin", beast = "wolf", monster = "werewolf", outfit = "bare", hair = rgb(84, 70, 58), skin = rgb(84, 70, 58), pants = rgb(62, 54, 46), scale = 1.3, mood = "monster", glow = rgb(255, 230, 90), hunch = true },
		attacks = { A.claw, A.clawL, atk(A.pounce, { lunge = 90, range = 22 }), atk(A.sweep, { anim = "ClawR" }) },
	},
	Fungoid = {
		name = "Fungoid", team = "monster", blood = "green", hp = 90, dmg = 14, speed = 15, aggro = 80, xp = 20, gold = { 3, 10 }, ai = "melee",
		look = { race = "Monster", monster = "fungoid", skin = rgb(222, 212, 192), shirt = rgb(176, 50, 48), outfit = "bare", mood = "calm", hairStyle = "bald", glow = rgb(140, 255, 200), skinMat = Enum.Material.SmoothPlastic, extras = {} },
		attacks = { A.slash, atk(A.nova, { anim = "Stomp", aoe = 9, dmg = 1.0 }) },
	},
	AbyssKnight = {
		name = "Abyssal Knight", team = "monster", blood = "void", hp = 520, dmg = 38, speed = 19, aggro = 140, xp = 140, gold = { 24, 50 }, ai = "melee", parryChance = 0.35, posture = 320, armor = 0.25,
		look = { race = "Demon", outfit = "knight", metal = rgb(34, 28, 40), accent = rgb(90, 20, 150), scale = 1.3, glow = rgb(190, 90, 255), skin = rgb(20, 10, 30), spiked = true, visorGlow = rgb(190, 90, 255), runes = rgb(170, 80, 255), tattered = true, plume = false, capeColor = rgb(16, 10, 24), hornColor = rgb(20, 16, 26), bigHorns = true }, weapon = "sword",
		attacks = { A.slash, A.backslash, atk(A.overhead, { kind = "heavy" }), atk(A.thrust, { kind = "lunge", lunge = 80, range = 16 }), atk(A.sweep, { range = 12 }) },
	},
	VoidShade = {
		name = "Void Shade", team = "monster", blood = "void", hp = 240, dmg = 32, speed = 22, aggro = 140, xp = 90, gold = { 16, 36 }, ai = "caster", keepAway = 22, blink = true,
		look = { race = "Monster", monster = "wraith", outfit = "cloak", shirt = rgb(10, 8, 14), mood = "hollow", glow = rgb(170, 80, 255), skin = rgb(12, 10, 16) },
		attacks = { atk(A.bolt, { proj = { speed = 95, gravity = 0, size = 1.0, color = rgb(170, 80, 255), style = "orb", count = 3, spread = 10, homing = 1.2 } }), A.nova, atk(A.slash, { w = 0.3 }) },
	},
	-- ================================================================ THE NORTH (fjords)
	Raider = {
		name = "Norse Raider", team = "human", blood = "red", hp = 110, dmg = 17, speed = 19, aggro = 110, xp = 26, gold = { 8, 22 }, ai = "melee", parryChance = 0.2, posture = 130,
		look = "raider", weapon = "axe",
		attacks = { A.slash, A.backslash, A.overhead, atk(A.kick, { kb = 40 }) },
	},
	RaiderArcher = {
		name = "Raider Bowman", team = "human", blood = "red", hp = 70, dmg = 15, speed = 18, aggro = 130, xp = 22, gold = { 8, 20 }, ai = "ranged", keepAway = 34,
		look = "bandit", weapon = "bow",
		attacks = { A.shoot, A.kick },
	},
	Berserker = {
		name = "Berserker", team = "human", blood = "red", hp = 240, dmg = 24, speed = 24, aggro = 120, xp = 60, gold = { 12, 30 }, ai = "melee", poise = true, posture = 220,
		look = "berserker", weapon = "axe",
		attacks = { atk(A.slash, { w = 0.32 }), atk(A.backslash, { w = 0.3 }), atk(A.overhead, { kind = "heavy" }), atk(A.pounce, { lunge = 85, range = 20 }), A.roar },
	},
	Draugr = {
		name = "Draugr", team = "monster", blood = "bone", hp = 150, dmg = 20, speed = 15, aggro = 100, xp = 36, gold = { 6, 16 }, ai = "melee", parryChance = 0.15, posture = 150,
		look = "draugr", weapon = "sword",
		attacks = { A.slash, A.overhead, A.thrust, atk(A.grab, { dmg = 1.2 }) },
	},
	-- ================================================================ THE GIANTWOOD
	Wanderer = {
		name = "Wandering Giant", team = "monster", blood = "red", hp = 460, dmg = 30, speed = 12, aggro = 120, xp = 120, gold = { 14, 32 }, ai = "melee", poise = true, posture = 600, giant = true,
		look = "giant",
		attacks = { atk(A.claw, { range = 15, arc = 100, kb = 40, w = 0.6 }), atk(A.grab, { range = 14, w = 0.9, dmg = 1.8 }), atk(A.stomp, { aoe = 16, range = 14 }), atk(A.slam, { range = 16, shock = 16 }) },
	},
	Deviant = {
		name = "Deviant Giant", team = "monster", blood = "red", hp = 300, dmg = 26, speed = 25, aggro = 150, xp = 110, gold = { 12, 30 }, ai = "melee", poise = true, posture = 400, giant = true,
		look = "deviant",
		attacks = { atk(A.claw, { range = 12, kb = 30 }), atk(A.pounce, { lunge = 120, range = 34, minRange = 10, dmg = 1.5 }), atk(A.sweep, { anim = "ClawR", range = 13 }) },
	},
	Hellhound = {
		name = "Hellhound", team = "monster", blood = "black", hp = 200, dmg = 28, speed = 30, aggro = 140, xp = 70, gold = { 10, 24 }, ai = "melee",
		look = monsterLook(rgb(46, 22, 20), { monster = "hound", scale = 1.0, glow = rgb(255, 120, 30), fire = rgb(255, 120, 30) }),
		attacks = { A.claw, A.clawL, atk(A.pounce, { lunge = 100, range = 24 }), atk(A.fireball, { anim = "Roar", range = 40, proj = { speed = 60, gravity = 0, size = 1.2, color = rgb(255, 100, 30), style = "fire" } }) },
	},
}

-- Look presets referenced by string.
Enemies.LOOKS = {
	villager = function(rng)
		local d = { race = "Human", outfit = rng:pick({ "peasant", "peasant", "farmer", "viking" }), mood = "angry" }
		d.skin = rng:pick(Palette.skin)
		d.hair = rng:pick(Palette.hair)
		d.hairStyle = rng:pick({ "short", "messy", "bald", "long", "bun", "ponytail" })
		d.shirt = rng:pick(Palette.cloth)
		d.pants = rng:pick(Palette.cloth)
		d.apron = if rng:chance(0.3) then rgb(220, 210, 190) else nil
		d.strawHat = rng:chance(0.3)
		if rng:chance(0.4) then
			d.beard = rng:pick({ "full", "stubble", "mustache" })
		end
		return d
	end,
	beastVillager = function(rng)
		local d = Enemies.LOOKS.villager(rng)
		d.race = "Beastkin"
		d.beast = rng:pick({ "wolf", "cat", "fox", "rabbit", "boar", "bear" })
		d.strawHat = false
		return d
	end,
	guard = function(rng)
		local d = Enemies.LOOKS.villager(rng)
		d.outfit = if rng:chance(0.5) then "guard" else "soldier"
		d.strawHat = false
		d.accent = rgb(40, 60, 140)
		d.gear = { Head = rng:pick({ "NasalHelm", "NasalHelm", "Spangenhelm" }), Offhand = if rng:chance(0.5) then "RoundShield" else nil, Feet = "Boots" }
		return d
	end,
	captain = function(rng)
		local d = Enemies.LOOKS.villager(rng)
		d.outfit = "knight"
		d.accent = rgb(170, 30, 40)
		d.scale = 1.15
		return d
	end,
	hedgeMage = function(rng)
		local d = Enemies.LOOKS.villager(rng)
		d.outfit = "mage"
		d.shirt = rng:pick({ rgb(90, 50, 120), rgb(40, 80, 110), rgb(110, 40, 40) })
		d.accent = rgb(230, 200, 90)
		d.strawHat = false
		return d
	end,
	knight = function(rng)
		local d = Enemies.LOOKS.villager(rng)
		d.outfit = "knight"
		d.accent = rgb(40, 60, 140)
		d.mood = "angry"
		d.gear = { Offhand = if rng:chance(0.6) then "KiteShield" else nil, Hands = "Gauntlets" }
		return d
	end,
	royalMage = function(rng)
		local d = Enemies.LOOKS.villager(rng)
		d.outfit = "mage"
		d.shirt = rgb(40, 50, 120)
		d.accent = rgb(240, 210, 110)
		return d
	end,
	beastGuard = function(rng)
		local d = Enemies.LOOKS.beastVillager(rng)
		d.outfit = "guard"
		d.accent = rgb(40, 60, 140)
		d.scale = 1.1
		return d
	end,
	bandit = function(rng)
		local d = Enemies.LOOKS.villager(rng)
		d.outfit = "viking"
		d.shirt = rng:pick({ rgb(60, 50, 40), rgb(40, 40, 40), rgb(70, 30, 30), rgb(90, 70, 50) })
		d.accent = rng:pick({ rgb(40, 40, 40), rgb(120, 30, 30), rgb(60, 60, 90) })
		d.hairStyle = rng:pick({ "braids", "wild", "undercut", "topknot", "long" })
		d.beard = rng:pick({ "braided", "full", "long" })
		d.furMantle = if rng:chance(0.5) then rgb(110, 90, 70) else nil
		d.extras = if rng:chance(0.3) then { "eyepatch" } else nil
		d.gear = { Head = if rng:chance(0.45) then rng:pick({ "NasalHelm", "HornedHelm", "WolfPelt" }) else nil, Offhand = if rng:chance(0.55) then "RoundShield" else nil, Chest = if rng:chance(0.25) then "Hauberk" else nil }
		return d
	end,
	raider = function(rng)
		local d = Enemies.LOOKS.bandit(rng)
		d.gear = { Head = rng:pick({ "NasalHelm", "Spangenhelm", "HornedHelm" }), Offhand = "RoundShield", Chest = rng:pick({ "Hauberk", "Gambeson", "Lamellar" }), Cloak = if rng:chance(0.4) then "FurCloak" else nil }
		return d
	end,
	scout = function(rng)
		local d = Enemies.LOOKS.villager(rng)
		d.outfit = "scout"
		d.mood = "determined"
		d.strawHat = false
		d.hairStyle = rng:pick({ "short", "undercut", "ponytail", "messy" })
		return d
	end,
	thrall = function(rng)
		local d = Enemies.LOOKS.villager(rng)
		d.outfit = "thrall"
		d.mood = rng:pick({ "sad", "scared", "neutral" })
		d.strawHat = false
		return d
	end,
	berserker = function(rng)
		local d = Enemies.LOOKS.bandit(rng)
		d.outfit = "barbarian"
		d.mood = "angry"
		d.furMantle = rgb(120, 96, 70)
		d.scale = 1.15
		d.hairStyle = rng:pick({ "wild", "braids", "undercut" })
		d.gear = { Head = if rng:chance(0.5) then "WolfPelt" else nil, Hands = "Bracers", Legs = "LegWraps" }
		return d
	end,
	draugr = function(rng)
		local d = Enemies.LOOKS.raider(rng)
		d.skin = rng:pick({ rgb(126, 138, 132), rgb(110, 122, 124), rgb(140, 146, 136) })
		d.hair = rgb(200, 204, 200)
		d.mood = "monster"
		d.glow = rgb(120, 220, 255)
		d.hunch = true
		d.shirt = Palette.shade(d.shirt or rgb(60, 50, 40), 0.7)
		d.extras = { "corpse", "tatters" }
		return d
	end,
	giant = function(rng)
		local skin = rng:pick(Palette.skin)
		return {
			race = "Human",
			outfit = "bare",
			skin = skin,
			shirt = skin,
			pants = Palette.shade(skin, 0.95),
			scale = rng:float(2.8, 3.6),
			mood = "titan",
			hairStyle = rng:pick({ "short", "messy", "bald", "long", "wild", "bun" }),
			hair = rng:pick(Palette.hair),
			hunch = rng:chance(0.4),
			eye = rgb(90, 70, 60),
			extras = { "giant" },
			}
	end,
	deviant = function(rng)
		local d = Enemies.LOOKS.giant(rng)
		d.scale = rng:float(2.3, 2.7)
		d.hunch = true
		d.eye = rgb(20, 20, 20)
		return d
	end,
	jarl = function(rng)
		local d = Enemies.LOOKS.villager(rng)
		d.outfit = "jarl"
		d.mood = "smug"
		d.hairStyle = rng:pick({ "long", "braids", "topknot" })
		d.beard = rng:pick({ "braided", "long" })
		d.accent = rgb(130, 30, 34)
		d.gear = { Head = if rng:chance(0.5) then "Circlet" else nil }
		return d
	end,
}

function Enemies.resolveLook(def, rng)
	local l = def.look
	if type(l) == "string" then
		return Enemies.LOOKS[l](rng)
	elseif type(l) == "function" then
		return l(rng)
	end
	return table.clone(l or {})
end

-- Named elite (miniboss) derived from a base archetype.
local ELITE_PRE = { "Gor", "Vex", "Mal", "Thra", "Kul", "Zar", "Ruk", "Bel", "Skar", "Or", "Nex", "Dra" }
local ELITE_SUF = { "bag", "ith", "gor", "zul", "ak", "oth", "mira", "enna", "ax", "ul", "ys" }
local ELITE_TITLE = { "the Flayer", "the Unbroken", "Bonegnaw", "the Red", "of a Thousand Scars", "the Hungry", "the Laughing", "Ironhide", "the Patient" }
function Enemies.elite(baseId, rng)
	-- accepts an archetype id or a def table (trait monsters)
	local b = if type(baseId) == "table" then baseId else Enemies.DEFS[baseId]
	if type(baseId) == "table" then
		baseId = b.name
	end
	local d = table.clone(b)
	d.name = rng:pick(ELITE_PRE) .. rng:pick(ELITE_SUF) .. " " .. rng:pick(ELITE_TITLE)
	d.hp = b.hp * 6
	d.dmg = b.dmg * 1.35
	d.xp = b.xp * 8
	d.gold = { b.gold[1] * 6, b.gold[2] * 8 }
	d.miniboss = true
	d.poise = true
	d.posture = (b.posture or 100) * 2.5
	d.baseId = baseId
	local look = Enemies.resolveLook(b, rng)
	look.scale = (look.scale or 1) * 1.3
	look.glowEye = rgb(255, 50, 50)
	d.look = look
	d.attacks = table.clone(b.attacks)
	table.insert(d.attacks, A.roar)
	return d
end

function Enemies.scaled(def, level: number)
	local lv = math.max(1, level or 1)
	return {
		hp = def.hp * (1 + 0.24 * (lv - 1)),
		dmg = def.dmg * (1 + 0.13 * (lv - 1)),
		xp = def.xp * (1 + 0.18 * (lv - 1)),
	}
end

return Enemies
