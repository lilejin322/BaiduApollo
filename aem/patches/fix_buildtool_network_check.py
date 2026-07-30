#!/usr/bin/env python3
"""Force buildtool's Procedure._check_network to the retry-based implementation.

Upstream apollo-neo-buildtool has shipped at least two variants of this
method:
  - a buggy one that calls `subprocess.call(cmd)` (a list, no shell=True),
    so ">/dev/null 2>&1" gets passed to curl as literal argv and curl
    always errors out, permanently forcing offline mode; and
  - a "fixed" single-attempt one (`--max-time 5`, one curl call, no retry)
    that no longer has that bug but gives up after one 5s attempt, so a
    transient network hiccup still flips buildtool into offline mode.

Either way we want the retry version below (7 attempts, 15s timeout each,
proper shell=True). This replaces the whole method body unconditionally
(matched by its `def _check_network(self):` header up to the next method
at the same indentation), regardless of which variant is currently
installed, so it's robust to upstream rewrites. Re-applied on every
container (re)creation because `apt install --only-upgrade` can reinstall
a different variant. Safe to run repeatedly (idempotent).
"""
import glob
import re

TARGET_GLOB = "/opt/apollo/neo/packages/buildtool/*/core/task/bazel/handler/__init__.py"

FIXED_BODY = '''    def _check_network(self):
        login_api = get_config("api", "login")
        cmd = ["curl", "--max-time", "15", login_api, ">/dev/null 2>&1"]
        max_attempts = 7
        for attempt in range(1, max_attempts + 1):
            if subprocess.call(" ".join(cmd), shell=True) == 0:
                return
            logger.warning(
                "Network check attempt {}/{} failed".format(attempt, max_attempts))
        logger.warning("Can't connect with the server, use offline mode")
        self.online = False

'''

# Captures the whole current _check_network body: from its `def` line up to
# (but not including) the next method defined at the same 4-space class
# indentation, so it doesn't care how the body in between is written.
METHOD_PATTERN = re.compile(
    r"    def _check_network\(self\):\n"
    r"(?:(?!    def ).*\n)*"
)


def patch_file(path):
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    if FIXED_BODY in content:
        print("[skip] already the retry version: {}".format(path))
        return

    new_content, count = METHOD_PATTERN.subn(FIXED_BODY, content, count=1)
    if count == 0:
        print("[warn] _check_network method not found, skip: {}".format(path))
        return

    with open(path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print("[fixed] {}".format(path))


def main():
    targets = glob.glob(TARGET_GLOB)
    if not targets:
        print("[warn] no buildtool handler/__init__.py matched {}".format(TARGET_GLOB))
        return
    for path in targets:
        patch_file(path)


if __name__ == "__main__":
    main()
