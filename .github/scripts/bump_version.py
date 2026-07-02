"""Module providing a function printing python version."""

#!/usr/bin/env python3

import os
import re
import sys

# ------------------------------------------------------------
# Read the contents of pubspec.yaml.
#
# Expected version format:
#
# version: MAJOR.MINOR.PATCH+BUILD
#
# Example:
# version: 1.0.4+15
# ------------------------------------------------------------
with open("pubspec.yaml", "r", encoding="utf-8") as f:
    text = f.read()

# ------------------------------------------------------------
# Find the current version number.
#
# Captured groups:
#   1 -> Major version
#   2 -> Minor version
#   3 -> Patch version
#   4 -> Build number
# ------------------------------------------------------------
match = re.search(
    r"version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)",
    text,
)

if match is None:
    print("Could not find version in pubspec.yaml", file=sys.stderr)
    sys.exit(1)

major, minor, patch, build = map(int, match.groups())

# ------------------------------------------------------------
# Versioning strategy:
#
# - Increment PATCH on every successful release.
# - Increment BUILD on every successful release.
#
# Example:
# 1.0.4+15
# becomes
# 1.0.5+16
# ------------------------------------------------------------
patch += 1
build += 1

# Full version used by Flutter.
VERSION = f"{major}.{minor}.{patch}+{build}"

# Short version used as the GitHub Release tag.
SHORT = f"{major}.{minor}.{patch}"

# ------------------------------------------------------------
# Replace the version inside pubspec.yaml.
# ------------------------------------------------------------
updated_text = re.sub(
    r"version:\s*\d+\.\d+\.\d+\+\d+",
    f"version: {VERSION}",
    text,
)

# ------------------------------------------------------------
# Write the updated pubspec.yaml back to disk.
# ------------------------------------------------------------
with open("pubspec.yaml", "w", encoding="utf-8") as f:
    f.write(updated_text)

# ------------------------------------------------------------
# Export values for use by later GitHub Actions steps.
#
# These become:
#
# steps.version.outputs.version
# steps.version.outputs.short
#
# Example:
#
# version = 1.0.5+16
# short   = 1.0.5
# ------------------------------------------------------------
github_output = os.environ.get("GITHUB_OUTPUT")

if github_output:
    with open(github_output, "a", encoding="utf-8") as f:
        f.write(f"version={VERSION}\n")
        f.write(f"short={SHORT}\n")

# ------------------------------------------------------------
# Print the new version so it appears in the workflow logs.
# ------------------------------------------------------------
print(f"Bumped version to {VERSION}")
