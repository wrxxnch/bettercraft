-- mc_name_resolver.lua
-- Utilitário para resolver nomes estilo Minecraft no Mineclonia / Luanti
-- Permite usar: stone, dirt, zombie, etc sem namespace
-- Compatível com Luanti / Minetest 5.14+

local M = {}

-- =========================
-- Resolver aliases em cadeia
-- =========================
local function resolve_alias_chain(name)
	-- Resolve aliases múltiplos: stone -> default:stone -> mcl_core:stone
	local seen = {}
	while core.registered_aliases[name] and not seen[name] do
		seen[name] = true
		name = core.registered_aliases[name]
	end
	return name
end

-- =========================
-- Resolve NODE (setblock, fill, etc)
-- =========================
function M.resolve_node(name)
	if not name or name == "" then return nil end

	-- 1) aliases
	name = resolve_alias_chain(name)

	-- 2) se já existir como node, retorna
	if core.registered_nodes[name] then
		return name
	end

	-- 3) se não tiver namespace, procurar pelo nome curto
	if not name:find(":") then
		for regname in pairs(core.registered_nodes) do
			local short = regname:match("^.+:(.+)$")
			if short == name then
				return regname
			end
		end
	end

	return nil
end

-- =========================
-- Resolve ITEM (give, replaceitem, etc)
-- =========================
function M.resolve_item(name)
	if not name or name == "" then return nil end

	-- 1) aliases
	name = resolve_alias_chain(name)

	-- 2) se já existir como item, retorna
	if core.registered_items[name] then
		return name
	end

	-- 3) se não tiver namespace, procurar pelo nome curto
	if not name:find(":") then
		for regname in pairs(core.registered_items) do
			local short = regname:match("^.+:(.+)$")
			if short == name then
				return regname
			end
		end
	end

	return nil
end

-- =========================
-- Resolve ITEMSTRING ("dirt 64", "stone 1 0")
-- =========================
function M.resolve_itemstring(itemstring)
	if not itemstring or itemstring == "" then
		return itemstring
	end

	local name, rest = itemstring:match("^([^%s]+)%s*(.*)$")
	if not name then
		return itemstring
	end

	local resolved = M.resolve_item(name)
	if not resolved then
		return itemstring
	end

	if rest ~= "" then
		return resolved .. " " .. rest
	end
	return resolved
end

return M
