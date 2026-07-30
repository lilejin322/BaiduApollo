#!/usr/bin/env python3
"""Patch buildtool's Procedure._check_network to use real shell redirection.

The buildtool package ships:
    cmd = ["curl", "--max-time", "15", login_api, ">/dev/null 2>&1"]
    subprocess.call(cmd)
`subprocess.call(cmd)` (a list, no shell=True) passes ">/dev/null" and
"2>&1" to curl as literal positional arguments instead of shell redirection,
so curl always errors out and buildtool permanently reports offline mode.

This is re-applied on every container (re)creation because
`apt install --only-upgrade apollo-neo-buildtool` can restore the buggy
file shipped by upstream. Safe to run repeatedly (idempotent).
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

METHOD_PATTERN = re.compile(
    r"    def _check_network\(self\):\n(?:.*\n)*?        self\.online = False\n"
)


def patch_file(path):
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    if FIXED_BODY in content:
        print("[skip] already patched: {}".format(path))
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
