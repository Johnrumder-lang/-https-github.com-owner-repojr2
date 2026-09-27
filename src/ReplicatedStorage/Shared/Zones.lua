--!nonstrict
-- Lighting presets ("moods") applied by the client when the server changes zone.
local Zones = {}
local rgb = Color3.fromRGB

local function P(t)
	-- defaults
	local d = {
		ClockTime = 14, Brightness = 2.2, Ambient = rgb(70, 70, 80), OutdoorAmbient = rgb(128, 128, 140),
		ExposureCompensation = 0, EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1,
		atmosphere = { Density = 0.3, Offset = 0.2, Color = rgb(200, 210, 230), Decay = rgb(110, 120, 140), Glare = 0.2, Haze = 1 },
		cc = { Brightness = 0, Contrast = 0.08, Saturation = 0.08, TintColor = rgb(255, 255, 255) },
		bloom = { Intensity = 0.6, Size = 26, Threshold = 1.6 },
		rays = { Intensity = 0.06, Spread = 0.8 },
		sky = { StarCount = 3000, CelestialBodiesShown = true },
	}
	for k, v in t do
		if type(v) == "table" and type(d[k]) == "table" then
			for k2, v2 in v do
				d[k][k2] = v2
			end
		else
			d[k] = v
		end
	end
	return d
end

Zones.PRESETS = {
	menu = P({ ClockTime = 0.2, Brightness = 0.6, Ambient = rgb(30, 30, 50), OutdoorAmbient = rgb(40, 40, 70), atmosphere = { Density = 0.4, Color = rgb(40, 40, 70), Decay = rgb(20, 20, 40) }, bloom = { Intensity = 1.2, Threshold = 0.9 } }),
	apartment = P({ ClockTime = 7.4, Brightness = 2.5, Ambient = rgb(90, 80, 70), OutdoorAmbient = rgb(150, 130, 110), atmosphere = { Density = 0.32, Color = rgb(255, 210, 170), Decay = rgb(200, 150, 120), Haze = 1.4 }, rays = { Intensity = 0.12 } }),
	street_day = P({ ClockTime = 9.2, Brightness = 2.8, Ambient = rgb(90, 90, 100), OutdoorAmbient = rgb(150, 150, 160), atmosphere = { Density = 0.3, Color = rgb(210, 220, 235) } }),
	office = P({ ClockTime = 12, Brightness = 2, Ambient = rgb(120, 120, 125), OutdoorAmbient = rgb(140, 140, 150), cc = { Saturation = -0.25, Contrast = 0.02, TintColor = rgb(235, 245, 255) } }),
	street_evening = P({ ClockTime = 18.2, Brightness = 2.2, Ambient = rgb(100, 70, 60), OutdoorAmbient = rgb(160, 110, 90), atmosphere = { Density = 0.35, Color = rgb(255, 170, 120), Decay = rgb(200, 90, 80), Glare = 0.8, Haze = 2 }, rays = { Intensity = 0.15 } }),
	street_night = P({ ClockTime = 23.2, Brightness = 1.2, Ambient = rgb(40, 44, 70), OutdoorAmbient = rgb(60, 66, 100), ExposureCompensation = 0.2, atmosphere = { Density = 0.36, Color = rgb(60, 70, 110), Decay = rgb(30, 30, 60), Haze = 1.5 }, bloom = { Intensity = 1.1, Threshold = 1.0, Size = 30 } }),
	tvroom = P({ ClockTime = 22, Brightness = 0.4, Ambient = rgb(20, 22, 30), OutdoorAmbient = rgb(20, 22, 30), bloom = { Intensity = 1.2, Threshold = 0.8 } }),
	whiteroom = P({ ClockTime = 12, Brightness = 4, Ambient = rgb(255, 255, 255), OutdoorAmbient = rgb(255, 255, 255), ExposureCompensation = 0.8, atmosphere = { Density = 0.62, Offset = 0, Color = rgb(255, 255, 255), Decay = rgb(255, 255, 255), Glare = 0, Haze = 0 }, cc = { Saturation = -0.2, Contrast = -0.1 }, bloom = { Intensity = 0.8, Threshold = 1.2 }, sky = { CelestialBodiesShown = false, StarCount = 0 } }),
	elder = P({ ClockTime = 12, Brightness = 2, Ambient = rgb(255, 230, 180), OutdoorAmbient = rgb(255, 220, 170), ExposureCompensation = 0.3, atmosphere = { Density = 0.6, Offset = 0, Color = rgb(255, 225, 170), Decay = rgb(230, 170, 110), Glare = 0, Haze = 0 }, cc = { Saturation = -0.1, TintColor = rgb(255, 240, 215) }, sky = { CelestialBodiesShown = false, StarCount = 0 } }),
	-- moonlit night outside the great hall's windows
	ritual = P({ ClockTime = 0.6, Brightness = 1.3, Ambient = rgb(62, 58, 76), OutdoorAmbient = rgb(70, 80, 120), atmosphere = { Density = 0.3, Color = rgb(70, 82, 120), Decay = rgb(28, 32, 60), Haze = 1.2, Glare = 0.2 }, cc = { Contrast = 0.14, Saturation = 0.05, TintColor = rgb(236, 236, 255) }, bloom = { Intensity = 0.9, Threshold = 1.1 }, sky = { StarCount = 5000, MoonAngularSize = 16 } }),
	-- the Abyss: cold stone and deep shadow; torches are the only warm colour
	pit = P({ ClockTime = 0, Brightness = 0, Ambient = rgb(38, 40, 52), OutdoorAmbient = rgb(38, 40, 52), ExposureCompensation = 0.12, atmosphere = { Density = 0.46, Offset = 0, Color = rgb(34, 36, 50), Decay = rgb(16, 16, 26), Haze = 0.4, Glare = 0 }, cc = { Contrast = 0.16, Saturation = -0.12, TintColor = rgb(222, 230, 255) }, bloom = { Intensity = 0.55, Threshold = 1.35, Size = 26 }, sky = { StarCount = 0, CelestialBodiesShown = false } }),
	fields = P({ ClockTime = 15.5, Brightness = 3, Ambient = rgb(90, 90, 90), OutdoorAmbient = rgb(150, 150, 150), atmosphere = { Density = 0.25, Color = rgb(200, 220, 240), Haze = 1.3 }, rays = { Intensity = 0.1 } }),
	village_burning = P({ ClockTime = 18.6, Brightness = 1.8, Ambient = rgb(110, 60, 50), OutdoorAmbient = rgb(170, 90, 70), atmosphere = { Density = 0.42, Color = rgb(255, 140, 90), Decay = rgb(160, 50, 40), Glare = 0.6, Haze = 2.4 }, cc = { Contrast = 0.15, Saturation = 0.12, TintColor = rgb(255, 225, 205) } }),
	cell = P({ ClockTime = 9, Brightness = 1.5, Ambient = rgb(40, 40, 46), OutdoorAmbient = rgb(80, 80, 90), cc = { Saturation = -0.2, Contrast = 0.12 }, rays = { Intensity = 0.3, Spread = 0.3 } }),
	arena = P({ ClockTime = 16.5, Brightness = 2.6, Ambient = rgb(90, 80, 70), OutdoorAmbient = rgb(150, 130, 110), atmosphere = { Density = 0.33, Color = rgb(240, 210, 170), Decay = rgb(180, 130, 90), Haze = 1.8 } }),
	titan = P({ ClockTime = 17.4, Brightness = 1.4, Ambient = rgb(80, 50, 50), OutdoorAmbient = rgb(130, 80, 70), atmosphere = { Density = 0.45, Color = rgb(170, 90, 80), Decay = rgb(90, 30, 30), Glare = 0.4, Haze = 2.6 }, cc = { Contrast = 0.22, Saturation = -0.05, TintColor = rgb(255, 225, 215) }, bloom = { Intensity = 0.9 } }),
	castle_burning = P({ ClockTime = 20.5, Brightness = 0.8, Ambient = rgb(90, 50, 40), OutdoorAmbient = rgb(120, 60, 50), atmosphere = { Density = 0.45, Color = rgb(255, 120, 60), Decay = rgb(100, 30, 20), Haze = 2.5 }, cc = { Contrast = 0.18, TintColor = rgb(255, 220, 200) }, bloom = { Intensity = 1.1, Threshold = 1.0 } }),
	crown = P({ ClockTime = 21, Brightness = 0.5, Ambient = rgb(90, 60, 50), OutdoorAmbient = rgb(90, 60, 50), cc = { Contrast = 0.2, TintColor = rgb(255, 230, 205) } }),
	-- biomes
	Fjord = P({ ClockTime = 15.8, Brightness = 2.4, Ambient = rgb(90, 100, 115), OutdoorAmbient = rgb(140, 150, 165), atmosphere = { Density = 0.36, Color = rgb(200, 212, 228), Decay = rgb(130, 150, 175), Haze = 2.2, Glare = 0.5 }, cc = { Saturation = -0.05, Contrast = 0.12, TintColor = rgb(240, 246, 255) }, rays = { Intensity = 0.14 } , cycle = true }),
	Giantwood = P({ ClockTime = 14.2, Brightness = 2.6, Ambient = rgb(80, 100, 80), OutdoorAmbient = rgb(130, 150, 125), atmosphere = { Density = 0.4, Color = rgb(190, 215, 190), Decay = rgb(110, 140, 100), Haze = 2.4, Glare = 0.3 }, cc = { Saturation = 0.12, TintColor = rgb(245, 255, 240) }, rays = { Intensity = 0.25, Spread = 0.6 } , cycle = true }),
	Meadow = P({ ClockTime = 13.5, Brightness = 3, Ambient = rgb(90, 95, 90), OutdoorAmbient = rgb(150, 155, 150), atmosphere = { Density = 0.24, Color = rgb(200, 220, 240), Haze = 1.3 }, cycle = true }),
	Arena = P({ ClockTime = 17.35, Brightness = 3, Ambient = rgb(96, 80, 66), OutdoorAmbient = rgb(150, 124, 98), ExposureCompensation = 0.05, atmosphere = { Density = 0.36, Offset = 0.15, Color = rgb(248, 204, 150), Decay = rgb(186, 112, 66), Haze = 2.2, Glare = 0.7 }, cc = { Saturation = 0.02, Contrast = 0.16, TintColor = rgb(255, 234, 206) }, bloom = { Intensity = 0.8, Threshold = 1.3, Size = 28 }, rays = { Intensity = 0.14, Spread = 0.7 } }),
	Autumn = P({ ClockTime = 16.8, Brightness = 2.6, Ambient = rgb(100, 80, 60), OutdoorAmbient = rgb(160, 130, 100), atmosphere = { Density = 0.34, Color = rgb(250, 200, 150), Decay = rgb(200, 120, 70), Haze = 1.8, Glare = 0.4 }, cc = { Saturation = 0.15, TintColor = rgb(255, 240, 220) } , cycle = true }),
	Desert = P({ ClockTime = 12.5, Brightness = 3.6, Ambient = rgb(120, 100, 80), OutdoorAmbient = rgb(180, 160, 130), ExposureCompensation = 0.1, atmosphere = { Density = 0.35, Color = rgb(250, 225, 180), Decay = rgb(220, 170, 110), Haze = 2.2, Glare = 1 }, cc = { TintColor = rgb(255, 245, 225) } , cycle = true }),
	Frost = P({ ClockTime = 10.5, Brightness = 2.8, Ambient = rgb(110, 120, 140), OutdoorAmbient = rgb(170, 180, 200), atmosphere = { Density = 0.4, Color = rgb(225, 235, 250), Decay = rgb(170, 190, 220), Haze = 2 }, cc = { Saturation = -0.1, TintColor = rgb(235, 245, 255) } , cycle = true }),
	Swamp = P({ ClockTime = 17, Brightness = 1.5, Ambient = rgb(60, 70, 55), OutdoorAmbient = rgb(100, 110, 90), atmosphere = { Density = 0.5, Color = rgb(140, 160, 120), Decay = rgb(70, 80, 50), Haze = 2.4 }, cc = { Saturation = -0.1, TintColor = rgb(235, 255, 225) } , cycle = true }),
	Volcanic = P({ ClockTime = 19, Brightness = 1.2, Ambient = rgb(110, 50, 40), OutdoorAmbient = rgb(140, 60, 50), atmosphere = { Density = 0.48, Color = rgb(160, 70, 50), Decay = rgb(80, 20, 10), Haze = 2.6, Glare = 0.3 }, cc = { Contrast = 0.2, TintColor = rgb(255, 220, 200) }, bloom = { Intensity = 1.0, Threshold = 1.0 } }),
	Crystal = P({ ClockTime = 21, Brightness = 1, Ambient = rgb(90, 80, 130), OutdoorAmbient = rgb(120, 110, 170), atmosphere = { Density = 0.35, Color = rgb(170, 150, 230), Decay = rgb(90, 70, 160), Haze = 1.4 }, bloom = { Intensity = 1.2, Threshold = 0.9 }, sky = { StarCount = 5000 } }),
	Mushroom = P({ ClockTime = 18.5, Brightness = 1.2, Ambient = rgb(100, 70, 110), OutdoorAmbient = rgb(130, 100, 140), atmosphere = { Density = 0.45, Color = rgb(170, 130, 180), Decay = rgb(90, 60, 110), Haze = 2 }, bloom = { Intensity = 1.2, Threshold = 0.9 } }),
	Evil = P({ ClockTime = 19.4, Brightness = 0.8, Ambient = rgb(90, 30, 40), OutdoorAmbient = rgb(110, 40, 50), atmosphere = { Density = 0.5, Color = rgb(120, 30, 40), Decay = rgb(50, 10, 16), Haze = 2.8, Glare = 0.6 }, cc = { Contrast = 0.25, Saturation = 0.1, TintColor = rgb(255, 215, 215) }, bloom = { Intensity = 1.1, Threshold = 1.0 } }),
	tower = P({ ClockTime = 19.6, Brightness = 0.9, Ambient = rgb(80, 30, 40), OutdoorAmbient = rgb(100, 40, 50), atmosphere = { Density = 0.4, Color = rgb(110, 30, 40), Decay = rgb(40, 10, 20), Haze = 2 }, cc = { Contrast = 0.22 } }),
	space = P({ ClockTime = 0, Brightness = 0.5, Ambient = rgb(60, 60, 80), OutdoorAmbient = rgb(80, 80, 110), ExposureCompensation = 0.3, atmosphere = { Density = 0, Haze = 0, Glare = 0 }, cc = { Contrast = 0.15, Saturation = 0 }, bloom = { Intensity = 1.4, Threshold = 0.9, Size = 36 }, sky = { StarCount = 5000, CelestialBodiesShown = false } }),
	antilight = P({ ClockTime = 0, Brightness = 0, Ambient = rgb(8, 8, 10), OutdoorAmbient = rgb(8, 8, 10), atmosphere = { Density = 0.6, Color = rgb(0, 0, 0), Decay = rgb(0, 0, 0), Haze = 0 }, cc = { Contrast = 0.6, Saturation = -0.7 }, bloom = { Intensity = 2, Threshold = 0.6 }, sky = { StarCount = 0, CelestialBodiesShown = false } }),
	void = P({ ClockTime = 0, Brightness = 0.2, Ambient = rgb(30, 30, 40), OutdoorAmbient = rgb(30, 30, 40), atmosphere = { Density = 0, Haze = 0 }, bloom = { Intensity = 1.5, Threshold = 0.7 }, sky = { StarCount = 5000, CelestialBodiesShown = false } }),
	ending = P({ ClockTime = 7, Brightness = 2.6, Ambient = rgb(110, 100, 90), OutdoorAmbient = rgb(170, 160, 140), atmosphere = { Density = 0.3, Color = rgb(255, 225, 190), Decay = rgb(220, 170, 120), Haze = 1.5, Glare = 0.8 }, rays = { Intensity = 0.2 } }),
}

return Zones
