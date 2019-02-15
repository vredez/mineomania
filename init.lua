--[[
-- 
-- MINE-O-MANIA mod
-- 
-- AUTHOR: vredez
-- TODO: code cleanup
--
--]]

--[[ CONFIG ]]--
-- Area of effect
local aoe = 10
-- Allowed blocks
local blocklist = {
    ["default:clay"] = true,
    ["default:stone_with_iron"] = true,
    ["default:stone_with_gold"] = true,
    ["default:stone_with_copper"] = true,
    ["default:stone_with_mese"] = true,
    ["default:stone_with_mese"] = true,
    ["default:stone_with_diamond"] = true,
    ["default:stone_with_coal"] = true,
    ["default:stone_with_tin"] = true,
    ["default:mese"] = true
}
--[[ === ]]--

minetest.register_tool("mineomania:maniac_pickaxe", {
    description = "Maniac Pickaxe",
    inventory_image = "bergonix.png",
    tool_capabilities = {
        full_punch_interval = 1.5,
        max_drop_level = 1,
        groupcaps = {
            crumbly = {
                maxlevel = 3,
                uses = 90,
                times = { [1]=1.60, [2]=1.20, [3]=0.80 }
            },
            cracky = {
                maxlevel = 3,
                uses = 90,
                times = { [1]=1.60, [2]=1.20, [3]=0.80 }
            },
        },
        damage_groups = {fleshy=2}
    }
})

minetest.register_alias("maniac_pickaxe", "mineomania:maniac_pickaxe")

minetest.register_craft({
    type = "shaped",
    output = "mineomania:maniac_pickaxe 1",
    recipe = {
        {"default:diamond", "default:obsidian", "default:diamond"},
        {"", "default:stick", ""},
        {"", "default:stick", ""}
    }
})

function scan_adjacent_nodes(id, data, flags, pos, origin, va, va_real, scan_candidates, matches)
    for z = pos.z - 1, pos.z + 1 do 
        for y = pos.y - 1, pos.y + 1 do
            for x = pos.x - 1, pos.x + 1 do
                local vec = vector.new(x, y, z)
                if va_real:containsp(vec) and not vector.equals(vec, pos) then
                    local vi = va:index(x, y, z)

                    if not flags[vi] and data[vi] == id then
                        table.insert(matches, vi)
                        table.insert(scan_candidates, { p = vec, o = pos })
                    end

                    flags[vi] = true
                end
            end
        end
    end
end

function dig_with_tool(pos, digger)
    return true
end
 
minetest.register_on_dignode(function(pos, oldnode, digger)
    local wielded = digger:get_wielded_item()

    if not wielded or wielded:get_name() ~= "mineomania:maniac_pickaxe" or not blocklist[oldnode.name] then
        return false
    end

    if digger:get_attribute("maniac") then
        return false
    end

    digger:set_attribute("maniac", "1")

    local minedge = vector.add(pos, -aoe)
    local maxedge = vector.add(pos, aoe)

    local vm = minetest.get_voxel_manip()
    local pmin, pmax = vm:read_from_map(minedge, maxedge)

    local data = vm:get_data()
    local va = VoxelArea:new{ MinEdge = pmin, MaxEdge = pmax }
    local va_real = VoxelArea:new{ MinEdge = minedge, MaxEdge = maxedge }

    local flags = {}

    local scan_candidates = {}
    local matches = {}

    local id = minetest.get_content_id(oldnode.name)

    -- scan all around first node (origin nil)
    local candidate = { p = pos, o = nil }

    while candidate ~= nil do
        scan_adjacent_nodes(id, data, flags, candidate.p, candidate.o, va, va_real, scan_candidates, matches)
        candidate = table.remove(scan_candidates)
    end

    local actual_number = 1 -- start with 1 since one node was digged in the default mode

    for k, v in pairs(matches) do
        local match_pos = va:position(v)
        minetest.node_dig(match_pos, vm:get_node_at(match_pos) ,digger)
        actual_number = actual_number + 1
        if wielded:get_count() == 0 then
            break
        end
    end

    minetest.chat_send_player(digger:get_player_name(), string.format("%s x%i", minetest.registered_nodes[oldnode.name].description, actual_number))

    digger:set_attribute("maniac", nil)
end)
