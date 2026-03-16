-- Iron Sights - Per-weapon camera position offset for RE9
-- Only applies when CurrentViewMode == FPS (1)

local SETTINGS_PATH = "IronSights/ironsights.json"
local COVER_SETTINGS_PATH = "IronSights/ironsights_cover.json"
local PREFS_PATH = "IronSights/ironsights_prefs.json"

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
    ["arm0400_leon"]  = "Requiem (Leon)",
    ["arm0400_grace"] = "Requiem (Grace)",
    ["arm0500"] = "Gal",
    ["arm0501"] = "Stiri REVO3 A1",
    ["arm0503"] = "Clatter Carbine",
    ["arm0505"] = "Freya's Needle",
    ["arm0600"] = "Classic 70",
    ["arm0601"] = "Marksman 1A",
    ["arm0700"] = "RPG-7",
}

local WEAPON_KEYS = {
    "arm0000", "arm0001", "arm0003", "arm0004", "arm0005", "arm0006", "arm0007",
    "arm0100", "arm0103", "arm0104", "arm0400_leon", "arm0400_grace",
    "arm0500", "arm0501", "arm0503", "arm0505", "arm0600", "arm0601", "arm0700"
}

local dropdown_options = {}
local dropdown_items = {}
for _, key in ipairs(WEAPON_KEYS) do
    table.insert(dropdown_options, WEAPON_NAMES[key] or key)
    table.insert(dropdown_items, key)
end

local selected_index = 1
local last_equipped_id = nil
local copy_all_confirm = false
local reset_confirm = false
local edit_mode = 1
local EDIT_MODE_LABELS = { "Normal", "Cover Right", "Cover Left" }
local EDIT_MODE_COVER_STATE = { nil, "CoverActionRight", "CoverActionLeft" }

-- Per-weapon offsets: { ["arm0000"] = { x=0, y=0, z=0 }, ... }
local DEFAULT_OFFSETS = {
    ["arm0000"]       = { x =  0.0,    y = -0.037, z = 0.0 },
    ["arm0001"]       = { x =  0.0,    y = -0.021, z = 0.0 },
    ["arm0003"]       = { x =  0.0,    y = -0.032, z = 0.0 },
    ["arm0004"]       = { x =  0.0,    y = -0.020, z = 0.0 },
    ["arm0005"]       = { x = -0.002,  y = -0.050, z = 0.0 },
    ["arm0006"]       = { x =  0.0,    y = -0.037, z = 0.0 },
    ["arm0007"]       = { x =  0.0,    y = -0.039, z = 0.0 },
    ["arm0100"]       = { x =  0.0,    y = -0.071, z = 0.0 },
    ["arm0103"]       = { x =  0.0,    y = -0.066, z = 0.0 },
    ["arm0104"]       = { x =  0.0,    y = -0.068, z = 0.0 },
    ["arm0400_leon"]  = { x = -0.002,  y = -0.040, z = 0.0 },
    ["arm0400_grace"] = { x =  0.001,  y = -0.036, z = 0.0 },
    ["arm0500"]       = { x =  0.0,    y = -0.055, z = 0.0 },
    ["arm0501"]       = { x =  0.0,    y = -0.044, z = 0.0 },
    ["arm0503"]       = { x = -0.045,  y = -0.026, z = 0.0 },
    ["arm0505"]       = { x =  0.0,    y = -0.037, z = 0.0 },
    ["arm0600"]       = { x =  0.0,    y = -0.055, z = 0.0 },
    ["arm0601"]       = { x =  0.0,    y = -0.047, z = 0.0 },
    ["arm0700"]       = { x =  0.0,    y =  0.0,   z = 0.0 },
}

local weapon_offsets = {}
local function save_offsets()
    json.dump_file(SETTINGS_PATH, weapon_offsets)
end
local function load_offsets()
    local saved = json.load_file(SETTINGS_PATH)
    if saved and type(saved) == "table" and next(saved) ~= nil then
        weapon_offsets = saved
    else
        for k, v in pairs(DEFAULT_OFFSETS) do
            weapon_offsets[k] = { x = v.x, y = v.y, z = v.z }
        end
        save_offsets()
    end
end
load_offsets()

local COVER_STATES = { "CoverActionRight", "CoverActionLeft", "CrouchCoverActionRight", "CrouchCoverActionLeft" }
local COVER_STATE_LABELS = {
    CoverActionRight = "Cover Right", CoverActionLeft = "Cover Left",
    CrouchCoverActionRight = "Crouch Cover Right", CrouchCoverActionLeft = "Crouch Cover Left",
}
local COVER_STATE_TO_KEY = {
    CoverActionRight = "CoverActionRight", CoverActionLeft = "CoverActionLeft",
    CrouchCoverActionRight = "CoverActionRight", CrouchCoverActionLeft = "CoverActionLeft",
}

local DEFAULT_COVER_OFFSETS = {
    ["arm0000|CoverActionRight"] = { x = -0.004, y = -0.044, z = 0.0 },
    ["arm0000|CoverActionLeft"]  = { x =  0.004, y = -0.044, z = 0.0 },
    ["arm0001|CoverActionRight"] = { x = -0.007, y = -0.017, z = 0.0 },
    ["arm0001|CoverActionLeft"]  = { x =  0.007, y = -0.017, z = 0.0 },
    ["arm0003|CoverActionRight"] = { x = -0.004, y = -0.037, z = 0.0 },
    ["arm0003|CoverActionLeft"]  = { x =  0.004, y = -0.037, z = 0.0 },
    ["arm0004|CoverActionRight"] = { x = -0.007, y = -0.017, z = 0.0 },
    ["arm0004|CoverActionLeft"]  = { x =  0.007, y = -0.017, z = 0.0 },
    ["arm0005|CoverActionRight"] = { x = -0.001, y = -0.022, z = 0.0 },
    ["arm0005|CoverActionLeft"]  = { x = -0.001, y = -0.022, z = 0.0 },
    ["arm0006|CoverActionRight"] = { x = -0.005, y = -0.040, z = 0.0 },
    ["arm0006|CoverActionLeft"]  = { x =  0.005, y = -0.040, z = 0.0 },
    ["arm0007|CoverActionRight"] = { x = -0.006, y = -0.042, z = 0.0 },
    ["arm0007|CoverActionLeft"]  = { x =  0.006, y = -0.042, z = 0.0 },
    ["arm0100|CoverActionRight"] = { x = -0.020, y = -0.071, z = 0.0 },
    ["arm0100|CoverActionLeft"]  = { x =  0.020, y = -0.071, z = 0.0 },
    ["arm0103|CoverActionRight"] = { x = -0.019, y = -0.070, z = 0.0 },
    ["arm0103|CoverActionLeft"]  = { x =  0.019, y = -0.070, z = 0.0 },
    ["arm0104|CoverActionRight"] = { x = -0.019, y = -0.067, z = 0.0 },
    ["arm0104|CoverActionLeft"]  = { x =  0.019, y = -0.067, z = 0.0 },
    ["arm0400_leon|CoverActionRight"]  = { x = -0.009, y = -0.047, z = 0.0 },
    ["arm0400_leon|CoverActionLeft"]   = { x =  0.009, y = -0.047, z = 0.0 },
    ["arm0400_grace|CoverActionRight"] = { x = -0.014, y = -0.026, z = 0.0 },
    ["arm0400_grace|CoverActionLeft"]  = { x =  0.016, y = -0.030, z = 0.0 },
    ["arm0500|CoverActionRight"] = { x = -0.019, y = -0.059, z = 0.0 },
    ["arm0500|CoverActionLeft"]  = { x =  0.019, y = -0.059, z = 0.0 },
    ["arm0501|CoverActionRight"] = { x = -0.014, y = -0.065, z = 0.0 },
    ["arm0501|CoverActionLeft"]  = { x =  0.014, y = -0.065, z = 0.0 },
    ["arm0600|CoverActionRight"] = { x = -0.020, y = -0.060, z = 0.0 },
    ["arm0600|CoverActionLeft"]  = { x =  0.020, y = -0.060, z = 0.0 },
    ["arm0601|CoverActionRight"] = { x = -0.015, y = -0.049, z = 0.0 },
    ["arm0601|CoverActionLeft"]  = { x =  0.015, y = -0.049, z = 0.0 },
}

local cover_offsets = {}
local function save_cover_offsets()
    json.dump_file(COVER_SETTINGS_PATH, cover_offsets)
end
local function load_cover_offsets()
    local saved = json.load_file(COVER_SETTINGS_PATH)
    if saved and type(saved) == "table" and next(saved) ~= nil then
        cover_offsets = saved
    else
        for k, v in pairs(DEFAULT_COVER_OFFSETS) do
            cover_offsets[k] = { x = v.x, y = v.y, z = v.z }
        end
        save_cover_offsets()
    end
end
load_cover_offsets()

local function get_cover_offset(weapon_key, cover_state)
    local k = weapon_key .. "|" .. cover_state
    return cover_offsets[k]
end

local function set_cover_offset(weapon_key, cover_state, x, y, z)
    local k = weapon_key .. "|" .. cover_state
    cover_offsets[k] = { x = x, y = y, z = z }
    save_cover_offsets()
end

local prefs = { hide_reticle = true, bullet_from_muzzle = true, muzzle_all_views = false, transition_in = 0.15, transition_out = 1.0, transition_swap = 0.5, standard_fps_mode = false, ha_hold_to_activate = false, ha_breath_duration = 0, enable_aim_camera_shake = true, zero_min_fit_rate = false }
do
    local saved = json.load_file(PREFS_PATH)
    if saved and type(saved) == "table" then
        if saved.hide_reticle ~= nil then prefs.hide_reticle = saved.hide_reticle end
        if saved.bullet_from_muzzle ~= nil then prefs.bullet_from_muzzle = saved.bullet_from_muzzle end
        if saved.muzzle_all_views ~= nil then prefs.muzzle_all_views = saved.muzzle_all_views end
        if saved.transition_in ~= nil then prefs.transition_in = saved.transition_in end
        if saved.transition_out ~= nil then prefs.transition_out = saved.transition_out end
        if saved.transition_swap ~= nil then prefs.transition_swap = saved.transition_swap end
        if saved.standard_fps_mode ~= nil then prefs.standard_fps_mode = saved.standard_fps_mode end
        if saved.ha_hold_to_activate ~= nil then prefs.ha_hold_to_activate = saved.ha_hold_to_activate end
        if saved.ha_breath_duration ~= nil then prefs.ha_breath_duration = saved.ha_breath_duration end
        if saved.enable_aim_camera_shake ~= nil then prefs.enable_aim_camera_shake = saved.enable_aim_camera_shake end
        if saved.zero_min_fit_rate ~= nil then prefs.zero_min_fit_rate = saved.zero_min_fit_rate end
    end
end
local function save_prefs()
    json.dump_file(PREFS_PATH, prefs)
end

local TYPE_PlayerEquipment = sdk.typeof("app.PlayerEquipment")
local TYPE_CameraPosSetting = sdk.typeof("app.PlayerCameraPositionSetting")

local HOLD_ANIM_PATH = "IronSights/hold_anim.json"
local hold_anim_edits = {}
do
    local saved = json.load_file(HOLD_ANIM_PATH)
    if saved and type(saved) == "table" then hold_anim_edits = saved end
end
local function save_hold_anim() json.dump_file(HOLD_ANIM_PATH, hold_anim_edits) end

local _any_hold_anim_enabled = false
local function refresh_any_hold_anim()
    for _, edit in pairs(hold_anim_edits) do
        if edit.enabled then _any_hold_anim_enabled = true; return end
    end
    _any_hold_anim_enabled = false
end
refresh_any_hold_anim()

local _ha_was_holding = false
local _ha_blend_weight = 0.0
local _ha_last_time = os.clock()
local _ha_active_start = nil
local _ha_breath_mfr_zeroed = false

local function get_hold_anim_for_key(key)
    local edit = key and hold_anim_edits[key]
    if edit and edit.enabled then
        return true, edit.force or 1.0, edit.speed or 1.0, edit.layers, edit.delay or 0, edit.ramp or 4.0
    end
    return false, 1.0, 1.0, nil, 0, 4.0
end

local _acs_TYPE_WCR = sdk.typeof("app.WeaponCatalogRegister")
local _acs_REGISTER_TYPES = {}
do
    for _, tn in ipairs({ "app.WeaponCatalogRegister", "chainsaw.WeaponCatalogRegister" }) do
        local t = sdk.typeof(tn)
        if t then _acs_REGISTER_TYPES[#_acs_REGISTER_TYPES + 1] = t end
    end
end

local function _acs_get_scene()
    local sm = sdk.get_native_singleton("via.SceneManager")
    local sm_type = sm and sdk.find_type_definition("via.SceneManager")
    return sm_type and sdk.call_native_func(sm, sm_type, "get_CurrentScene")
end

local function _acs_try_field(obj, name)
    local r; pcall(function() r = obj:get_field(name) end); return r
end

local function _acs_try_call(obj, method)
    local r; pcall(function() r = obj:call(method) end); return r
end

local function _acs_apply()
    local scene = _acs_get_scene()
    if not scene then return end
    local catalogs = {}
    pcall(function()
        local obj = scene:call("findGameObject(System.String)", "WeaponCatalog")
        if obj then catalogs[#catalogs + 1] = obj end
    end)
    if _acs_TYPE_WCR then
        pcall(function()
            local all = scene:call("findComponents(System.Type)", _acs_TYPE_WCR)
            if all then
                local n = 0; pcall(function() n = all:call("get_Count") end)
                for i = 0, n - 1 do
                    pcall(function()
                        local comp = all:call("get_Item", i)
                        if comp then
                            local go = comp:call("get_GameObject")
                            if go then catalogs[#catalogs + 1] = go end
                        end
                    end)
                end
            end
        end)
    end
    for _, catalog in ipairs(catalogs) do
        local reg
        for _, t in ipairs(_acs_REGISTER_TYPES) do
            reg = catalog:call("getComponent(System.Type)", t)
            if reg then break end
        end
        if reg then
            local ud = _acs_try_field(reg, "_WeaponEquipParamCatalogUserData")
                or _acs_try_call(reg, "get_WeaponEquipParamCatalogUserData")
                or _acs_try_field(reg, "_PlayerWeaponParameterUserData")
                or _acs_try_call(reg, "get_PlayerWeaponParameterUserData")
                or _acs_try_field(reg, "_WeaponCatalogUserData")
            if ud then
                local dt = _acs_try_field(ud, "_DataTable") or _acs_try_field(ud, "_WeaponEquipParams") or _acs_try_call(ud, "get_DataTable")
                if not dt then
                    local cd = _acs_try_field(ud, "_CatalogData")
                    if cd then dt = _acs_try_field(cd, "_DataTable") or _acs_try_field(cd, "_WeaponEquipParams") or _acs_try_call(cd, "get_DataTable") end
                end
                if dt then
                    local count = 0; pcall(function() count = dt:call("get_Count") end)
                    for i = 0, count - 1 do
                        pcall(function()
                            local wd = dt:call("get_Item", i)
                            if wd then
                                local wp = _acs_try_field(wd, "WeaponParameter") or _acs_try_field(wd, "_WeaponParameter")
                                if wp then
                                    local acsp = _acs_try_field(wp, "_AimCameraShakeParam") or _acs_try_field(wp, "AimCameraShakeParam")
                                    if acsp then
                                        pcall(function() acsp:set_field("_EnableAimCameraShake", prefs.enable_aim_camera_shake) end)
                                        if prefs.zero_min_fit_rate then
                                            pcall(function() acsp:set_field("_MinFitRate", 0.0) end)
                                        else
                                            pcall(function() acsp:set_field("_MinFitRate", 1.0) end)
                                        end
                                    end
                                end
                            end
                        end)
                    end
                end
            end
        end
    end
end

local _acs_applied = false

local function _acs_set_min_fit_rate(value)
    local scene = _acs_get_scene()
    if not scene then return end
    pcall(function()
        local obj = scene:call("findGameObject(System.String)", "WeaponCatalog")
        if not obj then return end
        local reg
        for _, t in ipairs(_acs_REGISTER_TYPES) do
            reg = obj:call("getComponent(System.Type)", t)
            if reg then break end
        end
        if not reg then return end
        local ud = _acs_try_field(reg, "_WeaponEquipParamCatalogUserData")
            or _acs_try_call(reg, "get_WeaponEquipParamCatalogUserData")
            or _acs_try_field(reg, "_PlayerWeaponParameterUserData")
            or _acs_try_call(reg, "get_PlayerWeaponParameterUserData")
            or _acs_try_field(reg, "_WeaponCatalogUserData")
        if not ud then return end
        local dt = _acs_try_field(ud, "_DataTable") or _acs_try_field(ud, "_WeaponEquipParams") or _acs_try_call(ud, "get_DataTable")
        if not dt then
            local cd = _acs_try_field(ud, "_CatalogData")
            if cd then dt = _acs_try_field(cd, "_DataTable") or _acs_try_field(cd, "_WeaponEquipParams") or _acs_try_call(cd, "get_DataTable") end
        end
        if not dt then return end
        local count = 0; pcall(function() count = dt:call("get_Count") end)
        for i = 0, count - 1 do
            pcall(function()
                local wd = dt:call("get_Item", i)
                if wd then
                    local wp = _acs_try_field(wd, "WeaponParameter") or _acs_try_field(wd, "_WeaponParameter")
                    if wp then
                        local acsp = _acs_try_field(wp, "_AimCameraShakeParam") or _acs_try_field(wp, "AimCameraShakeParam")
                        if acsp then
                            pcall(function() acsp:set_field("_MinFitRate", value) end)
                        end
                    end
                end
            end)
        end
    end)
end

re.on_pre_application_entry("LockScene", function()
    if _acs_applied then return end
    _acs_apply()
    _acs_applied = true
end)

sdk.hook(
    sdk.find_type_definition("via.SceneManager"):get_method("begin_change_sceneByString"),
    function() _acs_applied = false; return sdk.PreHookResult.CALL_ORIGINAL end,
    nil
)

-- UI state for the currently selected weapon's sliders
local ui_offset = { x = 0.0, y = 0.0, z = 0.0 }

local function populate_ui(key, cover_state)
    local o
    if cover_state then
        o = get_cover_offset(key, cover_state)
    else
        o = weapon_offsets[key]
    end
    if o then
        ui_offset.x = o.x or 0.0
        ui_offset.y = o.y or 0.0
        ui_offset.z = o.z or 0.0
    else
        ui_offset.x = 0.0
        ui_offset.y = 0.0
        ui_offset.z = 0.0
    end
end

local TRANSITION_IN = prefs.transition_in
local TRANSITION_OUT = prefs.transition_out
local TRANSITION_SWAP = prefs.transition_swap

local transition = {
    from_x = 0.0, from_y = 0.0, from_z = 0.0,
    to_x = 0.0, to_y = 0.0, to_z = 0.0,
    cur_x = 0.0, cur_y = 0.0, cur_z = 0.0,
    t = 1.0,
    duration = TRANSITION_IN,
    last_weapon_id = nil,
    last_time = os.clock(),
}

local function transition_set_target(tx, ty, tz, override_duration)
    if tx == transition.to_x and ty == transition.to_y and tz == transition.to_z then return end
    local was_zero = (transition.to_x == 0 and transition.to_y == 0 and transition.to_z == 0)
    local is_zero = (tx == 0 and ty == 0 and tz == 0)
    transition.from_x = transition.cur_x
    transition.from_y = transition.cur_y
    transition.from_z = transition.cur_z
    transition.to_x = tx
    transition.to_y = ty
    transition.to_z = tz
    transition.t = 0.0
    if override_duration then
        transition.duration = override_duration
    elseif is_zero then
        transition.duration = TRANSITION_OUT
    elseif was_zero then
        transition.duration = TRANSITION_IN
    else
        transition.duration = TRANSITION_SWAP
    end
end

local function smoothstep(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    return t * t * (3.0 - 2.0 * t)
end

local function transition_update()
    local now = os.clock()
    local dt = now - transition.last_time
    transition.last_time = now

    if transition.t >= 1.0 then
        transition.cur_x = transition.to_x
        transition.cur_y = transition.to_y
        transition.cur_z = transition.to_z
        return
    end

    if transition.duration <= 0 then
        transition.t = 1.0
    else
        transition.t = transition.t + dt / transition.duration
    end
    if transition.t > 1.0 then transition.t = 1.0 end
    local s = smoothstep(transition.t)

    transition.cur_x = transition.from_x + (transition.to_x - transition.from_x) * s
    transition.cur_y = transition.from_y + (transition.to_y - transition.from_y) * s
    transition.cur_z = transition.from_z + (transition.to_z - transition.from_z) * s
end

-- Reticle hiding
local hide_reticle = prefs.hide_reticle
local cached_view_mode = -1

local reticle_names = {
    "Gui_ui2020"
}
for i, v in ipairs(reticle_names) do
    reticle_names[v] = true
end

re.on_pre_gui_draw_element(function(element, context)
    if not hide_reticle then return true end
    if cached_view_mode ~= 1 then return true end
    local game_object = element:call("get_GameObject")
    if game_object == nil then return true end
    local name = game_object:call("get_Name")
    if reticle_names[name] ~= nil then
        return false
    end
    return true
end)

-- Bullet from muzzle
local bullet_from_muzzle = prefs.bullet_from_muzzle
local muzzle_joint = nil
local muzzle_cached_gun_go = nil
local muzzle_pos = nil
local muzzle_rot = nil
local muzzle_debug_joint_name = "none"
local muzzle_debug_all_joints = ""

local MUZZLE_JOINT_CANDIDATES = {
    "MuzzleAttach_Pos_00",
    "muzzle",
    "Muzzle",
    "MuzzleJoint",
    "vfx_muzzle1",
    "vfx_muzzle",
    "ef_muzzle",
    "Muzzle_Pos",
    "MuzzlePos",
    "gun_muzzle",
    "barrel_end",
}

local function muzzle_safe_call(obj, method, ...)
    if not obj then return nil end
    local ok, result = pcall(function(...) return obj:call(method, ...) end, ...)
    return ok and result or nil
end

local function find_muzzle_joint(gun_xf)
    for _, name in ipairs(MUZZLE_JOINT_CANDIDATES) do
        local j = muzzle_safe_call(gun_xf, "getJointByName", name)
        if j then
            muzzle_debug_joint_name = name
            return j
        end
    end

    -- Fallback: scan all joints for any containing "muzzle"
    local joint_count = muzzle_safe_call(gun_xf, "get_JointCount") or 0
    local names = {}
    for i = 0, joint_count - 1 do
        local j = muzzle_safe_call(gun_xf, "getJointByIndex", i)
        if j then
            local jname = muzzle_safe_call(j, "get_Name") or ""
            table.insert(names, jname)
            if jname:lower():find("muzzle") or jname:lower():find("barrel") then
                muzzle_debug_joint_name = jname .. " (scan)"
                return j
            end
        end
    end
    muzzle_debug_all_joints = table.concat(names, ", ")
    muzzle_debug_joint_name = "NOT FOUND"
    return nil
end

re.on_pre_application_entry("UpdateBehavior", function()
    if not bullet_from_muzzle and not prefs.muzzle_all_views then return end
    if not prefs.muzzle_all_views and cached_view_mode ~= 1 then return end

    local char_mgr = sdk.get_managed_singleton("app.CharacterManager")
    if not char_mgr then return end
    local ctx = muzzle_safe_call(char_mgr, "get_PlayerContextFast")
    local updater = ctx and muzzle_safe_call(ctx, "get_Updater")
    local arms = updater and muzzle_safe_call(updater, "get_EquipWeapon")
    if not arms then return end

    local td = arms:get_type_definition()
    if not td or not td:is_a("app.PlayerGun") then return end

    local gun_go = muzzle_safe_call(arms, "get_GameObject")
    if not gun_go then return end

    if gun_go ~= muzzle_cached_gun_go then
        muzzle_joint = nil
        muzzle_cached_gun_go = nil
        muzzle_pos = nil
        muzzle_rot = nil
        muzzle_debug_all_joints = ""

        local gun_xf = muzzle_safe_call(gun_go, "get_Transform")
        if gun_xf then
            muzzle_joint = find_muzzle_joint(gun_xf)
            if muzzle_joint then
                muzzle_cached_gun_go = gun_go
            end
        end
    end

    if muzzle_joint then
        muzzle_pos = muzzle_safe_call(muzzle_joint, "get_Position")
        muzzle_rot = muzzle_safe_call(muzzle_joint, "get_Rotation")
    end
end)

do
    local vec3_td = sdk.find_type_definition("via.vec3")
    local quat_td = sdk.find_type_definition("via.Quaternion")
    local pg_td = sdk.find_type_definition("app.PlayerGun")
    if pg_td then
        local m = pg_td:get_method("trySetupShellTransform")
        if m then
            sdk.hook(m,
                function(args)
                    if not bullet_from_muzzle and not prefs.muzzle_all_views then return end
                    if not prefs.muzzle_all_views and cached_view_mode ~= 1 then return end
                    if not muzzle_pos or not muzzle_rot then return end

                    local pos_ptr = sdk.to_ptr(sdk.to_int64(args[3]))
                    local rot_ptr = sdk.to_ptr(sdk.to_int64(args[4]))
                    if not pos_ptr or not rot_ptr then return end

                    sdk.set_native_field(pos_ptr, vec3_td, "x", muzzle_pos.x)
                    sdk.set_native_field(pos_ptr, vec3_td, "y", muzzle_pos.y)
                    sdk.set_native_field(pos_ptr, vec3_td, "z", muzzle_pos.z)

                    sdk.set_native_field(rot_ptr, quat_td, "w", muzzle_rot.w)
                    sdk.set_native_field(rot_ptr, quat_td, "x", muzzle_rot.x)
                    sdk.set_native_field(rot_ptr, quat_td, "y", muzzle_rot.y)
                    sdk.set_native_field(rot_ptr, quat_td, "z", muzzle_rot.z)

                    return sdk.PreHookResult.SKIP_ORIGINAL
                end,
                function(retval) return retval end
            )
        end
    end
end

local STANDARD_FPS_X = -0.09
local TRANSITION_SFPS = 0.2
local TRANSITION_ADS = 0.2
local standard_fps_mode = prefs.standard_fps_mode
local sfps_toggled_this_frame = false

local hk = require("Hotkeys/Hotkeys")
local IS_HK_PATH = "IronSights/hotkeys.json"
local is_hk_default_settings = {
    use_modifier = false,
    use_pad_modifier = true,
    hotkeys = {
        ["SFPS Modifier"] = "R Mouse",
        ["Standard FPS Toggle"] = "EX0",
        ["Pad SFPS Modifier"] = "LT (L2)",
        ["Pad Standard FPS Toggle"] = "",
        ["Hold Animation Toggle"] = "",
    }
}
local is_hk_settings = hk.recurse_def_settings(json.load_file(IS_HK_PATH) or {}, is_hk_default_settings)
hk.setup_hotkeys(is_hk_settings.hotkeys)

local sfps_toggle_was_down = false
local ha_toggle_was_down = false

re.on_application_entry("UpdateBehavior", function()
    local kb = (not is_hk_settings.use_modifier or hk.check_hotkey("SFPS Modifier", true)) and hk.check_hotkey("Standard FPS Toggle", true)
    local pad = (not is_hk_settings.use_pad_modifier or hk.check_hotkey("Pad SFPS Modifier", true)) and hk.check_hotkey("Pad Standard FPS Toggle", true)
    local is_down = kb or pad
    sfps_toggled_this_frame = false
    if is_down and not sfps_toggle_was_down then
        standard_fps_mode = not standard_fps_mode
        prefs.standard_fps_mode = standard_fps_mode
        save_prefs()
        sfps_toggled_this_frame = true
    end
    sfps_toggle_was_down = is_down or false
end)

local camera_offset_applied = false
local cached_weapon_id = nil
local cached_character = nil
local cached_is_holding = false
local cached_fps_state = nil
local cached_busy_ads = false

local function get_player_context()
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    if not cm then return nil end
    local ctx = nil
    pcall(function() ctx = cm:call("getPlayerContextRef") end)
    return ctx
end

local function get_equipped_weapon_id_from_ctx(ctx)
    if not ctx or not TYPE_PlayerEquipment then return nil end
    local go = nil
    pcall(function() go = ctx:call("get_GameObject") end)
    if not go then return nil end
    local pe = nil
    pcall(function() pe = go:call("getComponent(System.Type)", TYPE_PlayerEquipment) end)
    if not pe then return nil end
    local eid = nil
    pcall(function() eid = pe:get_field("<EquipWeaponID>k__BackingField") end)
    if not eid then return nil end
    local eid_str = nil
    pcall(function() eid_str = eid:call("ToString()") end)
    if not eid_str then
        pcall(function() eid_str = tostring(eid:get_field("value__")) end)
    end
    return eid_str
end

local SHARED_WEAPONS = { ["arm0400"] = true }

local function get_offset_key(weapon_id, character)
    if weapon_id and SHARED_WEAPONS[weapon_id] and character then
        return weapon_id .. "_" .. character
    end
    return weapon_id
end

local function quat_rotate_vec3(q, v)
    local qx, qy, qz, qw = q.x, q.y, q.z, q.w
    local ux, uy, uz = qx, qy, qz
    local dot_uv = ux * v.x + uy * v.y + uz * v.z
    local dot_uu = ux * ux + uy * uy + uz * uz
    local cx = uy * v.z - uz * v.y
    local cy = uz * v.x - ux * v.z
    local cz = ux * v.y - uy * v.x
    return {
        x = 2.0 * dot_uv * ux + (qw * qw - dot_uu) * v.x + 2.0 * qw * cx,
        y = 2.0 * dot_uv * uy + (qw * qw - dot_uu) * v.y + 2.0 * qw * cy,
        z = 2.0 * dot_uv * uz + (qw * qw - dot_uu) * v.z + 2.0 * qw * cz,
    }
end

re.on_pre_application_entry("LockScene", function()
    local ctx = get_player_context()
    if ctx then
        local view_mode = nil
        pcall(function() view_mode = ctx:get_field("<CurrentViewMode>k__BackingField") end)
        cached_view_mode = tonumber(view_mode) or -1

        local is_leon = nil
        pcall(function() is_leon = ctx:call("get_IsCp_A0Character") end)
        cached_character = is_leon and "leon" or "grace"

        local raw_id = get_equipped_weapon_id_from_ctx(ctx)
        cached_weapon_id = get_offset_key(raw_id, cached_character)

        cached_is_holding = false
        if TYPE_CameraPosSetting then
            local go = nil
            pcall(function() go = ctx:call("get_GameObject") end)
            if go then
                local cps = nil
                pcall(function() cps = go:call("getComponent(System.Type)", TYPE_CameraPosSetting) end)
                if cps then
                    local hold = nil
                    pcall(function() hold = cps:get_field("_IsHold") end)
                    cached_is_holding = hold == true

                    pcall(function()
                        local state_fps = cps:get_field("_StateFPS")
                        if state_fps then
                            local state_val = state_fps:get_field("<State>k__BackingField")
                            if state_val ~= nil then
                                local name = nil
                                pcall(function() name = state_val:call("ToString()") end)
                                if name then
                                    cached_fps_state = name
                                else
                                    pcall(function() cached_fps_state = state_val:get_field("value__") end)
                                end
                            else
                                cached_fps_state = nil
                            end
                        else
                            cached_fps_state = nil
                        end
                    end)

                    cached_busy_ads = false
                    pcall(function()
                        local blender = cps:get_field("_CameraBlender")
                        if blender then
                            local bct = blender:get_field("<BusyCameraType>k__BackingField")
                            if bct then
                                local bct_name = nil
                                pcall(function() bct_name = bct:call("ToString()") end)
                                cached_busy_ads = (bct_name == "ADS")
                            end
                        end
                    end)
                end
            end
        end
    else
        cached_view_mode = -1
        cached_weapon_id = nil
        cached_character = nil
        cached_is_holding = false
        cached_fps_state = nil
        cached_busy_ads = false
    end

    local cam = sdk.get_primary_camera()
    if not cam then
        camera_offset_applied = false
        return
    end

    local is_cover = COVER_STATE_TO_KEY[cached_fps_state] ~= nil
    local is_active = cached_view_mode == 1 and (cached_is_holding or is_cover)
    local o = nil
    if is_active and not cached_busy_ads and cached_weapon_id then
        if is_cover then
            o = get_cover_offset(cached_weapon_id, COVER_STATE_TO_KEY[cached_fps_state])
        end
        if not o then
            o = weapon_offsets[cached_weapon_id]
        end
    end
    local tx = o and o.x or 0
    local ty = o and o.y or 0
    local tz = o and o.z or 0

    if standard_fps_mode and is_active then
        tx = STANDARD_FPS_X
        ty = 0
        tz = 0
    end

    local override_dur = nil
    if sfps_toggled_this_frame then
        override_dur = TRANSITION_SFPS
    elseif cached_busy_ads and not standard_fps_mode then
        override_dur = TRANSITION_ADS
    end
    transition_set_target(tx, ty, tz, override_dur)
    transition_update()

    local ox = transition.cur_x
    local oy = transition.cur_y
    local oz = transition.cur_z

    local eps = 0.00001
    if math.abs(ox) < eps and math.abs(oy) < eps and math.abs(oz) < eps then
        camera_offset_applied = false
        return
    end

    if cached_view_mode ~= 1 then
        camera_offset_applied = false
        return
    end

    local go = nil
    pcall(function() go = cam:call("get_GameObject") end)
    if not go then return end
    local xform = nil
    pcall(function() xform = go:call("get_Transform") end)
    if not xform then return end

    local pos = nil
    pcall(function() pos = xform:call("get_Position") end)
    if not pos then return end

    local rot = nil
    pcall(function() rot = xform:call("get_Rotation") end)
    if not rot then return end

    local world_offset = quat_rotate_vec3(rot, { x = ox, y = oy, z = oz })

    pcall(function()
        xform:call("set_Position", Vector4f.new(
            pos.x + world_offset.x,
            pos.y + world_offset.y,
            pos.z + world_offset.z,
            1.0
        ))
    end)
    camera_offset_applied = true
end)

local _ha_hold_start = nil

local function get_player_motion_is()
    local char_mgr = sdk.get_managed_singleton("app.CharacterManager")
    if not char_mgr then return nil end
    local ctx = nil
    pcall(function() ctx = char_mgr:call("get_PlayerContextFast") end)
    if not ctx then return nil end
    local go = nil
    pcall(function() go = ctx:call("get_GameObject") end)
    if not go then return nil end
    local motion = nil
    pcall(function() motion = go:call("getComponent(System.Type)", sdk.typeof("via.motion.Motion")) end)
    return motion
end

local function get_all_motion_layers_is()
    local motion = get_player_motion_is()
    if not motion then return {} end
    local layers = {}
    pcall(function()
        local lc = motion:call("getLayerCount")
        for i = 0, lc - 1 do
            pcall(function()
                local tl = motion:call("getLayer", i)
                if tl and tl:call("get_Running") and not tl:call("get_TreeEmpty") then
                    local name = ""
                    pcall(function()
                        local mn = tl:call("get_HighestWeightMotionNode")
                        if mn then name = mn:call("get_MotionName") or "" end
                    end)
                    layers[#layers + 1] = { idx = i, layer = tl, name = name }
                end
            end)
        end
    end)
    return layers
end

local _ha_hotkey_activated = false

re.on_application_entry("UpdateBehavior", function()
    local ha_down = hk.check_hotkey("Hold Animation Toggle", true)
    local wkey = cached_weapon_id

    if prefs.ha_hold_to_activate then
        if ha_down and wkey then
            if not _ha_hotkey_activated then
                if not hold_anim_edits[wkey] then hold_anim_edits[wkey] = {} end
                hold_anim_edits[wkey].enabled = true
                _ha_blend_weight = 0.0
                _ha_active_start = nil
                refresh_any_hold_anim()
                save_hold_anim()
                _ha_hotkey_activated = true
            end
        elseif _ha_hotkey_activated and wkey then
            if hold_anim_edits[wkey] then
                hold_anim_edits[wkey].enabled = false
                local all_ml = get_all_motion_layers_is()
                for _, info in ipairs(all_ml) do
                    pcall(function()
                        info.layer:call("set_BlendRate", 1.0)
                        info.layer:call("set_Speed", 1.0)
                    end)
                end
                refresh_any_hold_anim()
                save_hold_anim()
            end
            if _ha_breath_mfr_zeroed then
                _acs_set_min_fit_rate(1.0)
                _ha_breath_mfr_zeroed = false
            end
            _ha_hotkey_activated = false
        end
    else
        if ha_down and not ha_toggle_was_down and wkey then
            if not hold_anim_edits[wkey] then hold_anim_edits[wkey] = {} end
            local new_state = not (hold_anim_edits[wkey].enabled or false)
            hold_anim_edits[wkey].enabled = new_state
            _ha_blend_weight = 0.0
            _ha_active_start = nil
            if not new_state then
                local all_ml = get_all_motion_layers_is()
                for _, info in ipairs(all_ml) do
                    pcall(function()
                        info.layer:call("set_BlendRate", 1.0)
                        info.layer:call("set_Speed", 1.0)
                    end)
                end
                if _ha_breath_mfr_zeroed then
                    _acs_set_min_fit_rate(1.0)
                    _ha_breath_mfr_zeroed = false
                end
            end
            refresh_any_hold_anim()
            save_hold_anim()
        end
    end
    ha_toggle_was_down = ha_down or false
end)

re.on_application_entry("UpdateBehavior", function()
    if cached_is_holding then
        if not _ha_hold_start then _ha_hold_start = os.clock() end
    else
        _ha_hold_start = nil
    end

    if not _any_hold_anim_enabled then return end
    if not cached_weapon_id then return end

    local now = os.clock()
    local dt = now - _ha_last_time
    _ha_last_time = now
    if dt > 0.1 then dt = 0.016 end
    if dt <= 0 then return end

    local enabled, _, _, _, delay, ramp = get_hold_anim_for_key(cached_weapon_id)

    if not enabled then
        if _ha_blend_weight > 0 then
            _ha_blend_weight = math.max(0, _ha_blend_weight - dt * ramp)
            if _ha_blend_weight < 0.001 then _ha_blend_weight = 0 end
        end
        _ha_active_start = nil
        if _ha_breath_mfr_zeroed then
            _acs_set_min_fit_rate(1.0)
            _ha_breath_mfr_zeroed = false
        end
        return
    end

    local want_active = cached_is_holding
    if want_active and delay > 0 and _ha_hold_start then
        if (now - _ha_hold_start) < delay then
            want_active = false
        end
    end

    local breath_dur = prefs.ha_breath_duration
    if want_active and breath_dur > 0 then
        if not _ha_active_start then
            _ha_active_start = now
        end
        if (now - _ha_active_start) >= breath_dur then
            want_active = false
        end
    end

    if not want_active or not cached_is_holding then
        if not cached_is_holding then
            _ha_active_start = nil
        end
    end

    if want_active then
        _ha_blend_weight = math.min(1.0, _ha_blend_weight + dt * ramp)
    else
        _ha_blend_weight = math.max(0.0, _ha_blend_weight - dt * ramp)
        if _ha_blend_weight < 0.001 then _ha_blend_weight = 0 end
    end

    local should_zero_mfr = want_active and _ha_blend_weight > 0
    if should_zero_mfr and not _ha_breath_mfr_zeroed then
        _acs_set_min_fit_rate(0.0)
        _ha_breath_mfr_zeroed = true
    elseif not should_zero_mfr and _ha_breath_mfr_zeroed then
        _acs_set_min_fit_rate(1.0)
        _ha_breath_mfr_zeroed = false
    end
end)

re.on_application_entry("LateUpdateBehavior", function()
    if not _any_hold_anim_enabled then return end
    if not cached_weapon_id then return end

    local enabled, force, speed, sel_layers, delay, ramp = get_hold_anim_for_key(cached_weapon_id)
    if not enabled then
        if _ha_was_holding and _ha_blend_weight <= 0 then
            local all_layers = get_all_motion_layers_is()
            for _, info in ipairs(all_layers) do
                pcall(function()
                    info.layer:call("set_BlendRate", 1.0)
                    info.layer:call("set_Speed", 1.0)
                end)
            end
            _ha_was_holding = false
        end
        return
    end

    local sel_set = {}
    if sel_layers then
        for _, idx in ipairs(sel_layers) do sel_set[idx] = true end
    end

    local all_layers = get_all_motion_layers_is()
    for _, info in ipairs(all_layers) do
        if sel_set[info.idx] and not info.name:lower():find("hold") then
            sel_set[info.idx] = nil
        end
    end

    local has_selection = next(sel_set) ~= nil

    if not has_selection then return end

    if _ha_blend_weight > 0 then
        local t = _ha_blend_weight
        local blended_force = 1.0 + (force - 1.0) * t
        local blended_speed = 1.0 + (speed - 1.0) * t
        local all_layers = get_all_motion_layers_is()
        for _, info in ipairs(all_layers) do
            if sel_set[info.idx] then
                pcall(function()
                    info.layer:call("set_BlendRate", blended_force)
                    info.layer:call("set_Speed", blended_speed)
                end)
            end
        end
        _ha_was_holding = true
    elseif _ha_was_holding then
        local all_layers = get_all_motion_layers_is()
        for _, info in ipairs(all_layers) do
            if sel_set[info.idx] then
                pcall(function()
                    info.layer:call("set_BlendRate", 1.0)
                    info.layer:call("set_Speed", 1.0)
                end)
            end
        end
        _ha_was_holding = false
    end
end)

re.on_draw_ui(function()
    if imgui.tree_node("Iron Sights") then

        local sfps_changed
        sfps_changed, standard_fps_mode = imgui.checkbox("Standard FPS Mode", standard_fps_mode)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Press side mouse button or set hotkey at bottom of menu to toggle. Gamepad must be set. (does not overwrite per-weapon settings)")
        end
        if sfps_changed then
            prefs.standard_fps_mode = standard_fps_mode
            save_prefs()
        end
        imgui.separator()

        local equipped_id = cached_weapon_id
        if equipped_id then
            local eid_name = WEAPON_NAMES[equipped_id] or equipped_id
            local state_label = cached_fps_state and (" | " .. (COVER_STATE_LABELS[cached_fps_state] or cached_fps_state)) or ""
            imgui.text_colored("Equipped: " .. eid_name .. state_label, 0xFFFFFF00)

            if equipped_id ~= last_equipped_id then
                for i, key in ipairs(dropdown_items) do
                    if key == equipped_id then
                        selected_index = i
                        populate_ui(key, EDIT_MODE_COVER_STATE[edit_mode])
                        break
                    end
                end
                last_equipped_id = equipped_id
            end
        else
            imgui.text_colored("Equipped: (not detected)", 0xFFFFFF00)
        end

        local combo_changed
        combo_changed, selected_index = imgui.combo("Weapon", selected_index, dropdown_options)
        if selected_index < 1 then selected_index = 1 end
        if selected_index > #dropdown_items then selected_index = #dropdown_items end
        if combo_changed then
            populate_ui(dropdown_items[selected_index], EDIT_MODE_COVER_STATE[edit_mode])
        end

        local mode_changed
        mode_changed, edit_mode = imgui.combo("Edit Mode", edit_mode, EDIT_MODE_LABELS)
        if edit_mode < 1 then edit_mode = 1 end
        if edit_mode > #EDIT_MODE_LABELS then edit_mode = #EDIT_MODE_LABELS end
        if mode_changed then
            populate_ui(dropdown_items[selected_index], EDIT_MODE_COVER_STATE[edit_mode])
        end

        imgui.separator()

        local key = dropdown_items[selected_index]
        local cover_state = EDIT_MODE_COVER_STATE[edit_mode]
        if key then
            local any_changed = false
            local cc
            cc, ui_offset.x = imgui.drag_float("Left/Right", ui_offset.x, 0.001, -5.0, 5.0, "%.4f")
            if cc then any_changed = true end
            cc, ui_offset.y = imgui.drag_float("Up/Down", ui_offset.y, 0.001, -5.0, 5.0, "%.4f")
            if cc then any_changed = true end
            cc, ui_offset.z = imgui.drag_float("Back/Forward", ui_offset.z, 0.001, -5.0, 5.0, "%.4f")
            if cc then any_changed = true end

            if any_changed then
                if cover_state then
                    set_cover_offset(key, cover_state, ui_offset.x, ui_offset.y, ui_offset.z)
                else
                    weapon_offsets[key] = { x = ui_offset.x, y = ui_offset.y, z = ui_offset.z }
                    save_offsets()
                end
            end

            if not reset_confirm then
                if imgui.button("Reset##offset") then
                    reset_confirm = true
                end
            else
                imgui.text_colored("Reset this weapon?", 0xFF00FFFF)
                if imgui.button("Yes##reset") then
                    if cover_state then
                        local ck = key .. "|" .. cover_state
                        local def = DEFAULT_COVER_OFFSETS[ck]
                        if def then
                            ui_offset.x = def.x
                            ui_offset.y = def.y
                            ui_offset.z = def.z
                            cover_offsets[ck] = { x = def.x, y = def.y, z = def.z }
                        else
                            ui_offset.x = 0.0
                            ui_offset.y = 0.0
                            ui_offset.z = 0.0
                            cover_offsets[ck] = nil
                        end
                        save_cover_offsets()
                    else
                        local def = DEFAULT_OFFSETS[key]
                        if def then
                            ui_offset.x = def.x
                            ui_offset.y = def.y
                            ui_offset.z = def.z
                            weapon_offsets[key] = { x = def.x, y = def.y, z = def.z }
                        else
                            ui_offset.x = 0.0
                            ui_offset.y = 0.0
                            ui_offset.z = 0.0
                            weapon_offsets[key] = nil
                        end
                        save_offsets()
                    end
                    reset_confirm = false
                end
                imgui.same_line()
                if imgui.button("No##reset") then
                    reset_confirm = false
                end
            end
            imgui.same_line()
            if not copy_all_confirm then
                if imgui.button("Copy to All") then
                    copy_all_confirm = true
                end
            else
                imgui.text_colored("Apply to all weapons?", 0xFF00FFFF)
                if imgui.button("Yes") then
                    for _, wk in ipairs(WEAPON_KEYS) do
                        if cover_state then
                            set_cover_offset(wk, cover_state, ui_offset.x, ui_offset.y, ui_offset.z)
                        else
                            weapon_offsets[wk] = { x = ui_offset.x, y = ui_offset.y, z = ui_offset.z }
                        end
                    end
                    if not cover_state then save_offsets() end
                    copy_all_confirm = false
                end
                imgui.same_line()
                if imgui.button("No") then
                    copy_all_confirm = false
                end
            end
        end

        imgui.separator()
        local ret_changed
        ret_changed, hide_reticle = imgui.checkbox("Hide Reticle in First Person", hide_reticle)
        if ret_changed then
            prefs.hide_reticle = hide_reticle
            if not hide_reticle and bullet_from_muzzle then
                bullet_from_muzzle = false
                prefs.bullet_from_muzzle = false
            end
            save_prefs()
        end
        if hide_reticle then
            local muzzle_changed
            muzzle_changed, bullet_from_muzzle = imgui.checkbox("Spawn Bullet From Muzzle", bullet_from_muzzle)
            if muzzle_changed then
                prefs.bullet_from_muzzle = bullet_from_muzzle
                save_prefs()
            end
            if bullet_from_muzzle then
                -- imgui.text("  Joint: " .. muzzle_debug_joint_name)
                if muzzle_debug_joint_name == "NOT FOUND" and muzzle_debug_all_joints ~= "" then
                    imgui.text_colored("  All joints: " .. muzzle_debug_all_joints, 0xFF00FFFF)
                end
            end
        end

        -- local mav_changed
        -- mav_changed, prefs.muzzle_all_views = imgui.checkbox("Bullets Follow Muzzle (All Views)", prefs.muzzle_all_views)
        -- if imgui.is_item_hovered() then
        --     imgui.set_tooltip("Spawn bullets from the muzzle in both first-person and third-person")
        -- end
        -- if mav_changed then
        --     if not prefs.muzzle_all_views then
        --         muzzle_joint = nil
        --         muzzle_cached_gun_go = nil
        --         muzzle_pos = nil
        --         muzzle_rot = nil
        --     end
        --     save_prefs()
        -- end

        imgui.spacing()
        local acs_changed, acs_new = imgui.checkbox("Enable Aim Camera Shake", prefs.enable_aim_camera_shake)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Toggle the camera shake effect when aiming")
        end
        if acs_changed then
            prefs.enable_aim_camera_shake = acs_new
            save_prefs()
            _acs_applied = false
        end
        local mfr_changed, mfr_new = imgui.checkbox("Disable Min Fit Rate", prefs.zero_min_fit_rate)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Sets _MinFitRate to 0 for all weapons (default is 1). Removes the minimum aim camera shake intensity")
        end
        if mfr_changed then
            prefs.zero_min_fit_rate = mfr_new
            save_prefs()
            _acs_applied = false
        end

        imgui.spacing()
        imgui.text_colored("Hold Animation:", 0xFFFFFF00)
        local breath_changed, breath_new = imgui.drag_float("Breath Duration (s)", prefs.ha_breath_duration, 0.1, 0.0, 30.0, "%.1f")
        if imgui.is_item_hovered() then
            imgui.set_tooltip("How long the effect stays active after engaging. 0 = unlimited")
        end
        if breath_changed then
            prefs.ha_breath_duration = breath_new
            save_prefs()
        end
        do
            local wkey = cached_weapon_id or dropdown_items[selected_index]
            local all_ml = get_all_motion_layers_is()

            local wedit = wkey and hold_anim_edits[wkey] or {}
            local dbg_force = wedit.force or 1.0
            local dbg_speed = wedit.speed or 1.0
            local t = _ha_blend_weight
            imgui.text(string.format("  blend: %.3f | force: %.3f -> %.3f | speed: %.3f -> %.3f | holding: %s",
                t, dbg_force, 1.0 + (dbg_force - 1.0) * t, dbg_speed, 1.0 + (dbg_speed - 1.0) * t, tostring(cached_is_holding)))
            imgui.text(string.format("  mfr_zeroed: %s | breath_start: %s | breath_dur: %.1f",
                tostring(_ha_breath_mfr_zeroed),
                _ha_active_start and string.format("%.1f ago", os.clock() - _ha_active_start) or "nil",
                prefs.ha_breath_duration))
            if #all_ml > 0 then
                for _, info in ipairs(all_ml) do
                    local cur_br, cur_sp = 0, 0
                    pcall(function() cur_br = info.layer:call("get_BlendRate") end)
                    pcall(function() cur_sp = info.layer:call("get_Speed") end)
                    imgui.text(string.format("    L%d %s  BR=%.3f  Sp=%.3f", info.idx, info.name, cur_br, cur_sp))
                end
            end
            if #all_ml > 0 and wkey then
                local wedit = hold_anim_edits[wkey] or {}
                local ha_enabled = wedit.enabled or false
                local ha_force = wedit.force or 1.0
                local ha_speed = wedit.speed or 1.0
                local ha_layers = wedit.layers or {}

                local hlock_changed, hlock_new = imgui.checkbox("Enable##hold_anim", ha_enabled)
                if hlock_changed then
                    if not hold_anim_edits[wkey] then hold_anim_edits[wkey] = {} end
                    hold_anim_edits[wkey].enabled = hlock_new
                    _ha_blend_weight = 0.0
                    _ha_active_start = nil
                    if not hlock_new then
                        for _, info in ipairs(all_ml) do
                            pcall(function()
                                info.layer:call("set_BlendRate", 1.0)
                                info.layer:call("set_Speed", 1.0)
                            end)
                        end
                        hold_anim_edits[wkey].layers = {}
                    end
                    ha_enabled = hlock_new
                    refresh_any_hold_anim()
                    save_hold_anim()
                end

                if ha_enabled then
                    local delay_val = wedit.delay or 0
                    if type(delay_val) == "boolean" then delay_val = delay_val and 1.0 or 0 end
                    local delay_changed, delay_new = imgui.drag_float("Delay (s)##hold_anim_delay", delay_val, 0.05, 0.0, 5.0, "%.2f")
                    if imgui.is_item_hovered() then
                        imgui.set_tooltip("Seconds to wait after aiming before applying overrides. 0 = no delay")
                    end
                    if delay_changed then
                        if not hold_anim_edits[wkey] then hold_anim_edits[wkey] = {} end
                        hold_anim_edits[wkey].delay = delay_new
                        save_hold_anim()
                    end

                    local ramp_val = wedit.ramp or 4.0
                    local ramp_changed, ramp_new = imgui.drag_float("Ramp Speed##hold_anim_ramp", ramp_val, 0.1, 0.5, 30.0, "%.1f")
                    if imgui.is_item_hovered() then
                        imgui.set_tooltip("How fast the override blends in/out. Higher = faster. 4.0 = ~0.25s, 2.0 = ~0.5s, 10.0 = nearly instant")
                    end
                    if ramp_changed then
                        if not hold_anim_edits[wkey] then hold_anim_edits[wkey] = {} end
                        hold_anim_edits[wkey].ramp = ramp_new
                        save_hold_anim()
                    end

                    local sel_set = {}
                    for _, idx in ipairs(ha_layers) do sel_set[idx] = true end

                    imgui.text("Target Layers:")
                    local layer_changed = false
                    for _, info in ipairs(all_ml) do
                        local is_hold = info.name:lower():find("hold")
                        if is_hold then
                            local label = "L" .. info.idx .. " " .. (info.name ~= "" and info.name or "(unnamed)")
                            local was_on = sel_set[info.idx] or false
                            local chk_changed, chk_new = imgui.checkbox(label .. "##hold_layer_" .. info.idx, was_on)
                            if chk_changed then
                                sel_set[info.idx] = chk_new or nil
                                layer_changed = true
                            end
                        end
                    end
                    if layer_changed then
                        if not hold_anim_edits[wkey] then hold_anim_edits[wkey] = {} end
                        local new_list = {}
                        for _, info in ipairs(all_ml) do
                            if sel_set[info.idx] then new_list[#new_list + 1] = info.idx end
                        end
                        hold_anim_edits[wkey].layers = new_list
                        save_hold_anim()
                    end

                    local hbr_changed, hbr_new = imgui.drag_float("Hold Animation Force", ha_force, 0.01, 0.0, 1.0)
                    if hbr_changed then
                        if not hold_anim_edits[wkey] then hold_anim_edits[wkey] = {} end
                        hold_anim_edits[wkey].force = hbr_new
                        for _, info in ipairs(all_ml) do
                            if sel_set[info.idx] then
                                pcall(function() info.layer:call("set_BlendRate", hbr_new) end)
                            end
                        end
                        save_hold_anim()
                    end

                    local hspd_changed, hspd_new = imgui.drag_float("Hold Animation Speed", ha_speed, 0.1, 0.0, 100.0)
                    if hspd_changed then
                        if not hold_anim_edits[wkey] then hold_anim_edits[wkey] = {} end
                        hold_anim_edits[wkey].speed = hspd_new
                        for _, info in ipairs(all_ml) do
                            if sel_set[info.idx] then
                                pcall(function() info.layer:call("set_Speed", hspd_new) end)
                            end
                        end
                        save_hold_anim()
                    end
                end
            else
                imgui.text("(no layers found)")
            end
        end

        imgui.spacing()
        imgui.text_colored("Transitions:", 0xFFFFFF00)
        local tin_changed
        tin_changed, TRANSITION_IN = imgui.drag_float("Aim In (sec)", TRANSITION_IN, 0.01, 0.0, 5.0, "%.2f")
        if imgui.is_item_hovered() then
            imgui.set_tooltip("How fast the offset applies when you start aiming")
        end
        if tin_changed then prefs.transition_in = TRANSITION_IN; save_prefs() end

        local tout_changed
        tout_changed, TRANSITION_OUT = imgui.drag_float("Aim Out (sec)", TRANSITION_OUT, 0.01, 0.0, 5.0, "%.2f")
        if imgui.is_item_hovered() then
            imgui.set_tooltip("How fast the offset resets when you stop aiming")
        end
        if tout_changed then prefs.transition_out = TRANSITION_OUT; save_prefs() end

        local tswap_changed
        tswap_changed, TRANSITION_SWAP = imgui.drag_float("Weapon Swap (sec)", TRANSITION_SWAP, 0.01, 0.0, 5.0, "%.2f")
        if imgui.is_item_hovered() then
            imgui.set_tooltip("How fast the offset blends when switching weapons while aiming")
        end
        if tswap_changed then prefs.transition_swap = TRANSITION_SWAP; save_prefs() end

        if imgui.button("Reset To Default") then
            TRANSITION_IN = 0.15
            TRANSITION_OUT = 1.0
            TRANSITION_SWAP = 0.5
            prefs.transition_in = TRANSITION_IN
            prefs.transition_out = TRANSITION_OUT
            prefs.transition_swap = TRANSITION_SWAP
            save_prefs()
        end

        imgui.spacing()
        imgui.text_colored("Hotkeys:", 0xFFFFFF00)
        local hk_changed = false
        local wc = false

        imgui.text_colored(" Keyboard and Mouse:", 0xFFFFFFAA)
        local mc; mc, is_hk_settings.use_modifier = imgui.checkbox("Use Modifier##is_kb_mod", is_hk_settings.use_modifier); wc = wc or mc
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Require holding this button while pressing toggle")
        end
        imgui.same_line()
        hk_changed = hk.hotkey_setter("SFPS Modifier") or hk_changed
        hk_changed = hk.hotkey_setter("Standard FPS Toggle", is_hk_settings.use_modifier and "SFPS Modifier") or hk_changed
        hk_changed = hk.hotkey_setter("Hold Animation Toggle") or hk_changed
        local hta_c, hta_v = imgui.checkbox("Hold to Activate##ha_hta", prefs.ha_hold_to_activate)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("When checked, Hold Animation is only active while the hotkey is held down")
        end
        if hta_c then
            prefs.ha_hold_to_activate = hta_v
            save_prefs()
        end

        imgui.text_colored(" Gamepad:", 0xFFFFFFAA)
        local pc; pc, is_hk_settings.use_pad_modifier = imgui.checkbox("Use Modifier##is_pad_mod", is_hk_settings.use_pad_modifier); wc = wc or pc
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Require holding this button while pressing toggle")
        end
        imgui.same_line()
        hk_changed = hk.hotkey_setter("Pad SFPS Modifier") or hk_changed
        hk_changed = hk.hotkey_setter("Pad Standard FPS Toggle", is_hk_settings.use_pad_modifier and "Pad SFPS Modifier") or hk_changed

        if hk_changed or wc then
            hk.update_hotkey_table(is_hk_settings.hotkeys)
            json.dump_file(IS_HK_PATH, is_hk_settings)
        end

        if imgui.button("Reset Hotkeys to Defaults") then
            is_hk_settings = hk.recurse_def_settings({}, is_hk_default_settings)
            hk.reset_from_defaults_tbl(is_hk_default_settings.hotkeys)
            hk.update_hotkey_table(is_hk_settings.hotkeys)
            json.dump_file(IS_HK_PATH, is_hk_settings)
        end

        imgui.tree_pop()
    end
end)
