#!/bin/bash
# Normalize all DXF files in the tooling library to millimeters.
# Requires: uv (https://github.com/astral-sh/uv)
#
# Usage: ./normalize_dxf_units.sh
#
# This script finds all profile.dxf files, checks their $INSUNITS header,
# and converts any non-mm files to mm using ezdxf.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for uv
if ! command -v uv &> /dev/null; then
    echo "Error: 'uv' is not installed. Install from https://github.com/astral-sh/uv"
    exit 1
fi

# Python script to normalize a single DXF
read -r -d '' PYTHON_SCRIPT << 'PYEOF' || true
import sys
import ezdxf
from ezdxf import units

path = sys.argv[1]
doc = ezdxf.readfile(path)
insunits = doc.header.get('$INSUNITS', 0)

# 0 = unitless, 4 = mm - both are fine
if insunits == 0 or insunits == 4:
    print(f"SKIP: {path} (already mm or unitless, $INSUNITS={insunits})")
    sys.exit(0)

scale = units.conversion_factor(insunits, units.MM)
unit_name = units.unit_name(insunits)
print(f"CONVERT: {path} ({unit_name} -> mm, scale={scale:.4f})")

msp = doc.modelspace()
for entity in msp:
    entity.scale_uniform(scale)

doc.header['$INSUNITS'] = 4
doc.saveas(path)
print(f"  Saved: {path}")
PYEOF

# Find and process all DXF files
echo "Normalizing DXF files to millimeters..."
echo ""

converted=0
skipped=0

for dxf in $(find "$SCRIPT_DIR" -name "*.dxf" -type f); do
    output=$(uv run --with ezdxf python3 -c "$PYTHON_SCRIPT" "$dxf" 2>&1 | grep -v "^INFO")
    echo "$output"

    if [[ "$output" == CONVERT* ]]; then
        converted=$((converted + 1))
    else
        skipped=$((skipped + 1))
    fi
done

echo ""
echo "Done. Converted: $converted, Skipped: $skipped"
