# moonstone/love-importer

Imports local LÖVE installations into normalized Moonstone runtime artifacts.

The importer is intentionally ad-hoc about host input formats and strict about output:

```text
files/bin/love
```

Supported v0 inputs:

- macOS `.app`
- macOS official zip containing one `.app`
- normalized root containing `bin/love`
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
moon add --global --tool moonstone:moonstone/love-importer
moon exec --global love-importer import /Applications/love.app --version 11.5
```

Outputs are written to `dist/love-importer/love-<version>-<target>/` by default and include:

- `files/` normalized artifact root
- `love-<version>-<target>.tar.zst`
- `package.toml`
- `import.toml`

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
[dependencies.runtime]
"moonstone:moonstone/love" = "11.5"

[scripts]
dev = "love ."
```

The importer stages the complete `files/` root before hashing and installing it into the Moonstone store. Unknown-provenance imports default to `publish_allowed = false`; `import-system` is always `local_only = true` and does not vendor dynamic library closure.

## Internal Modules

- `inspect.lua` classifies inputs as `macos_app`, `macos_zip`, `normalized_root`, `system_binary`, `appimage_rejected`, or `unknown`.
- `normalize.lua` converts a supported inspection result into a staged `files/` root.
- `staging.lua` owns recursive copies, symlink creation, runtime-root validation, and external-symlink rejection.
- `manifest.lua` writes import metadata, package descriptors, and current Moonstone store manifests.
- `store.lua` is the Moonstone integration seam: it calls `moon store import` when available and otherwise uses the current internal store layout fallback.

Long-term, `store.lua` should become a thin wrapper over a Moonstone-owned primitive such as:

```bash
moon store import <prepared-root> --descriptor <manifest.toml>
```

That keeps the split clear: `love-importer` knows LÖVE packaging, Moonstone core knows runtime artifacts, and Ballad knows release/export layouts.
