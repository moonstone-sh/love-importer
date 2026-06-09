local util = require("love_importer.util")

local M = {}

M.package_name = "moonstone/love"
M.runtime_name = "love"
M.lua_api = "love-11"
M.lua_abi = "lua-5.1"

function M.write_import_metadata(out_dir, opts, info, artifact_hash, blob_hash, artifact_path)
  local lines = {
    "[import]",
    "name = " .. util.toml_string(M.package_name),
    "version = " .. util.toml_string(opts.version),
    "target = " .. util.toml_string(opts.target),
    "source = " .. util.toml_string(info.source or info.layout),
    "layout = " .. util.toml_string(info.layout),
    "local_only = " .. tostring(info.local_only == true),
    "publish_allowed = " .. tostring(info.publish_allowed == true),
    "quarantine_cleared = " .. tostring(info.quarantine_cleared == true),
    "artifact_hash = " .. util.toml_string(artifact_hash),
    "blob_hash = " .. util.toml_string(blob_hash),
    "artifact = " .. util.toml_string(artifact_path),
    "store_path = " .. util.toml_string(opts.store_path or ""),
    "",
  }
  util.write_file(out_dir .. "/import.toml", table.concat(lines, "\n"))
end

function M.write_package_descriptor(out_dir, opts, info, artifact_hash, artifact_path)
  local bytes = tonumber(util.capture("wc -c < " .. util.quote(artifact_path))) or 0
  local recipe_hash = util.b3_string("recipe-love-" .. opts.version .. "-" .. opts.target .. "-" .. (info.layout or "unknown"))
  local lines = {
    "[package]",
    "name = \"" .. M.package_name .. "\"",
    "version = " .. util.toml_string(opts.version),
    "kind = \"runtime\"",
    "description = \"Imported local LÖVE runtime\"",
    "",
    "[[artifacts]]",
    "id = " .. util.toml_string("love-" .. opts.version .. "-" .. opts.target),
    "kind = \"runtime\"",
    "target = " .. util.toml_string(opts.target),
    "runtime = " .. util.toml_string("love@" .. opts.version),
    "lua_api = \"" .. M.lua_api .. "\"",
    "lua_abi = \"" .. M.lua_abi .. "\"",
    "format = \"tar.zst\"",
    "url = " .. util.toml_string("file://" .. util.abspath(artifact_path)),
    "hash = " .. util.toml_string(artifact_hash),
    "artifact_hash = " .. util.toml_string(artifact_hash),
    "bytes = " .. tostring(bytes),
    "recipe_hash = " .. util.toml_string(recipe_hash),
    "local_only = " .. tostring(info.local_only == true),
    "publish_allowed = " .. tostring(info.publish_allowed == true),
    "",
    "[artifacts.materialize]",
    "type = \"archive\"",
    "",
    "[[artifacts.provides]]",
    "kind = \"runtime\"",
    "name = \"" .. M.runtime_name .. "\"",
    "version = " .. util.toml_string(opts.version),
    "lua_api = \"" .. M.lua_api .. "\"",
    "lua_abi = \"" .. M.lua_abi .. "\"",
    "",
    "[[artifacts.provides]]",
    "kind = \"bin\"",
    "name = \"love\"",
    "path = \"bin/love\"",
    "",
  }
  util.write_file(out_dir .. "/package.toml", table.concat(lines, "\n"))
end

function M.write_store_manifest(store_path, opts, info, artifact_hash)
  local content = table.concat({
    "[artifact]",
    "name = " .. util.toml_string(M.package_name),
    "version = " .. util.toml_string(opts.version),
    "kind = \"runtime\"",
    "source_hash = " .. util.toml_string(artifact_hash),
    "recipe_hash = " .. util.toml_string(util.b3_string("love-importer-" .. opts.version .. "-" .. opts.target)),
    "artifact_hash = " .. util.toml_string(artifact_hash),
    "target = " .. util.toml_string(opts.target),
    "",
    "[compat]",
    "runtime_version = " .. util.toml_string("love@" .. opts.version),
    "lua_api = \"" .. M.lua_api .. "\"",
    "lua_abi = \"" .. M.lua_abi .. "\"",
    "runtime_artifact_hash = \"\"",
    "",
    "[origin]",
    "resolver = \"moonstone\"",
    "source = " .. util.toml_string(info.source or info.layout),
    "",
    "[provenance]",
    "imported_by = \"moonstone/love-importer\"",
    "source_kind = " .. util.toml_string(info.layout),
    "local_only = " .. tostring(info.local_only == true),
    "publish_allowed = " .. tostring(info.publish_allowed == true),
    "",
    "[[provides.runtime]]",
    "name = \"" .. M.runtime_name .. "\"",
    "version = " .. util.toml_string(opts.version),
    "abi = \"" .. M.lua_abi .. "\"",
    "",
    "[[provides.bin]]",
    "name = \"love\"",
    "path = \"bin/love\"",
    "",
  }, "\n")
  util.write_file(store_path .. "/manifest.toml", content)
end

return M
