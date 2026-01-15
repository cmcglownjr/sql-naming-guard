#!/usr/bin/env bash
set -euo pipefail

SQL_DIR="${1:-.}"

violations=0

echo "Scanning SQL files for disallowed database-qualified table references..."

while IFS= read -r -d '' file; do
    # Remove SQL comments (simple but effective)
    cleaned=$(sed \
        -e 's/--.*$//' \
        -e 's/#.*$//' \
        "$file")

    if echo "$cleaned" | grep -Ein \
        '\b(FROM|JOIN)\s+[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+' > /dev/null; then
        echo "::error file=$file::Database-qualified table found (database.table)"
        violations=$((violations + 1))
    fi
done < <(find "$SQL_DIR" -type f -name "*.sql" -print0)

if [[ "$violations" -gt 0 ]]; then
    echo "❌ $violations SQL file(s) violate database.table naming rules"
    exit 1
fi

echo "✅ SQL validation passed"
