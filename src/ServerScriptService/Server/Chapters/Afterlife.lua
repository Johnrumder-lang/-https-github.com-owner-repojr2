--!nonstrict
-- CHAPTER 1: The death report on TV, then the white room and the "kind" god.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local S = require(script.Parent.Parent.S)

local Ch: any = {}
local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB

function Ch.run(D)
	local b = D.bible()
	D.lock(true, true, true)
	D.fade("black", 0.2)
	local refs = D.ensure("heaven", function()
		return S.WorldHeaven.whiteRoom(b)
	end)
	D.spawnPlayers(refs.spawn)

	-- the news ------------------------------------------------------------------
	local ticker = string.format("%s, %d, KILLED BY %s TRUCK  ///  VICTIM ALLEGEDLY %s  ///  LOCAL CAT OPENS DOORS  ///  WEATHER: STILL BAD  ///  ", string.upper(b.hero), b.age, b.truck, string.upper(b.crime))
	D.scene("tv", { channel = b.news, headline = "LOCAL " .. string.upper(b.job) .. " HIT BY TRUCK", ticker = ticker, dur = 34 })
	task.wait(0.2)
	D.fade("clear", 1.5)
	D.say(D.lines("news"), { auto = 4.6 })
	D.fade("black", 1.4)
	D.scene("tvEnd")

	-- the white room --------------------------------------------------------------
	D.zone("whiteroom")
	D.music("Calm")
	task.wait(0.6)
	D.fade("white", 0.05)
	task.wait(0.5)
	Net.fireAll("Fade", { to = "clear", time = 3, color = Color3.new(1, 1, 1) })
	D.scene("blink", { times = 1 })
	D.lock(false, true, true)
	D.objective("...Where am I?")
	D.marker(refs.throne + V(0, 20, 0), "???")
	D.waitNear(refs.throne, 46, 40)
	D.marker(nil)
	D.objective(nil)
	D.lock(true, true, true)
	local cam = { cf = refs.godCam, fov = 55 }
	local wide = { cf = refs.cam, fov = 60 }
	D.say(D.lines("god_intro"), { cam = cam })
	D.say(D.lines("god_choice"), { cam = wide, choices = { "Infinite Power", "Immortality", "Flight", "Time Stop" } })
	D.say(D.lines("god_after"), { cam = cam })
	-- the gift
	D.giveAll(function(p, prof)
		prof.abilities.timestop = true
	end)
	for _, p in D.players() do
		D.scene("power", { target = p.Character, color = rgb(200, 190, 255) })
	end
	Net.fireAll("Notify", { kind = "level", text = "TIME STOP", sub = "Duration: 1 second. How generous." })
	task.wait(2.5)
	D.scene("flashWhite", { hold = 1.2, outT = 0.1 })
	task.wait(0.3)
	D.fade("white", 0.8)
	S.State.run.flags.gotTimeStop = true
	return "Summoning"
end

return Ch
