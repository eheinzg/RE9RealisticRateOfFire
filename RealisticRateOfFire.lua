-- RROF Editor for RE9

local RROF_DIR = "RROF/"
local DEFAULTS_PATH = RROF_DIR .. "defaults.json"
local PROFILES_DIR = RROF_DIR .. "profiles/"
local ROF_HOTKEYS_PATH = RROF_DIR .. "hotkeys.json"
local SETTINGS_PATH = RROF_DIR .. "settings.json"
local rof_edits = {}
local rof_defaults = {}
local rof_resolve_effective_weapon_key, rof_get_edit_or_fallback

local rof_settings_defaults = {
    enabled = true,                  -- the mod as a whole (RealisticRateOfFire.dll): off, the game's own values and behavior
    disable_regrip = true,
    regrip_mode = -1,          -- 0 on, 1 off, 2 on but not while shooting (RealisticRateOfFire.dll); -1: from disable_regrip
    disable_select_fire = false,
    smooth_semi_auto = true,
    smooth_burst = true,
    enable_aim_camera_shake = true,
    enable_recoil_anim_override = true,
    show_fire_mode_overlay = true,
    fire_mode_limit_semi_full = false,
    overlay_use_rects = false,
    overlay_style = 3,
    overlay_always_show = true,
    overlay_hk_color = 0x66FFFFFF,   -- the German style's color, 0xAABBGGRR (Default: the overlay's faint white)
    layer_recoil = true,             -- semi-auto and burst recoil blends like full-auto (RealisticRateOfFire.dll)
    debug_log = false,               -- our info lines in the REFramework log (and the DLL's shot probe): off in normal play
    active_profile = "",
    deleted_profiles = {},
}
local rof_settings = {}
do
    local saved = json.load_file(SETTINGS_PATH)
    if saved and type(saved) == "table" then
        for k, v in pairs(rof_settings_defaults) do
            if saved[k] ~= nil then rof_settings[k] = saved[k]
            else rof_settings[k] = v end
        end
    else
        for k, v in pairs(rof_settings_defaults) do rof_settings[k] = v end
    end
end

if rof_settings.regrip_mode == -1 or rof_settings.regrip_mode == nil then
    rof_settings.regrip_mode = rof_settings.disable_regrip and 1 or 2
end
-- (the always-on mode 0 is gone from the menu: On is mode 2, regrip between shots)
if rof_settings.regrip_mode == 0 then rof_settings.regrip_mode = 2 end

local function save_settings()
    json.dump_file(SETTINGS_PATH, rof_settings)
end

if rof_settings.overlay_style == nil or rof_settings.overlay_style == 1 then
    if not rof_settings.show_fire_mode_overlay then
        rof_settings.overlay_style = 0
    elseif rof_settings.overlay_use_rects then
        rof_settings.overlay_style = 2
    else
        rof_settings.overlay_style = 1
    end
end

-- "German" (cartridge pictograms) is drawn by RealisticRateOfFire.dll; when it cannot draw, this script shows circles for it
local OVERLAY_STYLES = { "None", "Circles", "Rectangles", "Text", "German" }

local WEAPON_NAMES = {
    ["arm0000"] = "Matilda IMP",
    ["arm0000_stock"] = "Matilda IMP (stock)",
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
    ["arm0400_leon"] = "Requiem (Leon)",
    ["arm0400_grace"] = "Requiem (Grace)",
    ["arm0500"] = "Gal",
    ["arm0501"] = "Stiri REVO3 A1",
    ["arm1002"] = "MP5",
    ["arm0503"] = "Clatter Carbine",
    ["arm0505"] = "Freya's Needle",
    ["arm0600"] = "Classic 70",
    ["arm0601"] = "Marksman 1A",
    ["arm0700"] = "RPG-7",
}

local WEAPON_KEYS = {
    "arm0000", "arm0000_stock",
    "arm0001", "arm0003", "arm0004", "arm0005", "arm0006", "arm0007",
    "arm0100", "arm0103", "arm0104",
    "arm0400_leon", "arm0400_grace",
    "arm0500", "arm0501", "arm1002", "arm0503", "arm0505", "arm0600", "arm0601", "arm0700"
}

local dropdown_options = {}
local dropdown_items = {}
local selected_index = 1
local last_equip_context_sig = nil

local ui_state = {
    type_of_shoot = 0,
    shot_interval = 0.6,
    burst_shot_interval = 5.0,
    burst_num = 3,
    enable_aim_camera_shake = rof_settings.enable_aim_camera_shake,
    recoil_rate = 1.0,
    recoil_yaw_s = 0.0,
    recoil_yaw_r = 0.0,
    recoil_pitch_s = 0.0,
    recoil_pitch_r = 0.0,
    status = ""
}

-- RealisticRateOfFire.dll does this mod's game work: the fire-mode logic, the execFire hook, regrip, the recoil animation
-- layer, the catalog edits and the overlay. It must have been loaded in this run of the game (its marker file is newer than
-- the game's start); without it this script changes nothing. This script keeps the menu, the profiles and the hotkeys, and
-- talks to the DLL two ways:
-- RealisticRateOfFire_Edits.json (NATIVE.sync: settings, edits, Default values and menu commands, written when the menu
-- changes something) and a byte array kept for good, handed over in RealisticRateOfFire_Bridge.json (offsets are the
-- DLL's Block struct: +0x24 hotkey presses in; +0x28 cycles done, +0x2C mode, +0x30 id, +0x40 row, +0x50 fire mode,
-- +0x54 smooth mode, +0x58 overlay flags out).
local NATIVE = { on = false, n = 0, cmds = {}, done = 0, nonce = os.time() + (os.clock() % 1) }
pcall(function()
    local d = json.load_file("RealisticRateOfFire_Loaded.json")
    if type(d) ~= "table" or type(d.t) ~= "number" then return end
    local up = sdk.call_native_func(sdk.get_native_singleton("via.Application"),
        sdk.find_type_definition("via.Application"), "get_UpTimeSecond")
    if d.t < os.time() - (tonumber(up) or 0) - 120 then return end
    local block = sdk.create_managed_array("System.Byte", 128):add_ref_permanent()
    block:write_dword(0x20, 0x464F5252)      -- the DLL's magic, "RROF"
    json.dump_file("RealisticRateOfFire_Bridge.json", { block = block:get_address() })
    NATIVE.block, NATIVE.on = block, true
end)
if not NATIVE.on then
    log.error("[RealisticRateOfFire] RealisticRateOfFire.dll is not loaded, so this mod changes nothing")
end
-- a dword the DLL wrote; nil for its -1
NATIVE.dword = function(off)
    local v = NATIVE.block:read_dword(0x20 + off)
    if v == nil or v == -1 or v == 0xFFFFFFFF then return nil end
    return v
end
NATIVE.str = function(off)
    local t = {}
    for i = 0, 15 do
        local c = NATIVE.block:read_byte(0x20 + off + i)
        if not c or c == 0 then break end
        t[#t + 1] = string.char(c)
    end
    return table.concat(t)
end
NATIVE.mode = function() return NATIVE.dword(0x34) end
NATIVE.shot_type = function() return NATIVE.dword(0x30) end
NATIVE.flags = function() return NATIVE.dword(0x38) or 0 end
NATIVE.press = function()
    NATIVE.block:write_dword(0x24, ((NATIVE.block:read_dword(0x24) or 0) + 1) & 0xFFFFFFFF)
end
-- a fire-mode cycle the DLL did: the same changes cycle_fire_mode made here
NATIVE.take = function()
    if not NATIVE.on then return end
    local d = NATIVE.block:read_dword(0x28) or 0
    if d == NATIVE.done then return end
    NATIVE.done = d
    local mode = NATIVE.block:read_dword(0x2C) or 0
    local eid, eff = NATIVE.str(0x10), NATIVE.str(0x20)
    local base_arm = (eid == "arm0000" or eid == "arm0400") and eid or nil
    local edit = rof_get_edit_or_fallback(eff, base_arm)
    if edit then edit.TypeOfShoot = mode end
    if selected_index and dropdown_items[selected_index] == eff then ui_state.type_of_shoot = mode end
    ui_state.status = ""
end
-- hands the DLL what the menu changed, with one command (op) when given
NATIVE.sync = function(op, extra)
    if not NATIVE.on then return end
    NATIVE.take()
    if op then
        NATIVE.n = NATIVE.n + 1
        local c = extra or {}
        c.n, c.op = NATIVE.n, op
        NATIVE.cmds[#NATIVE.cmds + 1] = c
        if #NATIVE.cmds > 16 then table.remove(NATIVE.cmds, 1) end
    end
    local known = {}
    for k in pairs(WEAPON_NAMES) do known[#known + 1] = k end
    pcall(json.dump_file, "RealisticRateOfFire_Edits.json", {
        nonce = NATIVE.nonce,
        settings = {
            enabled = rof_settings.enabled,
            disable_regrip = rof_settings.disable_regrip,
            regrip_mode = rof_settings.regrip_mode,
            disable_select_fire = rof_settings.disable_select_fire,
            smooth_semi_auto = rof_settings.smooth_semi_auto,
            smooth_burst = rof_settings.smooth_burst,
            enable_recoil_anim_override = rof_settings.enable_recoil_anim_override,
            fire_mode_limit_semi_full = rof_settings.fire_mode_limit_semi_full,
            enable_aim_camera_shake = ui_state.enable_aim_camera_shake,
            show_fire_mode_overlay = rof_settings.show_fire_mode_overlay,
            overlay_use_rects = rof_settings.overlay_use_rects,
            overlay_always_show = rof_settings.overlay_always_show,
            overlay_style = rof_settings.overlay_style,
            overlay_hk_color = rof_settings.overlay_hk_color,
            layer_recoil = rof_settings.layer_recoil,
            debug_log = rof_settings.debug_log,
        },
        known = known,
        edits = rof_edits,
        defaults = rof_defaults,
        cmds = NATIVE.cmds,
    })
end

local SHOOT_TYPES = { "Semi-Auto", "Full-Auto", "Burst" }

for i, key in ipairs(WEAPON_KEYS) do
    local label = WEAPON_NAMES[key] or key
    dropdown_items[i] = key
    dropdown_options[i] = label
end

--- Variant UI keys -> catalog arm id (must exist before early load_profile()).
local function rof_catalog_id_for_key(sel_key)
    if sel_key == "arm0000_stock" then return "arm0000" end
    if sel_key == "arm0400_leon" or sel_key == "arm0400_grace" then return "arm0400" end
    return sel_key
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
    profile_state.names = {}
    local deleted = {}
    if rof_settings.deleted_profiles and type(rof_settings.deleted_profiles) == "table" then
        for _, p in ipairs(rof_settings.deleted_profiles) do deleted[p] = true end
    end
    local ok, paths = pcall(fs.glob, [[RROF\\profiles\\.*]])
    if ok and paths then
        local seen = {}
        for _, path in ipairs(paths) do
            local name = path:match("RROF[/\\]profiles[/\\]([^/\\]+)%.json$")
            if name and not seen[name] and not deleted[name] then
                seen[name] = true
                profile_state.names[#profile_state.names + 1] = name
            end
        end
    end
    table.sort(profile_state.names)
    if rof_settings.active_profile and type(rof_settings.active_profile) == "string" then
        for i, n in ipairs(profile_state.names) do
            if n == rof_settings.active_profile then profile_state.selected = i; break end
        end
    end
    if profile_state.selected > #profile_state.names then
        profile_state.selected = math.max(1, #profile_state.names)
    end
end

local function save_profile_index()
    rof_settings.active_profile = profile_state.names[profile_state.selected] or ""
    save_settings()
end

local function save_profile(name)
    local data = {
        enable_aim_camera_shake = ui_state.enable_aim_camera_shake,
        edits = rof_edits,
    }
    pcall(json.dump_file, PROFILES_DIR .. name .. ".json", data)
    if rof_settings.deleted_profiles then
        for i, p in ipairs(rof_settings.deleted_profiles) do
            if p == name then table.remove(rof_settings.deleted_profiles, i); break end
        end
    end
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

local function get_recoil_for_key(key)
    local edit = rof_edits[key]
    if edit and edit.recoil then return edit.recoil end
    local def = rof_defaults[key]
    if def and def.recoil then return def.recoil end
    return nil
end

local function populate_ui_from_vals(vals, key)
    if not vals then return end
    ui_state.type_of_shoot = vals.TypeOfShoot or 0
    ui_state.shot_interval = vals.ShotInterval or 0.6
    ui_state.burst_shot_interval = vals.BurstShotInterval or 5.0
    ui_state.burst_num = vals.BurstNum or 3
    local r = vals.recoil or get_recoil_for_key(key)
    if r then
        ui_state.recoil_rate = r.rate or 1.0
        ui_state.recoil_yaw_s = r.yaw_s or 0
        ui_state.recoil_yaw_r = r.yaw_r or 0
        ui_state.recoil_pitch_s = r.pitch_s or 0
        ui_state.recoil_pitch_r = r.pitch_r or 0
    end
end

local function deep_copy_weapon_edit(src)
    if type(src) ~= "table" then return nil end
    local out = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            out[k] = deep_copy_weapon_edit(v)
        else
            out[k] = v
        end
    end
    return out
end

--- After "Disable All", rof_edits[key] was replaced with defaults; reload this slot from the selected profile JSON.
local function restore_weapon_edit_from_active_profile(weapon_key)
    local pname = profile_state.names[profile_state.selected]
    if not pname or not weapon_key then return false end
    local ok, data = pcall(json.load_file, PROFILES_DIR .. pname .. ".json")
    if not ok or not data or type(data.edits) ~= "table" then return false end
    local disk = data.edits[weapon_key]
    if type(disk) ~= "table" then return false end
    rof_edits[weapon_key] = deep_copy_weapon_edit(disk)
    rof_edits[weapon_key].disabled = nil
    populate_ui_from_vals(rof_edits[weapon_key], weapon_key)
    return true
end

local function get_weapon_smooth_burst(weapon_key)
    local edit = weapon_key and rof_edits[weapon_key]
    if edit and edit.disabled then return false end
    if not rof_settings.smooth_burst then return false end
    if edit and edit.smooth_burst ~= nil then return edit.smooth_burst end
    return rof_settings.smooth_burst
end

local function load_profile(name)
    local ok, data = pcall(json.load_file, PROFILES_DIR .. name .. ".json")
    if ok and data then
        rof_edits = data.edits or {}
        if data.enable_aim_camera_shake ~= nil then
            ui_state.enable_aim_camera_shake = data.enable_aim_camera_shake
        end
        local key = dropdown_items[selected_index]
        if key then
            populate_ui_from_vals(rof_edits[key] or rof_defaults[key] or rof_defaults[rof_catalog_id_for_key(key)], key)
        end
        return true
    end
    return false
end

local function delete_profile(name)
    pcall(json.dump_file, PROFILES_DIR .. name .. ".json", {})
    if not rof_settings.deleted_profiles then rof_settings.deleted_profiles = {} end
    local already = false
    for _, p in ipairs(rof_settings.deleted_profiles) do
        if p == name then already = true; break end
    end
    if not already then
        rof_settings.deleted_profiles[#rof_settings.deleted_profiles + 1] = name
    end
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

local DEFAULT_PROFILE_NAME = "Realistic Rate of Fire"

load_profile_index()
if #profile_state.names > 0 and profile_state.names[profile_state.selected] then
    load_profile(profile_state.names[profile_state.selected])
elseif next(rof_edits) == nil then
    local ok, data = pcall(json.load_file, PROFILES_DIR .. DEFAULT_PROFILE_NAME .. ".json")
    if ok and data and data.edits then
        rof_edits = data.edits
        if data.enable_aim_camera_shake ~= nil then
            ui_state.enable_aim_camera_shake = data.enable_aim_camera_shake
        end
        if not profile_state.names or #profile_state.names == 0 then
            profile_state.names = { DEFAULT_PROFILE_NAME }
            profile_state.selected = 1
            save_profile_index()
        end
        local key = dropdown_items[selected_index]
        if key then
            populate_ui_from_vals(rof_edits[key] or rof_defaults[key] or rof_defaults[rof_catalog_id_for_key(key)], key)
        end
    end
end

local TYPE_PlayerEquipment = sdk.typeof("app.PlayerEquipment")
local TYPE_PlayerMagazineGun = sdk.typeof("app.PlayerMagazineGun")
local TYPE_WeaponCatalogRegister = sdk.typeof("app.WeaponCatalogRegister")
local TYPE_Motion = sdk.typeof("via.motion.Motion")
local TYPE_BodyAddCtrlDriver = sdk.typeof("app.BodyAddCtrlDriver")


local function try_call(obj, method)
    local r; pcall(function() r = obj:call(method) end); return r
end

local function try_field(obj, name)
    local r; pcall(function() r = obj:get_field(name) end); return r
end

local function resolve_camera_recoil(weapon_data)
    if not weapon_data then return nil end
    local wp = try_field(weapon_data, "WeaponParameter") or try_field(weapon_data, "_WeaponParameter")
    if not wp then return nil end
    return try_field(wp, "_CameraRecoilParam") or try_field(wp, "CameraRecoilParam")
end

local function resolve_shot_camera_shake_move(weapon_data)
    if not weapon_data then return nil end
    local wp = try_field(weapon_data, "WeaponParameter") or try_field(weapon_data, "_WeaponParameter")
    if not wp then return nil end
    local scsp = try_field(wp, "_ShotCameraShakeParam") or try_field(wp, "ShotCameraShakeParam")
    if not scsp then return nil end
    return try_field(scsp, "_Move") or try_field(scsp, "Move")
end

local function read_shot_camera_shake_move(weapon_data)
    local move = resolve_shot_camera_shake_move(weapon_data)
    if not move then return nil end
    local tx = try_field(move, "_TranslationXRange")
    local ty = try_field(move, "_TranslationYRange")
    local tz = try_field(move, "_TranslationZRange")
    if not tx and not ty and not tz then return nil end
    return {
        tx_s = tx and tonumber(tx.s) or 0, tx_r = tx and tonumber(tx.r) or 0,
        ty_s = ty and tonumber(ty.s) or 0, ty_r = ty and tonumber(ty.r) or 0,
        tz_s = tz and tonumber(tz.s) or 0, tz_r = tz and tonumber(tz.r) or 0,
    }
end

local function read_recoil_values(crp)
    if not crp then return nil end
    local yaw = try_field(crp, "_YawRangeDeg")
    local pitch = try_field(crp, "_PitchRangeDeg")
    if not yaw or not pitch then return nil end
    local rate = try_field(crp, "_Rate")
    return {
        rate = tonumber(rate) or 1.0,
        yaw_s = tonumber(yaw.s) or 0,
        yaw_r = tonumber(yaw.r) or 0,
        pitch_s = tonumber(pitch.s) or 0,
        pitch_r = tonumber(pitch.r) or 0,
    }
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
    do
        local obj = scene:call("findGameObject(System.String)", "WeaponCatalog")
        if obj then
            local addr = obj:get_address()
            if not seen[addr] then
                seen[addr] = true
                results[#results + 1] = obj
            end
        end
    end
    if TYPE_WeaponCatalogRegister then
        local all_components = nil
        pcall(function() all_components = scene:call("findComponents(System.Type)", TYPE_WeaponCatalogRegister) end)
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

local REGISTER_TYPES = {}
do
    for _, tn in ipairs({ "app.WeaponCatalogRegister", "chainsaw.WeaponCatalogRegister" }) do
        local t = sdk.typeof(tn)
        if t then REGISTER_TYPES[#REGISTER_TYPES + 1] = t end
    end
end

local function get_register(catalog)
    if not catalog then return nil end
    for _, t in ipairs(REGISTER_TYPES) do
        local r = catalog:call("getComponent(System.Type)", t)
        if r then return r end
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

local WEAPON_ID_FIELDS = { "_WeaponID", "WeaponID", "_WeaponId" }

local function get_entry_id(weapon_data)
    if not weapon_data then return nil end
    for _, f in ipairs(WEAPON_ID_FIELDS) do
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

local function find_weapon_data_by_key(target_key)
    local catalogs = find_all_catalogs(get_scene())
    for _, catalog in ipairs(catalogs) do
        local dt = get_data_table(get_register(catalog))
        if dt then
            local count = 0; pcall(function() count = dt:call("get_Count") end)
            for i = 0, count - 1 do
                local wd; pcall(function() wd = dt:call("get_Item", i) end)
                if wd then
                    local id = get_entry_id(wd)
                    if id == target_key then return wd end
                end
            end
        end
    end
    return nil
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
                    if id == rof_catalog_id_for_key(weapon_key) then
                        local sd = resolve_shoot_data(wd)
                        if sd then
                            local vals = {
                                TypeOfShoot = tonumber(try_field(sd, "TypeOfShoot")) or 0,
                                ShotInterval = tonumber(try_field(sd, "ShotInterval")) or 0.6,
                                BurstShotInterval = tonumber(try_field(sd, "BurstShotInterval")) or 5.0,
                                BurstNum = tonumber(try_field(sd, "BurstNum")) or 3,
                            }
                            local crp = resolve_camera_recoil(wd)
                            local recoil = read_recoil_values(crp)
                            if recoil then
                                vals.recoil = recoil
                            end
                            local scsm = read_shot_camera_shake_move(wd)
                            if scsm then
                                vals.shot_camera_shake_move = scsm
                            end
                            return vals
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
                            local entry = {
                                TypeOfShoot = tonumber(tos) or 0,
                                ShotInterval = tonumber(si) or 0.6,
                                BurstShotInterval = tonumber(bsi) or 5.0,
                                BurstNum = tonumber(bn) or 3,
                                EnableAimCameraShake = acs_default
                            }
                            local crp = resolve_camera_recoil(wd)
                            local recoil = read_recoil_values(crp)
                            if recoil then
                                entry.recoil = recoil
                            end
                            local scsm = read_shot_camera_shake_move(wd)
                            if scsm then
                                entry.shot_camera_shake_move = scsm
                            end
                            entry.recoil_anim_enabled = false
                            entry.recoil_anim_force = 1.0
                            entry.recoil_anim_speed = 1.0
                            defaults[id] = entry
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
NATIVE.sync()

local function get_player()
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    if not cm then return nil end
    local ctx = nil
    pcall(function() ctx = cm:call("getPlayerContextRef") end)
    return ctx
end

local function get_player_equipment()
    local ctx = get_player()
    if not ctx then return nil end
    local go = nil
    pcall(function() go = ctx:call("get_GameObject") end)
    if not go or not TYPE_PlayerEquipment then return nil end
    local pe = nil
    pcall(function() pe = go:call("getComponent(System.Type)", TYPE_PlayerEquipment) end)
    return pe
end

local function get_player_magazine_gun()
    local pe = get_player_equipment()
    if not pe then return nil end
    local weapon = nil
    pcall(function() weapon = pe:call("getEquipWeapon") end)
    if not weapon then return nil end
    local go = nil
    pcall(function() go = weapon:call("get_GameObject") end)
    if not go or not TYPE_PlayerMagazineGun then return nil end
    local mg = nil
    pcall(function() mg = go:call("getComponent(System.Type)", TYPE_PlayerMagazineGun) end)
    return mg
end

local function get_weapon_id_from_pe(pe)
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

local function get_equipped_weapon_id()
    local pe = get_player_equipment()
    if not pe then return nil, nil end
    return get_weapon_id_from_pe(pe), pe
end

local cached_pe = nil
local cached_eid = nil
local cached_frame = -1

local function get_equipped_weapon_id_cached()
    local frame = re.get_frame_count and re.get_frame_count() or -1
    if frame == cached_frame and cached_pe then
        return cached_eid, cached_pe
    end
    cached_pe = get_player_equipment()
    cached_eid = get_weapon_id_from_pe(cached_pe)
    cached_frame = frame
    return cached_eid, cached_pe
end

--- Stock on Matilda: same as vanilla attach shoot data (burst gating uses this).
local function matilda_stock_attached()
    local mg = get_player_magazine_gun()
    if not mg then return false end
    return try_field(mg, "_IsUseAttachShootData") == true
end

local function player_is_leon()
    local ctx = get_player()
    if not ctx then return true end
    local is_a0 = nil
    pcall(function() is_a0 = ctx:call("get_IsCp_A0Character") end)
    return is_a0 == true
end

--- Which rof_edits row applies for the currently equipped catalog id.
rof_resolve_effective_weapon_key = function(base_id)
    if not base_id then return nil end
    if base_id == "arm0000" then
        return matilda_stock_attached() and "arm0000_stock" or "arm0000"
    end
    if base_id == "arm0400" then
        return player_is_leon() and "arm0400_leon" or "arm0400_grace"
    end
    return base_id
end

rof_get_edit_or_fallback = function(eff, base_id)
    if not eff then return nil end
    if rof_edits[eff] then return rof_edits[eff] end
    if base_id and rof_edits[base_id] then return rof_edits[base_id] end
    return nil
end

--- For auto-switching the editor when stock attaches or character changes.
local function rof_equip_context_signature()
    local base = get_equipped_weapon_id_cached()
    if not base then return nil end
    if base == "arm0000" then
        return base .. ":" .. tostring(matilda_stock_attached())
    end
    if base == "arm0400" then
        return base .. ":" .. (player_is_leon() and "leon" or "grace")
    end
    return base
end

--- Has the DLL push `edit`'s shot fields to the PlayerEquipment when it is the active row for what is equipped.
local function push_live_player_equipment_shoot_data(edit)
    if not edit then return end
    for k, v in pairs(rof_edits) do
        if v == edit then NATIVE.sync("push_key", { key = k }); break end
    end
end

local function push_live_for_current_equipment()
    NATIVE.sync("push_current")
end

local function apply_to_equipped(weapon_key, edit)
    if not weapon_key or not edit or edit.disabled then return false end
    local eid_str, pe = get_equipped_weapon_id()
    if not pe or not eid_str then return false end
    if rof_catalog_id_for_key(weapon_key) ~= eid_str then return false end
    local eff_now = rof_resolve_effective_weapon_key(eid_str)
    if weapon_key ~= eff_now then return false end
    push_live_player_equipment_shoot_data(edit)
    return true
end

--- When this profile row matches equipped weapon, set live fire mode (used if edit.disabled blocks apply_to_equipped).
local function push_equip_shot_type_if_matches(weapon_key, type_of_shoot)
    if not weapon_key or type_of_shoot == nil then return end
    local eid_str, pe = get_equipped_weapon_id()
    if not pe or not eid_str then return end
    if rof_catalog_id_for_key(weapon_key) ~= eid_str then return end
    local eff_now = rof_resolve_effective_weapon_key(eid_str)
    if weapon_key ~= eff_now then return end
    local v = math.floor(tonumber(type_of_shoot) + 0.5)
    NATIVE.sync("set_type", { v = v })
end

-- Hotkey system for fire mode toggle
local hk = require("Hotkeys/Hotkeys")
local FIRE_MODE_NAMES = { [0] = "Semi-Auto", [1] = "Full-Auto", [2] = "Burst" }
local show_fire_mode_overlay = rof_settings.show_fire_mode_overlay

local rof_hk_default_settings = {
    use_modifier = false,
    use_pad_modifier = true,
    hotkeys = {
        ["Fire Mode Modifier"] = "R Mouse",
        ["Fire Mode Toggle"] = "B",
        ["Pad Fire Mode Modifier"] = "LT (L2)",
        ["Pad Fire Mode Toggle"] = "A (X)",
    }
}
local rof_hk_settings = hk.recurse_def_settings(json.load_file(ROF_HOTKEYS_PATH) or {}, rof_hk_default_settings)
hk.setup_hotkeys(rof_hk_settings.hotkeys)

-- the fire mode the DLL shows (its smooth semi-auto and burst modes); nil when none
local function smooth_get_display_mode()
    if NATIVE.on then return NATIVE.mode() end
    return nil
end

-- Read-only export for other scripts (MP5Revo3.lua turns the MP5's selector lever with it):
-- the fire mode the player sees, 0 = Semi-Auto, 1 = Full-Auto, 2 = Burst (smooth modes included).
_G.RealisticRateOfFire = _G.RealisticRateOfFire or {}
_G.RealisticRateOfFire.get_fire_mode = function()
    if not NATIVE.on then return nil end
    return NATIVE.mode() or NATIVE.shot_type()
end

local toggle_was_down = false

if NATIVE.on then
re.on_application_entry("UpdateBehavior", function()
    local km = (not rof_hk_settings.use_modifier or hk.check_hotkey("Fire Mode Modifier", true)) and hk.check_hotkey("Fire Mode Toggle", true)
    local pad = (not rof_hk_settings.use_pad_modifier or hk.check_hotkey("Pad Fire Mode Modifier", true)) and hk.check_hotkey("Pad Fire Mode Toggle", true)
    local is_down = km or pad
    if is_down and not toggle_was_down then NATIVE.press() end      -- the DLL cycles the mode
    toggle_was_down = is_down or false
    NATIVE.take()
end)
end

local function get_player_motion()
    local ctx = get_player()
    if not ctx then return nil end
    local go = nil
    pcall(function() go = ctx:call("get_GameObject") end)
    if not go or not TYPE_Motion then return nil end
    local motion = nil
    pcall(function() motion = go:call("getComponent(System.Type)", TYPE_Motion) end)
    return motion
end

local function get_player_mfsm2()
    local ctx = get_player()
    if not ctx then return nil end
    local updater = nil
    pcall(function() updater = ctx:get_field("<Updater>k__BackingField") end)
    if not updater then return nil end
    local mfsm2 = nil
    pcall(function() mfsm2 = updater:get_field("<MotionFsm>k__BackingField") end)
    return mfsm2
end

local _cached_bac_driver = nil

local function get_body_add_ctrl_layer()
    local ctx = get_player()
    if not ctx then return nil, nil end
    local go = nil
    pcall(function() go = ctx:call("get_GameObject") end)
    if not go or not TYPE_BodyAddCtrlDriver then return nil, nil end
    local driver = nil
    pcall(function() driver = go:call("getComponent(System.Type)", TYPE_BodyAddCtrlDriver) end)
    if not driver then return nil, nil end
    _cached_bac_driver = driver
    local layer = nil
    pcall(function() layer = driver:get_field("<Layer>k__BackingField") end)
    return layer, driver
end

-- (Motion layer debug variables - kept for UI but inactive unless live logging enabled)
-- local regrip_action_log = {}
-- local regrip_hook_status = "searching..."
local _motion_layer_dump = nil
local _motion_live_logging = false
local _fsm_hash_log = {}
local _FSM_LOG_MAX = 30
local _action_hash_log = {}
local _ACTION_LOG_MAX = 30


-- the DLL applies the edits when it reads the file
local function apply_all_now()
    NATIVE.sync()
end

--- Rebuild rof_edits[key] from captured rof_defaults[key]. If keep_disabled, set disabled = true (vanilla + skip future edits).
local function reset_weapon_edits_from_defaults(key, keep_disabled)
    local def_key = rof_catalog_id_for_key(key)
    if not key or not rof_defaults[def_key] then return false end
    local def = rof_defaults[def_key]
    rof_edits[key] = {
        TypeOfShoot = def.TypeOfShoot,
        ShotInterval = def.ShotInterval,
        BurstShotInterval = def.BurstShotInterval,
        BurstNum = def.BurstNum,
        recoil = def.recoil and {
            rate = def.recoil.rate,
            yaw_s = def.recoil.yaw_s,
            yaw_r = def.recoil.yaw_r,
            pitch_s = def.recoil.pitch_s,
            pitch_r = def.recoil.pitch_r,
        } or nil,
        shot_camera_shake_move = def.shot_camera_shake_move and {
            tx_s = def.shot_camera_shake_move.tx_s,
            tx_r = def.shot_camera_shake_move.tx_r,
            ty_s = def.shot_camera_shake_move.ty_s,
            ty_r = def.shot_camera_shake_move.ty_r,
            tz_s = def.shot_camera_shake_move.tz_s,
            tz_r = def.shot_camera_shake_move.tz_r,
        } or nil,
        recoil_anim_enabled = def.recoil_anim_enabled or false,
        recoil_anim_force = def.recoil_anim_force or 1.0,
        recoil_anim_speed = def.recoil_anim_speed or 1.0,
        smooth_semi = nil,
        smooth_burst = nil,
        disabled = keep_disabled and true or nil,
    }
    populate_ui_from_vals(def, key)
    apply_all_now()
    push_live_player_equipment_shoot_data(rof_edits[key])
    return true
end

-- The menu, drawn through W: REFramework's menu (W_IMGUI below) or another mod's window, which hands over its own rows
-- (Mercenaries' Extras: _G.RealisticRateOfFire.draw_menu(W)). Every control sits in a W.card. W's calls:
--   card(id, title, fill, closed)  check(label, v, tip)  combo(label, idx, names, tip)  float(label, v, speed, lo, hi, fmt, tip)
--   button(label, text, tip)  same_line()  text(s, color)  value(label, value)  input(label, s, tip)  color(label, col, tip)
--   W.merc: keys(rows), rows = { { name, keyboard action, pad action }, ... }
local W_IMGUI = {}
function W_IMGUI.card(id, title, fill, closed)
    if closed then
        if imgui.tree_node(title .. "##rrof_" .. id) then
            fill()
            imgui.tree_pop()
        end
        return
    end
    fill()
    imgui.separator()
end
local function imgui_tip(tip) if tip and imgui.is_item_hovered() then imgui.set_tooltip(tip) end end
function W_IMGUI.check(label, v, tip)
    local c, nv = imgui.checkbox(label, v)
    imgui_tip(tip)
    return c, nv
end
function W_IMGUI.combo(label, idx, names, tip)
    local c, nv = imgui.combo(label, idx, names)
    imgui_tip(tip)
    return c, nv
end
function W_IMGUI.float(label, v, speed, lo, hi, fmt, tip)
    local c, nv = imgui.drag_float(label, v, speed, lo, hi, fmt)
    imgui_tip(tip)
    return c, nv
end
function W_IMGUI.button(label, text, tip)
    local _, id = label:match("^(.-)##(.*)$")
    local pressed = imgui.button((text or label) .. "##" .. (id or label))
    imgui_tip(tip)
    return pressed
end
function W_IMGUI.same_line() imgui.same_line() end
function W_IMGUI.text(s, color) imgui.text_colored(s, color or 0xFFFFFFFF) end
function W_IMGUI.value(label, value) imgui.text_colored(label .. ": " .. value, 0xFFFFFF00) end
function W_IMGUI.input(label, s, tip)
    local c, nv = imgui.input_text(label, s)
    imgui_tip(tip)
    return c, nv
end
function W_IMGUI.color(label, col, tip)
    local c, nv = imgui.color_edit(label, col)
    imgui_tip(tip)
    return c, nv
end

local function draw_menu(W)
    local changed

    W.card("main", "Realistic Rate of Fire", function()
        if not NATIVE.on then
            W.text("RealisticRateOfFire.dll is not loaded: these settings change nothing in the game", 0xFF4444FF)
        end
        -- the mod as a whole (user: "add an on of switch for teh realistic rate of fire as a whole so it completely disables
        -- the mod"): off, the DLL does no game work and puts back the game's own values it changed
        local en_changed
        en_changed, rof_settings.enabled = W.check("Realistic Rate of Fire##rrof_enabled", rof_settings.enabled ~= false,
            "Off: the game's own fire modes, rates, recoil, regrip and camera shake, as if the mod were not installed")
        if en_changed then
            NATIVE.sync()
            save_settings()
            ui_state.status = "Realistic Rate of Fire " .. (rof_settings.enabled and "on" or "off")
        end
        if not W.merc then
            W.text("Toggle Fire Mode With Assigned Hotkey (Default: B or L2(Left Trigger)+A(X))", 0xFFFFFF00)
        end

        if #profile_state.names > 0 then
            local prof_changed
            prof_changed, profile_state.selected = W.combo("Profile##rrof_profile", profile_state.selected, profile_state.names)
            if profile_state.selected < 1 then profile_state.selected = 1 end
            if profile_state.selected > #profile_state.names then profile_state.selected = #profile_state.names end
            if prof_changed then
                local pname = profile_state.names[profile_state.selected]
                if pname and load_profile(pname) then
                    apply_all_now()
                    push_live_for_current_equipment()
                    save_profile_index()
                    ui_state.status = "Loaded profile: " .. pname
                end
            end
            if W.button("Save the profile##rrof_save", "Save") then
                local pname = profile_state.names[profile_state.selected]
                if pname then
                    save_profile(pname)
                    ui_state.status = "Profile saved: " .. pname
                end
            end
            W.same_line()
            if W.button("Delete the profile##rrof_delete", "Delete") then
                local pname = profile_state.names[profile_state.selected]
                if pname then
                    delete_profile(pname)
                    ui_state.status = "Deleted profile: " .. pname
                end
            end
            W.same_line()
        end
        if W.button("New profile##rrof_new", "New Profile") then
            profile_state.naming = not profile_state.naming
        end
        if profile_state.naming then
            local buf_changed
            buf_changed, profile_state.name_buf = W.input("Name##rrof_name", profile_state.name_buf)
            W.same_line()
            if W.button("Create the profile##rrof_create", "Create") then
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
                W.same_line()
                W.text(ui_state.status, 0xFF00FFFF)
            end
        end
        if ui_state.status:match("^Profile saved:") or ui_state.status:match("^Deleted profile:") then
            W.text(ui_state.status, ui_state.status:match("^Deleted") and 0xFF5555FF or 0xFF00FF00)
        end
    end)

    -- the weapon picked in the list, its settings in the cards below
    local any_changed = false
    local weapon_disabled = false
    W.card("weapon", "Weapon", function()
        local equipped_key, pe = get_equipped_weapon_id_cached()
        if pe and equipped_key then
            local eid_name = WEAPON_NAMES[equipped_key]
            local is_known = eid_name ~= nil
            if equipped_key == "arm0400" then
                eid_name = player_is_leon() and WEAPON_NAMES["arm0400_leon"] or WEAPON_NAMES["arm0400_grace"]
                is_known = eid_name ~= nil
            elseif equipped_key == "arm0000" and matilda_stock_attached() then
                eid_name = WEAPON_NAMES["arm0000_stock"]
                is_known = true
            end
            eid_name = eid_name or equipped_key
            if is_known then
                local current_type = 0
                pcall(function() current_type = pe:get_field("_EquipShotType") end)
                current_type = smooth_get_display_mode() or tonumber(current_type) or 0
                eid_name = eid_name .. " (" .. (FIRE_MODE_NAMES[current_type] or "?") .. ")"
            end
            -- (no Equipped line in any menu: user, "dont show the equipped or current weapon stat in the menus")

            -- Auto-select weapon row when equip id, stock, or character context changes
            local sig_now = rof_equip_context_signature()
            if sig_now and sig_now ~= last_equip_context_sig then
                local eff = rof_resolve_effective_weapon_key(equipped_key)
                for i, key in ipairs(dropdown_items) do
                    if key == eff then
                        selected_index = i
                        local vals = rof_edits[key] or rof_defaults[key] or rof_defaults[rof_catalog_id_for_key(key)]
                            or read_live_values(key)
                        populate_ui_from_vals(vals, key)
                        break
                    end
                end
                last_equip_context_sig = sig_now
            end
        else
        end

        changed, selected_index = W.combo("Weapon##rrof_weapon", selected_index, dropdown_options)
        if selected_index < 1 then selected_index = 1 end
        if selected_index > #dropdown_items then selected_index = #dropdown_items end
        if changed then
            local key = dropdown_items[selected_index]
            local vals = rof_edits[key] or rof_defaults[key] or rof_defaults[rof_catalog_id_for_key(key)]
                or read_live_values(key)
            populate_ui_from_vals(vals, key)
        end

        local key = dropdown_items[selected_index]
        if key then
            local edit = rof_edits[key]
            if not edit then edit = {}; rof_edits[key] = edit end
            local dis_changed, dis_new = W.check("Disable All Modifications##pw_dis", edit.disabled or false,
                "Skip all mod edits for this weapon — it will use vanilla game values")
            if dis_changed then
                if dis_new then
                    NATIVE.sync("kill_semi")
                    NATIVE.sync("kill_burst")
                    if reset_weapon_edits_from_defaults(key, true) then
                        ui_state.status = "Disabled all mods (restored defaults): " .. (WEAPON_NAMES[key] or key)
                    else
                        edit.disabled = true
                        apply_all_now()
                        ui_state.status = "Disabled all mods (no captured defaults — capture first to restore vanilla): " .. (WEAPON_NAMES[key] or key)
                    end
                else
                    local restored = restore_weapon_edit_from_active_profile(key)
                    if not restored and rof_edits[key] then
                        rof_edits[key].disabled = nil
                    end
                    apply_all_now()
                    push_live_for_current_equipment()
                    if restored then
                        ui_state.status = (WEAPON_NAMES[key] or key) .. " modifications enabled (from profile)"
                    else
                        ui_state.status = (WEAPON_NAMES[key] or key)
                            .. " modifications enabled (no entry in profile file — save profile to persist)"
                    end
                end
            end
            local cur_edit = rof_edits[key]
            weapon_disabled = (cur_edit and cur_edit.disabled) or false
        end

        if weapon_disabled then
            W.text("(All modifications disabled for this weapon)", 0xFF8888FF)
            local shoot_idx = math.floor(ui_state.type_of_shoot + 1)
            if shoot_idx < 1 then shoot_idx = 1 end
            if shoot_idx > 3 then shoot_idx = 3 end
            local d_changed, d_new = W.combo("TypeOfShoot (hotkey cycling off for this weapon)##pw_dis", shoot_idx, SHOOT_TYPES,
                "Same idea as global Disable Select Fire: use this dropdown instead of the fire-mode hotkey while this weapon has all modifications disabled.")
            if d_changed and key then
                ui_state.type_of_shoot = d_new - 1
                if not rof_edits[key] then rof_edits[key] = {} end
                rof_edits[key].TypeOfShoot = math.floor(ui_state.type_of_shoot + 0.5)
                apply_all_now()
                push_equip_shot_type_if_matches(key, ui_state.type_of_shoot)
                ui_state.status = "Fire mode: " .. (SHOOT_TYPES[d_new] or tostring(d_new))
            end
            return
        end

        if key then
            local edit = rof_edits[key]
            if edit.allow_semi == nil then edit.allow_semi = true end
            if edit.allow_full == nil then edit.allow_full = true end
            if edit.allow_burst == nil then edit.allow_burst = true end

            local tip = "Select which fire modes are available when cycling with the hotkey"
            local sc; sc, edit.allow_semi = W.check("Semi##allow", edit.allow_semi, tip)
            W.same_line()
            local fc; fc, edit.allow_full = W.check("Full-Auto##allow", edit.allow_full, tip)
            W.same_line()
            local bc; bc, edit.allow_burst = W.check("Burst##allow", edit.allow_burst, tip)
            if not edit.allow_semi and not edit.allow_full and not edit.allow_burst then
                edit.allow_semi = true
            end
            if sc or fc or bc then NATIVE.sync() end

            local g_semi = rof_settings.smooth_semi_auto
            local g_burst = rof_settings.smooth_burst
            if not g_semi then edit.smooth_semi = nil end
            if not g_burst then edit.smooth_burst = nil end
            if g_semi then
                local pw_semi = edit.smooth_semi
                if pw_semi == nil then pw_semi = g_semi end
                local pss_changed
                pss_changed, pw_semi = W.check("Improved Semi-Auto##pw", pw_semi, "Semi-Auto animations layer properly")
                if pss_changed then
                    edit.smooth_semi = pw_semi
                    NATIVE.sync(not pw_semi and "kill_semi" or nil)
                end
            end
            if g_burst then
                if g_semi then W.same_line() end
                local pw_burst = edit.smooth_burst
                if pw_burst == nil then pw_burst = g_burst end
                local psb_changed
                psb_changed, pw_burst = W.check("Improved Burst##pw", pw_burst, "Burst animations layer properly")
                if psb_changed then
                    edit.smooth_burst = pw_burst
                    NATIVE.sync(not pw_burst and "kill_burst" or nil)
                end
            end
        end

        if rof_settings.disable_select_fire then
            local shoot_idx = math.floor(ui_state.type_of_shoot + 1)
            if shoot_idx < 1 then shoot_idx = 1 end
            if shoot_idx > 3 then shoot_idx = 3 end
            changed, shoot_idx = W.combo("TypeOfShoot", shoot_idx, SHOOT_TYPES)
            if changed then ui_state.type_of_shoot = shoot_idx - 1; any_changed = true end
        end

        changed, ui_state.shot_interval = W.float("ShotInterval", ui_state.shot_interval, 0.01, 0.0, 10.0)
        if changed then any_changed = true end
        if not get_weapon_smooth_burst(key) then
            changed, ui_state.burst_shot_interval = W.float("BurstShotInterval", ui_state.burst_shot_interval, 0.01, 0.0, 10.0)
            if changed then any_changed = true end
        end
        changed, ui_state.burst_num = W.float("BurstNum", ui_state.burst_num, 1.0, 0.0, 20.0, "%.0f")
        if changed then any_changed = true end
    end)

    if not weapon_disabled then
        W.card("recoil", "Camera Recoil", function()
            changed, ui_state.recoil_rate = W.float("Rate", ui_state.recoil_rate, 0.01, 0.0, 10.0, "%.3f")
            if changed then any_changed = true end
            changed, ui_state.recoil_yaw_s = W.float("Yaw Min", ui_state.recoil_yaw_s, 0.01, -10.0, 10.0, "%.3f")
            if changed then any_changed = true end
            changed, ui_state.recoil_yaw_r = W.float("Yaw Max", ui_state.recoil_yaw_r, 0.01, -10.0, 10.0, "%.3f")
            if changed then any_changed = true end
            changed, ui_state.recoil_pitch_s = W.float("Pitch Min", ui_state.recoil_pitch_s, 0.01, -10.0, 10.0, "%.3f")
            if changed then any_changed = true end
            changed, ui_state.recoil_pitch_r = W.float("Pitch Max", ui_state.recoil_pitch_r, 0.01, -10.0, 10.0, "%.3f")
            if changed then any_changed = true end
        end)

        if rof_settings.enable_recoil_anim_override then
            W.card("anim", "Recoil Animation", function()
                local bac_layer = get_body_add_ctrl_layer()
                if not bac_layer then
                    W.text("(not found)")
                    return
                end
                local br = 0; pcall(function() br = bac_layer:call("get_BlendRate") end)
                local spd = 0; pcall(function() spd = bac_layer:call("get_Speed") end)

                local wkey = dropdown_items[selected_index]
                local wedit = wkey and rof_edits[wkey]
                local ra_enabled = wedit and wedit.recoil_anim_enabled or false
                local ra_force = wedit and wedit.recoil_anim_force or 1.0
                local ra_speed = wedit and wedit.recoil_anim_speed or 1.0

                local lock_changed, lock_new = W.check("Enable##recoil_anim", ra_enabled)
                if lock_changed and wkey then
                    if not rof_edits[wkey] then rof_edits[wkey] = {} end
                    rof_edits[wkey].recoil_anim_enabled = lock_new
                    if lock_new then
                        if not rof_edits[wkey].recoil_anim_force then rof_edits[wkey].recoil_anim_force = br end
                        if not rof_edits[wkey].recoil_anim_speed then rof_edits[wkey].recoil_anim_speed = spd end
                    end
                    ra_enabled = lock_new
                    ra_force = rof_edits[wkey].recoil_anim_force or 1.0
                    ra_speed = rof_edits[wkey].recoil_anim_speed or 1.0
                    NATIVE.sync()
                end

                if ra_enabled then
                    local br_changed, br_new = W.float("Recoil Animation Force", ra_force, 0.01, 0.0, 1.0)
                    if br_changed and wkey then
                        if not rof_edits[wkey] then rof_edits[wkey] = {} end
                        rof_edits[wkey].recoil_anim_force = br_new
                        NATIVE.sync()
                    end

                    local spd_changed, spd_new = W.float("Recoil Animation Speed", ra_speed, 0.1, 0.0, 100.0)
                    if spd_changed and wkey then
                        if not rof_edits[wkey] then rof_edits[wkey] = {} end
                        rof_edits[wkey].recoil_anim_speed = spd_new
                        NATIVE.sync()
                    end
                end
            end)
        end

        W.card("shake", "Shot Camera Shake", function()
            local wkey = dropdown_items[selected_index]
            local wd = wkey and find_weapon_data_by_key(rof_catalog_id_for_key(wkey))
            local move = wd and resolve_shot_camera_shake_move(wd)
            if not move then
                W.text("No ShotCameraShakeParam._Move found")
                return
            end
            local axes = {
                { label = "Translation X", field = "_TranslationXRange", sk = "tx_s", rk = "tx_r" },
                { label = "Translation Y", field = "_TranslationYRange", sk = "ty_s", rk = "ty_r" },
                { label = "Translation Z", field = "_TranslationZRange", sk = "tz_s", rk = "tz_r" },
            }
            local scsm_changed = false
            -- the DLL writes the catalog from the edit, so the sliders show the edit's values once it has them
            local kept = wkey and rof_edits[wkey] and rof_edits[wkey].shot_camera_shake_move
            local pend = {}
            for _, axis in ipairs(axes) do
                local range_val = try_field(move, axis.field)
                if range_val then
                    local mn = tonumber(range_val.s) or 0
                    local mx = tonumber(range_val.r) or 0
                    if kept and kept[axis.sk] ~= nil then mn = kept[axis.sk] end
                    if kept and kept[axis.rk] ~= nil then mx = kept[axis.rk] end
                    local c1, new_min = W.float(axis.label .. " Min", mn, 0.001, -10.0, 10.0, "%.4f")
                    local c2, new_max = W.float(axis.label .. " Max", mx, 0.001, -10.0, 10.0, "%.4f")
                    pend[axis.sk], pend[axis.rk] = c1 and new_min or mn, c2 and new_max or mx
                    if c1 or c2 then scsm_changed = true end
                else
                    W.text(axis.label .. ": not found")
                end
            end
            if scsm_changed and wkey then
                local edit = rof_edits[wkey]
                if not edit then edit = {}; rof_edits[wkey] = edit end
                edit.shot_camera_shake_move = pend
                NATIVE.sync()
            end
        end)
    end

    if any_changed and not weapon_disabled then
        local key = dropdown_items[selected_index]
        if key then
            if not rof_edits[key] then rof_edits[key] = {} end
            local edit = rof_edits[key]
            edit.TypeOfShoot = math.floor(ui_state.type_of_shoot + 0.5)
            edit.ShotInterval = ui_state.shot_interval
            edit.BurstShotInterval = ui_state.burst_shot_interval
            edit.BurstNum = math.floor(ui_state.burst_num + 0.5)
            edit.recoil = {
                rate = ui_state.recoil_rate,
                yaw_s = ui_state.recoil_yaw_s,
                yaw_r = ui_state.recoil_yaw_r,
                pitch_s = ui_state.recoil_pitch_s,
                pitch_r = ui_state.recoil_pitch_r,
            }
            apply_all_now()
            if apply_to_equipped(key, edit) then
                ui_state.status = "Applied live: " .. (WEAPON_NAMES[key] or key)
            else
                ui_state.status = "Saved settings for " .. (WEAPON_NAMES[key] or key)
            end
        end
    end

    W.card("defaults", "Defaults", function()
        if W.button("Reset the current weapon##rrof_reset_one", "Reset Current Weapon") then
            local key = dropdown_items[selected_index]
            if key and reset_weapon_edits_from_defaults(key, false) then
                ui_state.status = "Reset " .. (WEAPON_NAMES[key] or key) .. " to defaults"
            elseif key then
                ui_state.status = "No defaults saved for " .. (WEAPON_NAMES[key] or key) .. " (capture first)"
            end
        end
        W.same_line()
        if W.button("Reset every weapon##rrof_reset_all", "Reset All to Defaults") then
            local count = 0
            for dkey, def in pairs(rof_defaults) do
                rof_edits[dkey] = {
                    TypeOfShoot = def.TypeOfShoot,
                    ShotInterval = def.ShotInterval,
                    BurstShotInterval = def.BurstShotInterval,
                    BurstNum = def.BurstNum,
                    recoil = def.recoil and {
                        rate = def.recoil.rate,
                        yaw_s = def.recoil.yaw_s,
                        yaw_r = def.recoil.yaw_r,
                        pitch_s = def.recoil.pitch_s,
                        pitch_r = def.recoil.pitch_r,
                    } or nil,
                    shot_camera_shake_move = def.shot_camera_shake_move and {
                        tx_s = def.shot_camera_shake_move.tx_s,
                        tx_r = def.shot_camera_shake_move.tx_r,
                        ty_s = def.shot_camera_shake_move.ty_s,
                        ty_r = def.shot_camera_shake_move.ty_r,
                        tz_s = def.shot_camera_shake_move.tz_s,
                        tz_r = def.shot_camera_shake_move.tz_r,
                    } or nil,
                    recoil_anim_enabled = def.recoil_anim_enabled or false,
                    recoil_anim_force = def.recoil_anim_force or 1.0,
                    recoil_anim_speed = def.recoil_anim_speed or 1.0,
                    smooth_semi = nil,
                    smooth_burst = nil,
                    disabled = nil,
                }
                if def.EnableAimCameraShake ~= nil then
                    ui_state.enable_aim_camera_shake = def.EnableAimCameraShake
                end
                count = count + 1
            end
            apply_all_now()
            local key = dropdown_items[selected_index]
            if key then
                populate_ui_from_vals(rof_defaults[key], key)
            end
            ui_state.status = "Reset all " .. tostring(count) .. " weapons to defaults"
        end

        local profile_msg = ui_state.status:match("^Enter a profile name")
            or ui_state.status:match("^Profile saved:")
            or ui_state.status:match("^Deleted profile:")
        if ui_state.status ~= "" and not profile_msg then
            local color = 0xFFFFFFFF
            local is_status = ui_state.status:match(": ")
                or ui_state.status:match("^Saved settings for")
                or ui_state.status:match("^Reset ")
                or ui_state.status:match("^Captured defaults")
                or ui_state.status:match("^Applied live")
            if is_status then
                color = 0xFF00FF00
            elseif ui_state.status:match("^No defaults saved") then
                color = 0xFF00FFFF
            end
            W.text(ui_state.status, color)
        end
    end)

    W.card("overlay", "Fire Mode Overlay", function()
        local style_changed
        local style_idx = (rof_settings.overlay_style or 1) + 1
        style_changed, style_idx = W.combo("Style##rrof_overlay_style", style_idx, OVERLAY_STYLES,
            "Choose the fire mode overlay style shown when switching modes")
        if style_changed then
            rof_settings.overlay_style = style_idx - 1
            show_fire_mode_overlay = rof_settings.overlay_style > 0
            rof_settings.show_fire_mode_overlay = show_fire_mode_overlay
            rof_settings.overlay_use_rects = rof_settings.overlay_style == 2
            NATIVE.sync()
            save_settings()
        end

        if rof_settings.overlay_style == 4 then
            local hk_changed, hk_new = W.color("German Color", rof_settings.overlay_hk_color, "Color and opacity of the German pictograms")
            W.same_line()
            if W.button("German color back to Default##hk_color", "Default") then
                hk_changed, hk_new = true, rof_settings_defaults.overlay_hk_color
            end
            if hk_changed then
                rof_settings.overlay_hk_color = hk_new
                NATIVE.sync()
                save_settings()
            end
        end

        local always_changed, always_new = W.check("Always Show (when HUD active)", rof_settings.overlay_always_show)
        if always_changed then
            rof_settings.overlay_always_show = always_new
            NATIVE.sync()
            save_settings()
        end
    end)

    W.card("keys", "Hotkeys", function()
        local wc = false
        local c
        if W.merc then
            c, rof_hk_settings.use_modifier = W.check("Keyboard: hold the modifier##rrof_kb_mod", rof_hk_settings.use_modifier)
            wc = wc or c
            c, rof_hk_settings.use_pad_modifier = W.check("Pad: hold the modifier##rrof_pad_mod", rof_hk_settings.use_pad_modifier)
            wc = wc or c
            wc = W.keys({ { "Fire mode", "Fire Mode Toggle", "Pad Fire Mode Toggle" },
                { "Modifier", "Fire Mode Modifier", "Pad Fire Mode Modifier" } }) or wc
        else
            imgui.text_colored(" Keyboard and Mouse:", 0xFFFFFFAA)
            c, rof_hk_settings.use_modifier = W.check("Use Modifier##kb_mod", rof_hk_settings.use_modifier,
                "Require holding this button while pressing toggle")
            wc = wc or c
            imgui.same_line()
            wc = hk.hotkey_setter("Fire Mode Modifier") or wc
            wc = hk.hotkey_setter("Fire Mode Toggle", rof_hk_settings.use_modifier and "Fire Mode Modifier") or wc

            imgui.text_colored(" Gamepad:", 0xFFFFFFAA)
            c, rof_hk_settings.use_pad_modifier = W.check("Use Modifier##pad_mod", rof_hk_settings.use_pad_modifier,
                "Require holding this button while pressing toggle")
            wc = wc or c
            imgui.same_line()
            wc = hk.hotkey_setter("Pad Fire Mode Modifier") or wc
            wc = hk.hotkey_setter("Pad Fire Mode Toggle", rof_hk_settings.use_pad_modifier and "Pad Fire Mode Modifier") or wc
        end

        if wc then
            hk.update_hotkey_table(rof_hk_settings.hotkeys)
            json.dump_file(ROF_HOTKEYS_PATH, rof_hk_settings)
        end

        if W.button("Hotkeys back to their defaults##rrof_hk_reset", "Reset Hotkeys to Defaults") then
            rof_hk_settings = hk.recurse_def_settings({}, rof_hk_default_settings)
            hk.reset_from_defaults_tbl(rof_hk_default_settings.hotkeys)
            hk.update_hotkey_table(rof_hk_settings.hotkeys)
            json.dump_file(ROF_HOTKEYS_PATH, rof_hk_settings)
        end
    end)

    -- (Advanced Options last, below Hotkeys; user: "for realistic rate of fire move advanced options below hotkeys")
    W.card("options", "Advanced Options", function()
        local acs_changed = false
        acs_changed, ui_state.enable_aim_camera_shake = W.check("Enable Aim Camera Shake", ui_state.enable_aim_camera_shake,
            "Toggle the camera shake effect when aiming")
        if acs_changed then
            apply_all_now()
            rof_settings.enable_aim_camera_shake = ui_state.enable_aim_camera_shake
            save_settings()
            ui_state.status = "Global Aim Camera Shake: " .. (ui_state.enable_aim_camera_shake and "Enabled" or "Disabled")
        end

        -- On = the DLL's "not while shooting" (regrip_mode 2: held back from a shot until the trigger is up and the recoil is
        -- done), Off = 1 (user: "rename the regrip anmation option called on, but not while shooting. change it to just On and
        -- remove the old On option"; the old always-on mode 0 is read as On)
        local regrip_changed, regrip_idx = W.combo("Regrip Animation", rof_settings.regrip_mode == 1 and 2 or 1, { "On", "Off" },
            "On plays it between shots, after the recoil animation is done. Off keeps it from interrupting shots when using high ROF")
        if regrip_changed then
            rof_settings.regrip_mode = regrip_idx == 2 and 1 or 2
            rof_settings.disable_regrip = rof_settings.regrip_mode == 1
            NATIVE.sync()
            save_settings()
            ui_state.status = "Regrip animation " .. (rof_settings.disable_regrip and "disabled" or "enabled")
        end

        local sf_changed
        sf_changed, rof_settings.disable_select_fire = W.check("Disable Select Fire", rof_settings.disable_select_fire,
            "Prevent cycling fire modes with the hotkey")
        if sf_changed then
            NATIVE.sync()
            save_settings()
            ui_state.status = "Select fire " .. (rof_settings.disable_select_fire and "disabled" or "enabled")
        end

        local rao_changed
        rao_changed, rof_settings.enable_recoil_anim_override = W.check("Enable Recoil Animation Override",
            rof_settings.enable_recoil_anim_override, "Master switch for per-weapon Recoil Animation Force/Speed overrides")
        if rao_changed then
            NATIVE.sync()
            save_settings()
            ui_state.status = "Recoil animation override " .. (rof_settings.enable_recoil_anim_override and "enabled" or "disabled")
        end

        local ssa_changed
        ssa_changed, rof_settings.smooth_semi_auto = W.check("Improved Semi-Auto Recoil Animation", rof_settings.smooth_semi_auto,
            "Global default for Improved Semi-Auto so that shots layer properly (can be overridden per weapon)")
        if ssa_changed then
            save_settings()
            if not rof_settings.smooth_semi_auto then
                for _, e in pairs(rof_edits) do
                    if e then e.smooth_semi = nil end
                end
                NATIVE.sync("kill_semi")
            else
                NATIVE.sync()
            end
            ui_state.status = "Smooth Semi-Auto " .. (rof_settings.smooth_semi_auto and "enabled" or "disabled")
        end

        local sb_changed
        sb_changed, rof_settings.smooth_burst = W.check("Improved Burst Recoil Animation", rof_settings.smooth_burst,
            "Global default for Improved Burst so that shots layer properly (can be overridden per weapon)")
        if sb_changed then
            save_settings()
            if not rof_settings.smooth_burst then
                for _, e in pairs(rof_edits) do
                    if e then e.smooth_burst = nil end
                end
                NATIVE.sync("kill_burst")
            else
                NATIVE.sync()
            end
            ui_state.status = "Smooth Burst " .. (rof_settings.smooth_burst and "enabled" or "disabled")
        end

        -- (hidden for now, user: "comment out the layerd sem-auto and burst recouil option for now"; the saved setting still
        -- goes to the DLL)
        -- local lr_changed
        -- lr_changed, rof_settings.layer_recoil = W.check("Layered Semi-Auto and Burst Recoil", rof_settings.layer_recoil,
        --     "Semi-auto and burst shots blend into the last shot's recoil like full-auto does,\n"
        --         .. "instead of restarting it (the game's own semi-auto and burst modes, no fire-mode workaround)")
        -- if lr_changed then
        --     NATIVE.sync()
        --     save_settings()
        --     ui_state.status = "Layered recoil " .. (rof_settings.layer_recoil and "enabled" or "disabled")
        -- end

        local dl_changed
        dl_changed, rof_settings.debug_log = W.check("Debug log##rrof_debug_log", rof_settings.debug_log,
            "Write this mod's info lines to the REFramework log (errors are always written)")
        if dl_changed then
            NATIVE.sync()
            save_settings()
        end
    end, true)
end

re.on_draw_ui(function()
    if imgui.tree_node("Realistic Rate of Fire") then
        draw_menu(W_IMGUI)
        imgui.tree_pop()
    end
end)

-- For Mercenaries' Extras: this menu in its window, with its rows (only when the DLL does the game work)
_G.RealisticRateOfFire.native = NATIVE.on
_G.RealisticRateOfFire.draw_menu = draw_menu

local fire_mode_display_timer = 0
local fire_mode_display_duration = 2.0
local last_displayed_mode = nil
local gui_became_active_at = 0
local gui_was_active = false
local sm_singleton = sdk.get_native_singleton("via.SceneManager")
local sm_typedef = sdk.find_type_definition("via.SceneManager")
local sv_typedef = sdk.find_type_definition("via.SceneView")

re.on_frame(function()
    if not show_fire_mode_overlay or not NATIVE.on then return end
    if (NATIVE.flags() & 8) ~= 0 then return end      -- the DLL draws it

    -- (only when the DLL could not find REFramework's ImGui functions)
    if (NATIVE.flags() & 3) ~= 3 then return end
    local current = NATIVE.mode() or NATIVE.shot_type()
    if current == nil then return end

    if last_displayed_mode ~= current then
        fire_mode_display_timer = os.clock()
        last_displayed_mode = current
    end

    local gui_active_now = rof_settings.overlay_always_show and (NATIVE.flags() & 4) ~= 0
    if gui_active_now and not gui_was_active then
        gui_became_active_at = os.clock()
    end
    gui_was_active = gui_active_now
    local always_on = gui_active_now and (os.clock() - gui_became_active_at >= 0.1)
    -- only with the game HUD (not on a loading screen)
    if (NATIVE.flags() & 4) == 0 then return end
    -- the game's HUD sits under its screen fade, this overlay on top: none while the screen is faded out
    local fade = sdk.get_managed_singleton("app.FadeManager")
    if fade and fade:call("isAnyFadeOut") == true then return end
    -- nor on the game over screen, which Mercenaries' results sit on (the HUD is skipped from drawing there, but the game
    -- still counts it as drawn)
    local game_over = sdk.get_managed_singleton("app.GameOverManager")
    if game_over and game_over:get_field("_GameOverHandle") ~= nil then return end
    if not always_on and os.clock() - fire_mode_display_timer > fire_mode_display_duration then return end

    local dot_count = 0
    if current == 0 then dot_count = 1
    elseif current == 2 then dot_count = 3
    elseif current == 1 then dot_count = 4
    end
    if dot_count == 0 then return end

    local size = nil
    pcall(function()
        local view = sdk.call_native_func(sm_singleton, sm_typedef, "get_MainView")
        size = sdk.call_native_func(view, sv_typedef, "get_WindowSize")
    end)
    if not size then return end

    if rof_settings.overlay_style == 3 then
        local label = ""
        if current == 0 then label = "SEMI-AUTO"
        elseif current == 2 then label = "BURST"
        elseif current == 1 then label = "FULL-AUTO"
        end
        if label == "" then return end

        local text_size = imgui.calc_text_size(label)
        local pad_x, pad_y = 12, 8
        local win_w = text_size.x + pad_x * 2
        local win_h = text_size.y + pad_y * 2

        local pos_x = size.w - win_w - 130
        local pos_y = size.h - win_h - 20

        imgui.set_next_window_pos({pos_x, pos_y}, 3, {0, 0})
        imgui.set_next_window_size({win_w, win_h}, 3)
        imgui.begin_window("##FireModeOverlay", true, 129)
        imgui.text_colored(label, 0x66FFFFFF)
        imgui.end_window()
    else
        local rect_w = 16.0
        local rect_h = 6.0
        local circle_r = 5.0
        local spacing = 20.0

        local item_w = rof_settings.overlay_use_rects and rect_w or (circle_r * 2)
        local item_h = rof_settings.overlay_use_rects and rect_h or (circle_r * 2)

        local total_width = (dot_count - 1) * spacing + item_w
        local win_w = total_width + 20
        local win_h = item_h + 20

        local pos_x = size.w - win_w - 130
        local pos_y = size.h - win_h - 20

        imgui.set_next_window_pos({pos_x, pos_y}, 3, {0, 0})
        imgui.set_next_window_size({win_w, win_h}, 3)
        imgui.begin_window("##FireModeOverlay", true, 129)

        local draw_list_x = 10
        local draw_list_y = 10
        for i = 0, dot_count - 1 do
            local cx = draw_list_x + (i * spacing)
            local cy = draw_list_y
            if rof_settings.overlay_use_rects then
                draw.filled_rect(pos_x + cx, pos_y + cy, rect_w, rect_h, 0x66FFFFFF)
            else
                draw.filled_circle(pos_x + cx + circle_r, pos_y + cy + circle_r, circle_r, 0x66FFFFFF, 16)
            end
        end

        imgui.end_window()
    end
end)
