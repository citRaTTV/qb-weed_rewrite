-- Variables
local QBCore = exports['qb-core']:GetCoreObject()
local SBHandler

-- Functions
local function checkPlant(entity)
    local plantData = json.decode(Entity(entity).state.weedplantData)

    exports['qb-menu']:openMenu({
        {
            isMenuHeader = true,
            header = 'Plant Status',
            txt = "Detailed weed plant status",
        },
        {
            header = 'Strain',
            txt = Config.Strains[plantData.strain].label,
        },
        {
            header = 'Stage',
            txt = Config.Strains[plantData.strain].stages[plantData.stage].label,
        },
        {
            header = 'Stage Growth Progress',
            txt = ("%d%%"):format(math.floor(plantData.progress * 100)),
        },
        {
            header = 'Gender',
            txt = plantData.gender == 1 and 'Male' or 'Female',
        },
        {
            header = 'Health',
            txt = ("%d%%"):format(math.floor(plantData.health)),
        },
        {
            header = 'Water',
            txt = ("%d%%"):format(math.floor(plantData.water)),
        },
        {
            header = 'Nutrients',
            txt = ("%d%%"):format(math.floor(plantData.food)),
        },
    })
end

local function harvestPlant(entity, harvest)
    LocalPlayer.state:set('inv_busy', true, true)
    exports['qb-target']:AllowTargeting(false)
    QBCore.Functions.Progressbar('remove_weed_plant', Lang:t(harvest and 'text.harvesting_plant' or 'text.removing_the_plant'), 30000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'amb@world_human_gardener_plant@male@base',
        anim = 'base',
        flags = 1,
    }, {}, {}, function() -- Done
        TriggerServerEvent('qb-weed:server:harvest', NetworkGetNetworkIdFromEntity(entity), harvest)
        LocalPlayer.state:set('inv_busy', false, true)
        exports['qb-target']:AllowTargeting(true)
    end, function() -- Cancel
        QBCore.Functions.Notify(Lang:t('error.process_canceled'), 'error')
        LocalPlayer.state:set('inv_busy', false, true)
        exports['qb-target']:AllowTargeting(true)
    end)
end

local function feedPlant(entity, foodType)
    if not exports['qb-inventory']:HasItem((foodType == 1 and 'weed_nutrition' or 'water_bottle'), 1) then
        QBCore.Functions.Notify("You need food or water", 'error')
        return
    end
    LocalPlayer.state:set('inv_busy', true, true)
    exports['qb-target']:AllowTargeting(false)
    QBCore.Functions.Progressbar('feed_weed_plant', Lang:t('text.feeding_plant'), 10000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'timetable@gardener@filling_can',
        anim = 'gar_ig_5_filling_can',
        flags = 1,
    }, {}, {}, function() -- Done
        TriggerServerEvent('qb-weed:server:feed', NetworkGetNetworkIdFromEntity(entity), foodType)
        LocalPlayer.state:set('inv_busy', false, true)
        exports['qb-target']:AllowTargeting(true)
    end, function() -- Cancel
        QBCore.Functions.Notify(Lang:t('error.process_canceled'), 'error')
        LocalPlayer.state:set('inv_busy', false, true)
        exports['qb-target']:AllowTargeting(true)
    end)
end

local function createTarget(entity, plantData)
    exports['qb-target']:RemoveTargetEntity(entity)
    exports['qb-target']:AddTargetEntity(entity, {
        options = {
            {
                num = 1,
                label = "Check plant",
                icon = 'fas fa-seedling',
                action = checkPlant,
            },
            {
                num = 2,
                label = "Harvest plant",
                icon = 'fas fa-sack-dollar',
                canInteract = function()
                    return plantData.stage == #Config.Strains[plantData.strain].stages
                end,
                action = function()
                    harvestPlant(entity, true)
                end,
            },
            {
                num = 3,
                label = "Chop down plant",
                icon = 'fas fa-scissors',
                action = function()
                    harvestPlant(entity, false)
                end,
            },
            {
                num = 4,
                label = "Water plant",
                icon = 'fas fa-droplet',
                canInteract = function()
                    return not plantData.dead
                end,
                action = function()
                    feedPlant(entity, 0)
                end,
            },
            {
                num = 5,
                label = "Feed plant",
                icon = 'fas fa-mound',
                canInteract = function()
                    return not plantData.dead
                end,
                action = function()
                    feedPlant(entity, 1)
                end,
            },
        },
        distance = 1.5,
    })
end

-- Events
RegisterNetEvent('qb-weed:client:placePlant', function(strain, item)
    local plantCoords = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0, 0.75, -1.0)

    if not lib.callback.await('qb-weed:server:checkTooClose', nil, plantCoords) then
        QBCore.Functions.Notify(Lang:t('error.cant_place_here'), 'error', 3500)
        return
    end

    LocalPlayer.state:set('inv_busy', true, true)
    QBCore.Functions.Progressbar('plant_weed_plant', Lang:t('text.planting'), 8000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'amb@world_human_gardener_plant@male@base',
        anim = 'base',
        flags = 1,
    }, {}, {}, function() -- Done
        TriggerServerEvent('qb-weed:server:savePlant', item, strain, plantCoords)
        LocalPlayer.state:set('inv_busy', false, true)
    end, function() -- Cancel
        QBCore.Functions.Notify(Lang:t('error.process_canceled'), 'error')
        LocalPlayer.state:set('inv_busy', false, true)
    end)
end)

RegisterNetEvent('qb-weed:client:getHousePlants', function(house)
    -- TODO: Add housing & apartment support
    LocalPlayer.state:set('currentHouse', house, true)
end)

RegisterNetEvent('qb-weed:client:leaveHouse', function()
    LocalPlayer.state:set('currentHouse', nil, true)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SBHandler = AddStateBagChangeHandler('weedplantData', nil, function(bagName, key, plantData)
        local entity = GetEntityFromStateBagName(bagName)
        if not DoesEntityExist(entity) then return end
        createTarget(entity, json.decode(plantData))
    end)

    for _, data in pairs(Config.Strains) do
        for i = 1, #data.stages do
            RequestModel(data.stages[i].prop)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    RemoveStateBagChangeHandler(SBHandler)
end)
