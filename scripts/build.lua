-- Run the MoonScript compiler in-process; no shell forwarding or POSIX copy.
package.path = "src/?.lua;src/?/init.lua;" .. package.path
local util = require("love_importer.util")
local compiler = require("moonscript.base")
util.mkdir("build/src/love_importer")
for _, source in ipairs({"main", "love_importer/cli"}) do
  local code = assert(util.read_file("src/" .. source .. ".moon"))
  local lua, err = compiler.to_lua(code)
  assert(lua, err)
  util.write_file("build/src/" .. source .. ".lua", lua)
end
for _, name in ipairs({"util", "host", "host@windows", "staging", "inspect", "normalize", "manifest", "store", "importer"}) do
  util.write_file("build/src/love_importer/" .. name .. ".lua", assert(util.read_file("src/love_importer/" .. name .. ".lua")))
end
