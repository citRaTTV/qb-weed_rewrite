-- Variables
local QBCore = exports['qb-core']:GetCoreObject()
local plants = {}

-- Functions
local function spawnPlant(plant)
    local entity = CreateObject(joaat(Config.Strains[plant.data.strain].stages[plant.data.stage].prop), plant.coords.x, plant.coords.y, plant.coords.z, true, true, false)
    while not DoesEntityExist(entity) do Wait(10) end
    FreezeEntityPosition(entity, true)
    ---@diagnostic disable-next-line: missing-parameter, param-type-mismatch
    SetEntityCoords(entity, plant.coords, true, true, false, false)
    plant.netId = NetworkGetNetworkIdFromEntity(entity)
    Entity(entity).state:set('weedplantID', plant.id, true)
end

local function syncPlants(foodTick)
    local curTime = os.time()
    for i = 1, #plants do
        if plants[i].data.dead then goto next end
        if foodTick then
            plants[i].data.water = math.max(plants[i].data.water - 1, 0)
            plants[i].data.food = math.max(plants[i].data.food - 1, 0)
        end

        if foodTick and plants[i].data.water <= 0 or plants[i].data.food <= 0 then
            plants[i].data.health = math.max(plants[i].data.health - 1, 0)
        end

        plants[i].data.progress = math.min((curTime - plants[i].data.planted) / (plants[i].data.nextStage - plants[i].data.planted), 1)
        if plants[i].data.health > 50 and plants[i].data.progress == 1 then
            if plants[i].data.stage < #Config.Strains[plants[i].data.strain].stages then
                if plants[i].netId then
                    DeleteEntity(NetworkGetEntityFromNetworkId(plants[i].netId))
                    plants[i].netId = nil
                end
                plants[i].data.stage += 1
                plants[i].data.progress = 0
                plants[i].data.nextStage = curTime + (Config.Strains[plants[i].data.strain].stages[plants[i].data.stage].growTime * 60)
                plants[i].data.planted = curTime
            elseif curTime + (Config.Strains[plants[i].data.strain].stages[plants[i].data.stage] * 60) >= plants[i].data.nextStage then
                plants[i].data.dead = true
            end
        elseif plants[i].data.health == 0 then
            plants[i].data.dead = true
        elseif foodTick then
            local stagnateTime = Config.TickTime * 60
            plants[i].data.nextStage += stagnateTime
            plants[i].data.planted += stagnateTime
        end

        MySQL.query("UPDATE `weed_plants` SET `data` = ? WHERE `id` = ?", { json.encode(plants[i].data), plants[i].id })

        if not plants[i].netId then
            spawnPlant(plants[i])
        end
        Entity(NetworkGetEntityFromNetworkId(plants[i].netId)).state:set('weedplantData', json.encode(plants[i].data), true)
        ::next::
    end

    if Config.Debug then QBCore.Debug(plants) end
end

local function savePlant(strain, coords, curHouse)
    local curTime = os.time()
    local plantData = {
        strain = strain,
        health = 100,
        water = 0,
        food = 0,
        stage = 1,
        gender = math.random() >= 0.5 and 0 or 1,
        planted = curTime,
        nextStage = curTime + (Config.Strains[strain].stages[1].growTime * 60),
        dead = false,
    }
    MySQL.insert([[
        INSERT INTO `weed_plants` (`coords`, `house`, `data`) VALUES (?, ?, ?)
    ]], {
        json.encode(coords),
        curHouse,
        json.encode(plantData),
    }, function(id)
        plants[#plants+1] = {
            id = id,
            coords = coords,
            house = curHouse,
            data = plantData,
        }
        syncPlants(false)
    end)
end

exports('SavePlant', savePlant)

local function getPlant(plantID)
    for i = 1, #plants do
        if plants[i].id == plantID then
            return plants[i]
        end
    end
end

local function init()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `weed_plants` (
            `id` int NOT NULL AUTO_INCREMENT PRIMARY KEY,
            `coords` varchar(100) NOT NULL,
            `house` varchar(100) NULL,
            `data` text NOT NULL
        ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    ]])

    MySQL.query("SELECT * FROM `weed_plants`", {}, function(_plants)
        for i = 1, #_plants do
            local plantData = json.decode(_plants[i].data)
            local coords = json.decode(_plants[i].coords)
            if plantData.dead then
                MySQL.query("DELETE FROM `weed_plants` WHERE id = ?", { _plants[i].id })
            end
            plants[#plants+1] = {
                id = _plants[i].id,
                coords = vector3(coords.x, coords.y, coords.z),
                house = _plants[i].house,
                data = plantData,
            }
        end

        Wait(1000)
        syncPlants(false)
    end)
end

-- Events
RegisterNetEvent('qb-weed:server:savePlant', function(item, strain, coords)
    local src = source
    if not src then return end
    local QPlayer = QBCore.Functions.GetPlayer(src)
    if #(GetEntityCoords(GetPlayerPed(src)) - coords) > 10.0 then
        print(("POSSIBLE EXPLOIT: Player distance over 10 from plant. CID: %s"):format(QPlayer.PlayerData.citizenid))
        return
    end
    if exports['qb-inventory']:RemoveItem(src, item.name, 1, item.slot, 'Planting weed') then
        savePlant(strain, coords, Player(src).state.currentHouse)
    end
end)

RegisterNetEvent('qb-weed:server:harvest', function(netId, giveItems)
    local src = source
    if not src then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    local plant = getPlant(Entity(entity).state.weedplantID)

    if not plant or #(GetEntityCoords(GetPlayerPed(src)) - plant.coords) > 10.0 then
        local QPlayer = QBCore.Functions.GetPlayer(src)
        print(("POSSIBLE EXPLOIT: Player distance over 10 from plant. CID: %s"):format(QPlayer.PlayerData.citizenid))
        return
    end
    if giveItems and plant.data.health > 0 then
        local amount = math.random(12, 16)
        if exports['qb-inventory']:RemoveItem(src, 'empty_weed_bag', amount, nil, 'Harvesting weed') then
            local item = (plant.data.gender == 1 and 'weed_%s_seed' or 'weed_%s'):format(plant.data.strain)
            exports['qb-inventory']:AddItem(src, item, amount, nil, nil, 'Harvesting weed')
            TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items['empty_weed_bag'], 'remove', amount)
            TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add', amount)
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t('error.you_dont_have_enough_resealable_bags'), 'error', 5000)
            return
        end
    end

    DeleteEntity(entity)
    MySQL.query("DELETE FROM `weed_plants` WHERE `id` = ?", { plant.id })
    TriggerClientEvent('QBCore:Notify', src, Lang:t('text.the_plant_has_been_harvested'), 'success', 3500)
    plant = nil
end)

RegisterNetEvent('qb-weed:server:feed', function(netId, foodType)
    local src = source
    if not src then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    local plant = getPlant(Entity(entity).state.weedplantID)
    local item = foodType == 1 and 'weed_nutrition' or 'water_bottle'

    if #(GetEntityCoords(GetPlayerPed(src)) - plant.coords) > 10.0 then
        local QPlayer = QBCore.Functions.GetPlayer(src)
        print(("POSSIBLE EXPLOIT: Player distance over 10 from plant. CID: %s"):format(QPlayer.PlayerData.citizenid))
        return
    end

    if exports['qb-inventory']:RemoveItem(src, item, 1, nil, 'Feeding weed') then
        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'remove', 1)
        plant.data[(foodType == 1 and 'food' or 'water')] = 100
        Entity(entity).state:set('weedplantData', json.encode(plant.data), true)
        syncPlants(false)
    else
        TriggerClientEvent('QBCore:Notify', src, "You need to have food or water", 'error')
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    init()

    for plantName, _ in pairs(Config.Strains) do
        QBCore.Functions.CreateUseableItem('weed_' .. plantName .. '_seed', function(source, item)
            TriggerClientEvent('qb-inventory:client:ItemBox', source, QBCore.Shared.Items['weed_' .. plantName .. '_seed'], 'remove', 1)
            TriggerClientEvent('qb-weed:client:placePlant', source, plantName, item)
        end)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for i = 1, #plants do
        if plants[i].netId then
            DeleteEntity(NetworkGetEntityFromNetworkId(plants[i].netId))
        end
    end
end)

-- Callbacks
lib.callback.register('qb-weed:server:checkTooClose', function(source, coords)
    for i = 1, #plants do
        if #(coords - plants[i].coords) < 1.5 then return false end
    end
    return true
end)

-- Threads
CreateThread(function()
    while true do
        Wait(Config.TickTime * 60 * 1000)
        syncPlants(true)
    end
end)