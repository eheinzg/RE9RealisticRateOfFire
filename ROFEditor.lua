-- ROF Editor for RE9
-- Per-weapon rate-of-fire overrides via WeaponCatalog

local rof_edits = {}
local has_applied = false

local WEAPON_NAMES = {
    ["arm0000"] = "Matilda IMP",
    ["arm0001"] = "S&S M232",
    ["arm0003"] = "Silencer 9",
    ["arm0004"] = "B934",
    ["arm0005"] = "Redemption",
    ["arm0006"] = "Ghost Grudge",
    ["arm0007"] = "Alligator Snapper",
    ["arm0100"] = "MSBG 500",
    ["arm0103"] = "W870 Police",
    ["arm0400"] = "Requiem",
    ["arm0500"] = "Gal",
    ["arm0501"] = "Stiri REVO3 A1",
    ["arm0503"] = "Clatter Carbine",
    ["arm0505"] = "Freya's Needle",
    ["arm0600"] = "Classic 70",
    ["arm0601"] = "Marksman 1A",
}

local WEAPON_KEYS = {
    "arm0000", "arm0001", "arm0002", "arm0003", "arm0004", "arm0005", "arm0006", "arm0007", 
    "arm0100", "arm0103", "arm0400", "arm0500", "arm0501", "arm0503", "arm0505", "arm0600", "arm0601"
}

local dropdown_options = {}
local dropdown_items = {}
local selected_index = 1

local ui_state = {
    type_of_shoot = 0,
    shot_interval = 0.6,
    burst_shot_interval = 5.0,
    burst_num = 3,
    status = ""
}

local SHOOT_TYPES = { "Semi-Auto", "Full-Auto", "Burst" }

for i, key in ipairs(WEAPON_KEYS) do
    local label = WEAPON_NAMES[key] or key
    dropdown_items[i] = key
    dropdown_options[i] = label
end

local function try_call(obj, method)
    local r; pcall(function() r = obj:call(method) end); return r
end

local function try_field(obj, name)
    local r; pcall(function() r = obj:get_field(name) end); return r
end

local function set_field_safe(obj, name, value)
    if obj == nil or name == nil or value == nil then return false end
    return pcall(function() obj:set_field(name, value) end)
end

local function get_scene()
    local sm = sdk.get_native_singleton("via.SceneManager")
    local sm_type = sm and sdk.find_type_definition("via.SceneManager")
    return sm_type and sdk.call_native_func(sm, sm_type, "get_CurrentScene")
end

local function find_all_catalogs(scene)
    local results = {}
    if not scene then return results end
    local seen = {}
    for _, name in ipairs({ "WeaponCatalog", "WeaponCatalog_AO", "WeaponCatalog_MC", "WeaponCatalog_MC_2nd" }) do
        local obj = scene:call("findGameObject(System.String)", name)
        if obj then
            local addr = obj:get_address()
            if not seen[addr] then
                seen[addr] = true
                results[#results + 1] = obj
            end
        end
    end
    local reg_type = sdk.typeof("app.WeaponCatalogRegister")
    if reg_type then
        local all_components = nil
        pcall(function() all_components = scene:call("findComponents(System.Type)", reg_type) end)
        if all_components then
            local n = 0; pcall(function() n = all_components:call("get_Count") end)
            for i = 0, n - 1 do
                local comp; pcall(function() comp = all_components:call("get_Item", i) end)
                if comp then
                    local go; pcall(function() go = comp:call("get_GameObject") end)
                    if go then
                        local addr = go:get_address()
                        if not seen[addr] then
                            seen[addr] = true
                            results[#results + 1] = go
                        end
                    end
                end
            end
        end
    end
    return results
end

local function get_register(catalog)
    if not catalog then return nil end
    for _, tn in ipairs({ "app.WeaponCatalogRegister", "chainsaw.WeaponCatalogRegister" }) do
        local t = sdk.typeof(tn)
        if t then
            local r = catalog:call("getComponent(System.Type)", t)
            if r then return r end
        end
    end
end

local function get_data_table(register)
    if not register then return nil end
    local ud = try_field(register, "_WeaponEquipParamCatalogUserData")
        or try_call(register, "get_WeaponEquipParamCatalogUserData")
        or try_field(register, "_PlayerWeaponParameterUserData")
        or try_call(register, "get_PlayerWeaponParameterUserData")
        or try_field(register, "_WeaponCatalogUserData")
    if not ud then return nil end
    local dt = try_field(ud, "_DataTable") or try_field(ud, "_WeaponEquipParams") or try_call(ud, "get_DataTable")
    if dt then return dt end
    local cd = try_field(ud, "_CatalogData")
    if cd then return try_field(cd, "_DataTable") or try_field(cd, "_WeaponEquipParams") or try_call(cd, "get_DataTable") end
end

local function normalize_key(value)
    if value == nil then return nil end
    local s = string.lower(tostring(value)):gsub("^%s+", ""):gsub("%s+$", "")
    if s:match("^[%a_]+%d+$") then return s end
end

local function get_entry_id(weapon_data)
    if not weapon_data then return nil end
    for _, f in ipairs({ "_WeaponID", "WeaponID", "_WeaponId" }) do
        local k = normalize_key(try_field(weapon_data, f))
        if k then return k end
    end
    local wc = try_field(weapon_data, "_WeaponCache") or try_field(weapon_data, "WeaponCache")
    if wc then
        local k = normalize_key(wc)
        if k then return k end
    end
    local wp = try_field(weapon_data, "WeaponParameter") or try_field(weapon_data, "_WeaponParameter")
    if wp then
        local k = string.lower(tostring(wp)):match("([%a_]+%d+)")
        if k then return k end
    end
end

local function resolve_shoot_data(weapon_data)
    if not weapon_data then return nil end
    local paths = {
        { try_field(weapon_data, "_WeaponStructureParam") or try_field(weapon_data, "WeaponStructureParam") },
    }
    local wp = try_field(weapon_data, "WeaponParameter") or try_field(weapon_data, "_WeaponParameter")
    if wp then
        paths[#paths + 1] = { try_field(wp, "_WeaponStructureParam") or try_field(wp, "WeaponStructureParam") }
    end
    for _, p in ipairs(paths) do
        local ws = p[1]
        if ws then
            local sdl = try_field(ws, "_TypeOfShootData") or try_field(ws, "TypeOfShootData") or try_call(ws, "get_TypeOfShootData")
            if sdl then
                local c = 0; pcall(function() c = sdl:call("get_Count") end)
                if c > 0 then
                    local sd; pcall(function() sd = sdl:call("get_Item", 0) end)
                    if sd then return sd end
                end
            end
        end
    end
end

local function apply_edits_to_table(dt)
    if not dt then return 0 end
    local applied = 0
    local count = 0; pcall(function() count = dt:call("get_Count") end)
    for i = 0, count - 1 do
        local wd; pcall(function() wd = dt:call("get_Item", i) end)
        if wd then
            local id = get_entry_id(wd)
            local edit = id and rof_edits[id]
            if edit then
                local sd = resolve_shoot_data(wd)
                if sd then
                    set_field_safe(sd, "TypeOfShoot", edit.TypeOfShoot)
                    set_field_safe(sd, "ShotInterval", edit.ShotInterval)
                    set_field_safe(sd, "BurstShotInterval", edit.BurstShotInterval)
                    set_field_safe(sd, "BurstNum", edit.BurstNum)
                    applied = applied + 1
                end
            end
        end
    end
    return applied
end

local function apply_edits()
    local catalogs = find_all_catalogs(get_scene())
    local total = 0
    for _, catalog in ipairs(catalogs) do
        local dt = get_data_table(get_register(catalog))
        total = total + apply_edits_to_table(dt)
    end
    return total
end

local function apply_all_now()
    has_applied = false
    local count = apply_edits()
    if count > 0 then has_applied = true end
    return count
end

re.on_pre_application_entry("LockScene", function()
    if has_applied then return end
    if not sdk.get_primary_camera() then
        has_applied = false
        return
    end
    if apply_edits() > 0 then has_applied = true end
end)

local sm_type = sdk.find_type_definition("via.SceneManager")
if sm_type then
    local m = sm_type:get_method("begin_change_sceneByString")
    if m then
        sdk.hook(m,
            function() return sdk.PreHookResult.CALL_ORIGINAL end,
            function(retval) has_applied = false; return retval end
        )
    end
end

re.on_draw_ui(function()
    if imgui.tree_node("ROF Editor") then
        local changed

        changed, selected_index = imgui.combo("Weapon", selected_index, dropdown_options)
        if selected_index < 1 then selected_index = 1 end
        if selected_index > #dropdown_items then selected_index = #dropdown_items end
        if changed then
            local key = dropdown_items[selected_index]
            local edit = rof_edits[key]
            if edit then
                ui_state.type_of_shoot = edit.TypeOfShoot or 0
                ui_state.shot_interval = edit.ShotInterval or 0.6
                ui_state.burst_shot_interval = edit.BurstShotInterval or 5.0
                ui_state.burst_num = edit.BurstNum or 3
            end
        end

        local any_changed = false
        local shoot_idx = math.floor(ui_state.type_of_shoot + 1)
        if shoot_idx < 1 then shoot_idx = 1 end
        if shoot_idx > 3 then shoot_idx = 3 end
        changed, shoot_idx = imgui.combo("TypeOfShoot", shoot_idx, SHOOT_TYPES)
        if changed then ui_state.type_of_shoot = shoot_idx - 1; any_changed = true end

        changed, ui_state.shot_interval = imgui.drag_float("ShotInterval", ui_state.shot_interval, 0.01, 0.0, 10.0)
        if changed then any_changed = true end
        changed, ui_state.burst_shot_interval = imgui.drag_float("BurstShotInterval", ui_state.burst_shot_interval, 0.01, 0.0, 10.0)
        if changed then any_changed = true end
        changed, ui_state.burst_num = imgui.drag_float("BurstNum", ui_state.burst_num, 1.0, 0.0, 20.0)
        if changed then any_changed = true end

        if any_changed then
            local key = dropdown_items[selected_index]
            if key then
                rof_edits[key] = {
                    TypeOfShoot = math.floor(ui_state.type_of_shoot + 0.5),
                    ShotInterval = ui_state.shot_interval,
                    BurstShotInterval = ui_state.burst_shot_interval,
                    BurstNum = math.floor(ui_state.burst_num + 0.5)
                }
                apply_all_now()
                ui_state.status = "Saved " .. key
            end
        end

        if imgui.button("Remove Entry") then
            local key = dropdown_items[selected_index]
            if key and rof_edits[key] then
                rof_edits[key] = nil
                apply_all_now()
                ui_state.status = "Removed " .. key
            end
        end

        if ui_state.status ~= "" then
            imgui.text(ui_state.status)
        end

        local has_entries = false
        for _ in pairs(rof_edits) do has_entries = true; break end
        if has_entries and imgui.tree_node("Active Edits") then
            for key, edit in pairs(rof_edits) do
                local name = WEAPON_NAMES[key] or key
                local mode = SHOOT_TYPES[(edit.TypeOfShoot or 0) + 1] or "?"
                imgui.text(name .. " [" .. key .. "] " .. mode ..
                    " | Interval=" .. string.format("%.3f", edit.ShotInterval or 0) ..
                    " | BurstInterval=" .. string.format("%.3f", edit.BurstShotInterval or 0) ..
                    " | BurstNum=" .. tostring(edit.BurstNum or 0))
            end
            imgui.tree_pop()
        end

        imgui.tree_pop()
    end
end)
