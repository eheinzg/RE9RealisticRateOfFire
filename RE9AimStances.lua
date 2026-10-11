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

local hk = require("Hotkeys/Hotkeys")

local SETTINGS_PATH = "RE9AimStances.json"
local HOLD_MASK = 0xF0000

-- bits = nil means the game's own choice is left alone.
local STANCES = {
    { id = "game", name = "Game decides", bits = nil,
      about = "The game picks the stance itself, as in vanilla." },
    { id = "standard", name = "Standard", bits = 0x00000,
      about = "Always the normal hold: the game never switches to a lean, injured or one-handed hold on its own." },
    { id = "cover_r", name = "Cover right (lean)", bits = 0x10000,
      about = "The hold the game uses at a wall corner, right side. First and third person." },
    { id = "cover_l", name = "Cover left (lean)", bits = 0x20000,
      about = "The hold the game uses at a wall corner, left side. First and third person." },
    { id = "over", name = "Over cover", bits = 0x60000,
      about = "Aiming over waist-high cover. Crouched only, third person only." },
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

local function kb_action(s) return "Aim Stance: " .. s.name end
local function pad_action(s) return "Aim Stance Pad: " .. s.name end

local default_settings = { stance = "game", hotkeys = {} }
for _, s in ipairs(STANCES) do
    if s.bits then
        default_settings.hotkeys[kb_action(s)] = "[Not Bound]"
        default_settings.hotkeys[pad_action(s)] = "[Not Bound]"
    end
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
