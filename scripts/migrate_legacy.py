#!/usr/bin/env python3
"""迁移 .mooncakes 里旧格式包（moon.mod.json / moon.pkg.json）到新格式（moon.mod / moon.pkg）。

新版 moon（rr_moon_mod flag）不认注册表里的 JSON 格式包描述文件，
需要手动转成 TOML 格式。CI 全新 runner 每次都会拉到旧格式包，
所以在 moon check 之前跑一次这个脚本。
"""
import json
import glob
import os


def json_to_toml(d):
    lines = []
    for k, v in d.items():
        if isinstance(v, str):
            lines.append(f'{k} = "{v}"')
        elif isinstance(v, list):
            items = ", ".join(
                f'"{x}"' if isinstance(x, str) else str(x) for x in v
            )
            lines.append(f"{k} = [{items}]")
        elif isinstance(v, bool):
            lines.append(f"{k} = {'true' if v else 'false'}")
        elif isinstance(v, (int, float)):
            lines.append(f"{k} = {v}")
    return "\n".join(lines) + "\n"


def main():
    migrated = 0
    for path in glob.glob(".mooncakes/**/moon.mod.json", recursive=True):
        d = json.load(open(path))
        open(path.replace("moon.mod.json", "moon.mod"), "w").write(json_to_toml(d))
        os.remove(path)
        migrated += 1
    for path in glob.glob(".mooncakes/**/moon.pkg.json", recursive=True):
        d = json.load(open(path))
        open(path.replace("moon.pkg.json", "moon.pkg"), "w").write(json_to_toml(d))
        os.remove(path)
        migrated += 1
    print(f"migrated {migrated} legacy package files")


if __name__ == "__main__":
    main()
