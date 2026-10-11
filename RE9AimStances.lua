-- RE9 Aim Stances: the game's own alternative aim stances, switchable at will.
--
-- Every gun's aiming motions come in variants, one bank per hold stance (ch0100_Handgun00HverB..G and
-- the like). Which variant plays is chosen by bits 16-19 of the player's motion bank type
-- (app.PlayerDefine.MotionBankTypeBit: HoldCover_R 1, HoldCover_L 2, HoldDamage 3, HoldMelee 4,
-- HoldMeleeWep 5, HoldCover_Up 6), and PlayerHoldDriver.getHoldBankTypeBit is where the game supplies
-- those bits. A post-hook hands back the chosen stance in their place; the game then swaps banks
-- itself, exactly as it does when you step up to a wall corner.
--
-- First person only has variants for the two cover leans and the melee weapon raise (Leon and Grace
-- alike); the others fall back to the normal hold there.
--
-- At a real corner the camera changes too: app.PlayerCameraPositionSetting picks a cover camera state
-- (CoverActionLeft/Right, CrouchCoverAction*, CoverActionUp) in place of the aiming one, which in first
-- person is the sideways lean of the view. A forced cover stance swaps the aiming state the camera
-- getters return for the matching cover state, so the camera follows as in vanilla; the slide to a
-- corner point is not reproduced, since there is no corner. The ADS (scope) state is left alone.
--
-- The short hold (gun pulled in close) is separate and sits on top of any stance. It is the game's
-- near-wall hold: PlayerHoldDriver.updateApplyHoldFront clears and recomputes the driver's "apply hold
-- front" flags every frame from its wall/enemy ray (and leaves them off in first person, where there
-- are no short-hold clips), and the HoldShortState motion variable and the shot logic follow those
-- flags. A post-hook sets them on after the game's own pass, third person only, so the short hold
-- behaves as it does at a wall, shooting included. The ray result itself is left alone.
--
-- Canted is the game's quick-shot pose: fire while the gun is coming up and the HoldStartShoot node
-- plays the hold turned ~53 degrees about the barrel (clip 1040, shots 1140), in both views. Two
-- things keep it from being a stance: app.IsHoldStartShoot only lets the raise into it on a trigger
-- press, and in third person app.HoldStartSootContinue ends it after MinContinueTime without a shot or
-- MaxContinueTime in all. With Canted on, the condition answers yes for the played character, and the
-- two times are swapped for a very long one only for the duration of that action's start/update calls
-- (start arms its timers from them, update re-arms the minimum on each shot), so nothing persists in
-- the game's data. Lowering the gun or reloading still ends it, as in vanilla.

local hk = require("Hotkeys/Hotkeys")

local SETTINGS_PATH = "RE9AimStances.json"
local HOLD_MASK = 0xF0000

-- bits = nil means the game's own choice is left alone. stand / crouch name the app.PlayerCameraState
-- the camera takes for that stance, standing and crouched.
local STANCES = {
    { id = "game", name = "Game decides", bits = nil,
      about = "The game picks the stance itself, as in vanilla." },
    { id = "standard", name = "Standard", bits = 0x00000,
      about = "Always the normal hold: the game never switches to a lean, injured or one-handed hold on its own." },
    { id = "cover_r", name = "Cover right (lean)", bits = 0x10000,
      stand = "CoverActionRight", crouch = "CrouchCoverActionRight",
      about = "The hold the game uses at a wall corner, right side, with its camera. First and third person." },
    { id = "cover_l", name = "Cover left (lean)", bits = 0x20000,
      stand = "CoverActionLeft", crouch = "CrouchCoverActionLeft",
      about = "The hold the game uses at a wall corner, left side, with its camera. First and third person." },
    { id = "over", name = "Over cover", bits = 0x60000, crouch = "CoverActionUp",
      about = "Aiming over waist-high cover, with its camera. Crouched only, third person only." },
    { id = "injured", name = "Injured", bits = 0x30000,
      about = "The hurt hold. Third person only." },
    { id = "one_hand", name = "One-handed", bits = 0x40000,
      about = "Leon's handguns only, third person only. Grace has no one-handed set." },
    { id = "melee_wep", name = "Melee weapon", bits = 0x50000,
      about = "Only the raise differs: the game has no hold clips for it, so the hold itself stays normal." },
}

local by_id, names = {}, {}
for i, s in ipairs(STANCES) do
    by_id[s.id] = s
    names[i] = s.name
end

local SHORT = { id = "short", name = "Short hold" }
local CANT = { id = "canted", name = "Canted" }

local function kb_action(s) return "Aim Stance: " .. s.name end
local function pad_action(s) return "Aim Stance Pad: " .. s.name end

local default_settings = { stance = "game", short_hold = false, canted = false, hotkeys = {} }
for _, s in ipairs(STANCES) do
    if s.bits then
        default_settings.hotkeys[kb_action(s)] = "[Not Bound]"
        default_settings.hotkeys[pad_action(s)] = "[Not Bound]"
    end
end
for _, s in ipairs({ SHORT, CANT }) do
    default_settings.hotkeys[kb_action(s)] = "[Not Bound]"
    default_settings.hotkeys[pad_action(s)] = "[Not Bound]"
end

local settings = hk.recurse_def_settings(json.load_file(SETTINGS_PATH) or {}, default_settings)
if not by_id[settings.stance] then settings.stance = "game" end
hk.setup_hotkeys(settings.hotkeys, default_settings.hotkeys)

local function save_settings() json.dump_file(SETTINGS_PATH, settings) end

-- What the game itself asked for on its last call, and how many calls the hook has seen (a 0 here in
-- game means the method is not being called through the hook at all).
local seen = { calls = 0, game_bits = nil }

local hold_td = sdk.find_type_definition("app.PlayerHoldDriver")
local hold_type = sdk.typeof("app.PlayerHoldDriver")

-- The hold driver of the character being played, so a companion's stance is never touched.
local function player_hold_address()
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    local ctx = cm and cm:call("getPlayerContextRef")
    local go = ctx and ctx:call("get_GameObject")
    local drv = go and go:call("getComponent(System.Type)", hold_type)
    return drv and drv:get_address()
end

sdk.hook(hold_td:get_method("getHoldBankTypeBit"),
    function(args)
        local storage = thread.get_hook_storage()
        if not storage then return end
        local ok, addr = pcall(player_hold_address)
        storage.mine = ok and addr ~= nil and sdk.to_int64(args[2]) == addr
    end,
    function(retval)
        local storage = thread.get_hook_storage()
        if not (storage and storage.mine) then return retval end
        local bits = sdk.to_int64(retval) & 0xFFFFFFFF
        seen.calls = seen.calls + 1
        seen.game_bits = bits & HOLD_MASK
        local forced = by_id[settings.stance].bits
        if forced == nil then return retval end
        return sdk.to_ptr((bits & ~HOLD_MASK) | forced)
    end)

local TPS = 0  -- app.PlayerMode

local function force_short_hold(drv)
    local ctx = drv:call("get_Context")
    if not ctx or ctx:get_field("<CurrentViewMode>k__BackingField") ~= TPS then return end
    drv:set_field("_IsApplyHoldFront", true)
    drv:set_field("_IsInternalApplyHoldFront", true)
end

sdk.hook(hold_td:get_method("updateApplyHoldFront"),
    function(args)
        local storage = thread.get_hook_storage()
        if not storage then return end
        storage.drv = nil
        if not settings.short_hold then return end
        local ok, addr = pcall(player_hold_address)
        if ok and addr ~= nil and sdk.to_int64(args[2]) == addr then
            storage.drv = sdk.to_managed_object(args[2])
        end
    end,
    function(retval)
        local storage = thread.get_hook_storage()
        if storage and storage.drv then pcall(force_short_hold, storage.drv) end
        return retval
    end)

-- Behavior-tree conditions and actions, and the camera setting, carry their character's updater, so the
-- played one is told apart by comparing it with the player context's.
local function is_player_updater(u)
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    local ctx = cm and cm:call("getPlayerContextRef")
    local mine = ctx and ctx:call("get_Updater")
    return u ~= nil and mine ~= nil and u:get_address() == mine:get_address()
end

local function is_players(obj)
    return is_player_updater(obj:get_field("<Updater>k__BackingField"))
end

sdk.hook(sdk.find_type_definition("app.IsHoldStartShoot"):get_method("evaluate"),
    function(args)
        local storage = thread.get_hook_storage()
        if not storage then return end
        storage.cant = false
        if not settings.canted then return end
        local ok, mine = pcall(is_players, sdk.to_managed_object(args[2]))
        storage.cant = ok and mine
    end,
    function(retval)
        local storage = thread.get_hook_storage()
        if storage and storage.cant then return sdk.to_ptr(1) end
        return retval
    end)

local LONG = 1.0e9

local function stretch(args)
    local storage = thread.get_hook_storage()
    if not storage then return end
    storage.cont = nil
    if not settings.canted then return end
    local action = sdk.to_managed_object(args[2])
    local ok, mine = pcall(is_players, action)
    if not (ok and mine) then return end
    storage.cont = { action, action:get_field("MinContinueTime"), action:get_field("MaxContinueTime") }
    action:set_field("MinContinueTime", LONG)
    action:set_field("MaxContinueTime", LONG)
end

local function unstretch(retval)
    local storage = thread.get_hook_storage()
    local c = storage and storage.cont
    if c then
        c[1]:set_field("MinContinueTime", c[2])
        c[1]:set_field("MaxContinueTime", c[3])
    end
    return retval
end

local cont_td = sdk.find_type_definition("app.HoldStartSootContinue")
sdk.hook(cont_td:get_method("start"), stretch, unstretch)
sdk.hook(cont_td:get_method("update"), stretch, unstretch)

-- The camera states a forced cover stance replaces: the aiming ones, plus the game's own cover states,
-- for when its corner check picks a different side than the one forced.
local AIM_STAND = { "Hold", "HoldMachineGun", "HoldRifle", "HoldShotgun", "HoldRocketLauncher",
    "HoldPoisonPump", "SpecialHold", "CoverActionLeft", "CoverActionRight" }
local AIM_CROUCH = { "CrouchHold", "CrouchSpecialHold", "CrouchCoverActionLeft", "CrouchCoverActionRight",
    "CoverActionUp" }

local cam_state_td = sdk.find_type_definition("app.PlayerCameraState")
local cam_swap = {}  -- stance id -> { [replaced state's address] = cover state }

local function static_state(name)
    local f = cam_state_td:get_field(name)
    return f and f:get_data(nil)
end

-- Built on first use; kept only once every state resolved, so a lookup made before the states exist
-- is simply tried again on the next call.
local function swap_for(s)
    if cam_swap[s.id] then return cam_swap[s.id] end
    local m, complete = {}, true
    for _, pair in ipairs({ { AIM_STAND, s.stand }, { AIM_CROUCH, s.crouch } }) do
        if pair[2] then
            local to = static_state(pair[2])
            if not to then complete = false end
            for _, name in ipairs(pair[1]) do
                local from = static_state(name)
                if from and to then m[from:get_address()] = to else complete = false end
            end
        end
    end
    if complete then cam_swap[s.id] = m end
    return m
end

local function cam_pre(args)
    local storage = thread.get_hook_storage()
    if not storage then return end
    storage.swap = nil
    local s = by_id[settings.stance]
    if not (s.stand or s.crouch) then return end
    local ok, m = pcall(function()
        local setting = sdk.to_managed_object(args[2])
        if is_player_updater(setting:get_field("_PlayerUpdater")) then return swap_for(s) end
    end)
    if ok then storage.swap = m end
end

local function cam_post(retval)
    local storage = thread.get_hook_storage()
    local m = storage and storage.swap
    local to = m and m[sdk.to_int64(retval)]
    if to then return sdk.to_ptr(to:get_address()) end
    return retval
end

local cam_td = sdk.find_type_definition("app.PlayerCameraPositionSetting")
for _, name in ipairs({ "getTPSState", "getFPSState", "getCommonState" }) do
    sdk.hook(cam_td:get_method(name), cam_pre, cam_post)
end

-- A stance key turns its stance on, or back to the game's choice when it is already on.
local was_down = {}

local function toggle(s)
    if settings.stance == s.id then
        settings.stance = "game"
    else
        settings.stance = s.id
    end
    save_settings()
end

re.on_application_entry("UpdateBehavior", function()
    for _, s in ipairs(STANCES) do
        if s.bits then
            local down = hk.check_hotkey(kb_action(s), true) or hk.check_hotkey(pad_action(s), true)
            if down and not was_down[s.id] then toggle(s) end
            was_down[s.id] = down or false
        end
    end
    for _, t in ipairs({ { SHORT, "short_hold" }, { CANT, "canted" } }) do
        local s, key = t[1], t[2]
        local down = hk.check_hotkey(kb_action(s), true) or hk.check_hotkey(pad_action(s), true)
        if down and not was_down[s.id] then
            settings[key] = not settings[key]
            save_settings()
        end
        was_down[s.id] = down or false
    end
end)

local function stance_name_of(bits)
    for _, s in ipairs(STANCES) do
        if s.bits == bits then return s.name end
    end
    return string.format("unknown (0x%X)", bits)
end

re.on_draw_ui(function()
    if not imgui.tree_node("RE9 Aim Stances") then return end

    local index = 1
    for i, s in ipairs(STANCES) do
        if s.id == settings.stance then index = i end
    end
    local changed, new_index = imgui.combo("Stance", index, names)
    if changed and STANCES[new_index] then
        settings.stance = STANCES[new_index].id
        save_settings()
    end
    imgui.text_colored(by_id[settings.stance].about, 0xFFAAAAAA)

    if seen.calls == 0 then
        imgui.text("The game's own stance: not seen yet (draw a gun)")
    else
        imgui.text("The game's own stance right now: " .. stance_name_of(seen.game_bits))
    end
    if imgui.is_item_hovered() then
        imgui.set_tooltip("What the game would use if left to decide. Walk up to a wall corner or take damage to see it change.")
    end

    local short_changed
    short_changed, settings.short_hold = imgui.checkbox("Short hold (third person)", settings.short_hold)
    if short_changed then save_settings() end
    if imgui.is_item_hovered() then
        imgui.set_tooltip("Gun pulled in close: the hold the game uses up against a wall, shooting included.\nWorks with any stance. Third person only: the game has no first-person short hold.")
    end

    local cant_changed
    cant_changed, settings.canted = imgui.checkbox("Canted", settings.canted)
    if cant_changed then save_settings() end
    if imgui.is_item_hovered() then
        imgui.set_tooltip("The game's quick-shot pose, gun tilted ~53 degrees, held for as long as you aim.\nFirst and third person. Takes effect from the next raise; Short hold wins when both are on.")
    end

    if imgui.tree_node("Hotkeys") then
        imgui.text_colored("A key turns its stance on, and back to Game decides when pressed again.", 0xFFAAAAAA)
        local hk_changed = false
        for _, s in ipairs(STANCES) do
            if s.bits then
                hk_changed = hk.hotkey_setter(kb_action(s), nil, s.name) or hk_changed
                imgui.same_line()
                hk_changed = hk.hotkey_setter(pad_action(s), nil, "Pad") or hk_changed
            end
        end
        for _, s in ipairs({ SHORT, CANT }) do
            hk_changed = hk.hotkey_setter(kb_action(s), nil, s.name) or hk_changed
            imgui.same_line()
            hk_changed = hk.hotkey_setter(pad_action(s), nil, "Pad") or hk_changed
        end
        if hk_changed then
            hk.update_hotkey_table(settings.hotkeys)
            save_settings()
        end
        if imgui.button("Reset Hotkeys to Defaults") then
            hk.reset_from_defaults_tbl(default_settings.hotkeys)
            hk.update_hotkey_table(settings.hotkeys)
            save_settings()
        end
        imgui.tree_pop()
    end

    imgui.tree_pop()
end)
