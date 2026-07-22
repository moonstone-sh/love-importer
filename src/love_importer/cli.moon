importer = require "love_importer.importer"
util = require "love_importer.util"
argparse = require "argparse"

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

add_import_options = (command, require_local_only) ->
  command\option("--version", "LÖVE version, e.g. 11.5")\argname("<version>")
  command\option("--target", "Moonstone target; defaults to the host target")\argname("<target>")
  command\option("--out", "Output directory")\argname("<dir>")
  command\option("--app-name", "Select an app bundle from an archive")\argname("<name>")
  command\flag("--skip-run-check", "Skip files/bin/love --version validation warning")
  command\flag("--clear-quarantine", "macOS only: remove quarantine from the staged copy")
  command\flag("--local-only", "Mark the imported artifact local-only") if require_local_only

build_parser = ->
  parser = argparse "love-importer", "Import local LÖVE installations into Moonstone runtime artifacts."
  parser\command_target "command"

  inspect = parser\command "inspect", "Inspect a supported LÖVE input."
  inspect\argument "input", "Path to inspect."

  import_command = parser\command "import", "Import a canonical LÖVE app, archive, or normalized root."
  import_command\argument "input", "Path to import."
  add_import_options import_command, false

  system = parser\command "import-system", "Import a system executable as a local-only artifact."
  system\argument "input", "System executable path."
  add_import_options system, true

  parser

parse = (argv) ->
  table.remove argv, 1 if argv[1] == "--"
  parser = build_parser!
  return { help: true, parser: parser } if #argv == 0 or argv[1] == "help" or argv[1] == "--help" or argv[1] == "-h"
  ok, result = parser\pparse argv
  error result unless ok
  result

validate = (opts) ->
  return true if opts.help
  error "unknown command: " .. tostring opts.command unless opts.command == "inspect" or opts.command == "import" or opts.command == "import-system"
  error opts.command .. " requires an input path" unless opts.input
  return true if opts.command == "inspect"
  error "--version is required" unless opts.version and opts.version != ""
  error "--local-only is required for import-system" if opts.command == "import-system" and not opts.local_only
  opts.target = opts.target or util.host_target!
  error "unknown target: " .. opts.target .. "; pass --target with a supported Moonstone target" unless util.is_known_target opts.target
  opts.out = opts.out or "dist/love-importer/love-" .. opts.version .. "-" .. opts.target
  true

M.main = (argv = {}) ->
  ok, result = pcall ->
    opts = parse argv
    if opts.help
      print opts.parser\get_help!
      return 0
    validate opts
    if opts.command == "inspect"
      print_inspect importer.inspect_path opts.input, opts
      return 0
    imported = if opts.command == "import"
      assert importer.import_path opts.input, opts
    else
      assert importer.import_system opts.input, opts
    print_imported imported, opts
    0
  return result if ok
  io.stderr\write "love-importer: " .. tostring(result) .. "\n"
  1

M
