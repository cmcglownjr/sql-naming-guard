#!/usr/bin/env bash
set -euo pipefail

SQL_DIR="${1:-.}"
STRICT_MODE="${STRICT_MODE:-false}"

violations=0

echo "Scanning SQL files for disallowed database-qualified table references..."
echo "Strict mode: $STRICT_MODE"

while IFS= read -r -d '' file; do
    # Skip intentionally ignored files
    if grep -qi "sql-naming-guard:ignore" "$file"; then
        echo "↷ Skipping $file (explicit ignore)"
        continue
    fi

    # Strip common SQL comments
    cleaned=$(sed \
        -e 's/--.*$//' \
        -e 's/#.*$//' \
        "$file")

    if [[ "$STRICT_MODE" == "true" ]]; then
        # Strict: database.table anywhere
        if echo "$cleaned" | grep -Ein '\b[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+' > /dev/null; then
            echo "::error file=$file::Database-qualified table found (strict mode)"
            violations=$((violations + 1))
        fi
    else
        # Default: FROM / JOIN only
        if echo "$cleaned" | grep -Ein \
            '\b(FROM|JOIN)\s+[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+' > /dev/null; then
            echo "::error file=$file::Database-qualified table found (FROM/JOIN)"
            violations=$((violations + 1))
        fi
    fi
done < <(find "$SQL_DIR" -type f -name "*.sql" -print0)

if [[ "$violations" -gt 0 ]]; then
    echo "❌ $violations SQL violation(s) detected"
    exit 1
fi

echo "✅ SQL validation passed"
