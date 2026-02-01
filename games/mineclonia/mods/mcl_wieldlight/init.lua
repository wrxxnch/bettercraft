-- Wieldlight for mineclonia
-- supports mcl_offhand
-- License GPL3
-- cora, 2023

local UPDATE_INTERVAL = 1
local placed_lights = {}
local next_update = 0

for i=2,minetest.LIGHT_MAX do
	minetest.register_node("mcl_wieldlight:light_"..i,{
		drawtype = "airlike",
		walkable = false,
		pointable = false,
		buildable_to = true,
		drop = "",
		light_source = i,
		groups = { wieldlight = i, not_in_creative_inventory = 1 },
	})
end

local function update_player_light(pl)
	local wield = pl:get_wielded_item():get_name()
	local offhand = mcl_offhand.get_offhand(pl):get_name()
	local wl = minetest.registered_items[wield] and minetest.registered_items[wield].light_source or 0
	local ol = minetest.registered_items[offhand] and minetest.registered_items[offhand].light_source or 0
	local light = math.min(math.max(wl,ol,0),minetest.LIGHT_MAX)
	local p = vector.round(vector.offset(pl:get_pos(),0,1,0))
	local n = minetest.get_node(p)
	if n.name ~= "air" and minetest.get_item_group(n.name, "wieldlight") == 0 then
		local ap = minetest.find_node_near(p, 1, {"air", "group:wieldlight"})
		if ap then
			p = ap
			n = minetest.get_node(p)
		end
	end
	local ph = minetest.hash_node_position(p)
	local has_light = false
	local rm = {}
	for h,v in pairs(placed_lights[pl] or {}) do
		if minetest.get_item_group(minetest.get_node(v).name, "wieldlight") ~= 0 then
			if light < 2 or ph ~= h then
				table.insert(rm,v)
				placed_lights[pl][h] = nil
			else
				has_light = true
			end
		else
			-- light has been replaced by something else
			placed_lights[pl][h] = nil
		end
	end

	if light >= 2 and not has_light and n.name == "air" then
		if not placed_lights[pl] then placed_lights[pl] = {} end
		minetest.set_node(p,{name="mcl_wieldlight:light_"..light})
		placed_lights[pl][ph] = p
	end

	minetest.bulk_set_node(rm,{name="air"}) --removal last otherwise you get flickering (and not nice flickering)
end

minetest.register_globalstep(function(dtime)
	next_update = next_update - dtime
	if next_update > 0 then return end

	for _,pl in pairs(minetest.get_connected_players()) do
		update_player_light(pl)
	end
	next_update = UPDATE_INTERVAL
end)

minetest.register_on_leaveplayer(function(pl)
	for h,v in pairs(placed_lights[pl] or {}) do
		minetest.remove_node(v)
	end
	placed_lights[pl] = nil
end)

minetest.register_lbm({
	label = "Remove oprphan wieldlights",
	name = "mcl_wieldlight:remove_orphan_lights",
	nodenames = {"group:wieldlight"},
	run_at_every_load = true,
	action = minetest.remove_node,
})

minetest.register_on_mods_loaded(function()
	for k,v in pairs(minetest.registered_items) do
		if v.light_source and v.light_source >= 2 then --allow all light emitting items as offhand nodes
			minetest.override_item(k,{
				groups = table.update({offhand_item = 1},v.groups)
				--use "reverse arg" table.update instead of the preferred table.merge to support legacy mcl2
			})
		end
	end
end)
