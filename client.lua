local RSGCore = exports['rsg-core']:GetCoreObject()
local CHECK_RADIUS = 5.0
local ANIMAL_TYPES = {
    {
        label = "lion",
        model = `a_c_lionmangy_01`,
        health = 300,
        speed = 1.5
    },
}

local spawnedAnimals = {}
local animalCounter = 0

function FindAndAttackNearbyTarget(animal)
    local coords = GetEntityCoords(animal)
    local nearbyPeds = GetGamePool('CPed')

    for _, ped in ipairs(nearbyPeds) do
        if DoesEntityExist(ped) and not IsPedAPlayer(ped) and ped ~= animal then
            local dist = #(coords - GetEntityCoords(ped))
            if dist < 20.0 and not IsPedDeadOrDying(ped, true) then
                TaskCombatPed(animal, ped, 0, 16)
                break
            end
        end
    end
end

local function MakeAnimalFollow(entity)
    if not DoesEntityExist(entity) then return end

    SetEntityInvincible(entity, false)
    local playerPed = PlayerPedId()
    local heading = GetEntityHeading(playerPed)

    local followOffset = vector3(
        3.0 * math.sin(math.rad(heading + math.random(-45, 45))),
        3.0 * math.cos(math.rad(heading + math.random(-45, 45))),
        0.0
    )

    TaskFollowToOffsetOfEntity(entity, playerPed, followOffset.x, followOffset.y, followOffset.z, 1.0, -1, 2.0, true)
    DecorSetBool(entity, "IsFollowing", true)
    DecorSetBool(entity, "IsStaying", false)
end

local function MakeAnimalStay(entity)
    if not DoesEntityExist(entity) then return end

    ClearPedTasks(entity)
    TaskStandStill(entity, -1)
    SetEntityInvincible(entity, true)
    DecorSetBool(entity, "IsStaying", true)
    DecorSetBool(entity, "IsFollowing", false)
end

local function MakeAnimalDefault(entity)
    if not DoesEntityExist(entity) then return end

    SetEntityInvincible(entity, false)
    ClearPedTasks(entity)
    DecorSetBool(entity, "IsStaying", false)
    DecorSetBool(entity, "IsFollowing", false)

    TaskWanderStandard(entity, 10.0, 10)
end

local function SetupAnimalBehavior(entity)
    if not DoesEntityExist(entity) then return end

    local playerGroupHash = GetHashKey("OWNER_" .. tostring(GetPlayerServerId(PlayerId())))

    AddRelationshipGroup("OWNER_" .. tostring(GetPlayerServerId(PlayerId())))

    SetRelationshipBetweenGroups(1, playerGroupHash, `PLAYER`)
    SetRelationshipBetweenGroups(1, `PLAYER`, playerGroupHash)

    SetRelationshipBetweenGroups(5, playerGroupHash, `CIVMALE`)
    SetRelationshipBetweenGroups(5, playerGroupHash, `CIVFEMALE`)
    SetRelationshipBetweenGroups(5, playerGroupHash, `AMBIENT_GANG_LOWER`)
    SetRelationshipBetweenGroups(5, playerGroupHash, `REL_NO_RELATIONSHIP`)
    SetRelationshipBetweenGroups(5, playerGroupHash, `REL_GANG_DUTCHS`)
    SetRelationshipBetweenGroups(5, playerGroupHash, `REL_GANG_ODRISCOLLS`)
    SetRelationshipBetweenGroups(5, playerGroupHash, `REL_GANG_SKINNER_BROTHERS`)
    SetRelationshipBetweenGroups(5, playerGroupHash, `REL_GANG_LEMOYNE_RAIDERS`)

    SetPedRelationshipGroupHash(entity, playerGroupHash)

    SetPedAsCop(entity, false)
    SetBlockingOfNonTemporaryEvents(entity, true)
    SetPedFleeAttributes(entity, 0, false)
    SetPedCombatAttributes(entity, 5, true)
    SetPedCombatAttributes(entity, 46, true)
    SetPedCombatAttributes(entity, 0, true)
    SetPedCombatRange(entity, 2)
    SetPedCombatMovement(entity, 2)

    SetPedCanRagdoll(entity, false)
    SetEntityInvincible(entity, false)

    DecorSetBool(entity, "IsFollowing", true)
    DecorSetBool(entity, "IsStaying", false)

    MakeAnimalFollow(entity)
end

local function GetAnimalTypeByModel(model)
    for _, animal in ipairs(ANIMAL_TYPES) do
        if animal.model == model then
            return animal
        end
    end
    return nil
end

local function IsPlayerOwner(animalEntity)
    local playerServerId = GetPlayerServerId(PlayerId())
    if spawnedAnimals[playerServerId] then
        for _, animalData in pairs(spawnedAnimals[playerServerId]) do
            if animalData.entity == animalEntity then
                return true
            end
        end
    end
    return false
end

local function GetPlayerAnimalCount()
    local playerServerId = GetPlayerServerId(PlayerId())
    if spawnedAnimals[playerServerId] then
        local count = 0
        for _ in pairs(spawnedAnimals[playerServerId]) do
            count = count + 1
        end
        return count
    end
    return 0
end

local function HasLionSpawned()
    local playerServerId = GetPlayerServerId(PlayerId())
    if spawnedAnimals[playerServerId] then
        for _, animalData in pairs(spawnedAnimals[playerServerId]) do
            if animalData.type == 'lion' then
                return true
            end
        end
    end
    return false
end

local function RegisterAnimalTargeting()
    local models = {}
    for _, animal in ipairs(ANIMAL_TYPES) do
        table.insert(models, animal.model)
    end

    exports['ox_target']:addModel(models, {
        {
            name = 'toggle_follow',
            event = 'rsg-sanctuary:client:toggleFollow',
            icon = "fas fa-walking",
            label = "Toggle Follow/Stay",
            distance = 3.0,
            canInteract = function(entity)
                return IsPlayerOwner(entity)
            end
        },
        {
            name = 'pickup',
            event = 'rsg-sanctuary:client:pickupAnimal',
            icon = "fas fa-hand",
            label = "Pick Up",
            distance = 2.0,
            canInteract = function(entity)
                return IsPlayerOwner(entity)
            end
        }
    })
end

CreateThread(function()
    exports['ox_target']:addGlobalPed({
        {
            name = 'attack_with_lion',
            icon = 'fas fa-dog',
            label = 'Command Lion to Attack',
            distance = 3.0,
            canInteract = function(entity)
                return HasLionSpawned() and IsPedHuman(entity) and not IsPedAPlayer(entity)
            end,
            onSelect = function(data)
                local target = data.entity
                TriggerEvent('rsg-sanctuary:client:animalAttackTarget', target)
            end
        }
    })
end)

RegisterNetEvent('rsg-sanctuary:client:animalAttackTarget', function(target)
    if not DoesEntityExist(target) or IsEntityDead(target) then
        lib.notify({ title = 'Invalid Target', description = 'Target is invalid or dead.', type = 'error' })
        return
    end

    local playerServerId = GetPlayerServerId(PlayerId())
    local playerAnimals = spawnedAnimals[playerServerId]

    if not playerAnimals then
        lib.notify({ title = 'No Animals', description = "You don't have any animals spawned.", type = 'error' })
        return
    end

    local closestAnimal = nil
    local closestDist = 9999.0
    local playerCoords = GetEntityCoords(PlayerPedId())

    for _, animal in pairs(playerAnimals) do
        if DoesEntityExist(animal.entity) and animal.type == 'lion' then
            local dist = #(GetEntityCoords(animal.entity) - playerCoords)
            if dist < closestDist then
                closestDist = dist
                closestAnimal = animal.entity
            end
        end
    end

    if not closestAnimal then
        lib.notify({ title = 'No Lion Found', description = 'Could not find your lion.', type = 'error' })
        return
    end

    ClearPedTasksImmediately(closestAnimal)

    SetPedCombatAttributes(closestAnimal, 16, false)
    SetPedCombatAttributes(closestAnimal, 46, true)
    SetPedCombatAttributes(closestAnimal, 5, false)
    SetPedCombatAttributes(closestAnimal, 0, true)
    SetPedCombatAttributes(closestAnimal, 1, false)

    TaskCombatPed(closestAnimal, target, 0, 16)

    CreateThread(function()
        while DoesEntityExist(target) and not IsEntityDead(target) do
            Wait(500)
        end

        if DoesEntityExist(closestAnimal) then
            ClearPedTasksImmediately(closestAnimal)
            MakeAnimalFollow(closestAnimal)
            lib.notify({
                title = 'Target Eliminated',
                description = 'Your animal has returned to you.',
                type = 'success'
            })
        end
    end)

    lib.notify({
        title = 'Attack Command',
        description = 'Your animal is attacking the target!',
        type = 'success'
    })
end)

RegisterNetEvent('rsg-sanctuary:client:spawnAnimal')
AddEventHandler('rsg-sanctuary:client:spawnAnimal', function(animalIndex)
    local playerServerId = GetPlayerServerId(PlayerId())
    local currentCount = GetPlayerAnimalCount()

    if currentCount >= 1 then
        lib.notify({
            title = 'Limit Reached',
            description = 'You can only have one animal spawned at a time.',
            type = 'error'
        })
        return
    end

    local animalData = ANIMAL_TYPES[animalIndex]
    if not animalData then return end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local forward = GetEntityForwardVector(ped)

    local offsetDistance = math.random(2, 4)
    local sideOffset = math.random(-2, 2)
    local x = coords.x + forward.x * offsetDistance + sideOffset
    local y = coords.y + forward.y * offsetDistance + sideOffset
    local z = coords.z

    local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, z + 1.0, false)
    if foundGround then
        z = groundZ
    end

    RequestModel(animalData.model)
    while not HasModelLoaded(animalData.model) do
        Wait(100)
    end

    local wasInventoryBusy = false
    if LocalPlayer.state then
        wasInventoryBusy = LocalPlayer.state.inv_busy or false
        LocalPlayer.state:set('inv_busy', true, true)
    end

    TaskStartScenarioInPlace(ped, GetHashKey('WORLD_HUMAN_CROUCH_INSPECT'), 2000, true, false, false, false)

    Wait(5000)

    local animalPed = CreatePed(animalData.model, x, y, z, heading, true, false, false, false)

    ClearPedTasks(ped)
    ClearPedTasksImmediately(ped)

    if LocalPlayer.state then
        LocalPlayer.state:set('inv_busy', wasInventoryBusy, true)
    end

    if animalPed and DoesEntityExist(animalPed) then
        Citizen.InvokeNative(0x23F74C2FDA6E7C61, -1749618580, animalPed)
        Citizen.InvokeNative(0x77FF8D35EEC6BBC4, animalPed, 0, false)
        SetupAnimalBehavior(animalPed)

        SetEntityHealth(animalPed, animalData.health)
        SetEntityMaxHealth(animalPed, animalData.health)

        animalCounter = animalCounter + 1
        if not spawnedAnimals[playerServerId] then
            spawnedAnimals[playerServerId] = {}
        end

        spawnedAnimals[playerServerId][animalCounter] = {
            entity = animalPed,
            model = animalData.model,
            type = animalData.label,
            health = animalData.health,
            spawnTime = GetGameTimer(),
            id = animalCounter
        }

        lib.notify({
            title = 'Spawned',
            description = 'Your ' .. animalData.label .. ' is now following you!',
            type = 'success'
        })
    else
        ClearPedTasks(ped)
        ClearPedTasksImmediately(ped)
        if LocalPlayer.state then
            LocalPlayer.state:set('inv_busy', wasInventoryBusy, true)
        end
    end

    SetModelAsNoLongerNeeded(animalData.model)
end)

RegisterNetEvent('rsg-sanctuary:client:toggleFollow', function(data)
    local entity = data.entity
    if not DoesEntityExist(entity) then return end

    local isStaying = DecorGetBool(entity, "IsStaying")
    local isFollowing = DecorGetBool(entity, "IsFollowing")

    if isStaying then
        MakeAnimalFollow(entity)
        lib.notify({
            title = "Following",
            description = "Your animal is now following you.",
            type = 'success'
        })
    elseif isFollowing then
        MakeAnimalStay(entity)
        lib.notify({
            title = "Staying",
            description = "Your animal will stay here.",
            type = 'success'
        })
    else
        MakeAnimalFollow(entity)
        lib.notify({
            title = "Following",
            description = "Your animal is now following you.",
            type = 'success'
        })
    end
end)

RegisterNetEvent('rsg-sanctuary:client:pickupAnimal', function(data)
    local animalEntity = data.entity

    if not IsPlayerOwner(animalEntity) then
        lib.notify({
            title = "Not Your Animal",
            description = "This isn't your animal to pick up.",
            type = 'error'
        })
        return
    end

    local ped = PlayerPedId()

    local wasInventoryBusy = false
    if LocalPlayer.state then
        wasInventoryBusy = LocalPlayer.state.inv_busy or false
        LocalPlayer.state:set('inv_busy', true, true)
    end

    TaskStartScenarioInPlace(ped, GetHashKey('WORLD_HUMAN_CROUCH_INSPECT'), 2000, true, false, false, false)
    Wait(2000)

    ClearPedTasks(ped)
    ClearPedTasksImmediately(ped)

    if LocalPlayer.state then
        LocalPlayer.state:set('inv_busy', wasInventoryBusy, true)
    end

    local playerServerId = GetPlayerServerId(PlayerId())
    if spawnedAnimals[playerServerId] then
        for id, animalData in pairs(spawnedAnimals[playerServerId]) do
            if animalData.entity == animalEntity then
                DeletePed(animalEntity)
                spawnedAnimals[playerServerId][id] = nil
                TriggerServerEvent('rsg-sanctuary:server:returnAnimalItem')
                break
            end
        end
    end

    lib.notify({
        title = 'Picked Up',
        description = 'You have retrieved your animal.',
        type = 'success'
    })
end)

RegisterNetEvent('rsg-sanctuary:client:callAnimals', function()
    local playerServerId = GetPlayerServerId(PlayerId())
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)

    if not spawnedAnimals[playerServerId] then
        lib.notify({
            title = "No Animals",
            description = "You don't have any animals spawned.",
            type = 'error'
        })
        return
    end

    local count = 0
    for id, animalData in pairs(spawnedAnimals[playerServerId]) do
        if DoesEntityExist(animalData.entity) then
            local animalCoords = GetEntityCoords(animalData.entity)
            local distance = #(playerCoords - animalCoords)

            if distance < 50.0 then
                ClearPedTasks(animalData.entity)
                MakeAnimalFollow(animalData.entity)
                count = count + 1
            end
        end
    end

    if count > 0 then
        lib.notify({
            title = 'Animals Called',
            description = 'Called ' .. count .. ' animals to follow you.',
            type = 'success'
        })
    else
        lib.notify({
            title = 'No Animals Nearby',
            description = 'No animals are close enough to call.',
            type = 'error'
        })
    end
end)

RegisterNetEvent('rsg-sanctuary:client:makeAllStay', function()
    local playerServerId = GetPlayerServerId(PlayerId())

    if not spawnedAnimals[playerServerId] then
        lib.notify({
            title = "No Animals",
            description = "You don't have any animals spawned.",
            type = 'error'
        })
        return
    end

    local count = 0
    for id, animalData in pairs(spawnedAnimals[playerServerId]) do
        if DoesEntityExist(animalData.entity) then
            MakeAnimalStay(animalData.entity)
            count = count + 1
        end
    end

    if count > 0 then
        lib.notify({
            title = 'Staying',
            description = 'Made ' .. count .. ' animals stay in place.',
            type = 'success'
        })
    end
end)

CreateThread(function()
    while true do
        Wait(5000)

        local playerServerId = GetPlayerServerId(PlayerId())
        if spawnedAnimals[playerServerId] then
            for id, animalData in pairs(spawnedAnimals[playerServerId]) do
                if DoesEntityExist(animalData.entity) then
                    local isFollowing = DecorGetBool(animalData.entity, "IsFollowing")
                    local isStaying = DecorGetBool(animalData.entity, "IsStaying")

                    if isFollowing and not isStaying then
                        local currentTask = Citizen.InvokeNative(0x35B13D7BE9B03A9F, animalData.entity)
                        if currentTask == 0 then
                            MakeAnimalFollow(animalData.entity)
                        end
                    end
                else
                    spawnedAnimals[playerServerId][id] = nil
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(30000)

        local playerServerId = GetPlayerServerId(PlayerId())
        if spawnedAnimals[playerServerId] then
            for id, animalData in pairs(spawnedAnimals[playerServerId]) do
                if not DoesEntityExist(animalData.entity) then
                    spawnedAnimals[playerServerId][id] = nil
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    local playerServerId = GetPlayerServerId(PlayerId())
    if spawnedAnimals[playerServerId] then
        for _, animalData in pairs(spawnedAnimals[playerServerId]) do
            if DoesEntityExist(animalData.entity) then
                DeletePed(animalData.entity)
            end
        end
    end
end)

CreateThread(function()
    DecorRegister("IsFollowing", 2)
    DecorRegister("IsStaying", 2)

    RegisterAnimalTargeting()
end)