# rps_core

A lightweight custom FiveM framework built on ox_lib and oxmysql.

## Install

1. Run `install/sql/install.sql` on your database.
2. Copy the `[rps]` folder (with `rps_core` inside) into your resources folder.
3. In `server.cfg` (OneSync must be on):

```
set mysql_connection_string "mysql://user:password@localhost/dbname?charset=utf8mb4"

ensure oxmysql
ensure ox_lib
ensure rps_core
```

To add ox_inventory and illenium-appearance, follow `install/SETUP_ox_inventory.md` and `install/SETUP_illenium-appearance.md`.
Existing servers run any new files in `install/sql/migrations/` first.

4. Make yourself admin: join once, then from the server console run `setgroup <your id> admin`
   (or set `group` = 'admin' on your row in the `users` table).

## Server API

```lua
local player = exports.rps_core:GetPlayer(source)
if not player then return end

player.getName()                              -- "John Doe"
player.getCharInfo()                          -- { firstname, lastname, dob, sex }
player.getMoney('cash')
player.addMoney('bank', 250, 'reason')        -- returns true/false
player.removeMoney('cash', 100, 'shop')       -- false if insufficient funds
player.setMoney('bank', 0, 'reason')
player.getJob()                               -- { name, label, grade, gradeLabel, salary, boss }
player.setJob('police', 1)
player.getGroup() / player.setGroup('mod')
player.hasPermission('group.admin')
player.getMeta('hunger') / player.setMeta('hunger', 80)
player.getPosition()
player.save()

player.source / player.charId / player.license -- fixed values

exports.rps_core:GetPlayerByCharId(charId)
exports.rps_core:GetPlayers()   -- list of loaded sources
exports.rps_core:GetJobs()
```

Always read data through the getter functions. When the player object crosses
resources via exports, only the functions stay live.

## Client API

```lua
exports.rps_core:GetPlayerData()  -- { charId, charinfo, accounts, job, group, metadata }
exports.rps_core:IsLoaded()
exports.rps_core:GetJobs()
```

Any client can read another player's job or group through state bags:
`Player(serverId).state.job`.

## Events

Server (`AddEventHandler`):
- `rps_core:server:playerLoaded` (src, player)
- `rps_core:server:playerUnloaded` (src, charId)
- `rps_core:server:moneyChanged` (src, account, newBalance, change, reason)
- `rps_core:server:jobChanged` (src, newJob, oldJob)
- `rps_core:server:characterDeleted` (charId, license)

Client (`AddEventHandler`):
- `rps_core:client:playerLoaded` (playerData)
- `rps_core:client:playerUnloaded`
- `rps_core:client:accountsChanged` (accounts)
- `rps_core:client:jobChanged` (job)
- `rps_core:client:metaChanged` (key, value)

## Commands

| Command | Who |
|---|---|
| `/setjob id job [grade]` | admin |
| `/givemoney id account amount` | admin |
| `/setgroup id group` | admin |
| `/logout` | everyone |

Groups inherit downward (admin > mod > user). Restrict your own commands with
`restricted = 'group.mod'` in `lib.addCommand`.

## Not included yet

HUD and vehicles. Death and respawn are in rps_ambulance.
