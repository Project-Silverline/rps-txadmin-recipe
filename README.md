# RPS Framework – txAdmin recipe

One-click deploy of the RPS roleplay framework with txAdmin. The recipe downloads every
resource, installs the RPS bridges into ox_inventory and illenium-appearance, sets up the
database and writes a ready `server.cfg`. Nothing has to be copied or edited by hand.

## What gets installed

| Folder | Contents | Version |
| --- | --- | --- |
| `resources/[cfx-default]` | chat, spawnmanager, mapmanager, sessionmanager, basic-gamemode, hardcap | cfx-server-data `c6afa39` |
| `resources/[ox]` | oxmysql | v2.14.3 |
| | ox_lib | v3.40.0 |
| | ox_inventory, with the `rps` bridge, table mapping and `medkit` item | v2.48.0 |
| `resources/[standalone]` | illenium-appearance, with the `rps` bridge and an EMS changing room | v5.7.0 |
| `resources/[rps]` | rps_core, rps_ambulance | from this repo |
| `rps-docs/` | Framework documentation | from this repo |

Database: `users`, `characters`, `rps_vehicles` and the four illenium-appearance tables.
ox_inventory adds its own table and columns on first start. Requires FXServer 12913 or
newer (oxmysql's minimum) and OneSync, which the recipe turns on.

## Repo layout

```
recipe.yaml       ← what txAdmin reads
server.cfg        ← template; {{placeholders}} are filled by txAdmin
sql/install.sql   ← full database schema
resources/[rps]/  ← rps_core, rps_ambulance
bridges/          ← files copied into ox_inventory and illenium-appearance
docs/             ← documentation, copied to rps-docs/ on the server
```

## 1. Put it on GitHub

1. Create a **public** repo, for example `rps-txadmin-recipe`, and push these files to it.
2. Open `recipe.yaml` and change the one line marked `CHANGE THIS`:

   ```yaml
   src: https://github.com/YOUR_GITHUB_USER/rps-txadmin-recipe
   ```

   Commit and push again.
3. Recommended: tag a release (`git tag v0.3.0 && git push --tags`) and set `ref: v0.3.0`
   on that task instead of `main`, so later pushes can't change what a deploy installs.
4. Open `recipe.yaml` on GitHub, click **Raw**, and copy the URL:

   ```
   https://raw.githubusercontent.com/YOUR_GITHUB_USER/rps-txadmin-recipe/main/recipe.yaml
   ```

## 2. Deploy with txAdmin

1. In the txAdmin setup wizard choose **Remote URL Template** and paste the raw URL.
   On an existing server: **Settings → Master Actions → Reset FXServer**, then run the
   setup again. Use a new profile to keep your current server untouched.
2. Enter your server name, license key (from portal.cfx.re) and database details. Leave
   the database name empty to let txAdmin create one.
3. Review the generated `server.cfg` and save. Start the server.
4. Your txAdmin account is added to `group.admin` automatically. To make your character an
   RPS admin too, join once and run `setgroup <your server id> admin` in the live console.

## After deploying

- Check the positions in `resources/[rps]/rps_ambulance/config.lua` (hospital, check-in,
  EMS locker, supply shop) and the selection camera in `rps_core/shared/config.lua`. They
  are untested defaults.
- The EMS changing room added to illenium-appearance's `shared/config.lua` is also an
  untested position.
- Updating ox_inventory or illenium-appearance later overwrites the bridges. Redeploy, or
  follow `rps-docs/SETUP_ox_inventory.md` and `rps-docs/SETUP_illenium-appearance.md`.

## Updating the recipe

To move to a newer ox or illenium release, change its URL in `recipe.yaml`. Pick a release
that has been out for a couple of weeks, check the patch targets still exist (the
`search` strings in the `replace_string` tasks), and test on a fresh profile first. If a
deploy fails, the deployer log names the failing task; the usual causes are a wrong path or
a `search` string that no longer matches.

Note: `replace_string` treats `search` as a regular expression, which is why dots, braces
and brackets in the searches are escaped with `\`.
