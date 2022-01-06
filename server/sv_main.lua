local CoreName = exports['qb-core']:GetCoreObject()
local oxmysql = exports.oxmysql

RegisterServerEvent('keep-carInventoryWeight:server:playerVehicleData')
AddEventHandler('keep-carInventoryWeight:server:playerVehicleData', function(plate, class)
    local src = source
    local Player = CoreName.Functions.GetPlayer(src)

    Result = oxmysql:fetchSync(
        'SELECT players.charinfo ,players.citizenid , player_vehicles.plate , player_vehicles.fakeplate , player_vehicles.vehicle , player_vehicles.hash ,player_vehicles.maxweight from players INNER join player_vehicles on players.citizenid = player_vehicles.citizenid WHERE plate = ?',
        {plate})

    if Result then
        local sv_response = createServerResponse(Result, class)
        TriggerClientEvent("keep-carInventoryWeight:Client:Sv_OpenUI", src, sv_response)
        return true
    end
    return false
end)

RegisterNetEvent('keep-carInventoryWeight:server:reciveUpgradeReq', function(upgradeReqData)
    -- process upgrade request sent by client
    local src = source
    local upgrade = {}

    if upgrade ~= nil then
        -- client wants to upgrade
        upgradePocess(src, upgradeReqData)
    end
end)

function upgradePocess(src, upgradeReqData)
    local plate = upgradeReqData["plate"]
    local weightUpgrades = oxmysql:scalarSync('SELECT weightUpgrades from player_vehicles where plate = ?', {plate})

    if weightUpgrades ~= nil then
        if saveCarWeight(src, upgradeReqData, weightUpgrades) then
            TriggerClientEvent('QBCore:Notify', src, 'Upgrade was successful', 'success', 3500)
            TriggerClientEvent('keep-carInventoryWeight:Client:CloseUI', src)
        else
            TriggerClientEvent('QBCore:Notify', src, 'unable to upgrade!', 'error', 3500)
        end
    else
        -- if for some reason it's still not exist in out database we init data here and then process to upgrade it
        TriggerClientEvent('QBCore:Notify', src, 'Vehicle not found in database!', 'error', 2500)
    end
end

function saveCarWeight(src, upgradeReqData, weightUpgrades)
    -- save car Weight 
    local weightUpgradesChanges = {}
    local upgrades = upgradeReqData["upgrade"]
    local canUpgrade, maxweight = calculateUpgradeAmount(src, upgradeReqData, weightUpgrades)

    if maxweight ~= nil and canUpgrade then
        for i = 1, #upgrades, 1 do
            table.insert(weightUpgradesChanges, string.format('"%s":%s', i, upgrades[i]))
        end
        updateVehicleDatabaseValues(maxweight, weightUpgradesChanges, upgradeReqData)
        return true
    end
    return false
end

function calculateUpgradeAmount(src, upgradeReqData, weightUpgrades)
    local vehicleClass = upgradeReqData["class"]
    local vehiclePlate = upgradeReqData["plate"]
    local vehicleModel = upgradeReqData['model']
    local weightUpgradesTable = json.decode(weightUpgrades)
    local sortedUpgrades = sortTable(upgradeReqData["upgrade"])
    local canUpgrade = false

    for Type, Vehicle in pairs(Config.Vehicles) do
        if Type == vehicleClass then
            for model, vehicleMeta in pairs(Vehicle) do
                if model == vehicleModel then
                    local currentCarryWeight = oxmysql:scalarSync(
                        'SELECT maxweight from player_vehicles where plate = ?', {vehiclePlate})

                    local step = (vehicleMeta.maxWeight - vehicleMeta.minWeight) / vehicleMeta.upgrades
                    local total = 0
                    for key, value in pairs(sortedUpgrades) do
                        if value == true and weightUpgradesTable[tostring(key)] ~= value then
                            total = total + 1
                        end
                    end
                    canUpgrade = (currentCarryWeight + (total * step) <= vehicleMeta.maxWeight) and
                                     (currentCarryWeight + (total * step) ~= currentCarryWeight)
                    if canUpgrade == true then
                        removeMoney(src , 'cash' , vehicleMeta.stepPrice * total , desc)
                    end
                    return canUpgrade, (currentCarryWeight + (total * step))
                end
            end
        end
    end
end

RegisterServerEvent('keep-carInventoryWeight:server:OpenUI')
AddEventHandler('keep-carInventoryWeight:server:OpenUI', function()
    local src = source
    local Player = CoreName.Functions.GetPlayer(src)
    Player.Functions.RemoveItem("huntingbait", 1)
end)

-- ============================
--      Functions
-- ============================
function removeMoney(src, type, amount, desc)
    local plyert = QBCore.Functions.GetPlayer(src)
    -- local plyCid = ply.PlayerData.citizenid
    if plyert.Functions.RemoveMoney(type, amount, "vehicle-upgrade-bail-" .. desc) then
        return true
    end
    return false
end

function createServerResponse(Result, class)
    -- create server response when client fetch data
    local weightUpgrades = oxmysql:scalarSync('SELECT weightUpgrades from player_vehicles where plate = ?',
        {Result[1]["plate"]})
    local characterINFO = json.decode(Result[1]['charinfo'])
    local sv_response = {}
    Upgrades = {}

    sv_response['vehicleInfo'] = {
        vehicle = Result[1]["vehicle"],
        plate = Result[1]["plate"],
        maxweight = Result[1]["maxweight"],
        hash = Result[1]["hash"],
        class = class
    }
    sv_response['characterInfo'] = {
        firstname = characterINFO["firstname"],
        lastname = characterINFO["lastname"],
        cid = characterINFO["cid"],
        phone = characterINFO["phone"],
        gender = characterINFO["gender"]
    }

    -- calculate upgrade steps 
    for Type, Vehicle in pairs(Config.Vehicles) do
        if Type == class then
            for name, vehicleMeta in pairs(Vehicle) do
                if name == Result[1]["vehicle"] then
                    Upgrades = createUpgrades(vehicleMeta, weightUpgrades, Result[1])
                end
            end
        end
    end
    sv_response['upgrades'] = Upgrades
    return sv_response
end

function createUpgrades(vehicleMeta, weightUpgrades, vehicle)
    local temp = {}
    local weightUpgrades = json.decode(weightUpgrades)
    local step = (vehicleMeta.maxWeight - vehicleMeta.minWeight) / vehicleMeta.upgrades

    if weightUpgrades ~= nil then
        for k, value in pairs(weightUpgrades) do
            temp[k] = value
        end
        temp["step"] = step
        temp["stepPrice"] = vehicleMeta.stepPrice
        return temp
    else
        return initWeightUpgradesData(vehicleMeta, vehicle, step)
    end
end

function initWeightUpgradesData(vehicleMeta, vehicle, step)
    -- init vehicle
    local initWeightUpgrades = {}
    for i = 1, vehicleMeta.upgrades, 1 do
        table.insert(initWeightUpgrades, string.format('"%s":%s', i, false))
    end

    updateVehicleDatabaseValues(vehicleMeta.minWeight, initWeightUpgrades, vehicle)

    -- step , stepPrice is for client to show to players
    table.insert(initWeightUpgrades, string.format('"%s":%s', 'step', step))
    table.insert(initWeightUpgrades, string.format('"%s":%s', 'stepPrice', vehicleMeta.stepPrice))

    initWeightUpgrades = "{" .. table.concat(initWeightUpgrades, ",") .. "}"
    return json.decode(initWeightUpgrades)
end

function updateVehicleDatabaseValues(maxweight, weightUpgradesChanges, upgradeReqData)
    local plate = upgradeReqData["plate"]
    local model = upgradeReqData["vehicle"] or upgradeReqData["model"]

    local hash = upgradeReqData["hash"]
    local weightUpgradesChanges2 = "{" .. table.concat(weightUpgradesChanges, ",") .. "}"

    oxmysql:update('UPDATE `player_vehicles` SET maxweight = ? WHERE vehicle = ? AND hash = ? AND plate = ?',
        {maxweight, model, hash, plate}, function(result)
            print(result, "maxweight updated")
        end)
    oxmysql:update('UPDATE `player_vehicles` SET weightUpgrades = ? WHERE vehicle = ? AND hash = ? AND plate = ?',
        {weightUpgradesChanges2, model, hash, plate}, function(result)
            print(result, "weightUpgrades updated")
        end)
end

function sortTable(table)
    local temp = {}
    for k, value in pairs(table) do
        temp[k] = value
    end
    return temp
end

-- ============================
--      Commands
-- ============================

CoreName.Commands.Add("testOpen", "Spawn Animals (Admin Only)", {{"model", "Animal Model"}}, false,
    function(source, args)
        TriggerClientEvent('keep-carInventoryWeight:Client:OpenUI', source, args[1])
    end, 'admin')

function tprint(tbl, indent)
    if not indent then
        indent = 0
    end
    for k, v in pairs(tbl) do
        formatting = string.rep("  ", indent) .. k .. ": "
        if type(v) == "table" then
            print(formatting)
            tprint(v, indent + 1)
        elseif type(v) == 'boolean' then
            print(formatting .. tostring(v))
        else
            print(formatting .. v)
        end
    end
end