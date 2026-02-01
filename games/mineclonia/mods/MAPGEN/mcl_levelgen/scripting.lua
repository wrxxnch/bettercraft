--------------------------------------------------------------------------
-- Level generator scripting interface.
--------------------------------------------------------------------------

local level_generator_scripts = {}

function mcl_levelgen.register_levelgen_script (script, ersatz)
	if not core then
		mcl_levelgen.is_levelgen_environment = true
		dofile (script)
	elseif core.get_mod_storage then
		table.insert (level_generator_scripts, {
			script = script,
			ersatz_supported = ersatz,
		})
		core.ipc_set ("mcl_levelgen:levelgen_scripts",
			      level_generator_scripts)
	end
end

------------------------------------------------------------------------
-- Feature environment stubs.
------------------------------------------------------------------------

function mcl_levelgen.register_loot_table (_, _)
end
