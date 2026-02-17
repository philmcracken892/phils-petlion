local RSGCore = exports['rsg-core']:GetCoreObject()

RSGCore.Functions.CreateUseableItem("lion", function(source, item)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end

    Player.Functions.RemoveItem("lion", 1)
    TriggerClientEvent('rsg-sanctuary:client:spawnAnimal', source, 1)
end)

RegisterNetEvent('rsg-sanctuary:server:returnAnimalItem', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    Player.Functions.AddItem("lion", 1)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items["lion"], "add")
end)

RSGCore.Functions.CreateCallback('rsg-sanctuary:server:getCitizenId', function(source, cb, targetServerId)
    local targetServerId = targetServerId or source
    local Player = RSGCore.Functions.GetPlayer(targetServerId)

    if Player then
        local citizenId = Player.PlayerData.citizenid
        cb(citizenId)
    else
        cb(nil)
    end
end)