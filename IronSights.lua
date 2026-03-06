-- Iron Sights - Per-weapon camera position offset for RE9
-- Only applies when CurrentViewMode == FPS (1)

local SETTINGS_PATH = "IronSights/offsets.json"
local PREFS_PATH = "IronSights/prefs.json"

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
for _, key in ipairs(WEAPON_KEYS) do
    table.insert(dropdown_options, WEAPON_NAMES[key] or key)
    table.insert(dropdown_items, key)
end

local selected_index = 1
local last_equipped_id = nil

-- Per-weapon offsets: { ["arm0000"] = { x=0, y=0, z=0 }, ... }
local weapon_offsets = {}
local function load_offsets()
    local saved = json.load_file(SETTINGS_PATH)
    if saved and type(saved) == "table" then
        weapon_offsets = saved
    end
end
local function save_offsets()
    json.dump_file(SETTINGS_PATH, weapon_offsets)
end
load_offsets()

local prefs = { hide_reticle = false, bullet_from_muzzle = false, transition_duration = 0.25, aim_slowdown = false, aim_slowdown_speed = 0.5, enable_aim_camera_shake = true }
do
    local saved = json.load_file(PREFS_PATH)
    if saved and type(saved) == "table" then
        if saved.hide_reticle ~= nil then prefs.hide_reticle = saved.hide_reticle end
        if saved.bullet_from_muzzle ~= nil then prefs.bullet_from_muzzle = saved.bullet_from_muzzle end
        if saved.transition_duration ~= nil then prefs.transition_duration = saved.transition_duration end
        if saved.aim_slowdown ~= nil then prefs.aim_slowdown = saved.aim_slowdown end
        if saved.aim_slowdown_speed ~= nil then prefs.aim_slowdown_speed = saved.aim_slowdown_speed end
        if saved.enable_aim_camera_shake ~= nil then prefs.enable_aim_camera_shake = saved.enable_aim_camera_shake end
    end
end
local function save_prefs()
    json.dump_file(PREFS_PATH, prefs)
end

local enable_aim_camera_shake = prefs.enable_aim_camera_shake

local function try_field(obj, name)
    local r; pcall(function() r = obj:get_field(name) end); return r
end

local function set_field_safe(obj, name, value)
    if obj == nil or name == nil or value == nil then return false end
    return pcall(function() obj:set_field(name, value) end)
end

local function try_call(obj, method, ...)
    local ok, r = pcall(function(...) return obj:call(method, ...) end, ...)
    if ok then return r end
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
    local obj = scene:call("findGameObject(System.String)", "WeaponCatalog")
    if obj then
        seen[obj:get_address()] = true
        results[#results + 1] = obj
    end
    local reg_type = sdk.typeof("app.WeaponCatalogRegister")
    if reg_type then
        local all_components
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

local function apply_camera_shake_global(enabled)
    local scene = get_scene()
    if not scene then return end
    local catalogs = find_all_catalogs(scene)
    for _, cat in ipairs(catalogs) do
        local reg = get_register(cat)
        local dt = get_data_table(reg)
        if dt then
            local count = 0; pcall(function() count = dt:call("get_Count") end)
            for i = 0, count - 1 do
                local wd; pcall(function() wd = dt:call("get_Item", i) end)
                if wd then
                    local wp = try_field(wd, "WeaponParameter") or try_field(wd, "_WeaponParameter")
                    if wp then
                        local acsp = try_field(wp, "_AimCameraShakeParam") or try_field(wp, "AimCameraShakeParam")
                        if acsp then
                            set_field_safe(acsp, "_EnableAimCameraShake", enabled)
                        end
                    end
                end
            end
        end
    end
end

local TYPE_PlayerEquipment = sdk.typeof("app.PlayerEquipment")
local TYPE_Motion = sdk.typeof("via.motion.Motion")
-- UI state for the currently selected weapon's sliders
local ui_offset = { x = 0.0, y = 0.0, z = 0.0 }

local function populate_ui(key)
    local o = weapon_offsets[key]
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

local transition = {
    from_x = 0.0, from_y = 0.0, from_z = 0.0,
    to_x = 0.0, to_y = 0.0, to_z = 0.0,
    cur_x = 0.0, cur_y = 0.0, cur_z = 0.0,
    t = 1.0,
    duration = prefs.transition_duration,
    last_weapon_id = nil,
    last_time = os.clock(),
}

local function transition_set_target(tx, ty, tz)
    if tx == transition.to_x and ty == transition.to_y and tz == transition.to_z then return end
    transition.from_x = transition.cur_x
    transition.from_y = transition.cur_y
    transition.from_z = transition.cur_z
    transition.to_x = tx
    transition.to_y = ty
    transition.to_z = tz
    transition.t = 0.0
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

-- Reticle hiding (FPS only)
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
    if not bullet_from_muzzle then return end
    if cached_view_mode ~= 1 then return end

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
                    if not bullet_from_muzzle then return end
                    if cached_view_mode ~= 1 then return end
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

local function get_player_context()
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    if not cm then return nil end
    local ctx = nil
    pcall(function() ctx = cm:call("getPlayerContextRef") end)
    return ctx
end

local function get_player_equipment()
    local ctx = get_player_context()
    if not ctx then return nil end
    local go = nil
    pcall(function() go = ctx:call("get_GameObject") end)
    if not go then return nil end
    if not TYPE_PlayerEquipment then return nil end
    local pe = nil
    pcall(function() pe = go:call("getComponent(System.Type)", TYPE_PlayerEquipment) end)
    return pe
end

local function get_equipped_weapon_id()
    local pe = get_player_equipment()
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

-- Aim animation slowdown
local hk = require("Hotkeys/Hotkeys")
local aim_slowdown = prefs.aim_slowdown
local aim_slowdown_speed = prefs.aim_slowdown_speed
local aim_slowdown_active = false
local aim_shoot_start_time = nil
local AIM_SLOWDOWN_DELAY = 0.5
local aim_debug = {
    stage = "idle",
    is_hold = "?",
    singleton_found = "?",
    motion_found = "?",
    current_speed = "?",
}
local aim_debug_fields_cache = nil

local function get_player_motion(player_go)
    if not TYPE_Motion then return nil end
    local go = player_go
    if not go then
        local cm = sdk.get_managed_singleton("app.CharacterManager")
        if not cm then return nil end
        local ctx = nil
        pcall(function() ctx = cm:call("getPlayerContextRef") end)
        if not ctx then return nil end
        pcall(function() go = ctx:call("get_GameObject") end)
    end
    if not go then return nil end
    local motion = nil
    pcall(function() motion = go:call("getComponent(System.Type)", TYPE_Motion) end)
    return motion
end

re.on_application_entry("UpdateHID", function()
    if not aim_slowdown then
        if aim_slowdown_active then
            local motion = get_player_motion()
            if motion then
                pcall(function() motion:call("set_PlaySpeed", 1.0) end)
            end
            aim_slowdown_active = false
        end
        return
    end
    if cached_view_mode ~= 1 then
        if aim_slowdown_active then
            local motion = get_player_motion()
            if motion then
                pcall(function() motion:call("set_PlaySpeed", 1.0) end)
            end
            aim_slowdown_active = false
        end
        return
    end

    local ctx = get_player_context()
    if not ctx then
        aim_debug.stage = "no ctx"
        aim_debug.singleton_found = "nil"
        return
    end

    aim_debug.singleton_found = tostring(ctx:get_type_definition():get_full_name())

    local is_shoot = nil
    local is_shooting = nil
    local found_on = "?"
    local aim_sub = nil

    local sub_fields = { "<Common>k__BackingField", "<Cp_A0Unit>k__BackingField", "<Cp_A1Unit>k__BackingField" }
    for _, sf in ipairs(sub_fields) do
        if is_shoot ~= nil then break end
        local sub = nil
        pcall(function() sub = ctx:get_field(sf) end)
        if sub then
            pcall(function() is_shoot = sub:call("get_IsShootEnable") end)
            if is_shoot ~= nil then aim_sub = sub; found_on = sf; break end

            pcall(function() is_shoot = sub:get_field("_IsShootEnable") end)
            if is_shoot ~= nil then aim_sub = sub; found_on = sf; break end

            pcall(function() is_shoot = sub:get_field("<IsShootEnable>k__BackingField") end)
            if is_shoot ~= nil then aim_sub = sub; found_on = sf; break end
        end
    end

    if aim_sub then
        pcall(function() is_shooting = aim_sub:call("get_IsShooting") end)
        if is_shooting == nil then
            pcall(function() is_shooting = aim_sub:get_field("_IsShooting") end)
        end
        if is_shooting == nil then
            pcall(function() is_shooting = aim_sub:get_field("<IsShooting>k__BackingField") end)
        end
    end

    aim_debug.is_hold = tostring(is_shoot) .. " / shooting:" .. tostring(is_shooting) .. " (" .. found_on .. ")"

    if is_shoot == nil then
        aim_debug.stage = "field nil"
        return
    end

    local player_go = nil
    pcall(function() player_go = ctx:call("get_GameObject") end)

    local motion = get_player_motion(player_go)
    if not motion then
        aim_debug.stage = "no motion"
        aim_debug.motion_found = "nil"
        return
    end
    aim_debug.motion_found = "yes"

    local cur_speed = nil
    pcall(function() cur_speed = motion:call("get_PlaySpeed") end)
    aim_debug.current_speed = tostring(cur_speed)

    local now = os.clock()
    if is_shoot then
        if not aim_shoot_start_time then
            aim_shoot_start_time = now
        end
        local elapsed = now - aim_shoot_start_time

        if is_shooting then
            if aim_slowdown_active then
                pcall(function() motion:call("set_PlaySpeed", 1.0) end)
                aim_slowdown_active = false
            end
            aim_debug.stage = "shooting"
        elseif elapsed >= AIM_SLOWDOWN_DELAY then
            pcall(function() motion:call("set_PlaySpeed", aim_slowdown_speed) end)
            aim_slowdown_active = true
            aim_debug.stage = "slowed (" .. tostring(aim_slowdown_speed) .. ")"
        else
            if aim_slowdown_active then
                pcall(function() motion:call("set_PlaySpeed", 1.0) end)
                aim_slowdown_active = false
            end
            aim_debug.stage = string.format("aim wait %.2f/%.2f", elapsed, AIM_SLOWDOWN_DELAY)
        end
    else
        aim_shoot_start_time = nil
        if aim_slowdown_active then
            pcall(function() motion:call("set_PlaySpeed", 1.0) end)
            aim_slowdown_active = false
            aim_debug.stage = "restored 1.0"
        else
            aim_debug.stage = "idle"
        end
    end
end)

local camera_offset_applied = false
local camera_debug = {
    stage = "idle",
    ctx_type = "?",
    view_mode_raw = "?",
    cam_type = "?",
    pos_str = "?",
    weapon_id = "?",
}

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

local acs_last_apply_time = 0
local acs_applied_value = nil

local cached_weapon_id = nil

re.on_pre_application_entry("LockScene", function()
    local now = os.clock()
    if enable_aim_camera_shake ~= acs_applied_value or now - acs_last_apply_time > 30 then
        apply_camera_shake_global(enable_aim_camera_shake)
        acs_applied_value = enable_aim_camera_shake
        acs_last_apply_time = now
    end

    camera_debug.stage = "start"

    local ctx = get_player_context()
    if ctx then
        local view_mode = nil
        pcall(function() view_mode = ctx:get_field("<CurrentViewMode>k__BackingField") end)
        cached_view_mode = tonumber(view_mode) or -1
        camera_debug.view_mode_raw = tostring(view_mode)
        camera_debug.ctx_type = tostring(ctx:get_type_definition():get_full_name())
    else
        cached_view_mode = -1
        camera_debug.ctx_type = "nil"
    end

    local weapon_id = nil
    if ctx then
        local go = nil
        pcall(function() go = ctx:call("get_GameObject") end)
        if go and TYPE_PlayerEquipment then
            local pe = nil
            pcall(function() pe = go:call("getComponent(System.Type)", TYPE_PlayerEquipment) end)
            if pe then
                local eid = nil
                pcall(function() eid = pe:get_field("<EquipWeaponID>k__BackingField") end)
                if eid then
                    pcall(function() weapon_id = eid:call("ToString()") end)
                    if not weapon_id then
                        pcall(function() weapon_id = tostring(eid:get_field("value__")) end)
                    end
                end
            end
        end
    end
    cached_weapon_id = weapon_id
    camera_debug.weapon_id = weapon_id or "none"

    local cam = sdk.get_primary_camera()
    if not cam then
        camera_offset_applied = false
        camera_debug.stage = "no camera"
        camera_debug.cam_type = "nil"
        return
    end
    camera_debug.cam_type = tostring(cam:get_type_definition():get_full_name())

    local o = weapon_id and weapon_offsets[weapon_id] or nil
    local tx = o and o.x or 0
    local ty = o and o.y or 0
    local tz = o and o.z or 0

    transition_set_target(tx, ty, tz)
    transition_update()

    local ox = transition.cur_x
    local oy = transition.cur_y
    local oz = transition.cur_z

    local eps = 0.00001
    if math.abs(ox) < eps and math.abs(oy) < eps and math.abs(oz) < eps then
        camera_offset_applied = false
        camera_debug.stage = "offset zero"
        return
    end

    if cached_view_mode ~= 1 then
        camera_offset_applied = false
        camera_debug.stage = "view_mode ~= 1 (" .. tostring(cached_view_mode) .. ")"
        return
    end

    local go = nil
    pcall(function() go = cam:call("get_GameObject") end)
    if not go then
        camera_debug.stage = "no cam GO"
        return
    end
    local xform = nil
    pcall(function() xform = go:call("get_Transform") end)
    if not xform then
        camera_debug.stage = "no cam xform"
        return
    end

    local pos = nil
    pcall(function() pos = xform:call("get_Position") end)
    if not pos then
        camera_debug.stage = "no pos"
        return
    end
    camera_debug.pos_str = string.format("%.3f, %.3f, %.3f", pos.x, pos.y, pos.z)

    local rot = nil
    pcall(function() rot = xform:call("get_Rotation") end)
    if not rot then
        camera_debug.stage = "no rot"
        return
    end

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
    camera_debug.stage = "applied"
end)

re.on_draw_ui(function()
    if imgui.tree_node("Ironsights") then

        local equipped_id = cached_weapon_id
        if equipped_id then
            local eid_name = WEAPON_NAMES[equipped_id] or equipped_id
            imgui.text_colored("Equipped: " .. eid_name, 0xFFFFFF00)

            if equipped_id ~= last_equipped_id then
                for i, key in ipairs(dropdown_items) do
                    if key == equipped_id then
                        selected_index = i
                        populate_ui(key)
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
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Select a weapon to configure its camera offset. Auto-selects when you equip a weapon in-game.")
        end
        if selected_index < 1 then selected_index = 1 end
        if selected_index > #dropdown_items then selected_index = #dropdown_items end
        if combo_changed then
            populate_ui(dropdown_items[selected_index])
        end

        imgui.separator()

        local key = dropdown_items[selected_index]
        if key then
            local any_changed = false
            local cc
            cc, ui_offset.x = imgui.drag_float("Left/Right", ui_offset.x, 0.001, -5.0, 5.0, "%.4f")
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Horizontal camera offset relative to the camera view. Positive = right, negative = left.")
            end
            if cc then any_changed = true end
            cc, ui_offset.y = imgui.drag_float("Up/Down", ui_offset.y, 0.001, -5.0, 5.0, "%.4f")
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Vertical camera offset. Positive = up, negative = down.")
            end
            if cc then any_changed = true end
            cc, ui_offset.z = imgui.drag_float("Back/Forward", ui_offset.z, 0.001, -5.0, 5.0, "%.4f")
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Depth camera offset. Positive = forward (zoom in), negative = backward (zoom out).")
            end
            if cc then any_changed = true end

            if any_changed then
                weapon_offsets[key] = { x = ui_offset.x, y = ui_offset.y, z = ui_offset.z }
                save_offsets()
            end

            if imgui.button("Reset##offset") then
                ui_offset.x = 0.0
                ui_offset.y = 0.0
                ui_offset.z = 0.0
                weapon_offsets[key] = nil
                save_offsets()
            end
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Reset the camera offset for this weapon to zero.")
            end
            imgui.same_line()
            if imgui.button("Copy to All") then
                for _, wk in ipairs(WEAPON_KEYS) do
                    weapon_offsets[wk] = { x = ui_offset.x, y = ui_offset.y, z = ui_offset.z }
                end
                save_offsets()
            end
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Apply this weapon's camera offset to all weapons.")
            end
        end

        imgui.separator()
        local ret_changed
        ret_changed, hide_reticle = imgui.checkbox("Hide Reticle in First Person", hide_reticle)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Hides the aiming reticle/crosshair when in first-person (FPS) view mode.")
        end
        if ret_changed then
            prefs.hide_reticle = hide_reticle
            if not hide_reticle then
                bullet_from_muzzle = false
                prefs.bullet_from_muzzle = false
            end
            save_prefs()
        end
        if hide_reticle then
            local muzzle_changed
            muzzle_changed, bullet_from_muzzle = imgui.checkbox("Spawn Bullet From Muzzle", bullet_from_muzzle)
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Bullets originate from the weapon's muzzle instead of the camera center. Only active in first-person mode.")
            end
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

        local dur_changed
        dur_changed, transition.duration = imgui.drag_float("Transition (sec)", transition.duration, 0.01, 0.0, 2.0, "%.2f")
        if imgui.is_item_hovered() then
            imgui.set_tooltip("How long the camera takes to smoothly transition between weapon offsets when switching weapons. Set to 0 for instant.")
        end
        if transition.duration < 0 then transition.duration = 0 end
        if dur_changed then
            prefs.transition_duration = transition.duration
            save_prefs()
        end

        imgui.separator()
        local slow_changed
        slow_changed, aim_slowdown = imgui.checkbox("Aim Animation Slowdown", aim_slowdown)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Slows down the player's holding/aiming animation while L2 or Right Mouse is held in first-person mode.")
        end
        if slow_changed then
            prefs.aim_slowdown = aim_slowdown
            save_prefs()
        end
        if aim_slowdown then
            local spd_changed
            spd_changed, aim_slowdown_speed = imgui.drag_float("Aim Speed", aim_slowdown_speed, 0.01, 0.0, 1.0, "%.2f")
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Animation playback speed while aiming. 1.0 = normal, 0.5 = half speed, 0.0 = frozen.")
            end
            if aim_slowdown_speed < 0 then aim_slowdown_speed = 0 end
            if spd_changed then
                prefs.aim_slowdown_speed = aim_slowdown_speed
                save_prefs()
            end
            if imgui.tree_node("Debug##aim_debug") then
                imgui.text("Stage: " .. aim_debug.stage)
                imgui.text("Singleton: " .. aim_debug.singleton_found)
                imgui.text("_IsShootEnable: " .. aim_debug.is_hold)
                imgui.text("Motion: " .. aim_debug.motion_found)
                imgui.text("Speed: " .. aim_debug.current_speed)
                imgui.text("Active: " .. tostring(aim_slowdown_active))
                imgui.tree_pop()
            end
        end

        imgui.separator()
        local acs_changed
        acs_changed, enable_aim_camera_shake = imgui.checkbox("Enable Aim Camera Shake (Global)", enable_aim_camera_shake)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Enables or disables the camera shake effect when aiming for all weapons. Unchecking removes aim camera shake globally.")
        end
        if acs_changed then
            prefs.enable_aim_camera_shake = enable_aim_camera_shake
            apply_camera_shake_global(enable_aim_camera_shake)
            acs_applied_value = enable_aim_camera_shake
            acs_last_apply_time = os.clock()
            save_prefs()
        end

--[[
        if imgui.tree_node("Debug##cam_debug") then
            imgui.text("Stage: " .. camera_debug.stage)
            imgui.text("Weapon: " .. camera_debug.weapon_id)
            imgui.text("Cam type: " .. camera_debug.cam_type)
            imgui.text("Ctx type: " .. camera_debug.ctx_type)
            imgui.text("ViewMode raw: " .. camera_debug.view_mode_raw)
            imgui.text("Cam pos: " .. camera_debug.pos_str)
            imgui.text("Applied: " .. tostring(camera_offset_applied))
            imgui.tree_pop()
        end
--]]
        imgui.tree_pop()
    end
end)
