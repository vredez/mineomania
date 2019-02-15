-- MINE-O-MANIA mod for minetest
--
-- AUTHOR:  vredez
-- VERSION: 1.0.0

--[[ Configuration  ]]--

-- node scanning area of effect (= number of nodes from the dug node to scan in each direction)
local scan_aoe = 10

-- node type whitelist
local nodetype_whitelist = {
    ["default:stone_with_iron"] = true,
    ["default:stone_with_gold"] = true,
    ["default:stone_with_copper"] = true,
    ["default:stone_with_mese"] = true,
    ["default:stone_with_diamond"] = true,
    ["default:stone_with_coal"] = true,
    ["default:stone_with_tin"] = true,
    ["default:clay"] = true,
    ["default:tree"] = true,
    ["default:mese"] = true
}
--[[ /Configuration ]]--

-- constants
local maniacpickaxe_name = "mineomania:maniac_pickaxe"
local attr_maniacmode = "maniac"

-- initialization
minetest.register_tool(maniacpickaxe_name, {
    description = "Maniac Pickaxe",
    inventory_image = "maniacpickaxe.png",
    tool_capabilities = {
        full_punch_interval = 1.5,
        max_drop_level = 1,
        groupcaps = {
            crumbly = {
                maxlevel = 3,
                uses = 90,
                times = { [1] = 1.6, [2] = 1.2, [3] = 0.8 }
            },
            cracky = {
                maxlevel = 3,
                uses = 90,
                times = { [1] = 1.6, [2] = 1.2, [3] = 0.8 }
            },
        },
        damage_groups = { fleshy = 2 }
    }
})
minetest.register_alias("maniacpickaxe", maniacpickaxe_name)

minetest.register_craft({
    output = maniacpickaxe_name,
    recipe = {
        {"default:diamond", "default:obsidian"  , "default:diamond"},
        {""               , "default:stick"     ,                ""},
        {""               , "default:gold_ingot",                ""}
    }
})

function scan_adjacent_nodes(
    pos,                 -- position of the center node
    id,                  -- id to scan for
    map_data,            -- map data containing ids
    scanned_flags,       -- data flagging already scanned nodes
    va,                  -- voxel area helper of the map data
    va_scope,            -- voxel area helper of the scanning scope
    scan_position_stack, -- stack of positions that need to be scanned
    matches              -- list of found voxel area indices
    )
    for z = pos.z - 1, pos.z + 1 do 
        for y = pos.y - 1, pos.y + 1 do
            for x = pos.x - 1, pos.x + 1 do
                local vec = vector.new(x, y, z)
                -- only consider adjacent nodes that are contained within the scope
                if va_scope:containsp(vec) and not vector.equals(vec, pos) then
                    local vi = va:index(x, y, z)

                    -- new match = not alreay scanned and id match
                    if not scanned_flags[vi] and map_data[vi] == id then
                        table.insert(matches, vi)
                        table.insert(scan_position_stack, vec)
                    end

                    -- flag as scanned
                    scanned_flags[vi] = true
                end
            end
        end
    end
end

local function on_joinplayer_handler(player)
    -- reset maniac mode, in case player connection broke or serve crashed
    player:set_attribute(attr_maniacmode, nil)
end

local function on_dignode_handler(pos, oldnode, digger)
    local tool = digger:get_wielded_item()

    if not tool or tool:get_name() ~= maniacpickaxe_name or not nodetype_whitelist[oldnode.name] then
        return nil
    end

    -- avoid recursive handler invokation
    if digger:get_attribute(attr_maniacmode) then
        return nil
    end
    digger:set_attribute(attr_maniacmode, "1")

    -- load map data
    local pos_min = vector.add(pos, -scan_aoe)
    local pos_max = vector.add(pos, scan_aoe)

    local vm = minetest.get_voxel_manip()
    local pos_min_actual, pos_max_actual = vm:read_from_map(pos_min, pos_max)
    local map_data = vm:get_data()

    local va = VoxelArea:new { MinEdge = pos_min_actual, MaxEdge = pos_max_actual }
    local va_scope = VoxelArea:new { MinEdge = pos_min, MaxEdge = pos_max }

    --[[ ===============================
    -- iterative node scanning procedure
    --   =============================== ]]
    local match_indices = {}
    local already_scanned_flags = {}
    local scan_position_stack = {}

    -- type id to scan for
    local type_id = minetest.get_content_id(oldnode.name)

    -- first scan candidate is the actual dug node
    local scan_position = pos

    while scan_position do
        scan_adjacent_nodes(
            scan_position,
            type_id,
            map_data,
            already_scanned_flags,
            va,
            va_scope,
            scan_position_stack,
            match_indices)

        -- pop from stack
        scan_position = table.remove(scan_position_stack)
    end
    --[[ =============================== ]]

    local dug_node_count = 1 -- start with 1 since one node is already dug
    
    for k, v in pairs(match_indices) do
        local match_pos = va:position(v)

        -- perform dig
        minetest.node_dig(match_pos, vm:get_node_at(match_pos), digger)
        dug_node_count = dug_node_count + 1

        -- stop on tool depletion
        if tool:get_count() == 0 then
            break
        end
    end

    -- notify player
    minetest.chat_send_player(
        digger:get_player_name(),
        string.format(
            "%s x%i",
            minetest.registered_nodes[oldnode.name].description,
            dug_node_count))

    digger:set_attribute(attr_maniacmode, nil)
end

-- callbacks
minetest.register_on_joinplayer(on_joinplayer_handler)
minetest.register_on_dignode(on_dignode_handler)
