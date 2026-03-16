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

local prefs = { hide_reticle = true, bullet_from_muzzle = true, muzzle_all_views = false, transition_in = 0.15, transition_out = 1.0, transition_swap = 0.5, standard_fps_mode = false, steady_aim = false, steady_aim_amount = 0.3, steady_aim_alpha = 0.08, steady_aim_auto = false, steady_aim_delay = false, steady_aim_pause_shoot = false, steady_aim_pause_move = false, ha_hold_to_activate = false }
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
        if saved.steady_aim ~= nil then prefs.steady_aim = saved.steady_aim end
        if saved.steady_aim_amount ~= nil then prefs.steady_aim_amount = saved.steady_aim_amount end
        if saved.steady_aim_alpha ~= nil then prefs.steady_aim_alpha = saved.steady_aim_alpha end
        if saved.steady_aim_auto ~= nil then prefs.steady_aim_auto = saved.steady_aim_auto end
        if saved.steady_aim_delay ~= nil then prefs.steady_aim_delay = saved.steady_aim_delay end
        if saved.steady_aim_pause_shoot ~= nil then prefs.steady_aim_pause_shoot = saved.steady_aim_pause_shoot end
        if saved.steady_aim_pause_move ~= nil then prefs.steady_aim_pause_move = saved.steady_aim_pause_move end
        if saved.ha_hold_to_activate ~= nil then prefs.ha_hold_to_activate = saved.ha_hold_to_activate end
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

local function get_hold_anim_for_key(key)
    local edit = key and hold_anim_edits[key]
    if edit and edit.enabled then
        return true, edit.force or 1.0, edit.speed or 1.0, edit.layers, edit.delay or 0, edit.ramp or 4.0
    end
    return false, 1.0, 1.0, nil, 0, 4.0
end

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
        ["Steady Aim Toggle"] = "",
        ["Hold Animation Toggle"] = "",
    }
}
local is_hk_settings = hk.recurse_def_settings(json.load_file(IS_HK_PATH) or {}, is_hk_default_settings)
hk.setup_hotkeys(is_hk_settings.hotkeys)

local sfps_toggle_was_down = false
local sa_toggle_was_down = false
local ha_toggle_was_down = false
local steady_aim_enabled = prefs.steady_aim
local steady_aim_amount = prefs.steady_aim_amount
local steady_aim_auto = prefs.steady_aim_auto
local steady_aim_delay = prefs.steady_aim_delay
local steady_aim_pause_shoot = prefs.steady_aim_pause_shoot
local steady_aim_pause_move = prefs.steady_aim_pause_move

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

    local sa_down = hk.check_hotkey("Steady Aim Toggle", true)
    if sa_down and not sa_toggle_was_down then
        steady_aim_enabled = not steady_aim_enabled
        prefs.steady_aim = steady_aim_enabled
        save_prefs()
        if not steady_aim_enabled and sa_clear then sa_clear() end
    end
    sa_toggle_was_down = sa_down or false
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

local _sa_smoothed = {}
local _sa_alpha = prefs.steady_aim_alpha

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
            _ha_hotkey_activated = false
        end
    else
        if ha_down and not ha_toggle_was_down and wkey then
            if not hold_anim_edits[wkey] then hold_anim_edits[wkey] = {} end
            local new_state = not (hold_anim_edits[wkey].enabled or false)
            hold_anim_edits[wkey].enabled = new_state
            _ha_blend_weight = 0.0
            if not new_state then
                local all_ml = get_all_motion_layers_is()
                for _, info in ipairs(all_ml) do
                    pcall(function()
                        info.layer:call("set_BlendRate", 1.0)
                        info.layer:call("set_Speed", 1.0)
                    end)
                end
            end
            refresh_any_hold_anim()
            save_hold_anim()
        end
    end
    ha_toggle_was_down = ha_down or false
end)

local _sa_body_transform = nil
local _sa_joint_list = nil
local _sa_was_holding = false

local __sa_temp_quat = nil
pcall(function()
    __sa_temp_quat = ValueType.new(sdk.find_type_definition("via.Quaternion"))
end)

local function sa_get_body_transform()
    local char_mgr = sdk.get_managed_singleton("app.CharacterManager")
    if not char_mgr then return nil end
    local ctx = nil
    pcall(function() ctx = char_mgr:call("get_PlayerContextFast") end)
    if not ctx then return nil end
    local go = nil
    pcall(function() go = ctx:call("get_GameObject") end)
    if not go then return nil end
    local tf = nil
    pcall(function() tf = go:call("get_Transform") end)
    return tf
end

local SA_ARM_PATTERNS = {
    "Arm", "arm", "Elbow", "elbow",
    "Wrist", "wrist", "Hand", "hand", "Finger", "finger",
    "Thumb", "thumb",
}

local function sa_is_arm_joint(name)
    if not name or name == "" then return false end
    for _, pat in ipairs(SA_ARM_PATTERNS) do
        if name:find(pat) then return true end
    end
    return false
end

local function sa_build_joint_list(tf)
    local joints = {}
    local ok, jarray = pcall(function() return tf:call("get_Joints") end)
    if not ok or not jarray then return joints end
    local count = 0
    pcall(function() count = jarray:call("get_Count") end)
    if count == 0 then
        pcall(function() count = jarray:get_size() end)
    end
    for i = 0, count - 1 do
        pcall(function()
            local j = jarray[i]
            if j then
                local jname = ""
                pcall(function() jname = j:call("get_Name") or "" end)
                if sa_is_arm_joint(jname) then
                    joints[#joints + 1] = { joint = j, name = jname }
                end
            end
        end)
    end
    return joints
end

local function sa_ensure_joints()
    if not _sa_body_transform then
        _sa_body_transform = sa_get_body_transform()
        if not _sa_body_transform then return false end
        _sa_joint_list = sa_build_joint_list(_sa_body_transform)
    end
    return _sa_joint_list and #_sa_joint_list > 0
end

local function sa_clear()
    _sa_body_transform = nil
    _sa_joint_list = nil
    _sa_smoothed = {}
    _sa_was_holding = false
end

local function quat_nlerp_t(cur, ref, t)
    local cx, cy, cz, cw = cur.x, cur.y, cur.z, cur.w
    local rx, ry, rz, rw = ref.x, ref.y, ref.z, ref.w
    if cx*rx + cy*ry + cz*rz + cw*rw < 0 then
        rx, ry, rz, rw = -rx, -ry, -rz, -rw
    end
    local nx = cx + (rx - cx) * t
    local ny = cy + (ry - cy) * t
    local nz = cz + (rz - cz) * t
    local nw = cw + (rw - cw) * t
    local len = math.sqrt(nx*nx + ny*ny + nz*nz + nw*nw)
    if len > 0.0001 then
        nx, ny, nz, nw = nx/len, ny/len, nz/len, nw/len
    end
    return nx, ny, nz, nw
end

local _sa_prev_cam_rot = nil
local _sa_auto_active = false
local _sa_AUTO_THRESHOLD = 0.00000001
local _sa_hold_start = nil
local _sa_last_shot_time = 0
local _sa_blend_weight = 0.0
local _sa_BLEND_SPEED = 8.0
local _sa_prev_pos = nil
local _sa_player_moving = false
local _sa_MOVE_THRESHOLD = 0.0001

do
    local equip_td = sdk.find_type_definition("app.PlayerEquipment")
    if equip_td then
        local exec_fire = equip_td:get_method("execFire")
        if exec_fire then
            sdk.hook(exec_fire, function() _sa_last_shot_time = os.clock() end, nil)
        end
    end
end

re.on_application_entry("LateUpdateBehavior", function()
    if cached_view_mode == 1 and cached_is_holding then
        if not _sa_hold_start then _sa_hold_start = os.clock() end
    else
        _sa_hold_start = nil
    end

    local want_active = steady_aim_enabled
    if steady_aim_auto and not steady_aim_enabled then
        if cached_view_mode == 1 and cached_is_holding then
            pcall(function()
                local cam = sdk.get_primary_camera()
                if cam then
                    local cam_go = cam:call("get_GameObject")
                    if cam_go then
                        local cam_xf = cam_go:call("get_Transform")
                        if cam_xf then
                            local rot = cam_xf:call("get_Rotation")
                            if rot and _sa_prev_cam_rot then
                                local dx = rot.x - _sa_prev_cam_rot.x
                                local dy = rot.y - _sa_prev_cam_rot.y
                                local dz = rot.z - _sa_prev_cam_rot.z
                                local dw = rot.w - _sa_prev_cam_rot.w
                                local delta = dx*dx + dy*dy + dz*dz + dw*dw
                                _sa_auto_active = delta <= _sa_AUTO_THRESHOLD
                            else
                                _sa_auto_active = false
                            end
                            if rot then
                                _sa_prev_cam_rot = { x = rot.x, y = rot.y, z = rot.z, w = rot.w }
                            end
                        end
                    end
                end
            end)
            want_active = _sa_auto_active
        else
            _sa_auto_active = false
            _sa_prev_cam_rot = nil
        end
    elseif not steady_aim_auto then
        _sa_prev_cam_rot = nil
        _sa_auto_active = false
    end

    if steady_aim_delay and want_active then
        if not _sa_hold_start or (os.clock() - _sa_hold_start) < 1.0 then
            want_active = false
        end
    end

    if steady_aim_pause_shoot and want_active then
        if (os.clock() - _sa_last_shot_time) < 0.1 then
            want_active = false
        end
    end

    if steady_aim_pause_move then
        pcall(function()
            local tf = sa_get_body_transform()
            if tf then
                local pos = tf:call("get_Position")
                if pos and _sa_prev_pos then
                    local dx = pos.x - _sa_prev_pos.x
                    local dy = pos.y - _sa_prev_pos.y
                    local dz = pos.z - _sa_prev_pos.z
                    _sa_player_moving = (dx*dx + dy*dy + dz*dz) > _sa_MOVE_THRESHOLD
                else
                    _sa_player_moving = false
                end
                if pos then
                    _sa_prev_pos = { x = pos.x, y = pos.y, z = pos.z }
                end
            end
        end)
        if _sa_player_moving and want_active then
            want_active = false
        end
    else
        _sa_prev_pos = nil
        _sa_player_moving = false
    end

    if cached_view_mode ~= 1 or not cached_is_holding then
        want_active = false
    end

    if steady_aim_amount >= 1.0 then
        want_active = false
    end

    local dt = 1.0 / 60.0
    if want_active then
        _sa_blend_weight = math.min(1.0, _sa_blend_weight + dt * _sa_BLEND_SPEED)
    else
        _sa_blend_weight = math.max(0.0, _sa_blend_weight - dt * _sa_BLEND_SPEED)
    end

    if _sa_blend_weight <= 0.001 then
        if _sa_was_holding then sa_clear() end
        return
    end

    pcall(function()
        if not sa_ensure_joints() then return end

        local t = (1.0 - steady_aim_amount) * _sa_blend_weight

        for i, entry in ipairs(_sa_joint_list) do
            pcall(function()
                local cur = entry.joint:call("get_LocalRotation")
                if cur and __sa_temp_quat then
                    local key = entry.name or tostring(i)
                    local s = _sa_smoothed[key]
                    if not s then
                        _sa_smoothed[key] = { x = cur.x, y = cur.y, z = cur.z, w = cur.w }
                        return
                    end

                    local sx, sy, sz, sw = quat_nlerp_t(s, cur, _sa_alpha)
                    _sa_smoothed[key] = { x = sx, y = sy, z = sz, w = sw }

                    local fx, fy, fz, fw = quat_nlerp_t(cur, _sa_smoothed[key], t)
                    __sa_temp_quat.x = fx
                    __sa_temp_quat.y = fy
                    __sa_temp_quat.z = fz
                    __sa_temp_quat.w = fw
                    entry.joint:call("set_LocalRotation", __sa_temp_quat)
                end
            end)
        end
    end)

    _sa_was_holding = true
end)

re.on_application_entry("UpdateBehavior", function()
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
        return
    end

    local want_active = cached_is_holding
    if want_active and delay > 0 and _sa_hold_start then
        if (now - _sa_hold_start) < delay then
            want_active = false
        end
    end

    if want_active then
        _ha_blend_weight = math.min(1.0, _ha_blend_weight + dt * ramp)
    else
        _ha_blend_weight = math.max(0.0, _ha_blend_weight - dt * ramp)
        if _ha_blend_weight < 0.001 then _ha_blend_weight = 0 end
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

local _steady_aim_dump = nil

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
        imgui.text_colored("Steady Aim:", 0xFFFFFF00)
        local sa_changed
        sa_changed, steady_aim_enabled = imgui.checkbox("Enable Steady Aim", steady_aim_enabled)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Reduces the idle sway/breathing animation while aiming")
        end
        if sa_changed then
            prefs.steady_aim = steady_aim_enabled
            save_prefs()
        end
        local auto_changed
        auto_changed, steady_aim_auto = imgui.checkbox("Auto Steady (when not moving)", steady_aim_auto)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Automatically engages steady aim when aiming and not moving the camera")
        end
        if auto_changed then
            prefs.steady_aim_auto = steady_aim_auto
            save_prefs()
        end
        local delay_changed
        delay_changed, steady_aim_delay = imgui.checkbox("Delay 1s (wait for hold)", steady_aim_delay)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Steady aim only activates after aiming for 1 second")
        end
        if delay_changed then
            prefs.steady_aim_delay = steady_aim_delay
            save_prefs()
        end
        local pause_changed
        pause_changed, steady_aim_pause_shoot = imgui.checkbox("Pause while shooting", steady_aim_pause_shoot)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Disables steady aim briefly when firing (0.1s grace period)")
        end
        if pause_changed then
            prefs.steady_aim_pause_shoot = steady_aim_pause_shoot
            save_prefs()
        end
        local move_changed
        move_changed, steady_aim_pause_move = imgui.checkbox("Pause while moving", steady_aim_pause_move)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Disables steady aim while the player is walking/running")
        end
        if move_changed then
            prefs.steady_aim_pause_move = steady_aim_pause_move
            save_prefs()
        end
        if steady_aim_enabled or steady_aim_auto then
            local saa_changed
            saa_changed, steady_aim_amount = imgui.slider_float("Sway Amount", steady_aim_amount, 0.0, 1.0, "%.2f")
            if imgui.is_item_hovered() then
                imgui.set_tooltip("0.0 = no sway, 1.0 = normal sway")
            end
            if saa_changed then
                prefs.steady_aim_amount = steady_aim_amount
                save_prefs()
            end

            local alpha_changed
            alpha_changed, _sa_alpha = imgui.slider_float("Tracking Speed", _sa_alpha, 0.01, 0.5, "%.3f")
            if imgui.is_item_hovered() then
                imgui.set_tooltip("How fast the filter follows aim movement. Lower = smoother, higher = more responsive")
            end
            if alpha_changed then
                prefs.steady_aim_alpha = _sa_alpha
                save_prefs()
            end

            if imgui.button("Dump Aim Layers") then
                local dump = { view_mode = cached_view_mode, is_holding = cached_is_holding, layers = {} }
                pcall(function()
                    local motion = get_player_motion_is()
                    if motion then
                        local lc = motion:call("getLayerCount")
                        dump.layer_count = lc
                        for li = 0, lc - 1 do
                            pcall(function()
                                local tl = motion:call("getLayer", li)
                                if tl then
                                    local info = { layer = li, running = tl:call("get_Running"), tree_empty = tl:call("get_TreeEmpty") }
                                    if info.running and not info.tree_empty then
                                        info.blend_mode = tl:call("get_BlendMode")
                                        info.blend_rate = tl:call("get_BlendRate")
                                        info.motion_id = tl:call("get_MotionID")
                                        info.motion_bank_id = tl:call("get_MotionBankID")
                                        info.speed = tl:call("get_Speed")
                                        info.joint_count = tl:call("get_JointCount")
                                        info.animated_joint_count = tl:call("get_AnimatedJointCount")
                                        pcall(function()
                                            local mn = tl:call("get_HighestWeightMotionNode")
                                            if mn then info.motion_name = mn:call("get_MotionName") or "" end
                                        end)
                                        pcall(function()
                                            local jd = tl:call("get_JointsData")
                                            if jd then
                                                info.joints_data_type = tostring(jd:get_type_definition():get_full_name())
                                                local len = jd:call("get_Length")
                                                info.joints_data_length = len
                                                local sample = {}
                                                local sample_count = math.min(len, 40)
                                                for si = 0, sample_count - 1 do
                                                    sample[#sample + 1] = jd:call("Get", si)
                                                end
                                                info.joints_data_sample = sample
                                            end
                                        end)
                                        pcall(function()
                                            local vc = tl:call("get_ValueCount")
                                            info.value_count = vc
                                        end)
                                    end
                                    dump.layers[#dump.layers + 1] = info
                                end
                            end)
                        end
                    end
                end)
                _steady_aim_dump = dump
                json.dump_file("IronSights/debug_aim_layers.json", dump)
            end
            if _steady_aim_dump then
                for _, l in ipairs(_steady_aim_dump.layers) do
                    if l.running and not l.tree_empty then
                        local label = "L" .. l.layer .. " bm=" .. tostring(l.blend_mode) .. " br=" .. string.format("%.2f", l.blend_rate or 0) .. " mot=" .. tostring(l.motion_id) .. " " .. (l.motion_name or "")
                        imgui.text(label)
                    end
                end
            end
        end

        imgui.spacing()
        imgui.text_colored("Hold Animation:", 0xFFFFFF00)
        do
            local wkey = cached_weapon_id or dropdown_items[selected_index]
            local all_ml = get_all_motion_layers_is()

            local wedit = wkey and hold_anim_edits[wkey] or {}
            local dbg_force = wedit.force or 1.0
            local dbg_speed = wedit.speed or 1.0
            local t = _ha_blend_weight
            imgui.text(string.format("  blend: %.3f | force: %.3f -> %.3f | speed: %.3f -> %.3f | holding: %s",
                t, dbg_force, 1.0 + (dbg_force - 1.0) * t, dbg_speed, 1.0 + (dbg_speed - 1.0) * t, tostring(cached_is_holding)))
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
                        local label = "L" .. info.idx .. " " .. (info.name ~= "" and info.name or "(unnamed)")
                        local was_on = sel_set[info.idx] or false
                        local chk_changed, chk_new = imgui.checkbox(label .. "##hold_layer_" .. info.idx, was_on)
                        if chk_changed then
                            sel_set[info.idx] = chk_new or nil
                            layer_changed = true
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
        hk_changed = hk.hotkey_setter("Steady Aim Toggle") or hk_changed
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
