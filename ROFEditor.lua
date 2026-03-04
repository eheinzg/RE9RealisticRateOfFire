-- ROF Editor for RE9
-- Per-weapon rate-of-fire overrides via WeaponCatalog

local DEFAULTS_PATH = "ROFDefaults.json"
local PROFILES_DIR = "ROFProfiles/"
local PROFILES_INDEX = "ROFProfiles_index.json"
local rof_edits = {}
local rof_defaults = {}
local has_applied = false
local disable_regrip = false

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
    ["arm0104"] = "990-TAC",
    ["arm0400"] = "Requiem",
    ["arm0500"] = "Gal",
    ["arm0501"] = "Stiri REVO3 A1",
    ["arm0503"] = "Clatter Carbine",
    ["arm0505"] = "Freya's Needle",
    ["arm0600"] = "Classic 70",
    ["arm0601"] = "Marksman 1A",
}

local WEAPON_KEYS = {
    "arm0000", "arm0001", "arm0003", "arm0004", "arm0005", "arm0006", "arm0007", 
    "arm0100", "arm0103", "arm0104", "arm0400", "arm0500", "arm0501", "arm0503", "arm0505", "arm0600", "arm0601"
}

local dropdown_options = {}
local dropdown_items = {}
local selected_index = 1

local ui_state = {
    type_of_shoot = 0,
    shot_interval = 0.6,
    burst_shot_interval = 5.0,
    burst_num = 3,
    enable_aim_camera_shake = true,
    status = ""
}

local SHOOT_TYPES = { "Semi-Auto", "Full-Auto", "Burst" }

for i, key in ipairs(WEAPON_KEYS) do
    local label = WEAPON_NAMES[key] or key
    dropdown_items[i] = key
    dropdown_options[i] = label
end

local profile_state = {
    name_buf = "",
    names = {},
    selected = 1,
    naming = false,
}

local function sanitize_filename(name)
    return name:gsub("[^%w%-%_ ]", ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function load_profile_index()
    local ok, data = pcall(json.load_file, PROFILES_INDEX)
    if ok and data and type(data) == "table" then
        if data.names and type(data.names) == "table" then
            table.sort(data.names)
            profile_state.names = data.names
            if data.active and type(data.active) == "string" then
                for i, n in ipairs(profile_state.names) do
                    if n == data.active then profile_state.selected = i; break end
                end
            end
        elseif #data > 0 then
            table.sort(data)
            profile_state.names = data
        else
            profile_state.names = {}
        end
    else
        profile_state.names = {}
    end
    if profile_state.selected > #profile_state.names then
        profile_state.selected = math.max(1, #profile_state.names)
    end
end

local function save_profile_index()
    local active_name = profile_state.names[profile_state.selected]
    pcall(json.dump_file, PROFILES_INDEX, { names = profile_state.names, active = active_name })
end

local function save_profile(name)
    local data = {
        enable_aim_camera_shake = ui_state.enable_aim_camera_shake,
        edits = rof_edits,
    }
    pcall(json.dump_file, PROFILES_DIR .. name .. ".json", data)
    local found = false
    for _, n in ipairs(profile_state.names) do
        if n == name then found = true; break end
    end
    if not found then
        profile_state.names[#profile_state.names + 1] = name
        table.sort(profile_state.names)
    end
    save_profile_index()
end

local function load_profile(name)
    local ok, data = pcall(json.load_file, PROFILES_DIR .. name .. ".json")
    if ok and data then
        rof_edits = data.edits or {}
        if data.enable_aim_camera_shake ~= nil then
            ui_state.enable_aim_camera_shake = data.enable_aim_camera_shake
        end
        local key = dropdown_items[selected_index]
        if key and rof_edits[key] then
            local edit = rof_edits[key]
            ui_state.type_of_shoot = edit.TypeOfShoot or 0
            ui_state.shot_interval = edit.ShotInterval or 0.6
            ui_state.burst_shot_interval = edit.BurstShotInterval or 5.0
            ui_state.burst_num = edit.BurstNum or 3
        end
        return true
    end
    return false
end

local function delete_profile(name)
    pcall(json.dump_file, PROFILES_DIR .. name .. ".json", {})
    for i, n in ipairs(profile_state.names) do
        if n == name then
            table.remove(profile_state.names, i)
            break
        end
    end
    save_profile_index()
    if profile_state.selected > #profile_state.names then
        profile_state.selected = math.max(1, #profile_state.names)
    end
end

load_profile_index()
if #profile_state.names > 0 and profile_state.names[profile_state.selected] then
    load_profile(profile_state.names[profile_state.selected])
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
    for _, name in ipairs({ "WeaponCatalog" }) do
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
            local wp = try_field(wd, "WeaponParameter") or try_field(wd, "_WeaponParameter")
            if wp then
                local acsp = try_field(wp, "_AimCameraShakeParam") or try_field(wp, "AimCameraShakeParam")
                if acsp then
                    set_field_safe(acsp, "_EnableAimCameraShake", ui_state.enable_aim_camera_shake)
                    applied = applied + 1
                end
            end

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

local function read_live_values(weapon_key)
    local catalogs = find_all_catalogs(get_scene())
    for _, catalog in ipairs(catalogs) do
        local dt = get_data_table(get_register(catalog))
        if dt then
            local count = 0; pcall(function() count = dt:call("get_Count") end)
            for i = 0, count - 1 do
                local wd; pcall(function() wd = dt:call("get_Item", i) end)
                if wd then
                    local id = get_entry_id(wd)
                    if id == weapon_key then
                        local sd = resolve_shoot_data(wd)
                        if sd then
                            return {
                                TypeOfShoot = tonumber(try_field(sd, "TypeOfShoot")) or 0,
                                ShotInterval = tonumber(try_field(sd, "ShotInterval")) or 0.6,
                                BurstShotInterval = tonumber(try_field(sd, "BurstShotInterval")) or 5.0,
                                BurstNum = tonumber(try_field(sd, "BurstNum")) or 3,
                            }
                        end
                    end
                end
            end
        end
    end
end

local function capture_defaults()
    local defaults = {}
    local catalogs = find_all_catalogs(get_scene())
    for _, catalog in ipairs(catalogs) do
        local dt = get_data_table(get_register(catalog))
        if dt then
            local count = 0; pcall(function() count = dt:call("get_Count") end)
            for i = 0, count - 1 do
                local wd; pcall(function() wd = dt:call("get_Item", i) end)
                if wd then
                    local id = get_entry_id(wd)
                    if id and not defaults[id] then
                        local acs_default = true
                        local wp = try_field(wd, "WeaponParameter") or try_field(wd, "_WeaponParameter")
                        if wp then
                            local acsp = try_field(wp, "_AimCameraShakeParam") or try_field(wp, "AimCameraShakeParam")
                            if acsp then
                                local val = try_field(acsp, "_EnableAimCameraShake")
                                if val ~= nil then acs_default = val end
                            end
                        end

                        local sd = resolve_shoot_data(wd)
                        if sd then
                            local tos = try_field(sd, "TypeOfShoot")
                            local si = try_field(sd, "ShotInterval")
                            local bsi = try_field(sd, "BurstShotInterval")
                            local bn = try_field(sd, "BurstNum")
                            defaults[id] = {
                                TypeOfShoot = tonumber(tos) or 0,
                                ShotInterval = tonumber(si) or 0.6,
                                BurstShotInterval = tonumber(bsi) or 5.0,
                                BurstNum = tonumber(bn) or 3,
                                EnableAimCameraShake = acs_default
                            }
                        end
                    end
                end
            end
        end
    end
    rof_defaults = defaults
    pcall(json.dump_file, DEFAULTS_PATH, defaults)
    return defaults
end

local function load_defaults()
    local ok, data = pcall(json.load_file, DEFAULTS_PATH)
    if ok and data then rof_defaults = data end
end

load_defaults()

local function get_player()
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    if not cm then return nil end
    local ctx = nil
    pcall(function() ctx = cm:call("getPlayerContextRef") end)
    return ctx
end

local function get_player_motion()
    local ctx = get_player()
    if not ctx then return nil end
    local go = nil
    pcall(function() go = ctx:call("get_GameObject") end)
    if not go then return nil end
    local motion_type = sdk.typeof("via.motion.Motion")
    if not motion_type then return nil end
    local motion = nil
    pcall(function() motion = go:call("getComponent(System.Type)", motion_type) end)
    return motion
end

local regrip_hook_log = {}
local regrip_prev_mid = nil
local regrip_prev_bank = nil
local regrip_prev_frame = nil
local regrip_prev_speed = nil

re.on_pre_application_entry("UpdateBehavior", function()
    if not disable_regrip then return end
    local motion = get_player_motion()
    if not motion then return end

    local l8 = nil
    pcall(function() l8 = motion:call("getLayer", 8) end)
    if not l8 then return end

    local mid = nil; pcall(function() mid = l8:call("get_MotionID") end)
    local mbank = nil; pcall(function() mbank = l8:call("get_MotionBankID") end)
    local frame = nil; pcall(function() frame = l8:call("get_Frame") end)
    local speed = nil; pcall(function() speed = l8:call("get_Speed") end)

    if mid and mid ~= 7001 then
        regrip_prev_mid = mid
        regrip_prev_bank = mbank
        regrip_prev_frame = frame
        regrip_prev_speed = speed
    end
end)

re.on_pre_application_entry("LateUpdateBehavior", function()
    if not disable_regrip then return end
    local motion = get_player_motion()
    if not motion then return end

    local l8 = nil
    pcall(function() l8 = motion:call("getLayer", 8) end)
    if not l8 then return end

    local mid = nil; pcall(function() mid = l8:call("get_MotionID") end)
    local mbank = nil; pcall(function() mbank = l8:call("get_MotionBankID") end)

    if mid == 7001 and mbank == 100 and regrip_prev_mid then
        pcall(function() l8:call("set_MotionID", regrip_prev_mid) end)
        pcall(function() l8:call("set_MotionBankID", regrip_prev_bank or 0) end)
        pcall(function() l8:call("set_Frame", regrip_prev_frame or 0.0) end)
        pcall(function() l8:call("set_Speed", regrip_prev_speed or 1.0) end)

        local entry = "restored L8: mid=" .. tostring(regrip_prev_mid) .. " bank=" .. tostring(regrip_prev_bank)
        if #regrip_hook_log >= 20 then table.remove(regrip_hook_log, 1) end
        regrip_hook_log[#regrip_hook_log + 1] = entry
    end
end)

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

        if #profile_state.names > 0 then
            local prof_changed
            prof_changed, profile_state.selected = imgui.combo("Profile", profile_state.selected, profile_state.names)
            if profile_state.selected < 1 then profile_state.selected = 1 end
            if profile_state.selected > #profile_state.names then profile_state.selected = #profile_state.names end
            if prof_changed then
                local pname = profile_state.names[profile_state.selected]
                if pname and load_profile(pname) then
                    apply_all_now()
                    save_profile_index()
                    ui_state.status = "Loaded profile: " .. pname
                end
            end
            if imgui.button("Save") then
                local pname = profile_state.names[profile_state.selected]
                if pname then
                    save_profile(pname)
                    ui_state.status = "Profile saved: " .. pname
                end
            end
            imgui.same_line()
            if imgui.button("Delete") then
                local pname = profile_state.names[profile_state.selected]
                if pname then
                    delete_profile(pname)
                    ui_state.status = "Deleted profile: " .. pname
                end
            end
            imgui.same_line()
        end
        if imgui.button("New Profile") then
            profile_state.naming = not profile_state.naming
        end
        if profile_state.naming then
            local buf_changed
            buf_changed, profile_state.name_buf = imgui.input_text("Name", profile_state.name_buf)
            imgui.same_line()
            if imgui.button("Create") then
                local safe = sanitize_filename(profile_state.name_buf)
                if safe ~= "" then
                    save_profile(safe)
                    for i, n in ipairs(profile_state.names) do
                        if n == safe then profile_state.selected = i; break end
                    end
                    save_profile_index()
                    profile_state.name_buf = ""
                    profile_state.naming = false
                    ui_state.status = "Profile saved: " .. safe
                else
                    ui_state.status = "Enter a profile name"
                end
            end
            if ui_state.status:match("^Enter a profile name") then
                imgui.same_line()
                imgui.text_colored(ui_state.status, 0xFF00FFFF)
            end
        end
        if ui_state.status:match("^Profile saved:") or ui_state.status:match("^Deleted profile:") then
            imgui.text_colored(ui_state.status, ui_state.status:match("^Deleted") and 0xFF5555FF or 0xFF00FF00)
        end
        imgui.separator()

        local acs_changed = false
        acs_changed, ui_state.enable_aim_camera_shake = imgui.checkbox("Enable Aim Camera Shake (Global)", ui_state.enable_aim_camera_shake)
        if acs_changed then
            apply_all_now()
            ui_state.status = "Global Aim Camera Shake: " .. (ui_state.enable_aim_camera_shake and "Enabled" or "Disabled")
        end

        local regrip_changed = false
        regrip_changed, disable_regrip = imgui.checkbox("Disable Regrip Animation", disable_regrip)
        if regrip_changed then
            regrip_hook_log = {}
            ui_state.status = "Regrip animation " .. (disable_regrip and "disabled" or "enabled")
            if not disable_regrip then
                regrip_prev_mid = nil
                regrip_prev_bank = nil
                regrip_prev_frame = nil
                regrip_prev_speed = nil
            end
        end
        if #regrip_hook_log > 0 and imgui.tree_node("Regrip Log") then
            if imgui.button("Clear") then regrip_hook_log = {} end
            for _, line in ipairs(regrip_hook_log) do
                imgui.text(line)
            end
            imgui.tree_pop()
        end
        imgui.separator()

        changed, selected_index = imgui.combo("Weapon", selected_index, dropdown_options)
        if selected_index < 1 then selected_index = 1 end
        if selected_index > #dropdown_items then selected_index = #dropdown_items end
        if changed then
            local key = dropdown_items[selected_index]
            local vals = rof_edits[key] or read_live_values(key)
            if vals then
                ui_state.type_of_shoot = vals.TypeOfShoot or 0
                ui_state.shot_interval = vals.ShotInterval or 0.6
                ui_state.burst_shot_interval = vals.BurstShotInterval or 5.0
                ui_state.burst_num = vals.BurstNum or 3
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
                ui_state.status = "Saved settings for " .. (WEAPON_NAMES[key] or key)
            end
        end

        imgui.separator()
        if imgui.button("Capture Defaults") then
            local defaults = capture_defaults()
            local n = 0; for _ in pairs(defaults) do n = n + 1 end
            ui_state.status = "Captured defaults for " .. tostring(n) .. " weapons"
        end
        imgui.same_line()
        if imgui.button("Reset Current Weapon") then
            local key = dropdown_items[selected_index]
            if key and rof_defaults[key] then
                local def = rof_defaults[key]
                rof_edits[key] = {
                    TypeOfShoot = def.TypeOfShoot,
                    ShotInterval = def.ShotInterval,
                    BurstShotInterval = def.BurstShotInterval,
                    BurstNum = def.BurstNum
                }
                ui_state.type_of_shoot = def.TypeOfShoot
                ui_state.shot_interval = def.ShotInterval
                ui_state.burst_shot_interval = def.BurstShotInterval
                ui_state.burst_num = def.BurstNum
                apply_all_now()
                ui_state.status = "Reset " .. (WEAPON_NAMES[key] or key) .. " to defaults"
            elseif key then
                ui_state.status = "No defaults saved for " .. (WEAPON_NAMES[key] or key) .. " (capture first)"
            end
        end
        imgui.same_line()
        if imgui.button("Reset All to Defaults") then
            local count = 0
            for key, def in pairs(rof_defaults) do
                rof_edits[key] = {
                    TypeOfShoot = def.TypeOfShoot,
                    ShotInterval = def.ShotInterval,
                    BurstShotInterval = def.BurstShotInterval,
                    BurstNum = def.BurstNum
                }
                -- We use the first one found or just assume true for global
                if def.EnableAimCameraShake ~= nil then
                    ui_state.enable_aim_camera_shake = def.EnableAimCameraShake
                end
                count = count + 1
            end
            apply_all_now()
            local key = dropdown_items[selected_index]
            if key and rof_defaults[key] then
                local def = rof_defaults[key]
                ui_state.type_of_shoot = def.TypeOfShoot
                ui_state.shot_interval = def.ShotInterval
                ui_state.burst_shot_interval = def.BurstShotInterval
                ui_state.burst_num = def.BurstNum
            end
            ui_state.status = "Reset all " .. tostring(count) .. " weapons to defaults"
        end

        local profile_msg = ui_state.status:match("^Enter a profile name")
            or ui_state.status:match("^Profile saved:")
            or ui_state.status:match("^Deleted profile:")
        if ui_state.status ~= "" and not profile_msg then
            local color = 0xFFFFFFFF
            if ui_state.status:match("^Saved settings for") then
                color = 0xFF00FF00
            elseif ui_state.status:match("^No defaults saved") then
                color = 0xFF00FFFF
            end
            imgui.text_colored(ui_state.status, color)
        end

        -- local has_entries = false
        -- for _ in pairs(rof_edits) do has_entries = true; break end
        -- if has_entries and imgui.tree_node("Active Edits") then
        --     for key, edit in pairs(rof_edits) do
        --         local name = WEAPON_NAMES[key] or key
        --         local mode = SHOOT_TYPES[(edit.TypeOfShoot or 0) + 1] or "?"
        --         imgui.text(name .. " [" .. key .. "] " .. mode ..
        --             " | Interval=" .. string.format("%.3f", edit.ShotInterval or 0) ..
        --             " | BurstInterval=" .. string.format("%.3f", edit.BurstShotInterval or 0) ..
        --             " | BurstNum=" .. tostring(edit.BurstNum or 0))
        --     end
        --     imgui.tree_pop()
        -- end

        imgui.tree_pop()
    end
end)
