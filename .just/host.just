set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']
set script-interpreter := ['bash', '-euo', 'pipefail']

# <host> is the name you SSH to, e.g. nix-test.lab.internal. Its first DNS label
# (nix-test) selects hosts/<name> and the flake configuration.

scripts := justfile_dir() + '/scripts'

[private]
default:
    just -l host

[arg('mode', pattern='switch|boot|test|dry-activate')]
[doc('Build on the host and activate it (ref: main | <branch/tag/sha> | local)')]
[group('host')]
deploy host mode='switch' ref='main':
    "{{ scripts }}/remote-rebuild.sh" "{{ host }}" "{{ mode }}" "{{ ref }}"

[doc('Show what a deploy would change in the closure, without activating')]
[group('host')]
diff host ref='main':
    "{{ scripts }}/remote-rebuild.sh" "{{ host }}" diff "{{ ref }}"

[doc('Trigger the GitOps reconcile now instead of waiting for the timer')]
[group('host')]
reconcile host:
    "{{ scripts }}/ssh.sh" -t "{{ host }}" sudo systemctl start --wait nixos-upgrade.service

[doc('Show the GitOps timer and the last reconcile logs')]
[group('host')]
status host:
    "{{ scripts }}/ssh.sh" "{{ host }}" 'systemctl list-timers nixos-upgrade.timer --no-pager; journalctl -u nixos-upgrade.service -n 30 --no-pager'

[doc('List system generations on the host')]
[group('host')]
generations host:
    "{{ scripts }}/ssh.sh" "{{ host }}" nixos-rebuild list-generations

[confirm("Roll back to the previous generation? [y/N]")]
[doc('Activate the previous generation (GitOps will re-apply main on its next run)')]
[group('host')]
rollback host:
    "{{ scripts }}/ssh.sh" -t "{{ host }}" sudo nixos-rebuild switch --rollback

[doc("Fetch the host's generated hardware-configuration.nix into the repo")]
[group('host')]
hardware host:
    "{{ scripts }}/ssh.sh" "{{ host }}" nixos-generate-config --show-hardware-config \
        > "{{ justfile_dir() }}/hosts/{{ replace_regex(host, '\..*', '') }}/hardware-configuration.nix"
    just log info "Wrote hardware config" file "hosts/{{ replace_regex(host, '\..*', '') }}/hardware-configuration.nix"

[confirm("Reboot the host? [y/N]")]
[doc('Reboot the host')]
[group('host')]
reboot host:
    "{{ scripts }}/ssh.sh" -t "{{ host }}" sudo systemctl reboot
