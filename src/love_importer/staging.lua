local util = require("love_importer.util")

local M = {}

function M.create_temp()
  local tmp = util.capture("mktemp -d")
  if tmp == "" then error("mktemp failed") end
  return tmp
end

function M.copy_tree(source, dest)
  local source_abs = util.abspath(source)
  local dest_abs = util.abspath(dest)
  util.mkdir(dest_abs)
  assert(util.command_ok("cd " .. util.quote(source_abs) .. " && tar -cf - . | (cd " .. util.quote(dest_abs) .. " && tar -xf -)"), "failed to copy tree")
end

function M.copy_file(source, dest)
  local source_abs = util.abspath(source)
  local dest_abs = util.abspath(dest)
  util.mkdir(util.dirname(dest_abs))
  assert(util.command_ok("cp " .. util.quote(source_abs) .. " " .. util.quote(dest_abs)), "failed to copy file")
end

function M.symlink(target, link_path)
  util.mkdir(util.dirname(link_path))
  assert(util.command_ok("ln -s " .. util.quote(target) .. " " .. util.quote(link_path)), "failed to create symlink")
end

function M.clear_quarantine(path)
  local xattr = util.capture("command -v xattr")
  if xattr == "" then return false end
  return util.command_ok(util.quote(xattr) .. " -dr com.apple.quarantine " .. util.quote(path))
end

function M.is_internal_symlink(path, root)
  local target = util.capture("readlink " .. util.quote(path))
  if target == "" then return true end
  if target:sub(1, 1) == "/" then return false, target end
  local target_dir = util.dirname(target)
  local normalized = util.capture("cd " .. util.quote(util.dirname(path)) .. " && cd " .. util.quote(target_dir) .. " && pwd -P")
  local abs_root = util.capture("cd " .. util.quote(root) .. " && pwd -P")
  return normalized:sub(1, #abs_root) == abs_root, target
end

function M.validate_no_external_symlink(path, root, display_path)
  local ok, target = M.is_internal_symlink(path, root)
  if not ok then
    error("Refusing to register artifact with external symlink:\n\n  " .. display_path .. " -> " .. target .. "\n\nMoonstone store artifacts must be self-contained. Copy the app/root into the artifact instead.")
  end
end

function M.validate_runtime_root(files_dir, opts)
  local love = files_dir .. "/bin/love"
  local is_symlink = util.capture("test -L " .. util.quote(love) .. " && echo yes") == "yes"
  if not util.is_file(love) and not is_symlink then error("staged artifact missing files/bin/love") end
  if not util.is_executable(love) then error("staged files/bin/love is not executable") end
  M.validate_no_external_symlink(love, files_dir, "files/bin/love")
  if not opts.version or opts.version == "" then error("version is required") end
  if not opts.target or opts.target == "" then error("target is required") end
  if not util.is_known_target(opts.target) then error("unknown target: " .. opts.target) end
end

return M
