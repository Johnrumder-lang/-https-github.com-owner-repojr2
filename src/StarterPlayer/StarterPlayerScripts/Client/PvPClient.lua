--!nonstrict
-- PvP overlay: duel countdown (3-2-1-FIGHT), the opponent's health bar, VICTORY /
-- DEFEAT banners, the arena kill feed and scoreboard.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local C = require(script.Parent.C)
local UI = require(script.Parent.UI)

local PvPClient = {}
local player = Players.LocalPlayer
local COL = UI.COL
local rgb = Color3.fromRGB
local V2 = Vector2.new

local gui, root
local big, bigSub
local oppFrame, oppName, oppFill, oppTrail
local feed, board
local oppModel: Model? = nil
local trailK = 1

local function build()
	gui, root = UI.layer("PvP", 14)
	big = UI.text(root, "", { Name = "Big", Size = UDim2.fromOffset(1200, 200), Position = UDim2.fromScale(0.5, 0.36), AnchorPoint = V2(0.5, 0.5), font = UI.GOTHIC, size = 150, color = COL.Bone, x = Enum.TextXAlignment.Center, strokeT = 0.2, Visible = false })
	bigSub = UI.text(root, "", { Name = "Sub", Size = UDim2.fromOffset(900, 40), Position = UDim2.fromScale(0.5, 0.47), AnchorPoint = V2(0.5, 0.5), font = UI.SERIF, size = 28, color = COL.BoneDim or COL.Bone, x = Enum.TextXAlignment.Center, strokeT = 0.4, Visible = false })
	-- opponent bar (top centre, under the compass)
	oppFrame = UI.frame(root, { Name = "Opponent", Size = UDim2.fromOffset(620, 54), Position = UDim2.new(0.5, 0, 0, 96), AnchorPoint = V2(0.5, 0), Visible = false })
	oppName = UI.text(oppFrame, "", { Name = "Name", Size = UDim2.new(1, 0, 0, 26), font = UI.GOTHIC, size = 26, color = COL.Bone, x = Enum.TextXAlignment.Center, strokeT = 0.4 })
	local back = UI.frame(oppFrame, { Name = "Back", Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 32), color = rgb(20, 14, 16), t = 0.1 })
	UI.stroke(back, COL.Gold, 1, 0.3)
	oppTrail = UI.frame(back, { Name = "Trail", Size = UDim2.fromScale(1, 1), color = rgb(230, 200, 150), t = 0.2 })
	oppFill = UI.frame(back, { Name = "Fill", Size = UDim2.fromScale(1, 1), color = rgb(170, 24, 32), t = 0 })
	-- kill feed (top right under the toasts) + scoreboard
	feed = UI.frame(root, { Name = "Feed", Size = UDim2.fromOffset(420, 200), Position = UDim2.new(1, -30, 0, 330), AnchorPoint = V2(1, 0) })
	UI.list(feed, 4, false, Enum.HorizontalAlignment.Right)
	board = UI.text(root, "", { Name = "Board", Size = UDim2.fromOffset(300, 200), Position = UDim2.new(0, 30, 0, 250), font = UI.BOLD, size = 16, color = COL.Bone, rich = true, strokeT = 0.5, y = Enum.TextYAlignment.Top, Visible = false })
end

local function flashBig(text: string, sub: string?, color: Color3?, hold: number?)
	big.Text = text
	big.TextColor3 = color or COL.Bone
	big.Visible = true
	UI.slam(big, 2.4, 0.25)
	bigSub.Text = sub or ""
	bigSub.Visible = sub ~= nil
	local token = {}
	big:SetAttribute("Tok", tostring(token))
	task.delay(hold or 0.8, function()
		if big:GetAttribute("Tok") == tostring(token) then
			big.Visible = false
			bigSub.Visible = false
		end
	end)
end

local function addFeed(text: string)
	local l = UI.text(feed, text, { Name = "Line", Size = UDim2.fromOffset(420, 22), font = UI.BOLD, size = 16, color = COL.Bone, rich = true, strokeT = 0.4, x = Enum.TextXAlignment.Right })
	task.delay(5, function()
		UI.tween(l, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
		task.delay(0.6, function()
			l:Destroy()
		end)
	end)
	local lines = feed:GetChildren()
	local n = 0
	for _, c in lines do
		if c:IsA("TextLabel") then
			n += 1
		end
	end
	if n > 6 then
		for _, c in lines do
			if c:IsA("TextLabel") then
				c:Destroy()
				break
			end
		end
	end
end

local function onEvent(d)
	if type(d) ~= "table" then
		return
	end
	if d.kind == "countdown" then
		oppModel = d.oppModel
		oppName.Text = string.upper(tostring(d.opponent or "OPPONENT"))
		oppFrame.Visible = true
		trailK = 1
		for i = 3, 1, -1 do
			task.delay((3 - i), function()
				flashBig(tostring(i), if i == 3 then "DUEL  vs  " .. tostring(d.opponent) else nil, COL.Bone, 0.9)
				C.Audio.play("Countdown", { pitch = 0.8 + (3 - i) * 0.1, ignoreTime = true })
			end)
		end
	elseif d.kind == "fight" then
		flashBig("FIGHT!", nil, rgb(220, 40, 45), 0.9)
		C.Audio.play("Fight", { ignoreTime = true })
		if C.Controller and C.Controller.shake then
			C.Controller.shake(1.2, 0.25)
		end
	elseif d.kind == "result" then
		if d.win then
			flashBig("VICTORY", "You defeated " .. tostring(d.name), rgb(235, 200, 120), 3)
		else
			flashBig("DEFEAT", tostring(d.name) .. " sent you flying", rgb(200, 30, 36), 3)
		end
		task.delay(3.5, function()
			oppFrame.Visible = false
			oppModel = nil
		end)
	elseif d.kind == "cancel" then
		oppFrame.Visible = false
		oppModel = nil
		flashBig("DUEL CANCELLED", nil, COL.Bone, 1.5)
	elseif d.kind == "feed" then
		local okName, me = pcall(function()
			return player.DisplayName
		end)
		if not okName then
			me = player.Name
		end
		local k = tostring(d.killer)
		local v = tostring(d.victim)
		addFeed(string.format('<font color="#e8e2d6">%s</font>  <font color="#aa1820">✦</font>  <font color="#a89f92">%s</font>', k, v))
		if k == me then
			flashBig("KILL", v, rgb(220, 40, 45), 0.7)
		end
		if type(d.score) == "table" then
			local rows = { '<font face="GrenzeGotisch" size="22">ARENA</font>' }
			for i, r in d.score do
				if i > 8 then
					break
				end
				table.insert(rows, string.format("%d.  %s  —  %d", i, tostring(r.name), tonumber(r.kills) or 0))
			end
			board.Text = table.concat(rows, "\n")
			board.Visible = true
		end
	elseif d.kind == "arena" then
		board.Visible = d.on == true
		if d.on then
			board.Text = '<font face="GrenzeGotisch" size="22">ARENA</font>\nKill everyone. Respawns are instant.'
		end
	end
end

function PvPClient.init()
	build()
	Net.on("PvP", onEvent)
	RunService.RenderStepped:Connect(function(dt)
		if oppFrame.Visible and oppModel and oppModel.Parent then
			local hum = oppModel:FindFirstChildOfClass("Humanoid")
			if hum then
				local k = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
				oppFill.Size = UDim2.fromScale(k, 1)
				trailK = if trailK > k then math.max(k, trailK - dt * 0.6) else k
				oppTrail.Size = UDim2.fromScale(trailK, 1)
			end
		end
		gui.Enabled = not C.menuOpen
	end)
end

return PvPClient
