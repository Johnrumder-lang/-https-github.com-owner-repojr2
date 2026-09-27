--!nonstrict
-- Colour palettes for the cubic art style.
local Palette = {}
local rgb = Color3.fromRGB

Palette.skin = {
	rgb(255, 224, 196), rgb(241, 194, 160), rgb(224, 172, 132), rgb(198, 140, 100),
	rgb(160, 106, 72), rgb(120, 78, 52), rgb(92, 58, 38),
}
Palette.hair = {
	rgb(30, 26, 24), rgb(58, 40, 28), rgb(96, 62, 36), rgb(150, 100, 56), rgb(214, 180, 110),
	rgb(236, 220, 170), rgb(170, 60, 40), rgb(120, 120, 128), rgb(230, 230, 235), rgb(64, 52, 90),
}
Palette.cloth = {
	rgb(52, 62, 88), rgb(92, 40, 40), rgb(46, 86, 60), rgb(120, 96, 60), rgb(70, 70, 76),
	rgb(150, 130, 100), rgb(84, 60, 110), rgb(40, 40, 46), rgb(170, 60, 50), rgb(60, 110, 140),
	rgb(200, 190, 170), rgb(110, 80, 50),
}
Palette.modernCloth = {
	rgb(40, 44, 60), rgb(210, 210, 215), rgb(180, 50, 60), rgb(60, 120, 200), rgb(30, 30, 34),
	rgb(90, 140, 90), rgb(230, 190, 60), rgb(120, 70, 150), rgb(250, 120, 60), rgb(80, 80, 90),
}
Palette.metal = {
	iron = rgb(140, 145, 155), steel = rgb(185, 190, 200), dark = rgb(60, 62, 70),
	gold = rgb(236, 190, 70), bronze = rgb(176, 120, 70), silver = rgb(215, 220, 230),
}
Palette.wood = { rgb(120, 82, 50), rgb(98, 66, 40), rgb(140, 100, 62), rgb(78, 52, 32) }
Palette.stone = { rgb(128, 128, 132), rgb(110, 108, 112), rgb(146, 142, 138), rgb(96, 96, 104) }

Palette.blood = {
	red = rgb(160, 12, 24),
	purple = rgb(130, 40, 200),
	green = rgb(80, 190, 40),
	bone = rgb(225, 220, 205),
	black = rgb(24, 10, 26),
	gold = rgb(255, 214, 90),
	void = rgb(20, 0, 30),
	blue = rgb(40, 120, 230),
}

Palette.rarity = {
	Common = rgb(190, 190, 195),
	Uncommon = rgb(90, 220, 100),
	Rare = rgb(70, 150, 255),
	Epic = rgb(190, 90, 255),
	Legendary = rgb(255, 170, 40),
	Divine = rgb(255, 250, 200),
}

Palette.element = {
	Fire = rgb(255, 110, 30),
	Frost = rgb(140, 220, 255),
	Void = rgb(150, 60, 255),
	Holy = rgb(255, 240, 160),
	Blood = rgb(220, 20, 40),
	Storm = rgb(120, 200, 255),
}

-- Biomes: every land picks one of these.
Palette.biomes = {
	Meadow = {
		grass = { rgb(98, 168, 72), rgb(88, 156, 64), rgb(110, 178, 80), rgb(80, 146, 60) },
		dirt = rgb(120, 86, 58), rock = rgb(128, 126, 122), sand = rgb(220, 204, 150),
		water = rgb(60, 130, 200), leaves = { rgb(70, 140, 60), rgb(60, 128, 52), rgb(92, 160, 64) },
		trunk = rgb(100, 70, 44), flowers = { rgb(240, 80, 90), rgb(250, 220, 80), rgb(240, 240, 250), rgb(170, 110, 230) },
		fog = rgb(190, 215, 235), sky = "day", treeKind = "oak",
	},
	Autumn = {
		grass = { rgb(170, 140, 70), rgb(160, 120, 60), rgb(180, 150, 80), rgb(150, 110, 56) },
		dirt = rgb(110, 76, 50), rock = rgb(120, 116, 110), sand = rgb(200, 180, 130),
		water = rgb(70, 110, 150), leaves = { rgb(220, 110, 40), rgb(200, 70, 40), rgb(240, 170, 50), rgb(170, 60, 40) },
		trunk = rgb(80, 56, 36), flowers = { rgb(240, 200, 60), rgb(200, 90, 40) },
		fog = rgb(230, 190, 150), sky = "dusk", treeKind = "oak",
	},
	Desert = {
		grass = { rgb(230, 200, 140), rgb(220, 190, 130), rgb(238, 210, 150), rgb(214, 182, 124) },
		dirt = rgb(190, 140, 90), rock = rgb(180, 120, 80), sand = rgb(240, 214, 160),
		water = rgb(40, 170, 190), leaves = { rgb(90, 150, 70), rgb(120, 160, 60) },
		trunk = rgb(150, 110, 70), flowers = { rgb(250, 120, 160) },
		fog = rgb(240, 220, 180), sky = "hot", treeKind = "cactus",
	},
	Frost = {
		grass = { rgb(236, 240, 248), rgb(226, 232, 244), rgb(244, 246, 252), rgb(216, 224, 238) },
		dirt = rgb(130, 140, 160), rock = rgb(120, 130, 146), sand = rgb(210, 220, 235),
		water = rgb(120, 180, 230), leaves = { rgb(40, 90, 70), rgb(50, 100, 80), rgb(220, 235, 245) },
		trunk = rgb(80, 64, 50), flowers = { rgb(160, 220, 255) },
		fog = rgb(220, 230, 245), sky = "cold", treeKind = "pine",
	},
	Swamp = {
		grass = { rgb(80, 100, 60), rgb(70, 90, 54), rgb(90, 110, 66), rgb(64, 84, 50) },
		dirt = rgb(70, 60, 44), rock = rgb(90, 96, 88), sand = rgb(120, 110, 80),
		water = rgb(60, 90, 60), leaves = { rgb(60, 90, 50), rgb(80, 100, 40), rgb(50, 70, 40) },
		trunk = rgb(60, 50, 40), flowers = { rgb(180, 220, 80), rgb(200, 120, 220) },
		fog = rgb(130, 150, 120), sky = "murk", treeKind = "willow",
	},
	Volcanic = {
		grass = { rgb(60, 50, 48), rgb(50, 42, 40), rgb(70, 58, 54), rgb(44, 36, 34) },
		dirt = rgb(40, 30, 28), rock = rgb(34, 30, 32), sand = rgb(90, 60, 50),
		water = rgb(255, 100, 20), leaves = { rgb(70, 40, 30), rgb(40, 30, 28) },
		trunk = rgb(30, 24, 22), flowers = { rgb(255, 120, 30), rgb(255, 200, 60) },
		fog = rgb(120, 60, 40), sky = "ash", treeKind = "dead", lavaWater = true,
	},
	Crystal = {
		grass = { rgb(110, 150, 170), rgb(100, 140, 160), rgb(120, 160, 180), rgb(94, 130, 150) },
		dirt = rgb(80, 80, 110), rock = rgb(100, 100, 130), sand = rgb(190, 190, 220),
		water = rgb(140, 100, 230), leaves = { rgb(180, 120, 255), rgb(120, 220, 255), rgb(255, 150, 220) },
		trunk = rgb(70, 70, 100), flowers = { rgb(120, 255, 230), rgb(255, 120, 255) },
		fog = rgb(180, 170, 230), sky = "aurora", treeKind = "crystal",
	},
	Mushroom = {
		grass = { rgb(120, 90, 130), rgb(110, 80, 120), rgb(130, 100, 140), rgb(100, 72, 110) },
		dirt = rgb(80, 60, 70), rock = rgb(100, 90, 100), sand = rgb(170, 150, 160),
		water = rgb(90, 160, 170), leaves = { rgb(220, 60, 60), rgb(240, 140, 60), rgb(170, 90, 220) },
		trunk = rgb(230, 220, 200), flowers = { rgb(120, 255, 180), rgb(255, 255, 140) },
		fog = rgb(150, 120, 160), sky = "dusk", treeKind = "mushroom",
	},
	-- cold green coast of the north: longhouses, longships, cliffs over grey water
	Fjord = {
		grass = { rgb(92, 138, 84), rgb(84, 128, 78), rgb(104, 148, 90), rgb(76, 118, 72) },
		dirt = rgb(104, 88, 70), rock = rgb(116, 120, 126), sand = rgb(196, 188, 164),
		water = rgb(40, 90, 130), leaves = { rgb(46, 96, 70), rgb(58, 110, 76), rgb(84, 130, 70) },
		trunk = rgb(86, 66, 50), flowers = { rgb(240, 240, 250), rgb(170, 110, 230), rgb(250, 220, 80) },
		fog = rgb(190, 205, 220), sky = "cold", treeKind = "pine", pine = rgb(40, 80, 60),
	},
	-- the forest of giant trees
	Giantwood = {
		grass = { rgb(84, 150, 62), rgb(74, 138, 56), rgb(96, 160, 70), rgb(66, 124, 50) },
		dirt = rgb(104, 76, 50), rock = rgb(118, 116, 108), sand = rgb(200, 186, 140),
		water = rgb(56, 120, 150), leaves = { rgb(58, 126, 50), rgb(46, 110, 44), rgb(76, 144, 56), rgb(40, 96, 40) },
		trunk = rgb(104, 76, 52), flowers = { rgb(250, 220, 80), rgb(240, 240, 250) },
		fog = rgb(180, 205, 190), sky = "day", treeKind = "oak",
	},
	Evil = {
		grass = { rgb(38, 26, 30), rgb(30, 20, 24), rgb(46, 30, 34), rgb(26, 16, 20) },
		dirt = rgb(28, 18, 20), rock = rgb(24, 20, 26), sand = rgb(60, 30, 30),
		water = rgb(140, 10, 20), leaves = { rgb(60, 10, 20), rgb(30, 10, 14) },
		trunk = rgb(16, 12, 14), flowers = { rgb(200, 20, 30), rgb(120, 20, 160) },
		fog = rgb(70, 20, 30), sky = "hell", treeKind = "dead", lavaWater = true,
	},
}

function Palette.jitter(c: Color3, amount: number, r: number): Color3
	-- r in [0,1) from caller's RNG so it stays deterministic
	local f = 1 + (r * 2 - 1) * amount
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end

function Palette.shade(c: Color3, f: number): Color3
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end

function Palette.invert(c: Color3): Color3
	return Color3.new(1 - c.R, 1 - c.G, 1 - c.B)
end

return Palette
