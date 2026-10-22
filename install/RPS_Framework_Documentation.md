# RPS Framework Documentation

Version 0.3 · October 2026

## Overview

RPS is a lightweight Lua roleplay framework for FiveM, built on ox_lib and oxmysql. It has two resources in the `[rps]` folder: `rps_core`, which owns players, characters, money, jobs and permissions, and `rps_ambulance`, which adds death, respawn and a basic EMS job. Inventory comes from ox_inventory and character appearance from illenium-appearance, each through an `rps` bridge.

Design principles:

- **Server is the authority.** Money, jobs, groups and death state are only changed on the server. Clients request; the server validates.
- **Small core, separate features.** `rps_core` holds only what every other resource needs. Inventory, housing, vehicles and jobs live in their own resources.
- **Functions, not fields.** The player object keeps its state behind getter functions so it stays live when passed between resources through exports.
- **Lean on ox_lib.** Callbacks, menus, input dialogs, notifications, commands and ACE helpers come from ox_lib instead of being rebuilt.

### Resource layout

```
[rps]/rps_core/
  fxmanifest.lua
  shared/config.lua        settings
  shared/jobs.lua          job and grade definitions
  server/main.lua          Core table, connecting, unload, save and paycheck loops
  server/player.lua        player object (Core.CreatePlayer)
  server/characters.lua    character callbacks
  server/commands.lua      admin and player commands
  server/exports.lua       public exports
  client/main.lua          PlayerData and sync events
  client/spawn.lua         spawning a loaded character
  client/characters.lua    loads the character rps_multicharacter picks; logout
  sql/                     schema and migrations (also in install/sql)

[rps]/rps_ambulance/
  fxmanifest.lua
  config.lua
  server/main.lua          death state, respawn, EMS actions, check-in, locker, shop
  client/death.lua         downed state, timers, respawn
  client/ems.lua           /revive, /heal, medkit item, distress alerts
  client/hospital.lua      hospital blip and check-in point
  client/supplies.lua      EMS locker and supply shop points

[rps]/rps_hud/             ps-hud 2.1.2 ported to rps_core (GPL-3.0)
  config.lua               menu key, speed unit, fuel script, admin-only layout
  client.lua, server.lua   rps_core data -> HUD, settings menu, /dev
  locale.lua, locales/     translations (qb_locale convar picks the language)
  html/                    built interface; svelte-source/ is its source
  stream/                  square and circle minimap textures

[rps]/rps_multicharacter/  (required: rps_core has no character menu of its own)
  fxmanifest.lua
  config.lua               preview spot, camera, default models, join delay
  server/main.lua          saved appearance for the preview ped
  client/main.lua          selection scene, preview ped, create / delete / play menu

install/ox_inventory/modules/bridge/rps/
  server.lua, client.lua   copied into ox_inventory

install/illenium-appearance/{client,server}/framework/rps/
  main.lua                 copied into illenium-appearance
```

## Installation

The short version is in `install/README.md`. In order:

| Requirement | Notes |
| --- | --- |
| FiveM server artifacts | A recent build with Lua 5.4 support |
| OneSync | Required. The server reads player positions and entities. |
| MySQL or MariaDB | Any version oxmysql supports |
| oxmysql | Database layer |
| ox_lib | Callbacks, menus, notifications, commands, ACE helpers |
| ox_inventory | Inventory, tested with 2.48.0 |
| illenium-appearance | Appearance, clothing, barbers, tattoos, outfits |

1. Run `install/sql/install.sql` (existing databases: the files in `install/sql/migrations/`).
2. Copy the `[rps]` folder into your resources folder. Keep the resource folder names unchanged, because exports are called by resource name.
3. Set up ox_inventory as described in `install/SETUP_ox_inventory.md`, and illenium-appearance as described in `install/SETUP_illenium-appearance.md`.
4. Add the lines from `install/server.cfg.example` to `server.cfg`:

```
set mysql_connection_string "mysql://user:password@localhost/dbname?charset=utf8mb4"

setr inventory:framework "rps"
setr inventory:slots 40
setr inventory:weight 30000

ensure oxmysql
ensure ox_lib
ensure rps_core
ensure ox_inventory
ensure illenium-appearance
ensure rps_ambulance
ensure rps_multicharacter
ensure rps_hud

add_ace resource.ox_lib command.add_ace allow
add_ace resource.ox_lib command.remove_ace allow
add_ace resource.ox_lib command.add_principal allow
add_ace resource.ox_lib command.remove_principal allow
```

The four `add_ace` lines are required: RPS groups and restricted commands are set up through ox_lib, which needs permission to run those commands.

5. Join the server once so your `users` row is created, then run `setgroup <your server id> admin` in the server console. You can also set `group` to `admin` on your row in the `users` table and reconnect.

If the default `spawnmanager` resource is running, `rps_core` turns off its auto-spawn automatically. Remove any other framework (ESX, QBCore, Qbox) from the start list.

## Configuration

All settings live in `rps_core/shared/config.lua` and `rps_ambulance/config.lua`. Restart the resource after changing them.

### rps_core

| Option | Default | Purpose |
| --- | --- | --- |
| `MaxCharacters` | 3 | Characters each license may own |
| `MinAge` | 18 | Minimum age for a new character's date of birth |
| `StartingAccounts` | cash 500, bank 5000 | Valid account names and new-character balances. Adding a key here creates a new account. |
| `DefaultMetadata` | hunger 100, thirst 100 | Metadata keys every character starts with |
| `DefaultGroup` | `user` | Group for new users |
| `Groups` | user, mod, admin | Permission groups from lowest to highest; each inherits the ones below |
| `DefaultModel` | freemode male and female | Ped model by sex, used until illenium-appearance applies the saved look |
| `DefaultSpawn` | vec4 near Legion Square | First spawn for new characters |
| `Notify` | top, 5000 ms | Default position and duration for notifications (top-right is rps_hud's money panel) |
| `Commands` | see file | `/me` distance and duration, `/givecash` range, `/report` cooldown |
| `Needs` | on; hunger -1, thirst -1.5 per minute | Hunger and thirst decay, damage at 0, fixed item values |
| `Stress` | on | Stress gain from shooting and speeding, relief over time and from items, screen effects |
| `SaveInterval` | 300000 ms | Auto-save period for all loaded players |
| `PaycheckInterval` | 900000 ms | How often salaries are paid to bank |
| `Jobs` | in `shared/jobs.lua` | Job definitions (see Jobs, groups and permissions) |

### rps_ambulance

| Option | Default | Purpose |
| --- | --- | --- |
| `Job` | `ambulance` | Job name treated as EMS |
| `RespawnTime` | 300 s | Time downed before respawn is allowed |
| `RespawnFee` | 500 | Hospital bill, from bank then cash; never blocks respawn |
| `RespawnPoint` | vec4 at Central LS Medical | Where respawned players appear |
| `ReviveDuration` | 10000 ms | CPR progress bar length |
| `ReviveReward` | 250 | Paid to the medic's bank per revive |
| `HealDuration` | 5000 ms | Treatment progress bar length |
| `ActionDistance` | 3.0 m | How close a medic must be to the patient |
| `AlertBlipTime` | 120 s | How long a distress blip stays on EMS maps |
| `CheckIn.coords` | vec3 at Central LS Medical | Check-in marker position |
| `CheckIn.fee` | 750 | Self-treatment cost |
| `CheckIn.duration` | 10000 ms | Check-in progress bar length |
| `CheckIn.maxEms` | 0 | Check-in only works with this many EMS online or fewer; `nil` always allows it |
| `Items.revive` | `medkit` | Item consumed per revive; `nil` = none needed |
| `Items.heal` | `bandage` | Item consumed per `/heal`; `nil` = none needed |
| `ClearInventoryOnRespawn` | false | Wipe the inventory on hospital respawn |
| `KeepOnRespawn` | `money` | Items kept when wiping |
| `Locker` | 50 slots, 100 kg, personal | EMS locker position and size |
| `Supply` | medkit $50, bandage $10 | EMS supply shop position and stock |

The hospital, locker and shop coordinates are untested defaults. Confirm them in-game, especially with a hospital MLO.

## Player lifecycle

A player exists in the framework only while a character is loaded. Connecting creates the user record; choosing a character builds the player object; logout and disconnect both save before the object is removed.

```
Connecting ──► Character menu ──► Load character ──► Spawned ──► Playing
                     ▲                                              │
                     └──────────────── /logout (save, unload) ◄─────┤
                                                                    └──► Disconnect (save, unload)
```

1. **Connecting.** `playerConnecting` defers the connection, reads the Rockstar license, rejects a second connection with the same license, and inserts or updates the `users` row. A database error rejects the connection with a retry message.
2. **Character menu.** Once the client is active, it turns off `spawnmanager` auto-spawn, shows the selection camera, and asks the server for its characters. Create and delete are server callbacks that validate ownership, names, date of birth and the character limit.
3. **Load character.** `rps_core:selectCharacter` loads the row, checks it belongs to the license and isn't already loaded, reads the user's group, and calls `Core.CreatePlayer`. The player is added to `Core.Players`, ACE principals and state bags are set, and `rps_core:server:playerLoaded` fires. ox_inventory loads the inventory on this event.
4. **Spawned.** The client sets the ped model, places the player at their saved position (or `DefaultSpawn`), waits for collision, and fires `rps_core:client:playerLoaded`. With illenium-appearance running, the screen stays faded out until the saved look is applied; a new character gets the appearance editor first.
5. **Playing.** All loaded players are saved every `SaveInterval` and paid their salary every `PaycheckInterval`.
6. **Logout or disconnect.** `Core.UnloadPlayer` saves, removes the group principal, clears state bags, removes the player from memory, and fires `rps_core:server:playerUnloaded`. ox_inventory saves and unloads the inventory. After `/logout` the client returns to rps_multicharacter's selection screen.

When txAdmin announces a shutdown, every loaded player is saved. Restarting `rps_core` itself while players are online is not supported.

## Server API

Other resources reach players through `rps_core` exports, which return the player object for a loaded character or `nil` if the player has none loaded.

```lua
local player = exports.rps_core:GetPlayer(source)
if not player then return end

if player.removeMoney('cash', 100, 'shop_purchase') then
    -- give the item
end
```

### Exports

| Export | Returns |
| --- | --- |
| `GetPlayer(source)` | Player object or `nil` |
| `GetPlayerByCharId(charId)` | Player object or `nil` |
| `GetPlayers()` | Array of server IDs with a loaded character |
| `GetJobs()` | The `Config.Jobs` table |
| `GetGroups()` | `Config.Groups`, lowest to highest |
| `HasGroup(source, group)` | true if the player's group is `group` or higher |
| `Notify(source, message, type?, duration?, title?)` | Shows an ox_lib notification; `message` can also be a `lib.notify` table. `source` -1 = everyone |
| `RegisterUsableItem(name, cb, style?)` | Runs `cb` when the item is used from ox_inventory (see below) |
| `CanUseItem(name)` | true if a usable-item callback is registered |
| `UseItem(source, name, slot)` | Runs the registered callback (ox_inventory calls this) |
| `Logout(source)` | Saves, unloads and sends the player back to character selection |

### Usable items

Items that have no client or server export of their own in `ox_inventory/data/items.lua` are handed to rps_core when used. Register a callback for them:

```lua
exports.rps_core:RegisterUsableItem('lockpick', function(source, slot)
    -- slot = { name, label, count, slot, metadata, weight }
end)
```

`style` is `'rps'` by default. The framework bridges register with `'qb'` and `'esx'` so QB and ESX scripts receive the arguments they expect. Callbacks run in their own thread, so they may wait.

### Player object

Three fixed fields are safe to read directly: `player.source`, `player.charId` and `player.license`. Everything else must be read through functions, because exports copy plain fields and those copies go stale.

| Method | Returns | Notes |
| --- | --- | --- |
| `getName()` | string | "First Last" |
| `getCharInfo()` | table | `firstname`, `lastname`, `dob`, `sex` |
| `getAccounts()` | table | All balances by account name |
| `getMoney(account)` | number | 0 for unknown accounts |
| `addMoney(account, amount, reason?)` | boolean | Amount is floored; must be above 0 |
| `removeMoney(account, amount, reason?)` | boolean | false if the balance is too low |
| `setMoney(account, amount, reason?)` | boolean | Amount must be 0 or more |
| `getJob()` | table | `name`, `label`, `grade`, `gradeLabel`, `salary`, `boss`, `onduty` |
| `setJob(name, grade?)` | boolean | false if the job or grade doesn't exist; duty resets to the job's `defaultDuty` |
| `setDuty(onduty)` | nil | Not saved: every session starts on the job's default |
| `getGroup()` | string | Current permission group |
| `setGroup(name)` | boolean | Updates ACE principals and the database |
| `hasPermission(ace)` | boolean | Wraps `IsPlayerAceAllowed` |
| `getMeta(key?)` | any | One value, or the whole table without a key |
| `setMeta(key, value)` | nil | Synced to the owning client, saved with the character |
| `getPosition()` | table | `x`, `y`, `z`, `w` from the server-side ped |
| `save()` | nil | Writes the character to the database (yields) |
| `getData()` | table | Snapshot sent to the client on load |

Every money change fires `rps_core:server:moneyChanged` and pushes the new balances to the owning client. Pass a short `reason` string so logging resources can tell transactions apart. Cash changes also update the ox_inventory `money` item.

## Client API

The client holds a read-only copy of the local player's data, kept in sync by server events. Treat it as display data only; never base a reward or a purchase on it without asking the server.

| Export | Returns |
| --- | --- |
| `exports.rps_core:GetPlayerData()` | `charId`, `charinfo`, `accounts`, `job`, `group`, `metadata`, `position` |
| `exports.rps_core:IsLoaded()` | true once a character is spawned |
| `exports.rps_core:GetJobs()` | The `Config.Jobs` table |
| `exports.rps_core:Notify(message, type?, duration?, title?)` | Shows an ox_lib notification (see below) |
| `exports.rps_ambulance:IsDead()` | true while the local player is downed |

### Notifications

One function on both sides, drawn by ox_lib with the position and duration from `Config.Notify`:

```lua
-- client
exports.rps_core:Notify('Paycheck received', 'success')
exports.rps_core:Notify('Low fuel', 'warning', 8000, 'Vehicle')
exports.rps_core:Notify({ title = 'Bank', description = 'Transfer sent', type = 'success', icon = 'building-columns' })

-- server: same arguments after the player's server id (-1 = everyone)
exports.rps_core:Notify(source, 'You were fined $500', 'error')
```

Types are ox_lib's `inform`, `success`, `error` and `warning`; `info`, `primary` and `warn` are accepted too. The table form takes any `lib.notify` field, such as `icon`, `iconColor` or `style`.

### State bags

The server sets these replicated state bags on every loaded player, so any client can read them for any player without a callback.

| Key | Value | Set by |
| --- | --- | --- |
| `job` | Same table as `getJob()` | rps_core |
| `group` | Group name | rps_core |
| `isLoggedIn` | boolean, true while a character is loaded (QB/Qbox scripts read it) | rps_core |
| `isDead` | boolean | rps_ambulance |
| `dead` | boolean, read by ox_inventory | rps_ambulance |

```lua
-- local player
local job = LocalPlayer.state.job

-- any player, by server ID
if Player(serverId).state.isDead then
    -- show a revive prompt
end
```

Money and metadata are not in state bags, because state bags replicate to every client. They are sent only to their owner.

## Events

Public events are local events: listen to them with `AddEventHandler` on the same side they fire. They tell you something happened; they don't change anything, so triggering them yourself does nothing useful.

### Server events

| Event | Arguments | Fires when |
| --- | --- | --- |
| `rps_core:server:playerLoaded` | `src`, `player` | A character finishes loading |
| `rps_core:server:playerUnloaded` | `src`, `charId` | A character is saved and removed (logout or disconnect) |
| `rps_core:server:moneyChanged` | `src`, `account`, `balance`, `change`, `reason` | Any balance changes; `change` is negative for removals |
| `rps_core:server:jobChanged` | `src`, `newJob`, `oldJob` | `setJob` succeeds or duty changes |
| `rps_core:server:metaChanged` | `src`, `key`, `value` | `setMeta` is called |
| `rps_core:server:characterDeleted` | `charId`, `license` | A player deletes a character; clean up rows keyed by `charId` |

### Client events

| Event | Arguments | Fires when |
| --- | --- | --- |
| `rps_core:client:playerLoaded` | `playerData` | The character has spawned |
| `rps_core:client:playerUnloaded` | none | The player logs out |
| `rps_core:client:accountsChanged` | `accounts` | Any balance changes |
| `rps_core:client:jobChanged` | `job` | The job changes |
| `rps_core:client:metaChanged` | `key`, `value` | A metadata value changes |
| `rps:client:statusItemUsed` | `values` | A food or drink item with a `status` is used |

```lua
-- server: log large transactions
AddEventHandler('rps_core:server:moneyChanged', function(src, account, balance, change, reason)
    if math.abs(change) >= 100000 then
        print(('[money] %s %s %+d (%s)'):format(src, account, change, reason or 'unknown'))
    end
end)
```

### Internal network events

These are used between the framework's own server and client files. Don't trigger them from other resources; use the exports and player methods instead.

| Event | Direction |
| --- | --- |
| `rps_core:client:setAccounts`, `setJob`, `setGroup`, `setMeta`, `logout`, `notify` | server to client |
| `rps_core:getCharacters`, `createCharacter`, `deleteCharacter`, `selectCharacter` | ox_lib callbacks |
| `rps_ambulance:server:setDead`, `respawn`, `alert`, `revive`, `heal`, `checkIn` | client to server |
| `rps_ambulance:client:revive`, `heal`, `respawn`, `alert` | server to client |
| `rps_ambulance:canCheckIn` | ox_lib callback |

## Jobs, groups and permissions

Jobs decide what a character does and earns; groups decide what the person behind it may do. They are separate: a police officer can be a normal user, and an admin can be unemployed.

### Jobs

Jobs are defined in `rps_core/shared/jobs.lua`. Grades start at 0, and a character whose saved job no longer exists falls back to `unemployed` on load.

```lua
Config.Jobs.mechanic = {
    label = 'Mechanic',
    grades = {
        [0] = { label = 'Apprentice', salary = 120 },
        [1] = { label = 'Mechanic', salary = 200 },
        [2] = { label = 'Owner', salary = 350, boss = true },
    },
}
```

| Field | Meaning |
| --- | --- |
| `label` | Display name of the job |
| `grades[n].label` | Display name of the grade |
| `grades[n].salary` | Paid to bank every `PaycheckInterval`; 0 disables it |
| `grades[n].boss` | Flag for boss menus; ox_inventory also uses it for boss checks |

Shipped jobs: `unemployed`, `police` (grades 0–3) and `ambulance` (grades 0–2). There is no on-duty toggle yet, so everyone with a job is treated as working.

### Groups

Groups map to FiveM ACE principals named `group.<name>`. When a character loads, the player's `player.<id>` principal is added to their group, and each group inherits the one below it: admin includes mod, mod includes user.

Restrict any ox_lib command by group:

```lua
lib.addCommand('announce', {
    help = 'Send a server announcement',
    params = { { name = 'message', type = 'longString' } },
    restricted = 'group.mod',
}, function(source, args)
    -- ...
end)
```

In code, check with `player.hasPermission('group.mod')`. The server console is allowed everything.

### Commands

Staff (`server/admin.lua`, `client/admin.lua`):

| Command | Group | Effect |
| --- | --- | --- |
| `/admin` | mod | Staff menu: player list (go to, bring, revive, kick; admins also set job, give money or items, kill), noclip, waypoint teleport, coords, delete vehicle, announcement, spawn vehicle |
| `/tp x y z` | mod | Teleport to coordinates |
| `/tpm` | mod | Teleport to your map waypoint |
| `/goto id`, `/bring id` | mod | Teleport to a player, or a player to you |
| `/noclip` | mod | Fly: WASD, Q/E down/up, Shift faster, Alt slower |
| `/coords` | mod | Show your position as `vec4(...)` and copy it |
| `/dv [radius]` | mod | Delete your vehicle or the nearest one (5 m), or every vehicle within `radius` (max 50) |
| `/kick id [reason]` | mod | Kick a player |
| `/announce message` | mod | Announcement to everyone |
| `/car model` | admin | Spawn a vehicle (replaces the one you're driving) |
| `/kill id` | admin | Kill a player |
| `/setjob id job [grade]` | admin | Set a player's job and grade |
| `/givemoney id account amount` | admin | Add money to an account |
| `/setmoney id account amount` | admin | Set a balance |
| `/removemoney id account amount` | admin | Take money from an account |
| `/giveitem id item [count]` | admin | Give an ox_inventory item |
| `/clearinv id` | admin | Empty a player's inventory |
| `/setgroup id group` | admin | Change a player's permission group |
| `/adrevive [id]` | admin | Revive or heal a player, or yourself (rps_ambulance) |

Players (`server/commands.lua`, `client/commands.lua`):

| Command | Effect |
| --- | --- |
| `/id` | Your server ID |
| `/job` | Your job, grade and duty status |
| `/cash`, `/bank` | Your balances |
| `/duty` | Go on or off duty |
| `/givecash id amount` | Hand cash to a player within `Config.Commands.giveCashDistance` |
| `/me text`, `/do text` | Action or scene text above your head for nearby players |
| `/ooc message` | Out-of-character chat to everyone |
| `/report message` | Message to online staff (mod and up), with a cooldown |
| `/logout` | Save and return to character selection |
| `/revive`, `/heal` | Ambulance job only (rps_ambulance): CPR on the closest downed player, or treat the closest conscious player |

### Hunger and thirst

`server/needs.lua` lowers `hunger` and `thirst` (0-100, in character metadata) every `Config.Needs.interval` seconds, except while the player is downed. At 0 the player loses `Config.Needs.damage` health every `damageInterval` seconds. Because the values are metadata, every HUD sees them, including QB, ESX and Qbox HUDs through the bridges.

Food and drink are ox_inventory items with a `client.status`, for example `status = { hunger = 200000 }`, which restores 20 points. The server only accepts the client's report alongside its own record that the player used an item, so eating can't be faked. To set amounts on the server instead, list the item in `Config.Needs.items`: `burger = { hunger = 25 }`. Other resources can change needs with `Core.AddNeeds(player, { hunger = 10 })` inside rps_core, or `player.setMeta('hunger', value)`.

## rps_ambulance

A player who dies is downed rather than respawned. They stay down until a medic revives them, an admin uses `/adrevive`, or the respawn timer runs out and they choose to respawn at the hospital.

### The downed state

- The client checks for death every 250 ms. On death it waits for the ragdoll to settle, resurrects the ped in place, makes it invincible, and plays a death animation, or a slumped pose in the same seat if the player was in a vehicle.
- All controls are disabled except looking around, chat, push-to-talk and the pause menu. The inventory can't be opened.
- **G** sends one distress call per death. Every online EMS gets a notification and a flashing map blip for `AlertBlipTime` seconds. If none are online, the player is told so.
- After `RespawnTime` seconds, **E** asks the server to respawn. The server checks its own timer, charges `RespawnFee` (bank first, then cash, partial if short), optionally wipes the inventory, clears the state and moves the player to `RespawnPoint`.

Death is saved as `isDead` in the character's metadata. A player who disconnects or logs out while downed comes back downed, and the timer starts again, so leaving can't skip the wait.

### EMS actions

Medics use `/revive` (or a medkit from the inventory) and `/heal` on the closest player within `ActionDistance`. Both run a cancellable progress bar with an animation, then ask the server, which checks:

- the medic has the `ambulance` job and isn't downed
- the target is a different, loaded player
- the target is downed (revive) or not downed (heal)
- the two are within `ActionDistance` + 2 m on the server
- the medic has the required item, which is removed only on success

A successful revive pays the medic `ReviveReward`. Medics also get a personal EMS locker and an EMS supplies shop at the hospital.

### Hospital check-in

Injured players who aren't downed can pay `CheckIn.fee` at the marker to restore full health. By default it only works when no EMS are online, so medics keep their role when they're around.

### Exports

| Export | Side | Returns |
| --- | --- | --- |
| `IsDead(source)` | server | boolean |
| `Revive(source)` | server | Revives the player, no checks |
| `IsDead()` | client | boolean for the local player |
| `medkit()` | client | Called by the medkit item |

### Stress

`stress` (0-100) is character metadata like hunger and thirst. It rises while shooting (`Config.Stress.shootingGain` per second of fire) and while driving over `speedingThreshold` mph (`speedingGain` every 10 seconds), except for on-duty jobs in `ignoreJobs` and weapons in `ignoreWeapons`. It falls by `decay` every `decayInterval` seconds, and when an item listed in `Config.Stress.items` is used. From `effectsAt` the camera shakes now and then, more often as stress rises; from `blurAt` the screen also blurs briefly.

Other resources change it with `exports.rps_core:AddStress(source, amount)` and `RemoveStress(source, amount)`. QBCore scripts that trigger `hud:server:GainStress` / `hud:server:RelieveStress` (the ps-hud / qb-hud events) work unchanged. Gains reported by clients are capped at `maxClientChange` and rate limited.

## HUD (rps_hud)

`rps_hud` is ps-hud 2.1.2 (Project Sloth, GPL-3.0) ported from QBCore to rps_core. It shows once a character is loaded (`isLoggedIn`).

- **Status icons:** health, armor, hunger, thirst and stress from rps_core metadata, stamina and oxygen, voice (pma-voice range, talking and radio), armed, parachute, and harness, nitro and cruise when another resource reports them. Downed state comes from rps_ambulance.
- **Vehicle panel:** speed (`Config.UseMPH`), fuel, altitude in aircraft, and seatbelt with a script that fires `seatbelt:client:ToggleSeatbelt`. Fuel reads ox_fuel's `fuel` state bag first, then the `GetFuel` export of `Config.FuelScript` if it runs, then the game value. A low-fuel warning repeats every minute below 20%.
- **Compass and streets** in vehicles (on foot too if enabled in the menu).
- **Info panel (top right):** server ID, job and grade with an on/off duty dot, cash and bank. A balance flashes and shows +$ / -$ when it changes.
- **Minimap:** GTA's minimap by default (`Config.CustomMinimap = false`), square or circle, and draggable in Edit Layout: it follows the drag live and the position is saved per player. If the Map box doesn't sit on the map at your resolution, Shift + drag the box once to line it up (the map stays put). With `Config.CustomMinimap = true` GTA's minimap is hidden and rps_hud draws its own from map tiles: it rotates with the camera and shows your arrow, north, nearby blips and the waypoint, square or round per the menu. Tiles go in `rps_hud/svelte-source/public/map/styleAtlas/` (see the README there) and are built into `html/map/`; without them the map shows only water colour. `Config.MinimapMeters` sets how far it shows. With `CustomMinimap = false` the GTA minimap is used, square or circle via the textures in `stream/`. Either way it shows in vehicles, and on foot if enabled in the menu.
- **Settings menu:** press **I** (`Config.OpenMenu`). Each player picks icon shapes, colours and what to show; `/resethud` restarts the HUD. With `Config.AdminOnly = true`, only admins change the icon styles and they are saved to `uiconfig.lua` for everyone.
- **Edit Layout** (menu sidebar): drag the status icons, vehicle panel, compass, ID/job/money panel and the minimap anywhere on a snapping grid. Esc or Done saves, Reset restores the defaults. Positions are saved per player.
- **`/dev`** (admin) shows developer mode; **G** toggles the engine.

Stress gain and its screen effects are rps_core's (`Config.Stress`); the HUD only displays stress. `/cash` and `/bank` are rps_core's commands. Menu sounds need interact-sound; seatbelt, cruise and harness icons need qb-smallresources or a script firing the same events. See `rps_hud/README.md` for every change from ps-hud.

## Inventory (ox_inventory)

Inventory is handled by ox_inventory through an `rps` bridge that lives inside ox_inventory, because ox_inventory has no plug-in API for custom frameworks. Setup is in `install/SETUP_ox_inventory.md`. Redo the bridge copy and the table edit after every ox_inventory update.

| Piece | Where | What it does |
| --- | --- | --- |
| Bridge | `ox_inventory/modules/bridge/rps/` | Loads inventories on `playerLoaded`, unloads on `playerUnloaded`, maps the job to ox groups, handles licenses and boss checks |
| Table edit | `ox_inventory/modules/mysql/server.lua` | Saves player inventories to `characters.inventory` (by `id`) and vehicle storage to `rps_vehicles` |
| Convar | `server.cfg` | `setr inventory:framework "rps"` |
| Start order | `server.cfg` | rps_core, then ox_inventory, then rps_ambulance |

**Cash is an item.** The `money` item and rps_core's `cash` account always hold the same amount. rps_core changes update the item, and moving, dropping or spending the item updates `cash`. rps_core is the source of truth when a character loads. Bank stays an account only.

**Groups.** ox_inventory sees one group per player: their job and grade, e.g. `{ police = 2 }`. Use this for job stashes and shops: `groups = { ambulance = 0 }`.

**Licenses** are read from `metadata.licenses`, e.g. `player.setMeta('licenses', { weapon = true })`.

**Vehicle storage** is saved only for vehicles with an `rpsVehicleId` entity state bag set to their `rps_vehicles.id`. The garage resource will set this; until then trunks and gloveboxes are temporary.

**Needs.** Food and drink items fire the local client event `rps:client:statusItemUsed` with their status values, for a future needs or HUD resource to apply.

## Appearance (illenium-appearance)

Character looks, clothing stores, barbers, tattoo parlours, plastic surgeons and saved outfits come from illenium-appearance through an `rps` bridge inside it. Setup is in `install/SETUP_illenium-appearance.md`: copy the bridge and add two lines to its `fxmanifest.lua`. Redo both after every illenium-appearance update.

| Moment | What happens |
| --- | --- |
| New character spawns | Screen stays faded, then the appearance editor opens. It can't be closed until the look is saved. |
| Returning character spawns | The saved look is applied, then the screen fades in. The default ped is never shown. |
| Shop visit | Cost is taken from `cash` through rps_core (the `money` item with ox_inventory) |
| Job changes | Job outfits, job clothing rooms and job blips update straight away |
| Character deleted | Saved skins and outfits for that character are removed |

The bridge passes the rps job to illenium-appearance in the format it expects, with `onduty` always true and no gang. Appearances are stored per character with `citizenid` set to the character id as text. `/pedmenu` is limited to `group.admin`.

For medics to change into the ambulance job outfits at the hospital, add the clothing room entry from the setup guide to `Config.ClothingRooms` in `illenium-appearance/shared/config.lua`.

## Database schema

`users` has one row per Rockstar license, `characters` one row per character, and `rps_vehicles` one row per owned vehicle. illenium-appearance adds four tables for looks and outfits. Deleting a user deletes their characters, and deleting a character deletes their vehicles. ox_inventory adds its own `ox_inventory` table for stashes.

### users

| Column | Type | Notes |
| --- | --- | --- |
| `license` | VARCHAR(60), primary key | `license:...` identifier |
| `name` | VARCHAR(255) | FiveM name at last connect |
| `group` | VARCHAR(30) | Permission group, default `user` |
| `created_at` | TIMESTAMP | First connect |

### characters

| Column | Type | Notes |
| --- | --- | --- |
| `id` | INT, auto increment | The `charId` used everywhere |
| `license` | VARCHAR(60), indexed | Owner; foreign key to `users` |
| `firstname`, `lastname` | VARCHAR(30) | Validated on creation |
| `dob` | VARCHAR(10) | `YYYY-MM-DD` |
| `sex` | CHAR(1) | `m` or `f` |
| `accounts` | LONGTEXT (JSON) | `{"cash":500,"bank":5000}` |
| `job`, `job_grade` | VARCHAR(50), INT | Default `unemployed`, 0 |
| `position` | LONGTEXT (JSON) | `{x, y, z, w}` at last save |
| `metadata` | LONGTEXT (JSON) | Free-form, e.g. `hunger`, `thirst`, `isDead`, `licenses` |
| `inventory` | LONGTEXT (JSON) | Added and written by ox_inventory |
| `created_at`, `last_played` | TIMESTAMP | `last_played` updates on every save |

### rps_vehicles

| Column | Type | Notes |
| --- | --- | --- |
| `id` | INT, auto increment | Set as the `rpsVehicleId` state bag on spawned vehicles |
| `charid` | INT, indexed | Owner; foreign key to `characters` |
| `plate` | VARCHAR(8), unique | |
| `model` | VARCHAR(50) | |
| `props` | LONGTEXT (JSON) | Vehicle properties |
| `glovebox`, `trunk` | LONGTEXT (JSON) | Added and written by ox_inventory |

### illenium-appearance tables

| Table | Holds | Keyed by |
| --- | --- | --- |
| `playerskins` | Saved appearance per character and model; `active = 1` is the current one | `citizenid` (character id) |
| `player_outfits` | Outfits a character saved | `citizenid` |
| `player_outfit_codes` | Share codes for saved outfits | `outfitid` |
| `management_outfits` | Job outfits set by bosses (off by default) | `job_name` |

Characters are read once when loaded and kept in memory. The database is written on auto-save, logout, disconnect and txAdmin shutdown, so edit a character's row only while that player is offline, or the next save overwrites your change.

Use `metadata` for small per-character values before adding columns. Add a new table when the data has its own rows, such as owned vehicles or properties, and key it by `charId`.

## Security model

Assume every client is modified. A cheater can trigger any network event with any arguments, so every server handler must decide from server-side facts, never from what the client sends.

What the framework already enforces:

- Money, jobs, groups and death state only change through server code.
- Character callbacks check the license owns the character, that it isn't already loaded, and that names and dates are valid.
- One connection per license.
- EMS actions check job, distance on the server, the target's state and the required item. Respawn checks a server-side timer.

Rules for resources you write:

1. **Never send amounts or prices from the client.** Send what was chosen (an item name, a shop ID) and look up the price on the server.
2. **Check the job and group on the server**, with `player.getJob()` or `player.hasPermission()`, even if the client already hid the button.
3. **Check distance on the server** with `GetEntityCoords(GetPlayerPed(src))` for anything that needs the player to be somewhere.
4. **Check the target exists and is in the right state** before acting on another player.
5. **Return early and quietly** on failed checks. Log them if you want to catch cheaters, but don't tell the client what failed.
6. **Don't trust a progress bar.** If a timed action matters, record the start time on the server and check it when the client says it finished.
7. **Add cooldowns** to events that pay out or spawn things.

```lua
-- good: the server decides the price and checks distance
RegisterNetEvent('rps_shop:server:buy', function(itemName)
    local src = source
    local player = exports.rps_core:GetPlayer(src)
    local item = Shop.Items[itemName]
    if not player or not item then return end

    local coords = GetEntityCoords(GetPlayerPed(src))
    if #(coords - Shop.coords) > 5.0 then return end

    if player.removeMoney('cash', item.price, 'shop:' .. itemName) then
        -- give the item
    end
end)
```

## Framework bridges (QBCore, ESX, Qbox)

rps_core can run scripts written for QBCore, ESX Legacy and Qbox, all at the same time. The bridges live in `rps_core/bridge/qb`, `bridge/esx` and `bridge/qbx` and are always on. They only translate: characters, money, jobs and metadata stay in rps_core, items in ox_inventory, and UI in ox_lib.

- **Exports:** `exports['qb-core']`, `exports.es_extended` and `exports.qbx_core` calls are answered by rps_core.
- **Detection and dependencies:** rps_core's manifest declares `provide 'qb-core'`, `provide 'es_extended'` and `provide 'qbx_core'`, so scripts that check for or depend on those frameworks find rps_core. Never run the real frameworks next to rps_core.
- **Shared data:** a character's cash, bank, job, metadata and items are the same whichever framework a script uses. An ESX script paying a player shows up in a QB script straight away.
- **Mapping:** QB/Qbox `citizenid` is the character id as a string. QB `cash`/`bank` and ESX `money`/`bank` are rps `cash`/`bank`. ESX `black_money` is the ox_inventory `black_money` item. Gangs don't exist (`none`). Usable items go through rps_core's usable-item registry.
- **Included files:** ESX and Qbox scripts that load framework files by path (`@es_extended/imports.lua`, `@qbx_core/modules/lib.lua`) get them from rps_core. If a script can't find one, change its path to `@rps_core/imports.lua` or `@rps_core/modules/lib.lua`.

Each bridge's README (`rps_core/bridge/<name>/README.md`) lists exactly what is and isn't supported.

## Building on RPS

A new feature is its own resource that depends on `rps_core`, calls its exports, and listens to its events. Put it in the `[rps]` folder. This minimal example pays a $50 bonus once per session to anyone loading in as police.

```lua
-- rps_example/fxmanifest.lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

shared_script '@ox_lib/init.lua'
server_script 'server.lua'
client_script 'client.lua'

dependencies { 'rps_core', 'ox_lib' }
```

```lua
-- rps_example/server.lua
local paid = {}

AddEventHandler('rps_core:server:playerLoaded', function(src, player)
    if paid[player.charId] then return end
    if player.getJob().name == 'police' then
        paid[player.charId] = true
        player.addMoney('bank', 50, 'shift_bonus')
    end
end)
```

```lua
-- rps_example/client.lua
AddEventHandler('rps_core:client:playerLoaded', function(data)
    lib.notify({ description = ('Welcome back, %s'):format(data.charinfo.firstname) })
end)
```

Name new resources with the `rps_` prefix and their events `rps_<resource>:server:...` and `rps_<resource>:client:...`. Add the resource to `server.cfg` after `rps_core`.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `No such export GetPlayer in resource rps_core` | The folder was renamed, or `rps_core` isn't started before the calling resource |
| Stuck on the loading screen | ox_lib or oxmysql isn't started, or the SQL wasn't imported; check the server console |
| "Database unavailable" when connecting | Wrong `mysql_connection_string` |
| Admin commands say no permission, or groups don't apply | The `add_ace resource.ox_lib ...` lines are missing from `server.cfg`, or your group isn't `admin`; run `setgroup <id> admin` from the console |
| A changed character row reverts | The player was online and the next save overwrote it |
| Dead player stays dead with no prompt | `rps_ambulance` isn't started |
| Spawning in the wrong place | Saved `position` is used if present; clear it in the database to use `DefaultSpawn` |
| ox_inventory error about the `rps` bridge or framework | The bridge folder wasn't copied, or ox_inventory was updated; redo `install/SETUP_ox_inventory.md` steps 2 and 3 |
| Inventories don't save | The `rps` branch is missing from `ox_inventory/modules/mysql/server.lua` |
| Inventory empty or groups missing on the client | `inventory:framework` was set with `set` instead of `setr`, or ox_inventory starts before rps_core |
| Black screen for 10 seconds after spawning | illenium-appearance is started but the `rps` bridge isn't registered in its `fxmanifest.lua` |
| New characters skip the appearance editor | illenium-appearance isn't started, or the folder is named differently |
| Appearance error about a missing table | `002_appearance.sql` wasn't run |
| Medkit does nothing | The `medkit` item isn't in `ox_inventory/data/items.lua`, or the player isn't on the ambulance job |

## Known limitations

- Not tested on a live server yet; spawn coordinates, the selection camera and the hospital points need checking in-game.
- Restarting `rps_core` while players are online isn't supported. Restart the whole server instead.
- No HUD of its own or garages yet (any QB/ESX/Qbox HUD works through the bridges). Job outfits treat every employee as on duty.
- The framework bridges cover the commonly used QBCore, ESX and Qbox APIs, not every function. Scripts that rely on a framework's database tables (for example `players` or `owned_vehicles`) won't work without changes.
- Callbacks and network events have no rate limiting.

## Roadmap

1. Inventory: ox_inventory bridge, medkits and bandages for EMS (done)
2. Appearance: clothing in character creation, outfits saved per character (done)
3. Police job: cuffing, searching, fines, jail, dispatch, on-duty toggle
4. HUD with hunger and thirst
5. Owned vehicles, garages and keys
6. Shops, ATMs and banking
