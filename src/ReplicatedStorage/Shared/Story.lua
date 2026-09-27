--!nonstrict
-- The story bible: every name, place and many details of a run come from the seed.
-- Story.lines(scene, bible) returns the dialogue for a scene: { {speaker, text}, ... }
local RNG = require(script.Parent.RNG)
local Util = require(script.Parent.Util)

local Story = {}

local SYL_A = { "al", "ven", "mor", "cal", "ith", "dra", "sel", "thar", "ul", "bry", "cor", "el", "fen", "gal", "hal", "is", "kar", "lor", "mar", "nor", "or", "par", "ren", "sar", "tor", "val", "wyn", "zer", "ae", "ly" }
local SYL_B = { "a", "e", "i", "o", "u", "ae", "ia", "ei", "ou", "y" }
local SYL_C = { "dor", "mere", "wyn", "ria", "gard", "heim", "moor", "vale", "reach", "thal", "dell", "mark", "ford", "crest", "spire", "holt", "fall", "shire" }

local FIRST = {
	"Aldric", "Bram", "Cedric", "Doran", "Edda", "Fenna", "Garrick", "Hilde", "Isolde", "Jorin", "Kael", "Lysa", "Mira", "Nils", "Orla", "Pell",
	"Quinn", "Rhea", "Soren", "Tamsin", "Ulric", "Vesna", "Wren", "Yara", "Zed", "Berta", "Corwin", "Dagny", "Elric", "Freya", "Gunnar", "Hollis",
	"Ivo", "Jessa", "Kit", "Lorne", "Maeve", "Nell", "Oswin", "Petra", "Rurik", "Sable", "Tobin", "Una", "Varric", "Wilma",
}
local BEAST_FIRST = { "Rook", "Fang", "Pip", "Ash", "Bristle", "Tuft", "Grim", "Hazel", "Juniper", "Moss", "Nettle", "Sorrel", "Thorn", "Wick", "Burr" }
local MODERN_FIRST = { "Kevin", "Dave", "Jessica", "Tyler", "Brenda", "Marco", "Linda", "Chad", "Priya", "Steve", "Tom", "Olga", "Mike", "Sandra", "Jens", "Ayşe" }
local MODERN_LAST = { "Miller", "Schmidt", "Novak", "Jensen", "Park", "Rossi", "Kowalski", "Becker", "Silva", "Moreau", "Tanaka", "Fischer" }

function Story.fantasyName(rng): string
	local n = rng:pick(SYL_A) .. rng:pick(SYL_B) .. (if rng:chance(0.6) then rng:pick(SYL_A) else "")
	return Util.titleCase(n)
end

function Story.placeName(rng): string
	return Util.titleCase(rng:pick(SYL_A) .. (if rng:chance(0.4) then rng:pick(SYL_B) else "") .. rng:pick(SYL_C))
end

function Story.personName(rng, beast: boolean?): string
	return if beast then rng:pick(BEAST_FIRST) else rng:pick(FIRST)
end

local BIOME_POOL = { "Autumn", "Desert", "Frost", "Swamp", "Volcanic", "Crystal", "Mushroom", "Fjord", "Giantwood" }
-- the saga lands: at least one of them is always on the road
local SAGA = { "Fjord", "Giantwood" }
Story.BIOME_INFO = {
	Meadow = { adj = "green", races = { "Human", "Beastkin" }, monsters = { "Goblin", "GoblinShaman", "Bandit", "BanditArcher", "Orc" }, boss = "Orc" },
	Autumn = { adj = "amber", races = { "Elf", "Beastkin" }, monsters = { "Werewolf", "Bandit", "BanditArcher", "Goblin", "Cultist" }, boss = "Werewolf" },
	Desert = { adj = "sunscorched", races = { "Lizard", "Human" }, monsters = { "Lizardman", "SkeletonKnight", "Bandit", "BanditArcher", "Necromancer" }, boss = "Lizardman" },
	Frost = { adj = "frozen", races = { "Human", "Beastkin" }, monsters = { "FrostTroll", "SkeletonKnight", "Werewolf", "Cultist", "CultPriest" }, boss = "FrostTroll" },
	Swamp = { adj = "drowned", races = { "Lizard", "Goblin" }, monsters = { "Lizardman", "Necromancer", "SkeletonKnight", "Fungoid", "GoblinShaman" }, boss = "Necromancer" },
	Volcanic = { adj = "burning", races = { "Orc", "Demon" }, monsters = { "Imp", "DemonKnight", "Orc", "Hellbrute", "DemonCaster" }, boss = "Hellbrute" },
	Crystal = { adj = "shimmering", races = { "Elf", "Human" }, monsters = { "Shade", "SkeletonKnight", "Cultist", "CultPriest", "Werewolf" }, boss = "Shade" },
	Mushroom = { adj = "spore-choked", races = { "Goblin", "Beastkin" }, monsters = { "Fungoid", "Goblin", "GoblinShaman", "Slime", "Ghoul" }, boss = "Fungoid" },
	Fjord = { adj = "wind-torn", races = { "Human", "Dwarf" }, monsters = { "Raider", "Berserker", "RaiderArcher", "Draugr", "Werewolf" }, boss = "Berserker" },
	Giantwood = { adj = "towering", races = { "Human", "Elf" }, monsters = { "Wanderer", "Deviant", "Bandit", "BanditArcher", "Werewolf" }, boss = "Wanderer" },
	Evil = { adj = "evil", races = { "Demon" }, monsters = { "AbyssKnight", "VoidShade", "Hellhound", "DemonKnight", "Imp", "DemonCaster", "Hellbrute" }, boss = "AbyssKnight" },
}

function Story.generate(seed: number, heroName: string?)
	local rng = RNG.new(seed)
	local b: any = { seed = seed }
	b.hero = heroName or "You"
	b.age = rng:int(24, 34)
	b.job = rng:pick({ "data entry clerk", "call-center agent", "junior accountant", "IT support technician", "insurance salesperson", "spreadsheet analyst" })
	b.company = rng:pick({ "Grayline Solutions", "Omnidata Ltd.", "Kessler & Sons Insurance", "Beige Box Systems", "Tedium Corp", "Paperstack GmbH" })
	b.crime = rng:pick({
		"stole money from a children's charity",
		"pocketed an entire school fundraiser",
		"took lunch money from kids. As an adult. Repeatedly",
		"embezzled donations meant for an orphanage",
		"sold fake raffle tickets at a children's hospital",
	})
	b.breakfast = rng:pick({ "cereal", "burnt toast", "cold pizza", "instant oatmeal", "a sad banana" })
	b.dinner = rng:pick({ "instant noodles", "a microwave burrito", "frozen pizza", "leftover rice" })
	b.club = rng:pick({ "NEON COFFIN", "CLUB VELVET", "BASSMENT", "AFTERLIFE", "PULSE", "THE ELEVENTH HOUR" })
	b.friend = rng:pick(MODERN_FIRST)
	b.bossName = rng:pick(MODERN_FIRST) .. " " .. rng:pick(MODERN_LAST)
	b.coworkers = { rng:pick(MODERN_FIRST), rng:pick(MODERN_FIRST), rng:pick(MODERN_FIRST) }
	b.truck = rng:pick({ "ISEKAI LOGISTICS", "KUN FREIGHT", "FATE EXPRESS", "DESTINY HAULING", "OTHERWORLD TRANSPORT" })
	b.news = rng:pick({ "CHANNEL 9", "CITY 24", "NBN LIVE", "METRO NEWS" })
	b.anchor = rng:pick(MODERN_FIRST) .. " " .. rng:pick(MODERN_LAST)
	b.weekday = rng:pick({ "Monday", "Tuesday", "Wednesday", "Thursday" })
	b.god = rng:pick({ "Aurelion", "Solmere", "Elyon", "Vaelith", "Oriel", "Caelum" })
	b.elder = rng:pick({ "Old Ohm", "Grandfather Tick", "the Clockmaker", "Aeonis the Forgotten" })
	b.otherGod = rng:pick({ "Nyx", "the Quiet One", "Mother Null", "Ilune" })
	b.kingdom = Story.placeName(rng)
	b.capital = b.kingdom
	b.king = rng:pick({ "Hadrian", "Osric", "Leopold", "Casimir", "Edmund", "Aurick" }) .. " " .. rng:pick({ "II", "III", "IV", "VII", "the Gilded", "the Bold" })
	b.archmage = rng:pick({ "Velyss", "Morgana", "Isandre", "Thessaly", "Ophira", "Caelith" })
	b.prisoner = rng:pick(BEAST_FIRST)
	b.prisonerBeast = rng:pick({ "wolf", "fox", "cat", "bear" })
	b.knight = "Sir " .. rng:pick(FIRST)
	b.captain = rng:pick(FIRST)
	b.titan = rng:pick({ "Gorathul", "Ymirax", "Moloch-Tar", "Vorhune", "Ashgrave" })
	b.titanTitle = rng:pick({ "the Kingdom-Eater", "the Walking Mountain", "Who Treads on Crowns", "the Hunger Beneath the Sky" })
	b.titanKind = rng:pick({ "stone", "flesh", "abyss" })
	b.power = rng:int(2, 5)
	b.announcer = rng:pick(FIRST)
	b.tavern = rng:pick({ "The Drunken Wyvern", "The Last Candle", "The Crooked Crown", "The Sleeping Titan" })

	-- lands
	local pool = rng:shuffle(table.clone(BIOME_POOL))
	-- land 2 is always a saga land (the fjords or the giant forest); the other one
	-- shows up later more often than not
	local first = rng:pick(SAGA)
	local other = if first == "Fjord" then "Giantwood" else "Fjord"
	local keepOther = rng:chance(0.7)
	local rest = {}
	for _, bn in pool do
		if bn ~= first and (bn ~= other or keepOther) then
			table.insert(rest, bn)
		end
	end
	pool = { first, rest[1], rest[2], rest[3] }
	b.lands = {}
	b.lands[1] = { name = "Kingdom of " .. b.kingdom, short = b.kingdom, biome = "Meadow", size = 1, level = 1 }
	for i = 2, 5 do
		local biome = pool[i - 1]
		local info = Story.BIOME_INFO[biome]
		b.lands[i] = {
			name = Util.titleCase(info.adj) .. " " .. rng:pick({ "Reaches of", "Wilds of", "Dominion of", "Marches of", "Realm of" }) .. " " .. Story.placeName(rng),
			short = Story.placeName(rng),
			biome = biome,
			town = Story.placeName(rng),
			lord = Story.personName(rng),
			size = i,
			level = 8 + (i - 2) * 8,
		}
	end
	b.lands[6] = { name = "The Evil Lands", short = "Evil Lands", biome = "Evil", town = "Last Light", size = 6, level = 44 }
	b.lands[1].town = b.kingdom
	return b
end

-- ------------------------------------------------------------------ dialogue
local function L(speaker, text)
	return { speaker = speaker, text = text }
end

local SCENES = {}

SCENES.wake = function(b)
	return {
		L("", "{weekday}. 7:02 AM."),
		L("You", "...Another day. The alarm didn't even bother ringing."),
		L("You", "Breakfast. Then work. Then... more work, probably."),
	}
end
SCENES.breakfast = function(b)
	return { L("You", "{breakfast}. Tastes like nothing. Just like yesterday.") }
end
SCENES.office_boss = function(b)
	return {
		L("{bossName}", "{hero}! You're four minutes late. That's four minutes of MY time."),
		L("{bossName}", "The quarterly report won't copy-paste itself. Go. Desk. Now."),
	}
end
SCENES.office_work = function(b)
	return { L("", "Type the keys before they vanish!") }
end
SCENES.office_done = function(b)
	return {
		L("{bossName}", "Five o'clock already? Hm. Overtime tomorrow. Don't make that face."),
		L("You", "Another day of {job} stuff. Riveting."),
	}
end
SCENES.coworker = function(b)
	return {
		{ L("{c1}", "Did you hear? Someone keeps stealing yogurts from the fridge. It's war now.") },
		{ L("{c2}", "I've been refreshing this spreadsheet for three hours. I think it's refreshing me.") },
		{ L("{c3}", "Going out tonight? Nah, me neither. Nobody here has a life.") },
		{ L("{c1}", "My horoscope says I'll meet a truck today. Weird, right? Probably means 'luck'.") },
	}
end
SCENES.dinner = function(b)
	return { L("You", "{dinner}. Gourmet.") }
end
SCENES.phone = function(b)
	return {
		L("{friend}", "yo {hero}"),
		L("{friend}", "{club} tonight. 11pm. no excuses this time"),
		L("You", "...Fine. Just once. Just this one time."),
	}
end
SCENES.crossing = function(b)
	return { L("You", "Just gotta cross the street...") }
end
SCENES.truck = function(b)
	return { L("You", "...Huh?") }
end
SCENES.news = function(b)
	return {
		L("{anchor}", "Breaking news from downtown tonight."),
		L("{anchor}", "{hero}, {age}, a {job} at {company}, was struck and killed by a {truck} truck while crossing the street."),
		L("{anchor}", "Police confirm the victim was under investigation after allegedly having {crime}."),
		L("{anchor}", "Neighbours describe {hero} as 'quiet' and 'honestly kind of annoying'."),
		L("{anchor}", "The truck driver is unharmed and reportedly 'not even that surprised'."),
		L("{anchor}", "In other news: a local cat has learned to open doors. Experts are concerned."),
	}
end
SCENES.god_intro = function(b)
	return {
		L("???", "Ah. You're awake. Or... whatever this is, after a truck."),
		L("{god}", "I am {god}. And I am kind. Truly — the kindest. Ask anyone. Well. Anyone left."),
		L("{god}", "Normally a soul like you would get a lovely blessing of their choosing."),
		L("{god}", "But let's be honest with each other, {hero}. You {crime}."),
		L("{god}", "And then you died on a {weekday}. On the way to a club called '{club}'."),
		L("{god}", "You deserved it. Frankly."),
		L("{god}", "Still... I am kind. So you get ONE ability. And no — you don't get to choose."),
	}
end
SCENES.god_choice = function(b)
	return {
		L("{god}", "Go on. Pick one. I'll pretend it matters."),
	}
end
SCENES.god_after = function(b)
	return {
		L("{god}", "No."),
		L("{god}", "You get Time Stop. One second of it. Use it wisely... or don't."),
		L("{god}", "I'll be watching, {hero}. From up here. In the white. I always am."),
		L("{god}", "Now go be someone's hero. Or someone's problem. Either is entertaining."),
	}
end
SCENES.summon = function(b)
	return {
		L("Court Mage", "The circle holds! Archmage, it WORKED!"),
		L("{archmage}", "Silence. ...A soul from another world. Welcome, Hero."),
		L("King {king}", "Hero! The world drowns in evil. Monsters rise in every land. You were summoned to free us."),
		L("{archmage}", "But first, the Appraisal. Place your hand on the crystal, Hero."),
	}
end
SCENES.appraisal = function(b)
	return {
		L("Court Mage", "It's... it's reading... Power level {power}...?"),
		L("Court Mage", "That can't be right. The average farmhand is TWELVE."),
		L("{archmage}", "Below a farmhand. Below a... chicken, probably."),
		L("{archmage}", "Skill: 'Time Stop'. Duration: one second. How... quaint."),
		L("King {king}", "A defective hero. After forty years of preparation."),
		L("King {king}", "Throw it into the Abyss beneath the castle. Let the monsters have their snack."),
		L("You", "Wait— wait, WAIT—"),
	}
end
SCENES.pit_wake = function(b)
	return {
		L("You", "...Ugh. Everything hurts."),
		L("You", "They threw me away. Like trash."),
		L("You", "Fine. If this is the bottom... there's only one way left to go."),
	}
end
SCENES.pit_sword = function(b)
	return { L("You", "A sword...? Next to a skeleton. Sorry, buddy. I need it more than you.") }
end
SCENES.warden = function(b)
	return {
		L("The Pit Warden", "Another scrap falls from the table above."),
		L("The Pit Warden", "Ten floors of my children you've butchered. I will hang your bones with the others."),
	}
end
SCENES.warden_dead = function(b)
	return {
		L("The Pit Warden", "Im...possible... the king said... you were... nothing..."),
		L("You", "The king says a lot of things."),
	}
end
SCENES.burst = function(b)
	return {
		L("You", "Sunlight. Finally."),
		L("You", "And there it is. The castle."),
		L("You", "{archmage}. King {king}. I'm coming for you."),
	}
end
SCENES.village_shouts = function(b)
	return {
		"It's the defective hero!",
		"The king said he'd be DEAD!",
		"Get your pitchforks!",
		"Protect the village!",
		"He crawled out of the Abyss!",
		"Kill it before it breeds!",
		"For the King!",
		"Run! RUN!",
		"You monster!",
		"My crops! My family!",
	}
end
SCENES.capture = function(b)
	return {
		L("{archmage}", "Well, well. The chicken crawled out of the Abyss."),
		L("{archmage}", "And look at the mess it made. An entire village. How dramatic."),
		L("You", "You threw me into a hole to die."),
		L("{archmage}", "And you didn't. Which makes you... interesting. Useful, even."),
		L("{archmage}", "Your little clock won't work in here, by the way. Sleep, Hero."),
	}
end
SCENES.cell_wake = function(b)
	return {
		L("{prisoner}", "Oi. You alive? You've been out for two days."),
		L("{prisoner}", "Name's {prisoner}. They caught me stealing bread. You? Let me guess — 'destroyed a village'?"),
		L("You", "...Something like that."),
		L("{prisoner}", "Ha! Then you're the entertainment. They'll make you fight in the Proving Pit. Eight rounds, they say."),
	}
end
SCENES.cell_talk = function(b)
	return {
		L("{prisoner}", "Eight rounds in the Pit. Survive them and maybe they let you go. Or maybe they don't. Nobody's ever survived to ask."),
		L("{prisoner}", "The kingdom's scared, you know. There's rumours. Something huge walking in the mountains. Big enough to step on a castle."),
		L("{prisoner}", "My grandma used to say there's more than one god. The loud one, up in the white... and the old ones, who are tired."),
		L("{prisoner}", "If you ever get out... go far. Past the five lands. They say the strongest thing in the world lives there, in a tower that never ends."),
	}
end
SCENES.arena_intro = function(b)
	return {
		L("Announcer {announcer}", "LORDS AND LADIES! Tonight in the Proving Pit..."),
		L("Announcer {announcer}", "The DEFECTIVE HERO! The CHICKEN FROM ANOTHER WORLD!"),
		L("Announcer {announcer}", "Eight rounds! Eight chances to die! Place your bets!"),
	}
end
SCENES.arena_taunts = function(b)
	return {
		"Round {n}! The crowd wants blood!",
		"Still standing? Round {n}, let's fix that!",
		"Round {n}! Somebody get this chicken a real monster!",
		"The odds just changed, folks! Round {n}!",
		"Round {n}! Our hero looks tired. Good!",
		"Round {n}! The Archmage herself is watching!",
		"Round {n}! We're running out of monsters, people!",
		"FINAL ROUND! Behold... BRAMORR, CHAMPION OF THE PIT!",
	}
end
SCENES.alarm = function(b)
	return {
		L("{knight}", "ARCHMAGE! YOUR MAJESTY! A colossal monster is attacking the kingdom!"),
		L("{knight}", "It's bigger than the castle — it's bigger than the MOUNTAINS—"),
		L("{archmage}", "...Impossible. Nothing that size has walked since the old gods slept."),
	}
end
SCENES.elder = function(b)
	return {
		L("???", "Hm. Hmmm. Oh dear. Another one of HIS toys."),
		L("{elder}", "Tossed about, spat on, and now about to be stepped on. You've had a week, haven't you?"),
		L("{elder}", "I'm {elder}. An old god. A tired one. I used to count the seconds of this world."),
		L("{elder}", "The loud one up in the white gave you a single second and called it kindness."),
		L("{elder}", "I have some power lying around. Spare change, really. I won't be needing it."),
		L("{elder}", "Your little clock will tick longer now. And your blade will cut deeper than any foot can stomp."),
		L("{elder}", "One more thing, child. When you reach the top of the world... remember who is watching."),
	}
end
SCENES.awaken = function(b)
	return { L("You", "...I can feel it. Every second. Every heartbeat.") }
end
SCENES.titan_dead = function(b)
	return {
		L("You", "Kingdom-Eater, huh."),
		L("You", "Now. Where were we. The castle."),
	}
end
SCENES.archmage_fight = function(b)
	return {
		L("{archmage}", "You killed the titan. You. The one-second chicken."),
		L("{archmage}", "Fine. Then I'll erase you myself — properly this time."),
	}
end
SCENES.archmage_dead = function(b)
	return {
		L("{archmage}", "I... measured you... wrong..."),
		L("You", "You measured me at all. That was your mistake."),
	}
end
SCENES.king = function(b)
	return {
		L("King {king}", "S-stay back! Guards! GUARDS!"),
		L("You", "There are no guards anymore."),
		L("King {king}", "Please... please. I have gold. Titles. My daughter's hand— anything!"),
		L("You", "Tell me something. Who is the strongest in this world?"),
		L("King {king}", "The strongest...? Past the five lands. In the Evil Lands, there is a tower with no top."),
		L("King {king}", "They say something sits at its peak. Something that has... been farming aura for a thousand years."),
		L("King {king}", "Please. I told you. Let me live. I'll... I'll remember this. I swear it."),
	}
end
SCENES.king_spared = function(b)
	return { L("King {king}", "Th-thank you. I won't forget. I swear on my crown, I won't forget.") }
end
SCENES.king_killed = function(b)
	return { L("You", "You threw me away. I'm just returning the favour.") }
end
SCENES.open_world = function(b)
	return {
		L("You", "The kingdom is broken. And beyond it... five lands. The Evil Lands at the end."),
		L("You", "A tower with no top. Let's go see who's sitting up there."),
	}
end
SCENES.tower_base_spared = function(b)
	return {
		L("King {king}", "Hero! I told you I'd remember. I brought what's left of my knights."),
		L("King {king}", "Take this. The Crown of Dawn. My family's blade. It should be in hands that show mercy."),
		L("King {king}", "Go. We'll hold the gate. Whatever sits up there... end it."),
	}
end
SCENES.tower_base_killed = function(b)
	return {
		L("Prince Alaric", "YOU. The murderer of my father!"),
		L("Prince Alaric", "I followed you through five lands. I will not let you reach the top!"),
	}
end
SCENES.hollow_intro = function(b)
	return {
		L("???", "..."),
		L("???", "So. You finally climbed all the way up. I've been waiting."),
		L("???", "Every monster you killed. Every village. Every second you stopped. I felt them all."),
		L("???", "Let's see how much aura you've farmed."),
	}
end
SCENES.hollow_kneel = function(b)
	return {
		L("???", "Heh... hah... Not bad. Not bad at all."),
		L("???", "You still don't get it, do you? Look closer."),
		L("You", "...That face."),
		L("The Hollow", "Yeah. It's yours. Colours flipped. Every choice you didn't make — I made them."),
		L("The Hollow", "I became the strongest. And it still wasn't enough to beat the strongest."),
		L("The Hollow", "So let me show you true power, pitiful human."),
	}
end
SCENES.hollow_extra_killed = function(b)
	return { L("The Hollow", "You killed a begging old man in his crown room. We're really not so different.") }
end
SCENES.hollow_extra_spared = function(b)
	return { L("The Hollow", "You spared a king. How sweet. I didn't. That's the difference between us. That's why I'm stronger.") }
end
SCENES.abnormality_dead = function(b)
	return { L("", "Its core is exposed. END IT.") }
end
SCENES.glitch = function(b)
	return {
		L("The Hollow", "W-wait— WAIT— listen to me—"),
		L("The Hollow", "It w-w-wasn't me— I was never the evil one— I was just the strongest thing it could build—"),
		L("The Hollow", "The one high up— h-high up in the white— it's all h-h-his st—"),
	}
end
SCENES.god_arrives = function(b)
	return {
		L("{god}", "Squish."),
		L("{god}", "Bravo! Truly, bravo. What a finale. I haven't been this entertained in centuries."),
		L("{god}", "The defective hero, thrown into a pit, rising to the top of the world. Chef's kiss."),
		L("{god}", "You've finished my little story, {hero}. So I'll be kind — as always — and let you choose how it ends."),
	}
end
SCENES.god_final_choice = function(b)
	return { L("{god}", "Save this world, delete it, or start a brand new story? Pick. I'm dying to know.") }
end
SCENES.god_fight = function(b)
	return {
		L("{god}", "...Oh? That option wasn't supposed to be visible."),
		L("{god}", "You want to fight ME? The one who wrote you? The one who gave you your second?"),
		L("{god}", "Very well. I'm kind. I'll let you try."),
	}
end
SCENES.god_phase2 = function(b)
	return {
		L("{god}", "Enough. You want to see what I really am?"),
		L("{god}", "Here. No light. No kindness. Just me."),
	}
end
SCENES.god_defeat = function(b)
	return {
		L("{god}", "You... you actually... hah. Hahaha."),
		L("{god}", "Do you know how many worlds I've written? How many heroes I've dropped in pits for fun?"),
		L("{god}", "The Hollow was right. I built him to be the strongest. I built YOU to lose to him."),
		L("{god}", "But you just kept... going. Every second I gave you, you took ten."),
		L("{god}", "Fine. If I can't end the story... nobody gets to live in it."),
	}
end
SCENES.void = function(b)
	return {
		L("You", "..."),
		L("You", "It's... gone. All of it."),
	}
end
SCENES.other_god = function(b)
	return {
		L("???", "Shh. It's alright."),
		L("{otherGod}", "I am {otherGod}. I watch the places between stories. You broke his pen, little one."),
		L("{otherGod}", "No one has ever done that. The world he burned... I can let it grow again. Without an author."),
		L("{otherGod}", "No more pits. No more trucks. Just a world, and you in it — for real this time."),
		L("{otherGod}", "Or you can refuse, and fall into a brand new random story. Your choice. Truly yours."),
	}
end

-- Ending texts: { title, lines }
Story.ENDINGS = {
	save = { title = "ENDING: THE KEEPER", lines = { "You chose to save the world.", "The lands heal slowly. Villages rebuild. Nobody thanks you — nobody knows.", "But you stay. And for once, every second is yours." } },
	delete = { title = "ENDING: ZERO", lines = { "Every living thing, gone.", "Every single one.", "The world is deleted, and the god applauds from the white.", "You are finally, perfectly alone." } },
	restart = { title = "ENDING: ANOTHER STORY", lines = { "The world folds up like paper.", "A new seed. A new truck. A new pit.", "Maybe this time it'll be different." } },
	best = { title = "TRUE ENDING: NO AUTHOR", lines = { "The world grows back without anyone writing it.", "Nobody is watching from the white anymore.", "You wake up in a meadow. It's a Monday. You don't have to go to work.", "Somewhere, a cat opens a door." } },
	decline = { title = "ENDING: RANDOM", lines = { "You refuse the gift.", "You fall between the pages...", "...into a brand new random story." } },
}

function Story.vars(b, extra)
	local v = {}
	for k, x in b do
		if type(x) == "string" or type(x) == "number" then
			v[k] = x
		end
	end
	if b.coworkers then
		v.c1, v.c2, v.c3 = b.coworkers[1], b.coworkers[2], b.coworkers[3]
	end
	for k, x in extra or {} do
		v[k] = x
	end
	return v
end

-- Returns a list of {speaker, text} with all placeholders filled.
function Story.lines(scene: string, b, extra)
	local fn = SCENES[scene]
	if not fn then
		return { L("", "[missing scene " .. scene .. "]") }
	end
	local raw: { any } = fn(b)
	local vars = Story.vars(b, extra)
	local out: { any } = {}
	local function fillLine(l)
		return { speaker = Util.fill(l.speaker, vars), text = Util.fill(l.text, vars) }
	end
	for _, l in raw do
		if typeof(l) == "string" then
			table.insert(out, Util.fill(l, vars))
		elseif l.speaker == nil and l[1] then
			-- list of alternatives (e.g. coworker chatter)
			local alt = {}
			for _, x in l do
				table.insert(alt, fillLine(x))
			end
			table.insert(out, alt)
		else
			table.insert(out, fillLine(l))
		end
	end
	return out
end

function Story.fillText(text: string, b, extra): string
	return Util.fill(text, Story.vars(b, extra))
end

-- Random townsfolk chatter for open world NPCs.
Story.CHATTER = {
	"Did you hear? The capital of {kingdom} fell. Someone says one man did it.",
	"Monsters on the roads again. I'd stay inside if I were you.",
	"My grandmother said the old gods are asleep. My grandfather said they're just tired.",
	"There's a tower in the Evil Lands. They say it goes past the sky. Past everything.",
	"You look like you've been stepped on. By a titan. Twice.",
	"The bread here is terrible. Don't tell the baker I said that. I'm the baker.",
	"I saw a cloaked figure on the east road once. It had one red eye. I didn't sleep for a week.",
	"Some folk pray to the god in the white. I don't. Kind gods don't laugh that much.",
	"If you're heading out, clear the monster camp on the hill. Please. I beg you.",
	"They say time stands still around the stranger. That's silly. Right?",
	"Adventurers come through all the time. None of them come back through.",
	"I used to be an adventurer too. Then I got a desk job. Worse than any arrow.",
}

return Story
