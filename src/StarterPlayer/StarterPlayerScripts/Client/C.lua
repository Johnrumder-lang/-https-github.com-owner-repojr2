--!nonstrict
-- Client module registry (same idea as the server's S table) + shared client state.
local C: any = {}
-- [reason] = true while something needs a free mouse cursor. Reasons in use:
--   menu UIs: pause, inventory, dialogue (choices), settings;  alt = the player
--   pressed Left Alt to free the cursor during play.
C.cursor = {}
C.timeStop = { active = false, frozenSelf = false, inverted = false }
C.lastHurt = nil -- { dir = Vector3 (knockback of the last hit taken), t = os.clock() }
C.profile = nil
C.inCutscene = false
C.menuOpen = true
C.paused = false -- true while the pause menu is open (server pauses when solo)
C.settings = {
	sensitivity = 1,
	fov = 95,
	shake = 1,
	damageNumbers = true,
	blood = true,
	impactFrames = true,
	motionBlur = true,
	masterVolume = 1, -- 0..1
	musicVolume = 0.8, -- 0..1
}

function C.wantsCursor(): boolean
	for _, v in C.cursor do
		if v then
			return true
		end
	end
	return false
end

-- Caught runtime errors (pcall'd UI code) are collected here so tests can see them.
C.errors = {}
function C.report(where: string, err)
	local msg = tostring(where) .. ": " .. tostring(err)
	table.insert(C.errors, msg)
	warn("[TRS] " .. msg)
end

-- Settings with change listeners: C.onSetting(fn(key, value)) / C.setSetting(key, value)
local listeners = {}
function C.onSetting(fn)
	table.insert(listeners, fn)
end

function C.setSetting(key: string, value)
	C.settings[key] = value
	for _, fn in listeners do
		local ok, err = pcall(fn, key, value)
		if not ok then
			C.report("setting listener", err)
		end
	end
end

return C
