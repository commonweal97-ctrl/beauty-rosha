#!/bin/bash
for f in "$@"; do
    perl -i -pe 's/^class _/}\n\nclass _/' "$f"
    echo "✅ $f"
done
