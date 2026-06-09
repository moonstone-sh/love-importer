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
  return path:match("([^/]+)/*$") or path
end

function M.dirname(path)
  return path:match("^(.*)/[^/]+/*$") or "."
end

function M.abspath(path)
  if path:sub(1, 1) == "/" then return path end
  local cwd = M.capture("pwd -P")
  return cwd .. "/" .. path
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
  if sys == "Darwin" then return "darwin-" .. arch end
  if sys == "FreeBSD" then return "freebsd-" .. arch end
  if sys == "Linux" then
    local libc = M.capture("getconf GNU_LIBC_VERSION")
    local flavor = libc ~= "" and "gnu" or "musl"
    return "linux-" .. arch .. "-" .. flavor
  end
  return sys:lower() .. "-" .. arch
end

function M.is_known_target(target)
  return target:match("^darwin%-aarch64$")
    or target:match("^darwin%-x86_64$")
    or target:match("^linux%-x86_64%-gnu$")
    or target:match("^linux%-aarch64%-gnu$")
    or target:match("^linux%-x86_64%-musl$")
    or target:match("^linux%-aarch64%-musl$")
    or target:match("^freebsd%-x86_64$")
    or target:match("^freebsd%-aarch64$")
end

function M.moonstone_home()
  return os.getenv("MOONSTONE_HOME") or ((os.getenv("HOME") or ".") .. "/.local/share/moonstone")
end

function M.b3_file(path)
  local b3sum = M.capture("command -v b3sum")
  if b3sum == "" then error("b3sum is required") end
  return "b3:" .. M.capture(M.quote(b3sum) .. " --no-names " .. M.quote(path))
end

function M.b3_string(value)
  local tmp = os.tmpname()
  M.write_file(tmp, value)
  local hash = M.b3_file(tmp)
  os.remove(tmp)
  return hash
end

return M
