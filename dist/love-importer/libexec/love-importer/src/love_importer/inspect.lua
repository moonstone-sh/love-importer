local util = require("love_importer.util")

local M = {}

local function result(kind, path, fields)
  fields = fields or {}
  fields.kind = kind
  fields.path = path
  fields.warnings = fields.warnings or {}
  fields.supported = fields.supported == true
  return fields
end

local function normalized_root(path)
  local executable = path .. "/bin/love"
  return result("normalized_root", path, {
    executable = executable,
    executable_ok = util.is_executable(executable),
    supported = util.is_file(executable) and util.is_executable(executable),
  })
end

local function macos_app(path)
  local executable = path .. "/Contents/MacOS/love"
  return result("macos_app", path, {
    executable = executable,
    executable_ok = util.is_executable(executable),
    supported = util.is_file(executable) and util.is_executable(executable),
  })
end

function M.path(path, opts)
  opts = opts or {}
  if path:match("%.AppImage$") then
    return result("appimage_rejected", path, {
      note = "AppImage is rejected for canonical imports",
      supported = false,
    })
  end
  if path:match("%.zip$") then
    return result("macos_zip", path, {
      note = "zip import will extract and search for a single .app bundle",
      supported = true,
    })
  end
  if util.is_dir(path) and path:match("%.app/?$") then return macos_app(path) end
  if util.is_dir(path) then return normalized_root(path) end
  if util.is_file(path) and util.is_executable(path) then
    return result("system_binary", path, {
      executable = path,
      executable_ok = true,
      supported = opts.allow_system_binary == true,
      warnings = { "system executable imports are local-only because dynamic library closure is not vendored" },
    })
  end
  return result("unknown", path, { supported = false })
end

return M
