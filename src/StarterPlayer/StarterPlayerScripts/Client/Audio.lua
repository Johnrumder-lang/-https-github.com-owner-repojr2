--!nonstrict
-- Sound playback with pitch variation + optional music loops.
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local C = require(script.Parent.C)

local Audio = {}
local sfxGroup = Instance.new("SoundGroup")
sfxGroup.Name = "SFX"
sfxGroup.Volume = 0.8
sfxGroup.Parent = SoundService
local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "Music"
musicGroup.Volume = 0.5
musicGroup.Parent = SoundService
Audio.sfx = sfxGroup

local anchorFolder
local function anchor(pos: Vector3): Attachment
	if not anchorFolder or not anchorFolder.Parent then
		anchorFolder = Instance.new("Part")
		anchorFolder.Name = "AudioAnchor"
		anchorFolder.Anchored = true
		anchorFolder.CanCollide = false
		anchorFolder.CanQuery = false
		anchorFolder.CanTouch = false
		anchorFolder.Transparency = 1
		anchorFolder.Size = Vector3.one
		anchorFolder.CFrame = CFrame.new(0, -10000, 0)
		anchorFolder.Parent = workspace
	end
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = anchorFolder
	return a
end

-- opts: {pitch, vol, spread, pos, parent}
function Audio.play(name: string, opts)
	local def = Config.Sounds[name]
	if not def or def.id == "" then
		return nil
	end
	opts = opts or {}
	local s = Instance.new("Sound")
	s.SoundId = def.id
	s.Volume = (def.vol or 0.6) * (opts.vol or 1)
	local spread = opts.spread or 0.08
	s.PlaybackSpeed = (opts.pitch or 1) * (1 + (math.random() * 2 - 1) * spread)
	if C.timeStop.active and not opts.ignoreTime then
		s.PlaybackSpeed *= 0.6
	end
	s.SoundGroup = sfxGroup
	local life = 6
	if opts.pos then
		local a = anchor(opts.pos)
		s.RollOffMaxDistance = opts.range or 180
		s.RollOffMinDistance = 8
		s.Parent = a
		Debris:AddItem(a, life)
	elseif opts.parent then
		s.RollOffMaxDistance = opts.range or 160
		s.Parent = opts.parent
		Debris:AddItem(s, life)
	else
		s.Parent = SoundService
		Debris:AddItem(s, life)
	end
	s:Play()
	return s
end

local current: Sound? = nil
function Audio.music(mood: string)
	local id = Config.Music[mood]
	if current then
		local old = current
		TweenService:Create(old, TweenInfo.new(1.5), { Volume = 0 }):Play()
		Debris:AddItem(old, 1.6)
		current = nil
	end
	if not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = musicGroup
	s.Parent = SoundService
	s:Play()
	TweenService:Create(s, TweenInfo.new(2), { Volume = 0.6 }):Play()
	current = s
end

function Audio.setTimeStop(on: boolean)
	TweenService:Create(musicGroup, TweenInfo.new(0.3), { Volume = if on then 0.12 else 0.5 }):Play()
end

return Audio
