# niri settings page: safe config writing

Status: in open [PR #4063](https://github.com/duxlabs-dev/dux-shell/pull/4063)

## What it does

- Every change made on the page is turned into KDL and written to `dms/niri.kdl` in the niri config folder. Text the user writes in the KDL drawer goes to `dms/niri-custom.kdl`.
- Before anything is written, the whole config is checked with `niri validate` on a temporary copy. If niri refuses, nothing is saved and niri's message is shown.
- The file is written in one step. If it changed on disk in the meantime, the write is refused.
- After the write, DMS waits for niri to reload. If the reload fails, the previous file comes back. Older versions are kept, so a change can be undone or an old version restored.
- DMS adds the line `include optional=true "dms/niri.kdl"` to `config.kdl` once, after niri accepts it. This can be undone.
- Only values the user changed are written. niri keeps its own defaults for the rest.

## Why

- The author did not want a settings page that can break the niri config or lock the user out.
- Existing DMS settings keep their own writer, so one niri key is never written twice.
- `config.kdl` is never rewritten, only given one include line.

## How it is built

- Go side: [store.go](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/core/internal/niriconf/store.go) (apply, hash check, rollback), [validate.go](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/core/internal/niriconf/validate.go) (`niri validate` on a copy), [write.go](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/core/internal/niriconf/write.go) (atomic write, symlinks kept), [history.go](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/core/internal/niriconf/history.go) (versions, 20 by default), [reload.go](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/core/internal/niriconf/reload.go) (waits for niri's reload event, 3 seconds) and [include_fix.go](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/core/internal/niriconf/include_fix.go) (add and undo the include).
- Socket methods in [niriconf_handler.go](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/core/internal/server/niriconf_handler.go): `niri.config.read`, `apply`, `history`, `restore` and `doctor`. Fragments are limited to 256 KiB.
- QML side: [NiriPageService.qml](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Services/NiriPageService.qml) has `get`, `set`, `reset`, `isModified`, `undo` and `restore`. A change is applied after a 300 ms pause. If the file changed, it reads the hash again and retries once.
- [assemble.js](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Common/niri/assemble.js) merges the blocks of all sections into one KDL text and ends it with the include of the custom fragment.
- Each section has a module in `quickshell/Common/niri/sections/` with `defaults`, `toKdl`, `search` and `stored` (see the [README](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Common/niri/sections/README.md)). [registry.js](https://github.com/lung595/DankMaterialShell/blob/page-niri-pr/quickshell/Common/niri/registry.js) lists them. `stored` says where a key lives: the page state (`SettingsData.niriPage`) or an existing DMS setting.

## Known limits

- The maintainers asked to pause PR #4063 and to talk with the team first, before more work on it.
- The socket only touches the two page fragments. Other `dms/*.kdl` files are written by other DMS code.
- The check needs the `niri` program to run `niri validate`.
- Some blocks are replaced whole by niri when an include repeats them, so sections that share a block are merged into one block before writing.

## Images

No screenshot yet.

