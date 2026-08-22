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

local ui_state = {
    selected_index = 1,
    last_equipped_id = nil,
    copy_all_confirm = false,
    reset_confirm = false,
    edit_mode = 1
}
local EDIT_MODE_LABELS = { "Normal", "Cover Right", "Cover Left", "Standard FPS" }
local EDIT_MODE_COVER_STATE = { nil, "CoverActionRight", "CoverActionLeft", "StandardFPS" }

-- Per-weapon offsets: { ["arm0000"] = { x=0, y=0, z=0 }, ... }
local DEFAULT_OFFSETS = {
    ["arm0000"]       = { x =  0.0,    y = -0.037, z = 0.0 },
    ["arm0001"]       = { x =  0.0,    y = -0.021, z = 0.0 },
    ["arm0003"]       = { x =  0.0,    y = -0.032, z = 0.0 },
    ["arm0004"]       = { x =  0.0,    y = -0.020, z = 0.0 },
    ["arm0005"]       = { x = -0.002,  y = -0.050, z = 0.0 },
    ["arm0006"]       = { x = -0.001,  y = -0.037, z = 0.0 },
    ["arm0007"]       = { x =  0.0,    y = -0.039, z = 0.0 },
    ["arm0100"]       = { x =  0.0,    y = -0.071, z = 0.0 },
    ["arm0103"]       = { x =  0.0,    y = -0.066, z = 0.0 },
    ["arm0104"]       = { x =  0.0,    y = -0.068, z = 0.0 },
    ["arm0400_leon"]  = { x = -0.002,  y = -0.040, z = 0.0 },
    ["arm0400_grace"] = { x =  0.001,  y = -0.036, z = 0.0 },
    ["arm0500"]       = { x =  0.0005, y = -0.059, z = 0.0 },
    ["arm0501"]       = { x =  0.0,    y = -0.044, z = 0.0 },
    ["arm0503"]       = { x = -0.045,  y = -0.026, z = 0.0 },
    ["arm0505"]       = { x =  0.001,    y = -0.0420, z = 0.0 },
    ["arm0600"]       = { x =  0.0,    y = -0.064, z = 0.0 },
    ["arm0601"]       = { x =  -0.0005,    y = -0.048, z = 0.0 },
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
    ["arm0400_grace|CoverActionRight"] = { x = -0.015, y = -0.023, z = 0.0 },
    ["arm0400_grace|CoverActionLeft"]  = { x =  0.014, y = -0.026, z = 0.0 },
    ["arm0500|CoverActionRight"] = { x = -0.019, y = -0.059, z = 0.0 },
    ["arm0500|CoverActionLeft"]  = { x =  0.019, y = -0.059, z = 0.0 },
    ["arm0501|CoverActionRight"] = { x = -0.014, y = -0.065, z = 0.0 },
    ["arm0501|CoverActionLeft"]  = { x =  0.014, y = -0.065, z = 0.0 },
    ["arm0505|CoverActionRight"] = { x = -0.019, y = -0.033, z = 0.0 },
    ["arm0505|CoverActionLeft"]  = { x =  0.019, y = -0.033, z = 0.0 },
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

--- Saved value, or bundled default (for UI / first edit before key exists in JSON).
local function effective_cover_offset(weapon_key, cover_state)
    local o = get_cover_offset(weapon_key, cover_state)
    if o then return o end
    return DEFAULT_COVER_OFFSETS[weapon_key .. "|" .. cover_state]
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

-- Arm hand/lower/upper rotation per weapon (Euler degrees X,Y,Z for right hand; left mirrors)
-- Hardcoded defaults from arm_hand_rotation.json (used when no saved file or missing keys)
local DEFAULT_CANTED_OFFSETS = {
    arm0000       = { arm_hand_rotation = { x = 18.0,  y = -19.5, z = -4.5 },  arm_lower_rotation = { x = -12.0, y = 12.5,  z = -2.0 }, arm_upper_rotation = { x = 10.5, y = -6.0,  z = 4.5 } },
    arm0001       = { arm_hand_rotation = { x = 24.0,  y = 4.0,   z = -8.5 },  arm_lower_rotation = { x = 13.0,  y = -4.5,  z = 0.0 },  arm_upper_rotation = { x = 0.0,  y = 0.0,   z = 0.0 } },
    arm0003       = { arm_hand_rotation = { x = 18.0,  y = -19.5, z = -4.5 },  arm_lower_rotation = { x = -12.0, y = 12.5,  z = -2.0 }, arm_upper_rotation = { x = 10.5, y = -6.0,  z = 4.5 } },
    arm0004       = { arm_hand_rotation = { x = 24.0,  y = 4.0,   z = -8.5 },  arm_lower_rotation = { x = 13.0,  y = -4.5,  z = 0.0 },  arm_upper_rotation = { x = 0.0,  y = 0.0,   z = 0.0 } },
    arm0005       = { arm_hand_rotation = { x = 18.0,  y = -19.5, z = -4.5 },  arm_lower_rotation = { x = -9.5,  y = 13.5,  z = -2.0 }, arm_upper_rotation = { x = 10.5, y = -6.0,  z = 4.5 } },
    arm0006       = { arm_hand_rotation = { x = 18.0,  y = -19.5, z = -4.5 },  arm_lower_rotation = { x = -12.0, y = 12.5,  z = -2.0 }, arm_upper_rotation = { x = 10.5, y = -6.0,  z = 4.5 } },
    arm0007       = { arm_hand_rotation = { x = 18.0,  y = -19.5, z = -4.5 },  arm_lower_rotation = { x = -12.0, y = 12.5,  z = -2.0 }, arm_upper_rotation = { x = 10.5, y = -6.0,  z = 4.5 } },
    arm0100       = { arm_hand_rotation = { x = 18.0,  y = -19.5, z = -4.5 },  arm_lower_rotation = { x = -6.5,  y = 12.5,  z = -5.5 }, arm_upper_rotation = { x = -6.0,  y = -3.5,  z = 0.0 } },
    arm0103       = { arm_hand_rotation = { x = 18.0,  y = -19.5, z = -4.5 },  arm_lower_rotation = { x = -6.5,  y = 12.5,  z = -5.5 }, arm_upper_rotation = { x = -6.0,  y = -3.5,  z = 0.0 } },
    arm0104       = { arm_hand_rotation = { x = 18.0,  y = -19.5, z = -4.5 },  arm_lower_rotation = { x = -6.5,  y = 12.5,  z = -5.5 }, arm_upper_rotation = { x = -6.0,  y = -3.5,  z = 0.0 } },
    arm0400_leon  = { arm_hand_rotation = { x = 26.0,  y = -8.0,  z = -21.5 }, arm_lower_rotation = { x = 16.0,  y = 10.0,  z = 4.5 },  arm_upper_rotation = { x = 0.0,  y = 0.0,   z = 0.0 } },
    arm0400_grace = { arm_hand_rotation = { x = 26.0,  y = -8.0,  z = -21.5 }, arm_lower_rotation = { x = 16.0,  y = 10.0,  z = 4.5 },  arm_upper_rotation = { x = 0.0,  y = 0.0,   z = 0.0 } },
    arm0500       = { arm_hand_rotation = { x = 26.0,  y = -8.0,  z = -21.5 }, arm_lower_rotation = { x = 16.0,  y = 10.0,  z = 4.5 },  arm_upper_rotation = { x = 0.0,  y = 0.0,   z = 0.0 } },
    arm0501       = { arm_hand_rotation = { x = 20.0,  y = -5.5,  z = -22.0 }, arm_lower_rotation = { x = 16.0,  y = 10.0,  z = 4.5 },  arm_upper_rotation = { x = 0.0,  y = 0.0,   z = 0.0 } },
    arm0503       = { arm_hand_rotation = { x = 18.0,  y = -19.5, z = -4.5 },  arm_lower_rotation = { x = -7.5,  y = 6.0,   z = 1.0 },  arm_upper_rotation = { x = 0.0,  y = 0.0,   z = 0.0 } },
    arm0505       = { arm_hand_rotation = { x = 23.5,  y = 6.5,   z = -7.0 },  arm_lower_rotation = { x = 16.0,  y = -5.5,  z = -1.5 }, arm_upper_rotation = { x = 0.0,  y = 0.0,   z = 0.0 } },
    arm0600       = { arm_hand_rotation = { x = 31.0,  y = -2.0,  z = 3.5 },  arm_lower_rotation = { x = 0,  y = 0,  z = 0 }, arm_upper_rotation = { x = 0,  y = 0,  z = 0 } },
    arm0601       = { arm_hand_rotation = { x = 31.0,  y = -1.0,  z = 3.5 },  arm_lower_rotation = { x = 0,  y = 0,  z = 0 }, arm_upper_rotation = { x = 0,  y = 0,  z = 0 } },
    arm0700       = { arm_hand_rotation = { x = 0.0,  y = 0.0,  z = 0.0 }, arm_lower_rotation = { x = 0.0,  y = 0.0,  z = 0.0 },  arm_upper_rotation = { x = 0.0,  y = 0.0,   z = 0.0 } },
}
local arm_hand_rotations = {}
local arm_lower_rotations = {}
local arm_upper_rotations = {}

local function get_arm_hand_rotation(weapon_key)
    local t = arm_hand_rotations[weapon_key]
    if not t then return { x = 0.0, y = 0.0, z = 0.0 } end
    return { x = t.x or 0.0, y = t.y or 0.0, z = t.z or 0.0 }
end
local function get_arm_lower_rotation(weapon_key)
    local t = arm_lower_rotations[weapon_key]
    if not t then return { x = 0.0, y = 0.0, z = 0.0 } end
    return { x = t.x or 0.0, y = t.y or 0.0, z = t.z or 0.0 }
end
local function get_arm_upper_rotation(weapon_key)
    local t = arm_upper_rotations[weapon_key]
    if not t then return { x = 0.0, y = 0.0, z = 0.0 } end
    return { x = t.x or 0.0, y = t.y or 0.0, z = t.z or 0.0 }
end

local function set_arm_hand_rotation(weapon_key, x, y, z)
    arm_hand_rotations[weapon_key] = { x = x, y = y, z = z }
end
local function set_arm_lower_rotation(weapon_key, x, y, z)
    arm_lower_rotations[weapon_key] = { x = x, y = y, z = z }
end
local function set_arm_upper_rotation(weapon_key, x, y, z)
    arm_upper_rotations[weapon_key] = { x = x, y = y, z = z }
end

-- Per-weapon hand/finger joint rotations, keyed by the joint's OWN name. Unlike the three arm
-- joints above there is no right-authored/left-mirrored pairing here: the left hand is the
-- support hand and grips a completely different part of the weapon, so every joint carries its
-- own X/Y/Z. Joint names are discovered from the live skeleton (see collect_finger_joints), never
-- hardcoded, so this works for whatever the model actually ships.
local finger_rotations = {}
-- Set whenever the values or the resolved joints change; the apply path recompiles its list.
local finger_apply_dirty = true
local _fj_m4a1_sig = ""   -- last published finger values baked into _fj_list

local function get_finger_rotation(weapon_key, joint_name)
    -- Same override, one level deeper: the publishing mod names the joints it
    -- owns, so a joint it does not mention still comes from the json.
    local o = rawget(_G, "M4A1_ArmPose")
    if type(o) == "table" and o.key == weapon_key and type(o.fingers) == "table" then
        local ft = o.fingers[joint_name]
        if type(ft) == "table" then
            return { x = ft.x or 0.0, y = ft.y or 0.0, z = ft.z or 0.0 }
        end
    end
    local w = weapon_key and finger_rotations[weapon_key]
    local t = w and w[joint_name]
    if not t then return { x = 0.0, y = 0.0, z = 0.0 } end
    return { x = t.x or 0.0, y = t.y or 0.0, z = t.z or 0.0 }
end

local function set_finger_rotation(weapon_key, joint_name, x, y, z)
    if not weapon_key or not joint_name then return end
    local w = finger_rotations[weapon_key]
    if not w then w = {}; finger_rotations[weapon_key] = w end
    -- Drop back to nil at zero so untouched joints never reach the save file or the apply list
    if math.abs(x) < 0.0001 and math.abs(y) < 0.0001 and math.abs(z) < 0.0001 then
        w[joint_name] = nil
    else
        w[joint_name] = { x = x, y = y, z = z }
    end
    finger_apply_dirty = true
end

local function clear_finger_rotations(weapon_key, name_filter)
    local w = weapon_key and finger_rotations[weapon_key]
    if not w then return end
    for jname in pairs(w) do
        if not name_filter or name_filter[jname] then w[jname] = nil end
    end
    finger_apply_dirty = true
end

local function save_arm_hand_rotation()
    finger_apply_dirty = true
    if _ah_off_cache_valid ~= nil then _ah_off_cache_valid = false end
    local out = {}
    local keys = {}
    for k in pairs(arm_hand_rotations) do keys[k] = true end
    for k in pairs(arm_lower_rotations) do keys[k] = true end
    for k in pairs(arm_upper_rotations) do keys[k] = true end
    for k in pairs(finger_rotations) do keys[k] = true end
    for wkey in pairs(keys) do
        local h = arm_hand_rotations[wkey] or { x = 0, y = 0, z = 0 }
        local l = arm_lower_rotations[wkey] or { x = 0, y = 0, z = 0 }
        local u = arm_upper_rotations[wkey] or { x = 0, y = 0, z = 0 }
        out[wkey] = { arm_hand_rotation = h, arm_lower_rotation = l, arm_upper_rotation = u }
        local f = finger_rotations[wkey]
        if f and next(f) ~= nil then out[wkey].finger_rotations = f end
    end
    json.dump_file(ARM_HAND_SETTINGS_PATH, out)
end

local function load_arm_hand_rotation()
    -- Apply hardcoded defaults first
    for wkey, def in pairs(DEFAULT_CANTED_OFFSETS) do
        if def.arm_hand_rotation then
            arm_hand_rotations[wkey] = { x = def.arm_hand_rotation.x or 0, y = def.arm_hand_rotation.y or 0, z = def.arm_hand_rotation.z or 0 }
        end
        if def.arm_lower_rotation then
            arm_lower_rotations[wkey] = { x = def.arm_lower_rotation.x or 0, y = def.arm_lower_rotation.y or 0, z = def.arm_lower_rotation.z or 0 }
        end
        if def.arm_upper_rotation then
            arm_upper_rotations[wkey] = { x = def.arm_upper_rotation.x or 0, y = def.arm_upper_rotation.y or 0, z = def.arm_upper_rotation.z or 0 }
        end
    end
    local saved = json.load_file(ARM_HAND_SETTINGS_PATH)
    if not saved or type(saved) ~= "table" then return end
    -- Legacy: top-level arm_hand_rotation / arm_lower_rotation / arm_upper_rotation (no per-weapon key like "arm0000")
    local has_per_weapon = saved["arm0000"] and type(saved["arm0000"]) == "table"
    local has_legacy_top = (saved.arm_hand_rotation and type(saved.arm_hand_rotation) == "table") or (type(saved.x) == "number")
    if has_legacy_top and not has_per_weapon then
        local h = saved.arm_hand_rotation and type(saved.arm_hand_rotation) == "table" and saved.arm_hand_rotation or { x = saved.x or 0, y = saved.y or 0, z = saved.z or 0 }
        local l = saved.arm_lower_rotation and type(saved.arm_lower_rotation) == "table" and saved.arm_lower_rotation or { x = 0, y = 0, z = 0 }
        local u = saved.arm_upper_rotation and type(saved.arm_upper_rotation) == "table" and saved.arm_upper_rotation or { x = 0, y = 0, z = 0 }
        h.x = type(h.x) == "number" and h.x or 0; h.y = type(h.y) == "number" and h.y or 0; h.z = type(h.z) == "number" and h.z or 0
        l.x = type(l.x) == "number" and l.x or 0; l.y = type(l.y) == "number" and l.y or 0; l.z = type(l.z) == "number" and l.z or 0
        u.x = type(u.x) == "number" and u.x or 0; u.y = type(u.y) == "number" and u.y or 0; u.z = type(u.z) == "number" and u.z or 0
        for _, key in ipairs(dropdown_items) do
            arm_hand_rotations[key] = { x = h.x, y = h.y, z = h.z }
            arm_lower_rotations[key] = { x = l.x, y = l.y, z = l.z }
            arm_upper_rotations[key] = { x = u.x, y = u.y, z = u.z }
        end
        save_arm_hand_rotation()
        return
    end
    -- Overlay saved per-weapon entries on top of defaults
    for wkey, entry in pairs(saved) do
        if type(entry) == "table" and type(wkey) == "string" then
            if entry.arm_hand_rotation and type(entry.arm_hand_rotation) == "table" then
                local h = entry.arm_hand_rotation
                arm_hand_rotations[wkey] = { x = type(h.x) == "number" and h.x or 0, y = type(h.y) == "number" and h.y or 0, z = type(h.z) == "number" and h.z or 0 }
            end
            if entry.arm_lower_rotation and type(entry.arm_lower_rotation) == "table" then
                local l = entry.arm_lower_rotation
                arm_lower_rotations[wkey] = { x = type(l.x) == "number" and l.x or 0, y = type(l.y) == "number" and l.y or 0, z = type(l.z) == "number" and l.z or 0 }
            end
            if entry.arm_upper_rotation and type(entry.arm_upper_rotation) == "table" then
                local u = entry.arm_upper_rotation
                arm_upper_rotations[wkey] = { x = type(u.x) == "number" and u.x or 0, y = type(u.y) == "number" and u.y or 0, z = type(u.z) == "number" and u.z or 0 }
            end
            if entry.finger_rotations and type(entry.finger_rotations) == "table" then
                local dst = {}
                for jname, r in pairs(entry.finger_rotations) do
                    if type(jname) == "string" and type(r) == "table" then
                        local fx = type(r.x) == "number" and r.x or 0
                        local fy = type(r.y) == "number" and r.y or 0
                        local fz = type(r.z) == "number" and r.z or 0
                        if fx ~= 0 or fy ~= 0 or fz ~= 0 then
                            dst[jname] = { x = fx, y = fy, z = fz }
                        end
                    end
                end
                if next(dst) ~= nil then finger_rotations[wkey] = dst end
            end
        end
    end
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

-- Rotation table is { x, y, z } in degrees (right hand; left mirrors X and Z)
local function arm_hand_offset_quat_r(rot)
    return euler_deg_to_quat(rot.x, rot.y, rot.z)
end
local function arm_hand_offset_quat_l(rot)
    return euler_deg_to_quat(-rot.x, rot.y, -rot.z)
end
local function arm_lower_offset_quat_r(rot)
    return euler_deg_to_quat(rot.x, rot.y, rot.z)
end
local function arm_lower_offset_quat_l(rot)
    return euler_deg_to_quat(-rot.x, rot.y, -rot.z)
end
local function arm_upper_offset_quat_r(rot)
    return euler_deg_to_quat(rot.x, rot.y, rot.z)
end
local function arm_upper_offset_quat_l(rot)
    return euler_deg_to_quat(-rot.x, rot.y, -rot.z)
end

local prefs = { hide_reticle = true, bullet_from_muzzle = true, muzzle_all_views = false, transition_in = 0.15, transition_out = 1.0, transition_swap = 0.5, standard_fps_mode = false, zero_min_fit_rate = false, sfps_disable_ads_snipers = true, muzzle_disable_ads_snipers = true, auto_iron_sight = true, canted_aim_enabled = false, canted_aim_toggle_double_press_kb = false, canted_aim_toggle_double_press_pad = true, canted_aim_transition_in = 0.15, canted_aim_transition_out = 0.2, canted_aim_spring_k = 1000.0, canted_aim_spring_d = 20.0, canted_aim_wobble = true, canted_aim_wobble_in = true, canted_aim_wobble_amplitude = 0.04, canted_aim_wobble_frequency = 21.0, canted_aim_wobble_damping = 6.3, canted_aim_wobble_duration = 1.6, pose_ignore_canted = false, sfps_wobble_amplitude = 0.007, sfps_wobble_forward_amplitude = 0.007, sfps_wobble_frequency = 23.5, sfps_wobble_damping = 7.5, sfps_wobble_duration = 0.85 }
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
        if saved.sfps_wobble_amplitude ~= nil then prefs.sfps_wobble_amplitude = saved.sfps_wobble_amplitude end
        if saved.sfps_wobble_forward_amplitude ~= nil then prefs.sfps_wobble_forward_amplitude = saved.sfps_wobble_forward_amplitude end
        if saved.sfps_wobble_frequency ~= nil then prefs.sfps_wobble_frequency = saved.sfps_wobble_frequency end
        if saved.sfps_wobble_damping ~= nil then prefs.sfps_wobble_damping = saved.sfps_wobble_damping end
        if saved.sfps_wobble_duration ~= nil then prefs.sfps_wobble_duration = saved.sfps_wobble_duration end
        -- Breath-hold prefs moved to re9holdbreath (its own prefs.json); it owns them now.
        if saved.zero_min_fit_rate ~= nil then prefs.zero_min_fit_rate = saved.zero_min_fit_rate end
        if saved.sfps_disable_ads_snipers ~= nil then prefs.sfps_disable_ads_snipers = saved.sfps_disable_ads_snipers end
        if saved.muzzle_disable_ads_snipers ~= nil then prefs.muzzle_disable_ads_snipers = saved.muzzle_disable_ads_snipers end
        if saved.auto_iron_sight ~= nil then prefs.auto_iron_sight = saved.auto_iron_sight end
        if saved.canted_aim_enabled ~= nil then prefs.canted_aim_enabled = saved.canted_aim_enabled end
        if saved.pose_ignore_canted ~= nil then prefs.pose_ignore_canted = saved.pose_ignore_canted end
        if saved.canted_aim_toggle_double_press_kb ~= nil then prefs.canted_aim_toggle_double_press_kb = saved.canted_aim_toggle_double_press_kb end
        if saved.canted_aim_toggle_double_press_pad ~= nil then prefs.canted_aim_toggle_double_press_pad = saved.canted_aim_toggle_double_press_pad end
        if saved.canted_aim_transition_in ~= nil then prefs.canted_aim_transition_in = saved.canted_aim_transition_in end
        if saved.canted_aim_transition_out ~= nil then prefs.canted_aim_transition_out = saved.canted_aim_transition_out end
        if saved.canted_aim_spring_k ~= nil then prefs.canted_aim_spring_k = saved.canted_aim_spring_k end
        if saved.canted_aim_spring_d ~= nil then prefs.canted_aim_spring_d = saved.canted_aim_spring_d end
        if saved.canted_aim_wobble ~= nil then prefs.canted_aim_wobble = saved.canted_aim_wobble end
        if saved.canted_aim_wobble_in ~= nil then prefs.canted_aim_wobble_in = saved.canted_aim_wobble_in end
        if saved.canted_aim_wobble_amplitude ~= nil then prefs.canted_aim_wobble_amplitude = saved.canted_aim_wobble_amplitude end
        if saved.canted_aim_wobble_frequency ~= nil then prefs.canted_aim_wobble_frequency = saved.canted_aim_wobble_frequency end
        if saved.canted_aim_wobble_damping ~= nil then prefs.canted_aim_wobble_damping = saved.canted_aim_wobble_damping end
        if saved.canted_aim_wobble_duration ~= nil then prefs.canted_aim_wobble_duration = saved.canted_aim_wobble_duration end
    end
end
local function save_prefs()
    json.dump_file(PREFS_PATH, prefs)
end


-- PlayerEquipment / CameraPosSetting / Cp_A*InputDriver types dropped: that state now comes
-- from the shared re9holdbreath cache.
local TYPE_Cp_A000Updater = sdk.typeof("app.Cp_A000Updater")
local TYPE_Cp_A100Updater = sdk.typeof("app.Cp_A100Updater")
local TYPE_PlayerFPSCameraController = sdk.typeof("app.PlayerFPSCameraController")
local TYPE_BodyAddCtrlDriver = sdk.typeof("app.BodyAddCtrlDriver")


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
        o = effective_cover_offset(key, cover_state)
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
local CANTED_AIM_TRANSITION_IN = prefs.canted_aim_transition_in
local CANTED_AIM_TRANSITION_OUT = prefs.canted_aim_transition_out

local transition = {
    from_x = 0.0, from_y = 0.0, from_z = 0.0,
    to_x = 0.0, to_y = 0.0, to_z = 0.0,
    cur_x = 0.0, cur_y = 0.0, cur_z = 0.0,
    t = 1.0,
    duration = TRANSITION_IN,
    last_weapon_id = nil,
    last_time = os.clock(),
}

-- Damped sine wobble on camera offset after Standard FPS mode toggle (same formula as canted aim).
-- prefs.sfps_wobble_amplitude scales motion along the offset delta (UI: side-to-side); sfps_wobble_forward_amplitude adds Z-only term.
local sfps_cam_wobble = {
    active = false,
    wobble_after_lerp = false,
    start_time = 0.0,
    settle_x = 0.0, settle_y = 0.0, settle_z = 0.0,
    dir_x = 1.0, dir_y = 0.0, dir_z = 0.0,
}

local function transition_set_target(tx, ty, tz, override_duration, arm_sfps_wobble)
    if tx == transition.to_x and ty == transition.to_y and tz == transition.to_z then return end
    sfps_cam_wobble.active = false
    sfps_cam_wobble.wobble_after_lerp = false
    if arm_sfps_wobble then
        local dx = tx - transition.cur_x
        local dy = ty - transition.cur_y
        local dz = tz - transition.cur_z
        local len_sq = dx * dx + dy * dy + dz * dz
        if len_sq > 1e-12 then
            local inv = 1.0 / math.sqrt(len_sq)
            sfps_cam_wobble.dir_x = dx * inv
            sfps_cam_wobble.dir_y = dy * inv
            sfps_cam_wobble.dir_z = dz * inv
            sfps_cam_wobble.wobble_after_lerp = true
        end
    end
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

-- Damped spring for canted aim blend: overshoot, wobble a bit, then settle (tunable via sliders)
local CANTED_AIM_SPRING_K = prefs.canted_aim_spring_k
local CANTED_AIM_SPRING_D = prefs.canted_aim_spring_d
local CANTED_AIM_BLEND_CLAMP_LO = -0.22
local CANTED_AIM_BLEND_CLAMP_HI = 1.22
local CANTED_AIM_SETTLE_THRESH = 0.002
local CANTED_AIM_VEL_THRESH = 0.015
-- Initial velocity when handing off to spring: smaller for transition-in so wobble into canted is gentler
local CANTED_AIM_WOBBLE_VEL_IN = 2.0
local CANTED_AIM_WOBBLE_VEL_OUT = 5.0

local function transition_update()
    local now = os.clock()
    local dt = now - transition.last_time
    transition.last_time = now

    if transition.t >= 1.0 then
        transition.cur_x = transition.to_x
        transition.cur_y = transition.to_y
        transition.cur_z = transition.to_z
        if sfps_cam_wobble.wobble_after_lerp then
            sfps_cam_wobble.wobble_after_lerp = false
            local amp0 = prefs.sfps_wobble_amplitude or 0.007
            local amp_fwd0 = prefs.sfps_wobble_forward_amplitude or 0.007
            if amp0 > 1e-8 or amp_fwd0 > 1e-8 then
                sfps_cam_wobble.active = true
                sfps_cam_wobble.start_time = now
                sfps_cam_wobble.settle_x = transition.to_x
                sfps_cam_wobble.settle_y = transition.to_y
                sfps_cam_wobble.settle_z = transition.to_z
            end
        end
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

-- RE9Laser publishes this while its master Enabled gate is on (for EVERY laser style, Vanilla
-- included). When it's active, RE9Laser owns bullet spawn entirely — its bundled muzzle fix
-- rewrites the shell transform — so we run NONE of our own muzzle-spawn code and let it decide,
-- rather than both mods rewriting the same shell transform. It also owns the reticle: our
-- reticle hiding would take the laser dot down with it (the dot draws through Gui_ui2020), so
-- while the laser is active we never hide and the two options are removed from the menu.
-- Checked at runtime (not load) since script load order isn't guaranteed.
local function re9_laser_active()
    return rawget(_G, "RE9Laser_Active") == true
end

-- Reticle hiding
local hide_reticle = prefs.hide_reticle
local cached_view_mode = -1
local cached_body_view_mode = -1
local PLAYER_MODE_FPS = 1
local PLAYER_MODE_TPS = 0
local cached_game_paused = false

local function is_tps_view()
    if cached_body_view_mode == PLAYER_MODE_TPS then return true end
    if cached_view_mode == PLAYER_MODE_TPS then return true end
    return cached_view_mode >= 0 and cached_view_mode ~= PLAYER_MODE_FPS
end

local function is_fps_view()
    return cached_view_mode == PLAYER_MODE_FPS
end


local reticle_names = {
    "Gui_ui2020"
}
for i, v in ipairs(reticle_names) do
    reticle_names[v] = true
end

re.on_pre_gui_draw_element(function(element, context)
    -- RE9Laser active: never veto the reticle draw. Its laser dot renders through the same
    -- Gui_ui2020 element, so hiding the reticle would hide the dot too.
    if re9_laser_active() then return true end
    -- Scope overlay up (M4A1's ACOG): the optic IS the sight picture, and the crosshair drawn
    -- inside it is the game's own - so iron-sight mode must not take it away. Whether the
    -- crosshair belongs there at all is that mod's call (it has its own hide option); this only
    -- stops a second, independent hide fighting it. Published every frame, false when absent.
    if _G.M4A1_ScopeOverlayVisible == true then return true end
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

-- RE93DCrosshair sets this global when installed. While it is present we force bullet-from-
-- muzzle on so shots line up with its world-space crosshair. Checked at runtime (not load)
-- because script load order isn't guaranteed.
local function re9_3d_crosshair_active()
    return rawget(_G, "__re93dcrosshair_installed") == true
end
-- Shared muzzle bullet-spawn module (bundled under muzzlebulletspawn/). ALL muzzle-spawn logic
-- lives there now — the same file RE9Laser uses — so this mod no longer carries its own copy of
-- the muzzle-joint lookup + shell-transform rewrite; it just drives the module's enable (see the
-- UpdateBehavior below). require caches by path, so if RE9Laser is also loaded both share ONE
-- module instance and one set of hooks.
local muzzlefix = require("muzzlebulletspawn/muzzlebulletspawn")

local function muzzle_safe_call(obj, method, ...)
    if not obj then return nil end
    local ok, result = pcall(obj.call, obj, method, ...)
    return ok and result or nil
end

-- Arm hand and arm lower joints: cache and resolve from player character
local arm_hand_cached_player_go = nil
local joints = {
    r_arm_hand = nil,
    l_arm_hand = nil,
    r_arm_lower = nil,
    l_arm_lower = nil,
    r_arm_upper = nil,
    l_arm_upper = nil
}

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

-- Hand/finger joints: everything that descends from R_Arm_Hand / L_Arm_Hand in the skeleton.
-- Discovered by walking the transform's whole joint array once per player spawn (same cache
-- lifetime as the six arm joints above) instead of hardcoding a name list, so this still finds
-- the fingers on a swapped-in weapon/arm model.
local finger_joints = { r = {}, l = {} }  -- ordered { name = , joint = } per side, sorted by name
local finger_joint_by_name = {}
local finger_joints_generation = 0  -- bumped per scan; the apply list recompiles off this
local FINGER_PARENT_WALK_MAX = 8

local function collect_finger_joints(xform_r, xform_l)
    finger_joints.r = {}
    finger_joints.l = {}
    finger_joint_by_name = {}
    finger_joints_generation = finger_joints_generation + 1

    local by_name, parent_of, order = {}, {}, {}

    local function scan(xform)
        if not xform then return end
        local arr = muzzle_safe_call(xform, "get_Joints")
        if not arr then return end
        local list
        local ok_e, elems = pcall(arr.get_elements, arr)
        if ok_e and type(elems) == "table" then
            list = elems
        else
            list = {}
            local ok_n, n = pcall(arr.get_size, arr)
            if not ok_n or type(n) ~= "number" then return end
            for i = 0, n - 1 do
                local ok_j, j = pcall(arr.get_element, arr, i)
                if ok_j and j then list[#list + 1] = j end
            end
        end
        -- One get_Parent per joint here; the ancestry walk below is then pure string lookups
        for i = 1, #list do
            local j = list[i]
            local name = muzzle_safe_call(j, "get_Name")
            if type(name) == "string" and name ~= "" and not by_name[name] then
                by_name[name] = j
                order[#order + 1] = name
                local p = muzzle_safe_call(j, "get_Parent")
                local pname = p and muzzle_safe_call(p, "get_Name")
                if type(pname) == "string" and pname ~= "" then parent_of[name] = pname end
            end
        end
    end

    scan(xform_r)
    scan(xform_l)

    for i = 1, #order do
        local name = order[i]
        local cur, depth = parent_of[name], 0
        while cur and depth < FINGER_PARENT_WALK_MAX do
            local side = (cur == "R_Arm_Hand" and finger_joints.r)
                or (cur == "L_Arm_Hand" and finger_joints.l)
            if side then
                side[#side + 1] = { name = name, joint = by_name[name] }
                finger_joint_by_name[name] = by_name[name]
                break
            end
            cur = parent_of[cur]
            depth = depth + 1
        end
    end

    local function by_joint_name(a, b) return a.name < b.name end
    table.sort(finger_joints.r, by_joint_name)
    table.sort(finger_joints.l, by_joint_name)
end

local arm_hand_last_resolve_time = 0
local ARM_HAND_RESOLVE_INTERVAL = 0.2  -- only re-resolve when cache valid every 0.2s to cut SDK calls

local arm_hand_resolved_view_mode = -1

local function resolve_arm_hand_joints()
    local now = os.clock()
    -- First and third person can be driven by different models, so a view flip has to re-scan
    -- (the player GameObject compare below would not catch it on its own).
    if cached_view_mode ~= arm_hand_resolved_view_mode then
        arm_hand_resolved_view_mode = cached_view_mode
        arm_hand_cached_player_go = nil
    elseif arm_hand_cached_player_go and (now - arm_hand_last_resolve_time) < ARM_HAND_RESOLVE_INTERVAL then
        return  -- cache valid and not stale: skip SDK calls this frame
    end
    local char_mgr = sdk.get_managed_singleton("app.CharacterManager")
    if not char_mgr then return end
    local ctx = muzzle_safe_call(char_mgr, "get_PlayerContextFast")
    if not ctx then return end
    local player_go = muzzle_safe_call(ctx, "get_GameObject")
    if not player_go then return end

    if player_go ~= arm_hand_cached_player_go then
        joints.r_arm_hand = nil
        joints.l_arm_hand = nil
        joints.r_arm_lower = nil
        joints.l_arm_lower = nil
        joints.r_arm_upper = nil
        joints.l_arm_upper = nil
        arm_hand_cached_player_go = nil
        local xform = muzzle_safe_call(player_go, "get_Transform")
        if xform then
            joints.r_arm_hand = find_transform_with_joint(xform, "R_Arm_Hand")
            joints.l_arm_hand = find_transform_with_joint(xform, "L_Arm_Hand")
            joints.r_arm_lower = find_transform_with_joint(xform, "R_Arm_Lower")
            joints.l_arm_lower = find_transform_with_joint(xform, "L_Arm_Lower")
            joints.r_arm_upper = find_transform_with_joint(xform, "R_Arm_Upper")
            joints.l_arm_upper = find_transform_with_joint(xform, "L_Arm_Upper")
            -- The hand joints can live on a child transform (find_transform_with_joint walks the
            -- child chain), so scan from whichever transform actually owns them, not from xform.
            collect_finger_joints(
                joints.r_arm_hand and muzzle_safe_call(joints.r_arm_hand, "get_Owner") or nil,
                joints.l_arm_hand and muzzle_safe_call(joints.l_arm_hand, "get_Owner") or nil
            )
            if joints.r_arm_hand or joints.l_arm_hand or joints.r_arm_lower or joints.l_arm_lower or joints.r_arm_upper or joints.l_arm_upper then
                arm_hand_cached_player_go = player_go
            end
        end
    end
    arm_hand_last_resolve_time = now
end

local _muzzle_ads_suppressed = false

re.on_pre_application_entry("UpdateBehavior", function()
    -- Drive the shared muzzle-fix module (muzzle spawn on, and first person unless "all views").
    -- Runs its first half even while RE9Laser is active — the forced flag feeds the LockScene
    -- publish — but only ONE mod ever calls set_enabled, so bail before it.
    if re9_3d_crosshair_active() then bullet_from_muzzle = true end
    local want = (bullet_from_muzzle or prefs.muzzle_all_views)
        and (prefs.muzzle_all_views or cached_view_mode == 1)
    if re9_laser_active() then return end
    muzzlefix.set_enabled(want == true)
end)

-- (The PlayerGun.trySetupShellTransform shell-transform rewrite now lives in the shared
-- muzzlebulletspawn module, driven by the enable above — no local hook here anymore.)

local STANDARD_FPS_X = -0.09
local TRANSITION_SFPS = 0.2
local TRANSITION_ADS = 0.2
-- Was the scope offset the target LAST frame? Raising or lowering an optic is an ADS move, but
-- with standard-FPS mode on it runs between two NON-ZERO offsets, which the duration picker
-- reads as a "swap" and gives TRANSITION_SWAP (0.5 s) -- two and a half times slower than an
-- ordinary ADS blend, and very obvious with a large scope offset. Remembering the previous frame
-- makes lowering the scope as quick as raising it, instead of only fixing one direction.
local scope_offset_prev = false
local standard_fps_mode = prefs.standard_fps_mode
local canted_aim_enabled = prefs.canted_aim_enabled
-- Set when Standard FPS mode is toggled (hotkey or UI); consumed in LockScene for transition duration + wobble
local pending_sfps_camera_event = false

local function sync_auto_iron_sight()
    -- RE9Laser owns the reticle while active; don't let auto mode force it hidden (that would
    -- take the laser dot with it).
    if re9_laser_active() then return end
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
local holdbreath = require("re9holdbreath/re9holdbreath")
local IS_HK_PATH = "IronSights/hotkeys.json"
local is_hk_default_settings = {
    use_modifier = false,
    use_pad_modifier = true,
    use_canted_aim_modifier = true,
    use_pad_canted_aim_modifier = true,
    use_ha_modifier = false,
    use_pad_ha_modifier = true,
    hotkeys = {
        ["SFPS Modifier"] = "R Mouse",
        ["Standard FPS Toggle"] = "EX0",
        ["Pad SFPS Modifier"] = "LT (L2)",
        ["Pad Standard FPS Toggle"] = "",
        ["Canted Aim Modifier"] = "R Mouse",
        ["Canted Aim Toggle"] = "Alt",
        ["Pad Canted Aim Modifier"] = "LT (L2)",
        ["Pad Canted Aim Toggle"] = "L3",
        ["HA Modifier"] = "",
        ["Hold Animation Toggle"] = "T",
        ["Pad HA Modifier"] = "LT (L2)",
        ["Pad Hold Animation Toggle"] = "L3",
    }
}
local is_hk_settings = hk.recurse_def_settings(json.load_file(IS_HK_PATH) or {}, is_hk_default_settings)
hk.setup_hotkeys(is_hk_settings.hotkeys, is_hk_default_settings.hotkeys)

local CANTED_AIM_DOUBLECLICK_WINDOW = 0.4
local canted_aim_state = {
    toggle_was_down_kb = false,
    toggle_was_down_pad = false,
    last_press_time_kb = 0,
    last_press_time_pad = 0,
    blend = canted_aim_enabled and 1.0 or 0.0,
    velocity = 0.0,
    prev_target = canted_aim_enabled and 1.0 or 0.0,
    in_transition = false,
    transition_start_time = 0.0,
    transition_start_blend = 0.0,
    blend_last_time = os.clock(),
    overshoot_active = false,
    overshoot_start_time = 0.0,
    overshoot_target = 0.0
}
local sfps_toggle_was_down = false
local ha_toggle_was_down = false

re.on_application_entry("UpdateBehavior", function()
    local kb = (not is_hk_settings.use_modifier or hk.check_hotkey("SFPS Modifier", true)) and hk.check_hotkey("Standard FPS Toggle", true)
    local pad = (not is_hk_settings.use_pad_modifier or hk.check_hotkey("Pad SFPS Modifier", true)) and hk.check_hotkey("Pad Standard FPS Toggle", true)
    local is_down = kb or pad
    -- PRESS COUNTER for other mods, on the raw EDGE of the IRON SIGHT hotkey
    -- (Standard FPS Toggle - modifier + key, e.g. L2 + Circle on a pad). A
    -- counter and not a state: M4A1 toggles its third-person scope overlay from
    -- this, and over the shoulder no pose STATE changes at all, so a press is
    -- the only signal that exists there. Published before the toggle body, so it
    -- counts the press itself rather than what the press did with it.
    if is_down and not sfps_toggle_was_down then
        _G.IronSights_IronPress = (rawget(_G, "IronSights_IronPress") or 0) + 1
        standard_fps_mode = not standard_fps_mode
        prefs.standard_fps_mode = standard_fps_mode
        save_prefs()
        pending_sfps_camera_event = true
        sync_auto_iron_sight()
    end
    sfps_toggle_was_down = is_down or false

    local ar_kb = (not is_hk_settings.use_canted_aim_modifier or hk.check_hotkey("Canted Aim Modifier", true)) and hk.check_hotkey("Canted Aim Toggle", true)
    local ar_pad = (not is_hk_settings.use_pad_canted_aim_modifier or hk.check_hotkey("Pad Canted Aim Modifier", true)) and hk.check_hotkey("Pad Canted Aim Toggle", true)
    local now = os.clock()
    if ar_kb and not canted_aim_state.toggle_was_down_kb then
        if prefs.canted_aim_toggle_double_press_kb then
            -- Both taps of the double press are handed to re9holdbreath as an engage
            -- deferral. The same key commonly carries the breath hold as well, and
            -- there each tap would engage the hold and its release tear the pinned
            -- frames down again, mid canted-swing — the judder. The module no-ops this
            -- unless the bindings really do collide, and holding the key past the
            -- window still engages the hold normally. See M.defer_engage.
            if canted_aim_state.last_press_time_kb > 0 and (now - canted_aim_state.last_press_time_kb) <= CANTED_AIM_DOUBLECLICK_WINDOW then
                canted_aim_enabled = not canted_aim_enabled
                prefs.canted_aim_enabled = canted_aim_enabled
                save_prefs()
                canted_aim_state.last_press_time_kb = 0
                holdbreath.defer_engage(CANTED_AIM_DOUBLECLICK_WINDOW + 0.05)
            else
                canted_aim_state.last_press_time_kb = now
                holdbreath.defer_engage(CANTED_AIM_DOUBLECLICK_WINDOW + 0.05)
            end
        else
            canted_aim_enabled = not canted_aim_enabled
            prefs.canted_aim_enabled = canted_aim_enabled
            save_prefs()
            canted_aim_state.last_press_time_kb = 0
        end
    end
    if ar_pad and not canted_aim_state.toggle_was_down_pad then
        if prefs.canted_aim_toggle_double_press_pad then
            -- Same deferral as the KB path above.
            if canted_aim_state.last_press_time_pad > 0 and (now - canted_aim_state.last_press_time_pad) <= CANTED_AIM_DOUBLECLICK_WINDOW then
                canted_aim_enabled = not canted_aim_enabled
                prefs.canted_aim_enabled = canted_aim_enabled
                save_prefs()
                canted_aim_state.last_press_time_pad = 0
                holdbreath.defer_engage(CANTED_AIM_DOUBLECLICK_WINDOW + 0.05)
            else
                canted_aim_state.last_press_time_pad = now
                holdbreath.defer_engage(CANTED_AIM_DOUBLECLICK_WINDOW + 0.05)
            end
        else
            canted_aim_enabled = not canted_aim_enabled
            prefs.canted_aim_enabled = canted_aim_enabled
            save_prefs()
            canted_aim_state.last_press_time_pad = 0
        end
    end
    canted_aim_state.toggle_was_down_kb = ar_kb or false
    canted_aim_state.toggle_was_down_pad = ar_pad or false

    -- Published for RE9Laser (which owns the reticle GUI while active): hide it while the FP
    -- camera is down the real sights — iron-sight mode, canted off. Unread when RE9Laser is
    -- absent; our own hide_reticle veto covers the standalone case.
    --
    -- A scope picture (M4A1's ACOG overlay) cancels it: the eye is down an OPTIC, not the iron
    -- sights, so the reticle is not redundant there. This matters beyond the crosshair — the
    -- laser DOT draws through that same element, so hiding it took the whole laser with it.
    _G.IronSights_HideGui = (cached_view_mode == 1)
        and (not standard_fps_mode)
        and (not canted_aim_enabled)
        and (_G.M4A1_ScopeOverlayVisible ~= true)
end)

local camera_offset_applied = false
local cached = {
    weapon_id = nil,
    character = nil,
    is_holding = false,
    fps_state = nil,
    busy_ads = false,
    is_hold_end_request = false,
    fire_active = false,
}

-- Blend (0..1) for applying canted offset; when hold flag is false we decay this so offset interpolates to zero instead of snapping
local ah_hold_apply_blend = 1.0
local ah_hold_apply_last_time = 0.0
local AH_HOLD_APPLY_RATE = 10.0  -- blend in/out over ~0.1s
-- Blend (0..1) for canted in cover; when in cover we decay so canted interpolates to zero instead of snapping
local ah_cover_apply_blend = 1.0
local AH_COVER_APPLY_RATE = 10.0  -- blend in/out over ~0.1s

local function get_player_context()
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    if not cm then return nil end
    local ok, ctx = pcall(cm.call, cm, "getPlayerContextRef")
    if ok then return ctx end
    return nil
end

-- (weapon-id resolution from a context lives in re9holdbreath now; we read its cache.)

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

-- IsPause lives on app.CameraControllerRoot as a property: use get_IsPause(), not get_field("_IsPause").
local function resolve_fps_player_camera_from_go(go)
    if not go then return nil end
    for _, updater_type in ipairs({ TYPE_Cp_A000Updater, TYPE_Cp_A100Updater }) do
        if updater_type then
            local ok_up, updater = pcall(go.call, go, "getComponent(System.Type)", updater_type)
            if ok_up and updater then
                local ok_cam, cam = pcall(updater.get_field, updater, "<FPSPlayerCamera>k__BackingField")
                if ok_cam and cam then return cam end
                break
            end
        end
    end
    if TYPE_PlayerFPSCameraController then
        local ok_comp, cam = pcall(go.call, go, "getComponent(System.Type)", TYPE_PlayerFPSCameraController)
        if ok_comp and cam then return cam end
    end
    return nil
end

local function read_fps_camera_is_pause(cam)
    if not cam then return false end
    local ok, v = pcall(cam.call, cam, "get_IsPause()")
    if ok and type(v) == "boolean" then
        return v
    end
    ok, v = pcall(cam.get_field, cam, "_IsPause")
    if ok and type(v) == "boolean" then
        return v
    end
    ok, v = pcall(cam.get_field, cam, "<IsPause>k__BackingField")
    if ok and type(v) == "boolean" then
        return v
    end
    return false
end

-- Only called from apply_arm_hand_rotation (after cheap checks) — avoids SDK work every LateUpdate.
local function refresh_cached_game_paused()
    local ctx = get_player_context()
    if not ctx then
        cached_game_paused = false
        return
    end
    local ok_go, go = pcall(ctx.call, ctx, "get_GameObject")
    if not ok_go or not go then
        cached_game_paused = false
        return
    end
    local cam = resolve_fps_player_camera_from_go(go)
    if not cam then
        cached_game_paused = false
        return
    end
    cached_game_paused = read_fps_camera_is_pause(cam)
end

re.on_pre_application_entry("LockScene", function()
    -- Player / weapon / view / ADS state comes from the shared re9holdbreath cache. That module
    -- is a require-cached singleton which already resolves this exact set once per frame, and its
    -- own pre-LockScene hook registered before this one (we require it above), so these are
    -- same-frame values -- this just stops us walking
    -- CharacterManager -> PlayerContext -> GameObject -> getComponent a second time every frame.
    -- Key semantics are identical: it applies the same get_offset_key/SHARED_WEAPONS rule.
    local s = holdbreath.get_state()
    cached_view_mode           = holdbreath.view_mode()
    cached_body_view_mode      = holdbreath.body_view_mode()
    cached.character           = s.character
    cached.weapon_id           = s.weapon_id
    cached.is_holding          = s.is_holding == true
    cached.fps_state           = s.fps_state
    cached.busy_ads            = s.busy_ads == true
    cached.is_hold_end_request = s.is_hold_end_request == true
    cached.fire_active         = s.fire_active == true
    if not holdbreath.has_player() then cached_game_paused = false end


    -- Scoped check comes from re9holdbreath (shared with RE9 Laser and muzzlebulletspawn). This
    -- used to read cached.busy_ads directly, which is transition-only: it suppressed on the way
    -- into the scope and then restored as soon as the blend settled, i.e. while you were actually
    -- aiming through it. The shared rule also covers the blend back out on release.
    if prefs.muzzle_disable_ads_snipers and holdbreath.is_scoped() then
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

    local arm_sfps_transition = pending_sfps_camera_event
    pending_sfps_camera_event = false

    local is_cover = COVER_STATE_TO_KEY[cached.fps_state] ~= nil
    local is_active = cached_view_mode == 1 and (cached.is_holding or is_cover)
    -- Published for RE9Laser (which owns the shared muzzle module while active): force muzzle
    -- spawn exactly while the iron sights are the aim — FP with the weapon up, not Standard FPS,
    -- canted off (in those two the laser's own spawn rules decide again, matching the reticle
    -- rule above). Decided here, off the same condition that applies the camera offsets.
    -- bullet_from_muzzle still carries this mod's own policy on top.
    _G.IronSights_MuzzleSpawn = (is_active and not standard_fps_mode
        and not canted_aim_enabled
        and (bullet_from_muzzle or prefs.muzzle_all_views)) == true

    -- Pose state for mods that draw against the weapon (M4A1's scope overlay
    -- hides itself through these transitions rather than riding the swing).
    -- Same publish convention as IronSights_MuzzleSpawn above.
    _G.IronSights_PoseState = {
        canted   = canted_aim_enabled == true,
        sfps     = standard_fps_mode == true,
        -- the main blend only. The overshoot wobble that follows it runs for
        -- canted_aim_wobble_duration (1.6 s by default) and is cosmetic - the
        -- weapon is already in its new pose, so waiting it out just makes
        -- anything gated on this feel sluggish.
        settling = canted_aim_state.in_transition == true,
        wobbling = canted_aim_state.overshoot_active == true,
    }
    local o = nil
    local scope_offset_now = false
    if is_active and not cached.busy_ads and cached.weapon_id then
        -- M4A1's ACOG, checked FIRST because it is the most specific state. With the optic's
        -- sight picture up the eye is down a scope, so neither the iron-sight figure nor a cover
        -- pose describes the alignment. That mod owns both the flag and the values (its own menu
        -- edits them, under "Scope aim offset"); this only applies them. Absent mod, absent
        -- scope, or a malformed table all fall through to the normal path untouched.
        --
        -- Gated on arm0503 as well as the flag: the M4A1 replaces that weapon, and this offset is
        -- tuned for its optic alone — it must never reach another gun. Prefix-matched because
        -- this mod already keys per-character variants like arm0400_leon / arm0400_grace.
        -- FITTED, not "overlay currently visible". The optic's picture fades up partway through
        -- the raise, so keying on it moved the camera target mid-transition: the eye set off
        -- toward the iron-sight offset, then redirected to the scope one. That redirect is the
        -- flicker. Fitted holds for the whole move. Falls back to the visibility flag so an
        -- older M4A1 that does not publish the new one still works.
        if (_G.M4A1_ScopeFitted == true or _G.M4A1_ScopeOverlayVisible == true)
            and cached.weapon_id:sub(1, 7) == "arm0503" then
            local so = nil
            -- Leaning around cover moves the body, so the optic wants its own eye
            -- position there rather than the standing one. Keyed by OUR cover names,
            -- so the crouch states collapse onto the same pair the weapon table uses.
            -- Still the scope path, not the cover path below: an older M4A1 that does
            -- not publish these, or a malformed table, falls back to the plain scope
            -- offset and behaves exactly as before.
            if is_cover then
                so = _G.M4A1_ScopeCoverOffset
                so = type(so) == "table" and so[COVER_STATE_TO_KEY[cached.fps_state]] or nil
            end
            so = so or _G.M4A1_ScopeAimOffset
            if type(so) == "table" and type(so.x) == "number"
                and type(so.y) == "number" and type(so.z) == "number" then
                o = so
                scope_offset_now = true
            end
        end
        -- M4A1's IRON cover pair, checked BEFORE the generic cover table below. That mod
        -- replaces arm0503, so it owns this weapon's alignment in every pose - the same
        -- argument the plain iron offset further down already makes. It has to sit ABOVE
        -- the lookup, not below: stale arm0503 rows exist in saved cover files (the M4A1
        -- was tuned through this mod's own cover menu before it had its own pair), and a
        -- row saved for one lean direction and not the other made that direction ignore
        -- the M4A1's slider while the other obeyed it.
        if not o and is_cover and cached.weapon_id:sub(1, 7) == "arm0503" then
            local ic = _G.M4A1_IronCoverOffset
            ic = type(ic) == "table" and ic[COVER_STATE_TO_KEY[cached.fps_state]] or nil
            if type(ic) == "table" and type(ic.x) == "number"
                and type(ic.y) == "number" and type(ic.z) == "number" then
                o = ic
            end
        end
        if not o and is_cover then
            o = get_cover_offset(cached.weapon_id, COVER_STATE_TO_KEY[cached.fps_state])
        end
        -- M4A1's IRON sight offset, the counterpart to the scope one above and used when its
        -- ACOG is off. It stands in for this mod's own arm0503 figure — that weapon is the M4A1,
        -- so the mod that knows what its sights look like owns the alignment, and both of its
        -- sight pictures can be tuned from one menu. Checked AFTER cover, unlike the scope
        -- offset: a cover pose is about where the body is, which the sight picture does not
        -- change. Every other weapon, and an absent mod, keep the normal path.
        if not o and cached.weapon_id:sub(1, 7) == "arm0503" then
            -- Standing irons. The cover poses were already handled above, so this is
            -- only reached out of cover, or when that pair is missing/malformed.
            local io_ = _G.M4A1_IronAimOffset
            if type(io_) == "table" and type(io_.x) == "number"
                and type(io_.y) == "number" and type(io_.z) == "number" then
                o = io_
            end
        end
        if not o then
            o = weapon_offsets[cached.weapon_id]
        end
    end
    local tx = o and o.x or 0
    local ty = o and o.y or 0
    local tz = o and o.z or 0

    local sfps_blocked_by_ads = cached.busy_ads and prefs.sfps_disable_ads_snipers
        and (cached.weapon_id == "arm0600" or cached.weapon_id == "arm0601")
    if standard_fps_mode and is_active and not sfps_blocked_by_ads then
        local o_sfps = cached.weapon_id and get_standard_fps_offset(cached.weapon_id)
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
    if arm_sfps_transition then
        override_dur = TRANSITION_SFPS
    elseif scope_offset_now or scope_offset_prev then
        -- Raising or lowering the optic: an ADS move, so give it the ADS duration rather than
        -- letting it fall through to the slower swap blend. Either side of the edge counts, so
        -- coming out of the scope is as quick as going in.
        override_dur = TRANSITION_ADS
    elseif cached.busy_ads and not standard_fps_mode then
        override_dur = TRANSITION_ADS
    end
    scope_offset_prev = scope_offset_now
    transition_set_target(tx, ty, tz, override_dur, arm_sfps_transition)
    transition_update()
    if sfps_cam_wobble.active then
        local wnow = os.clock()
        local elapsed = wnow - sfps_cam_wobble.start_time
        local wdur = math.max(0.01, prefs.sfps_wobble_duration or 0.85)
        if elapsed >= wdur then
            sfps_cam_wobble.active = false
            transition.cur_x = sfps_cam_wobble.settle_x
            transition.cur_y = sfps_cam_wobble.settle_y
            transition.cur_z = sfps_cam_wobble.settle_z
        else
            local amp = prefs.sfps_wobble_amplitude or 0.007
            local amp_fwd = prefs.sfps_wobble_forward_amplitude or 0.007
            local freq = prefs.sfps_wobble_frequency or 23.5
            local damp = prefs.sfps_wobble_damping or 7.5
            local env = math.exp(-damp * elapsed)
            local w = amp * env * math.sin(freq * elapsed)
            -- Extra oscillation on offset Z only; same phase as side-to-side term so displacement is 0 at wobble start (no Z jump)
            local w_z = amp_fwd * env * math.sin(freq * elapsed)
            transition.cur_x = sfps_cam_wobble.settle_x + w * sfps_cam_wobble.dir_x
            transition.cur_y = sfps_cam_wobble.settle_y + w * sfps_cam_wobble.dir_y
            transition.cur_z = sfps_cam_wobble.settle_z + w * sfps_cam_wobble.dir_z + w_z
        end
    end

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

-- Joint write helper. Shared by the canted arm pose below and by the hand/finger pose further
-- down (which is independent of canted and runs in third person too), so it sits at file scope.
-- Cache method objects for joint get/set (avoids string lookup per call)
local _ah_joint_td = sdk.find_type_definition("via.Joint")
local _ah_meth_get_rot = _ah_joint_td and _ah_joint_td:get_method("get_Rotation")
local _ah_meth_set_rot = _ah_joint_td and _ah_joint_td:get_method("set_Rotation")

-- Reusable native Quaternion for set_Rotation (avoids per-frame allocation)
local _ah_temp_quat_native = nil
pcall(function()
    if Quaternion then _ah_temp_quat_native = Quaternion.new() end
end)

local canted_aim_identity_quat = { w = 1.0, x = 0.0, y = 0.0, z = 0.0 }

-- Returns false when the joint could not be read, which for a via.Joint means it has gone stale
-- (the read then throws every frame); callers drop the cache rather than keep hammering it.
local function _ah_set_joint_rotation(joint, off)
    if not joint then return false end
    local ok, cur
    if _ah_meth_get_rot then
        ok, cur = pcall(_ah_meth_get_rot, joint)
    end
    if not ok or not cur then
        ok, cur = pcall(joint.call, joint, "get_Rotation")
        if not ok or not cur then return false end
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
    return true
end

local function _re9_canted_scope() -- canted-aim / arm-rotation (breath-hold moved to re9holdbreath)
local function canted_aim_non_zero(rot)
    local eps = 0.0001
    return math.abs(rot.x) > eps or math.abs(rot.y) > eps or math.abs(rot.z) > eps
end

-- Cache base offset quats (avoid 4x euler_deg_to_quat per frame); invalidated by save_arm_hand_rotation
local _ah_off_cache_valid = false
local _ah_cached_off_r, _ah_cached_off_l, _ah_cached_lower_r, _ah_cached_lower_l, _ah_cached_upper_r, _ah_cached_upper_l

-- Pre-allocated offset quats for slerp results (avoid per-frame table creation)
local _ah_slerp = {
    r = { w = 1, x = 0, y = 0, z = 0 },
    l = { w = 1, x = 0, y = 0, z = 0 },
    lr = { w = 1, x = 0, y = 0, z = 0 },
    ll = { w = 1, x = 0, y = 0, z = 0 },
    ur = { w = 1, x = 0, y = 0, z = 0 },
    ul = { w = 1, x = 0, y = 0, z = 0 }
}

local function is_in_cover_state()
    if not cached.fps_state then return false end
    for _, cs in ipairs(COVER_STATES) do
        if cached.fps_state == cs then return true end
    end
    return false
end

local function apply_arm_hand_rotation()
    if not cached.weapon_id then return end
    if cached_view_mode ~= 1 then return end -- arm pose only in first person
    -- The canted blend, for EVERY weapon including a replaced one. A publishing
    -- mod supplies FINGER rotations (see m4a1_fingers) and nothing else -
    -- it does not pin the blend, so canted still fades in and out normally on its
    -- weapon. A per-weapon pin was tried here and removed: it made the toggle do
    -- nothing on that gun, which is the whole behaviour being protected.
    local canted_blend = prefs.pose_ignore_canted and 1.0 or canted_aim_state.blend
    if canted_blend <= 0 then return end
    -- Blend out when in cover (ah_cover_apply_blend is updated in LateUpdateBehavior)
    local effective_blend = canted_blend * ah_hold_apply_blend * ah_cover_apply_blend
    if effective_blend <= 0 then return end
    local hand_rot = get_arm_hand_rotation(cached.weapon_id)
    local lower_rot = get_arm_lower_rotation(cached.weapon_id)
    local upper_rot = get_arm_upper_rotation(cached.weapon_id)
    local hand_nz = canted_aim_non_zero(hand_rot)
    local lower_nz = canted_aim_non_zero(lower_rot)
    local upper_nz = canted_aim_non_zero(upper_rot)
    if not hand_nz and not lower_nz and not upper_nz then return end
    -- Pause is the only SDK read in the gate chain, so it comes last -- once we already know
    -- there is something to apply this frame.
    refresh_cached_game_paused()
    if cached_game_paused then return end
    resolve_arm_hand_joints()

    _ah_cached_off_r = arm_hand_offset_quat_r(hand_rot)
    _ah_cached_off_l = arm_hand_offset_quat_l(hand_rot)
    _ah_cached_lower_r = arm_lower_offset_quat_r(lower_rot)
    _ah_cached_lower_l = arm_lower_offset_quat_l(lower_rot)
    _ah_cached_upper_r = arm_upper_offset_quat_r(upper_rot)
    _ah_cached_upper_l = arm_upper_offset_quat_l(upper_rot)

    local blend = effective_blend
    if blend == 1.0 then
        if hand_nz then
            _ah_set_joint_rotation(joints.r_arm_hand, _ah_cached_off_r)
            _ah_set_joint_rotation(joints.l_arm_hand, _ah_cached_off_l)
        end
        if lower_nz then
            _ah_set_joint_rotation(joints.r_arm_lower, _ah_cached_lower_r)
            _ah_set_joint_rotation(joints.l_arm_lower, _ah_cached_lower_l)
        end
        if upper_nz then
            _ah_set_joint_rotation(joints.r_arm_upper, _ah_cached_upper_r)
            _ah_set_joint_rotation(joints.l_arm_upper, _ah_cached_upper_l)
        end
        return
    end

    if hand_nz then
        local q = quat_slerp(canted_aim_identity_quat, _ah_cached_off_r, blend)
        _ah_slerp.r.w = q.w; _ah_slerp.r.x = q.x; _ah_slerp.r.y = q.y; _ah_slerp.r.z = q.z
        q = quat_slerp(canted_aim_identity_quat, _ah_cached_off_l, blend)
        _ah_slerp.l.w = q.w; _ah_slerp.l.x = q.x; _ah_slerp.l.y = q.y; _ah_slerp.l.z = q.z
        _ah_set_joint_rotation(joints.r_arm_hand, _ah_slerp.r)
        _ah_set_joint_rotation(joints.l_arm_hand, _ah_slerp.l)
    end
    if lower_nz then
        local q = quat_slerp(canted_aim_identity_quat, _ah_cached_lower_r, blend)
        _ah_slerp.lr.w = q.w; _ah_slerp.lr.x = q.x; _ah_slerp.lr.y = q.y; _ah_slerp.lr.z = q.z
        q = quat_slerp(canted_aim_identity_quat, _ah_cached_lower_l, blend)
        _ah_slerp.ll.w = q.w; _ah_slerp.ll.x = q.x; _ah_slerp.ll.y = q.y; _ah_slerp.ll.z = q.z
        _ah_set_joint_rotation(joints.r_arm_lower, _ah_slerp.lr)
        _ah_set_joint_rotation(joints.l_arm_lower, _ah_slerp.ll)
    end
    if upper_nz then
        local q = quat_slerp(canted_aim_identity_quat, _ah_cached_upper_r, blend)
        _ah_slerp.ur.w = q.w; _ah_slerp.ur.x = q.x; _ah_slerp.ur.y = q.y; _ah_slerp.ur.z = q.z
        q = quat_slerp(canted_aim_identity_quat, _ah_cached_upper_l, blend)
        _ah_slerp.ul.w = q.w; _ah_slerp.ul.x = q.x; _ah_slerp.ul.y = q.y; _ah_slerp.ul.z = q.z
        _ah_set_joint_rotation(joints.r_arm_upper, _ah_slerp.ur)
        _ah_set_joint_rotation(joints.l_arm_upper, _ah_slerp.ul)
    end
end

re.on_application_entry("LateUpdateBehavior", function()
    local now = os.clock()
    local dt_hold = now - ah_hold_apply_last_time
    if dt_hold < 0 then dt_hold = 0 end
    if dt_hold > 0.05 then dt_hold = 0.05 end
    ah_hold_apply_last_time = now
    -- Only increase blend when actually holding; if game leaves IsHoldEndRequest true after release, decay so effect can't get stuck
    if cached.is_hold_end_request and cached.is_holding then
        ah_hold_apply_blend = math.min(1.0, ah_hold_apply_blend + dt_hold * AH_HOLD_APPLY_RATE)
    else
        ah_hold_apply_blend = math.max(0.0, ah_hold_apply_blend - dt_hold * AH_HOLD_APPLY_RATE)
    end
    if is_in_cover_state() then
        ah_cover_apply_blend = math.max(0.0, ah_cover_apply_blend - dt_hold * AH_COVER_APPLY_RATE)
    else
        ah_cover_apply_blend = math.min(1.0, ah_cover_apply_blend + dt_hold * AH_COVER_APPLY_RATE)
    end

    local target = canted_aim_enabled and 1.0 or 0.0

    -- Fast path: already settled at target — only re-apply rotation, skip all blend math
    if canted_aim_state.blend == target and not canted_aim_state.in_transition and not canted_aim_state.overshoot_active then
        apply_arm_hand_rotation()
        return
    end

    local dt = now - canted_aim_state.blend_last_time
    if dt < 0 then dt = 0 end
    canted_aim_state.blend_last_time = now
    if dt > 0.05 then dt = 0.05 end

    if target ~= canted_aim_state.prev_target then
        canted_aim_state.prev_target = target
        canted_aim_state.in_transition = true
        canted_aim_state.transition_start_time = now
        canted_aim_state.transition_start_blend = canted_aim_state.blend
        -- Cancel any active overshoot when target changes
        canted_aim_state.overshoot_active = false
    end

    if canted_aim_state.in_transition then
        local duration = (target > 0.5) and math.max(0.001, CANTED_AIM_TRANSITION_IN) or math.max(0.001, CANTED_AIM_TRANSITION_OUT)
        local elapsed = now - canted_aim_state.transition_start_time
        if elapsed >= duration then
            canted_aim_state.in_transition = false
            -- Start overshoot oscillation
            canted_aim_state.overshoot_active = true
            canted_aim_state.overshoot_start_time = now
            canted_aim_state.overshoot_target = target
            canted_aim_state.blend = target
        else
            canted_aim_state.blend = canted_aim_state.transition_start_blend + (target - canted_aim_state.transition_start_blend) * smoothstep(elapsed / duration)
        end
    elseif canted_aim_state.overshoot_active then
        local elapsed = now - canted_aim_state.overshoot_start_time
        local duration = math.max(0.01, prefs.canted_aim_wobble_duration or 1.6)
        if elapsed >= duration then
            -- Done with oscillations, settle to target
            canted_aim_state.overshoot_active = false
            canted_aim_state.blend = canted_aim_state.overshoot_target
        else
            -- Damped sine oscillation: amplitude * exp(-damping * t) * sin(frequency * t)
            local t = elapsed
            local amp = prefs.canted_aim_wobble_amplitude or 0.04
            local freq = prefs.canted_aim_wobble_frequency or 21.0
            local damp = prefs.canted_aim_wobble_damping or 6.3
            local overshoot = amp * math.exp(-damp * t) * math.sin(freq * t)
            canted_aim_state.blend = canted_aim_state.overshoot_target + overshoot
            -- Clamp to valid range
            if canted_aim_state.blend < 0.0 then canted_aim_state.blend = 0.0
            elseif canted_aim_state.blend > 1.0 then canted_aim_state.blend = 1.0 end
        end
    else
        canted_aim_state.blend = target
    end

    apply_arm_hand_rotation()
end)
end
_re9_canted_scope()

-- Hand / finger pose. Deliberately its own pass: it is a grip fix, not part of the canted aim, so
-- it is independent of canted, of Standard FPS and of the view mode -- it has to hold in third
-- person the same as in first. Registered after the canted pass so the arm joints settle first.
local _fj_list = {}
local _fj_key = nil
local _fj_generation = -1

--- The finger table a publishing mod supplies for this weapon, or nil. The
--- getter override alone was not enough: the APPLY path reads finger_rotations
--- directly and never calls it, so published joints reached the UI and nothing
--- else. Both places below now consult this.
local function m4a1_fingers(weapon_key)
    local o = rawget(_G, "M4A1_ArmPose")
    if type(o) ~= "table" or o.key ~= weapon_key then return nil end
    return type(o.fingers) == "table" and o.fingers or nil
end

--- Cheap signature of those values, so a slider edit rebuilds the baked quats.
--- They are published every frame and edited live, so a dirty FLAG cannot see
--- the change - only the values themselves can.
local function m4a1_finger_sig(weapon_key)
    local f = m4a1_fingers(weapon_key)
    if not f then return "" end
    local acc = {}
    for jn, t in pairs(f) do
        acc[#acc + 1] = string.format("%s:%.3f,%.3f,%.3f", jn,
                                      t.x or 0, t.y or 0, t.z or 0)
    end
    table.sort(acc)
    return table.concat(acc, "|")
end

local function rebuild_finger_apply_list(weapon_key)
    _fj_list = {}
    _fj_key = weapon_key
    _fj_generation = finger_joints_generation
    finger_apply_dirty = false
    _fj_m4a1_sig = m4a1_finger_sig(weapon_key)
    local w = weapon_key and finger_rotations[weapon_key]
    local pub = m4a1_fingers(weapon_key)
    if not w and not pub then return end
    -- Merged, with the published values winning per JOINT: a joint the mod does
    -- not name still comes from the saved file.
    local merged = {}
    for jname, rot in pairs(w or {}) do merged[jname] = rot end
    for jname, rot in pairs(pub or {}) do merged[jname] = rot end
    for jname, rot in pairs(merged) do
        local j = finger_joint_by_name[jname]
        if j then
            _fj_list[#_fj_list + 1] = { joint = j, quat = euler_deg_to_quat(rot.x or 0, rot.y or 0, rot.z or 0) }
        end
    end
end

re.on_application_entry("LateUpdateBehavior", function()
    local wkey = cached.weapon_id
    if not wkey then return end
    local w = finger_rotations[wkey]
    if (not w or next(w) == nil) and not m4a1_fingers(wkey) then return end
    -- Pause is the only SDK read in the gate chain, so it comes last of the cheap checks
    refresh_cached_game_paused()
    if cached_game_paused then return end
    resolve_arm_hand_joints()
    -- Generation covers a re-scan (player spawn, first/third person model swap) picking up a name
    -- that was unresolved before, without rebuilding every frame while it stays unresolved.
    if finger_apply_dirty or _fj_key ~= wkey or _fj_generation ~= finger_joints_generation
       or _fj_m4a1_sig ~= m4a1_finger_sig(wkey) then
        rebuild_finger_apply_list(wkey)
    end
    for i = 1, #_fj_list do
        if not _ah_set_joint_rotation(_fj_list[i].joint, _fj_list[i].quat) then
            -- Stale joint: drop the caches so the next resolve rebuilds them
            arm_hand_cached_player_go = nil
            finger_apply_dirty = true
            return
        end
    end
end)

-- Per-joint hand/finger editor. One collapsible node per discovered joint so a full hand stays
-- navigable, names straight off the skeleton, and each joint independent per side (the left hand
-- grips a different part of the weapon, so there is nothing sensible to mirror).
local function draw_finger_side_ui(key, side, side_id, label)
    if not imgui.tree_node(label .. "##fingers_" .. side_id) then return end
    local list = finger_joints[side]
    if #list == 0 then
        imgui.text_colored("No finger joints found yet (list fills in once the player is loaded)", 0xFF00FFFF)
        imgui.tree_pop()
        return
    end
    for i = 1, #list do
        local jname = list[i].name
        local r = get_finger_rotation(key, jname)
        local edited = (r.x ~= 0 or r.y ~= 0 or r.z ~= 0)
        if imgui.tree_node((edited and "* " or "") .. jname .. "##fj_node_" .. jname) then
            local cx, cy, cz, nx, ny, nz
            cx, nx = imgui.drag_float("X (deg)##fjx_" .. jname, r.x, 0.5, -180.0, 180.0, "%.1f")
            if cx then r.x = nx end
            cy, ny = imgui.drag_float("Y (deg)##fjy_" .. jname, r.y, 0.5, -180.0, 180.0, "%.1f")
            if cy then r.y = ny end
            cz, nz = imgui.drag_float("Z (deg)##fjz_" .. jname, r.z, 0.5, -180.0, 180.0, "%.1f")
            if cz then r.z = nz end
            if cx or cy or cz then
                set_finger_rotation(key, jname, r.x, r.y, r.z)
                save_arm_hand_rotation()
            end
            if imgui.button("Reset##fjreset_" .. jname) then
                set_finger_rotation(key, jname, 0.0, 0.0, 0.0)
                save_arm_hand_rotation()
            end
            imgui.tree_pop()
        end
    end
    if imgui.button("Reset all##fjresetall_" .. side_id) then
        local names = {}
        for i = 1, #list do names[list[i].name] = true end
        clear_finger_rotations(key, names)
        save_arm_hand_rotation()
    end
    imgui.tree_pop()
end

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
            pending_sfps_camera_event = true
        end
        if imgui.tree_node("Standard FPS transition wobble") then
            if imgui.is_item_hovered() then
                imgui.set_tooltip(
                    "When you turn Standard FPS Mode on or off (hotkey, or gamepad), a slight wobbble/settling effect is applied for a more realistic feel"
                )
            end
            local sfa, sff, sfd, sfdu
            sfa, prefs.sfps_wobble_amplitude = imgui.slider_float("Side-to-side amplitude##sfps_wobble", prefs.sfps_wobble_amplitude, 0.0, 0.06, "%.4f")
            if imgui.is_item_hovered() then
                imgui.set_tooltip(
                    "How strong the side to side wobble is (scaled along the camera offset transition)")
            end
            if sfa then save_prefs() end
            local sfz
            sfz, prefs.sfps_wobble_forward_amplitude = imgui.slider_float("Back/Forward amplitude##sfps_wobble_z", prefs.sfps_wobble_forward_amplitude, 0.0, 0.06, "%.4f")
            if imgui.is_item_hovered() then
                imgui.set_tooltip(
                    "Adds oscillation purely on back/forward offset")
            end
            if sfz then save_prefs() end
            sff, prefs.sfps_wobble_frequency = imgui.slider_float("Frequency##sfps_wobble", prefs.sfps_wobble_frequency, 1.0, 40.0, "%.1f")
            if imgui.is_item_hovered() then
                imgui.set_tooltip(
                    "Oscillation rate (roughly cycles per second feel). Higher = quicker, tighter shakes; lower = slower, wider rolls"
                )
            end
            if sff then save_prefs() end
            sfd, prefs.sfps_wobble_damping = imgui.slider_float("Damping##sfps_wobble", prefs.sfps_wobble_damping, 0.5, 10.0, "%.1f")
            if imgui.is_item_hovered() then
                imgui.set_tooltip(
                    "How fast weapon settles")
            end
            if sfd then save_prefs() end
            sfdu, prefs.sfps_wobble_duration = imgui.slider_float("Duration (sec)##sfps_wobble", prefs.sfps_wobble_duration, 0.2, 4.0, "%.2f")
            if imgui.is_item_hovered() then
                imgui.set_tooltip(
                    "Length of time the wobble is active (seconds)"
                )
            end
            if sfdu then save_prefs() end
            if imgui.button("Reset to Defaults##sfps_wobble") then
                prefs.sfps_wobble_amplitude = 0.007
                prefs.sfps_wobble_forward_amplitude = 0.007
                prefs.sfps_wobble_frequency = 23.5
                prefs.sfps_wobble_damping = 7.5
                prefs.sfps_wobble_duration = 0.85
                save_prefs()
            end
            imgui.tree_pop()
        end
        -- RE9Laser owns the reticle while it's active: its dot draws through the same Gui_ui2020
        -- element, so either of these hiding it would take the dot down too. Removed from the menu
        -- here, and not applied (see the draw hook and sync_auto_iron_sight).
        if re9_laser_active() then
            imgui.text("Crosshair hiding: managed by RE9 Laser")
            if imgui.is_item_hovered() then
                imgui.set_tooltip("RE9 Laser is loaded and owns the reticle. Its laser dot draws through the\n"
                    .. "same element as the crosshair, so hiding the crosshair would hide the dot.\n"
                    .. "Auto Hide Crosshair Mode and Hide Reticle are disabled while it is active.")
            end
        else
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
        end
        if not prefs.auto_iron_sight then
        if not re9_laser_active() then
        local ret_changed
        ret_changed, hide_reticle = imgui.checkbox("Hide Reticle in First Person", hide_reticle)
        if ret_changed then
            prefs.hide_reticle = hide_reticle
            save_prefs()
        end
        end
        -- Muzzle spawn is independent of hiding the crosshair: allow it with the reticle on.
        if re9_laser_active() then
            imgui.text("Spawn Bullet From Muzzle: managed by RE9 Laser")
            if imgui.is_item_hovered() then
                imgui.set_tooltip("RE9 Laser is loaded and handles bullet spawn itself, so IronSights' muzzle spawn is disabled to avoid conflicting edits.")
            end
        elseif re9_3d_crosshair_active() then
            bullet_from_muzzle = true
            imgui.text("Spawn Bullet From Muzzle: ON (RE93DCrosshair detected)")
        else
            local muzzle_changed
            muzzle_changed, bullet_from_muzzle = imgui.checkbox("Spawn Bullet From Muzzle", bullet_from_muzzle)
            if imgui.is_item_hovered() then
                imgui.set_tooltip("Spawns bullets from the muzzle in first person, whether or not the crosshair is hidden.")
            end
            if muzzle_changed then
                prefs.bullet_from_muzzle = bullet_from_muzzle
                save_prefs()
            end
        end
        end
        holdbreath.draw_menu()
        imgui.separator()

        local equipped_id = cached.weapon_id
        if equipped_id then
            local eid_name = WEAPON_NAMES[equipped_id] or equipped_id
            imgui.text_colored("Equipped: " .. eid_name, 0xFFFFFF00)

            if equipped_id ~= ui_state.last_equipped_id then
                for i, key in ipairs(dropdown_items) do
                    if key == equipped_id then
                        ui_state.selected_index = i
                        populate_ui(key, EDIT_MODE_COVER_STATE[ui_state.edit_mode])
                        break
                    end
                end
                ui_state.last_equipped_id = equipped_id
            end
        else
            imgui.text_colored("Equipped: (not detected)", 0xFFFFFF00)
        end

        local combo_changed
        combo_changed, ui_state.selected_index = imgui.combo("Weapon", ui_state.selected_index, dropdown_options)
        if ui_state.selected_index < 1 then ui_state.selected_index = 1 end
        if ui_state.selected_index > #dropdown_items then ui_state.selected_index = #dropdown_items end
        if combo_changed then
            populate_ui(dropdown_items[ui_state.selected_index], EDIT_MODE_COVER_STATE[ui_state.edit_mode])
        end

        local mode_changed
        mode_changed, ui_state.edit_mode = imgui.combo("Edit Mode", ui_state.edit_mode, EDIT_MODE_LABELS)
        if ui_state.edit_mode < 1 then ui_state.edit_mode = 1 end
        if ui_state.edit_mode > #EDIT_MODE_LABELS then ui_state.edit_mode = #EDIT_MODE_LABELS end
        if mode_changed then
            populate_ui(dropdown_items[ui_state.selected_index], EDIT_MODE_COVER_STATE[ui_state.edit_mode])
        end

        imgui.separator()

        local key = dropdown_items[ui_state.selected_index]
        local cover_state = EDIT_MODE_COVER_STATE[ui_state.edit_mode]
        if key then
            if imgui.tree_node("Iron Sight Offsets") then
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

                if not ui_state.reset_confirm then
                    if imgui.button("Reset##offset") then
                        ui_state.reset_confirm = true
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
                        ui_state.reset_confirm = false
                    end
                    imgui.same_line()
                    if imgui.button("No##reset") then
                        ui_state.reset_confirm = false
                    end
                end
                if imgui.tree_node("Cover offsets") then
                    if imgui.is_item_hovered() then
                        imgui.set_tooltip(
                            "Camera offset while aiming from cover (leaning left or right). "
                            .. "Crouch cover uses the same values as stand cover. "
                        )
                    end
                    local function draw_cover_side(cover_action, title)
                        if imgui.tree_node(title .. "##cover_ui_" .. cover_action) then
                            local co = effective_cover_offset(key, cover_action)
                            local cx = co and (co.x or 0) or 0
                            local cy = co and (co.y or 0) or 0
                            local cz = co and (co.z or 0) or 0
                            local ax, axn = imgui.drag_float("Left/Right##" .. cover_action, cx, 0.001, -5.0, 5.0, "%.4f")
                            if ax then cx = axn end
                            local ay, ayn = imgui.drag_float("Up/Down##" .. cover_action, cy, 0.001, -5.0, 5.0, "%.4f")
                            if ay then cy = ayn end
                            local az, azn = imgui.drag_float("Back/Forward##" .. cover_action, cz, 0.001, -5.0, 5.0, "%.4f")
                            if az then cz = azn end
                            if ax or ay or az then
                                set_cover_offset(key, cover_action, cx, cy, cz)
                            end
                            if imgui.button("Reset##cover_reset_" .. cover_action) then
                                local def = DEFAULT_COVER_OFFSETS[key .. "|" .. cover_action]
                                if def then
                                    set_cover_offset(key, cover_action, def.x, def.y, def.z)
                                else
                                    set_cover_offset(key, cover_action, 0.0, 0.0, 0.0)
                                end
                            end
                            if imgui.is_item_hovered() then
                                if DEFAULT_COVER_OFFSETS[key .. "|" .. cover_action] then
                                    imgui.set_tooltip("Restore mod default for this weapon and cover side.")
                                else
                                    imgui.set_tooltip("No bundled default for this weapon; reset to 0,0,0.")
                                end
                            end
                            imgui.tree_pop()
                        end
                    end
                    draw_cover_side("CoverActionRight", "Cover right")
                    draw_cover_side("CoverActionLeft", "Cover left")
                    imgui.tree_pop()
                end
                imgui.tree_pop()
            end

            if imgui.tree_node("Standard FPS Offsets") then
                local sfps_o = get_standard_fps_offset(key) or default_standard_fps_offsets[key] or default_standard_fps_offset
                local sfps_x, sfps_y, sfps_z = sfps_o.x or 0, sfps_o.y or 0, sfps_o.z or 0
                local sx, sx_new = imgui.drag_float("Left/Right (Standard FPS)", sfps_x, 0.001, -5.0, 5.0, "%.4f")
                if sx then sfps_x = sx_new end
                local sy, sy_new = imgui.drag_float("Up/Down (Standard FPS)", sfps_y, 0.001, -5.0, 5.0, "%.4f")
                if sy then sfps_y = sy_new end
                local sz, sz_new = imgui.drag_float("Back/Forward (Standard FPS)", sfps_z, 0.001, -5.0, 5.0, "%.4f")
                if sz then sfps_z = sz_new end
                if sx or sy or sz then
                    set_standard_fps_offset(key, sfps_x, sfps_y, sfps_z)
                end
                if imgui.button("Reset##standard_fps") then
                    set_standard_fps_offset(key, -0.09, 0.0, 0.0)
                end
                imgui.tree_pop()
            end

            -- Hand / finger joints (everything under R_Arm_Hand / L_Arm_Hand) — per weapon, per
            -- joint. Its own section, not part of Canted Aim: this pose applies in first and
            -- third person and does not care about canted, Standard FPS or iron sights.
            if imgui.tree_node("Hand / Finger Joints") then
                resolve_arm_hand_joints()
                imgui.text_colored("Applies always (first and third person), independent of aim mode.", 0xFF80FF80)
                draw_finger_side_ui(key, "r", "right", "Right hand")
                draw_finger_side_ui(key, "l", "left", "Left hand")
                imgui.tree_pop()
            end

            if imgui.tree_node("Canted Aim") then
                local ar_dbl_kb_t, ar_dbl_pad_t
                ar_dbl_kb_t, prefs.canted_aim_toggle_double_press_kb = imgui.checkbox("KB/Mouse: require double press##canted_dbl_kb", prefs.canted_aim_toggle_double_press_kb)
                if imgui.is_item_hovered() then
                    imgui.set_tooltip("Keyboard/mouse canted hotkey: if unchecked, one press toggles; if checked, two quick presses toggle.")
                end
                ar_dbl_pad_t, prefs.canted_aim_toggle_double_press_pad = imgui.checkbox("Gamepad: require double press##canted_dbl_pad", prefs.canted_aim_toggle_double_press_pad)
                if imgui.is_item_hovered() then
                    imgui.set_tooltip("Gamepad canted hotkey: if unchecked, one press toggles; if checked, two quick presses toggle.")
                end
                if ar_dbl_kb_t or ar_dbl_pad_t then save_prefs() end
                -- Arm hand rotation (R_Arm_Hand / L_Arm_Hand) — per weapon
                if imgui.tree_node("Hands") then
                    resolve_arm_hand_joints()
                    local h = get_arm_hand_rotation(key)
                    local ax, ax_new = imgui.drag_float("X (deg)", h.x, 0.5, -180.0, 180.0, "%.1f")
                    if ax then h.x = ax_new end
                    local ay, ay_new = imgui.drag_float("Y (deg)", h.y, 0.5, -180.0, 180.0, "%.1f")
                    if ay then h.y = ay_new end
                    local az, az_new = imgui.drag_float("Z (deg)", h.z, 0.5, -180.0, 180.0, "%.1f")
                    if az then h.z = az_new end
                    if ax or ay or az then set_arm_hand_rotation(key, h.x, h.y, h.z); save_arm_hand_rotation() end
                    if imgui.button("Reset##arm_hand") then
                        local def = key and DEFAULT_CANTED_OFFSETS[key] and DEFAULT_CANTED_OFFSETS[key].arm_hand_rotation
                        if def then
                            set_arm_hand_rotation(key, def.x or 0, def.y or 0, def.z or 0)
                        else
                            set_arm_hand_rotation(key, 0.0, 0.0, 0.0)
                        end
                        save_arm_hand_rotation()
                    end
                    if not joints.r_arm_hand and not joints.l_arm_hand then
                        imgui.text_colored("Arm hand joints not found", 0xFF00FF00)
                    end
                    imgui.tree_pop()
                end
                -- Arm lower rotation (R_Arm_Lower / L_Arm_Lower) — per weapon
                if imgui.tree_node("Lower Arms") then
                    resolve_arm_hand_joints()
                    local l = get_arm_lower_rotation(key)
                    local lx, lx_new = imgui.drag_float("X (deg)##arm_lower", l.x, 0.5, -180.0, 180.0, "%.1f")
                    if lx then l.x = lx_new end
                    local ly, ly_new = imgui.drag_float("Y (deg)##arm_lower", l.y, 0.5, -180.0, 180.0, "%.1f")
                    if ly then l.y = ly_new end
                    local lz, lz_new = imgui.drag_float("Z (deg)##arm_lower", l.z, 0.5, -180.0, 180.0, "%.1f")
                    if lz then l.z = lz_new end
                    if lx or ly or lz then set_arm_lower_rotation(key, l.x, l.y, l.z); save_arm_hand_rotation() end
                    if imgui.button("Reset##arm_lower") then
                        local def = key and DEFAULT_CANTED_OFFSETS[key] and DEFAULT_CANTED_OFFSETS[key].arm_lower_rotation
                        if def then
                            set_arm_lower_rotation(key, def.x or 0, def.y or 0, def.z or 0)
                        else
                            set_arm_lower_rotation(key, 0.0, 0.0, 0.0)
                        end
                        save_arm_hand_rotation()
                    end
                    if not joints.r_arm_lower and not joints.l_arm_lower then
                        imgui.text_colored("Arm lower joints not found", 0xFF00FF00)
                    end
                    imgui.tree_pop()
                end
                -- Arm upper rotation (R_Arm_Upper / L_Arm_Upper) — per weapon
                if imgui.tree_node("Upper Arms") then
                    resolve_arm_hand_joints()
                    local u = get_arm_upper_rotation(key)
                    local ux, ux_new = imgui.drag_float("X (deg)##arm_upper", u.x, 0.5, -180.0, 180.0, "%.1f")
                    if ux then u.x = ux_new end
                    local uy, uy_new = imgui.drag_float("Y (deg)##arm_upper", u.y, 0.5, -180.0, 180.0, "%.1f")
                    if uy then u.y = uy_new end
                    local uz, uz_new = imgui.drag_float("Z (deg)##arm_upper", u.z, 0.5, -180.0, 180.0, "%.1f")
                    if uz then u.z = uz_new end
                    if ux or uy or uz then set_arm_upper_rotation(key, u.x, u.y, u.z); save_arm_hand_rotation() end
                    if imgui.button("Reset##arm_upper") then
                        local def = key and DEFAULT_CANTED_OFFSETS[key] and DEFAULT_CANTED_OFFSETS[key].arm_upper_rotation
                        if def then
                            set_arm_upper_rotation(key, def.x or 0, def.y or 0, def.z or 0)
                        else
                            set_arm_upper_rotation(key, 0.0, 0.0, 0.0)
                        end
                        save_arm_hand_rotation()
                    end
                    if not joints.r_arm_upper and not joints.l_arm_upper then
                        imgui.text_colored("Arm upper joints not found", 0xFF00FF00)
                    end
                    imgui.tree_pop()
                end
                -- Wobble (overshoot) settings
                if imgui.tree_node("Wobble (overshoot)") then
                    local wob_amp_ch
                    wob_amp_ch, prefs.canted_aim_wobble_amplitude = imgui.slider_float("Amplitude##wobble", prefs.canted_aim_wobble_amplitude, 0.0, 0.25, "%.2f")
                    if imgui.is_item_hovered() then imgui.set_tooltip("How much the blend overshoots (0 = no wobble). Default 0.04") end
                    if wob_amp_ch then save_prefs() end
                    local wob_freq_ch
                    wob_freq_ch, prefs.canted_aim_wobble_frequency = imgui.slider_float("Frequency##wobble", prefs.canted_aim_wobble_frequency, 1.0, 40.0, "%.1f")
                    if imgui.is_item_hovered() then imgui.set_tooltip("Speed of oscillation (higher = faster). Default 21.0") end
                    if wob_freq_ch then save_prefs() end
                    local wob_damp_ch
                    wob_damp_ch, prefs.canted_aim_wobble_damping = imgui.slider_float("Damping##wobble", prefs.canted_aim_wobble_damping, 0.5, 10.0, "%.1f")
                    if imgui.is_item_hovered() then imgui.set_tooltip("How quickly wobble fades (higher = settles faster). Default 6.3") end
                    if wob_damp_ch then save_prefs() end
                    local wob_dur_ch
                    wob_dur_ch, prefs.canted_aim_wobble_duration = imgui.slider_float("Duration (sec)##wobble", prefs.canted_aim_wobble_duration, 0.2, 4.0, "%.2f")
                    if imgui.is_item_hovered() then imgui.set_tooltip("How long the wobble runs before settling. Default 1.6") end
                    if wob_dur_ch then save_prefs() end
                    if imgui.button("Reset to Defaults##wobble") then
                        prefs.canted_aim_wobble_amplitude = 0.04
                        prefs.canted_aim_wobble_frequency = 21.0
                        prefs.canted_aim_wobble_damping = 6.3
                        prefs.canted_aim_wobble_duration = 1.6
                        save_prefs()
                    end
                    imgui.tree_pop()
                end
                imgui.tree_pop()
            end
        end



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

        imgui.text_colored(" Canted Aim Toggle:", 0xFFFFFFAA)
        imgui.indent(10)
        imgui.text("Keyboard and Mouse:")
        imgui.indent(10)
        local ar_dbl_kb_hk
        ar_dbl_kb_hk, prefs.canted_aim_toggle_double_press_kb = imgui.checkbox("Require double press##canted_aim_dbl_kb", prefs.canted_aim_toggle_double_press_kb)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("If checked, two quick presses toggle canted (default). If unchecked, a single press toggles.")
        end
        if ar_dbl_kb_hk then save_prefs() end
        wc = wc or ar_dbl_kb_hk
        local armc; armc, is_hk_settings.use_canted_aim_modifier = imgui.checkbox("Use Modifier##canted_aim_kb_mod", is_hk_settings.use_canted_aim_modifier); wc = wc or armc
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Require holding this button while pressing toggle")
        end
        imgui.same_line()
        hk_changed = hk.hotkey_setter("Canted Aim Modifier") or hk_changed
        hk_changed = hk.hotkey_setter("Canted Aim Toggle", is_hk_settings.use_canted_aim_modifier and "Canted Aim Modifier") or hk_changed
        imgui.unindent(10)
        imgui.text("Gamepad:")
        imgui.indent(10)
        local ar_dbl_pad_hk
        ar_dbl_pad_hk, prefs.canted_aim_toggle_double_press_pad = imgui.checkbox("Require double press##canted_aim_dbl_pad", prefs.canted_aim_toggle_double_press_pad)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("If checked, two quick presses toggle canted (default). If unchecked, a single press toggles.")
        end
        if ar_dbl_pad_hk then save_prefs() end
        wc = wc or ar_dbl_pad_hk
        local armc2; armc2, is_hk_settings.use_pad_canted_aim_modifier = imgui.checkbox("Use Modifier##canted_aim_pad_mod", is_hk_settings.use_pad_canted_aim_modifier); wc = wc or armc2
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Require holding this button while pressing toggle")
        end
        imgui.same_line()
        hk_changed = hk.hotkey_setter("Pad Canted Aim Modifier") or hk_changed
        hk_changed = hk.hotkey_setter("Pad Canted Aim Toggle", is_hk_settings.use_pad_canted_aim_modifier and "Pad Canted Aim Modifier") or hk_changed
        imgui.unindent(10)
        imgui.unindent(10)
        imgui.separator()


        if hk_changed or wc then
            hk.update_hotkey_table(is_hk_settings.hotkeys)
            json.dump_file(IS_HK_PATH, is_hk_settings)
        end

        holdbreath.draw_hotkeys()
        imgui.separator()

        if imgui.button("Reset Hotkeys to Defaults") then
            is_hk_settings = hk.recurse_def_settings({}, is_hk_default_settings)
            hk.reset_from_defaults_tbl(is_hk_default_settings.hotkeys)
            hk.update_hotkey_table(is_hk_settings.hotkeys)
            json.dump_file(IS_HK_PATH, is_hk_settings)
            -- Double-press lives in prefs, not Hotkeys_data / IS_HK
            prefs.canted_aim_toggle_double_press_kb = false
            prefs.canted_aim_toggle_double_press_pad = true
            save_prefs()
            -- Breath-hold bindings live in re9holdbreath's own file; reset them here too so
            -- this stays the single reset for the whole Hotkeys menu.
            holdbreath.reset_hotkeys()
        end

        imgui.tree_pop()
        imgui.spacing()
        imgui.spacing()
    end
end)
