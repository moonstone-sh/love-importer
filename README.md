# moonstone/love-importer

Imports local LÖVE installations into normalized Moonstone runtime artifacts.

The command layer is written in MoonScript and compiled to `build/src/` during
`moon run build`; the build also stages the Lua import core there. The exported
artifact therefore contains only compiled runtime code and runtime dependencies,
while filesystem, staging, manifest, and store modules remain Lua because they
primarily model explicit artifact operations.

For local development, run the project entrypoint through Moonstone and place
importer arguments after `--`:

```bash
moon run love-importer -- inspect /Applications/love.app
moon run love-importer -- import /Applications/love.app --version 11.5
```

Run `moon run build` first. The importer uses Lua 5.4; this host runtime is independent of the LuaJIT runtime inside the LÖVE distribution.

The importer is intentionally ad-hoc about host input formats and strict about output:

```text
files/bin/love
```

Supported v0 inputs:

- macOS `.app`
- macOS official zip containing one `.app`
- Windows LÖVE directory or official ZIP, retaining companion DLLs
- normalized root containing `bin/love` or `bin/love.exe`
- system executable with `import-system ... --local-only`

Raw AppImage canonical imports are rejected.

## Usage

```bash
love-importer inspect ./love-root
love-importer import /Applications/love.app --version 11.5
love-importer import ./love-11.5-macos.zip --version 11.5
love-importer import ./love-root --version 11.5 --target linux-x86_64-gnu
love-importer import-system "$(which love)" --version 11.5 --local-only
```

On macOS, downloaded zips/apps may carry Gatekeeper quarantine attributes. The importer does not bypass that by default. If you have verified the LÖVE download yourself and want the staged runtime copy to avoid repeated Gatekeeper prompts, opt in explicitly:

```bash
love-importer import ~/Downloads/love-11.5-macos.zip --version 11.5 --clear-quarantine
```

Global install/run shape:

```bash
moon add --global --tool moonstone/love-importer
moon exec --global love-importer import /Applications/love.app --version 11.5
```

Outputs are written to `dist/love-importer/love-<version>-<target>/` by default and include:

- `files/` normalized artifact root
- `love-<version>-<target>.tar.zst` on POSIX, or `.tar.gz` on Windows
- `package.toml`
- `import.toml`
- `registry/` with the verified descriptor and index used for installation

The normalized runtime package identity is always:

```toml
[package]
name = "moonstone/love"
version = "11.5"
kind = "runtime"
```

It provides `runtime love@11.5` and `bin love -> bin/love` with `lua_api = "love-11"` and `lua_abi = "lua-5.1"`.

Use the imported runtime from a LÖVE project with:

```toml
manifest_version = 2

[[dependencies]]
name = "moonstone/love"
constraint = "11.5"
role = "runtime"

[scripts]
dev = "love ."
```

The importer stages the complete `files/` root, builds an output-local registry, and delegates installation to `moon add --global --runtime`. It does not modify the CAS or rebuild the index itself. Unknown-provenance imports default to `publish_allowed = false`; `import-system` is always `local_only = true` and does not vendor dynamic library closure.

## Internal Modules

- `inspect.lua` classifies inputs as `macos_app`, `macos_zip`, `normalized_root`, `system_binary`, `appimage_rejected`, or `unknown`.
- `normalize.lua` converts a supported inspection result into a staged `files/` root.
- `staging.lua` owns recursive copies, symlink creation, runtime-root validation, and external-symlink rejection.
- `manifest.lua` writes import metadata and package descriptors.
- `store.lua` is the Moonstone integration seam: it calls `moon store import` when available and otherwise uses the current internal store layout fallback.

Long-term, `store.lua` should become a thin wrapper over a Moonstone-owned primitive such as:

```bash
moon store import <prepared-root> --descriptor <manifest.toml>
```

That keeps the split clear: `love-importer` knows LÖVE packaging, Moonstone core knows runtime artifacts, and Ballad knows release/export layouts.

To export the importer itself, its `partiture.lua` uses Ballad's current
Moonstone contract: `moonstone:run("build", ...)`, `layout.libexec(...)`,
`moonstone.registry.package(...)`, and explicit `p.sink.*` outputs. Run it with:

```bash
moon sync
moon run export
```

## Windows development and verification

Use a LÖVE directory containing `love.exe` and its DLLs, or the official ZIP:

```powershell
moon run build
moon exec -- lua build/src/main.lua import C:/Downloads/love-11.5-win64.zip --version 11.5 --target x86_64-windows
```

Windows imports produce `files/bin/love.exe` with companion files beside it.
ZIP traversal entries and symlinks, directory reparse points, and overlapping
input/output directories are rejected. Filesystem helpers use the Windows
host flavor and Windows PowerShell. Command arguments containing cmd
metacharacters are rejected rather than interpreted. Native Windows imports
require the pending portable hashing/exporter framework changes pinned in CI.

`python3 tests/native_lifecycle.py` checks real imports and runs the exported
launcher after relocating it outside the checkout. On Windows it downloads the
official LÖVE 11.5 ZIP, compares every staged and installed file, and exercises
unsafe ZIP and overlap rejection. It skips graphical execution. Test runtime
installation uses an isolated `MOONSTONE_HOME`.

Exporter artifacts bundle the host Lua runtime and carry its concrete target;
they are not published as `any`. No new release is included in this change.
