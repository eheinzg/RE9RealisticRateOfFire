
-- Minimal per-weapon edits.
-- Key = WeaponID, values = fields inside _WeaponStructureParam._TypeOfShootData[0]
local rof_edits = {
    -- Example:
    -- [4000] = {
    --     TypeOfShoot = 0,
    --     ShotInterval = 0.60000002,
    --     BurstShotInterval = 5.0,
    --     BurstNum = 3
    -- }
}

local has_applied = false
local equipped_weapon_id = nil
local equipped_weapon_status = "No player"
local apply_edits
local ui_state = {
    weapon_id_text = "",
    type_of_shoot = 0,
    shot_interval = 0.6,
    burst_shot_interval = 5.0,
    burst_num = 3,
    status = "No changes yet"
}
local WEAPON_NAMES = {
    ["arm0007"] = "Alligator Snapper",
    ["arm0400"] = "Requiem",
}

local HARD_CODED_WEAPON_KEYS = {
    "arm0000",
    "arm0002",
    "arm0003",
    "arm0005",
    "arm0006",
    "arm0007",
    "arm0008",
    "arm0100",
    "arm0103",
    "arm0104",
    "arm0200",
    "arm0202",
    "arm0203",
    "arm0204",
    "arm0205",
    "arm0206",
    "arm0207",
    "arm0300",
    "arm0303",
    "arm0304",
    "arm0305",
    "arm0307",
    "arm0309",
    "arm0315",
    "arm0318",
    "arm0319",
    "arm0320",
    "arm0321",
    "arm0322",
    "arm0323",
    "arm0324",
    "arm0325",
    "arm0326",
    "arm0400"
}
local weapon_list_state = {
    items = {},
    dropdown_options = {},
    selected_index = 1,
    last_refresh_count = 0,
    last_refresh_status = "Preset list not initialized"
}
local debug = {
    scene_found = false,
    catalog_found = false,
    catalog_name = "(none)",
    register_found = false,
    register_type = "(none)",
    userdata_found = false,
    userdata_getter = "(none)",
    data_table_found = false,
    data_table_field = "(none)",
    data_table_count = 0,
    last_apply_count = 0,
    match_count = 0,
    ws_param_count = 0,
    shoot_list_count = 0,
    shoot_data_count = 0,
    write_count = 0,
    last_reason = "Not run yet"
}

local function count_table_entries(t)
    local n = 0
    for _, _ in pairs(t or {}) do
        n = n + 1
    end
    return n
end

local function parse_int(text)
    if text == nil then
        return nil
    end
    local n = tonumber(text)
    if n == nil then
        return nil
    end
    return math.floor(n + 0.5)
end

local function parse_weapon_key(text)
    if text == nil then
        return nil
    end

    local s = tostring(text)
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then
        return nil
    end

    local lowered = string.lower(s)
    if lowered:match("^[%a_]+%d+$") then
        return lowered
    end

    local n = tonumber(s)
    if n ~= nil then
        return math.floor(n + 0.5)
    end

    return nil
end

local function apply_all_now()
    has_applied = false
    local count = apply_edits()
    if count > 0 then
        has_applied = true
    end
    return count
end

local function load_ui_from_entry(weapon_id, edit)
    if weapon_id == nil or edit == nil then
        return
    end
    ui_state.weapon_id_text = tostring(weapon_id)
    ui_state.type_of_shoot = tonumber(edit.TypeOfShoot) or 0
    ui_state.shot_interval = tonumber(edit.ShotInterval) or 0.6
    ui_state.burst_shot_interval = tonumber(edit.BurstShotInterval) or 5.0
    ui_state.burst_num = tonumber(edit.BurstNum) or 3
end

local function load_ui_for_weapon_id(weapon_id)
    if weapon_id == nil then
        return
    end
    ui_state.weapon_id_text = tostring(weapon_id)

    local edit = rof_edits[weapon_id]
    if edit == nil and type(weapon_id) == "number" then
        edit = rof_edits[tostring(weapon_id)]
    end
    if edit ~= nil then
        load_ui_from_entry(weapon_id, edit)
    end
end

local function normalize_numeric_id(value)
    if type(value) == "number" then
        return math.floor(value + 0.5)
    end
    if type(value) == "string" then
        local n = tonumber(value)
        if n ~= nil then
            return math.floor(n + 0.5)
        end
    end
    return nil
end

local function normalize_weapon_key(value)
    if value == nil then
        return nil
    end

    if type(value) == "string" then
        local lowered = string.lower(value:gsub("^%s+", ""):gsub("%s+$", ""))
        if lowered:match("^[%a_]+%d+$") then
            return lowered
        end
        return nil
    end

    local as_text = tostring(value)
    if as_text == nil or as_text == "" then
        return nil
    end
    local lowered = string.lower(as_text:gsub("^%s+", ""):gsub("%s+$", ""))
    if lowered:match("^[%a_]+%d+$") then
        return lowered
    end
    return nil
end

local function extract_weapon_key_from_path_text(text)
    if text == nil then
        return nil
    end
    local lowered = string.lower(tostring(text))
    local from_param = lowered:match("/([%a_]+%d+)parameter%.user")
    if from_param then
        return from_param
    end
    local anywhere = lowered:match("([%a_]+%d+)")
    if anywhere then
        return anywhere
    end
    return nil
end

local function try_get_player_from_manager(manager_name)
    local manager = sdk.get_managed_singleton(manager_name)
    if not manager then
        return nil
    end

    local player = nil
    pcall(function() player = manager:call("getPlayerContextRef") end)
    if player then
        return player
    end

    pcall(function() player = manager:call("get_PlayerContextRef") end)
    return player
end

local function get_equipped_weapon_id()
    local player = try_get_player_from_manager("app.CharacterManager")
    if not player then
        player = try_get_player_from_manager("chainsaw.CharacterManager")
    end
    if not player then
        return nil, "No player"
    end

    local inventory = nil
    pcall(function() inventory = player:get_field("<Inventory>k__BackingField") end)
    if not inventory then
        pcall(function() inventory = player:get_field("_Inventory") end)
    end
    if not inventory then
        return nil, "No inventory"
    end

    local equip_controller = nil
    pcall(function() equip_controller = inventory:get_field("_EquipController") end)
    if not equip_controller then
        return nil, "No equip controller"
    end

    local weapon = nil
    pcall(function() weapon = equip_controller:call("getEquipItem", 0) end)
    if not weapon then
        pcall(function() weapon = equip_controller:call("get_EquipItem", 0) end)
    end
    if not weapon then
        return nil, "No equipped weapon"
    end

    local item_def = nil
    pcall(function() item_def = weapon:get_field("_ItemDefine") end)
    if not item_def then
        pcall(function() item_def = weapon:get_field("_ItemDef") end)
    end
    if not item_def then
        return nil, "No item define"
    end

    local weapon_id = nil
    pcall(function() weapon_id = item_def:get_field("_ItemId") end)
    if not weapon_id then
        pcall(function() weapon_id = item_def:get_field("_WeaponId") end)
    end
    if weapon_id == nil then
        return nil, "No weapon id"
    end

    return weapon_id, "OK"
end

local function get_scene()
    local scene_manager = sdk.get_native_singleton("via.SceneManager")
    if not scene_manager then
        return nil
    end

    local scene_manager_type = sdk.find_type_definition("via.SceneManager")
    if not scene_manager_type then
        return nil
    end

    return sdk.call_native_func(scene_manager, scene_manager_type, "get_CurrentScene")
end

local function find_weapon_catalog(scene)
    if not scene then
        return nil
    end

    local names = {
        "WeaponCatalog",
        "WeaponCatalog_AO",
        "WeaponCatalog_MC",
        "WeaponCatalog_MC_2nd"
    }

    for _, name in ipairs(names) do
        local obj = scene:call("findGameObject(System.String)", name)
        if obj then
            return obj, name
        end
    end

    return nil, "(none)"
end

local function get_catalog_register(catalog)
    if not catalog then
        return nil
    end

    local register_types = {
        "app.WeaponCatalogRegister",
        "chainsaw.WeaponCatalogRegister"
    }

    for _, type_name in ipairs(register_types) do
        local t = sdk.typeof(type_name)
        if t then
            local register = catalog:call("getComponent(System.Type)", t)
            if register then
                return register, type_name
            end
        end
    end

    return nil, "(none)"
end

local function try_call_noargs(obj, method_name)
    local result = nil
    pcall(function() result = obj:call(method_name) end)
    return result
end

local function try_get_field(obj, field_name)
    local result = nil
    pcall(function() result = obj:get_field(field_name) end)
    return result
end

local function get_weapon_data_table(register)
    if not register then
        return nil
    end

    local userdata_candidates = {
        { source = "register:get_WeaponEquipParamCatalogUserData", obj = try_call_noargs(register, "get_WeaponEquipParamCatalogUserData") },
        { source = "register:get_PlayerWeaponParameterUserData", obj = try_call_noargs(register, "get_PlayerWeaponParameterUserData") },
        { source = "register._WeaponEquipParamCatalogUserData", obj = try_get_field(register, "_WeaponEquipParamCatalogUserData") },
        { source = "register._PlayerWeaponParameterUserData", obj = try_get_field(register, "_PlayerWeaponParameterUserData") },
        { source = "register._WeaponCatalogUserData", obj = try_get_field(register, "_WeaponCatalogUserData") }
    }

    for _, candidate in ipairs(userdata_candidates) do
        local userdata = candidate.obj
        if userdata then
            local direct_data_table = try_get_field(userdata, "_DataTable")
            if direct_data_table then
                return direct_data_table, candidate.source, candidate.source .. "._DataTable"
            end

            local direct_weapon_params = try_get_field(userdata, "_WeaponEquipParams")
            if direct_weapon_params then
                return direct_weapon_params, candidate.source, candidate.source .. "._WeaponEquipParams"
            end

            local direct_data_table_method = try_call_noargs(userdata, "get_DataTable")
            if direct_data_table_method then
                return direct_data_table_method, candidate.source, candidate.source .. ":get_DataTable"
            end

            local catalog_data = try_get_field(userdata, "_CatalogData")
            if catalog_data then
                local nested_data_table = try_get_field(catalog_data, "_DataTable")
                if nested_data_table then
                    return nested_data_table, candidate.source, candidate.source .. "._CatalogData._DataTable"
                end

                local nested_weapon_params = try_get_field(catalog_data, "_WeaponEquipParams")
                if nested_weapon_params then
                    return nested_weapon_params, candidate.source, candidate.source .. "._CatalogData._WeaponEquipParams"
                end

                local nested_data_table_method = try_call_noargs(catalog_data, "get_DataTable")
                if nested_data_table_method then
                    return nested_data_table_method, candidate.source, candidate.source .. "._CatalogData:get_DataTable"
                end
            end
        end
    end

    return nil, "(none)", "(none)"
end

local function resolve_weapon_data_table(update_debug)
    if update_debug then
        debug.scene_found = false
        debug.catalog_found = false
        debug.catalog_name = "(none)"
        debug.register_found = false
        debug.register_type = "(none)"
        debug.userdata_found = false
        debug.userdata_getter = "(none)"
        debug.data_table_found = false
        debug.data_table_field = "(none)"
        debug.data_table_count = 0
        debug.last_apply_count = 0
    end

    local scene = get_scene()
    if update_debug then
        debug.scene_found = scene ~= nil
    end
    if not scene then
        if update_debug then
            debug.last_reason = "No current scene"
        end
        return nil
    end

    local catalog, catalog_name = find_weapon_catalog(scene)
    if update_debug then
        debug.catalog_found = catalog ~= nil
        debug.catalog_name = catalog_name or "(none)"
    end
    if not catalog then
        if update_debug then
            debug.last_reason = "WeaponCatalog object not found"
        end
        return nil
    end

    local register, register_type = get_catalog_register(catalog)
    if update_debug then
        debug.register_found = register ~= nil
        debug.register_type = register_type or "(none)"
    end
    if not register then
        if update_debug then
            debug.last_reason = "Catalog register component not found"
        end
        return nil
    end

    local data_table, userdata_getter, data_table_field = get_weapon_data_table(register)
    if update_debug then
        debug.userdata_getter = userdata_getter or "(none)"
        debug.userdata_found = userdata_getter ~= "(none)"
        debug.data_table_found = data_table ~= nil
        debug.data_table_field = data_table_field or "(none)"
    end
    if not data_table then
        if update_debug then
            debug.last_reason = "Weapon data table not found"
        end
        return nil
    end

    local count = 0
    pcall(function() count = data_table:call("get_Count") end)
    if update_debug then
        debug.data_table_count = count or 0
        debug.last_reason = "OK"
    end

    return data_table
end

local function get_weapon_entry_id(weapon_data)
    if not weapon_data then
        return nil, "(none)"
    end

    local direct_id_fields = {
        "_WeaponID",
        "WeaponID",
        "_WeaponId",
        "_ItemID",
        "_ItemId",
        "ItemID"
    }

    for _, field_name in ipairs(direct_id_fields) do
        local value = try_get_field(weapon_data, field_name)
        local weapon_key = normalize_weapon_key(value)
        if weapon_key ~= nil then
            return weapon_key, "weapon_data." .. field_name
        end
        local weapon_id = normalize_numeric_id(value)
        if weapon_id ~= nil then
            return weapon_id, "weapon_data." .. field_name
        end
    end

    local id_methods = {
        "get_WeaponID",
        "get_WeaponId",
        "get_ItemID",
        "get_ItemId"
    }

    for _, method_name in ipairs(id_methods) do
        local value = try_call_noargs(weapon_data, method_name)
        local weapon_key = normalize_weapon_key(value)
        if weapon_key ~= nil then
            return weapon_key, "weapon_data:" .. method_name
        end
        local weapon_id = normalize_numeric_id(value)
        if weapon_id ~= nil then
            return weapon_id, "weapon_data:" .. method_name
        end
    end

    local weapon_cache = try_get_field(weapon_data, "_WeaponCache")
    if not weapon_cache then
        weapon_cache = try_get_field(weapon_data, "WeaponCache")
    end
    if weapon_cache then
        local cache_id_fields = {
            "_WeaponID",
            "WeaponID",
            "_WeaponId",
            "_ItemID",
            "_ItemId",
            "WeaponId"
        }
        for _, field_name in ipairs(cache_id_fields) do
            local value = try_get_field(weapon_cache, field_name)
            local weapon_key = normalize_weapon_key(value)
            if weapon_key ~= nil then
                return weapon_key, "weapon_cache." .. field_name
            end
            local weapon_id = normalize_numeric_id(value)
            if weapon_id ~= nil then
                return weapon_id, "weapon_cache." .. field_name
            end
        end

        local cache_key = normalize_weapon_key(weapon_cache)
        if cache_key ~= nil then
            return cache_key, "weapon_cache:tostring"
        end
    end

    local parameter = try_get_field(weapon_data, "WeaponParameter")
    if not parameter then
        parameter = try_get_field(weapon_data, "_WeaponParameter")
    end
    if parameter then
        local path_key = extract_weapon_key_from_path_text(parameter)
        if path_key ~= nil then
            return path_key, "weapon_parameter:path"
        end
    end

    return nil, "(none)"
end

local function get_weapon_entry_label(weapon_data, index)
    if not weapon_data then
        return "entry[" .. tostring(index) .. "]"
    end

    local weapon_id = get_weapon_entry_id(weapon_data)
    if weapon_id and WEAPON_NAMES[weapon_id] then
        return WEAPON_NAMES[weapon_id]
    end

    local weapon_cache = try_get_field(weapon_data, "_WeaponCache")
    if not weapon_cache then
        weapon_cache = try_get_field(weapon_data, "WeaponCache")
    end
    if weapon_cache then
        local label_fields = { "_WeaponName", "WeaponName", "_Name", "Name" }
        for _, field_name in ipairs(label_fields) do
            local value = try_get_field(weapon_cache, field_name)
            if value ~= nil then
                local s = tostring(value)
                if s ~= "" then
                    return s
                end
            end
        end
        local cache_s = tostring(weapon_cache)
        if cache_s and cache_s ~= "" then
            return cache_s
        end
    end

    local parameter = try_get_field(weapon_data, "WeaponParameter")
    if not parameter then
        parameter = try_get_field(weapon_data, "_WeaponParameter")
    end
    if parameter then
        local param_s = tostring(parameter)
        if param_s and param_s ~= "" then
            return param_s
        end
    end

    return "entry[" .. tostring(index) .. "]"
end

local function set_weapon_list_from_keys(keys, status_text)
    weapon_list_state.items = {}
    weapon_list_state.dropdown_options = {}
    weapon_list_state.selected_index = 1

    for i, key in ipairs(keys or {}) do
        local normalized = parse_weapon_key(key)
        if normalized ~= nil then
            local label = WEAPON_NAMES[normalized] or "(preset)"
            weapon_list_state.items[#weapon_list_state.items + 1] = {
                index = i - 1,
                weapon_id = normalized,
                id_source = "hardcoded",
                label = label
            }
            weapon_list_state.dropdown_options[#weapon_list_state.dropdown_options + 1] = 
                tostring(label) .. " [" .. tostring(normalized) .. "]"
        end
    end

    weapon_list_state.last_refresh_count = #weapon_list_state.items
    weapon_list_state.last_refresh_status = status_text or "Preset list loaded"
end

local function resolve_shoot_data(weapon_data)
    if not weapon_data then
        return nil, "(none)"
    end

    local ws_param = try_get_field(weapon_data, "_WeaponStructureParam")
    if not ws_param then
        ws_param = try_get_field(weapon_data, "WeaponStructureParam")
    end
    if ws_param then
        local shoot_data_list = try_get_field(ws_param, "_TypeOfShootData")
        if not shoot_data_list then
            shoot_data_list = try_get_field(ws_param, "TypeOfShootData")
        end
        if not shoot_data_list then
            shoot_data_list = try_call_noargs(ws_param, "get_TypeOfShootData")
        end
        if shoot_data_list then
            local count = 0
            pcall(function() count = shoot_data_list:call("get_Count") end)
            if count > 0 then
                local shoot_data = nil
                pcall(function() shoot_data = shoot_data_list:call("get_Item", 0) end)
                if shoot_data then
                    return shoot_data, "weapon_data._WeaponStructureParam._TypeOfShootData[0]"
                end
            end
        end
    end

    local parameter = try_get_field(weapon_data, "WeaponParameter")
    if not parameter then
        parameter = try_get_field(weapon_data, "_WeaponParameter")
    end
    if parameter then
        local ws_param_from_param = try_get_field(parameter, "_WeaponStructureParam")
        if not ws_param_from_param then
            ws_param_from_param = try_get_field(parameter, "WeaponStructureParam")
        end
        if ws_param_from_param then
            local shoot_data_list = try_get_field(ws_param_from_param, "_TypeOfShootData")
            if not shoot_data_list then
                shoot_data_list = try_get_field(ws_param_from_param, "TypeOfShootData")
            end
            if not shoot_data_list then
                shoot_data_list = try_call_noargs(ws_param_from_param, "get_TypeOfShootData")
            end
            if shoot_data_list then
                local count = 0
                pcall(function() count = shoot_data_list:call("get_Count") end)
                if count > 0 then
                    local shoot_data = nil
                    pcall(function() shoot_data = shoot_data_list:call("get_Item", 0) end)
                    if shoot_data then
                        return shoot_data, "weapon_data.WeaponParameter._WeaponStructureParam._TypeOfShootData[0]"
                    end
                end
            end
        end
    end

    return nil, "(none)"
end

local function refresh_weapon_list()
    weapon_list_state.items = {}
    weapon_list_state.dropdown_options = {}
    weapon_list_state.selected_index = 1
    weapon_list_state.last_refresh_count = 0

    local data_table = resolve_weapon_data_table(true)
    if not data_table then
        set_weapon_list_from_keys(HARD_CODED_WEAPON_KEYS, "Refresh failed, using preset list")
        return
    end

    local count = 0
    pcall(function() count = data_table:call("get_Count") end)
    for i = 0, (count or 0) - 1 do
        local weapon_data = data_table:call("get_Item", i)
        if weapon_data then
            local weapon_id, id_source = get_weapon_entry_id(weapon_data)
            local label = get_weapon_entry_label(weapon_data, i)
            weapon_list_state.items[#weapon_list_state.items + 1] = {
                index = i,
                weapon_id = weapon_id,
                id_source = id_source,
                label = label
            }
        end
    end

    table.sort(weapon_list_state.items, function(a, b)
        local a_id = a.weapon_id and tostring(a.weapon_id) or ""
        local b_id = b.weapon_id and tostring(b.weapon_id) or ""
        return a_id < b_id
    end)

    for _, item in ipairs(weapon_list_state.items) do
        local display_id = item.weapon_id and tostring(item.weapon_id) or "(no id)"
        local label = item.label or "(no label)"
        weapon_list_state.dropdown_options[#weapon_list_state.dropdown_options + 1] =
            tostring(label) .. " [" .. display_id .. "]"
    end

    weapon_list_state.last_refresh_count = #weapon_list_state.items
    weapon_list_state.last_refresh_status = "OK"
end

set_weapon_list_from_keys(HARD_CODED_WEAPON_KEYS, "Preset list loaded")

local function set_if_exists(obj, field_name, value)
    if obj == nil or field_name == nil or value == nil then
        return false
    end

    local ok = pcall(function()
        obj:set_field(field_name, value)
    end)
    return ok
end

apply_edits = function()
    local data_table = resolve_weapon_data_table(true)
    if not data_table then
        return 0
    end

    local applied = 0
    debug.match_count = 0
    debug.ws_param_count = 0
    debug.shoot_list_count = 0
    debug.shoot_data_count = 0
    debug.write_count = 0
    local count = data_table:call("get_Count")
    debug.data_table_count = count or 0
    for i = 0, count - 1 do
        local weapon_data = data_table:call("get_Item", i)
        if weapon_data then
            local weapon_id = get_weapon_entry_id(weapon_data)
            local edit = rof_edits[weapon_id]
            if edit == nil and type(weapon_id) == "number" then
                edit = rof_edits[tostring(weapon_id)]
            end
            if edit then
                debug.match_count = debug.match_count + 1
                local shoot_data, shoot_path = resolve_shoot_data(weapon_data)
                if shoot_path ~= "(none)" then
                    debug.ws_param_count = debug.ws_param_count + 1
                    debug.shoot_list_count = debug.shoot_list_count + 1
                end
                if shoot_data then
                    debug.shoot_data_count = debug.shoot_data_count + 1
                    local wrote = 0
                    if set_if_exists(shoot_data, "TypeOfShoot", edit.TypeOfShoot) then wrote = wrote + 1 end
                    if set_if_exists(shoot_data, "ShotInterval", edit.ShotInterval) then wrote = wrote + 1 end
                    if set_if_exists(shoot_data, "BurstShotInterval", edit.BurstShotInterval) then wrote = wrote + 1 end
                    if set_if_exists(shoot_data, "BurstNum", edit.BurstNum) then wrote = wrote + 1 end
                    debug.write_count = debug.write_count + wrote
                    if wrote > 0 then
                        applied = applied + 1
                        debug.last_reason = "OK (" .. shoot_path .. ")"
                    else
                        debug.last_reason = "Matched entry, but no fields were writable"
                    end
                else
                    debug.last_reason = "Matched entry, but shoot data path not found"
                end
            end
        end
    end

    debug.last_apply_count = applied
    if applied == 0 and debug.match_count == 0 then
        debug.last_reason = "No matching edit IDs found in table"
    elseif applied == 0 and debug.match_count > 0 and debug.shoot_data_count == 0 then
        debug.last_reason = "Found edit IDs, but no shoot data found"
    elseif applied == 0 and debug.match_count > 0 and debug.write_count == 0 then
        debug.last_reason = "Found shoot data, but field writes failed"
    end
    return applied
end

re.on_pre_application_entry("LockScene", function()
    equipped_weapon_id, equipped_weapon_status = get_equipped_weapon_id()

    if has_applied then
        return
    end

    local camera = sdk.get_primary_camera()
    if not camera then
        has_applied = false
        return
    end

    local count = apply_edits()
    if count > 0 then
        has_applied = true
    end
end)

local scene_manager_type = sdk.find_type_definition("via.SceneManager")
if scene_manager_type then
    local begin_change_scene = scene_manager_type:get_method("begin_change_sceneByString")
    if begin_change_scene then
        sdk.hook(
            begin_change_scene,
            function(args)
                return sdk.PreHookResult.CALL_ORIGINAL
            end,
            function(retval)
                has_applied = false
                return retval
            end
        )
    end
end

re.on_draw_ui(function()
    if imgui.tree_node("ROF Editor") then
        imgui.text("Game: RE9")
        imgui.text("Edits in table: " .. tostring(count_table_entries(rof_edits)))
        imgui.text("Applied this scene: " .. tostring(has_applied))
        if equipped_weapon_id ~= nil then
            local has_edit = rof_edits[equipped_weapon_id] ~= nil
            imgui.text("Equipped Weapon ID: " .. tostring(equipped_weapon_id))
            imgui.text("Has edit entry: " .. tostring(has_edit))
        else
            imgui.text("Equipped Weapon ID: (none)")
            imgui.text_colored("Status: " .. tostring(equipped_weapon_status), 0xFFAAAAFF)
        end
        imgui.separator()
        imgui.text("Catalog Debug:")
        imgui.text("Scene found: " .. tostring(debug.scene_found))
        imgui.text("Catalog found: " .. tostring(debug.catalog_found) .. " (" .. tostring(debug.catalog_name) .. ")")
        imgui.text("Register found: " .. tostring(debug.register_found) .. " (" .. tostring(debug.register_type) .. ")")
        imgui.text("UserData getter: " .. tostring(debug.userdata_getter))
        imgui.text("Data table found: " .. tostring(debug.data_table_found) .. " [" .. tostring(debug.data_table_field) .. "]")
        imgui.text("Data table count: " .. tostring(debug.data_table_count))
        imgui.text("Last apply count: " .. tostring(debug.last_apply_count))
        imgui.text("Matched edit IDs: " .. tostring(debug.match_count))
        imgui.text("Shoot data objects found: " .. tostring(debug.shoot_data_count))
        imgui.text("Total fields written: " .. tostring(debug.write_count))
        imgui.text("Last reason: " .. tostring(debug.last_reason))
        if imgui.button("Refresh Weapon List") then
            refresh_weapon_list()
        end
        imgui.same_line()
        imgui.text("List status: " .. tostring(weapon_list_state.last_refresh_status) .. " (" .. tostring(weapon_list_state.last_refresh_count) .. ")")
        if #weapon_list_state.dropdown_options > 0 then
            local changed = false
            changed, weapon_list_state.selected_index = imgui.combo("Weapon Dropdown", weapon_list_state.selected_index, weapon_list_state.dropdown_options)
            if weapon_list_state.selected_index < 1 then
                weapon_list_state.selected_index = 1
            elseif weapon_list_state.selected_index > #weapon_list_state.items then
                weapon_list_state.selected_index = #weapon_list_state.items
            end
            if changed then
                local selected = weapon_list_state.items[weapon_list_state.selected_index]
                if selected and selected.weapon_id ~= nil then
                    load_ui_for_weapon_id(selected.weapon_id)
                    ui_state.status = "Selected " .. tostring(selected.weapon_id) .. " from dropdown"
                end
            end
            if imgui.button("Load Selected Weapon") then
                local selected = weapon_list_state.items[weapon_list_state.selected_index]
                if selected and selected.weapon_id ~= nil then
                    load_ui_for_weapon_id(selected.weapon_id)
                    ui_state.status = "Loaded " .. tostring(selected.weapon_id)
                else
                    ui_state.status = "Selected weapon has no usable ID"
                end
            end
        else
            imgui.text("Weapon Dropdown: (refresh list first)")
        end
        imgui.text("Weapon IDs from table:")
        if #weapon_list_state.items == 0 then
            imgui.text("(empty - click Refresh Weapon List)")
        elseif imgui.tree_node("Show Full Weapon Table") then
            for _, item in ipairs(weapon_list_state.items) do
                local display_id = item.weapon_id and tostring(item.weapon_id) or "(no id)"
                if item.weapon_id ~= nil then
                    if imgui.button("Use##wid" .. tostring(item.index)) then
                        ui_state.weapon_id_text = tostring(item.weapon_id)
                    end
                    imgui.same_line()
                end
                imgui.text(
                    "#" .. tostring(item.index) ..
                    " ID=" .. display_id ..
                    " | " .. tostring(item.label) ..
                    " | src=" .. tostring(item.id_source)
                )
            end
            imgui.tree_pop()
        end
        imgui.separator()
        imgui.text("Edit Entry (UI):")
        if equipped_weapon_id ~= nil then
            if imgui.button("Use Equipped Weapon ID") then
                ui_state.weapon_id_text = tostring(equipped_weapon_id)
            end
        end
        local changed = false
        changed, ui_state.weapon_id_text = imgui.input_text("Weapon ID", ui_state.weapon_id_text)
        changed, ui_state.type_of_shoot = imgui.drag_float("TypeOfShoot", ui_state.type_of_shoot, 1.0, 0.0, 20.0)
        changed, ui_state.shot_interval = imgui.drag_float("ShotInterval", ui_state.shot_interval, 0.01, 0.0, 10.0)
        changed, ui_state.burst_shot_interval = imgui.drag_float("BurstShotInterval", ui_state.burst_shot_interval, 0.01, 0.0, 10.0)
        changed, ui_state.burst_num = imgui.drag_float("BurstNum", ui_state.burst_num, 1.0, 0.0, 20.0)

        if imgui.button("Save Values") then
            local weapon_id = parse_weapon_key(ui_state.weapon_id_text)
            if weapon_id == nil then
                ui_state.status = "Invalid Weapon ID"
            else
                rof_edits[weapon_id] = {
                    TypeOfShoot = math.floor((tonumber(ui_state.type_of_shoot) or 0) + 0.5),
                    ShotInterval = tonumber(ui_state.shot_interval) or 0.6,
                    BurstShotInterval = tonumber(ui_state.burst_shot_interval) or 5.0,
                    BurstNum = math.floor((tonumber(ui_state.burst_num) or 3) + 0.5)
                }
                local applied_count = apply_all_now()
                ui_state.status = "Saved entry for Weapon ID " .. tostring(weapon_id) .. " (applied " .. tostring(applied_count) .. ")"
            end
        end
        imgui.same_line()
        if imgui.button("Remove Entry") then
            local weapon_id = parse_weapon_key(ui_state.weapon_id_text)
            if weapon_id == nil then
                ui_state.status = "Invalid Weapon ID"
            elseif rof_edits[weapon_id] == nil then
                ui_state.status = "No entry for Weapon ID " .. tostring(weapon_id)
            else
                rof_edits[weapon_id] = nil
                local applied_count = apply_all_now()
                ui_state.status = "Removed Weapon ID " .. tostring(weapon_id) .. " (applied " .. tostring(applied_count) .. ")"
            end
        end
        imgui.same_line()
        if imgui.button("Reapply Now") then
            local applied_count = apply_all_now()
            ui_state.status = "Reapplied edits: " .. tostring(applied_count)
        end

        imgui.text("UI status: " .. tostring(ui_state.status))
        imgui.text("Current entries:")
        local keys = {}
        for weapon_id, _ in pairs(rof_edits) do
            keys[#keys + 1] = weapon_id
        end
        table.sort(keys)
        if #keys == 0 then
            imgui.text("(none)")
        else
            for _, weapon_id in ipairs(keys) do
                local edit = rof_edits[weapon_id]
                if imgui.button("Load##" .. tostring(weapon_id)) then
                    load_ui_from_entry(weapon_id, edit)
                end
                imgui.same_line()
                imgui.text(
                    "ID " .. tostring(weapon_id) ..
                    " | TypeOfShoot=" .. tostring(edit.TypeOfShoot) ..
                    ", ShotInterval=" .. string.format("%.4f", edit.ShotInterval or 0.0) ..
                    ", BurstShotInterval=" .. string.format("%.4f", edit.BurstShotInterval or 0.0) ..
                    ", BurstNum=" .. tostring(edit.BurstNum)
                )
            end
        end
        imgui.text_colored("Edit values in ROFEditor.lua", 0xFFBBBBBB)
        imgui.tree_pop()
    end
end)
