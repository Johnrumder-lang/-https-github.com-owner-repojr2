--!nonstrict
-- THE RANDOM STORY - global tuning values. Everything gameplay-related lives here.
local Config = {}

Config.VERSION = "v4"
Config.GAME_NAME = "THE RANDOM STORY"
Config.DATASTORE = "TheRandomStory_v1"

Config.Player = {
	baseHealth = 100,
	healthPerPoint = 14,
	baseDamage = 16,
	damagePerPoint = 0.07, -- +7% per point
	gravity = 128, -- workspace gravity (Roblox default 196.2): floaty, Ultrakill-like air time
	walkSpeed = 26, -- Ultrakill-fast base run
	sprintMult = 1.35, -- hold SHIFT after a dash
	jumpPower = 50, -- ~9.8 studs high at gravity 128
	doubleJumpPower = 46,
	dashSpeed = 132,
	dashTime = 0.24, -- ~32 studs per dash
	dashCharges = 3,
	dashRecharge = 0.8,
	dashIframes = 0.26,
	dashStabRadius = 4.2, -- dashing through an enemy stabs it
	dashStabMult = 0.9, -- x weapon damage
	slideSpeed = 62, -- slide keeps going while CTRL is held
	slideTime = 0.8,
	slideMaxTime = 2.2,
	slideMin = 34,
	slamSpeed = 170, -- CTRL in the air
	slamMinHeight = 2.2, -- studs above the floor needed to start a slam
	slamJump = 1.6, -- jump right after a slam goes higher
	wallJumps = 3,
	wallJumpUp = 48,
	wallJumpOut = 40,
	coyote = 0.13,
	jumpBuffer = 0.14,
	airHang = 0.22, -- air attacks keep you floating
	flaskCharges = 3,
	flaskHeal = 0.45,
	parryWindow = 0.24,
	parryCooldown = 0.32,
	blockReduction = 0.3,
	riposteMult = 1.6,
	respawnDelay = 3.5,
}

Config.TimeStop = {
	baseDuration = 2.0, -- the gift: two whole seconds
	durationPerPoint = 0.25,
	baseCooldown = 14,
	cooldownPerPoint = 0.6,
	minCooldown = 4,
	maxDuration = 12,
	parryRefund = 1.0, -- seconds of cooldown removed by a perfect parry
	blessingDuration = 2.0, -- added by the Old God's power
	blessingCooldownMult = 0.8,
	ragdollThreshold = 34, -- stored knockback above this launches a ragdoll
}

Config.Combat = {
	comboWindow = 0.55,
	launchUp = 64, -- heavy attacks launch light targets into the air
	juggleUp = 24, -- every hit on an airborne target keeps it up
	finisherKnock = 70, -- 3rd combo hit sends people flying (ragdoll)
	heavyChargeTime = 0.38,
	heavyMult = 1.9,
	finisherMult = 1.3,
	baseKnockback = 12,
	heavyKnockback = 58,
	ragdollKnockback = 38,
	critMult = 1.75,
	hitstop = 0.055,
	killLaunch = 1.35, -- death knockback multiplier (normal hits)
	heavyKillLaunch = 2.6, -- heavy / finisher kills send bodies flying
	knockdownAt = 38, -- living targets hit harder than this fall over (animation, no ragdoll)
	maxAttackersPerTarget = 2,
	postureRegen = 12,
}

Config.XP = {
	pointsPerLevel = 2,
	maxLevel = 120,
}
function Config.xpForLevel(level: number): number
	return math.floor(45 * level ^ 1.42 + 20)
end

Config.Abilities = {
	AetherStep = { key = "F", cooldown = 2.2, distance = 34 },
	VoidSlash = { key = "G", cooldown = 5.5, damage = 2.4, speed = 130, range = 120 },
	-- spells (Z / X): a blood-fire rune that erupts and launches, a web of storm lightning
	FlameRune = { key = "Z", cooldown = 6, damage = 2.2, radius = 11, delay = 0.65, range = 70, launch = 62, level = 3 },
	StormWeb = { key = "X", cooldown = 9, damage = 1.4, radius = 34, chains = 5, stun = 1.1, level = 6 },
	Slam = { damage = 1.1, radius = 12, launch = 46 },
}

-- Sound bank. rbxasset:// files ship with every Roblox client. Swap in your own
-- rbxassetid:// ids here to upgrade the audio without touching any other code.
Config.Sounds = {
	Swing = { id = "rbxasset://sounds/swordslash.wav", vol = 0.55 },
	SwingHeavy = { id = "rbxasset://sounds/swordlunge.wav", vol = 0.7 },
	Equip = { id = "rbxasset://sounds/unsheath.wav", vol = 0.6 },
	Hit = { id = "rbxasset://sounds/swordlunge.wav", vol = 0.6 },
	Flesh = { id = "rbxasset://sounds/splat.wav", vol = 0.7 },
	Parry = { id = "rbxasset://sounds/electronicpingshort.wav", vol = 0.9 },
	Block = { id = "rbxasset://sounds/collide.wav", vol = 0.8 },
	-- the old swoosh.wav clipped and played far too long: dashes use a short, pitched-up blade whoosh
	Dash = { id = "rbxasset://sounds/swordslash.wav", vol = 0.42, len = 0.32 },
	DashStab = { id = "rbxasset://sounds/swordlunge.wav", vol = 0.75, len = 0.5 },
	Jump = { id = "rbxasset://sounds/action_jump.mp3", vol = 0.4 },
	Land = { id = "rbxasset://sounds/action_jump_land.mp3", vol = 0.5 },
	Step = { id = "rbxasset://sounds/action_footsteps_plastic.mp3", vol = 0.25 },
	TimeStop = { id = "rbxasset://sounds/bass.wav", vol = 1 },
	TimeResume = { id = "rbxasset://sounds/swordlunge.wav", vol = 0.8, len = 0.7 },
	Tick = { id = "rbxasset://sounds/clickfast.wav", vol = 0.6 },
	Click = { id = "rbxasset://sounds/button.wav", vol = 0.5 },
	Pickup = { id = "rbxasset://sounds/electronicpingshort.wav", vol = 0.6 },
	LevelUp = { id = "rbxasset://sounds/victory.wav", vol = 0.6 },
	Explosion = { id = "rbxasset://sounds/collide.wav", vol = 1 },
	Rumble = { id = "rbxasset://sounds/bass.wav", vol = 1 },
	Glass = { id = "rbxasset://sounds/glassbreak.wav", vol = 0.8 },
	Horn = { id = "rbxasset://sounds/bass.wav", vol = 1 },
	Death = { id = "rbxasset://sounds/uuhhh.mp3", vol = 0.5 },
	Magic = { id = "rbxasset://sounds/electronicpingshort.wav", vol = 0.5 },
	Chest = { id = "rbxasset://sounds/switch.wav", vol = 0.7 },
	Door = { id = "rbxasset://sounds/switch.wav", vol = 0.6 },
	Eat = { id = "rbxasset://sounds/splat.wav", vol = 0.3 },
	Type = { id = "rbxasset://sounds/clickfast.wav", vol = 0.4 },
	Phone = { id = "rbxasset://sounds/electronicpingshort.wav", vol = 0.7 },
	Roar = { id = "rbxasset://sounds/bass.wav", vol = 1 },
	Heartbeat = { id = "rbxasset://sounds/bass.wav", vol = 0.5 },
	Laser = { id = "rbxasset://sounds/Rocket shot.wav", vol = 0.6 },
	Shatter = { id = "rbxasset://sounds/glassbreak.wav", vol = 1 },
	Teleport = { id = "rbxasset://sounds/swordslash.wav", vol = 0.55, len = 0.35 },
	Flask = { id = "rbxasset://sounds/action_swim.mp3", vol = 0.5 },
	Slam = { id = "rbxasset://sounds/collide.wav", vol = 1 },
	WallJump = { id = "rbxasset://sounds/action_jump.mp3", vol = 0.55 },
	Splat = { id = "rbxasset://sounds/splat.wav", vol = 0.35 },
	Mumble = { id = "rbxasset://sounds/clickfast.wav", vol = 0.12 },
	SlideLoop = { id = "rbxasset://sounds/action_swim.mp3", vol = 0.35 },
	Kill = { id = "rbxasset://sounds/splat.wav", vol = 0.9 },
	Rune = { id = "rbxasset://sounds/bass.wav", vol = 0.9 },
	Lightning = { id = "rbxasset://sounds/electronicpingshort.wav", vol = 0.8 },
	Countdown = { id = "rbxasset://sounds/clickfast.wav", vol = 0.8 },
	Fight = { id = "rbxasset://sounds/victory.wav", vol = 0.7 },
}

-- Optional music ids (leave empty to play no music).
Config.Music = {
	Menu = "",
	Calm = "",
	Combat = "",
	Boss = "",
	Final = "",
	Ending = "",
}

-- UI palette (v3, gothic dark fantasy): near-black ink, bone text, blood red,
-- tarnished gold ornaments, time-stop violet.
Config.Colors = {
	-- ink (backgrounds)
	Ink = Color3.fromRGB(10, 9, 12),
	Ink2 = Color3.fromRGB(16, 14, 18),
	Ink3 = Color3.fromRGB(26, 23, 28),
	-- bone (text)
	Bone = Color3.fromRGB(232, 226, 214),
	BoneDim = Color3.fromRGB(168, 160, 146),
	BoneFaint = Color3.fromRGB(110, 104, 96),
	-- blood (accents, health)
	Blood = Color3.fromRGB(170, 24, 32),
	BloodBright = Color3.fromRGB(226, 48, 52),
	BloodDeep = Color3.fromRGB(74, 8, 14),
	-- tarnished gold (ornaments)
	Gold = Color3.fromRGB(190, 160, 95),
	GoldBright = Color3.fromRGB(236, 208, 142),
	GoldDeep = Color3.fromRGB(104, 84, 46),
	-- time stop
	Violet = Color3.fromRGB(170, 150, 255),
	VioletDeep = Color3.fromRGB(64, 52, 124),
	-- feedback
	Good = Color3.fromRGB(138, 204, 120),
	Bad = Color3.fromRGB(230, 90, 84),
	-- legacy keys (kept for older code)
	UIBack = Color3.fromRGB(10, 9, 12),
	UIPanel = Color3.fromRGB(16, 14, 18),
	UIEdge = Color3.fromRGB(190, 160, 95),
	UIAccent = Color3.fromRGB(170, 24, 32),
	UIWarn = Color3.fromRGB(226, 48, 52),
	UIGold = Color3.fromRGB(190, 160, 95),
	Health = Color3.fromRGB(170, 24, 32),
	HealthBack = Color3.fromRGB(28, 8, 10),
	TimeStop = Color3.fromRGB(170, 150, 255),
	XP = Color3.fromRGB(190, 160, 95),
}

-- UI layout: everything is authored at this reference resolution and scaled.
Config.UI = {
	refWidth = 1920,
	refHeight = 1080,
	smallScreenBias = 0.85, -- scale^bias below 1 so 720p text stays readable
	styleRanks = { "DULL", "CRUEL", "BRUTAL", "SAVAGE", "SADISTIC", "MERCILESS", "TIME-BREAKER" },
	styleThresholds = { 0, 90, 220, 400, 640, 940, 1300 },
	styleMax = 1700,
}

return Config
