local modpath = core.get_modpath(core.get_current_modname())

mcl_weather = {}

-- If not located then embeded skycolor mod version will be loaded.
if core.get_modpath("skycolor") == nil then
	dofile(modpath.."/skycolor.lua")
end

dofile(modpath.."/weather_core.lua")
dofile(modpath.."/snow.lua")
dofile(modpath.."/rain.lua")
dofile(modpath.."/nether_dust.lua")
dofile(modpath.."/thunder.lua")

core.register_globalstep(function(dtime)
	local weather = mcl_weather[mcl_weather.state]
	if not (weather and weather.step) then return end

	weather.step(dtime)
end)

