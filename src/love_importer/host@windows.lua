local M = { windows = true }
local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function b64(bytes)
  local out = {}
  for i=1,#bytes,3 do
    local a,b,c=bytes:byte(i,i+2); local n=a*65536+(b or 0)*256+(c or 0)
    for shift=18,0,-6 do local k=math.floor(n/2^shift)%64+1; out[#out+1]=alphabet:sub(k,k) end
    if i+1>#bytes then out[#out-1]='=' end
    if i+2>#bytes then out[#out]='=' end
  end
  return table.concat(out)
end
function M.literal(value)
  return "([Text.Encoding]::Default.GetString([Convert]::FromBase64String('"..b64(value).."')))"
end
function M.ps(script, capture)
  script="$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue';[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false);"..script
  local command='powershell.exe -NoLogo -NoProfile -NonInteractive -EncodedCommand '..b64((script:gsub('.',function(c)return c..'\0'end)))
  if capture then
    local pipe=assert(io.popen(command,'r')); local output=pipe:read('*a'); local ok=pipe:close()
    assert(ok==true or ok==0,'Windows filesystem operation failed')
    return (output:gsub('%s+$',''))
  end
  local ok=os.execute(command); assert(ok==true or ok==0,'Windows filesystem operation failed')
end
function M.quote(value)
  value=tostring(value)
  assert(not value:find('[&|<>()^"!%%\r\n%z]') and value:sub(-1)~='\\','unsafe Windows command argument; use a path without cmd metacharacters')
  return '"'..value..'"'
end
function M.capture(command)
  -- The prefix keeps cmd's outer quote handling from stripping a quoted tool.
  local p=assert(io.popen('cmd /d /v:off /s /c "@ '..command..' 2>NUL"','r'))
  local text=p:read('*a') or ''; p:close(); return (text:gsub('%s+$',''))
end
function M.is_dir(p) return M.ps('if([IO.Directory]::Exists('..M.literal(p)..')){\'yes\'}',true)=='yes' end
function M.is_file(p) return M.ps('if([IO.File]::Exists('..M.literal(p)..')){\'yes\'}',true)=='yes' end
function M.is_executable(p) return p:lower():match('%.exe$')~=nil and M.is_file(p) end
function M.mkdir(p) M.ps('[IO.Directory]::CreateDirectory('..M.literal(p)..')|Out-Null') end
function M.rm_rf(p)
  local n=p:gsub('\\','/'):gsub('/+$','')
  assert(n~='' and n~='.' and n~='..' and not n:match('^%a:$') and not n:match('^//[^/]+/[^/]+$'),'refusing unsafe removal')
  M.ps('$p='..M.literal(p)..';if(Test-Path -LiteralPath $p){Remove-Item -LiteralPath $p -Recurse -Force}')
end
function M.abspath(p) return M.ps('[IO.Path]::GetFullPath('..M.literal(p)..')',true):gsub('\\','/') end
function M.copy_file(s,d) M.mkdir((d:gsub('\\','/'):match('^(.*)/') or '.')); M.ps('[IO.File]::Copy('..M.literal(s)..','..M.literal(d)..',$true)') end
function M.copy_tree(s,d)
  M.mkdir(d)
  M.validate_tree(s)
  M.ps('Get-ChildItem -LiteralPath '..M.literal(s)..' -Force|Copy-Item -Destination '..M.literal(d)..' -Recurse -Force')
end
function M.cp_a(s,d) return M.copy_tree(s,d) end
function M.create_temp() local p=os.tmpname();os.remove(p);M.mkdir(p);return M.abspath(p) end
function M.host_target()
  local a=(os.getenv('PROCESSOR_ARCHITEW6432') or os.getenv('PROCESSOR_ARCHITECTURE') or ''):lower()
  local arch=({amd64='x86_64',arm64='aarch64'})[a];assert(arch,'unsupported Windows architecture: '..a);return arch..'-windows'
end
function M.validate_tree(root)
  -- Inspect each directory before descending, so junction loops are rejected
  -- before they can turn enumeration into an unbounded traversal.
  M.ps('$stack=[Collections.Generic.Stack[string]]::new();$stack.Push('..M.literal(root)..');while($stack.Count -gt 0){$p=$stack.Pop();$i=Get-Item -LiteralPath $p -Force;if($i.Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Runtime contains a reparse point"};foreach($i in @(Get-ChildItem -LiteralPath $p -Force)){if($i.Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Runtime contains a reparse point"};if($i.PSIsContainer){$stack.Push($i.FullName)}}}')
end

function M.entries(root,output)
  M.validate_tree(root)
  M.ps('$root=[IO.Path]::GetFullPath('..M.literal(root)..').TrimEnd([char]92,[char]47);$entries=@(Get-ChildItem -LiteralPath $root -File -Recurse -Force|Sort-Object FullName|ForEach-Object{$rel=$_.FullName.Substring($root.Length+1).Replace([char]92,[char]47);@{virtual_path=$rel;source_path=$_.FullName;mode=$(if($_.Extension -eq ".exe"){"0755"}else{"0644"})}});$json=@{contract="moonstone:artifact-entries:v1";entries=$entries}|ConvertTo-Json -Depth 6;[IO.File]::WriteAllText('..M.literal(output)..',$json,[Text.UTF8Encoding]::new($false))')
end
function M.extract_zip(archive,dest)
  M.ps('Add-Type -AssemblyName System.IO.Compression.FileSystem;$z=[IO.Compression.ZipFile]::OpenRead('..M.literal(archive)..');try{foreach($e in $z.Entries){$n=$e.FullName.Replace([char]92,[char]47);if($n.StartsWith("/") -or $n.Contains(":") -or @($n.Split("/")|Where-Object{$_ -eq ".."}).Count -gt 0 -or ((($e.ExternalAttributes -shr 16) -band 61440) -eq 40960)){throw "Unsafe ZIP entry"}}}finally{$z.Dispose()};[IO.Compression.ZipFile]::ExtractToDirectory('..M.literal(archive)..','..M.literal(dest)..')')
end
function M.find_love(root)
  local text=M.ps('@(Get-ChildItem -LiteralPath '..M.literal(root)..' -Recurse -File -Filter love.exe|ForEach-Object{$_.DirectoryName})|ConvertTo-Json -Compress',true)
  local json=require('dkjson');local paths=json.decode(text);if type(paths)=='string'then return{(paths:gsub('\\','/'))}end
  local result={};for _,p in ipairs(paths or{})do result[#result+1]=p:gsub('\\','/')end;return result
end
return M
