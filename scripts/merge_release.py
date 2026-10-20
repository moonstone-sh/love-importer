"""Combine independently built host artifacts into one registry descriptor."""
import argparse
from pathlib import Path
import re
import tomllib

parser = argparse.ArgumentParser()
parser.add_argument('root', type=Path)
parser.add_argument('--version', required=True)
parser.add_argument('--release-url', required=True)
parser.add_argument('--expected-count', type=int, default=3)
args = parser.parse_args()
heads, blocks, targets, names = [], [], set(), set()
for descriptor in sorted(args.root.rglob('package.toml')):
    text = descriptor.read_text()
    document = tomllib.loads(text)
    assert document['package']['name'] == 'moonstone/love-importer'
    assert document['package']['version'] == args.version
    artifacts = document['artifacts']
    assert len(artifacts) == 1
    artifact = artifacts[0]
    target = artifact['target']
    assert target != 'any' and target not in targets, target
    targets.add(target)
    name = artifact['url'].rsplit('/', 1)[-1]
    assert name not in names and '/' not in name and name.endswith('.tar.gz'), name
    names.add(name)
    assert (descriptor.parent/name).is_file(), name
    head, block = text.split('[[artifacts]]', 1)
    heads.append({key: value for key, value in document.items() if key != 'artifacts'})
    assert heads[-1] == heads[0], 'host package declarations disagree'
    url = args.release_url.rstrip('/') + '/' + name
    block, count = re.subn(r'^url = .*$', 'url = "' + url + '"', block, count=1, flags=re.MULTILINE)
    assert count == 1
    blocks.append('[[artifacts]]' + block)
assert len(blocks) == args.expected_count, targets
output = head + '\n'.join(blocks)
assert len(tomllib.loads(output)['artifacts']) == args.expected_count
(args.root/'combined.toml').write_text(output)
print('Combined release targets: ' + ', '.join(sorted(targets)))
