-- The importer can also run directly, before a Moonstone flavor searcher exists.
if package.config:sub(1, 1) == "\\" then return require("love_importer.host@windows") end
return {}
