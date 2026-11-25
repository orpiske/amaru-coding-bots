#!/usr/bin/env python3
"""Checks every bot folder under bots/ for the layout the build expects.

Each bots/<name>/ must have a Containerfile, amaru.yaml, project.yaml and
README.md, and:
- <name> is lowercase letters, digits and dashes (it becomes the image name);
- the Containerfile builds FROM ${BASE_IMAGE}, declares that ARG, and copies
  amaru.yaml and project.yaml to /config/;
- amaru.yaml and project.yaml parse, amaru.yaml lists project.yaml, the
  project's agent is defined in amaru.yaml, the project names a repo and an
  intake label or assignee;
- the web port in amaru.yaml (web.listen) is EXPOSEd by the Containerfile
  and no two bots share it, so they can all run on one host.

It checks the layout only. The images are built by CI
(.github/workflows/build-bots.yml), and Amaru Light validates every key when
the daemon starts.
"""

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("check-bots: PyYAML is missing (pip install pyyaml, or python3-pyyaml)")

ROOT = Path(__file__).resolve().parent.parent
BOTS = ROOT / "bots"
REQUIRED = ["Containerfile", "amaru.yaml", "project.yaml", "README.md"]
NAME = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def load(path, errors):
    try:
        data = yaml.safe_load(path.read_text())
    except yaml.YAMLError as e:
        errors.append(f"{path.relative_to(ROOT)}: does not parse: {e}")
        return None
    if not isinstance(data, dict):
        errors.append(f"{path.relative_to(ROOT)}: is not a mapping")
        return None
    return data


def check_bot(bot, errors, ports):
    rel = bot.relative_to(ROOT)
    if not NAME.match(bot.name):
        errors.append(f"{rel}: the name must be lowercase letters, digits and dashes")
    missing = [f for f in REQUIRED if not (bot / f).is_file()]
    for f in missing:
        errors.append(f"{rel}: {f} is missing")
    if missing:
        return

    containerfile = (bot / "Containerfile").read_text()
    if not re.search(r"^ARG BASE_IMAGE=\S+", containerfile, re.M):
        errors.append(f"{rel}/Containerfile: needs `ARG BASE_IMAGE=<default>` before FROM")
    if not re.search(r"^FROM \$\{BASE_IMAGE\}\s*$", containerfile, re.M):
        errors.append(f"{rel}/Containerfile: the final stage must be `FROM ${{BASE_IMAGE}}`")
    if not re.search(r"^COPY .*\bamaru\.yaml\b.*\bproject\.yaml\b.*\s/config/\s*$", containerfile, re.M):
        errors.append(f"{rel}/Containerfile: must COPY amaru.yaml project.yaml /config/")
    exposed = set(re.findall(r"^EXPOSE\s+(\d+)", containerfile, re.M))

    daemon = load(bot / "amaru.yaml", errors)
    project = load(bot / "project.yaml", errors)
    if daemon is None or project is None:
        return

    if not daemon.get("state_dir"):
        errors.append(f"{rel}/amaru.yaml: state_dir is missing")
    projects = daemon.get("projects") or []
    if "project.yaml" not in projects:
        errors.append(f"{rel}/amaru.yaml: projects must list project.yaml")
    agents = daemon.get("agents") or {}
    if not agents:
        errors.append(f"{rel}/amaru.yaml: no agents are defined")

    listen = (daemon.get("web") or {}).get("listen")
    if listen:
        port = str(listen).rsplit(":", 1)[-1]
        if not str(listen).startswith("0.0.0.0:"):
            errors.append(f"{rel}/amaru.yaml: web.listen must be 0.0.0.0:<port> to be reachable from the host")
        if port not in exposed:
            errors.append(f"{rel}: web port {port} is not EXPOSEd in the Containerfile")
        if port in ports:
            errors.append(f"{rel}: web port {port} is already used by bots/{ports[port]}")
        ports[port] = bot.name
    else:
        errors.append(f"{rel}/amaru.yaml: web.listen is missing; give each bot its own port")

    if not re.match(r"^[\w.-]+/[\w.-]+$", str(project.get("repo", ""))):
        errors.append(f"{rel}/project.yaml: repo must be owner/name")
    if project.get("agent") not in agents:
        errors.append(f"{rel}/project.yaml: agent {project.get('agent')!r} is not defined in amaru.yaml")
    intake = project.get("intake") or {}
    if not intake.get("labels") and not intake.get("assignee"):
        errors.append(f"{rel}/project.yaml: intake needs labels, an assignee or both")
    if not project.get("checks"):
        errors.append(f"{rel}/project.yaml: no checks are defined")


def main():
    errors = []
    ports = {}
    bots = sorted(p for p in BOTS.iterdir() if p.is_dir()) if BOTS.is_dir() else []
    if not bots:
        errors.append("bots/: no bots found")
    for bot in bots:
        check_bot(bot, errors, ports)
    for e in errors:
        print(f"error: {e}", file=sys.stderr)
    if errors:
        sys.exit(1)
    for port, name in sorted(ports.items()):
        print(f"ok  {name:24} port {port}")


if __name__ == "__main__":
    main()
