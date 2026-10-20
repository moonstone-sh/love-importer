# LÖVE Importer

Import a local LÖVE installation into a normalized Moonstone runtime artifact.
The importer accepts supported local inputs, stages a predictable `files/` root,
and writes the descriptor needed to use that runtime from a Moonstone project.

## Install

```sh
moon add --global --tool moonstone/love-importer
moon exec --global love-importer --help
```

## Import LÖVE

```sh
moon exec --global love-importer inspect /Applications/love.app
moon exec --global love-importer import /Applications/love.app --version 11.5
```

For a verified downloaded macOS archive, clearing Gatekeeper quarantine is an
explicit opt-in:

```sh
moon exec --global love-importer import ~/Downloads/love-11.5-macos.zip \
  --version 11.5 --clear-quarantine
```

The generated runtime is `moonstone/love@<version>`. Add it to a LÖVE project:

```toml
[[dependencies]]
name = "moonstone/love"
constraint = "11.5"
role = "runtime"
```

System-binary imports are local-only by design. The repository README documents
supported input formats, trust boundaries, and the importer architecture.

Windows development supports official LÖVE ZIPs and directories with companion
DLLs. Imports are installed by Moonstone through a generated local registry;
the importer does not write CAS directories directly. These changes depend on
the portable Moonstone/Ballad revisions pinned by the repository CI and are not
yet part of a new tagged release.
