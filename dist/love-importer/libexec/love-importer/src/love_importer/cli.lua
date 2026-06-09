local importer = require("love_importer.importer")
local util = require("love_importer.util")

local M = {}

local function print_help()
  print([[Usage:
	love-importer inspect <path>
	love-importer import <path> --version <version> [options]
	love-importer import-system <path> --version <version> --local-only [options]

Options:
  --version <v>       LÖVE version, e.g. 11.5 (required)
  --target <target>   Moonstone target; defaults to host target
  --out <dir>         Output directory; defaults to dist/love-importer/love-<version>-<target>
  --app-name <name>   Select app bundle name when a zip contains multiple .app bundles
  --local-only        Mark imported artifact as local-only; required for import-system
  --skip-run-check    Skip files/bin/love --version validation warning
  --clear-quarantine  macOS only: remove com.apple.quarantine from the staged copy
  --help              Show help

Supported canonical inputs:
  macOS .app, macOS official zip, normalized root with bin/love

Unsupported by default:
  Windows, source builds, raw AppImage canonical imports
]])
end

local function yes_no(value)
  if value then return "yes" end
  return "no"
end

local function print_inspect(result)
  print("LÖVE input inspection")
  print("path:       " .. result.path)
  print("kind:       " .. result.kind)
  print("supported:  " .. yes_no(result.supported))
  if result.executable then print("executable: " .. result.executable) end
  if result.executable_ok ~= nil then print("exec_ok:    " .. yes_no(result.executable_ok)) end
  if result.note then print("note:       " .. result.note) end
end

local function print_imported(imported, opts)
  print("Imported LÖVE runtime")
  print("")
  print("name:       moonstone/love")
  print("version:    " .. opts.version)
  print("target:     " .. opts.target)
  print("lua_api:    love-11")
  print("lua_abi:    lua-5.1")
  print("artifact:   " .. imported.blob_hash)
  print("path:       " .. imported.store_path)
  print("")
  print("provides:")
  print("  runtime love@" .. opts.version)
  print("  bin love -> bin/love")
end

local function parse(argv)
  if argv[1] == "--help" or argv[1] == "-h" or argv[1] == "help" then
    return { help = true }
  end
  local opts = { command = argv[1], input = argv[2] }
  local i = 3
  while i <= #argv do
    local a = argv[i]
    if a == "--version" then i = i + 1; opts.version = argv[i]
    elseif a == "--target" then i = i + 1; opts.target = argv[i]
    elseif a == "--out" then i = i + 1; opts.out = argv[i]
    elseif a == "--app-name" then i = i + 1; opts.app_name = argv[i]
    elseif a == "--local-only" then opts.local_only = true
    elseif a == "--skip-run-check" then opts.skip_run_check = true
    elseif a == "--clear-quarantine" then opts.clear_quarantine = true
    elseif a == "--help" or a == "-h" then opts.help = true
    else error("unknown argument: " .. tostring(a)) end
    i = i + 1
  end
  return opts
end

local function validate(opts)
  if opts.help or not opts.command then return true end
  if opts.command ~= "inspect" and opts.command ~= "import" and opts.command ~= "import-system" then error("unknown command: " .. tostring(opts.command)) end
  if not opts.input then error(opts.command .. " requires an input path") end
  if opts.command == "inspect" then return true end
  if not opts.version or opts.version == "" then error("--version is required") end
  opts.target = opts.target or util.host_target()
  if not util.is_known_target(opts.target) then error("unknown target: " .. opts.target .. "; pass --target with a supported Moonstone target") end
  opts.out = opts.out or ("dist/love-importer/love-" .. opts.version .. "-" .. opts.target)
  return true
end

function M.main(argv)
  local ok, result = pcall(function()
    local opts = parse(argv or {})
    validate(opts)
    if opts.help or not opts.command then print_help(); return 0 end
    if opts.command == "inspect" then
      print_inspect(importer.inspect_path(opts.input, opts))
      return 0
    end
    local imported
    if opts.command == "import" then
      imported = assert(importer.import_path(opts.input, opts))
    else
      imported = assert(importer.import_system(opts.input, opts))
    end
    print_imported(imported, opts)
    return 0
  end)
  if ok then return result end
  io.stderr:write("love-importer: " .. tostring(result) .. "\n")
  return 1
end

return M
