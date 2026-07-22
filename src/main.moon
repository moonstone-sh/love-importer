source = debug.getinfo(1, "S").source
script_path = if source\sub(1, 1) == "@" then source\sub(2) else "build/src/main.lua"
root = script_path\gsub "build/src/main%.lua$", ""
root = "." if root == ""
root = root\gsub "/$", ""

package.path = table.concat {
  root .. "/build/src/?.lua"
  root .. "/build/src/?/init.lua"
  root .. "/src/?.lua"
  root .. "/src/?/init.lua"
  package.path
}, ";"

cli = require "love_importer.cli"
os.exit cli.main(arg), true
