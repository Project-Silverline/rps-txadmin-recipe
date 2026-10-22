# ox_inventory for RPS

ox_inventory has no plug-in API for custom frameworks, so the bridge lives inside
ox_inventory and needs one small edit there. Keep these steps handy: **updating
ox_inventory overwrites both, so redo steps 2 and 3 after every update.**

Tested against ox_inventory 2.48.0.

## 1. Install ox_inventory

Download the latest release from https://github.com/overextended/ox_inventory/releases
(the release zip, not the source code, so the web UI is already built).

## 2. Add the bridge

Copy `install/ox_inventory/modules/bridge/rps` into your
`ox_inventory/modules/bridge/` folder, next to `esx`, `nd`, `ox` and `qbx`.

## 3. Register the database tables

Open `ox_inventory/modules/mysql/server.lua`. Find the block that starts with
`if shared.framework == 'ox' then` and add an `rps` branch before the final `else`:

```lua
    elseif shared.framework == 'qbx' then
        playerTable = 'players'
        playerColumn = 'citizenid'
        vehicleTable = 'player_vehicles'
        vehicleColumn = 'id'
    elseif shared.framework == 'rps' then      -- add
        playerTable = 'characters'             -- add
        playerColumn = 'id'                    -- add
        vehicleTable = 'rps_vehicles'          -- add
        vehicleColumn = 'id'                   -- add
    else
        return
    end
```

Without this, ox_inventory doesn't know where to save player inventories.

## 4. Database

Run `install/sql/migrations/001_inventory.sql` (fresh installs: `install/sql/install.sql` already
includes it). On first start ox_inventory adds an `inventory` column to `characters`,
`glovebox` and `trunk` columns to `rps_vehicles`, and creates its own `ox_inventory`
table for stashes.

## 5. Add the medkit item

Add this to `ox_inventory/data/items.lua`. `bandage` already exists there.

```lua
	['medkit'] = {
		label = 'Medkit',
		weight = 500,
		stack = true,
		close = true,
		description = 'Used by paramedics to revive unconscious patients',
		client = {
			export = 'rps_ambulance.medkit',
		},
	},
```

## 6. server.cfg

```
setr inventory:framework "rps"
setr inventory:slots 40
setr inventory:weight 30000

ensure oxmysql
ensure ox_lib
ensure rps_core
ensure ox_inventory
ensure illenium-appearance
ensure rps_ambulance
```

`setr` (not `set`) matters: the client also needs to know the framework.
ox_inventory must start **after** rps_core and **before** rps_ambulance.

## How cash works

Cash is a physical `money` item, so it can be dropped, traded and stolen. rps_core's
`cash` account and the item are kept equal in both directions:

- `player.addMoney('cash', ...)` and other rps_core changes update the item.
- Moving, dropping or spending the item updates rps_core's cash.

Bank stays an account only.

## Licenses

Shop items with a `license` field check `metadata.licenses` on the character, e.g.
`player.setMeta('licenses', { weapon = true })`.

## Vehicle storage

Trunks and gloveboxes are saved only for vehicles whose `rpsVehicleId` entity state
bag is set to their `rps_vehicles.id`. The garage resource will set this; until then,
vehicle storage is temporary.
