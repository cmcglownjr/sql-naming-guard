#!/usr/bin/env bash
set -euo pipefail

SQL_DIR="${1:-.}"
STRICT_MODE="${STRICT_MODE:-false}"
CHANGED_ONLY="${CHANGED_ONLY:-false}"

violations=0

echo "Scanning SQL files for disallowed database-qualified table references"
echo "  SQL path      : $SQL_DIR"
echo "  Strict mode   : $STRICT_MODE"
echo "  Changed only  : $CHANGED_ONLY"

get_changed_sql_files() {
    local files=""

    if [[ -n "${GITHUB_EVENT_NAME:-}" ]]; then
        case "$GITHUB_EVENT_NAME" in
            pull_request)
                files=$(git diff --name-only \
                    "$GITHUB_BASE_SHA" "$GITHUB_SHA")
                ;;
            push)
                files=$(git diff --name-only \
                    "$GITHUB_EVENT_BEFORE" "$GITHUB_SHA")
                ;;
        esac
    fi

    echo "$files" | grep -E '^.*\.sql$' || true
}

if [[ "$CHANGED_ONLY" == "true" ]]; then
    mapfile -t sql_files < <(get_changed_sql_files)

    if [[ "${#sql_files[@]}" -eq 0 ]]; then
        echo "No changed SQL files detected — skipping scan"
        exit 0
    fi
else
    mapfile -t sql_files < <(find "$SQL_DIR" -type f -name "*.sql")
fi

for file in "${sql_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        continue
    fi

    # Skip explicitly ignored files
    if grep -qi "sql-naming-guard:ignore" "$file"; then
        echo "↷ Skipping $file (explicit ignore)"
        continue
    fi

    cleaned=$(sed \
        -e 's/--.*$//' \
        -e 's/#.*$//' \
        "$file")

    if [[ "$STRICT_MODE" == "true" ]]; then
        if echo "$cleaned" | grep -Ein '\b[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+' > /dev/null; then
            echo "::error file=$file::Database-qualified table found (strict mode)"
            violations=$((violations + 1))
        fi
    else
        if echo "$cleaned" | grep -Ein \
            '\b(FROM|JOIN)\s+[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+' > /dev/null; then
            echo "::error file=$file::Database-qualified table found (FROM/JOIN)"
            violations=$((violations + 1))
        fi
    fi
done

if [[ "$violations" -gt 0 ]]; then
    echo "❌ $violations SQL violation(s) detected"
    exit 1
fi

echo "✅ SQL validation passed"
