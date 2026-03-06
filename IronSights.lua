-- Iron Sights - Per-weapon camera position offset for RE9
-- Only applies when CurrentViewMode == FPS (1)

local SETTINGS_PATH = "RROF/ironsights.json"
local PREFS_PATH = "RROF/ironsights_prefs.json"

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

local prefs = { hide_reticle = true, bullet_from_muzzle = true, transition_in = 0.15, transition_out = 1.0, transition_swap = 0.5, standard_fps_mode = false }
do
    local saved = json.load_file(PREFS_PATH)
    if saved and type(saved) == "table" then
        if saved.hide_reticle ~= nil then prefs.hide_reticle = saved.hide_reticle end
        if saved.bullet_from_muzzle ~= nil then prefs.bullet_from_muzzle = saved.bullet_from_muzzle end
        if saved.transition_in ~= nil then prefs.transition_in = saved.transition_in end
        if saved.transition_out ~= nil then prefs.transition_out = saved.transition_out end
        if saved.transition_swap ~= nil then prefs.transition_swap = saved.transition_swap end
        if saved.standard_fps_mode ~= nil then prefs.standard_fps_mode = saved.standard_fps_mode end
    end
end
local function save_prefs()
    json.dump_file(PREFS_PATH, prefs)
end

local TYPE_PlayerEquipment = sdk.typeof("app.PlayerEquipment")
local TYPE_CameraPosSetting = sdk.typeof("app.PlayerCameraPositionSetting")

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

local STANDARD_FPS_X = -0.09
local TRANSITION_SFPS = 0.2
local standard_fps_mode = prefs.standard_fps_mode
local sfps_toggled_this_frame = false

local hk = require("Hotkeys/Hotkeys")
local IS_HK_PATH = "IronSights/hotkeys.json"
local is_hk_default_settings = {
    use_modifier = false,
    use_pad_modifier = true,
    hotkeys = {
        ["SFPS Modifier"] = "R Mouse",
        ["Standard FPS Toggle"] = "N",
        ["Pad SFPS Modifier"] = "LT (L2)",
        ["Pad Standard FPS Toggle"] = "",
    }
}
local is_hk_settings = hk.recurse_def_settings(json.load_file(IS_HK_PATH) or {}, is_hk_default_settings)
hk.setup_hotkeys(is_hk_settings.hotkeys)

local sfps_toggle_was_down = false

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
                end
            end
        end
    else
        cached_view_mode = -1
        cached_weapon_id = nil
        cached_character = nil
        cached_is_holding = false
    end

    local cam = sdk.get_primary_camera()
    if not cam then
        camera_offset_applied = false
        return
    end

    local is_active = cached_view_mode == 1 and cached_is_holding
    local o = (is_active and cached_weapon_id) and weapon_offsets[cached_weapon_id] or nil
    local tx = o and o.x or 0
    local ty = o and o.y or 0
    local tz = o and o.z or 0

    if standard_fps_mode and is_active then
        tx = tx + STANDARD_FPS_X
        ty = 0
        tz = 0
    end

    transition_set_target(tx, ty, tz, sfps_toggled_this_frame and TRANSITION_SFPS or nil)
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

re.on_draw_ui(function()
    if imgui.tree_node("Iron Sights") then

        local sfps_changed
        sfps_changed, standard_fps_mode = imgui.checkbox("Standard FPS Mode", standard_fps_mode)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Press N or set hotkey at bottom of menu to toggle. (does not overwrite per-weapon settings)")
        end
        if sfps_changed then
            prefs.standard_fps_mode = standard_fps_mode
            save_prefs()
        end
        imgui.separator()

        local equipped_id = cached_weapon_id
        if equipped_id then
            local char_label = cached_character and (" [" .. cached_character:sub(1,1):upper() .. cached_character:sub(2) .. "]") or ""
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
            if cc then any_changed = true end
            cc, ui_offset.y = imgui.drag_float("Up/Down", ui_offset.y, 0.001, -5.0, 5.0, "%.4f")
            if cc then any_changed = true end
            cc, ui_offset.z = imgui.drag_float("Back/Forward", ui_offset.z, 0.001, -5.0, 5.0, "%.4f")
            if cc then any_changed = true end

            if any_changed then
                weapon_offsets[key] = { x = ui_offset.x, y = ui_offset.y, z = ui_offset.z }
                save_offsets()
            end

            if not reset_confirm then
                if imgui.button("Reset##offset") then
                    reset_confirm = true
                end
            else
                imgui.text_colored("Reset this weapon?", 0xFF00FFFF)
                if imgui.button("Yes##reset") then
                    ui_offset.x = 0.0
                    ui_offset.y = 0.0
                    ui_offset.z = 0.0
                    weapon_offsets[key] = nil
                    save_offsets()
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
                        weapon_offsets[wk] = { x = ui_offset.x, y = ui_offset.y, z = ui_offset.z }
                    end
                    save_offsets()
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
