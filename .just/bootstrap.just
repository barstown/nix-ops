set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']
set script-interpreter := ['bash', '-euo', 'pipefail']

sops_config := justfile_dir() + '/.sops.yaml'

[private]
default:
    just -l bootstrap

[doc('Generate your post-quantum admin age key and add it to .sops.yaml')]
[group('bootstrap')]
[script]
age-key:
    key="${SOPS_AGE_KEY_FILE:?SOPS_AGE_KEY_FILE is not set; run inside the mise environment}"
    if [[ -s "$key" ]]; then
        just log info "Keeping existing admin key" file "$key"
    else
        install -d -m 0700 "$(dirname "$key")"
        (umask 077 && age-keygen -pq -o "$key" 2>/dev/null)
        just log info "Generated admin key — back it up to your password manager now" file "$key"
    fi
    just bootstrap _set-recipient admin "$(age-keygen -y "$key")"

[doc("Generate a post-quantum age key on the host and add it to .sops.yaml")]
[group('bootstrap')]
host-key host:
    just bootstrap _set-recipient "{{ replace_regex(host, '\..*', '') }}" \
        "$("{{ justfile_dir() }}/scripts/bootstrap-host-key.sh" "{{ host }}")"

[doc("Create the host's encrypted secrets file with the admin password hash")]
[group('bootstrap')]
[script]
host-secrets host user='kyle':
    file="hosts/{{ replace_regex(host, '\..*', '') }}/secrets.sops.yaml"
    cd "{{ justfile_dir() }}"
    if [[ -e "$file" ]]; then
        just log error "Already exists; use 'just sops edit $file'" file "$file"
        exit 1
    fi
    pw="$(gum input --password --placeholder "Console password for {{ user }}@{{ host }}")"
    [[ "$pw" == "$(gum input --password --placeholder 'Confirm password')" ]] \
        || { just log error "Passwords do not match"; exit 1; }
    if command -v mkpasswd >/dev/null; then
        hash="$(mkpasswd --method=yescrypt --stdin <<<"$pw")"
    else
        hash="$(openssl passwd -6 -stdin <<<"$pw")"
    fi
    printf 'users:\n  {{ user }}:\n    hashed-password: %s\n' "$hash" \
        | sops encrypt --filename-override "$file" --input-type yaml --output-type yaml /dev/stdin \
        > "$file"
    just log info "Created encrypted secrets" file "$file"

# Arguments arrive as $1/$2 rather than being interpolated into the script, so
# unexpected input can't break the shell.
[private]
[positional-arguments]
[script]
_set-recipient name pubkey:
    name="$1" pubkey="$2" config="{{ sops_config }}"
    if [[ "$pubkey" != age1pq1* || "$pubkey" == *[[:space:]]* ]]; then
        just log error "Not a post-quantum age key" key "${pubkey:0:40}"
        exit 1
    fi
    placeholder="age1pq1-$name-REPLACE"
    if grep -qF -- "$placeholder" "$config"; then
        sed -i "s|$placeholder|$pubkey|" "$config"
        just log info "Added recipient to .sops.yaml" name "$name"
        just log info "Run 'just sops updatekeys' if secrets already exist for it"
    elif grep -qF -- "$pubkey" "$config"; then
        just log info "Recipient already in .sops.yaml" name "$name"
    else
        just log warn "No placeholder '$placeholder' in .sops.yaml — add this key under 'keys:' with anchor &$name, reference it in a creation rule, then run 'just sops updatekeys'"
        printf '%s\n' "$pubkey"
    fi
