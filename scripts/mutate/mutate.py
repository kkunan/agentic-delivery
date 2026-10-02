import os
import sys

from journal import apply, recover
from manifest import Refusal, validate
from results import baseline, verdict


def tool():
    return os.environ.get("MUTATE_XCRESULTTOOL") or "xcrun xcresulttool"


def main(argv):
    cmd, args = argv[0], argv[1:]
    if cmd == "validate":
        validate(*args)
    elif cmd == "apply":
        apply(*args)
    elif cmd == "recover":
        flags = args[2:]
        recover(args[0], args[1], "--quiet" in flags, "--interrupted" in flags)
    elif cmd == "verdict":
        print("\t".join(verdict(int(args[0]), args[1], tool())))
    elif cmd == "baseline":
        problems = baseline(int(args[0]), args[1], args[2:], tool())
        for p in problems:
            print(p)
        return 2 if problems else 0
    else:
        raise Refusal(f"unknown command {cmd}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Refusal as e:
        print(e, file=sys.stderr)
        sys.exit(4)
    except Exception as e:
        print(f"mutate.py failed: {type(e).__name__}: {e}", file=sys.stderr)
        sys.exit(5)
