-- illenium-appearance bridge for rps_core (client)
-- Location: illenium-appearance/client/framework/rps/main.lua

if GetResourceState('rps_core') == 'missing' then return end

local client = client
local RPS = exports.rps_core

local NO_GANG = { name = 'none', label = 'None', grade = { level = 0, name = 'None' } }
local UNEMPLOYED = { name = 'unemployed', label = 'Unemployed', grade = { level = 0, name = 'Unemployed' }, onduty = true }

local PlayerData = {}

-- illenium-appearance expects QBCore-style job tables
local function toJob(job)
    if not job then return UNEMPLOYED end
    return {
        name = job.name,
        label = job.label,
        grade = { level = job.grade, name = job.gradeLabel },
        isboss = job.boss,
        onduty = true, -- rps has no duty toggle yet
    }
end

local function setClientParams()
    client.job = toJob(PlayerData.job)
    client.gang = NO_GANG
    client.citizenid = PlayerData.charId and tostring(PlayerData.charId) or nil
end

function Framework.GetPlayerGender()
    return PlayerData.charinfo and PlayerData.charinfo.sex == 'f' and 'Female' or 'Male'
end

function Framework.UpdatePlayerData()
    PlayerData = RPS:GetPlayerData() or {}
    setClientParams()
end

function Framework.HasTracker() return false end

function Framework.CheckPlayerMeta()
    return LocalPlayer.state.isDead or IsPedCuffed(cache.ped)
end

function Framework.IsPlayerAllowed(citizenid)
    return citizenid == client.citizenid
end

function Framework.GetRankInputValues(rankType)
    if rankType == 'gang' then return {} end

    local job = RPS:GetJobs()[client.job.name]
    local values = {}
    if job then
        for level, grade in pairs(job.grades) do
            values[#values + 1] = { label = grade.label, value = level }
        end
        table.sort(values, function(a, b) return a.value < b.value end)
    end
    return values
end

function Framework.GetJobGrade() return client.job.grade.level end
function Framework.GetGangGrade() return 0 end
function Framework.CachePed() end
function Framework.RestorePlayerArmour() end

---------------------------------------------------------------------------
-- rps_core events
---------------------------------------------------------------------------

-- rps_core keeps the screen faded out after spawning while this resource runs,
-- so the default ped is never shown. Every path here must fade back in.
AddEventHandler('rps_core:client:playerLoaded', function()
    Framework.UpdatePlayerData()

    local appearance = lib.callback.await('illenium-appearance:server:getAppearance', false)

    if appearance then
        client.setPlayerAppearance(appearance)
        DoScreenFadeIn(500)
        InitAppearance() -- blips, uniforms, armour and the rest of illenium's setup
    else
        -- New character: the editor can't be closed until an appearance is saved
        DoScreenFadeIn(500)
        InitializeCharacter(Framework.GetGender(true))
    end
end)

AddEventHandler('rps_core:client:jobChanged', function(job)
    PlayerData.job = job
    client.job = toJob(job)
    ResetBlips()
end)

AddEventHandler('rps_core:client:playerUnloaded', function()
    PlayerData = {}
    setClientParams()
end)

-- Defaults so illenium-appearance never reads a nil job before a character loads
Framework.UpdatePlayerData()
