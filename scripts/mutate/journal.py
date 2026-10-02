import hashlib
import json
import os
import shutil
import stat

from manifest import Refusal, count, read_list, sha


# ── Apply, and the journal ────────────────────────────────────────────────

def atomic_write(target, data, journal, mode_source):
    tmp = os.path.join(journal, "write.tmp")
    with open(tmp, "wb") as f:
        f.write(data)
    os.chmod(tmp, stat.S_IMODE(os.stat(mode_source).st_mode))
    os.replace(tmp, target)


def apply(manifest, repo, journal, label):
    e = next(x for x in read_list(manifest) if x["label"] == label)
    target = os.path.join(repo, e["file"])
    with open(target, "rb") as f:
        data = f.read()
    find, new = e["find"].encode("utf-8"), e["replace"].encode("utf-8")
    if count(data, find) != 1:
        raise Refusal(f"{label}: find no longer occurs exactly once")
    mutated = data.replace(find, new, 1)
    os.mkdir(journal)
    shutil.copy2(target, os.path.join(journal, "original"))
    write_record(journal, e, data, mutated)
    atomic_write(target, mutated, journal, os.path.join(journal, "original"))
    if sha(target) != hashlib.sha256(mutated).hexdigest():
        raise Refusal(f"{label}: {e['file']} does not hold the mutated bytes after the write")


def write_record(journal, e, data, mutated):
    record = {
        "label": e["label"],
        "file": e["file"],
        "original": hashlib.sha256(data).hexdigest(),
        "mutated": hashlib.sha256(mutated).hexdigest(),
    }
    tmp = os.path.join(journal, "record.tmp")
    with open(tmp, "w") as f:
        json.dump(record, f)
    os.replace(tmp, os.path.join(journal, "record"))


# ── Recovery, which is also the revert ────────────────────────────────────

def recover(repo, journal, quiet, interrupted=False):
    if not os.path.isdir(journal):
        return
    record_path = os.path.join(journal, "record")
    if not os.path.exists(record_path):
        shutil.rmtree(journal)
        print("RECOVERED: removed an unfinished journal; no mutation was applied")
        return
    try:
        with open(record_path) as f:
            r = json.load(f)
        target = os.path.join(repo, r["file"])
    except Exception as e:
        raise Refusal(f"REFUSED: the journal record {record_path} is unreadable ({e}). Restore by hand, then delete {journal}")
    restore(r, target, journal, quiet, interrupted)


def restore(r, target, journal, quiet, interrupted=False):
    current = sha(target) if os.path.isfile(target) else None
    if current == r["original"]:
        shutil.rmtree(journal)
        if not quiet:
            print(f"RECOVERED: {r['file']} was already original; removed the journal of mutation {r['label']}")
        return
    if current != r["mutated"]:
        raise Refusal(f"REFUSED: {r['file']} matches neither the original nor mutation {r['label']}. "
                      f"The original is at {os.path.join(journal, 'original')}. Restore the file by hand, then delete {journal}")
    saved = os.path.join(journal, "original")
    with open(saved, "rb") as f:
        atomic_write(target, f.read(), journal, saved)
    after = sha(target)
    if after != r["original"]:
        raise Refusal(f"REFUSED: restoring {r['file']} gave {after}, not the original {r['original']}. "
                      f"The saved original at {saved} is damaged. Restore {r['file']} from git by hand, then delete {journal}")
    shutil.rmtree(journal)
    if not quiet:
        if interrupted:
            print(f"RECOVERED: restored {r['file']} from mutation {r['label']}")
        else:
            print(f"RECOVERED: restored {r['file']} from mutation {r['label']}, left by an earlier run")
