-- ox_inventory bridge for rps_core
-- Location: ox_inventory/modules/bridge/rps/client.lua

if not lib.checkDependency('rps_core', '0.1.0', true) then return end

local function setGroups(job)
    if job then
        client.setPlayerData('groups', { [job.name] = job.grade })
    end
end

AddEventHandler('rps_core:client:playerLoaded', function(data)
    setGroups(data.job)
end)

AddEventHandler('rps_core:client:jobChanged', setGroups)
AddEventHandler('rps_core:client:playerUnloaded', client.onLogout)

-- ox_inventory restarted while the player is in-game
SetTimeout(500, function()
    if exports.rps_core:IsLoaded() then
        setGroups(exports.rps_core:GetPlayerData().job)
    end
end)

-- Food and drink items carry a `status` table (e.g. { hunger = 200000 }).
-- rps_core has no needs system yet, so this is passed on as a local event
-- for a future HUD/needs resource to handle.
---@diagnostic disable-next-line: duplicate-set-field
function client.setPlayerStatus(values)
    TriggerEvent('rps:client:statusItemUsed', values)
end
