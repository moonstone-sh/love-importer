local M = {}

function M.quote(value)
  value = tostring(value)
  return "'" .. value:gsub("'", "'\\''") .. "'"
end

function M.command_ok(command)
  local code = os.execute(command)
  if code == true then return true end
  if type(code) == "number" then return code == 0 end
  return false
end

function M.capture(command)
  local pipe = io.popen(command .. " 2>/dev/null", "r")
  if not pipe then return "" end
  local out = pipe:read("*a") or ""
  pipe:close()
  return (out:gsub("%s+$", ""))
end

function M.exists(path)
  local f = io.open(path, "rb")
  if f then f:close(); return true end
  return false
end

function M.is_dir(path)
  return M.command_ok("test -d " .. M.quote(path))
end

function M.is_file(path)
  return M.command_ok("test -f " .. M.quote(path))
end

function M.is_executable(path)
  return M.command_ok("test -x " .. M.quote(path))
end

function M.mkdir(path)
  assert(M.command_ok("mkdir -p " .. M.quote(path)), "cannot create directory: " .. path)
end

function M.rm_rf(path)
  if path == "" or path == "/" then error("refusing to remove unsafe path") end
  assert(M.command_ok("rm -rf " .. M.quote(path)), "cannot remove: " .. path)
end

function M.cp_a(src, dest)
  assert(M.command_ok("cp -R " .. M.quote(src) .. " " .. M.quote(dest)), "cannot copy " .. src .. " to " .. dest)
end

function M.basename(path)
  path = path:gsub("\\", "/")
  return path:match("([^/]+)/*$") or path
end

function M.dirname(path)
  path = path:gsub("\\", "/")
  return path:match("^(.*)/[^/]+/*$") or "."
end

function M.abspath(path)
  if path:sub(1, 1) == "/" then return path end
  local cwd = M.capture("pwd -P")
  return cwd .. "/" .. path
end

function M.safe_output(input, output)
  local function canonical(p)
    p = M.abspath(p):gsub("\\", "/")
    local parts = {}
    for part in p:gmatch('[^/]+') do
      if part == '..' then table.remove(parts) elseif part ~= '.' then parts[#parts+1] = part end
    end
    p = (p:sub(1,1)=='/' and '/' or '') .. table.concat(parts,'/')
    return M.windows and p:lower() or p
  end
  local source, dest, cwd = canonical(input), canonical(output), canonical('.')
  local function under(a,b) return a==b or a:sub(1,#b+1)==b..'/' end
  assert(dest~='' and dest~='/' and not dest:match('^%a:$') and not dest:match('^//[^/]+/[^/]+$'), 'unsafe output directory')
  assert(not under(cwd,dest), 'output must not replace the current directory or its parents')
  assert(not under(source,dest) and not under(dest,source), 'input and output directories must not overlap')
end

function M.toml_string(value)
  value = tostring(value or "")
  value = value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
  return '"' .. value .. '"'
end

function M.write_file(path, content)
  M.mkdir(M.dirname(path))
  local f = assert(io.open(path, "wb"))
  f:write(content)
  f:close()
end

function M.read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
end

function M.host_target()
  local sys = M.capture("uname -s")
  local machine = M.capture("uname -m")
  local arch = ({ arm64 = "aarch64", aarch64 = "aarch64", x86_64 = "x86_64", amd64 = "x86_64" })[machine] or machine
  if sys == "Darwin" then return arch .. "-macos" end
  if sys == "FreeBSD" then return arch .. "-freebsd" end
  if sys == "Linux" then
    local libc = M.capture("getconf GNU_LIBC_VERSION")
    local flavor = libc ~= "" and "gnu" or "musl"
    return arch .. "-linux-" .. flavor
  end
  return arch .. "-" .. sys:lower()
end

function M.normalize_target(target)
  if not target then return nil end
  if target == "darwin-aarch64" then return "aarch64-macos" end
  if target == "darwin-x86_64" then return "x86_64-macos" end
  if target == "linux-x86_64-gnu" then return "x86_64-linux-gnu" end
  if target == "linux-aarch64-gnu" then return "aarch64-linux-gnu" end
  if target == "linux-x86_64-musl" then return "x86_64-linux-musl" end
  if target == "linux-aarch64-musl" then return "aarch64-linux-musl" end
  return target
end

function M.is_known_target(target)
  local norm = M.normalize_target(target)
  return norm == "aarch64-macos"
    or norm == "x86_64-macos"
    or norm == "x86_64-linux-gnu"
    or norm == "aarch64-linux-gnu"
    or norm == "x86_64-linux-musl"
    or norm == "aarch64-linux-musl"
    or norm == "x86_64-freebsd"
    or norm == "aarch64-freebsd"
    or norm == "x86_64-windows"
    or norm == "aarch64-windows"
end

function M.moonstone_home()
  return os.getenv("MOONSTONE_HOME") or ((os.getenv("HOME") or ".") .. "/.local/share/moonstone")
end

function M.b3_file(path)
  local hash = M.capture('moon artifact hash -- ' .. M.quote(M.abspath(path)))
  assert(#hash == 64 and hash:match('^[0-9a-f]+$'), 'Moonstone BLAKE3 hashing failed: ' .. path)
  return 'b3:' .. hash
end

function M.file_uri(path)
  path = M.abspath(path):gsub("\\", "/")
  return "file://" .. (path:sub(1,1)=="/" and "" or "/") .. path:gsub('[^%w%-%._~/:]', function(c) return string.format('%%%02X', c:byte()) end)
end

function M.b3_string(value)
  local tmp = os.tmpname()
  M.write_file(tmp, value)
  local hash = M.b3_file(tmp)
  os.remove(tmp)
  return hash
end

for key, value in pairs(require("love_importer.host")) do M[key] = value end
return M
