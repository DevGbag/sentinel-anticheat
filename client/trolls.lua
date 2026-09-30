--[[
Client-side troll effects (server half: server/anticheat/trolls.lua,
definitions: shared/trolls.lua). `harmless` has no client effect — it's
enforced server-side.
]]

local active = {}  -- name -> GetGameTimer() expiry
local cleanup = {} -- name -> function that undoes the effect

local function loadModel(model)
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end
    return HasModelLoaded(model)
end

local function stop(name)
    active[name] = nil
    local fn = cleanup[name]
    cleanup[name] = nil
    if fn then fn() end
end

local function stopAll()
    for name in pairs(active) do stop(name) end
    for name in pairs(cleanup) do stop(name) end
end

local effects = {}

effects.launch = function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        SetEntityVelocity(veh, 0.0, 0.0, 60.0)
    else
        SetPedToRagdoll(ped, 6000, 6000, 0, false, false, false)
        SetEntityVelocity(ped, 0.0, 0.0, 60.0)
    end
end

effects.fire = function()
    StartEntityFire(PlayerPedId())
end

effects.drunk = function()
    local ped = PlayerPedId()
    local clipset = 'move_m@drunk@verydrunk'
    RequestAnimSet(clipset)
    local timeout = GetGameTimer() + 3000
    while not HasAnimSetLoaded(clipset) and GetGameTimer() < timeout do Wait(0) end

    SetPedMovementClipset(ped, clipset, 1.0)
    SetPedIsDrunk(ped, true)
    ShakeGameplayCam('DRUNK_SHAKE', 2.0)
    SetTimecycleModifier('drug_wobbly')
    return function()
        ResetPedMovementClipset(PlayerPedId(), 0.0)
        SetPedIsDrunk(PlayerPedId(), false)
        StopGameplayCamShaking(true)
        ClearTimecycleModifier()
    end
end

effects.blind = function()
    DoScreenFadeOut(500)
    return function() DoScreenFadeIn(500) end
end

effects.slippery = function()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then return end
    SetVehicleReduceGrip(veh, true)
    for wheel = 0, 5 do SetVehicleTyreBurst(veh, wheel, true, 1000.0) end
    return function()
        if DoesEntityExist(veh) then SetVehicleReduceGrip(veh, false) end
    end
end

effects.attackers = function()
    local ped = PlayerPedId()
    local model = `a_c_mtlion`
    if not loadModel(model) then return end

    local spawned = {}
    local origin = GetEntityCoords(ped)
    for i = 1, 3 do
        local angle = i * (2 * math.pi / 3)
        local lion = CreatePed(28, model, origin.x + math.cos(angle) * 8.0, origin.y + math.sin(angle) * 8.0, origin.z, 0.0, true, false)
        SetPedRelationshipGroupHash(lion, `HATES_PLAYER`)
        SetPedCombatAttributes(lion, 46, true)
        TaskCombatPed(lion, ped, 0, 16)
        spawned[#spawned + 1] = lion
    end
    SetModelAsNoLongerNeeded(model)

    return function()
        for _, lion in ipairs(spawned) do
            if DoesEntityExist(lion) then DeleteEntity(lion) end
        end
    end
end

effects.fakeCrash = function()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetTimeScale(0.0)
    StartAudioScene('MP_LEADERBOARD_SCENE') -- mutes most game audio
    active.lockControls = GetGameTimer() + 60000 -- the server drops them long before this
    return function()
        SetTimeScale(1.0)
        StopAudioScene('MP_LEADERBOARD_SCENE')
        FreezeEntityPosition(PlayerPedId(), false)
    end
end

-- ragdoll, lockControls and noShoot are applied every frame in the loop below
RegisterNetEvent('sentinel:client:troll', function(name, seconds)
    local def = SentinelTrollByName[name]
    if not def then return end

    if def.timed then
        stop(name) -- re-applying restarts the effect with the new duration
        active[name] = GetGameTimer() + (tonumber(seconds) or 30) * 1000
    end
    if effects[name] then
        cleanup[name] = effects[name]()
    end
end)

RegisterNetEvent('sentinel:client:trollStop', stopAll)

-- expiry
CreateThread(function()
    while true do
        Wait(250)
        local now = GetGameTimer()
        for name, expires in pairs(active) do
            if now >= expires then stop(name) end
        end
    end
end)

-- per-frame effects
CreateThread(function()
    while true do
        if active.ragdoll or active.lockControls or active.noShoot then
            Wait(0)
            local ped = PlayerPedId()
            if active.ragdoll and not IsPedRagdoll(ped) then
                SetPedToRagdoll(ped, 2000, 2000, 0, false, false, false)
            end
            if active.lockControls then
                DisableAllControlActions(0)
                EnableControlAction(0, 1, true) -- look left/right
                EnableControlAction(0, 2, true) -- look up/down
            end
            if active.noShoot then
                DisablePlayerFiring(PlayerId(), true)
                DisableControlAction(0, 24, true)  -- attack
                DisableControlAction(0, 257, true) -- attack 2
                DisableControlAction(0, 140, true) -- melee light
                DisableControlAction(0, 141, true) -- melee heavy
                DisableControlAction(0, 142, true) -- melee alternate
            end
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    stopAll()
    SetTimeScale(1.0)
end)
