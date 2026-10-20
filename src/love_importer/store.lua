local util = require("love_importer.util")
local M = {}

-- Publish an output-local file registry, then let Moonstone own materialization
-- and index updates. Never manufacture or replace CAS directories ourselves.
function M.import_root(_, opts, _, _, artifact)
  local root = opts.out .. "/registry"
  local descriptor = "packages/moonstone/love/" .. opts.version .. "/package.toml"
  local text = assert(util.read_file(opts.out .. "/package.toml"))
  text = text:gsub("\nurl = [^\n]+", "\nurl = " .. util.toml_string("../../../../../" .. util.basename(artifact)))
  util.write_file(root .. "/" .. descriptor, text)
  local index = table.concat({
    '[[package]]', 'name = "moonstone/love"', 'version = ' .. util.toml_string(opts.version),
    'kind = "runtime"', 'descriptor = ' .. util.toml_string(descriptor),
    'descriptor_hash = ' .. util.toml_string(util.b3_string(text)), '',
  }, '\n')
  util.write_file(root .. "/index.toml", index)
  util.write_file(root .. "/registry.toml", table.concat({
    '[registry]', 'id = "love-importer-local"', 'name = "Imported LÖVE runtime"',
    'protocol = "moonstone.registry.v0"', 'revision = 1',
    'generated_at = "1970-01-01T00:00:00Z"', 'min_client = "0.7.0"',
    '[index]', 'format = "toml"', 'url = "index.toml"',
    'hash = ' .. util.toml_string(util.b3_string(index)),
    '[blobs]', 'algorithm = "blake3"', 'layout = "b3/2/2"',
    '[capabilities]', 'runtimes = true', 'artifacts = true', '',
  }, '\n'))
  local output = util.capture('moon add --global --runtime '.. util.quote('moonstone/love@'..opts.version)
    ..' --target '..util.quote(opts.target)..' --registry '..util.quote(util.file_uri(root))..' --json')
  local json = require('dkjson')
  for line in output:gmatch('[^\r\n]+') do
    local event = json.decode(line)
    if event and event.kind == 'RESULT' and event.value == 'ok' and event.terminator and event.data and event.data.path then
      return event.data.path
    end
  end
  error('Moonstone could not install the imported runtime: '..output)
end
return M
