#!/usr/bin/env bash
# Guard rail for a public repo: fail if any *.sops.* file is not encrypted or
# if a private key appears anywhere in the files git would commit.
set -Eeuo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

cd "$(dirname "${BASH_SOURCE[0]}")/.."

failed=0
mapfile -d '' files < <(git ls-files -z --cached --others --exclude-standard)

for f in "${files[@]}"; do
    [[ -e "${f}" ]] || continue
    # ?* skips the .sops.yaml config file itself.
    case "${f##*/}" in
        ?*.sops.yaml | ?*.sops.yml | ?*.sops.json)
            if ! grep -q 'ENC\[AES256_GCM' "${f}" || ! grep -Eq '"?mac"?:' "${f}"; then
                log warn "Not encrypted with sops" "file=${f}"
                failed=1
            fi
            ;;
    esac
done

# Patterns are split so this script doesn't match itself.
key_patterns=(
    'AGE-SECRET''-KEY-'
    'BEGIN [A-Z ]*PRIVATE'' KEY'
)
for pattern in "${key_patterns[@]}"; do
    if matches="$(printf '%s\0' "${files[@]}" | xargs -0 grep -IlE -- "${pattern}" 2>/dev/null)"; then
        while IFS= read -r m; do
            log warn "Private key material found" "file=${m}"
        done <<<"${matches}"
        failed=1
    fi
done

if ((failed)); then
    log error "Secret check failed; do not commit these files"
fi
log info "Secret check passed" "files=${#files[@]}"
