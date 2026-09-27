--!nonstrict
-- EPILOGUE: after the "save" or the true ending, the world is yours to live in.
-- Free roam through the lands; any waystone can start a brand new random story.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local S = require(script.Parent.Parent.S)

local Ch: any = {}

function Ch.run(D)
	local run = S.State.run
	local b = D.bible()
	local ending = run.flags.ending or "save"
	run.flags.epilogue = true
	D.clearWorld()
	D.current = nil
	D.refs = {}
	D.look("awakened")
	D.lock(false, false, false)
	-- pick up in the first open land
	run.land = 2
	local refs = D.ensure("land2", function()
		return S.WorldLand.build(2, b, D.seed())
	end)
	D.spawnPlayers(refs.entry)
	S.Chapters.World.skipSpawn = true
	D.zone(b.lands[2].biome, "EPILOGUE", if ending == "best" then "No one is writing this anymore." else "The world you kept.")
	D.music("Calm")
	D.fade("clear", 1.5)
	if ending == "best" then
		D.say({
			{ speaker = "", text = "It's a Monday. You don't have to go to work." },
			{ speaker = "", text = "Nobody is watching from the white anymore. Whatever happens now... actually happens." },
		}, { auto = 3 })
	else
		D.say({
			{ speaker = "", text = "The lands are quieter now. Villages rebuild. The monsters still come - but so do you." },
			{ speaker = b.god, text = "(somewhere far above, someone is still watching)" },
		}, { auto = 3 })
	end
	D.tutorial("Explore freely. Any Waystone can take you between lands - or begin a brand new random story.", nil, 9)
	Net.fireAll("Notify", { kind = "level", text = "FREE ROAM", sub = "Your gear and level carry over into a new story." })
	D.save()
	return "World"
end

return Ch
