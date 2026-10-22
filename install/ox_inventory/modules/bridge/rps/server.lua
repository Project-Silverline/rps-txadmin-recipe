-- ox_inventory bridge for rps_core
-- Location: ox_inventory/modules/bridge/rps/server.lua
-- Enable with: setr inventory:framework "rps"

if not lib.checkDependency('rps_core', '0.1.0', true) then return end

local Inventory = require 'modules.inventory.server'
local RPS = exports.rps_core

-- While a player's inventory is being created, the inventory's money item and
-- rps_core's cash can disagree. rps_core is the source of truth for cash, so
-- syncing is paused until the money item has been set from it.
local loading = {}

local function groupsFromJob(job)
    return { [job.name] = job.grade }
end

local function loadPlayer(src)
    local player = RPS:GetPlayer(src)
    if not player then return end

    local info = player.getCharInfo()
    loading[src] = true

    server.setPlayerInventory({
        source = src,
        identifier = player.charId,
        name = player.getName(),
        groups = groupsFromJob(player.getJob()),
        sex = info.sex,
        dateofbirth = info.dob,
    })

    Inventory.SetItem(src, 'money', player.getMoney('cash'))
    loading[src] = nil
end

---------------------------------------------------------------------------
-- rps_core events
---------------------------------------------------------------------------
AddEventHandler('rps_core:server:playerLoaded', function(src)
    loadPlayer(src)
end)

AddEventHandler('rps_core:server:playerUnloaded', function(src)
    loading[src] = nil
    server.playerDropped(src)
end)

AddEventHandler('rps_core:server:jobChanged', function(src, job)
    local inv = Inventory(src)
    if inv and inv.player then
        inv.player.groups = groupsFromJob(job)
    end
end)

-- Cash changed by rps_core (paychecks, fines, /givemoney): mirror it to the money item
AddEventHandler('rps_core:server:moneyChanged', function(src, account, balance, _, reason)
    if account ~= 'cash' or reason == 'ox_inventory' or loading[src] then return end
    if not Inventory(src) then return end

    if Inventory.GetItemCount(src, 'money') ~= balance then
        Inventory.SetItem(src, 'money', balance)
    end
end)

-- ox_inventory restarted while players are online
SetTimeout(500, function()
    for _, src in ipairs(RPS:GetPlayers()) do
        CreateThread(function() loadPlayer(src) end)
    end
end)

-- Only the money item is tied to an rps_core account. Bank stays an account.
server.accounts = { money = 0 }

---------------------------------------------------------------------------
-- Bridge functions called by ox_inventory
---------------------------------------------------------------------------

-- Money item changed inside the inventory (drops, trades, shops): mirror it to cash
---@diagnostic disable-next-line: duplicate-set-field
function server.syncInventory(inv)
    if loading[inv.id] then return end

    local accounts = Inventory.GetAccountItemCounts(inv)
    if not accounts then return end

    local player = RPS:GetPlayer(inv.id)
    if player and player.getMoney('cash') ~= accounts.money then
        player.setMoney('cash', accounts.money, 'ox_inventory')
    end
end

-- Items with no export of their own: run whatever rps_core has registered for them
-- (rps resources, or QB / ESX / Qbox scripts through the bridges)
---@diagnostic disable-next-line: duplicate-set-field
function server.UseItem(source, itemName, data)
    return RPS:UseItem(source, itemName, data)
end

---@diagnostic disable-next-line: duplicate-set-field
function server.setPlayerData(player)
    return {
        source = player.source,
        identifier = player.identifier,
        name = player.name,
        groups = player.groups or {},
        sex = player.sex,
        dateofbirth = player.dateofbirth,
    }
end

-- Licenses are stored in character metadata: metadata.licenses = { weapon = true }
---@diagnostic disable-next-line: duplicate-set-field
function server.hasLicense(inv, name)
    local player = RPS:GetPlayer(inv.id)
    if not player then return end

    local licenses = player.getMeta('licenses') or {}
    return licenses[name] and name or nil
end

---@diagnostic disable-next-line: duplicate-set-field
function server.buyLicense(inv, license)
    local player = RPS:GetPlayer(inv.id)
    if not player then return false end

    if server.hasLicense(inv, license.name) then
        return false, 'already_have'
    elseif Inventory.GetItemCount(inv, 'money') < license.price then
        return false, 'can_not_afford'
    end

    Inventory.RemoveItem(inv, 'money', license.price)

    local licenses = player.getMeta('licenses') or {}
    licenses[license.name] = true
    player.setMeta('licenses', licenses)

    return true, 'have_purchased'
end

---@diagnostic disable-next-line: duplicate-set-field
function server.isPlayerBoss(playerId, group)
    local player = RPS:GetPlayer(playerId)
    if not player then return end

    local job = player.getJob()
    return job.name == group and job.boss
end

-- Trunks and gloveboxes persist for vehicles that carry an rpsVehicleId state bag
-- (set by a future garage resource from rps_vehicles.id). Others are temporary.
---@diagnostic disable-next-line: duplicate-set-field
function server.getOwnedVehicleId(entityId)
    return Entity(entityId).state.rpsVehicleId
end
