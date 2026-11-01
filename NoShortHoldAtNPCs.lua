-- No Short Hold At NPCs: a friendly NPC in front of the gun no longer pulls it into the short hold.
--
-- The third person short hold is the game's near-obstacle hold. Every frame while aiming,
-- PlayerHoldDriver.updateApplyHoldFront asks isApplyHoldFrontInternal whether something is close: a
-- sphere cast along the camera direction for characters (_HoldFrontCheckEnemyParam), then the wall
-- check. A yes turns the hold on and arms _ContinueHoldFrontTimer, so a civilian running across the
-- aim flips the stance and keeps it flipped a moment after they have gone, cutting into the shots.
--
-- A post-hook on isApplyHoldFrontInternal answers no when the yes can only be down to a friendly: the
-- same two casts find an NPC or companion first, and no wall is there. Answering there rather than
-- clearing the flags afterwards leaves the timer unarmed. The game's cast results stay on its stack,
-- so the casts are repeated from the same config values, stretched the way the game stretches them
-- while the hold is on. Everything else takes the game's answer. First person never gets here:
-- updateApplyHoldFront leaves early in that view.

local LENGTH_MARGIN = 0.3     -- reaches anything the game's check touched at its far end
local WALL_CHECK_START = 0.15 -- the game starts its wall check this far along the aim
local DEFAULT_WALL_LENGTH, DEFAULT_WALL_RADIUS = 0.3, 0.2

local FACE_FRONT, FACE_BOTH, OPTION_NONE = 0, 2, 0

local hold_td = sdk.find_type_definition("app.PlayerHoldDriver")
local hold_type = sdk.typeof("app.PlayerHoldDriver")
local collision_td = sdk.find_type_definition("app.Collision")
local filter_td = sdk.find_type_definition("app.Collision.Filter")
local cast_first = collision_td:get_method(
    "castSphere(System.Single, via.vec3, via.vec3, app.CollisionCastResult, via.physics.FilterInfo, app.CastHitFaceType, app.CastOptionFlag)")
local cast_any = collision_td:get_method(
    "castSphere(System.Single, via.vec3, via.vec3, via.physics.FilterInfo, app.CastHitFaceType, app.CastOptionFlag)")
local character_filter = filter_td:get_field("DamageCheckEnemyHit")
local effect_filter = filter_td:get_field("EffectDefault")
local terrain_filter = filter_td:get_field("TerrainDefault")

-- What the in-game readout shows.
local seen = { game_yes = 0, blocked = 0, last = "not seen yet", error = nil }

local function player_hold_address()
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    local ctx = cm and cm:call("getPlayerContextRef")
    local go = ctx and ctx:call("get_GameObject")
    local drv = go and go:call("getComponent(System.Type)", hold_type)
    return drv and drv:get_address()
end

local function in_list(list, go_addr, skip)
    for i = 0, list:call("get_Count") - 1 do
        local ctx = list:call("get_Item", i)
        if ctx and ctx:get_address() ~= skip and ctx:call("get_GameObject"):get_address() == go_addr then
            return true
        end
    end
    return false
end

local function along(s, dir, len)
    return Vector3f.new(s.x + dir.x * len, s.y + dir.y * len, s.z + dir.z * len)
end

-- The reason the game's yes should stand, or nil when only a friendly explains it.
local function keep_reason(drv)
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    local updater = drv:get_field("_Updater")
    local ctx = drv:call("get_Context")
    local cfg = updater:call("get_Configuration"):call("get_PlayerHoldSetting")
    local param = cfg:call("get_HoldFrontCheckEnemyParam")

    local xf = ctx:call("get_Transform")
    local pos = xf:call("get_Position")
    local spine = updater:get_field("<Spine_1>k__BackingField"):call("get_Position")
    local up, front = xf:call("get_AxisY"), xf:call("get_AxisZ")
    local rise, ahead = param:call("get_HoldFrontCheckYOffset"), param:call("get_HoldFrontCheckOffset")
    local s = Vector3f.new(pos.x + up.x * rise + front.x * ahead,
        spine.y + up.y * rise + front.y * ahead,
        pos.z + up.z * rise + front.z * ahead)

    local cam_z = sdk.get_primary_camera():call("get_GameObject"):call("get_Transform"):call("get_AxisZ")
    local dir = Vector3f.new(-cam_z.x, -cam_z.y, -cam_z.z)  -- cameras look down -Z

    local length_rate, radius_rate = 1.0, 1.0
    if drv:get_field("_IsPrevApplyHoldFront") then
        length_rate = cfg:call("get_HoldFrontCheckEnableColliderLength")
        radius_rate = cfg:call("get_HoldFrontCheckEnableColliderRadius")
    end

    -- First stage of the check: characters, from the shared parameters.
    local my_addr = ctx:get_address()
    local friendly
    local function check_hit(radius, from, length, filter, face)
        local result = sdk.create_instance("app.CollisionCastResult")
        if not cast_first:call(nil, radius * radius_rate, from,
            along(from, dir, length * length_rate + LENGTH_MARGIN), result,
            filter:get_data(nil), face, OPTION_NONE) then
            return nil
        end
        local go = result:call("get_GameObject")
        if not go then return "hit has no object" end
        local go_addr = go:get_address()
        if not in_list(cm:call("getSpawnedNPCContextRefList"), go_addr, my_addr)
            and not in_list(cm:call("getPlayerContextRefs"), go_addr, my_addr) then
            return "not a friendly: " .. go:call("get_Name")
        end
        friendly = go:call("get_Name")
        return nil
    end
    local reason = check_hit(param:call("get_HoldFrontCheckRadius"), s,
        param:call("get_HoldFrontCheckLength"), character_filter, FACE_FRONT)
    if reason then return reason end

    -- Second stage: the wall check, from the weapon's parameters, or the game's built-in values for a
    -- weapon without any. Its small sideways offset is taken up in the radius instead of working out
    -- the game's aim frame.
    local wall = cfg:call("getWeaponHoldFrontCheckParam", updater:call("get_EquipWeaponID"))
    local wall_rise = wall and wall:call("get_HoldFrontCheckYOffset") or 0.0
    local wall_side = wall and wall:call("get_HoldFrontCheckOffset") or 0.0
    local wall_radius = wall and wall:call("get_HoldFrontCheckRadius") or DEFAULT_WALL_RADIUS
    local wall_length = wall and wall:call("get_HoldFrontCheckLength") or DEFAULT_WALL_LENGTH
    local wall_from = along(Vector3f.new(pos.x + up.x * wall_rise, spine.y + up.y * wall_rise,
        pos.z + up.z * wall_rise), dir, WALL_CHECK_START)
    reason = check_hit(wall_radius + math.abs(wall_side), wall_from, wall_length, effect_filter, FACE_BOTH)
    if reason then return reason end
    if not friendly then return "cast found nothing" end

    if cast_any:call(nil, wall_radius, wall_from, along(wall_from, dir, wall_length + LENGTH_MARGIN),
        terrain_filter:get_data(nil), FACE_FRONT, OPTION_NONE) then
        return "wall behind " .. friendly
    end
    return nil
end

sdk.hook(hold_td:get_method("isApplyHoldFrontInternal"),
    function(args)
        local storage = thread.get_hook_storage()
        if not storage then return end
        storage.drv = nil
        local ok, addr = pcall(player_hold_address)
        if ok and addr ~= nil and sdk.to_int64(args[2]) == addr then
            storage.drv = sdk.to_managed_object(args[2])
        end
    end,
    function(retval)
        local storage = thread.get_hook_storage()
        local drv = storage and storage.drv
        if not drv or (sdk.to_int64(retval) & 0xFF) == 0 then return retval end
        seen.game_yes = seen.game_yes + 1
        local ok, reason = pcall(keep_reason, drv)
        if not ok then
            seen.error = tostring(reason)
            return retval
        end
        seen.last = reason and ("kept: " .. reason) or "blocked: friendly"
        if reason then return retval end
        seen.blocked = seen.blocked + 1
        drv:set_field("_IsNearHitWallHoldFront", false)
        return sdk.to_ptr(0)
    end)

re.on_draw_ui(function()
    if not imgui.tree_node("No Short Hold At NPCs") then return end
    imgui.text("Last: " .. seen.last)
    imgui.text(string.format("Game asked for the hold %d times, blocked %d", seen.game_yes, seen.blocked))
    if seen.error then imgui.text("Error: " .. seen.error) end
    imgui.tree_pop()
end)
