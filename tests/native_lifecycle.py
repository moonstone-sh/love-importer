"""Test real imports and relocated exports in an isolated Moonstone home."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
import zipfile

sys.stdout.reconfigure(encoding='utf-8')
repo = Path(__file__).resolve().parents[1]
moon = os.environ.get('MOONSTONE_CLI') or os.environ.get('MOONSTONE_BIN') or shutil.which('moon')
assert moon
moon = str(Path(moon).resolve())
os.environ['PATH'] = str(Path(moon).parent) + os.pathsep + os.environ.get('PATH', '')

def run(*args, env=None, failure=False):
    result = subprocess.run([moon, '-C', str(repo), *args], capture_output=True, text=True, encoding='utf-8', errors='replace', env=env, timeout=600)
    assert (result.returncode != 0) == failure, (args, result.stdout, result.stderr)
    print(result.stdout)
    return result.stdout

run('run', 'build')
if os.name != 'nt':
    subprocess.run(['bash', 'tests/smoke.sh'], cwd=repo, check=True, timeout=300)
else:
    with tempfile.TemporaryDirectory(prefix='love importer ') as temporary:
        root = Path(temporary)
        archive = root/'love.zip'
        urllib.request.urlretrieve('https://github.com/love2d/love/releases/download/11.5/love-11.5-win64.zip', archive)
        source = root/'distribution'
        with zipfile.ZipFile(archive) as bundle:
            bundle.extractall(source)
        original = next(source.rglob('love.exe')).parent
        expected = {p.relative_to(original).as_posix(): p.read_bytes() for p in original.rglob('*') if p.is_file()}
        assert 'love.exe' in expected and any(name.lower().endswith('.dll') for name in expected)
        env = dict(os.environ, MOONSTONE_HOME=str(root/'moonstone home'))
        for input_path, label in ((original,'directory'), (archive,'zip')):
            output = root/label
            result = run('exec','--','lua','build/src/main.lua','import',str(input_path),'--version','11.5','--target','x86_64-windows','--out',str(output),'--skip-run-check',env=env)
            installed = Path(next(line.removeprefix('path:').strip() for line in result.splitlines() if line.startswith('path:')))
            for name, content in expected.items():
                assert (output/'files/bin'/name).read_bytes() == content, name
                assert (installed/'files/bin'/name).read_bytes() == content, name
            assert 'bin/love.exe' in (output/'package.toml').read_text()
            assert 'tar.gz' in (output/'package.toml').read_text()
            with tarfile.open(next(output.glob('*.tar.gz'))) as bundle:
                assert 'bin/love.exe' in bundle.getnames()
            assert (output/'registry/registry.toml').is_file()
        system_output = root/'system-only'
        run('exec','--','lua','build/src/main.lua','import-system',str(original/'love.exe'),'--version','11.5','--target','x86_64-windows','--out',str(system_output),'--local-only','--skip-run-check',env=env)
        assert (system_output/'files/bin/love.exe').read_bytes() == expected['love.exe']
        assert 'local_only = true' in (system_output/'import.toml').read_text()
        assert not list((system_output/'files/bin').glob('*.dll'))
        unsafe = root/'unsafe.zip'
        with zipfile.ZipFile(unsafe,'w') as bundle:
            bundle.writestr('../escaped.txt','bad')
        run('exec','--','lua','build/src/main.lua','import',str(unsafe),'--version','11.5','--out',str(root/'unsafe-out'),'--skip-run-check',env=env,failure=True)
        assert not (root/'escaped.txt').exists()
        run('exec','--','lua','build/src/main.lua','import',str(original),'--version','11.5','--out',str(original),'--skip-run-check',env=env,failure=True)
        assert (original/'love.exe').read_bytes() == expected['love.exe']
if os.environ.get('BALLAD_SOURCE'):
    source = Path(os.environ['BALLAD_SOURCE']).resolve().as_posix()
    code = 'package.path=[['+source+'/src/?.lua;'+source+'/src/?/init.lua;]]..package.path;arg={"play","partiture.lua"};dofile([['+source+'/src/main.lua]])'
    run('exec','--','lua','-e',code)
else:
    run('exec','--','ballad','play','partiture.lua')
with tempfile.TemporaryDirectory(prefix='love relocated ') as temporary:
    relocated = Path(temporary)/'app'
    shutil.copytree(repo/'dist/love-importer', relocated, symlinks=True)
    launcher = relocated/'bin'/('love-importer.cmd' if os.name=='nt' else 'love-importer')
    result = subprocess.run([str(launcher),'--help'], capture_output=True, text=True, timeout=60)
    assert result.returncode==0 and 'inspect' in result.stdout, (result.stdout,result.stderr)
print('PASS: native imports, managed runtime installation, and relocated exporter launcher')
