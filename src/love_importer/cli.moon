importer = require "love_importer.importer"
util = require "love_importer.util"
c = require "clingy"
v = require "valua"

M = {}

yes_no = (value) -> if value then "yes" else "no"

print_inspect = (result) ->
  print "LÖVE input inspection"
  print "path:       " .. result.path
  print "kind:       " .. result.kind
  print "supported:  " .. yes_no result.supported
  print "executable: " .. result.executable if result.executable
  print "exec_ok:    " .. yes_no result.executable_ok if result.executable_ok != nil
  print "note:       " .. result.note if result.note

print_imported = (imported, opts) ->
  print "Imported LÖVE runtime"
  print ""
  print "name:       moonstone/love"
  print "version:    " .. opts.version
  print "target:     " .. opts.target
  print "lua_api:    love-11"
  print "lua_abi:    lua-5.1"
  print "artifact:   " .. imported.blob_hash
  print "path:       " .. imported.store_path
  print ""
  print "provides:"
  print "  runtime love@" .. opts.version
  print "  bin love -> bin/love"

build_app = ->
  local app
  app = c.create {
    name: "love-importer"
    version: "0.1.14"
    description: "Import local LÖVE installations into Moonstone runtime artifacts."

    c.root c.node {
      c.inherit(
        c.flag "-h", "--help"
      )

      c.run (ctx) ->
        io.stdout\write app\help! .. "\n"
        0

      inspect: c.node {
        c.arg "input", v.string!

        c.run (ctx) ->
          if ctx.args.help
            io.stdout\write app\help("inspect") .. "\n"
            return 0
          result = importer.inspect_path ctx.args.input, ctx.args
          print_inspect result
          0
      }, {
        description: "Inspect a supported LÖVE input."
      }

      import: c.node {
        c.arg "input", v.string!
        c.option "--version", v.string!
        c.option "--target", v.string!
        c.option "--out", v.string!
        c.option "--app-name", v.string!
        c.flag "--skip-run-check"
        c.flag "--clear-quarantine"

        c.run (ctx) ->
          if ctx.args.help
            io.stdout\write app\help("import") .. "\n"
            return 0
          opts = ctx.args
          error "--version is required" unless opts.version and opts.version != ""
          opts.target = opts.target or util.host_target!
          error "unknown target: " .. opts.target .. "; pass --target with a supported Moonstone target" unless util.is_known_target opts.target
          opts.out = opts.out or "dist/love-importer/love-" .. opts.version .. "-" .. opts.target
          imported = assert importer.import_path opts.input, opts
          print_imported imported, opts
          0
      }, {
        description: "Import a canonical LÖVE app, archive, or normalized root."
      }

      "import-system": c.node {
        c.arg "input", v.string!
        c.option "--version", v.string!
        c.option "--target", v.string!
        c.option "--out", v.string!
        c.option "--app-name", v.string!
        c.flag "--skip-run-check"
        c.flag "--clear-quarantine"
        c.flag "--local-only"

        c.run (ctx) ->
          if ctx.args.help
            io.stdout\write app\help("import-system") .. "\n"
            return 0
          opts = ctx.args
          error "--version is required" unless opts.version and opts.version != ""
          error "--local-only is required for import-system" unless opts.local_only
          opts.target = opts.target or util.host_target!
          error "unknown target: " .. opts.target .. "; pass --target with a supported Moonstone target" unless util.is_known_target opts.target
          opts.out = opts.out or "dist/love-importer/love-" .. opts.version .. "-" .. opts.target
          imported = assert importer.import_system opts.input, opts
          print_imported imported, opts
          0
      }, {
        description: "Import a system executable as a local-only artifact."
      }
    }
  }
  app

M.main = (argv = {}) ->
  app = build_app!
  ok, result = pcall ->
    app\run argv
  return result if ok
  io.stderr\write "love-importer: " .. tostring(result) .. "\n"
  1

M

