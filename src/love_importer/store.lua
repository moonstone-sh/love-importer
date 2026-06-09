local manifest = require("love_importer.manifest")
local util = require("love_importer.util")

local M = {}

local function store_path_for(hash, version)
  local hash_body = hash:gsub("^b3:", "")
  return table.concat({
    util.moonstone_home(),
    "store/v0/b3",
    hash_body:sub(1, 2),
    hash_body:sub(3, 4),
    hash_body .. "-moonstone_love-" .. version,
  }, "/")
end

local function moon_store_import_available()
  local output = util.capture("moon store import --help")
  return output:match("moon store import") ~= nil or output:match("Usage:.*store import") ~= nil
end

local function call_moon_store_import(files_dir, opts, info, artifact_hash)
  local prepared = opts.out .. "/prepared-root"
  local descriptor = prepared .. "/manifest.toml"
  util.rm_rf(prepared)
  util.mkdir(prepared .. "/files")
  assert(util.command_ok("cd " .. util.quote(files_dir) .. " && tar -cf - . | (cd " .. util.quote(prepared .. "/files") .. " && tar -xf -)"), "failed to prepare Moonstone import root")
  manifest.write_store_manifest(prepared, opts, info, artifact_hash)
  local cmd = table.concat({
    "moon store import",
    util.quote(prepared),
    "--descriptor",
    util.quote(descriptor),
    "--quiet",
  }, " ")
  local store_path = util.capture(cmd)
  if store_path == "" then error("moon store import failed") end
  return store_path
end

local function internal_import(files_dir, opts, info, artifact_hash)
  local store_path = store_path_for(artifact_hash, opts.version)
  util.rm_rf(store_path)
  util.mkdir(store_path .. "/files")
  assert(util.command_ok("cd " .. util.quote(files_dir) .. " && tar -cf - . | (cd " .. util.quote(store_path .. "/files") .. " && tar -xf -)"), "failed to install files into store")
  manifest.write_store_manifest(store_path, opts, info, artifact_hash)
  util.command_ok("moon index rebuild >/dev/null 2>&1")
  return store_path
end

function M.import_root(files_dir, opts, info, artifact_hash)
  if not opts.no_moon_store_import and moon_store_import_available() then
    return call_moon_store_import(files_dir, opts, info, artifact_hash)
  end
  return internal_import(files_dir, opts, info, artifact_hash)
end

return M
