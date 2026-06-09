local inspect = require("love_importer.inspect")
local staging = require("love_importer.staging")
local util = require("love_importer.util")

local M = {}

local function fail(message)
  io.stderr:write("error: " .. message .. "\n")
  return nil, message
end

local function find_apps(root)
  local cmd = "find " .. util.quote(root) .. " -maxdepth 4 -name '*.app' -type d | sort"
  local pipe = assert(io.popen(cmd, "r"))
  local apps = {}
  for line in pipe:lines() do apps[#apps + 1] = line end
  pipe:close()
  return apps
end

function M.macos_app(input, files_dir)
  if not input.executable or not util.is_executable(input.executable) then
    return fail("Could not find LÖVE executable.\n\nExpected one of:\n  <root>/bin/love\n  <app>/Contents/MacOS/love\n\nInput:\n  " .. input.path)
  end
  local app_name = util.basename(input.path)
  local dest_app = files_dir .. "/libexec/" .. app_name
  util.mkdir(files_dir .. "/libexec")
  staging.copy_tree(input.path, dest_app)
  staging.symlink("../libexec/" .. app_name .. "/Contents/MacOS/love", files_dir .. "/bin/love")
  return {
    layout = "macos-app",
    source = "macos-app",
    app_name = app_name,
    local_only = false,
    publish_allowed = false,
    bin_path = "bin/love",
  }
end

function M.macos_zip(input, files_dir, opts)
  local tmp = staging.create_temp()
  local ok, result = pcall(function()
    assert(util.command_ok("unzip -q " .. util.quote(input.path) .. " -d " .. util.quote(tmp)), "failed to unzip " .. input.path)
    local apps = find_apps(tmp)
    if opts.app_name then
      local filtered = {}
      for _, app in ipairs(apps) do
        if util.basename(app) == opts.app_name then filtered[#filtered + 1] = app end
      end
      apps = filtered
    end
    if #apps == 0 then error("zip does not contain a plausible love.app") end
    if #apps > 1 then error("zip contains multiple .app bundles; pass --app-name") end
    local app = inspect.path(apps[1], opts)
    local info = assert(M.macos_app(app, files_dir))
    info.source = "macos-zip"
    return info
  end)
  util.rm_rf(tmp)
  if not ok then return fail(tostring(result)) end
  return result
end

function M.normalized_root(input, files_dir)
  if not input.executable or not util.is_executable(input.executable) then
    return fail("Could not find LÖVE executable.\n\nExpected one of:\n  <root>/bin/love\n  <app>/Contents/MacOS/love\n\nInput:\n  " .. input.path)
  end
  staging.copy_tree(input.path, files_dir)
  return {
    layout = "normalized-root",
    source = "normalized-root",
    local_only = false,
    publish_allowed = false,
    bin_path = "bin/love",
  }
end

function M.system_binary(input, files_dir, opts)
  if not opts.local_only then return fail("import-system requires --local-only") end
  staging.copy_file(input.executable, files_dir .. "/bin/love")
  assert(util.command_ok("chmod +x " .. util.quote(files_dir .. "/bin/love")), "failed to chmod executable")
  return {
    layout = "system-executable",
    source = "system-executable",
    local_only = true,
    publish_allowed = false,
    bin_path = "bin/love",
  }
end

return M
