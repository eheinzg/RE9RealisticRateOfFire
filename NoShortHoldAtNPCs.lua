-- No Short Hold At NPCs: a friendly NPC in front of the gun no longer pulls it into the short hold.
--
-- The third person short hold is the game's near-obstacle hold. Every frame while aiming,
-- PlayerHoldDriver.updateApplyHoldFront asks isApplyHoldFrontInternal whether something is close: a
-- sphere cast along the camera direction for characters (_HoldFrontCheckEnemyParam), then the wall
-- check. A yes turns the hold on and arms _ContinueHoldFrontTimer, so a civilian running across the
-- aim flips the stance and keeps it flipped a moment after they have gone, cutting into the shots.
--
-- SmallScripts.dll post-hooks isApplyHoldFrontInternal and answers no when the yes can only be down to a
-- friendly: the same two casts find an NPC or companion first, and no wall is there. Answering there rather
-- than clearing the flags afterwards leaves the timer unarmed. Everything else takes the game's answer.
-- First person never gets here: updateApplyHoldFront leaves early in that view.
--
-- This script keeps only the readout, from the DLL's NoShortHoldAtNPCs_Status.json (read twice a second while the
-- menu is open), and the Debug log switch.
local NATIVE = { on = false, read_t = -10 }
pcall(function()
    local d = json.load_file("SmallScripts_Loaded.json")
    if type(d) ~= "table" or type(d.t) ~= "number" then return end
    local up = sdk.call_native_func(sdk.get_native_singleton("via.Application"),
        sdk.find_type_definition("via.Application"), "get_UpTimeSecond")
    NATIVE.on = d.t >= os.time() - (tonumber(up) or 0) - 120
end)
-- our info lines in the REFramework log, off by default; saved in NoShortHoldAtNPCs.json (SmallScripts.dll reads it too)
NATIVE.debug_log = false
pcall(function()
    local d = json.load_file("NoShortHoldAtNPCs.json")
    if type(d) == "table" and type(d.debug_log) == "boolean" then NATIVE.debug_log = d.debug_log end
end)
if not NATIVE.on then log.error("[No Short Hold At NPCs] SmallScripts.dll is not loaded, so this mod changes nothing") end

-- What the in-game readout shows.
local seen = { game_yes = 0, blocked = 0, last = "not seen yet", error = nil }

re.on_draw_ui(function()
    if not imgui.tree_node("No Short Hold At NPCs") then return end
    if not NATIVE.on then
        imgui.text_colored("SmallScripts.dll is not loaded: this mod changes nothing in the game", 0xFF4444FF)
    elseif os.clock() - NATIVE.read_t > 0.5 then
        NATIVE.read_t = os.clock()
        local s = json.load_file("NoShortHoldAtNPCs_Status.json")
        if type(s) == "table" then
            seen.last = tostring(s.last or seen.last)
            seen.game_yes = tonumber(s.game_yes) or seen.game_yes
            seen.blocked = tonumber(s.blocked) or seen.blocked
            seen.error = (s.error ~= nil and s.error ~= "") and tostring(s.error) or nil
        end
    end
    local changed, v = imgui.checkbox("Debug log", NATIVE.debug_log)
    if changed then
        NATIVE.debug_log = v
        pcall(json.dump_file, "NoShortHoldAtNPCs.json", { debug_log = v })
    end
    imgui.text("Last: " .. seen.last)
    imgui.text(string.format("Game asked for the hold %d times, blocked %d", seen.game_yes, seen.blocked))
    if seen.error then imgui.text("Error: " .. seen.error) end
    imgui.tree_pop()
end)
