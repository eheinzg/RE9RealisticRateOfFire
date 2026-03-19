-- Iron Sights - Per-weapon camera position offset for RE9
-- Only applies when CurrentViewMode == FPS (1)

local SETTINGS_PATH = "IronSights/ironsights.json"
local COVER_SETTINGS_PATH = "IronSights/ironsights_cover.json"
local STANDARD_FPS_SETTINGS_PATH = "IronSights/ironsights_standard_fps.json"
local ARM_HAND_SETTINGS_PATH = "IronSights/arm_hand_rotation.json"
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
local EDIT_MODE_LABELS = { "Normal", "Cover Right", "Cover Left", "Standard FPS" }
local EDIT_MODE_COVER_STATE = { nil, "CoverActionRight", "CoverActionLeft", "StandardFPS" }

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
    ["arm0505"]       = { x =  0.001,    y = -0.0420, z = 0.0 },
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

-- Per-weapon offsets when Standard FPS Mode is ON (default: x=-0.09 like STANDARD_FPS_X)
local STANDARD_FPS_DEFAULT_X = -0.09
local default_standard_fps_offset = { x = STANDARD_FPS_DEFAULT_X, y = 0.0, z = 0.0 }
local default_standard_fps_offsets = {}
for _, k in ipairs(WEAPON_KEYS) do
    default_standard_fps_offsets[k] = { x = STANDARD_FPS_DEFAULT_X, y = 0.0, z = 0.0 }
end
local standard_fps_offsets = {}
local function save_standard_fps_offsets()
    json.dump_file(STANDARD_FPS_SETTINGS_PATH, standard_fps_offsets)
end
local function load_standard_fps_offsets()
    local saved = json.load_file(STANDARD_FPS_SETTINGS_PATH)
    if saved and type(saved) == "table" and next(saved) ~= nil then
        standard_fps_offsets = saved
    else
        for k, v in pairs(default_standard_fps_offsets) do
            standard_fps_offsets[k] = { x = v.x, y = v.y, z = v.z }
        end
        save_standard_fps_offsets()
    end
end
load_standard_fps_offsets()

local function get_standard_fps_offset(weapon_key)
    return standard_fps_offsets[weapon_key]
end
local function set_standard_fps_offset(weapon_key, x, y, z)
    standard_fps_offsets[weapon_key] = { x = x, y = y, z = z }
    save_standard_fps_offsets()
end

-- Arm hand rotation offset (Euler degrees X,Y,Z for right hand; left mirrors)
local arm_hand_rotation = { x = 0.0, y = 0.0, z = 0.0 }
local arm_lower_rotation = { x = 0.0, y = 0.0, z = 0.0 }
local function load_arm_hand_rotation()
    local saved = json.load_file(ARM_HAND_SETTINGS_PATH)
    if saved and type(saved) == "table" then
        -- Legacy: file may be { x, y, z } for arm_hand only
        if type(saved.x) == "number" then arm_hand_rotation.x = saved.x end
        if type(saved.y) == "number" then arm_hand_rotation.y = saved.y end
        if type(saved.z) == "number" then arm_hand_rotation.z = saved.z end
        if saved.arm_hand_rotation and type(saved.arm_hand_rotation) == "table" then
            if type(saved.arm_hand_rotation.x) == "number" then arm_hand_rotation.x = saved.arm_hand_rotation.x end
            if type(saved.arm_hand_rotation.y) == "number" then arm_hand_rotation.y = saved.arm_hand_rotation.y end
            if type(saved.arm_hand_rotation.z) == "number" then arm_hand_rotation.z = saved.arm_hand_rotation.z end
        end
        if saved.arm_lower_rotation and type(saved.arm_lower_rotation) == "table" then
            if type(saved.arm_lower_rotation.x) == "number" then arm_lower_rotation.x = saved.arm_lower_rotation.x end
            if type(saved.arm_lower_rotation.y) == "number" then arm_lower_rotation.y = saved.arm_lower_rotation.y end
            if type(saved.arm_lower_rotation.z) == "number" then arm_lower_rotation.z = saved.arm_lower_rotation.z end
        end
    end
end
local function save_arm_hand_rotation()
    _ah_off_cache_valid = false  -- invalidate offset quat cache when user changes sliders
    json.dump_file(ARM_HAND_SETTINGS_PATH, {
        arm_hand_rotation = arm_hand_rotation,
        arm_lower_rotation = arm_lower_rotation,
    })
end
load_arm_hand_rotation()

local function euler_deg_to_quat(ex_deg, ey_deg, ez_deg)
    local ex = math.rad(ex_deg)
    local ey = math.rad(ey_deg)
    local ez = math.rad(ez_deg)
    local cx, sx = math.cos(ex * 0.5), math.sin(ex * 0.5)
    local cy, sy = math.cos(ey * 0.5), math.sin(ey * 0.5)
    local cz, sz = math.cos(ez * 0.5), math.sin(ez * 0.5)
    return {
        w = cx * cy * cz + sx * sy * sz,
        x = sx * cy * cz - cx * sy * sz,
        y = cx * sy * cz + sx * cy * sz,
        z = cx * cy * sz - sx * sy * cz,
    }
end

local _qmul_result = { w = 1, x = 0, y = 0, z = 0 }
local function quat_mul(a, b)
    local aw, ax, ay, az = a.w, a.x, a.y, a.z
    local bw, bx, by, bz = b.w, b.x, b.y, b.z
    _qmul_result.w = aw * bw - ax * bx - ay * by - az * bz
    _qmul_result.x = aw * bx + ax * bw + ay * bz - az * by
    _qmul_result.y = aw * by - ax * bz + ay * bw + az * bx
    _qmul_result.z = aw * bz + ax * by - ay * bx + az * bw
    return _qmul_result
end

local function quat_normalize(q)
    local qw, qx, qy, qz = q.w, q.x, q.y, q.z
    local len = math.sqrt(qw * qw + qx * qx + qy * qy + qz * qz)
    if len < 1e-8 then q.w = 1; q.x = 0; q.y = 0; q.z = 0; return q end
    local inv = 1.0 / len
    q.w = qw * inv; q.x = qx * inv; q.y = qy * inv; q.z = qz * inv
    return q
end

local _slerp_result = { w = 1.0, x = 0.0, y = 0.0, z = 0.0 }
local function quat_slerp(a, b, t)
    if t < -0.25 then t = -0.25 elseif t > 1.25 then t = 1.25 end
    local aw, ax, ay, az = a.w, a.x, a.y, a.z
    local bw, bx, by, bz = b.w, b.x, b.y, b.z
    local dot = aw * bw + ax * bx + ay * by + az * bz
    if dot < 0 then dot = -dot; bx = -bx; by = -by; bz = -bz; bw = -bw end
    local rw, rx, ry, rz
    if dot > 0.9995 then
        local omt = 1.0 - t
        rw = aw * omt + bw * t
        rx = ax * omt + bx * t
        ry = ay * omt + by * t
        rz = az * omt + bz * t
    else
        if dot > 1 then dot = 1 elseif dot < -1 then dot = -1 end
        local th0 = math.acos(dot)
        local th = th0 * t
        local sin_th = math.sin(th)
        local sin_th0 = math.sin(th0)
        if sin_th0 > -1e-8 and sin_th0 < 1e-8 then sin_th0 = 1 end
        local s0 = math.cos(th) - dot * sin_th / sin_th0
        local s1 = sin_th / sin_th0
        rw = aw * s0 + bw * s1
        rx = ax * s0 + bx * s1
        ry = ay * s0 + by * s1
        rz = az * s0 + bz * s1
    end
    local len = math.sqrt(rw * rw + rx * rx + ry * ry + rz * rz)
    if len > 1e-8 then
        local inv = 1.0 / len
        rw = rw * inv; rx = rx * inv; ry = ry * inv; rz = rz * inv
    end
    _slerp_result.w = rw; _slerp_result.x = rx; _slerp_result.y = ry; _slerp_result.z = rz
    return _slerp_result
end

local function arm_hand_offset_quat_r()
    return euler_deg_to_quat(arm_hand_rotation.x, arm_hand_rotation.y, arm_hand_rotation.z)
end

local function arm_hand_offset_quat_l()
    return euler_deg_to_quat(-arm_hand_rotation.x, arm_hand_rotation.y, -arm_hand_rotation.z)
end

local function arm_lower_offset_quat_r()
    return euler_deg_to_quat(arm_lower_rotation.x, arm_lower_rotation.y, arm_lower_rotation.z)
end

local function arm_lower_offset_quat_l()
    return euler_deg_to_quat(-arm_lower_rotation.x, arm_lower_rotation.y, -arm_lower_rotation.z)
end

local prefs = { hide_reticle = true, bullet_from_muzzle = true, muzzle_all_views = false, transition_in = 0.15, transition_out = 1.0, transition_swap = 0.5, standard_fps_mode = false, ha_hold_to_activate = true, ha_breath_duration = 3.5, ha_apply_min_fit_rate = true, zero_min_fit_rate = false, perfect_focus = true, sfps_disable_ads_snipers = true, muzzle_disable_ads_snipers = true, auto_iron_sight = true, arm_rotation_enabled = true, arm_rot_transition_in = 0.15, arm_rot_transition_out = 0.2, arm_rot_spring_k = 1000.0, arm_rot_spring_d = 20.0, arm_rot_wobble = true }
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
        if saved.ha_apply_min_fit_rate ~= nil then prefs.ha_apply_min_fit_rate = saved.ha_apply_min_fit_rate end
        if saved.zero_min_fit_rate ~= nil then prefs.zero_min_fit_rate = saved.zero_min_fit_rate end
        if saved.perfect_focus ~= nil then prefs.perfect_focus = saved.perfect_focus end
        if saved.sfps_disable_ads_snipers ~= nil then prefs.sfps_disable_ads_snipers = saved.sfps_disable_ads_snipers end
        if saved.muzzle_disable_ads_snipers ~= nil then prefs.muzzle_disable_ads_snipers = saved.muzzle_disable_ads_snipers end
        if saved.auto_iron_sight ~= nil then prefs.auto_iron_sight = saved.auto_iron_sight end
        if saved.arm_rotation_enabled ~= nil then prefs.arm_rotation_enabled = saved.arm_rotation_enabled end
        if saved.arm_rot_transition_in ~= nil then prefs.arm_rot_transition_in = saved.arm_rot_transition_in end
        if saved.arm_rot_transition_out ~= nil then prefs.arm_rot_transition_out = saved.arm_rot_transition_out end
        if saved.arm_rot_spring_k ~= nil then prefs.arm_rot_spring_k = saved.arm_rot_spring_k end
        if saved.arm_rot_spring_d ~= nil then prefs.arm_rot_spring_d = saved.arm_rot_spring_d end
        if saved.arm_rot_wobble ~= nil then prefs.arm_rot_wobble = saved.arm_rot_wobble end
    end
end
local function save_prefs()
    json.dump_file(PREFS_PATH, prefs)
end

local TYPE_PlayerEquipment = sdk.typeof("app.PlayerEquipment")
local TYPE_CameraPosSetting = sdk.typeof("app.PlayerCameraPositionSetting")
local TYPE_Cp_A000InputDriver = sdk.typeof("app.Cp_A000InputDriver")  -- Leon
local TYPE_Cp_A100InputDriver = sdk.typeof("app.Cp_A100InputDriver")  -- Grace

local HOLD_ANIM_PATH = "IronSights/hold_anim.json"
local HOLD_ANIM_DEFAULTS = {
    arm0000 = { enabled = false, layers = {0,1}, ramp = 1.0, speed = 0.2 },
    arm0001 = { enabled = false, layers = {0,1}, ramp = 1.0, speed = 0.1 },
    arm0003 = { enabled = false, layers = {0,1}, ramp = 1.0, speed = 0.2 },
    arm0004 = { enabled = false, layers = {0,1}, ramp = 1.0, speed = 0.1 },
    arm0005 = { enabled = false, layers = {0,1}, ramp = 1.0, speed = 0.1 },
    arm0006 = { enabled = false, layers = {0,1}, ramp = 1.5, speed = 0.1 },
    arm0007 = { enabled = false, layers = {0,1}, ramp = 1.0, speed = 0.2 },
    arm0100 = { enabled = false, layers = {0,1}, ramp = 1.0, speed = 0.1 },
    arm0103 = { enabled = false, layers = {0,1}, ramp = 1.5, speed = 0.1 },
    arm0104 = { enabled = false, layers = {0,1}, ramp = 1.5, speed = 0.1 },
    arm0200 = { enabled = false },
    arm0400_grace = { enabled = false, layers = {0,1}, ramp = 1.0, speed = 0.1 },
    arm0400_leon = { enabled = false, layers = {0,1}, ramp = 1.5, speed = 0.1 },
    arm0500 = { enabled = false, layers = {0,1}, ramp = 1.0, speed = 0.1 },
    arm0501 = { enabled = false, layers = {0,1}, ramp = 2.0, speed = 0.2 },
    arm0503 = { enabled = false, layers = {0,1}, ramp = 1.5, speed = 0.15 },
    arm0505 = { enabled = false, layers = {0,1}, ramp = 1.5, speed = 0.15 },
    arm0600 = { enabled = false, layers = {0,1}, ramp = 1.5, speed = 0.0 },
    arm0601 = { enabled = false, layers = {0,1}, ramp = 2.5, speed = 0.0 },
}
local hold_anim_edits = {}
do
    for k, v in pairs(HOLD_ANIM_DEFAULTS) do
        hold_anim_edits[k] = {}
        for fk, fv in pairs(v) do hold_anim_edits[k][fk] = fv end
    end
    local saved = json.load_file(HOLD_ANIM_PATH)
    if saved and type(saved) == "table" then
        for k, v in pairs(saved) do
            if type(v) == "table" then
                if not hold_anim_edits[k] then hold_anim_edits[k] = {} end
                for fk, fv in pairs(v) do hold_anim_edits[k][fk] = fv end
            end
        end
    end
end
local function save_hold_anim() json.dump_file(HOLD_ANIM_PATH, hold_anim_edits) end

local _ha = {}
_ha.any_enabled = false
local function refresh_any_hold_anim()
    for _, edit in pairs(hold_anim_edits) do
        if edit.enabled then _ha.any_enabled = true; return end
    end
    _ha.any_enabled = false
end
refresh_any_hold_anim()

_ha.was_holding = false
_ha.blend_weight = 0.0
_ha.last_time = os.clock()
_ha.active_start = nil
_ha.breath_mfr_zeroed = false
_ha.breath_pf_applied = false

local function get_hold_anim_for_key(key)
    local edit = key and hold_anim_edits[key]
    if edit and edit.enabled then
        local force = math.max(0, math.min(edit.force or 1.0, 10.0))
        local speed = math.max(0, math.min(edit.speed or 0.1, 10.0))
        return true, force, speed, edit.layers, edit.delay or 0, edit.ramp or 1.5
    end
    return false, 1.0, 0.1, nil, 0, 1.5
end

local _acs = {}
_acs.TYPE_WCR = sdk.typeof("app.WeaponCatalogRegister")
_acs.REGISTER_TYPES = {}
do
    for _, tn in ipairs({ "app.WeaponCatalogRegister", "chainsaw.WeaponCatalogRegister" }) do
        local t = sdk.typeof(tn)
        if t then _acs.REGISTER_TYPES[#_acs.REGISTER_TYPES + 1] = t end
    end
end

function _acs.get_scene()
    local sm = sdk.get_native_singleton("via.SceneManager")
    local sm_type = sm and sdk.find_type_definition("via.SceneManager")
    return sm_type and sdk.call_native_func(sm, sm_type, "get_CurrentScene")
end

function _acs.try_field(obj, name)
    local ok, r = pcall(obj.get_field, obj, name)
    if ok then return r end
    return nil
end

function _acs.try_call(obj, method)
    local ok, r = pcall(obj.call, obj, method)
    if ok then return r end
    return nil
end

_acs.WEAPON_ID_FIELDS = { "_WeaponID", "WeaponID", "_WeaponId" }

function _acs.get_entry_id(wd)
    if not wd then return nil end
    for i = 1, #_acs.WEAPON_ID_FIELDS do
        local v = _acs.try_field(wd, _acs.WEAPON_ID_FIELDS[i])
        if v ~= nil then
            local s = tostring(v)
            s = string.lower(s)
            -- Trim leading/trailing whitespace inline
            local first = s:find("%S")
            if first then
                local last = s:find("%S%s*$")
                if last then s = s:sub(first, last) end
            end
            if s:match("^[%a_]+%d+$") then return s end
        end
    end
end

function _acs.write_valuetype(parent_obj, offset, value)
    for i = 0, value.type:get_valuetype_size() - 1 do
        parent_obj:write_byte(offset + i, value:read_byte(i))
    end
end

_acs.point_range_originals = {}

function _acs.apply_pr_param(param, sub_key, s_val, r_val, cache_key)
    if not param then return end
    local ok_pt, param_type = pcall(param.get_type_definition, param)
    if not ok_pt or not param_type then return end
    local pr_field = param_type:get_field("_PointRange")
    if not pr_field then return end
    local ok_pr, pr = pcall(param.get_field, param, "_PointRange")
    if not ok_pr or not pr then return end
    if cache_key and sub_key and not _acs.point_range_originals[sub_key] then
        _acs.point_range_originals[sub_key] = { s = pr.s, r = pr.r }
    end
    pr.s = s_val
    pr.r = r_val
    _acs.write_valuetype(param, pr_field:get_offset_from_base(), pr)
end

function _acs.apply_point_range(wd, s_val, r_val, cache_key)
    local wp = _acs.try_field(wd, "_WeaponParameter") or _acs.try_field(wd, "WeaponParameter")
    if not wp then return end
    local rft = _acs.try_field(wp, "_ReticleFitParamTable") or _acs.try_field(wp, "ReticleFitParamTable")
    if not rft then return end
    _acs.apply_pr_param(_acs.try_field(rft, "_DefaultParam"), cache_key and (cache_key .. "_def"), s_val, r_val, cache_key)
    local cp = _acs.try_field(rft, "_CustomParams")
    if cp then
        local ok_n, n = pcall(cp.call, cp, "get_Count")
        if not ok_n or not n then n = 0 end
        for i = 0, n - 1 do
            local ok_it, item = pcall(cp.call, cp, "get_Item", i)
            if ok_it and item then
                _acs.apply_pr_param(_acs.try_field(item, "_Param"), cache_key and (cache_key .. "_c" .. i), s_val, r_val, cache_key)
            end
        end
    end
end

function _acs.restore_pr_param(param, sub_key)
    if not param or not sub_key then return end
    local orig = _acs.point_range_originals[sub_key]
    if not orig then return end
    local ok_pt, param_type = pcall(param.get_type_definition, param)
    if not ok_pt or not param_type then return end
    local pr_field = param_type:get_field("_PointRange")
    if not pr_field then return end
    local ok_pr, pr = pcall(param.get_field, param, "_PointRange")
    if not ok_pr or not pr then return end
    pr.s = orig.s
    pr.r = orig.r
    _acs.write_valuetype(param, pr_field:get_offset_from_base(), pr)
end

function _acs.restore_point_range(wd, cache_key)
    local wp = _acs.try_field(wd, "_WeaponParameter") or _acs.try_field(wd, "WeaponParameter")
    if not wp then return end
    local rft = _acs.try_field(wp, "_ReticleFitParamTable") or _acs.try_field(wp, "ReticleFitParamTable")
    if not rft then return end
    _acs.restore_pr_param(_acs.try_field(rft, "_DefaultParam"), cache_key .. "_def")
    local cp = _acs.try_field(rft, "_CustomParams")
    if cp then
        local ok_n, n = pcall(cp.call, cp, "get_Count")
        if not ok_n or not n then n = 0 end
        for i = 0, n - 1 do
            local ok_it, item = pcall(cp.call, cp, "get_Item", i)
            if ok_it and item then
                _acs.restore_pr_param(_acs.try_field(item, "_Param"), cache_key .. "_c" .. i)
            end
        end
    end
end

function _acs.find_all_catalogs()
    local scene = _acs.get_scene()
    if not scene then return {} end
    local results = {}
    local seen = {}
    pcall(function()
        local obj = scene:call("findGameObject(System.String)", "WeaponCatalog")
        if obj then
            local addr = obj:get_address()
            if not seen[addr] then
                seen[addr] = true
                results[#results + 1] = obj
            end
        end
    end)
    if _acs.TYPE_WCR then
        pcall(function()
            local all = scene:call("findComponents(System.Type)", _acs.TYPE_WCR)
            if all then
                local n = 0; pcall(function() n = all:call("get_Count") end)
                for i = 0, n - 1 do
                    pcall(function()
                        local comp = all:call("get_Item", i)
                        if comp then
                            local go = comp:call("get_GameObject")
                            if go then
                                local addr = go:get_address()
                                if not seen[addr] then
                                    seen[addr] = true
                                    results[#results + 1] = go
                                end
                            end
                        end
                    end)
                end
            end
        end)
    end
    return results
end

function _acs.get_data_table(catalog)
    if not catalog then return nil end
    local reg
    for _, t in ipairs(_acs.REGISTER_TYPES) do
        reg = catalog:call("getComponent(System.Type)", t)
        if reg then break end
    end
    if not reg then return nil end
    local ud = _acs.try_field(reg, "_WeaponEquipParamCatalogUserData")
        or _acs.try_call(reg, "get_WeaponEquipParamCatalogUserData")
        or _acs.try_field(reg, "_PlayerWeaponParameterUserData")
        or _acs.try_call(reg, "get_PlayerWeaponParameterUserData")
        or _acs.try_field(reg, "_WeaponCatalogUserData")
    if not ud then return nil end
    local dt = _acs.try_field(ud, "_DataTable") or _acs.try_field(ud, "_WeaponEquipParams") or _acs.try_call(ud, "get_DataTable")
    if dt then return dt end
    local cd = _acs.try_field(ud, "_CatalogData")
    if cd then return _acs.try_field(cd, "_DataTable") or _acs.try_field(cd, "_WeaponEquipParams") or _acs.try_call(cd, "get_DataTable") end
    return nil
end

function _acs.apply()
    local catalogs = _acs.find_all_catalogs()
    for _, catalog in ipairs(catalogs) do
        local dt = _acs.get_data_table(catalog)
        if dt then
            local count = 0; pcall(function() count = dt:call("get_Count") end)
            for i = 0, count - 1 do
                pcall(function()
                    local wd = dt:call("get_Item", i)
                    if wd then
                        local wid = _acs.get_entry_id(wd)
                        local is_known = wid and WEAPON_NAMES[wid]
                        local wp = _acs.try_field(wd, "WeaponParameter") or _acs.try_field(wd, "_WeaponParameter")
                        if wp then
                            local acsp = _acs.try_field(wp, "_AimCameraShakeParam") or _acs.try_field(wp, "AimCameraShakeParam")
                            if acsp then
                                if is_known then
                                    if prefs.zero_min_fit_rate then
                                        pcall(function() acsp:set_field("_MinFitRate", 0.0) end)
                                    else
                                        pcall(function() acsp:set_field("_MinFitRate", 1.0) end)
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
    end
end

_acs.applied = false

-- Cached catalog + data_table pairs to avoid scene search on every breath transition
_acs.catalog_cache = nil
_acs.catalog_cache_time = 0
_acs.CATALOG_CACHE_TTL = 0.5

function _acs.get_cached_catalog_dts()
    local now = os.clock()
    if _acs.catalog_cache and (now - _acs.catalog_cache_time) < _acs.CATALOG_CACHE_TTL then
        return _acs.catalog_cache
    end
    local catalogs = _acs.find_all_catalogs()
    local pairs_list = {}
    for _, catalog in ipairs(catalogs) do
        local dt = _acs.get_data_table(catalog)
        if dt then
            pairs_list[#pairs_list + 1] = dt
        end
    end
    _acs.catalog_cache = pairs_list
    _acs.catalog_cache_time = now
    return pairs_list
end

function _acs.set_min_fit_rate(value)
    local dts = _acs.get_cached_catalog_dts()
    for _, dt in ipairs(dts) do
        local ok_c, count = pcall(dt.call, dt, "get_Count")
        if ok_c and count then
            for i = 0, count - 1 do
                local ok_i, wd = pcall(dt.call, dt, "get_Item", i)
                if ok_i and wd then
                    local wid = _acs.get_entry_id(wd)
                    if wid and WEAPON_NAMES[wid] then
                        local wp = _acs.try_field(wd, "WeaponParameter") or _acs.try_field(wd, "_WeaponParameter")
                        if wp then
                            local acsp = _acs.try_field(wp, "_AimCameraShakeParam") or _acs.try_field(wp, "AimCameraShakeParam")
                            if acsp then
                                pcall(acsp.set_field, acsp, "_MinFitRate", value)
                            end
                        end
                    end
                end
            end
        end
    end
end

function _acs.set_point_range_all(s_val, r_val)
    local dts = _acs.get_cached_catalog_dts()
    for _, dt in ipairs(dts) do
        local ok_c, count = pcall(dt.call, dt, "get_Count")
        if ok_c and count then
            for i = 0, count - 1 do
                local ok_i, wd = pcall(dt.call, dt, "get_Item", i)
                if ok_i and wd then
                    local wid = _acs.get_entry_id(wd)
                    if wid and WEAPON_NAMES[wid] then
                        _acs.apply_point_range(wd, s_val, r_val, wid)
                    end
                end
            end
        end
    end
end

function _acs.restore_point_range_all()
    local dts = _acs.get_cached_catalog_dts()
    for _, dt in ipairs(dts) do
        local ok_c, count = pcall(dt.call, dt, "get_Count")
        if ok_c and count then
            for i = 0, count - 1 do
                local ok_i, wd = pcall(dt.call, dt, "get_Item", i)
                if ok_i and wd then
                    local wid = _acs.get_entry_id(wd)
                    if wid and WEAPON_NAMES[wid] then
                        _acs.restore_point_range(wd, wid)
                    end
                end
            end
        end
    end
end

re.on_pre_application_entry("LockScene", function()
    if _acs.applied then return end
    _acs.apply()
    _acs.applied = true
end)

sdk.hook(
    sdk.find_type_definition("via.SceneManager"):get_method("begin_change_sceneByString"),
    function() _acs.applied = false; return sdk.PreHookResult.CALL_ORIGINAL end,
    nil
)

-- UI state for the currently selected weapon's sliders
local ui_offset = { x = 0.0, y = 0.0, z = 0.0 }

local function populate_ui(key, cover_state)
    local o
    if cover_state == "StandardFPS" then
        o = get_standard_fps_offset(key) or default_standard_fps_offsets[key] or default_standard_fps_offset
    elseif cover_state then
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
local ARM_ROT_TRANSITION_IN = prefs.arm_rot_transition_in
local ARM_ROT_TRANSITION_OUT = prefs.arm_rot_transition_out

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

-- Damped spring for arm rotation blend: overshoot, wobble a bit, then settle (tunable via sliders)
local ARM_ROT_SPRING_K = prefs.arm_rot_spring_k
local ARM_ROT_SPRING_D = prefs.arm_rot_spring_d
local ARM_ROT_BLEND_CLAMP_LO = -0.22
local ARM_ROT_BLEND_CLAMP_HI = 1.22
local ARM_ROT_SETTLE_THRESH = 0.002
local ARM_ROT_VEL_THRESH = 0.015

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
    local ok, result = pcall(obj.call, obj, method, ...)
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

-- Arm hand and arm lower joints: cache and resolve from player character
local arm_hand_cached_player_go = nil
local joint_r_arm_hand = nil
local joint_l_arm_hand = nil
local joint_r_arm_lower = nil
local joint_l_arm_lower = nil

local function find_transform_with_joint(xform, joint_name)
    if not xform then return nil end
    local j = muzzle_safe_call(xform, "getJointByName", joint_name)
    if j then return j end
    -- Fallback: search children (get_Child returns first child; follow chain)
    local child = muzzle_safe_call(xform, "get_Child")
    local depth = 0
    while child and depth < 16 do
        j = muzzle_safe_call(child, "getJointByName", joint_name)
        if j then return j end
        child = muzzle_safe_call(child, "get_Child")
        depth = depth + 1
    end
    return nil
end

local arm_hand_last_resolve_time = 0
local ARM_HAND_RESOLVE_INTERVAL = 0.2  -- only re-resolve when cache valid every 0.2s to cut SDK calls

local function resolve_arm_hand_joints()
    local now = os.clock()
    if arm_hand_cached_player_go and (now - arm_hand_last_resolve_time) < ARM_HAND_RESOLVE_INTERVAL then
        return  -- cache valid and not stale: skip SDK calls this frame
    end
    local char_mgr = sdk.get_managed_singleton("app.CharacterManager")
    if not char_mgr then return end
    local ctx = muzzle_safe_call(char_mgr, "get_PlayerContextFast")
    if not ctx then return end
    local player_go = muzzle_safe_call(ctx, "get_GameObject")
    if not player_go then return end

    if player_go ~= arm_hand_cached_player_go then
        joint_r_arm_hand = nil
        joint_l_arm_hand = nil
        joint_r_arm_lower = nil
        joint_l_arm_lower = nil
        arm_hand_cached_player_go = nil
        local xform = muzzle_safe_call(player_go, "get_Transform")
        if xform then
            joint_r_arm_hand = find_transform_with_joint(xform, "R_Arm_Hand")
            joint_l_arm_hand = find_transform_with_joint(xform, "L_Arm_Hand")
            joint_r_arm_lower = find_transform_with_joint(xform, "R_Arm_Lower")
            joint_l_arm_lower = find_transform_with_joint(xform, "L_Arm_Lower")
            if joint_r_arm_hand or joint_l_arm_hand or joint_r_arm_lower or joint_l_arm_lower then
                arm_hand_cached_player_go = player_go
            end
        end
    end
    arm_hand_last_resolve_time = now
end

local _muzzle_ads_suppressed = false

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
local arm_rotation_enabled = prefs.arm_rotation_enabled
local sfps_toggled_this_frame = false

local function sync_auto_iron_sight()
    if not prefs.auto_iron_sight then return end
    if standard_fps_mode then
        hide_reticle = false
        bullet_from_muzzle = false
    else
        hide_reticle = true
        bullet_from_muzzle = true
    end
end
sync_auto_iron_sight()

local hk = require("Hotkeys/Hotkeys")
local IS_HK_PATH = "IronSights/hotkeys.json"
local is_hk_default_settings = {
    use_modifier = false,
    use_pad_modifier = true,
    use_arm_rot_modifier = false,
    use_pad_arm_rot_modifier = true,
    use_ha_modifier = false,
    use_pad_ha_modifier = true,
    hotkeys = {
        ["SFPS Modifier"] = "R Mouse",
        ["Standard FPS Toggle"] = "EX0",
        ["Pad SFPS Modifier"] = "LT (L2)",
        ["Pad Standard FPS Toggle"] = "",
        ["Arm Rotation Modifier"] = "",
        ["Arm Rotation Toggle"] = "F7",
        ["Pad Arm Rotation Modifier"] = "LT (L2)",
        ["Pad Arm Rotation Toggle"] = "",
        ["HA Modifier"] = "",
        ["Hold Animation Toggle"] = "T",
        ["Pad HA Modifier"] = "LT (L2)",
        ["Pad Hold Animation Toggle"] = "L3",
    }
}
local is_hk_settings = hk.recurse_def_settings(json.load_file(IS_HK_PATH) or {}, is_hk_default_settings)
hk.setup_hotkeys(is_hk_settings.hotkeys, is_hk_default_settings.hotkeys)

local sfps_toggle_was_down = false
local arm_rot_toggle_was_down = false
local arm_rot_last_press_time = 0
local ARM_ROT_DOUBLECLICK_WINDOW = 0.4
local arm_rot_blend = arm_rotation_enabled and 1.0 or 0.0
local arm_rot_velocity = 0.0
local arm_rot_prev_target = arm_rotation_enabled and 1.0 or 0.0
local arm_rot_in_transition = false
local arm_rot_transition_start_time = 0.0
local arm_rot_transition_start_blend = 0.0
local arm_rot_blend_last_time = os.clock()
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
        sync_auto_iron_sight()
    end
    sfps_toggle_was_down = is_down or false

    local ar_kb = (not is_hk_settings.use_arm_rot_modifier or hk.check_hotkey("Arm Rotation Modifier", true)) and hk.check_hotkey("Arm Rotation Toggle", true)
    local ar_pad = (not is_hk_settings.use_pad_arm_rot_modifier or hk.check_hotkey("Pad Arm Rotation Modifier", true)) and hk.check_hotkey("Pad Arm Rotation Toggle", true)
    local ar_down = ar_kb or ar_pad
    if ar_down and not arm_rot_toggle_was_down then
        local now = os.clock()
        if arm_rot_last_press_time > 0 and (now - arm_rot_last_press_time) <= ARM_ROT_DOUBLECLICK_WINDOW then
            arm_rotation_enabled = not arm_rotation_enabled
            prefs.arm_rotation_enabled = arm_rotation_enabled
            save_prefs()
            arm_rot_last_press_time = 0
        else
            arm_rot_last_press_time = now
        end
    end
    arm_rot_toggle_was_down = ar_down or false
end)

local camera_offset_applied = false
local cached_weapon_id = nil
local cached_character = nil
local cached_is_holding = false
local cached_fps_state = nil
local cached_busy_ads = false
local cached_is_hold_end_request = false

local function get_player_context()
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    if not cm then return nil end
    local ok, ctx = pcall(cm.call, cm, "getPlayerContextRef")
    if ok then return ctx end
    return nil
end

local function get_equipped_weapon_id_from_ctx(ctx)
    if not ctx or not TYPE_PlayerEquipment then return nil end
    local ok_go, go = pcall(ctx.call, ctx, "get_GameObject")
    if not ok_go or not go then return nil end
    local ok_pe, pe = pcall(go.call, go, "getComponent(System.Type)", TYPE_PlayerEquipment)
    if not ok_pe or not pe then return nil end
    local ok_eid, eid = pcall(pe.get_field, pe, "<EquipWeaponID>k__BackingField")
    if not ok_eid or not eid then return nil end
    local ok_s, eid_str = pcall(eid.call, eid, "ToString()")
    if not ok_s or not eid_str then
        local ok_v, val = pcall(eid.get_field, eid, "value__")
        if ok_v and val then eid_str = tostring(val) end
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
        local ok_vm, view_mode = pcall(ctx.get_field, ctx, "<CurrentViewMode>k__BackingField")
        cached_view_mode = (ok_vm and tonumber(view_mode)) or -1

        local ok_il, is_leon = pcall(ctx.call, ctx, "get_IsCp_A0Character")
        cached_character = (ok_il and is_leon) and "leon" or "grace"

        local raw_id = get_equipped_weapon_id_from_ctx(ctx)
        cached_weapon_id = get_offset_key(raw_id, cached_character)

        cached_is_hold_end_request = false
        local ok_go, go = pcall(ctx.call, ctx, "get_GameObject")
        if ok_go and go then
            local input_driver_type = (cached_character == "leon") and TYPE_Cp_A000InputDriver or TYPE_Cp_A100InputDriver
            if input_driver_type then
                local ok_drv, driver = pcall(go.call, go, "getComponent(System.Type)", input_driver_type)
                if ok_drv and driver then
                    local ok_req, val = pcall(driver.get_field, driver, "<IsHoldEndRequest>k__BackingField")
                    cached_is_hold_end_request = ok_req and val == true
                end
            end
        end

        cached_is_holding = false
        if TYPE_CameraPosSetting and go then
            if ok_go and go then
                local ok_cps, cps = pcall(go.call, go, "getComponent(System.Type)", TYPE_CameraPosSetting)
                if ok_cps and cps then
                    local ok_h, hold = pcall(cps.get_field, cps, "_IsHold")
                    cached_is_holding = ok_h and hold == true

                    cached_fps_state = nil
                    local ok_sf, state_fps = pcall(cps.get_field, cps, "_StateFPS")
                    if ok_sf and state_fps then
                        local ok_sv, state_val = pcall(state_fps.get_field, state_fps, "<State>k__BackingField")
                        if ok_sv and state_val ~= nil then
                            local ok_n, name = pcall(state_val.call, state_val, "ToString()")
                            if ok_n and name then
                                cached_fps_state = name
                            else
                                local ok_v, val = pcall(state_val.get_field, state_val, "value__")
                                if ok_v then cached_fps_state = val end
                            end
                        end
                    end

                    cached_busy_ads = false
                    local ok_bl, blender = pcall(cps.get_field, cps, "_CameraBlender")
                    if ok_bl and blender then
                        local ok_bt, bct = pcall(blender.get_field, blender, "<BusyCameraType>k__BackingField")
                        if ok_bt and bct then
                            local ok_bn, bct_name = pcall(bct.call, bct, "ToString()")
                            cached_busy_ads = ok_bn and (bct_name == "ADS")
                        end
                    end
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
        cached_is_hold_end_request = false
    end

    if prefs.muzzle_disable_ads_snipers and cached_busy_ads
        and (cached_weapon_id == "arm0600" or cached_weapon_id == "arm0601") then
        if not _muzzle_ads_suppressed then
            bullet_from_muzzle = false
            _muzzle_ads_suppressed = true
        end
    elseif _muzzle_ads_suppressed then
        bullet_from_muzzle = prefs.bullet_from_muzzle
        _muzzle_ads_suppressed = false
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

    local sfps_blocked_by_ads = cached_busy_ads and prefs.sfps_disable_ads_snipers
        and (cached_weapon_id == "arm0600" or cached_weapon_id == "arm0601")
    if standard_fps_mode and is_active and not sfps_blocked_by_ads then
        local o_sfps = cached_weapon_id and get_standard_fps_offset(cached_weapon_id)
        if o_sfps then
            tx = o_sfps.x or STANDARD_FPS_X
            ty = o_sfps.y or 0
            tz = o_sfps.z or 0
        else
            tx = STANDARD_FPS_X
            ty = 0
            tz = 0
        end
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

    local ok_go, go = pcall(cam.call, cam, "get_GameObject")
    if not ok_go or not go then return end
    local ok_xf, xform = pcall(go.call, go, "get_Transform")
    if not ok_xf or not xform then return end

    local ok_p, pos = pcall(xform.call, xform, "get_Position")
    if not ok_p or not pos then return end

    local ok_r, rot = pcall(xform.call, xform, "get_Rotation")
    if not ok_r or not rot then return end

    local world_offset = quat_rotate_vec3(rot, { x = ox, y = oy, z = oz })

    pcall(xform.call, xform, "set_Position", Vector4f.new(
        pos.x + world_offset.x,
        pos.y + world_offset.y,
        pos.z + world_offset.z,
        1.0
    ))
    camera_offset_applied = true
end)

_ha.hold_start = nil

_ha.motion_type = sdk.typeof("via.motion.Motion")

-- Cache method objects for motion layer set calls (avoid string lookup per frame)
_ha.layer_td = sdk.find_type_definition("via.motion.Layer")
_ha.meth_set_blend = _ha.layer_td and _ha.layer_td:get_method("set_BlendRate")
_ha.meth_set_speed = _ha.layer_td and _ha.layer_td:get_method("set_Speed")

local function get_player_motion_is()
    local char_mgr = sdk.get_managed_singleton("app.CharacterManager")
    if not char_mgr then return nil end
    local ok1, ctx = pcall(char_mgr.call, char_mgr, "get_PlayerContextFast")
    if not ok1 or not ctx then return nil end
    local ok2, go = pcall(ctx.call, ctx, "get_GameObject")
    if not ok2 or not go then return nil end
    local ok3, motion = pcall(go.call, go, "getComponent(System.Type)", _ha.motion_type)
    if not ok3 then return nil end
    return motion
end

local function get_all_motion_layers_is()
    local motion = get_player_motion_is()
    if not motion then return {} end
    local layers = {}
    local ok_lc, lc = pcall(motion.call, motion, "getLayerCount")
    if not ok_lc or not lc then return layers end
    for i = 0, lc - 1 do
        local ok_gl, tl = pcall(motion.call, motion, "getLayer", i)
        if ok_gl and tl then
            local ok_r, running = pcall(tl.call, tl, "get_Running")
            local ok_e, empty = pcall(tl.call, tl, "get_TreeEmpty")
            if ok_r and running and ok_e and not empty then
                local name = ""
                local ok_mn, mn = pcall(tl.call, tl, "get_HighestWeightMotionNode")
                if ok_mn and mn then
                    local ok_n, n = pcall(mn.call, mn, "get_MotionName")
                    if ok_n and n then name = n end
                end
                layers[#layers + 1] = { idx = i, layer = tl, name = name }
            end
        end
    end
    return layers
end

-- Cache motion layers for hold-anim to avoid get_all_motion_layers_is() every frame (frametime spike)
_ha.layers_cache = nil
_ha.layers_cache_time = 0
_ha.layers_cache_weapon = nil
_ha.LAYERS_CACHE_INTERVAL = 0.15

-- True if any motion layer is currently playing a recoil/fire-like clip (so we delay hold-breath blend until it finishes)
local function is_recoil_animation_playing()
    local motion = get_player_motion_is()
    if not motion then return false end
    local ok_lc, lc = pcall(motion.call, motion, "getLayerCount")
    if not ok_lc or not lc then return false end
    for i = 0, lc - 1 do
        local ok_gl, tl = pcall(motion.call, motion, "getLayer", i)
        if ok_gl and tl then
            local ok_r, running = pcall(tl.call, tl, "get_Running")
            if not (ok_r and running) then goto continue end
            local ok_e, empty = pcall(tl.call, tl, "get_TreeEmpty")
            if ok_e and empty then goto continue end
            local ok_mn, mn = pcall(tl.call, tl, "get_HighestWeightMotionNode")
            if not (ok_mn and mn) then goto continue end
            local ok_n, n = pcall(mn.call, mn, "get_MotionName")
            if not (ok_n and n) then goto continue end
            local name_lower = tostring(n or ""):lower()
            if name_lower:find("recoil") or name_lower:find("fire") or name_lower:find("shot") or name_lower:find("shoot") or name_lower:find("attack") or name_lower:find("kick") then
                return true
            end
            ::continue::
        end
    end
    return false
end

local function get_ha_layers_cached()
    local now = os.clock()
    local w = cached_weapon_id
    if _ha.layers_cache and _ha.layers_cache_weapon == w and (now - _ha.layers_cache_time) < _ha.LAYERS_CACHE_INTERVAL then
        return _ha.layers_cache
    end
    _ha.layers_cache = get_all_motion_layers_is()
    _ha.layers_cache_time = now
    _ha.layers_cache_weapon = w
    -- Pre-compute lowercased name and hold flag per layer entry to avoid per-frame string ops
    for i = 1, #_ha.layers_cache do
        local info = _ha.layers_cache[i]
        info.name_lower = info.name:lower()
        info.is_hold = info.name_lower:find("hold") ~= nil
    end
    return _ha.layers_cache
end

_ha.hotkey_activated = false
_ha.toggle_cooldown = 0.35
_ha.last_toggle_time = 0
_ha.last_shot_time = 0
_ha.pending_disengage = false
_ha.disengage_after = 0
_ha.pending_disengage_wkey = nil
local HA_DISENGAGE_DELAY_AFTER_SHOT = 0.5

re.on_application_entry("UpdateBehavior", function()
    local ha_kb = (not is_hk_settings.use_ha_modifier or hk.check_hotkey("HA Modifier", true)) and hk.check_hotkey("Hold Animation Toggle", true)
    local ha_pad = (not is_hk_settings.use_pad_ha_modifier or hk.check_hotkey("Pad HA Modifier", true)) and hk.check_hotkey("Pad Hold Animation Toggle", true)
    local ha_down = ha_kb or ha_pad
    local wkey = cached_weapon_id
    local now = os.clock()

    if prefs.ha_hold_to_activate then
        if _ha.pending_disengage and now >= _ha.disengage_after and _ha.pending_disengage_wkey then
            local pk = _ha.pending_disengage_wkey
            if hold_anim_edits[pk] then
                hold_anim_edits[pk].enabled = false
                local all_ml = get_ha_layers_cached()
                for i = 1, #all_ml do
                    _ha.set_layer(all_ml[i].layer, 1.0, 1.0)
                end
                refresh_any_hold_anim()
                save_hold_anim()
            end
            if _ha.breath_mfr_zeroed then
                _acs.set_min_fit_rate(1.0)
                _ha.breath_mfr_zeroed = false
            end
            if _ha.breath_pf_applied then
                _acs.restore_point_range_all()
                _ha.breath_pf_applied = false
            end
            _ha.hotkey_activated = false
            _ha.pending_disengage = false
            _ha.pending_disengage_wkey = nil
            _ha.last_toggle_time = now
        elseif ha_down and wkey then
            if _ha.pending_disengage then
                _ha.pending_disengage = false
                _ha.pending_disengage_wkey = nil
            end
            if not _ha.hotkey_activated and (now - _ha.last_toggle_time) >= _ha.toggle_cooldown then
                if not hold_anim_edits[wkey] then hold_anim_edits[wkey] = { force = 1.0, speed = 0.1, ramp = 1.5 } end
                hold_anim_edits[wkey].enabled = true
                _ha.blend_weight = 0.0
                _ha.active_start = nil
                refresh_any_hold_anim()
                save_hold_anim()
                _ha.hotkey_activated = true
                _ha.last_toggle_time = now
            end
        elseif _ha.hotkey_activated and wkey then
            _ha.pending_disengage = true
            _ha.disengage_after = math.max(now, _ha.last_shot_time + HA_DISENGAGE_DELAY_AFTER_SHOT)
            _ha.pending_disengage_wkey = wkey
        end
    else
        if ha_down and not ha_toggle_was_down and wkey and (now - _ha.last_toggle_time) >= _ha.toggle_cooldown then
            if not hold_anim_edits[wkey] then hold_anim_edits[wkey] = { force = 1.0, speed = 0.1, ramp = 1.5 } end
            local new_state = not (hold_anim_edits[wkey].enabled or false)
            hold_anim_edits[wkey].enabled = new_state
            _ha.blend_weight = 0.0
            _ha.active_start = nil
            if not new_state then
                local all_ml = get_ha_layers_cached()
                for i = 1, #all_ml do
                    _ha.set_layer(all_ml[i].layer, 1.0, 1.0)
                end
                if _ha.breath_mfr_zeroed then
                    _acs.set_min_fit_rate(1.0)
                    _ha.breath_mfr_zeroed = false
                end
                if _ha.breath_pf_applied then
                    _acs.restore_point_range_all()
                    _ha.breath_pf_applied = false
                end
            end
            refresh_any_hold_anim()
            save_hold_anim()
            _ha.last_toggle_time = now
        end
    end
    ha_toggle_was_down = ha_down or false
end)

re.on_application_entry("UpdateBehavior", function()
    if cached_is_holding then
        if not _ha.hold_start then _ha.hold_start = os.clock() end
    else
        _ha.hold_start = nil
    end

    if not _ha.any_enabled then return end
    if not cached_weapon_id then return end

    local now = os.clock()
    local dt = now - _ha.last_time
    _ha.last_time = now
    if dt > 0.1 then dt = 0.016 end
    if dt <= 0 then return end

    local enabled, _, _, _, delay, ramp = get_hold_anim_for_key(cached_weapon_id)

    if not enabled then
        if _ha.blend_weight > 0 then
            _ha.blend_weight = math.max(0, _ha.blend_weight - dt * ramp)
            if _ha.blend_weight < 0.001 then _ha.blend_weight = 0 end
        end
        _ha.active_start = nil
        if _ha.breath_mfr_zeroed then
            _acs.set_min_fit_rate(1.0)
            _ha.breath_mfr_zeroed = false
        end
        if _ha.breath_pf_applied then
            _acs.restore_point_range_all()
            _ha.breath_pf_applied = false
        end
        return
    end

    local want_active = cached_is_holding and not cached_busy_ads
    if want_active and delay > 0 and _ha.hold_start then
        if (now - _ha.hold_start) < delay then
            want_active = false
        end
    end

    local breath_dur = prefs.ha_breath_duration
    if want_active and breath_dur > 0 then
        if not _ha.active_start then
            _ha.active_start = now
        end
        if (now - _ha.active_start) >= breath_dur then
            want_active = false
        end
    end

    if not want_active or not cached_is_holding then
        if not cached_is_holding then
            _ha.active_start = nil
        end
    end

    -- Don't start or increase hold-breath blend until recoil animation is complete
    local recoil_playing = want_active and is_recoil_animation_playing()
    if recoil_playing then _ha.last_shot_time = now end
    local allow_blend_in = want_active and not recoil_playing
    if allow_blend_in then
        _ha.blend_weight = math.min(1.0, _ha.blend_weight + dt * ramp)
    else
        _ha.blend_weight = math.max(0.0, _ha.blend_weight - dt * ramp)
        if _ha.blend_weight < 0.001 then _ha.blend_weight = 0 end
    end

    local should_zero_mfr = want_active and _ha.blend_weight > 0 and prefs.ha_apply_min_fit_rate
    if should_zero_mfr and not _ha.breath_mfr_zeroed then
        _acs.set_min_fit_rate(0.0)
        _ha.breath_mfr_zeroed = true
    elseif not should_zero_mfr and _ha.breath_mfr_zeroed then
        _acs.set_min_fit_rate(1.0)
        _ha.breath_mfr_zeroed = false
    end

    local should_pf = prefs.perfect_focus and want_active and _ha.blend_weight > 0 and prefs.ha_apply_min_fit_rate
    if should_pf and not _ha.breath_pf_applied then
        _acs.set_point_range_all(100, 100)
        _ha.breath_pf_applied = true
    elseif not should_pf and _ha.breath_pf_applied then
        _acs.restore_point_range_all()
        _ha.breath_pf_applied = false
    end
end)

-- Arm hand rotation: apply offset after animation (R_Arm_Hand + L_Arm_Hand mirrored)
local function arm_hand_rotation_non_zero()
    local eps = 0.0001
    return math.abs(arm_hand_rotation.x) > eps or math.abs(arm_hand_rotation.y) > eps or math.abs(arm_hand_rotation.z) > eps
end

local function arm_lower_rotation_non_zero()
    local eps = 0.0001
    return math.abs(arm_lower_rotation.x) > eps or math.abs(arm_lower_rotation.y) > eps or math.abs(arm_lower_rotation.z) > eps
end

-- Cache method objects for joint get/set (avoids string lookup per call)
local _ah_joint_td = sdk.find_type_definition("via.Joint")
local _ah_meth_get_rot = _ah_joint_td and _ah_joint_td:get_method("get_Rotation")
local _ah_meth_set_rot = _ah_joint_td and _ah_joint_td:get_method("set_Rotation")

-- Reusable native Quaternion for set_Rotation (avoids per-frame allocation)
local _ah_temp_quat_native = nil
pcall(function()
    if Quaternion then _ah_temp_quat_native = Quaternion.new() end
end)

local arm_rot_identity_quat = { w = 1.0, x = 0.0, y = 0.0, z = 0.0 }

-- Cache base offset quats (avoid 4x euler_deg_to_quat per frame); invalidated by save_arm_hand_rotation
local _ah_off_cache_valid = false
local _ah_cached_off_r, _ah_cached_off_l, _ah_cached_lower_r, _ah_cached_lower_l

local function _ah_set_joint_rotation(joint, off)
    if not joint then return end
    local ok, cur
    if _ah_meth_get_rot then
        ok, cur = pcall(_ah_meth_get_rot, joint)
    end
    if not ok or not cur then
        ok, cur = pcall(joint.call, joint, "get_Rotation")
        if not ok or not cur then return end
    end
    -- Inline quat multiply + normalize: result = cur * off
    local cw, cx, cy, cz = cur.w, cur.x, cur.y, cur.z
    local ow, ox, oy, oz = off.w, off.x, off.y, off.z
    local rw = cw * ow - cx * ox - cy * oy - cz * oz
    local rx = cw * ox + cx * ow + cy * oz - cz * oy
    local ry = cw * oy - cx * oz + cy * ow + cz * ox
    local rz = cw * oz + cx * oy - cy * ox + cz * ow
    local len = math.sqrt(rw * rw + rx * rx + ry * ry + rz * rz)
    if len > 1e-8 then
        local inv = 1.0 / len
        rw = rw * inv; rx = rx * inv; ry = ry * inv; rz = rz * inv
    end
    if _ah_temp_quat_native then
        _ah_temp_quat_native.w = rw; _ah_temp_quat_native.x = rx; _ah_temp_quat_native.y = ry; _ah_temp_quat_native.z = rz
        if _ah_meth_set_rot then
            pcall(_ah_meth_set_rot, joint, _ah_temp_quat_native)
        else
            pcall(joint.call, joint, "set_Rotation", _ah_temp_quat_native)
        end
    else
        cur.w = rw; cur.x = rx; cur.y = ry; cur.z = rz
        pcall(joint.call, joint, "set_Rotation", cur)
    end
end

-- Pre-allocated offset quats for slerp results (avoid per-frame table creation)
local _ah_slerp_r = { w = 1, x = 0, y = 0, z = 0 }
local _ah_slerp_l = { w = 1, x = 0, y = 0, z = 0 }
local _ah_slerp_lr = { w = 1, x = 0, y = 0, z = 0 }
local _ah_slerp_ll = { w = 1, x = 0, y = 0, z = 0 }

local function apply_arm_hand_rotation()
    if arm_rot_blend <= 0 then return end
    if not cached_is_hold_end_request then return end
    local hand_nz = arm_hand_rotation_non_zero()
    local lower_nz = arm_lower_rotation_non_zero()
    if not hand_nz and not lower_nz then return end
    resolve_arm_hand_joints()

    if not _ah_off_cache_valid then
        _ah_cached_off_r = arm_hand_offset_quat_r()
        _ah_cached_off_l = arm_hand_offset_quat_l()
        _ah_cached_lower_r = arm_lower_offset_quat_r()
        _ah_cached_lower_l = arm_lower_offset_quat_l()
        _ah_off_cache_valid = true
    end

    local blend = arm_rot_blend
    if blend == 1.0 then
        if hand_nz then
            _ah_set_joint_rotation(joint_r_arm_hand, _ah_cached_off_r)
            _ah_set_joint_rotation(joint_l_arm_hand, _ah_cached_off_l)
        end
        if lower_nz then
            _ah_set_joint_rotation(joint_r_arm_lower, _ah_cached_lower_r)
            _ah_set_joint_rotation(joint_l_arm_lower, _ah_cached_lower_l)
        end
        return
    end

    if hand_nz then
        local q = quat_slerp(arm_rot_identity_quat, _ah_cached_off_r, blend)
        _ah_slerp_r.w = q.w; _ah_slerp_r.x = q.x; _ah_slerp_r.y = q.y; _ah_slerp_r.z = q.z
        q = quat_slerp(arm_rot_identity_quat, _ah_cached_off_l, blend)
        _ah_slerp_l.w = q.w; _ah_slerp_l.x = q.x; _ah_slerp_l.y = q.y; _ah_slerp_l.z = q.z
        _ah_set_joint_rotation(joint_r_arm_hand, _ah_slerp_r)
        _ah_set_joint_rotation(joint_l_arm_hand, _ah_slerp_l)
    end
    if lower_nz then
        local q = quat_slerp(arm_rot_identity_quat, _ah_cached_lower_r, blend)
        _ah_slerp_lr.w = q.w; _ah_slerp_lr.x = q.x; _ah_slerp_lr.y = q.y; _ah_slerp_lr.z = q.z
        q = quat_slerp(arm_rot_identity_quat, _ah_cached_lower_l, blend)
        _ah_slerp_ll.w = q.w; _ah_slerp_ll.x = q.x; _ah_slerp_ll.y = q.y; _ah_slerp_ll.z = q.z
        _ah_set_joint_rotation(joint_r_arm_lower, _ah_slerp_lr)
        _ah_set_joint_rotation(joint_l_arm_lower, _ah_slerp_ll)
    end
end

re.on_application_entry("LateUpdateBehavior", function()
    local target = arm_rotation_enabled and 1.0 or 0.0

    -- Fast path: already settled at target — only re-apply rotation, skip all blend math
    if arm_rot_blend == target and arm_rot_velocity == 0.0 and not arm_rot_in_transition then
        apply_arm_hand_rotation()
        return
    end

    local now = os.clock()
    local dt = now - arm_rot_blend_last_time
    if dt < 0 then dt = 0 end
    arm_rot_blend_last_time = now
    if dt > 0.05 then dt = 0.05 end

    if target ~= arm_rot_prev_target then
        arm_rot_prev_target = target
        arm_rot_in_transition = true
        arm_rot_transition_start_time = now
        arm_rot_transition_start_blend = arm_rot_blend
    end

    if arm_rot_in_transition then
        local duration = (target > 0.5) and math.max(0.001, ARM_ROT_TRANSITION_IN) or math.max(0.001, ARM_ROT_TRANSITION_OUT)
        local elapsed = now - arm_rot_transition_start_time
        if elapsed >= duration then
            arm_rot_in_transition = false
            if prefs.arm_rot_wobble then
                arm_rot_blend = (target > 0.5) and 0.9 or 0.1
                arm_rot_velocity = (target > 0.5) and 5.0 or -5.0
            else
                arm_rot_blend = target
                arm_rot_velocity = 0.0
            end
        else
            arm_rot_blend = arm_rot_transition_start_blend + (target - arm_rot_transition_start_blend) * smoothstep(elapsed / duration)
            arm_rot_velocity = 0.0
        end
    else
        local speed_scale = (target > 0.5) and (0.2 / math.max(0.05, ARM_ROT_TRANSITION_IN)) or (0.2 / math.max(0.05, ARM_ROT_TRANSITION_OUT))
        if speed_scale < 0.3 then speed_scale = 0.3 elseif speed_scale > 3.0 then speed_scale = 3.0 end
        local k = ARM_ROT_SPRING_K * speed_scale
        local accel = k * (target - arm_rot_blend) - ARM_ROT_SPRING_D * math.sqrt(speed_scale) * arm_rot_velocity
        arm_rot_velocity = arm_rot_velocity + accel * dt
        arm_rot_blend = arm_rot_blend + arm_rot_velocity * dt

        if arm_rot_blend < ARM_ROT_BLEND_CLAMP_LO then arm_rot_blend = ARM_ROT_BLEND_CLAMP_LO
        elseif arm_rot_blend > ARM_ROT_BLEND_CLAMP_HI then arm_rot_blend = ARM_ROT_BLEND_CLAMP_HI end

        local diff = arm_rot_blend - target
        if diff < 0 then diff = -diff end
        local vel = arm_rot_velocity
        if vel < 0 then vel = -vel end
        if diff < ARM_ROT_SETTLE_THRESH and vel < ARM_ROT_VEL_THRESH then
            arm_rot_blend = target
            arm_rot_velocity = 0.0
        end
    end

    apply_arm_hand_rotation()
end)

-- Reusable sel_set table and helper to avoid per-frame allocation
_ha.sel_set = {}
_ha.sel_count = 0

_ha.set_layer = function(layer, blend_val, speed_val)
    if _ha.meth_set_blend then
        pcall(_ha.meth_set_blend, layer, blend_val)
    else
        pcall(layer.call, layer, "set_BlendRate", blend_val)
    end
    if _ha.meth_set_speed then
        pcall(_ha.meth_set_speed, layer, speed_val)
    else
        pcall(layer.call, layer, "set_Speed", speed_val)
    end
end

-- Build sel_set from sel_layers + all_layers, reusing the table
local function _ha_build_sel_set(all_layers, sel_layers)
    -- Clear previous entries
    for k in pairs(_ha.sel_set) do _ha.sel_set[k] = nil end
    _ha.sel_count = 0

    if sel_layers then
        for i = 1, #sel_layers do _ha.sel_set[sel_layers[i]] = true end
    end

    -- Filter: only keep sel entries whose layer name contains "hold"
    for i = 1, #all_layers do
        local info = all_layers[i]
        if _ha.sel_set[info.idx] and not info.is_hold then
            _ha.sel_set[info.idx] = nil
        end
    end

    -- If nothing left, select all hold layers
    if not next(_ha.sel_set) then
        for i = 1, #all_layers do
            local info = all_layers[i]
            if info.is_hold then
                _ha.sel_set[info.idx] = true
            end
        end
    end

    -- Count for fast empty check
    _ha.sel_count = 0
    for _ in pairs(_ha.sel_set) do _ha.sel_count = _ha.sel_count + 1 end
end

re.on_application_entry("LateUpdateBehavior", function()
    if not _ha.any_enabled then return end
    if not cached_weapon_id then return end

    local enabled, force, speed, sel_layers = get_hold_anim_for_key(cached_weapon_id)
    if not enabled then
        if _ha.was_holding and _ha.blend_weight <= 0 then
            local all_layers = get_ha_layers_cached()
            for i = 1, #all_layers do
                _ha.set_layer(all_layers[i].layer, 1.0, 1.0)
            end
            _ha.was_holding = false
        end
        return
    end

    local all_layers = get_ha_layers_cached()
    _ha_build_sel_set(all_layers, sel_layers)
    if _ha.sel_count == 0 then return end

    if _ha.blend_weight > 0 then
        local t = _ha.blend_weight
        local blended_force = 1.0 + (force - 1.0) * t
        local blended_speed = 1.0 + (speed - 1.0) * t
        for i = 1, #all_layers do
            local info = all_layers[i]
            if _ha.sel_set[info.idx] then
                _ha.set_layer(info.layer, blended_force, blended_speed)
            end
        end
        _ha.was_holding = true
    elseif _ha.was_holding then
        for i = 1, #all_layers do
            local info = all_layers[i]
            if _ha.sel_set[info.idx] then
                _ha.set_layer(info.layer, 1.0, 1.0)
            end
        end
        _ha.was_holding = false
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
            sync_auto_iron_sight()
        end
        -- Standard FPS offsets: show when Standard FPS Mode is on so sliders are always visible
        if standard_fps_mode then
            local sfps_node_open = imgui.tree_node("Standard FPS camera offsets")
            if sfps_node_open then
                local sfps_key = dropdown_items[selected_index] or dropdown_items[1]
                local sfps_o = get_standard_fps_offset(sfps_key) or default_standard_fps_offsets[sfps_key] or default_standard_fps_offset
                local sfps_x, sfps_y, sfps_z = sfps_o.x or 0, sfps_o.y or 0, sfps_o.z or 0
                local sx, sx_new = imgui.drag_float("Left/Right (Standard FPS)", sfps_x, 0.001, -5.0, 5.0, "%.4f")
                if sx then sfps_x = sx_new end
                local sy, sy_new = imgui.drag_float("Up/Down (Standard FPS)", sfps_y, 0.001, -5.0, 5.0, "%.4f")
                if sy then sfps_y = sy_new end
                local sz, sz_new = imgui.drag_float("Back/Forward (Standard FPS)", sfps_z, 0.001, -5.0, 5.0, "%.4f")
                if sz then sfps_z = sz_new end
                if sx or sy or sz then
                    set_standard_fps_offset(sfps_key, sfps_x, sfps_y, sfps_z)
                end
                imgui.text("Weapon: " .. (WEAPON_NAMES[sfps_key] or sfps_key))
                imgui.text("Uses the weapon selected in the Weapon dropdown below.")
                imgui.tree_pop()
            end
        end
        local arm_rot_changed
        arm_rot_changed, arm_rotation_enabled = imgui.checkbox("Arm rotation adjustment", arm_rotation_enabled)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Apply arm/hand and arm lower rotation offsets. Toggle with hotkey: rapid double-click (see Hotkeys section).")
        end
        if arm_rot_changed then
            prefs.arm_rotation_enabled = arm_rotation_enabled
            save_prefs()
        end
        local artin_changed
        artin_changed, ARM_ROT_TRANSITION_IN = imgui.drag_float("Arm rot. transition in (sec)", ARM_ROT_TRANSITION_IN, 0.01, 0.0, 5.0, "%.2f")
        if imgui.is_item_hovered() then
            imgui.set_tooltip("How fast arm rotation blends in when enabled")
        end
        if artin_changed then prefs.arm_rot_transition_in = ARM_ROT_TRANSITION_IN; save_prefs() end
        local artout_changed
        artout_changed, ARM_ROT_TRANSITION_OUT = imgui.drag_float("Arm rot. transition out (sec)", ARM_ROT_TRANSITION_OUT, 0.01, 0.0, 5.0, "%.2f")
        if imgui.is_item_hovered() then
            imgui.set_tooltip("How fast arm rotation blends out when disabled")
        end
        if artout_changed then prefs.arm_rot_transition_out = ARM_ROT_TRANSITION_OUT; save_prefs() end
        local wobble_changed
        wobble_changed, prefs.arm_rot_wobble = imgui.checkbox("Arm rot. wobble (overshoot effect)", prefs.arm_rot_wobble)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Adds a realistic overshoot/oscillation after the transition ends. Disable for a clean, smooth blend.")
        end
        if wobble_changed then save_prefs() end
        if prefs.arm_rot_wobble then
        local ark_changed
        ark_changed, ARM_ROT_SPRING_K = imgui.drag_float("Arm rot. spring stiffness (K)", ARM_ROT_SPRING_K, 1.0, 10.0, 5000.0, "%.0f")
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Higher = snappier wobble after transition")
        end
        if ark_changed then prefs.arm_rot_spring_k = ARM_ROT_SPRING_K; save_prefs() end
        local ard_changed
        ard_changed, ARM_ROT_SPRING_D = imgui.drag_float("Arm rot. spring damping (D)", ARM_ROT_SPRING_D, 0.1, 1.0, 100.0, "%.1f")
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Lower = more oscillation; higher = settles faster")
        end
        if ard_changed then prefs.arm_rot_spring_d = ARM_ROT_SPRING_D; save_prefs() end
        end -- wobble sliders
        -- Arm hand rotation (R_Arm_Hand / L_Arm_Hand)
        if imgui.tree_node("Arm hand rotation") then
            resolve_arm_hand_joints()
            imgui.text("L_Arm_Hand mirrors R_Arm_Hand.")
            local ah_changed = false
            local ax, ax_new = imgui.drag_float("X (deg)", arm_hand_rotation.x, 0.5, -180.0, 180.0, "%.1f")
            if ax then arm_hand_rotation.x = ax_new; ah_changed = true end
            local ay, ay_new = imgui.drag_float("Y (deg)", arm_hand_rotation.y, 0.5, -180.0, 180.0, "%.1f")
            if ay then arm_hand_rotation.y = ay_new; ah_changed = true end
            local az, az_new = imgui.drag_float("Z (deg)", arm_hand_rotation.z, 0.5, -180.0, 180.0, "%.1f")
            if az then arm_hand_rotation.z = az_new; ah_changed = true end
            if ah_changed then save_arm_hand_rotation() end
            if imgui.button("Reset##arm_hand") then
                arm_hand_rotation.x = 0.0
                arm_hand_rotation.y = 0.0
                arm_hand_rotation.z = 0.0
                save_arm_hand_rotation()
            end
            if not joint_r_arm_hand and not joint_l_arm_hand then
                imgui.text_colored("Arm hand joints not found", 0xFF00FF00)
            end
            imgui.tree_pop()
        end
        -- Arm lower rotation (R_Arm_Lower / L_Arm_Lower)
        if imgui.tree_node("Arm lower rotation") then
            resolve_arm_hand_joints()
            imgui.text("L_Arm_Lower mirrors R_Arm_Lower.")
            local al_changed = false
            local lx, lx_new = imgui.drag_float("X (deg)##arm_lower", arm_lower_rotation.x, 0.5, -180.0, 180.0, "%.1f")
            if lx then arm_lower_rotation.x = lx_new; al_changed = true end
            local ly, ly_new = imgui.drag_float("Y (deg)##arm_lower", arm_lower_rotation.y, 0.5, -180.0, 180.0, "%.1f")
            if ly then arm_lower_rotation.y = ly_new; al_changed = true end
            local lz, lz_new = imgui.drag_float("Z (deg)##arm_lower", arm_lower_rotation.z, 0.5, -180.0, 180.0, "%.1f")
            if lz then arm_lower_rotation.z = lz_new; al_changed = true end
            if al_changed then save_arm_hand_rotation() end
            if imgui.button("Reset##arm_lower") then
                arm_lower_rotation.x = 0.0
                arm_lower_rotation.y = 0.0
                arm_lower_rotation.z = 0.0
                save_arm_hand_rotation()
            end
            if not joint_r_arm_lower and not joint_l_arm_lower then
                imgui.text_colored("Arm lower joints not found", 0xFF00FF00)
            end
            imgui.tree_pop()
        end
        -- local ads_sniper_c, ads_sniper_v = imgui.checkbox("Disable SFPS During ADS (Snipers)", prefs.sfps_disable_ads_snipers)
        -- if imgui.is_item_hovered() then
        --     imgui.set_tooltip("Disables Standard FPS offset when using scopes/red dots on Classic 70 and Marksman 1A")
        -- end
        -- if ads_sniper_c then
        --     prefs.sfps_disable_ads_snipers = ads_sniper_v
        --     save_prefs()
        -- end
        -- local muz_sniper_c, muz_sniper_v = imgui.checkbox("Disable Muzzle Spawn During ADS for Snipers)", prefs.muzzle_disable_ads_snipers)
        -- if imgui.is_item_hovered() then
        --     imgui.set_tooltip("Disables bullet-from-muzzle when using scopes/red dots on Classic 70 and Marksman 1A")
        -- end
        if muz_sniper_c then
            prefs.muzzle_disable_ads_snipers = muz_sniper_v
            save_prefs()
        end
        local ais_changed, ais_new = imgui.checkbox("Auto Hide Crosshair Mode", prefs.auto_iron_sight)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Shows crosshair in default view; hides crosshair and enables muzzle spawn in iron sights")
        end
        if ais_changed then
            prefs.auto_iron_sight = ais_new
            save_prefs()
            if ais_new then
                sync_auto_iron_sight()
            else
                hide_reticle = prefs.hide_reticle
                bullet_from_muzzle = prefs.bullet_from_muzzle
            end
        end
        if not prefs.auto_iron_sight then
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
        end
        imgui.separator()

        local equipped_id = cached_weapon_id
        if equipped_id then
            local eid_name = WEAPON_NAMES[equipped_id] or equipped_id
            local state_label = cached_fps_state and (" | " .. (COVER_STATE_LABELS[cached_fps_state] or cached_fps_state)) or ""
            imgui.text_colored("Equipped: " .. eid_name .. state_label, 0xFFFFFF00)
            -- local is_sniper = equipped_id == "arm0600" or equipped_id == "arm0601"
            -- imgui.text(string.format("  DBG MUZZLE: busy_ads=%s | suppressed=%s | bfm=%s | sniper=%s",
            --     tostring(cached_busy_ads), tostring(_muzzle_ads_suppressed),
            --     tostring(bullet_from_muzzle), tostring(is_sniper)))

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
                if cover_state == "StandardFPS" then
                    set_standard_fps_offset(key, ui_offset.x, ui_offset.y, ui_offset.z)
                elseif cover_state then
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
                    if cover_state == "StandardFPS" then
                        local def = default_standard_fps_offsets[key] or default_standard_fps_offset
                        ui_offset.x = def.x
                        ui_offset.y = def.y
                        ui_offset.z = def.z
                        standard_fps_offsets[key] = { x = def.x, y = def.y, z = def.z }
                        save_standard_fps_offsets()
                    elseif cover_state then
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
                        if cover_state == "StandardFPS" then
                            set_standard_fps_offset(wk, ui_offset.x, ui_offset.y, ui_offset.z)
                        elseif cover_state then
                            set_cover_offset(wk, cover_state, ui_offset.x, ui_offset.y, ui_offset.z)
                        else
                            weapon_offsets[wk] = { x = ui_offset.x, y = ui_offset.y, z = ui_offset.z }
                        end
                    end
                    if cover_state == "StandardFPS" then save_standard_fps_offsets() end
                    if not cover_state then save_offsets() end
                    copy_all_confirm = false
                end
                imgui.same_line()
                if imgui.button("No") then
                    copy_all_confirm = false
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

        -- imgui.spacing()
        -- local mfr_changed, mfr_new = imgui.checkbox("Disable Min Fit Rate", prefs.zero_min_fit_rate)
        -- if imgui.is_item_hovered() then
        --     imgui.set_tooltip("Sets _MinFitRate to 0 for all weapons (default is 1). Removes the minimum aim camera shake intensity")
        -- end
        -- if mfr_changed then
        --     prefs.zero_min_fit_rate = mfr_new
        --     save_prefs()
        --     _acs.applied = false
        -- end
        -- local pf_changed, pf_new = imgui.checkbox("Perfect Focus (Breath Hold)", prefs.perfect_focus)
        -- if imgui.is_item_hovered() then
        --     imgui.set_tooltip("When holding breath, sets _PointRange to 100 for instant perfect aim. Reverts when breath runs out or released")
        -- end
        -- if pf_changed then
        --     prefs.perfect_focus = pf_new
        --     save_prefs()
        --     if not pf_new and _ha.breath_pf_applied then
        --         _acs.restore_point_range_all()
        --         _ha.breath_pf_applied = false
        --     end
        -- end

        imgui.spacing()
        imgui.separator()
        imgui.text_colored("Hold Animation:", 0xFFFFFF00)
        do
            local breath_changed, breath_new = imgui.drag_float("Breath Duration (s)", prefs.ha_breath_duration, 0.1, 0.0, 30.0, "%.1f")
            if imgui.is_item_hovered() then
                imgui.set_tooltip("How long the effect stays active after engaging. 0 = unlimited")
            end
            if breath_changed then
                prefs.ha_breath_duration = breath_new
                save_prefs()
            end
            local mfr_changed, mfr_new = imgui.checkbox("Apply min fit rate when holding breath", prefs.ha_apply_min_fit_rate)
            if imgui.is_item_hovered() then
                imgui.set_tooltip("When checked, holding breath applies min fit rate (camera shake) and point range (reticle fit). Uncheck to leave both unchanged during hold breath.")
            end
            if mfr_changed then
                prefs.ha_apply_min_fit_rate = mfr_new
                save_prefs()
            end
        end

        --[[ Hold Animation UI commented out for release
            local wkey = cached_weapon_id or dropdown_items[selected_index]
            local all_ml = get_all_motion_layers_is()

            local wedit = wkey and hold_anim_edits[wkey] or {}
            -- local dbg_force = wedit.force or 1.0
            -- local dbg_speed = wedit.speed or 1.0
            -- local t = _ha.blend_weight
            -- imgui.text(string.format("  blend: %.3f | force: %.3f -> %.3f | speed: %.3f -> %.3f | holding: %s",
            --     t, dbg_force, 1.0 + (dbg_force - 1.0) * t, dbg_speed, 1.0 + (dbg_speed - 1.0) * t, tostring(cached_is_holding)))
            -- imgui.text(string.format("  mfr_zeroed: %s | pf_applied: %s | breath_start: %s | breath_dur: %.1f",
            --     tostring(_ha.breath_mfr_zeroed),
            --     tostring(_ha.breath_pf_applied),
            --     _ha.active_start and string.format("%.1f ago", os.clock() - _ha.active_start) or "nil",
            --     prefs.ha_breath_duration))
            -- if #all_ml > 0 then
            --     for _, info in ipairs(all_ml) do
            --         local cur_br, cur_sp = 0, 0
            --         pcall(function() cur_br = info.layer:call("get_BlendRate") end)
            --         pcall(function() cur_sp = info.layer:call("get_Speed") end)
            --         imgui.text(string.format("    L%d %s  BR=%.3f  Sp=%.3f", info.idx, info.name, cur_br, cur_sp))
            --     end
            -- end
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
                    _ha.blend_weight = 0.0
                    _ha.active_start = nil
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
        --]]

        imgui.spacing()
        imgui.separator()
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
            TRANSITION_IN = 0.25
            TRANSITION_OUT = 0.25
            TRANSITION_SWAP = 0.5
            prefs.transition_in = TRANSITION_IN
            prefs.transition_out = TRANSITION_OUT
            prefs.transition_swap = TRANSITION_SWAP
            save_prefs()
        end

        imgui.separator()
        imgui.spacing()
        imgui.text_colored("Hotkeys:", 0xFFFFFF00)
        local hk_changed = false
        local wc = false
        imgui.separator()

        imgui.text_colored(" Standard FPS Toggle:", 0xFFFFFFAA)
        imgui.indent(10)
        imgui.text("Keyboard and Mouse:")
        imgui.indent(10)
        local mc; mc, is_hk_settings.use_modifier = imgui.checkbox("Use Modifier##is_kb_mod", is_hk_settings.use_modifier); wc = wc or mc
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Require holding this button while pressing toggle")
        end
        imgui.same_line()
        hk_changed = hk.hotkey_setter("SFPS Modifier") or hk_changed
        hk_changed = hk.hotkey_setter("Standard FPS Toggle", is_hk_settings.use_modifier and "SFPS Modifier") or hk_changed
        imgui.unindent(10)
        imgui.text("Gamepad:")
        imgui.indent(10)
        local pc; pc, is_hk_settings.use_pad_modifier = imgui.checkbox("Use Modifier##is_pad_mod", is_hk_settings.use_pad_modifier); wc = wc or pc
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Require holding this button while pressing toggle")
        end
        imgui.same_line()
        hk_changed = hk.hotkey_setter("Pad SFPS Modifier") or hk_changed
        hk_changed = hk.hotkey_setter("Pad Standard FPS Toggle", is_hk_settings.use_pad_modifier and "Pad SFPS Modifier") or hk_changed
        imgui.unindent(10)
        imgui.unindent(10)
        imgui.separator()

        imgui.text_colored(" Arm rotation adjustment Toggle (rapid double-click):", 0xFFFFFFAA)
        imgui.indent(10)
        imgui.text("Keyboard and Mouse:")
        imgui.indent(10)
        local armc; armc, is_hk_settings.use_arm_rot_modifier = imgui.checkbox("Use Modifier##arm_rot_kb_mod", is_hk_settings.use_arm_rot_modifier); wc = wc or armc
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Require holding this button while pressing toggle")
        end
        imgui.same_line()
        hk_changed = hk.hotkey_setter("Arm Rotation Modifier") or hk_changed
        hk_changed = hk.hotkey_setter("Arm Rotation Toggle", is_hk_settings.use_arm_rot_modifier and "Arm Rotation Modifier") or hk_changed
        imgui.unindent(10)
        imgui.text("Gamepad:")
        imgui.indent(10)
        local armc2; armc2, is_hk_settings.use_pad_arm_rot_modifier = imgui.checkbox("Use Modifier##arm_rot_pad_mod", is_hk_settings.use_pad_arm_rot_modifier); wc = wc or armc2
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Require holding this button while pressing toggle")
        end
        imgui.same_line()
        hk_changed = hk.hotkey_setter("Pad Arm Rotation Modifier") or hk_changed
        hk_changed = hk.hotkey_setter("Pad Arm Rotation Toggle", is_hk_settings.use_pad_arm_rot_modifier and "Pad Arm Rotation Modifier") or hk_changed
        imgui.unindent(10)
        imgui.unindent(10)
        imgui.separator()

        imgui.text_colored(" Hold Animation Toggle:", 0xFFFFFFAA)
        imgui.indent(10)
        imgui.text("Keyboard and Mouse:")
        imgui.indent(10)
        local hmc; hmc, is_hk_settings.use_ha_modifier = imgui.checkbox("Use Modifier##ha_kb_mod", is_hk_settings.use_ha_modifier); wc = wc or hmc
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Require holding this button while pressing toggle")
        end
        imgui.same_line()
        hk_changed = hk.hotkey_setter("HA Modifier") or hk_changed
        hk_changed = hk.hotkey_setter("Hold Animation Toggle", is_hk_settings.use_ha_modifier and "HA Modifier") or hk_changed
        imgui.unindent(10)
        imgui.text("Gamepad:")
        imgui.indent(10)
        local hpc; hpc, is_hk_settings.use_pad_ha_modifier = imgui.checkbox("Use Modifier##ha_pad_mod", is_hk_settings.use_pad_ha_modifier); wc = wc or hpc
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Require holding this button while pressing toggle")
        end
        imgui.same_line()
        hk_changed = hk.hotkey_setter("Pad HA Modifier") or hk_changed
        hk_changed = hk.hotkey_setter("Pad Hold Animation Toggle", is_hk_settings.use_pad_ha_modifier and "Pad HA Modifier") or hk_changed
        imgui.unindent(10)
        local hta_c, hta_v = imgui.checkbox("Hold to Activate##ha_hta", prefs.ha_hold_to_activate)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("When checked, Hold Animation is only active while the hotkey is held down")
        end
        if hta_c then
            prefs.ha_hold_to_activate = hta_v
            save_prefs()
        end
        imgui.unindent(10)
        imgui.separator()

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
        imgui.spacing()
        imgui.spacing()
    end
end)
