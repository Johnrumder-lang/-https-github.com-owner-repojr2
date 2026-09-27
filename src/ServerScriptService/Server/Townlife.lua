--!nonstrict
-- Ambient town life. A "set" is a crowd tied to an area: people walk between
-- street points, stop to look at stalls, pair up and chat (speech bubbles, heads
-- turned to each other, mouths moving), vendors cry their wares, farmers carry
-- their animals around - and once in a while somebody walks up to the player and
-- asks them something. Sets spawn when a player comes near and despawn when
-- everybody is far away; if a chapter wipes the NPCs, the crowd simply comes back.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local RNG = require(Shared.RNG)
local Rig = require(Shared.Rig)
local Util = require(Shared.Util)
local Story = require(Shared.Story)
local S = require(script.Parent.S)

local Townlife = {}
Townlife.sets = {}
local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB
local rng = RNG.new(os.time() % 7919 + 3)

local SMALL_TALK = {
	{ "Fine weather for it.", "For what?", "For anything, really." },
	{ "Have you tried the new baker?", "The one who cries into the dough?", "That's the secret ingredient." },
	{ "My cousin saw a monster twice the size of a barn.", "Your cousin sees a lot of things.", "He was sober this time!" },
	{ "Prices went up again.", "Everything goes up. Except wages." },
	{ "Did the guard captain ever find his horse?", "He found it. It had joined a better guard." },
	{ "I heard the King hasn't slept in days.", "Would you? After what happened?" },
	{ "Are you going to the market later?", "Only if the fishmonger has stopped shouting." },
	{ "Look at the size of those clouds.", "Rain by evening.", "Rain by evening, every evening." },
	{ "Nice hat.", "It was my father's.", "It shows." },
	{ "Mind the road north. Wolves.", "Wolves I can live with. It's the taxes." },
	{ "How's the harvest?", "The crows are fatter than my children." },
	{ "They say there's a stranger in town.", "There's always a stranger in town.", "Not like this one." },
}

local VENDOR_CRIES = {
	"Fresh bread! Warm bread!", "Apples! Crisp as a dragon's scale!", "Fish, caught this morning!", "Cloth from the southern lands!",
	"Knives sharpened, two coppers!", "Honey cakes! Honey cakes!", "Potions! Mostly safe!", "Cheese! Aged like fine regret!",
	"Pots and pans! Loud and sturdy!", "Herbs for every ache!",
}

-- Questions a passer-by might put to the player. {q, choices, answers, gold?}
local ASKS = {
	{ q = "Stranger! You haven't seen a brown goat, have you? She answers to 'Duchess'.", choices = { "No, sorry.", "...A goat named Duchess?" }, answers = { "Well. Keep an eye out.", "Don't you judge her." } },
	{ q = "Is it true what they say? That the world ends past the mountains?", choices = { "There's more out there.", "Nobody knows." }, answers = { "More? Gods help us.", "That's what I was afraid of." } },
	{ q = "Could you spare a few coins for bread? Just a few.", choices = { "Give 10 gold", "Not today." }, answers = { "Bless you. May your blade stay sharp.", "Aye. Nobody does, these days." }, cost = 10 },
	{ q = "You look like an adventurer. My cellar has rats the size of dogs. Any tips?", choices = { "Get a cat.", "Get a bigger cat." }, answers = { "We had a cat. The rats ate it.", "...I'll ask around." } },
	{ q = "That's a fine sword. Is it heavy? It looks heavy.", choices = { "You get used to it.", "Want to hold it?" }, answers = { "I'll stick to my ladle.", "Gods, no. I'd drop it on my foot." } },
	{ q = "Excuse me - which way is the market square?", choices = { "That way.", "No idea, I'm new here." }, answers = { "Thank you kindly!", "Ha! Aren't we all." } },
	{ q = "Are you the one they whisper about? The one who stops time?", choices = { "Who's asking?", "That's just a rumour." }, answers = { "N-nobody. Nobody at all.", "Right. Right, of course." } },
	{ q = "I found this by the road. It's no use to me - here, take it.", choices = { "Thanks.", "What is it?" }, answers = { "Safe travels!", "A few coins, I think. Take them." }, gold = 25 },
}

-- ------------------------------------------------------------------ the walker brain
local Walker = {}
Walker.__index = Walker

function Walker.new(e, opts)
	local self = setmetatable({}, Walker)
	self.e = e
	self.set = opts.set
	self.state = "idle"
	self.t = rng:float(0, 4)
	self.home = e.root.Position
	self.scared = 0
	self.vendor = opts.vendor
	self.carrying = opts.carrying
	return self
end

function Walker:pose(p: string?)
	if self.carrying and p ~= "Talk" then
		p = "Carry"
	end
	self.e.model:SetAttribute("Pose", p)
end

function Walker:pickTarget()
	local set = self.set
	local pos = self.e.root.Position
	-- prefer points that are not too far (people run errands, they don't cross the city)
	local best, tries = nil, 0
	while tries < 6 do
		tries += 1
		local p = set.points[rng:int(1, #set.points)]
		if Util.flatDist(p, pos) < 160 then
			best = p
			break
		end
		best = best or p
	end
	return best + V(rng:float(-3, 3), 0, rng:float(-3, 3))
end

local function partner(self)
	for _, o in self.set.walkers do
		if o ~= self and o.state ~= "chat" and o.state ~= "ask" and not o.vendor and not o.e.dead and o.e.root.Parent then
			if Util.flatDist(o.e.root.Position, self.e.root.Position) < 26 then
				return o
			end
		end
	end
	return nil
end

function Walker:chatWith(o)
	self.state, o.state = "chat", "chat"
	local a, b = self, o
	task.spawn(function()
		local pa, pb = a.e.root.Position, b.e.root.Position
		local mid = (pa + pb) / 2
		local dir = Util.flatUnit(pb - pa)
		if dir.Magnitude < 0.5 then
			dir = V(1, 0, 0)
		end
		a.e.hum:MoveTo(mid - dir * 1.8)
		b.e.hum:MoveTo(mid + dir * 1.8)
		task.wait(1.6)
		if a.e.dead or b.e.dead then
			a.state, b.state = "idle", "idle"
			return
		end
		S.NPCs.face(a.e.model, b.e.root.Position)
		S.NPCs.face(b.e.model, a.e.root.Position)
		local talk = SMALL_TALK[rng:int(1, #SMALL_TALK)]
		if rng:chance(0.3) then
			talk = { Story.fillText(Story.CHATTER[rng:int(1, #Story.CHATTER)], S.State.run and S.State.run.bible or {}), "Hm." }
		end
		for i, line in talk do
			local who, other = if i % 2 == 1 then a else b, if i % 2 == 1 then b else a
			if who.e.dead or other.e.dead or who.scared > 0 or other.scared > 0 then
				break
			end
			who:pose("Talk")
			other:pose(if rng:chance(0.5) then "Crossed" else nil)
			Net.fireAll("FX", "Shout", { target = who.e.model, text = line, talk = true })
			task.wait(1.6 + #line * 0.045)
		end
		for _, w in { a, b } do
			if not w.e.dead then
				w:pose(nil)
				w.state = "idle"
				w.t = rng:float(0.5, 2)
			end
		end
	end)
end

-- Walk up to a player and ask them something (one player at a time, rarely).
function Walker:ask(player: Player)
	self.state = "ask"
	self.set.lastAsk = os.clock()
	task.spawn(function()
		local e = self.e
		local t0 = os.clock()
		while os.clock() - t0 < 8 and not e.dead do
			local c = player.Character
			local r = c and c.PrimaryPart
			if not r then
				break
			end
			if Util.flatDist(r.Position, e.root.Position) < 5.5 then
				break
			end
			e.hum.WalkSpeed = 10
			e.hum:MoveTo(r.Position)
			task.wait(0.2)
		end
		local c = player.Character
		local r = c and c.PrimaryPart
		if e.dead or not r or Util.flatDist(r.Position, e.root.Position) > 8 or S.PlayerService.locked then
			self.state = "idle"
			return
		end
		e.hum:MoveTo(e.root.Position)
		S.NPCs.face(e.model, r.Position)
		self:pose("Talk")
		Net.fireAll("FX", "Shout", { target = e.model, text = "Excuse me-", talk = true })
		task.wait(0.8)
		local a = ASKS[rng:int(1, #ASKS)]
		local name = e.model:GetAttribute("DisplayName") or "Passer-by"
		local choice = S.Director.say({ { speaker = name, text = a.q } }, { player = player, choices = a.choices, timeout = 45 })
		if e.dead then
			return
		end
		local reply = a.answers[choice] or a.answers[1]
		if a.cost and choice == 1 then
			local prof = S.State.profile(player)
			if prof and (prof.gold or 0) >= a.cost then
				S.State.addGold(player, -a.cost)
			else
				reply = "...You're as poor as me. Never mind."
			end
		elseif a.gold then
			S.State.addGold(player, a.gold)
		end
		Net.fireAll("FX", "Shout", { target = e.model, text = reply, talk = true })
		task.wait(2)
		self:pose(nil)
		self.state = "idle"
		self.t = 1
	end)
end

function Walker:update(dt)
	local e = self.e
	if e.dead or not e.root.Parent then
		return
	end
	local hum = e.hum
	if self.scared > 0 then
		self.scared -= dt
		local threat = S.Entities.nearestHostile(e, 70)
		local from = if threat then S.Entities.position(threat) else self.home
		hum.WalkSpeed = 20
		hum:MoveTo(e.root.Position + Util.flatUnit(e.root.Position - from) * 24)
		self:pose(nil)
		return
	end
	if self.state == "chat" or self.state == "ask" then
		return
	end
	self.t -= dt
	if self.vendor then
		-- vendors stay at their stall, crying their wares now and then
		if self.t <= 0 then
			self.t = rng:float(7, 16)
			self:pose("Talk")
			Net.fireAll("FX", "Shout", { target = e.model, text = VENDOR_CRIES[rng:int(1, #VENDOR_CRIES)], talk = true })
			task.delay(2.5, function()
				if not e.dead then
					self:pose(if rng:chance(0.5) then "Crossed" else nil)
				end
			end)
		end
		return
	end
	if self.state == "walk" then
		if Util.flatDist(e.root.Position, self.target) < 3 or self.t <= 0 then
			self.state = "idle"
			self.t = rng:float(2, 7)
			self:pose(rng:pick({ nil, nil, "Crossed", "Talk" }))
			-- sometimes strike up a conversation
			if rng:chance(0.3) then
				local o = partner(self)
				if o then
					self:chatWith(o)
					return
				end
			end
		end
		return
	end
	-- idle
	if self.t <= 0 then
		-- rarely: approach a nearby player with a question
		local set = self.set
		if set.ask and os.clock() - (set.lastAsk or 0) > set.askEvery and rng:chance(0.25) and not S.PlayerService.locked then
			for _, p in Players:GetPlayers() do
				local c = p.Character
				local r = c and c.PrimaryPart
				if r and Util.flatDist(r.Position, e.root.Position) < 24 and not S.Entities.nearestHostile(S.Entities.forPlayer(p) or e, 70) then
					self:ask(p)
					return
				end
			end
		end
		self.target = self:pickTarget()
		self.state = "walk"
		self.t = 25
		hum.WalkSpeed = rng:float(6.5, 10)
		hum:MoveTo(self.target)
		self:pose(nil)
	end
end

function Walker:onHit(attacker, info)
	if attacker and attacker.kind == "player" then
		Net.fireAll("FX", "Shout", { target = self.e.model, text = rng:pick({ "Help!", "Guards!", "Why?!", "Murderer!" }) })
		for _, w in self.set.walkers do
			if not w.e.dead and Util.flatDist(w.e.root.Position, self.e.root.Position) < 60 then
				w.scared = 10
				w.state = "idle"
			end
		end
	end
end

function Walker:onDeath() end
function Walker:destroy() end

-- ------------------------------------------------------------------ sets
local function lookFor(set)
	local race = set.races[rng:int(1, #set.races)]
	local outfit = set.outfits[rng:int(1, #set.outfits)]
	local d = Rig.randomLook(rng, if race == "Dwarf" then "Human" else race, outfit)
	d.mood = rng:pick({ "neutral", "happy", "calm", "neutral" })
	if rng:chance(0.2) then
		d.apron = rgb(220, 210, 190)
	end
	return d
end

local function smallAnimal(): string
	local list = if S.Fauna then S.Fauna.SMALL else { "chicken" }
	return list[rng:int(1, #list)]
end

local function spawnOne(set, kind, cf: CFrame)
	local look = lookFor(set)
	if kind == "vendor" then
		look.outfit = "merchant"
		look.apron = rgb(230, 220, 200)
	elseif kind == "farmer" then
		look.outfit = "peasant"
	end
	local isBeast = look.race == "Beastkin"
	local name = Story.personName(rng, isBeast)
	local carrying = if kind == "farmer" and S.Fauna then smallAnimal() else nil
	local e = S.NPCs.townsfolk(look, cf, {
		name = name,
		level = set.level or 5,
		tags = { ambient = true, [set.name] = true },
		fightBack = false,
		talk = { { speaker = name, text = Story.fillText(Story.CHATTER[rng:int(1, #Story.CHATTER)], S.State.run and S.State.run.bible or {}) } },
		brain = function(ent, o)
			return Walker.new(ent, { set = set, vendor = kind == "vendor", carrying = carrying })
		end,
	})
	if carrying then
		S.Fauna.carried(e.model, carrying, rng)
	end
	table.insert(set.walkers, e.brain)
	return e
end

-- set: {name, center, radius, points = {Vector3 ground}, count, vendors = {CFrame}, farmers = n,
--       races, outfits, level, ask = bool, askEvery = seconds, enabled = true}
function Townlife.define(set)
	set.walkers = {}
	set.enabled = if set.enabled == nil then true else set.enabled
	set.races = set.races or { "Human", "Human", "Human", "Beastkin" }
	set.outfits = set.outfits or { "peasant", "peasant", "merchant", "noble" }
	set.askEvery = set.askEvery or 120
	set.lastAsk = os.clock() - rng:float(0, set.askEvery * 0.6)
	set.vendors = set.vendors or {}
	Townlife.sets[set.name] = set
	return set
end

function Townlife.enable(name: string, on: boolean)
	local set = Townlife.sets[name]
	if set then
		set.enabled = on
		if not on then
			Townlife.despawn(set)
		end
	end
end

function Townlife.despawn(set)
	for _, w in set.walkers do
		local e = w.e
		if not e.dead then
			e.dead = true
			if e.model then
				e.model:Destroy()
			end
			S.Entities.remove(e)
		end
	end
	set.walkers = {}
	set.live = false
end

function Townlife.clear()
	for _, set in Townlife.sets do
		Townlife.despawn(set)
	end
	Townlife.sets = {}
end

local function anyPlayerWithin(center: Vector3, r: number): boolean
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local root = c and c.PrimaryPart
		if root and Util.flatDist(root.Position, center) < r then
			return true
		end
	end
	return false
end

task.spawn(function()
	while true do
		task.wait(1)
		for _, set in Townlife.sets do
			if not set.enabled or #set.points == 0 then
				continue
			end
			-- forget the dead (a chapter may have wiped every NPC)
			for i = #set.walkers, 1, -1 do
				local w = set.walkers[i]
				if w.e.dead or not w.e.model or not w.e.model.Parent then
					table.remove(set.walkers, i)
				end
			end
			local near = anyPlayerWithin(set.center, set.radius + 220)
			if near then
				-- top the crowd up, a few per second so it never hitches
				local vendorsAlive = 0
				for _, w in set.walkers do
					if w.vendor then
						vendorsAlive += 1
					end
				end
				local budget = 3
				for i = vendorsAlive + 1, #set.vendors do
					if budget <= 0 then
						break
					end
					budget -= 1
					pcall(spawnOne, set, "vendor", set.vendors[i])
				end
				local farmers = 0
				for _, w in set.walkers do
					if w.carrying then
						farmers += 1
					end
				end
				while budget > 0 and #set.walkers < set.count + #set.vendors do
					budget -= 1
					local p = set.points[rng:int(1, #set.points)]
					local kind = if farmers < (set.farmers or 0) then "farmer" else "walker"
					if kind == "farmer" then
						farmers += 1
					end
					pcall(spawnOne, set, kind, CF(p + V(rng:float(-4, 4), 3, rng:float(-4, 4))))
				end
				set.live = true
			elseif set.live and not anyPlayerWithin(set.center, set.radius + 420) then
				Townlife.despawn(set)
			end
		end
	end
end)

return Townlife
