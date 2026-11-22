# A local Windows build, derived from the workflow

Read this when James asks to start roadmap item 1 (building on the Windows VM), or when you
need to know exactly what toolchain the GitHub build uses.

**Status: derived from the workflow; written but not executed on 2026-11-22.** Written
by reading `.github/workflows/build-worldserver.yml` at `origin/main` `d3e030f`. No PowerShell and no Windows
machine were available, so every command below is untested. Expect to fix details on first
use, and record what you changed here.

Nothing in the repository implements a local build yet. `docs/roadmap.md` item 1 describes the
intent: a kept build folder on the VM, a few cores only or quiet hours, about 20 to 30 GB of
disk, GitHub kept as the backup builder.

Building on the VM that runs the live server is a change to how the server gets its program.
Classify with `wildcard-change-control` before installing anything there. A separate Windows
machine carries none of that risk and is the better place for a first attempt.

## Toolchain

| Tool | Version | How the workflow gets it | For a local machine |
|---|---|---|---|
| Microsoft C++ compiler, x64 | Whatever `windows-latest` has. Not pinned | `ilammy/msvc-dev-cmd@v1` with `arch: x64` | Visual Studio Build Tools with the C++ workload. Open "x64 Native Tools Command Prompt" or run its `vcvars64.bat` |
| Boost | 1.87.0, the `msvc-14.3` 64-bit binaries | Installer `boost_1_87_0-msvc-14.3-64.exe` from SourceForge, silent, into `C:\local\boost_1_87_0` | Same installer, same folder. The workflow checks that `C:\local\boost_1_87_0\lib64-msvc-14.3` exists |
| MySQL client library | 8.4.9, Windows x64 zip | `mysql-8.4.9-winx64.zip` from `cdn.mysql.com/archives/mysql-8.4/`, unpacked to `C:\tools\mysql\current` | Same. Needed: `include\` and `lib\mysqlclient.lib` |
| OpenSSL | Whatever the runner has. Not pinned | Found at `%OPENSSL_ROOT_DIR%`, `C:\Program Files\OpenSSL` or `C:\Program Files\OpenSSL-Win64`. Must contain `include\openssl\opensslv.h` | Install a Win64 OpenSSL development package into one of those folders |
| CMake and Ninja | Whatever the runner has. Not pinned | Preinstalled on the runner | Install both and put them on `PATH` |
| Git | Preinstalled | `core.autocrlf false` is set globally before any checkout | Set the same, or patches and anchors will not match |
| PowerShell | PowerShell 7 (`shell: pwsh`) | Preinstalled | Install PowerShell 7 and run the patch scripts with `pwsh` |

Two cautions that come from reading the scripts, not from a test:

- Run the patch scripts with PowerShell 7, as the workflow does. `Install.cmd` on the VM uses
  the older Windows PowerShell 5.1, which writes text files in a different default encoding.
  The patch scripts write C++ source with `Set-Content`, so the older shell may produce
  different bytes.
- The unpinned tools mean a local build and a GitHub build can differ in compiler version.
  A program built locally is not proven equal to the GitHub one.

## Folder layout

The patch scripts use paths relative to one workspace root, for example
`core/modules/mod-playerbots/src/...`. Reproduce the workflow's layout exactly.

| Folder | Contents | Pinned by |
|---|---|---|
| `_mine` | This repository | the commit you are building |
| `core` | `Corfirean/azerothcore-wotlk-coa` | `core_sha` |
| `_bots` | `Corfirean/mod-coa-playerbots` | `bots_sha` |
| `_scaling` | `Corfirean/mod-coa-content-scaling` | `scaling_sha` |
| `core/modules/mod-playerbots` | `Zyth45/mod-playerbots` | `squid_sha` |
| `core/modules/mod-dungeon-clear` | `Zyth45/mod-dungeon-clear` | `dungeon_sha`, if listed |
| `_build` | `Corfirean/coa-server-build` (only `patches/` is needed) | `build_sha`, if listed |
| `core/modules/mod-ollama-chat` | `DustinHendrickson/mod-ollama-chat` | `906eb2a45f5b3b815a281977005371193517eb32` |

## Steps

Run in PowerShell 7 from an empty workspace folder, inside the x64 compiler environment.

```powershell
# 0. Same line ending rule as the workflow
git config --global core.autocrlf false

# 1. This repository, and the pinned commits for the release
git clone https://github.com/JaTynan/coa-wildcard-mystic _mine
python -I _mine/scripts/resolve_release.py latest      # note every key=value it prints

# 2. One pinned checkout. Repeat for each row of the layout table with its own sha.
function Get-Pinned($repo, $sha, $path) {
    git init -q $path
    git -C $path remote add origin "https://github.com/$repo"
    git -C $path fetch -q --depth 1 origin $sha
    git -C $path checkout -q FETCH_HEAD
}
Get-Pinned 'Corfirean/azerothcore-wotlk-coa' '<core_sha>' 'core'
```

Then, in the workflow's order, and copying each step's script from the workflow file so the
two cannot drift:

3. **Apply our patches.** In `core`, for each `..\_mine\patches\*.patch` in name order:
   `git apply --check --whitespace=nowarn <file>` then `git apply --whitespace=nowarn <file>`.
4. Check out `_bots`, `_scaling`, `core/modules/mod-playerbots`, and if listed
   `core/modules/mod-dungeon-clear` and `_build`.
5. **Apply the official module patches.** For each listed patch: compare
   `(Get-FileHash <file> -Algorithm SHA256).Hash.ToLower()` with the release's checksum, then
   `git -C <module folder> apply --check <file>` and `git -C <module folder> apply <file>`.
6. Check out `core/modules/mod-ollama-chat` at its pinned commit.
7. **Apply our patch scripts.** From the workspace root:
   `foreach ($s in Get-ChildItem _mine/patches -Filter *.ps1 | Sort-Object Name) { & $s.FullName }`
   and stop at the first error.
8. **Place the modules.** Copy `_bots/module/src` to `core/modules/mod-coa-playerbots/src` and
   `_bots/module/conf/*` to its `conf`. Copy `_scaling` to
   `core\modules\mod-coa-content-scaling` leaving out `.git`, `artifacts` and `tools`. Copy
   `_scaling\content-packs\mod-coa-tbc-content` and `mod-coa-wotlk-content` to
   `core\modules\`. The workflow uses `robocopy` for these (lines 188-201).
9. **Configure.** In `core`, with `BOOST_ROOT=C:\local\boost_1_87_0` and `OPENSSL_ROOT_DIR`
   set. These are the workflow's flags word for word (lines 257-266):

```powershell
cmake -S . -B build -G Ninja `
  -DCMAKE_BUILD_TYPE=RelWithDebInfo `
  -DCMAKE_NINJA_FORCE_RESPONSE_FILE=ON `
  -DAPPS_BUILD=all -DTOOLS_BUILD=none `
  -DSCRIPTS=static -DMODULES=static `
  -DUSE_COREPCH=1 -DUSE_SCRIPTPCH=1 `
  "-DBOOST_ROOT=$env:BOOST_ROOT" `
  -DMYSQL_INCLUDE_DIR=C:/tools/mysql/current/include `
  -DMYSQL_LIBRARY=C:/tools/mysql/current/lib/mysqlclient.lib `
  -DOPENSSL_ROOT_DIR="$env:OPENSSL_ROOT_DIR"
```

10. **Build.** `cmake --build build --target worldserver -j 4`. The workflow uses 4 parallel
    jobs. On the live VM (10 logical processors seen on 22 Nov, shared with the game; `docs/performance.md`'s 8 is stale) the roadmap asks for
    fewer, or quiet hours.
11. **Check.** Find `worldserver.exe` under `build` and run it with `--version`.
12. **Package**, only if you want the installer to accept it: a folder with
    `server\worldserver.exe`, the DLLs beside it, and `server\core-revision.txt` holding the
    40 character `core_sha` with no line break, plus `_mine\vm\*`. The installer compares that
    file with the official server's revision.

## What makes this an incremental loop, and what is missing

Steps 9 and 10 are incremental by nature. Run step 10 again after editing one source file and
Ninja recompiles only what depends on it. That is the whole idea of roadmap item 1.

The missing piece is steps 3, 5 and 7. They assume a clean tree and cannot be run twice. A
real loop needs one of these, and none exists yet:

- Reset the trees to their pinned commits and re-apply everything, in a way that leaves
  unchanged files with their old timestamps so Ninja does not rebuild them. A plain
  `git checkout` rewrites only files whose content differs, which helps, but the patch
  scripts then rewrite every file they touch.
- Keep a clean copy and a patched copy, and copy across only files whose content changed.

Design that before promising "minutes". Until it is built and timed, the estimate is the
roadmap's, not a measurement.
