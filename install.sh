#!/bin/sh
# Alias for get.sh -- the universal bootstrap. Kept so `install.sh` works too.
d="$(cd "$(dirname "$0")" && pwd)"
exec sh "$d/get.sh" "$@"
