"""Preserve independent MIME preferences before Home Manager replaces XDG links."""

import configparser
import hashlib
import io
import os
from pathlib import Path
import re
import sys
import tempfile


def parse(data):
    # Desktop-entry keys are case-sensitive. '%' is literal in INI values.
    parser = configparser.ConfigParser(interpolation=None, delimiters=("=",), default_section="")
    parser.optionxform = str
    parser.read_string(data.decode("utf-8"))
    return parser


def merge(sources, declared):
    result = parse(b"")
    association_sections = ("Removed Associations", "Added Associations")
    decided = set()
    for source in sources:  # restored config, restored legacy data, then mutable state
        for section in source.sections():
            if not result.has_section(section):
                result.add_section(section)
            if section not in association_sections:
                for mime, value in source[section].items():
                    result[section].setdefault(mime, value)
        # Each desktop ID has one add/remove decision per MIME type. On an
        # ambiguous entry in the same source, honour explicit removal.
        for section in association_sections:
            if section not in source:
                continue
            for mime, value in source[section].items():
                kept = result[section].get(mime, "").split(";")
                for app in filter(None, value.split(";")):
                    if (mime, app) not in decided:
                        kept.append(app)
                        decided.add((mime, app))
                if any(kept):
                    result[section][mime] = ";".join(filter(None, kept)) + ";"
    defaults = "Default Applications"
    if defaults not in result:
        result.add_section(defaults)
    result[defaults].update(declared[defaults])
    return result


def save(path, data, *, backup=False):
    # A completed temporary file can be published atomically. Backups use
    # link(2) so an existing recovery copy is never overwritten.
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as f:
        temp = Path(f.name)
        try:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
            if backup:
                try:
                    os.link(temp, path)
                except FileExistsError:
                    if path.is_symlink() or not path.is_file() or path.read_bytes() != data:
                        raise ValueError("existing backup conflicts")
            else:
                os.replace(temp, path)
        finally:
            temp.unlink(missing_ok=True)


def migrate(state, config, legacy, declared):
    raw = {}
    regular_inputs = {}
    if state.is_symlink():
        raise ValueError("mutable state must be a regular file")
    for name, path in (("config", config), ("legacy", legacy), ("state", state)):
        if path.is_symlink():
            destination = path.resolve()
            if destination == state.resolve():
                continue
            # Previous HM releases linked this generated INI out of the store.
            # Refuse arbitrary linked files before reading or backing them up.
            if not re.fullmatch(r"/nix/store/[0-9a-df-np-sv-z]{32}-mimeapps\.list", str(destination)):
                raise ValueError("unexpected MIME link")
        if not os.path.lexists(path):
            continue
        if not path.is_file():
            raise ValueError("MIME location is unreadable or has unexpected type")
        if name != "state" and not path.is_symlink():
            regular_inputs[name] = (path, path.stat())
        raw[name] = path.read_bytes()

    # Parsing must succeed for every source before the first write.
    docs = {name: parse(data) for name, data in raw.items()}
    merged = merge(docs.values(), parse(declared.read_bytes()))
    change = "state" not in docs or docs["state"] != merged
    state.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    for name, data in raw.items():
        if name == "state" and not change:
            continue
        backups = state.parent / "mimeapps-backups"
        backups.mkdir(mode=0o700, exist_ok=True)
        if backups.is_symlink() or backups.stat().st_uid != os.getuid() or backups.stat().st_mode & 0o077:
            raise ValueError("expected a private MIME backup directory")
        digest = hashlib.sha256(data).hexdigest()
        save(backups / f"{name}-{digest}.list", data, backup=True)
    if change:
        out = io.StringIO()
        merged.write(out, space_around_delimiters=False)
        save(state, out.getvalue().encode("utf-8"))

    canonical = state.read_bytes()
    for name, (path, before) in regular_inputs.items():
        current = path.lstat()
        if not os.path.samestat(before, current) or before.st_mtime_ns != current.st_mtime_ns:
            raise ValueError("MIME input changed during migration")
        if raw[name] == canonical:
            # HM deliberately skips an identical regular file. Give it a link
            # to adopt so future writes through either path reach the state.
            with tempfile.TemporaryDirectory(dir=path.parent) as directory:
                link = Path(directory) / "mimeapps.list"
                link.symlink_to(state)
                os.replace(link, path)


if __name__ == "__main__":
    try:
        migrate(*map(Path, sys.argv[1:]))
    except (OSError, ValueError, RuntimeError, configparser.Error):
        sys.exit("MIME migration failed. Review the XDG MIME files and private mimeapps-backups before activation.")
