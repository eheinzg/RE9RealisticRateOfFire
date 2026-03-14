-- RROF Editor for RE9

local RROF_DIR = "RROF/"
local DEFAULTS_PATH = RROF_DIR .. "defaults.json"
local PROFILES_DIR = RROF_DIR .. "profiles/"
local PROFILES_INDEX = RROF_DIR .. "profiles_index.json"
local ROF_HOTKEYS_PATH = RROF_DIR .. "hotkeys.json"
local SETTINGS_PATH = RROF_DIR .. "settings.json"
local rof_edits = {}
local rof_defaults = {}
local has_applied = false

local rof_settings_defaults = {
    disable_regrip = false,
    disable_select_fire = true,
    smooth_semi_auto = true,
    smooth_burst = true,
    enable_aim_camera_shake = true,
    show_fire_mode_overlay = true,
    fire_mode_limit_semi_full = false,
    overlay_use_rects = true,
    overlay_style = 1,
    overlay_always_show = false,
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

local OVERLAY_STYLES = { "None", "Circles", "Rectangles", "Text" }

local disable_regrip = true

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
    ["arm0700"] = "RPG-7",
}

local WEAPON_KEYS = {
    "arm0000", "arm0001", "arm0003", "arm0004", "arm0005", "arm0006", "arm0007", 
    "arm0100", "arm0103", "arm0104", "arm0400", "arm0500", "arm0501", "arm0503", "arm0505", "arm0600", "arm0601", "arm0700"
}

local dropdown_options = {}
local dropdown_items = {}
local selected_index = 1
local last_equipped_id = nil

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

local function load_profile(name)
    local ok, data = pcall(json.load_file, PROFILES_DIR .. name .. ".json")
    if ok and data then
        rof_edits = data.edits or {}
        if data.enable_aim_camera_shake ~= nil then
            ui_state.enable_aim_camera_shake = data.enable_aim_camera_shake
        end
        local key = dropdown_items[selected_index]
        if key then
            populate_ui_from_vals(rof_edits[key] or rof_defaults[key], key)
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
            populate_ui_from_vals(rof_edits[key] or rof_defaults[key], key)
        end
    end
end

local TYPE_PlayerEquipment = sdk.typeof("app.PlayerEquipment")
local TYPE_WeaponCatalogRegister = sdk.typeof("app.WeaponCatalogRegister")
local TYPE_Motion = sdk.typeof("via.motion.Motion")
local TYPE_BodyAddCtrlDriver = sdk.typeof("app.BodyAddCtrlDriver")

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

local function write_valuetype(parent_obj, offset, value)
    for i = 0, value.type:get_valuetype_size() - 1 do
        parent_obj:write_byte(offset + i, value:read_byte(i))
    end
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

local function apply_shot_camera_shake_move(weapon_data, scsm)
    if not scsm then return end
    local move = resolve_shot_camera_shake_move(weapon_data)
    if not move then return end
    local move_type = move:get_type_definition()
    local fields = {
        { name = "_TranslationXRange", sk = "tx_s", rk = "tx_r" },
        { name = "_TranslationYRange", sk = "ty_s", rk = "ty_r" },
        { name = "_TranslationZRange", sk = "tz_s", rk = "tz_r" },
    }
    for _, fld in ipairs(fields) do
        local f = move_type:get_field(fld.name)
        if f then
            local range_val = try_field(move, fld.name)
            if range_val then
                range_val.s = scsm[fld.sk] or range_val.s
                range_val.r = scsm[fld.rk] or range_val.r
                write_valuetype(move, f:get_offset_from_base(), range_val)
            end
        end
    end
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

local function apply_recoil_values(crp, recoil)
    if not crp or not recoil then return false end
    local yaw = try_field(crp, "_YawRangeDeg")
    local pitch = try_field(crp, "_PitchRangeDeg")
    if not yaw or not pitch then return false end
    yaw.s = recoil.yaw_s
    yaw.r = recoil.yaw_r
    pitch.s = recoil.pitch_s
    pitch.r = recoil.pitch_r
    if recoil.rate then
        set_field_safe(crp, "_Rate", recoil.rate)
    end
    local crp_type = crp:get_type_definition()
    local yaw_field = crp_type:get_field("_YawRangeDeg")
    local pitch_field = crp_type:get_field("_PitchRangeDeg")
    if yaw_field and pitch_field then
        write_valuetype(crp, yaw_field:get_offset_from_base(), yaw)
        write_valuetype(crp, pitch_field:get_offset_from_base(), pitch)
        return true
    end
    return false
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
                if edit.recoil then
                    local crp = resolve_camera_recoil(wd)
                    if crp then
                        apply_recoil_values(crp, edit.recoil)
                    end
                end
                if edit.shot_camera_shake_move then
                    apply_shot_camera_shake_move(wd, edit.shot_camera_shake_move)
                end
            end
        end
    end
    return applied
end

local function get_attachment_data_table(register)
    if not register then return nil end
    local holder = try_field(register, "_AttachmentWeaponEquipParamCatalogUserData")
    if not holder then return nil end
    local cd = try_field(holder, "_CatalogData")
    if cd then
        local dt = try_field(cd, "_DataTable")
        if dt then return dt end
    end
    local dt = try_field(holder, "_DataTable")
    if dt then return dt end
    return nil
end

local function apply_attachment_shoot_data(sd, edit)
    if not sd or not edit then return false end
    set_field_safe(sd, "TypeOfShoot", edit.TypeOfShoot)
    set_field_safe(sd, "ShotInterval", edit.ShotInterval)
    set_field_safe(sd, "BurstShotInterval", edit.BurstShotInterval)
    set_field_safe(sd, "BurstNum", edit.BurstNum)
    return true
end

local function apply_edit_to_param(param, edit)
    if not param or not edit then return 0 end
    local count = 0
    local sd = try_field(param, "_ShootData")
    if sd and apply_attachment_shoot_data(sd, edit) then count = count + 1 end
    local csd = try_field(param, "_ChangeShootData")
    if csd and apply_attachment_shoot_data(csd, edit) then count = count + 1 end
    return count
end

local function resolve_att_id(entry)
    if not entry then return nil end
    local aid_obj = try_field(entry, "_AttachmentIDCache")
    if not aid_obj then return nil end
    local s; pcall(function() s = aid_obj:call("ToString") end)
    if s then return string.lower(s) end
    pcall(function() s = aid_obj:call("toString") end)
    if s then return string.lower(s) end
    return nil
end

local function att_id_to_weapon_id(att_str)
    if not att_str then return nil end
    local digits = att_str:match("ath(%d+)")
    if not digits or #digits < 4 then return nil end
    local group = tonumber(digits:sub(1, #digits - 2))
    if not group or group < 1 then return nil end
    return "arm" .. string.format("%04d", group - 1)
end

local function apply_entry_with_levelups(entry, edit)
    if not entry or not edit then return 0 end
    local applied = 0
    local param = try_field(entry, "_Parameter")
    if param then
        applied = applied + apply_edit_to_param(param, edit)
    end
    local lvl_params = try_field(entry, "_LevelUpParameters")
    if lvl_params then
        local lc = 0; pcall(function() lc = lvl_params:call("get_Count") end)
        if lc == 0 then
            local len = try_field(lvl_params, "Length")
            if len then lc = tonumber(len) or 0 end
        end
        for li = 0, lc - 1 do
            local lp; pcall(function() lp = lvl_params:call("get_Item", li) end)
            if not lp then pcall(function() lp = lvl_params:call("Get", li) end) end
            if lp then
                applied = applied + apply_edit_to_param(lp, edit)
            end
        end
    end
    return applied
end

local function apply_edits_to_attachments(dt)
    if not dt then return 0 end
    local applied = 0
    local count = 0; pcall(function() count = dt:call("get_Count") end)
    for i = 0, count - 1 do
        local entry; pcall(function() entry = dt:call("get_Item", i) end)
        if not entry then goto continue end
        local param = try_field(entry, "_Parameter")
        if not param or not try_field(param, "_ShootData") then goto continue end
        local att_str = resolve_att_id(entry)
        local weapon_id = att_id_to_weapon_id(att_str)
        local edit = weapon_id and rof_edits[weapon_id]
        if edit then
            applied = applied + apply_entry_with_levelups(entry, edit)
        end
        ::continue::
    end
    return applied
end

local function apply_edits()
    local catalogs = find_all_catalogs(get_scene())
    local total = 0
    for _, catalog in ipairs(catalogs) do
        local reg = get_register(catalog)
        local dt = get_data_table(reg)
        total = total + apply_edits_to_table(dt)
        local adt = get_attachment_data_table(reg)
        total = total + apply_edits_to_attachments(adt)
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

local function get_recoil_anim_for_key(key)
    local edit = key and rof_edits[key]
    if edit and edit.recoil_anim_enabled ~= nil then
        return edit.recoil_anim_enabled, edit.recoil_anim_force or 1.0, edit.recoil_anim_speed or 1.0
    end
    local def = key and rof_defaults[key]
    if def and def.recoil_anim_enabled ~= nil then
        return def.recoil_anim_enabled, def.recoil_anim_force or 1.0, def.recoil_anim_speed or 1.0
    end
    return false, 1.0, 1.0
end

local function apply_to_equipped(weapon_key, edit)
    local eid_str, pe = get_equipped_weapon_id()
    if not pe or not eid_str then return false end
    if eid_str ~= weapon_key then return false end

    if edit.ShotInterval then
        pcall(function() pe:set_field("_ShotInterval", edit.ShotInterval) end)
        pcall(function() pe:set_field("_CalcShotInterval", edit.ShotInterval) end)
    end
    if edit.TypeOfShoot ~= nil then
        pcall(function() pe:set_field("_EquipShotType", edit.TypeOfShoot) end)
    end
    return true
end

-- Hotkey system for fire mode toggle
local hk = require("Hotkeys/Hotkeys")
local FIRE_MODE_NAMES = { [0] = "Semi-Auto", [1] = "Full-Auto", [2] = "Burst" }
local show_fire_mode_overlay = rof_settings.show_fire_mode_overlay
local fire_mode_limit_semi_full = rof_settings.fire_mode_limit_semi_full

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

-- ============================================================
-- Smooth Semi-Auto
-- Allows one shot per trigger pull on full-auto weapons.
-- After the first execFire, sets DisableShootState on the
-- weapon object to block further shots. Resets on release.
-- ============================================================
local smooth_semi = {
    has_fired = false,
    shoot_held = false,
    active = false,
    display_mode = nil,
    last_pe = nil,
    last_weapon_id = nil,
}

local function smooth_semi_set_dss(pe, value)
    if not pe then return end
    local weapon = nil
    pcall(function() weapon = pe:call("getEquipWeapon") end)
    if not weapon then return end
    local wtype = weapon:get_type_definition()
    if not wtype then return end
    local f = wtype:get_field("<DisableShootState>k__BackingField")
    if f then
        weapon:write_byte(f:get_offset_from_base(), value and 1 or 0)
    end
end

-- ============================================================
-- Smooth Burst
-- Allows BurstNum shots per trigger pull on full-auto weapons.
-- After BurstNum execFire calls, sets DisableShootState on the
-- weapon object to block further shots. Resets on release.
-- ============================================================
local smooth_burst = {
    shot_count = 0,
    shoot_held = false,
    active = false,
    display_mode = nil,
    last_pe = nil,
    last_weapon_id = nil,
}

local function smooth_get_display_mode()
    if smooth_semi.active then return 0 end
    if smooth_burst.active then return 2 end
    return nil
end

local function cycle_fire_mode()
    if rof_settings.disable_select_fire then return end

    local eid_str, pe = get_equipped_weapon_id_cached()
    if not pe or not eid_str then return end
    if not WEAPON_NAMES[eid_str] then return end

    local current = nil
    pcall(function() current = pe:get_field("_EquipShotType") end)
    if current == nil then return end
    current = smooth_get_display_mode() or tonumber(current) or 0

    local edit = rof_edits[eid_str] or {}
    local allow = {
        [0] = edit.allow_semi ~= false,
        [1] = edit.allow_full ~= false,
        [2] = edit.allow_burst ~= false,
    }
    if fire_mode_limit_semi_full then allow[2] = false end

    local next_mode = current
    for attempt = 1, 3 do
        next_mode = (next_mode + 1) % 3
        if allow[next_mode] then break end
    end
    if next_mode == current then return end

    if smooth_semi.active then
        smooth_semi.active = false
        smooth_semi.display_mode = nil
        smooth_semi.has_fired = false
        smooth_semi_set_dss(pe, false)
    end
    if smooth_burst.active then
        smooth_burst.active = false
        smooth_burst.display_mode = nil
        smooth_burst.shot_count = 0
        smooth_semi_set_dss(pe, false)
    end

    pcall(function() pe:set_field("_EquipShotType", next_mode) end)

    if edit then edit.TypeOfShoot = next_mode end

    local catalogs = find_all_catalogs(get_scene())
    for _, catalog in ipairs(catalogs) do
        local dt = get_data_table(get_register(catalog))
        if dt then
            local count = 0; pcall(function() count = dt:call("get_Count") end)
            for i = 0, count - 1 do
                local wd; pcall(function() wd = dt:call("get_Item", i) end)
                if wd then
                    local id = get_entry_id(wd)
                    if id == eid_str then
                        local sd = resolve_shoot_data(wd)
                        if sd then
                            set_field_safe(sd, "TypeOfShoot", next_mode)
                        end
                    end
                end
            end
        end
    end

    if selected_index then
        local sel_key = dropdown_items[selected_index]
        if sel_key == eid_str then
            ui_state.type_of_shoot = next_mode
        end
    end
    ui_state.status = ""
end

local toggle_was_down = false

re.on_application_entry("UpdateBehavior", function()
    local km = (not rof_hk_settings.use_modifier or hk.check_hotkey("Fire Mode Modifier", true)) and hk.check_hotkey("Fire Mode Toggle", true)
    local pad = (not rof_hk_settings.use_pad_modifier or hk.check_hotkey("Pad Fire Mode Modifier", true)) and hk.check_hotkey("Pad Fire Mode Toggle", true)
    local is_down = km or pad
    if is_down and not toggle_was_down then
        cycle_fire_mode()
    end
    toggle_was_down = is_down or false
end)

local function get_burst_num_for_equipped()
    local eid_str = cached_eid or get_weapon_id_from_pe(get_player_equipment())
    if not eid_str then return 3 end
    local edit = rof_edits[eid_str]
    if edit and edit.BurstNum then return edit.BurstNum end
    local def = rof_defaults[eid_str]
    if def and def.BurstNum then return def.BurstNum end
    return 3
end

re.on_application_entry("UpdateHID", function()
    local pe = get_player_equipment()
    cached_pe = pe

    -- Smooth Semi-Auto cleanup when disabled
    if not rof_settings.smooth_semi_auto then
        if smooth_semi.active then
            smooth_semi.active = false
            smooth_semi.has_fired = false
            smooth_semi.display_mode = nil
            if pe then
                pcall(function() pe:set_field("_EquipShotType", 0) end)
                smooth_semi_set_dss(pe, false)
            end
        end
    end

    -- Smooth Burst cleanup when disabled
    if not rof_settings.smooth_burst then
        if smooth_burst.active then
            smooth_burst.active = false
            smooth_burst.shot_count = 0
            smooth_burst.display_mode = nil
            if pe then
                pcall(function() pe:set_field("_EquipShotType", 2) end)
                smooth_semi_set_dss(pe, false)
            end
        end
    end

    if not rof_settings.smooth_semi_auto and not rof_settings.smooth_burst then
        cached_eid = get_weapon_id_from_pe(pe)
        return
    end
    if not pe then
        smooth_semi.last_pe = nil
        smooth_semi.last_weapon_id = nil
        smooth_burst.last_pe = nil
        smooth_burst.last_weapon_id = nil
        return
    end

    local cur_weapon_id = get_weapon_id_from_pe(pe)
    cached_eid = cur_weapon_id

    local pe_changed = (pe ~= smooth_semi.last_pe)
    local weapon_changed = (cur_weapon_id ~= smooth_semi.last_weapon_id)
    smooth_semi.last_pe = pe
    smooth_semi.last_weapon_id = cur_weapon_id
    smooth_burst.last_pe = pe
    smooth_burst.last_weapon_id = cur_weapon_id

    if (pe_changed or weapon_changed) and smooth_semi.active then
        smooth_semi.has_fired = false
        smooth_semi.shoot_held = false
        smooth_semi.active = false
        smooth_semi.display_mode = nil
        smooth_semi_set_dss(pe, false)
    end
    if (pe_changed or weapon_changed) and smooth_burst.active then
        smooth_burst.shot_count = 0
        smooth_burst.shoot_held = false
        smooth_burst.active = false
        smooth_burst.display_mode = nil
        smooth_semi_set_dss(pe, false)
    end

    if weapon_changed and cur_weapon_id then
        local edit = rof_edits[cur_weapon_id] or {}
        local allow_semi = edit.allow_semi ~= false
        local allow_full = edit.allow_full ~= false
        local allow_burst = edit.allow_burst ~= false
        local cur_type = nil
        pcall(function() cur_type = pe:get_field("_EquipShotType") end)
        cur_type = tonumber(cur_type) or 0
        local allowed = { [0] = allow_semi, [1] = allow_full, [2] = allow_burst }
        if not allowed[cur_type] then
            local fallback = allow_semi and 0 or (allow_burst and 2 or (allow_full and 1 or 0))
            pcall(function() pe:set_field("_EquipShotType", fallback) end)
        end
    end

    local shot_type = nil
    pcall(function() shot_type = pe:get_field("_EquipShotType") end)
    shot_type = tonumber(shot_type) or -1

    local rt_down = hk.check_pad_button("RT (R2)", true) or false
    local lmb_down = hk.check_mouse_button("L Mouse", true) or false
    local shoot_held = rt_down or lmb_down

    -- Smooth Semi-Auto (exclude RPG-7)
    if rof_settings.smooth_semi_auto and cur_weapon_id ~= "arm0700" then
        if shot_type == 0 or smooth_semi.active then
            if not smooth_semi.active then
                smooth_semi.active = true
                smooth_semi.display_mode = 0
            end
            pcall(function() pe:set_field("_EquipShotType", 1) end)

            if not shoot_held and smooth_semi.shoot_held then
                smooth_semi.has_fired = false
                smooth_semi_set_dss(pe, false)
            end
            smooth_semi.shoot_held = shoot_held

            if shot_type ~= 0 and shot_type ~= 1 then
                smooth_semi.active = false
                smooth_semi.display_mode = nil
                smooth_semi.has_fired = false
                smooth_semi_set_dss(pe, false)
            end
        else
            if smooth_semi.active then
                smooth_semi.active = false
                smooth_semi.display_mode = nil
                smooth_semi.has_fired = false
            end
        end
    end

    -- Smooth Burst
    if rof_settings.smooth_burst then
        if shot_type == 2 or smooth_burst.active then
            if not smooth_burst.active then
                smooth_burst.active = true
                smooth_burst.display_mode = 2
            end
            pcall(function() pe:set_field("_EquipShotType", 1) end)

            if not shoot_held and smooth_burst.shoot_held then
                smooth_burst.shot_count = 0
                smooth_semi_set_dss(pe, false)
            end
            smooth_burst.shoot_held = shoot_held

            if shot_type ~= 2 and shot_type ~= 1 then
                smooth_burst.active = false
                smooth_burst.display_mode = nil
                smooth_burst.shot_count = 0
                smooth_semi_set_dss(pe, false)
            end
        else
            if smooth_burst.active then
                smooth_burst.active = false
                smooth_burst.display_mode = nil
                smooth_burst.shot_count = 0
            end
        end
    end
end)

local _bac_apply_override

do
    local equip_td = sdk.find_type_definition("app.PlayerEquipment")
    if equip_td then
        local exec_fire = equip_td:get_method("execFire")
        if exec_fire then
            local pending_pe = nil
            sdk.hook(exec_fire,
                function(args)
                    if smooth_semi.active then
                        if not smooth_semi.has_fired then
                            smooth_semi.has_fired = true
                            pcall(function() pending_pe = sdk.to_managed_object(args[2]) end)
                        end
                    elseif smooth_burst.active then
                        smooth_burst.shot_count = smooth_burst.shot_count + 1
                        local burst_num = get_burst_num_for_equipped()
                        if smooth_burst.shot_count >= burst_num then
                            pcall(function() pending_pe = sdk.to_managed_object(args[2]) end)
                        end
                    end
                end,
                function(retval)
                    if pending_pe then
                        smooth_semi_set_dss(pending_pe, true)
                        pending_pe = nil
                    end
                    _bac_apply_override()
                    return retval
                end
            )
        end
    end
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

local function get_body_add_ctrl_layer()
    local ctx = get_player()
    if not ctx then return nil, nil end
    local go = nil
    pcall(function() go = ctx:call("get_GameObject") end)
    if not go or not TYPE_BodyAddCtrlDriver then return nil, nil end
    local driver = nil
    pcall(function() driver = go:call("getComponent(System.Type)", TYPE_BodyAddCtrlDriver) end)
    if not driver then return nil, nil end
    local layer = nil
    pcall(function() layer = driver:get_field("<Layer>k__BackingField") end)
    return layer, driver
end

local REGRIP_CONDITION_INDICES = { 0, 10 }

local function set_regrip_condition_enabled(enabled)
    local ctx = get_player()
    if not ctx then return false end
    local ok = false
    pcall(function()
        local updater = ctx:get_field("<Updater>k__BackingField")
        if not updater then return end
        local input_driver = updater:get_field("<InputDriver>k__BackingField")
        if not input_driver then return end
        local reaction = input_driver:get_field("<Reaction>k__BackingField")
        if not reaction then return end
        local container = reaction:get_field("<Container>k__BackingField")
        if not container then return end
        local resident = container:get_field("<ResidentSettings>k__BackingField")
        if not resident then return end
        local settings = resident:get_field("_Settings")
        if not settings then return end
        for _, idx in ipairs(REGRIP_CONDITION_INDICES) do
            pcall(function()
                local setting = settings:call("get_Item", idx)
                if not setting then return end
                local condition = setting:get_field("_Condition")
                if not condition then return end
                condition:set_field("_IsEnable", enabled)
                ok = true
            end)
        end
    end)
    return ok
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

_bac_apply_override = function()
    local eid = cached_eid
    if not eid then
        eid = get_equipped_weapon_id_cached()
    end
    if not eid then return end
    local enabled, force, speed = get_recoil_anim_for_key(eid)
    if not enabled then return end
    local layer = nil
    pcall(function() layer = get_body_add_ctrl_layer() end)
    if layer then
        pcall(function()
            layer:call("set_BlendRate", force)
            layer:call("set_Speed", speed)
        end)
    end
end

local _cached_gui_gameobj = nil

local _ui2021_td = sdk.find_type_definition("app.UI2021GuiBehavior")
if _ui2021_td then
    local _ui2021_hooked = false
    for _, mname in ipairs({"update", "lateUpdate", "onEnable", "doAwake", "doEnable"}) do
        if _ui2021_hooked then break end
        local meth = _ui2021_td:get_method(mname)
        if meth then
            sdk.hook(meth,
                function(args)
                    if not _cached_gui_gameobj then
                        pcall(function()
                            local obj = sdk.to_managed_object(args[2])
                            if obj then
                                local go = obj:call("get_GameObject")
                                if go and tostring(go:call("get_Name")) == "Gui_ui2021" then
                                    _cached_gui_gameobj = go
                                end
                            end
                        end)
                    end
                    return sdk.PreHookResult.CALL_ORIGINAL
                end,
                function(retval) return retval end
            )
            _ui2021_hooked = true
        end
    end
end

local function apply_all_now()
    has_applied = false
    local count = apply_edits()
    if count > 0 then has_applied = true end
    return count
end

local _regrip_condition_applied = false

re.on_pre_application_entry("LockScene", function()
    if has_applied and _regrip_condition_applied then return end
    if not sdk.get_primary_camera() then
        has_applied = false
        _regrip_condition_applied = false
        _cached_gui_gameobj = nil
        return
    end
    if not has_applied then
        if apply_edits() > 0 then has_applied = true end
    end
    if not _regrip_condition_applied and disable_regrip then
        if set_regrip_condition_enabled(false) then
            _regrip_condition_applied = true
        end
    end
end)

local sm_type = sdk.find_type_definition("via.SceneManager")
if sm_type then
    local m = sm_type:get_method("begin_change_sceneByString")
    if m then
        sdk.hook(m,
            function() return sdk.PreHookResult.CALL_ORIGINAL end,
            function(retval) has_applied = false; _regrip_condition_applied = false; _cached_gui_gameobj = nil; return retval end
        )
    end
end

local function is_game_gui_active()
    if not _cached_gui_gameobj then return false end
    local ok, drawing = pcall(function()
        return _cached_gui_gameobj:call("get_Draw")
    end)
    if not ok then _cached_gui_gameobj = nil; return false end
    return drawing == true
end

re.on_draw_ui(function()
    if imgui.tree_node("Realistic Rate of Fire") then
        imgui.text_colored("Toggle Fire Mode With Assigned Hotkey (Default: B or L2(Left Trigger)+A(X))", 0xFFFFFF00)
        imgui.separator()
        local changed

        if #profile_state.names > 0 then
            local prof_changed
            local active_pname = profile_state.names[profile_state.selected] or ""
            imgui.text_colored("Profile: " .. active_pname, 0xFFFFFF00)
            prof_changed, profile_state.selected = imgui.combo("##Profile", profile_state.selected, profile_state.names)
            if profile_state.selected < 1 then profile_state.selected = 1 end
            if profile_state.selected > #profile_state.names then profile_state.selected = #profile_state.names end
            if prof_changed then
                local pname = profile_state.names[profile_state.selected]
                if pname and load_profile(pname) then
                    apply_all_now()
                    for k, edit in pairs(rof_edits) do
                        apply_to_equipped(k, edit)
                    end
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

        if imgui.tree_node("Advanced Options") then
        local acs_changed = false
        acs_changed, ui_state.enable_aim_camera_shake = imgui.checkbox("Enable Aim Camera Shake", ui_state.enable_aim_camera_shake)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Toggle the camera shake effect when aiming")
        end
        if acs_changed then
            apply_all_now()
            rof_settings.enable_aim_camera_shake = ui_state.enable_aim_camera_shake
            save_settings()
            ui_state.status = "Global Aim Camera Shake: " .. (ui_state.enable_aim_camera_shake and "Enabled" or "Disabled")
        end

        local regrip_changed = false
        regrip_changed, disable_regrip = imgui.checkbox("Disable Regrip Animation", disable_regrip)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Keep disabled to prevent the animation from interrupting shots when using high ROF")
        end
        if regrip_changed then
            rof_settings.disable_regrip = disable_regrip
            if disable_regrip then
                if set_regrip_condition_enabled(false) then
                    _regrip_condition_applied = true
                end
            else
                set_regrip_condition_enabled(true)
                _regrip_condition_applied = false
            end
            save_settings()
            ui_state.status = "Regrip animation " .. (disable_regrip and "disabled" or "enabled")
        end

        local sf_changed
        sf_changed, rof_settings.disable_select_fire = imgui.checkbox("Disable Select Fire", rof_settings.disable_select_fire)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Prevent cycling fire modes with the hotkey")
        end
        if sf_changed then
            save_settings()
            ui_state.status = "Select fire " .. (rof_settings.disable_select_fire and "disabled" or "enabled")
        end

        local ssa_changed
        ssa_changed, rof_settings.smooth_semi_auto = imgui.checkbox("Improved Semi-Auto Recoil Animation", rof_settings.smooth_semi_auto)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Consecutive shots layer properly for a smoother animation")
        end
        if ssa_changed then
            save_settings()
            smooth_semi.has_fired = false
            smooth_semi.shoot_held = false
            if not rof_settings.smooth_semi_auto and smooth_semi.active then
                smooth_semi.active = false
                smooth_semi.display_mode = nil
                local pe = get_player_equipment()
                if pe then
                    pcall(function() pe:set_field("_EquipShotType", 0) end)
                    smooth_semi_set_dss(pe, false)
                end
            end
            ui_state.status = "Smooth Semi-Auto " .. (rof_settings.smooth_semi_auto and "enabled" or "disabled")
        end

        local sb_changed
        sb_changed, rof_settings.smooth_burst = imgui.checkbox("Improved Burst Recoil Animation", rof_settings.smooth_burst)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Consecutive shots layer properly for a smoother animation")
        end
        if sb_changed then
            save_settings()
            smooth_burst.shot_count = 0
            smooth_burst.shoot_held = false
            if not rof_settings.smooth_burst and smooth_burst.active then
                smooth_burst.active = false
                smooth_burst.display_mode = nil
                local pe = get_player_equipment()
                if pe then
                    pcall(function() pe:set_field("_EquipShotType", 2) end)
                    smooth_semi_set_dss(pe, false)
                end
            end
            ui_state.status = "Smooth Burst " .. (rof_settings.smooth_burst and "enabled" or "disabled")
        end

        imgui.tree_pop()
        end

        -- Motion Layers debug UI 
        -- if imgui.tree_node("Motion Layers") then
        --     local live_changed
        --     live_changed, _motion_live_logging = imgui.checkbox("Live Update", _motion_live_logging)
        --
        --     local function capture_motion_layers()
        --         local dump = { layers = {} }
        --         pcall(function()
        --             local motion = get_player_motion()
        --             if motion then
        --                 local lc = motion:call("getLayerCount")
        --                 dump.layer_count = lc
        --                 for li = 0, lc - 1 do
        --                     pcall(function()
        --                         local tl = motion:call("getLayer", li)
        --                         if tl then
        --                             local info = { layer = li, running = tl:call("get_Running"), tree_empty = tl:call("get_TreeEmpty") }
        --                             if info.running and not info.tree_empty then
        --                                 info.blend_mode = tl:call("get_BlendMode")
        --                                 info.blend_rate = tl:call("get_BlendRate")
        --                                 info.motion_id = tl:call("get_MotionID")
        --                                 info.motion_bank_id = tl:call("get_MotionBankID")
        --                                 info.speed = tl:call("get_Speed")
        --                                 info.joint_count = tl:call("get_JointCount")
        --                                 info.animated_joint_count = tl:call("get_AnimatedJointCount")
        --                                 pcall(function()
        --                                     local mn = tl:call("get_HighestWeightMotionNode")
        --                                     if mn then
        --                                         info.motion_name = mn:call("get_MotionName") or ""
        --                                     end
        --                                 end)
        --                                 pcall(function()
        --                                     local jd = tl:call("get_JointsData")
        --                                     if jd then
        --                                         info.joints_data_type = tostring(jd:get_type_definition():get_full_name())
        --                                         local len = jd:call("get_Length")
        --                                         info.joints_data_length = len
        --                                         local sample = {}
        --                                         local sample_count = math.min(len, 40)
        --                                         for si = 0, sample_count - 1 do
        --                                             sample[#sample + 1] = jd:call("Get", si)
        --                                         end
        --                                         info.joints_data_sample = sample
        --                                     end
        --                                 end)
        --                                 pcall(function()
        --                                     local vc = tl:call("get_ValueCount")
        --                                     info.value_count = vc
        --                                 end)
        --                             end
        --                             dump.layers[#dump.layers + 1] = info
        --                         end
        --                     end)
        --                 end
        --             end
        --         end)
        --         return dump
        --     end
        --
        --     if _motion_live_logging then
        --         _motion_layer_dump = capture_motion_layers()
        --     end
        --
        --     imgui.same_line()
        --     if imgui.button("Snapshot to JSON") then
        --         _motion_layer_dump = capture_motion_layers()
        --         json.dump_file(RROF_DIR .. "debug_motion_layers.json", _motion_layer_dump)
        --     end
        --
        --     if _motion_layer_dump then
        --         for _, l in ipairs(_motion_layer_dump.layers) do
        --             if l.running and not l.tree_empty then
        --                 local label = "L" .. l.layer .. " bm=" .. tostring(l.blend_mode) .. " br=" .. string.format("%.2f", l.blend_rate or 0) .. " mot=" .. tostring(l.motion_id) .. " bank=" .. tostring(l.motion_bank_id) .. " " .. (l.motion_name or "")
        --                 imgui.text(label)
        --             end
        --         end
        --     end
        --
        --     if _motion_live_logging and #_fsm_hash_log > 0 then
        --         imgui.spacing()
        --         imgui.text_colored("FSM Transition Hashes:", 0xFFFFFF00)
        --         for i = #_fsm_hash_log, math.max(1, #_fsm_hash_log - 14), -1 do
        --             imgui.text(_fsm_hash_log[i])
        --         end
        --         if imgui.button("Clear FSM Log") then _fsm_hash_log = {} end
        --     end
        --
        --     if _motion_live_logging and #_action_hash_log > 0 then
        --         imgui.spacing()
        --         imgui.text_colored("Action Hashes (execAction):", 0xFF00FFFF)
        --         for i = #_action_hash_log, math.max(1, #_action_hash_log - 14), -1 do
        --             imgui.text(_action_hash_log[i])
        --         end
        --         if imgui.button("Clear Action Log") then _action_hash_log = {} end
        --     end
        --
        --     imgui.tree_pop()
        -- end

        imgui.separator()

        local equipped_key, pe = get_equipped_weapon_id_cached()
        if pe then
            if equipped_key then
                local eid_name = WEAPON_NAMES[equipped_key]
                local is_known = eid_name ~= nil
                eid_name = eid_name or equipped_key

                imgui.text_colored("Equipped: ", 0xFFFFFF00)
                imgui.same_line()
                imgui.text_colored(eid_name, 0xFFFFFF00)

                if is_known then
                    local current_type = 0
                    pcall(function() current_type = pe:get_field("_EquipShotType") end)
                    current_type = smooth_get_display_mode() or tonumber(current_type) or 0
                    local mode_name = FIRE_MODE_NAMES[current_type] or "?"

                    imgui.same_line()
                    imgui.text_colored("(" .. mode_name .. ")", 0xFF0000FF)
                end

                -- Auto-select weapon if it changed
                if equipped_key ~= last_equipped_id then
                    for i, key in ipairs(dropdown_items) do
                        if key == equipped_key then
                            selected_index = i
                            local vals = rof_edits[key] or rof_defaults[key] or read_live_values(key)
                            populate_ui_from_vals(vals, key)
                            break
                        end
                    end
                    last_equipped_id = equipped_key
                end
            else
                imgui.text_colored("Equipped: (waiting...)", 0xFFFFFF00)
            end
        else
            imgui.text_colored("Equipped: (waiting...)", 0xFFFFFF00)
        end

        changed, selected_index = imgui.combo("Weapon", selected_index, dropdown_options)
        if selected_index < 1 then selected_index = 1 end
        if selected_index > #dropdown_items then selected_index = #dropdown_items end
        if changed then
            local key = dropdown_items[selected_index]
            local vals = rof_edits[key] or rof_defaults[key] or read_live_values(key)
            populate_ui_from_vals(vals, key)
        end

        do
            local key = dropdown_items[selected_index]
            if key then
                local edit = rof_edits[key]
                if not edit then edit = {}; rof_edits[key] = edit end
                if edit.allow_semi == nil then edit.allow_semi = true end
                if edit.allow_full == nil then edit.allow_full = true end
                if edit.allow_burst == nil then edit.allow_burst = true end

                imgui.text_colored("Fire Modes:", 0xFFFFFF00)
                if imgui.is_item_hovered() then
                    imgui.set_tooltip("Select which fire modes are available when cycling with the hotkey")
                end
                local sc; sc, edit.allow_semi = imgui.checkbox("Semi##allow", edit.allow_semi)
                imgui.same_line()
                local fc; fc, edit.allow_full = imgui.checkbox("Full-Auto##allow", edit.allow_full)
                imgui.same_line()
                local bc; bc, edit.allow_burst = imgui.checkbox("Burst##allow", edit.allow_burst)
                if not edit.allow_semi and not edit.allow_full and not edit.allow_burst then
                    edit.allow_semi = true
                end
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

        imgui.spacing()
        imgui.text_colored("Camera Recoil:", 0xFFFFFF00)
        changed, ui_state.recoil_rate = imgui.drag_float("Rate", ui_state.recoil_rate, 0.01, 0.0, 10.0, "%.3f")
        if changed then any_changed = true end
        changed, ui_state.recoil_yaw_s = imgui.drag_float("Yaw Min", ui_state.recoil_yaw_s, 0.01, -10.0, 10.0, "%.3f")
        if changed then any_changed = true end
        changed, ui_state.recoil_yaw_r = imgui.drag_float("Yaw Max", ui_state.recoil_yaw_r, 0.01, -10.0, 10.0, "%.3f")
        if changed then any_changed = true end
        changed, ui_state.recoil_pitch_s = imgui.drag_float("Pitch Min", ui_state.recoil_pitch_s, 0.01, -10.0, 10.0, "%.3f")
        if changed then any_changed = true end
        changed, ui_state.recoil_pitch_r = imgui.drag_float("Pitch Max", ui_state.recoil_pitch_r, 0.01, -10.0, 10.0, "%.3f")
        if changed then any_changed = true end

        imgui.spacing()
        imgui.text_colored("Recoil Animation:", 0xFFFFFF00)
        local bac_layer = get_body_add_ctrl_layer()
        if bac_layer then
            local br = 0; pcall(function() br = bac_layer:call("get_BlendRate") end)
            local spd = 0; pcall(function() spd = bac_layer:call("get_Speed") end)

            local wkey = dropdown_items[selected_index]
            local wedit = wkey and rof_edits[wkey]
            local ra_enabled = wedit and wedit.recoil_anim_enabled or false
            local ra_force = wedit and wedit.recoil_anim_force or 1.0
            local ra_speed = wedit and wedit.recoil_anim_speed or 1.0

            local lock_changed, lock_new = imgui.checkbox("Enable##recoil_anim", ra_enabled)
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
            end

            local br_changed, br_new = imgui.drag_float("Recoil Animation Force", ra_force, 0.01, 0.0, 1.0)
            if br_changed and wkey then
                if not rof_edits[wkey] then rof_edits[wkey] = {} end
                rof_edits[wkey].recoil_anim_force = br_new
                pcall(function() bac_layer:call("set_BlendRate", br_new) end)
            end

            local spd_changed, spd_new = imgui.drag_float("Recoil Animation Speed", ra_speed, 0.1, 0.0, 100.0)
            if spd_changed and wkey then
                if not rof_edits[wkey] then rof_edits[wkey] = {} end
                rof_edits[wkey].recoil_anim_speed = spd_new
                pcall(function() bac_layer:call("set_Speed", spd_new) end)
            end
        else
            imgui.text("(not found)")
        end

        imgui.spacing()
        imgui.text_colored("Shot Camera Shake:", 0xFFFFFF00)
        do
            local wkey = dropdown_items[selected_index]
            local wd = wkey and find_weapon_data_by_key(wkey)
            local move = wd and resolve_shot_camera_shake_move(wd)
            if move then
                local move_type = move:get_type_definition()
                local axes = {
                    { label = "Translation X", field = "_TranslationXRange", sk = "tx_s", rk = "tx_r" },
                    { label = "Translation Y", field = "_TranslationYRange", sk = "ty_s", rk = "ty_r" },
                    { label = "Translation Z", field = "_TranslationZRange", sk = "tz_s", rk = "tz_r" },
                }
                local scsm_changed = false
                for _, axis in ipairs(axes) do
                    local range_val = try_field(move, axis.field)
                    if range_val then
                        local mn = tonumber(range_val.s) or 0
                        local mx = tonumber(range_val.r) or 0
                        local c1, new_min = imgui.drag_float(axis.label .. " Min", mn, 0.001, -10.0, 10.0, "%.4f")
                        local c2, new_max = imgui.drag_float(axis.label .. " Max", mx, 0.001, -10.0, 10.0, "%.4f")
                        if c1 or c2 then
                            range_val.s = c1 and new_min or mn
                            range_val.r = c2 and new_max or mx
                            local f = move_type:get_field(axis.field)
                            if f then
                                write_valuetype(move, f:get_offset_from_base(), range_val)
                            end
                            scsm_changed = true
                        end
                    else
                        imgui.text(axis.label .. ": not found")
                    end
                end
                if scsm_changed and wkey then
                    local edit = rof_edits[wkey]
                    if not edit then edit = {}; rof_edits[wkey] = edit end
                    edit.shot_camera_shake_move = read_shot_camera_shake_move(wd)
                end
            else
                imgui.text("No ShotCameraShakeParam._Move found")
            end
        end

        if any_changed then
            local key = dropdown_items[selected_index]
            if key then
                local prev = rof_edits[key]
                local edit = {
                    TypeOfShoot = math.floor(ui_state.type_of_shoot + 0.5),
                    ShotInterval = ui_state.shot_interval,
                    BurstShotInterval = ui_state.burst_shot_interval,
                    BurstNum = math.floor(ui_state.burst_num + 0.5),
                    recoil = {
                        rate = ui_state.recoil_rate,
                        yaw_s = ui_state.recoil_yaw_s,
                        yaw_r = ui_state.recoil_yaw_r,
                        pitch_s = ui_state.recoil_pitch_s,
                        pitch_r = ui_state.recoil_pitch_r,
                    },
                    shot_camera_shake_move = prev and prev.shot_camera_shake_move or nil,
                    recoil_anim_enabled = prev and prev.recoil_anim_enabled or nil,
                    recoil_anim_force = prev and prev.recoil_anim_force or nil,
                    recoil_anim_speed = prev and prev.recoil_anim_speed or nil
                }
                rof_edits[key] = edit
                apply_all_now()
                if apply_to_equipped(key, edit) then
                    ui_state.status = "Applied live: " .. (WEAPON_NAMES[key] or key)
                else
                    ui_state.status = "Saved settings for " .. (WEAPON_NAMES[key] or key)
                end
            end
        end

        if imgui.button("Capture Defaults") then
          local defaults = capture_defaults()
          local n = 0; for _ in pairs(defaults) do n = n + 1 end
          ui_state.status = "Captured defaults for " .. tostring(n) .. " weapons"
        end

        if imgui.button("Reset Current Weapon") then
            local key = dropdown_items[selected_index]
            if key and rof_defaults[key] then
                local def = rof_defaults[key]
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
                    recoil_anim_speed = def.recoil_anim_speed or 1.0
                }
                populate_ui_from_vals(def, key)
                apply_all_now()
                ui_state.status = "Reset " .. (WEAPON_NAMES[key] or key) .. " to defaults"
            elseif key then
                ui_state.status = "No defaults saved for " .. (WEAPON_NAMES[key] or key) .. " (capture first)"
            end
        end
        imgui.same_line()
        if imgui.button("Reset All to Defaults") then
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
                    recoil_anim_speed = def.recoil_anim_speed or 1.0
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
            imgui.text_colored(ui_state.status, color)
        end

        imgui.separator()
        
        imgui.text_colored("Fire Mode Overlay:", 0xFFFFFF00)
        local style_changed
        local style_idx = (rof_settings.overlay_style or 1) + 1
        style_changed, style_idx = imgui.combo("Style", style_idx, OVERLAY_STYLES)
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Choose the fire mode overlay style shown when switching modes")
        end
        if style_changed then
            rof_settings.overlay_style = style_idx - 1
            show_fire_mode_overlay = rof_settings.overlay_style > 0
            rof_settings.show_fire_mode_overlay = show_fire_mode_overlay
            rof_settings.overlay_use_rects = rof_settings.overlay_style == 2
            save_settings()
        end

        local always_changed, always_new = imgui.checkbox("Always Show (when HUD active)", rof_settings.overlay_always_show)
        if always_changed then
            rof_settings.overlay_always_show = always_new
            save_settings()
        end

        imgui.separator()
        imgui.text_colored("Hotkeys:", 0xFFFFFF00)
        local changed = false
        local wc = false

        imgui.text_colored(" Keyboard and Mouse:", 0xFFFFFFAA)
        changed, rof_hk_settings.use_modifier = imgui.checkbox("Use Modifier##kb_mod", rof_hk_settings.use_modifier); wc = wc or changed
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Require holding this button while pressing toggle")
        end
        imgui.same_line()
        changed = hk.hotkey_setter("Fire Mode Modifier") or false; wc = wc or changed
        changed = hk.hotkey_setter("Fire Mode Toggle", rof_hk_settings.use_modifier and "Fire Mode Modifier") or false; wc = wc or changed

        imgui.text_colored(" Gamepad:", 0xFFFFFFAA)
        changed, rof_hk_settings.use_pad_modifier = imgui.checkbox("Use Modifier##pad_mod", rof_hk_settings.use_pad_modifier); wc = wc or changed
        if imgui.is_item_hovered() then
            imgui.set_tooltip("Require holding this button while pressing toggle")
        end
        imgui.same_line()
        changed = hk.hotkey_setter("Pad Fire Mode Modifier") or false; wc = wc or changed
        changed = hk.hotkey_setter("Pad Fire Mode Toggle", rof_hk_settings.use_pad_modifier and "Pad Fire Mode Modifier") or false; wc = wc or changed

        if changed or wc then
            hk.update_hotkey_table(rof_hk_settings.hotkeys)
            json.dump_file(ROF_HOTKEYS_PATH, rof_hk_settings)
        end

        imgui.spacing()
        if imgui.button("Reset Hotkeys to Defaults") then
            rof_hk_settings = hk.recurse_def_settings({}, rof_hk_default_settings)
            hk.reset_from_defaults_tbl(rof_hk_default_settings.hotkeys)
            hk.update_hotkey_table(rof_hk_settings.hotkeys)
            json.dump_file(ROF_HOTKEYS_PATH, rof_hk_settings)
        end

        -- Attachment Catalog Debug (commented out, not needed for normal use)
        -- imgui.separator()
        -- if imgui.tree_node("Attachment Catalog Debug") then
        --     ...
        --     imgui.tree_pop()
        -- end

        imgui.tree_pop()
    end
end)

local fire_mode_display_timer = 0
local fire_mode_display_duration = 2.0
local last_displayed_mode = nil
local gui_became_active_at = 0
local gui_was_active = false
local sm_singleton = sdk.get_native_singleton("via.SceneManager")
local sm_typedef = sdk.find_type_definition("via.SceneManager")
local sv_typedef = sdk.find_type_definition("via.SceneView")

re.on_frame(function()
    if not show_fire_mode_overlay then return end

    local eid_str, pe = get_equipped_weapon_id_cached()
    if not pe or not eid_str then return end
    if not WEAPON_NAMES[eid_str] then return end

    local current = nil
    pcall(function() current = pe:get_field("_EquipShotType") end)
    if current == nil then return end
    current = smooth_get_display_mode() or tonumber(current) or 0

    if last_displayed_mode ~= current then
        fire_mode_display_timer = os.clock()
        last_displayed_mode = current
    end

    local gui_active_now = rof_settings.overlay_always_show and is_game_gui_active()
    if gui_active_now and not gui_was_active then
        gui_became_active_at = os.clock()
    end
    gui_was_active = gui_active_now
    local always_on = gui_active_now and (os.clock() - gui_became_active_at >= 0.1)
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
        elseif current == 2 then label = "BURST-FIRE"
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
