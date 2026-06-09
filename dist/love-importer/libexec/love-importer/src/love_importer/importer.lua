local inspect = require("love_importer.inspect")
local manifest = require("love_importer.manifest")
local normalize = require("love_importer.normalize")
local staging = require("love_importer.staging")
local store = require("love_importer.store")
local util = require("love_importer.util")

local M = {}

local function fail(message)
  io.stderr:write("error: " .. message .. "\n")
  return nil, message
end

local function warn(message)
  io.stderr:write("warning: " .. message .. "\n")
end

local function run_check(files_dir, opts, info)
  if opts.skip_run_check then return nil end
  if opts.target and opts.target:match("^darwin%-") and info and info.layout == "macos-app" then
    warn("skipping macOS .app run check to avoid triggering Gatekeeper during import; pass --skip-run-check to silence this warning")
    return nil
  end
  local love = files_dir .. "/bin/love"
  local output = util.capture(util.quote(love) .. " --version")
  if output == "" then
    warn("could not verify `files/bin/love --version`; pass --skip-run-check to silence this warning")
    return nil
  end
  return output
end

local function validate_staged_root(files_dir, opts, info)
  staging.validate_runtime_root(files_dir, opts)
  run_check(files_dir, opts, info)
end

local function prepare_out_dir(out_dir)
  util.rm_rf(out_dir)
  util.mkdir(out_dir)
end

local function package_files(out_dir, files_dir, opts, info)
  local artifact = util.abspath(out_dir .. "/love-" .. opts.version .. "-" .. opts.target .. ".tar.zst")
  validate_staged_root(files_dir, opts, info)
  assert(util.command_ok("command -v zstd >/dev/null"), "zstd is required")
  assert(util.command_ok("cd " .. util.quote(files_dir) .. " && tar -cf - . | zstd -q -c > " .. util.quote(artifact)), "failed to create artifact archive")
  local artifact_hash = util.b3_file(artifact)
  local store_path = store.import_root(files_dir, opts, info, artifact_hash)
  opts.store_path = store_path
  manifest.write_import_metadata(out_dir, opts, info, artifact_hash, artifact_hash, artifact)
  manifest.write_package_descriptor(out_dir, opts, info, artifact_hash, artifact)
  return artifact, artifact_hash, store_path
end

local function result(out_dir, files_dir, artifact, artifact_hash, store_path, layout)
  return {
    out = out_dir,
    files = files_dir,
    artifact = artifact,
    blob_hash = artifact_hash,
    store_path = store_path,
    layout = layout,
  }
end

function M.inspect_path(input_path, opts)
  return inspect.path(input_path, opts or {})
end

function M.import_path(input_path, opts)
  local inspected = inspect.path(input_path, opts)
  if inspected.kind == "appimage_rejected" then
    return fail("AppImage input is not accepted as a canonical Moonstone LÖVE runtime.\n\nMoonstone runtime artifacts must expose a normalized root with files/bin/love.\nExtract/repack the AppImage into a root, or provide a local LÖVE app/root.\n\nUse --allow-opaque --local-only only for non-publishable local experiments.")
  end
  if inspected.kind == "system_binary" then
    return fail("system executable inputs must use import-system")
  end
  if not inspected.supported then
    return fail("Could not find LÖVE executable.\n\nExpected one of:\n  <root>/bin/love\n  <app>/Contents/MacOS/love\n\nInput:\n  " .. input_path)
  end

  prepare_out_dir(opts.out)
  local files_dir = opts.out .. "/files"
  util.mkdir(files_dir)

  local info
  if inspected.kind == "macos_app" then
    info = assert(normalize.macos_app(inspected, files_dir))
  elseif inspected.kind == "macos_zip" then
    info = assert(normalize.macos_zip(inspected, files_dir, opts))
  elseif inspected.kind == "normalized_root" then
    info = assert(normalize.normalized_root(inspected, files_dir))
  else
    return fail("unsupported input kind: " .. tostring(inspected.kind))
  end

  if opts.local_only then
    info.local_only = true
    info.publish_allowed = false
  end
  if opts.clear_quarantine then
    if not staging.clear_quarantine(files_dir) then warn("could not clear macOS quarantine attributes") end
    info.quarantine_cleared = true
  end

  local artifact, artifact_hash, store_path = package_files(opts.out, files_dir, opts, info)
  return result(opts.out, files_dir, artifact, artifact_hash, store_path, info.layout)
end

function M.import_system(input_path, opts)
  if not opts.local_only then
    return fail("System executable imports are local-only because their dynamic library closure is not vendored.\n\nRe-run with:\n  love-importer import-system " .. input_path .. " --version " .. tostring(opts.version or "<version>") .. " --local-only")
  end

  local inspected = inspect.path(input_path, opts)
  if inspected.kind ~= "system_binary" then
    return fail("system executable does not exist or is not executable: " .. input_path)
  end

  prepare_out_dir(opts.out)
  local files_dir = opts.out .. "/files"
  util.mkdir(files_dir)
  local info = assert(normalize.system_binary(inspected, files_dir, opts))
  warn("dynamic library closure is not vendored")
  warn("local-only artifact should not be uploaded as a first-party/reproducible runtime")

  local artifact, artifact_hash, store_path = package_files(opts.out, files_dir, opts, info)
  return result(opts.out, files_dir, artifact, artifact_hash, store_path, info.layout)
end

return M
