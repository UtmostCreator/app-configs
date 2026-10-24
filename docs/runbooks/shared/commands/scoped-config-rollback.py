#!/usr/bin/env python3
"""Restricted, bounded snapshots of explicitly approved files/symlinks; no directory restore.

Usage: snapshot ROOT STATE PATH... | checkpoint STATE | restore STATE
Run under the change's exclusive configuration-edit lock. A checkpoint must be
reviewed against the approved diff before restoration is authorised.
"""
import argparse
import base64
import json
import os
from pathlib import Path
import stat
import sys

LIMIT = 4 * 1024 * 1024
MAX_PATHS = 64


def encode(value):
    return base64.b64encode(value).decode('ascii')


def checked_path(root, name):
    relative = Path(name)
    if relative.is_absolute() or not relative.parts or any(p in ('.', '..') for p in name.split('/')):
        raise ValueError('scope must contain normal relative file paths')
    path = root / relative
    for parent in path.parents:
        if parent == root:
            break
        if parent.is_symlink() or not parent.is_dir():
            raise ValueError('scope parents must be existing real directories')
    return path


def inspect(path):
    try:
        info = path.lstat()
    except FileNotFoundError:
        return None
    if not (stat.S_ISREG(info.st_mode) or stat.S_ISLNK(info.st_mode)):
        raise ValueError('only regular files and symlinks can be in scope')
    if stat.S_ISREG(info.st_mode) and (info.st_nlink != 1 or info.st_size > LIMIT):
        raise ValueError('hardlinked or oversized configuration file is unsupported')
    content = None
    if stat.S_ISREG(info.st_mode):
        with path.open('rb') as stream:
            raw = stream.read(LIMIT + 1)
        if len(raw) > LIMIT:
            raise ValueError('configuration exceeds byte limit')
        content = encode(raw)
    attributes = {key: encode(os.getxattr(path, key, follow_symlinks=False))
                  for key in os.listxattr(path, follow_symlinks=False)}
    return dict(kind='link' if stat.S_ISLNK(info.st_mode) else 'file',
                mode=stat.S_IMODE(info.st_mode), uid=info.st_uid, gid=info.st_gid,
                mtime_ns=info.st_mtime_ns, content=content,
                target=os.readlink(path) if stat.S_ISLNK(info.st_mode) else None,
                xattrs=attributes)


def capture(root, names):
    result = {name: inspect(checked_path(root, name)) for name in names}
    if len(json.dumps(result)) > 2 * LIMIT:
        raise ValueError('snapshot exceeds total manifest size limit')
    return result


def write_json(path, value):
    # Never overwrite an existing checkpoint or follow a destination symlink.
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'w') as stream:
        json.dump(value, stream, sort_keys=True)


def load_json(path):
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077 or info.st_size > 3 * LIMIT:
        raise ValueError('manifest must be a restricted regular file within the size limit')
    return json.loads(path.read_text())


def restore_one(path, record):
    current = inspect(path)
    if current is not None and (record is None or current['kind'] != record['kind']):
        path.unlink()
    if record is None:
        return
    if record['kind'] == 'link':
        if path.is_symlink():
            path.unlink()
        path.symlink_to(record['target'])
    else:
        with path.open('wb') as stream:
            stream.write(base64.b64decode(record['content']))
    info = path.lstat()
    if (info.st_uid, info.st_gid) != (record['uid'], record['gid']):
        os.chown(path, record['uid'], record['gid'], follow_symlinks=False)
    if record['kind'] == 'file':
        os.chmod(path, record['mode'])
    # ACLs are included where the filesystem exposes them as system.posix_acl_*.
    for key in os.listxattr(path, follow_symlinks=False):
        if key not in record['xattrs']:
            os.removexattr(path, key, follow_symlinks=False)
    for key, value in record['xattrs'].items():
        os.setxattr(path, key, base64.b64decode(value), follow_symlinks=False)
    os.utime(path, ns=(record['mtime_ns'], record['mtime_ns']), follow_symlinks=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('snapshot', 'checkpoint', 'restore'))
    parser.add_argument('arguments', nargs='+')
    args = parser.parse_args()
    if args.action == 'snapshot':
        if len(args.arguments) < 3:
            parser.error('snapshot requires ROOT STATE PATH...')
        root_arg, state_arg, *names = args.arguments
        root = Path(root_arg)
        if not root.is_absolute() or root.resolve() != root or not root.is_dir():
            raise ValueError('ROOT must be an absolute real directory')
        if len(names) != len(set(names)) or not 1 <= len(names) <= MAX_PATHS:
            raise ValueError('scope must have 1..64 distinct file paths')
        state = Path(state_arg)
        if state.resolve() == root or root in state.resolve().parents:
            raise ValueError('STATE must be outside the configuration root')
        before = capture(root, names)
        write_json(state, dict(root=str(root), before=before))
        if capture(root, names) != before:
            raise ValueError('configuration changed during snapshot; discard and restart')
    else:
        if len(args.arguments) != 1:
            parser.error('checkpoint/restore requires STATE')
        state = Path(args.arguments[0])
        document = load_json(state)
        root = Path(document['root'])
        if not root.is_absolute() or root.resolve() != root or not root.is_dir():
            raise ValueError('configuration root moved or became a symlink; review target')
        before = document['before']
        checkpoint = state.with_name(state.name + '.expected')
        current = capture(root, before)
        if args.action == 'checkpoint':
            write_json(checkpoint, current)
        else:
            expected = load_json(checkpoint)
            if current != expected:
                raise ValueError('scoped drift detected; no files restored; review and reauthorise')
            for name, record in before.items():
                restore_one(checked_path(root, name), record)
            if capture(root, before) != before:
                raise ValueError('restoration metadata/bytes verification failed')
    print(args.action + ': verified scoped filesystem state; service validation still required')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError) as error:
        print('BLOCK: ' + str(error), file=sys.stderr)
        sys.exit(1)
