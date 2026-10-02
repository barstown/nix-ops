set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

[private]
default:
    just -l sops

[doc('Open an encrypted file in $EDITOR (creates it if missing)')]
[group('sops')]
edit file:
    cd "{{ justfile_dir() }}" && sops edit "{{ file }}"

[doc('Re-encrypt every secret for the current recipients in .sops.yaml')]
[group('sops')]
updatekeys:
    cd "{{ justfile_dir() }}" && find . -name '*.sops.*' -not -path './.git/*' -print0 \
        | xargs -0 -r -n1 sops updatekeys --yes

[doc('Verify every *.sops.* file is encrypted and no private keys are present')]
[group('sops')]
check:
    "{{ justfile_dir() }}/scripts/check-secrets.sh"
