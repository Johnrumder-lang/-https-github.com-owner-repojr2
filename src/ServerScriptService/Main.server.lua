--!nonstrict
-- THE RANDOM STORY - server entry. Fills the service registry, wires the
-- systems together and hands control to the story director.
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

-- lower, Ultrakill-like gravity (the place file sets it too; this keeps old places in sync)
workspace.Gravity = Config.Player.gravity or 128

local Server = script.Parent:WaitForChild("Server")
local S = require(Server.S)

-- order matters only for readability: no module touches S while loading
local MODULES = {
	"State",
	"Entities",
	"Ragdoll",
	"TimeStop",
	"Combat",
	"Projectiles",
	"AI",
	"PlayerService",
	"PvP",
	"Pause",
	"Loot",
	"Quests",
	"NPCs",
	"Bosses",
	"TitanBoss",
	"World",
	"Build",
	"Nature",
	"TerrainGen",
	"Fauna",
	"Interiors",
	"Townlife",
	"WorldCapital",
	"WorldPrologue",
	"WorldHeaven",
	"WorldPit",
	"WorldLand",
	"WorldTower",
	"WorldArena",
	"Director",
}

for _, name in MODULES do
	local ok, mod = pcall(require, Server:WaitForChild(name))
	if ok then
		S[name] = mod
	else
		warn("[Main] failed to load " .. name .. ": " .. tostring(mod))
	end
end

local CHAPTERS = {
	"Prologue",
	"Afterlife",
	"Summoning",
	"Pit",
	"Breakout",
	"Prison",
	"Titan",
	"Castle",
	"World",
	"Tower",
	"Finale",
	"GodFight",
	"Delete",
	"Epilogue",
	"Arena",
}

S.Chapters = {}
local chapterFolder = Server:WaitForChild("Chapters")
for _, name in CHAPTERS do
	local ok, mod = pcall(require, chapterFolder:WaitForChild(name))
	if ok then
		S.Chapters[name] = mod
	else
		warn("[Main] failed to load chapter " .. name .. ": " .. tostring(mod))
	end
end

-- the game builds its own characters (cubic R6 rigs)
Players.CharacterAutoLoads = false

S.PlayerService.init()
S.Loot.init()
S.Quests.init()
S.Director.init(S.Chapters)

print(string.format("[TheRandomStory] server ready - %d systems, %d chapters", #MODULES, #CHAPTERS))
