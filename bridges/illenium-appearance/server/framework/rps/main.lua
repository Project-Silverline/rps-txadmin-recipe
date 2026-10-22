-- illenium-appearance bridge for rps_core (server)
-- Location: illenium-appearance/server/framework/rps/main.lua

if GetResourceState('rps_core') == 'missing' then return end

local RPS = exports.rps_core

local NO_GANG = { name = 'none', label = 'None', grade = { level = 0, name = 'None' } }
local UNEMPLOYED = { name = 'unemployed', label = 'Unemployed', grade = { level = 0, name = 'Unemployed' }, onduty = true }

-- Appearances are stored per character; citizenid = tostring(charId)
function Framework.GetPlayerID(src)
    local player = RPS:GetPlayer(src)
    return player and tostring(player.charId) or nil
end

-- Shops always charge cash. With ox_inventory, cash is the money item and stays in sync.
function Framework.HasMoney(src, account, amount)
    local player = RPS:GetPlayer(src)
    return player ~= nil and player.getMoney(account) >= amount
end

function Framework.RemoveMoney(src, account, amount)
    local player = RPS:GetPlayer(src)
    if not player then return false end
    if amount <= 0 then return true end
    return player.removeMoney(account, amount, 'appearance')
end

function Framework.GetJob(src)
    local player = RPS:GetPlayer(src)
    if not player then return UNEMPLOYED end

    local job = player.getJob()
    return {
        name = job.name,
        label = job.label,
        grade = { level = job.grade, name = job.gradeLabel },
        isboss = job.boss,
        onduty = true,
    }
end

function Framework.GetGang()
    return NO_GANG
end

function Framework.SaveAppearance(appearance, citizenID)
    if not citizenID then return end
    Database.PlayerSkins.UpdateActiveField(citizenID, 0)
    Database.PlayerSkins.DeleteByModel(citizenID, appearance.model)
    Database.PlayerSkins.Add(citizenID, appearance.model, json.encode(appearance), 1)
end

function Framework.GetAppearance(citizenID, model)
    if not citizenID then return end
    local result = Database.PlayerSkins.GetByCitizenID(citizenID, model)
    if result then
        return json.decode(result)
    end
end

-- Remove skins and saved outfits when a character is deleted
AddEventHandler('rps_core:server:characterDeleted', function(charId)
    local citizenID = tostring(charId)
    MySQL.query('DELETE FROM playerskins WHERE citizenid = ?', { citizenID })
    MySQL.query('DELETE player_outfit_codes FROM player_outfit_codes INNER JOIN player_outfits ON player_outfits.id = player_outfit_codes.outfitid WHERE player_outfits.citizenid = ?', { citizenID }, function()
        MySQL.query('DELETE FROM player_outfits WHERE citizenid = ?', { citizenID })
    end)
end)
