package.path = table.concat({
  "src/?.lua",
  "src/?/init.lua",
  package.path,
}, ";")

local cli = require("love_importer.cli")
os.exit(cli.main(arg), true)
