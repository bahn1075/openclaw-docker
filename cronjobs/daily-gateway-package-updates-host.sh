#!/usr/bin/env bash
set -u

overall_rc=0

section() {
  printf '\n### %s\n' "$1"
}

run_dnf_update() {
  section "dnf update -y"

  local tmp
  tmp="$(mktemp)"

  sudo dnf update -y >"$tmp" 2>&1
  local rc=$?

  if [ "$rc" -eq 0 ]; then
    # dnf runs RPM scriptlets as root from the OpenClaw host chroot. Some
    # Docker/nginx scriptlets try root systemctl and emit this harmless bus
    # warning even though the transaction succeeds. Keep reports actionable by
    # filtering only this exact known line on successful transactions.
    grep -F -v "Failed to connect to bus: No data available" "$tmp" || true
  else
    cat "$tmp"
  fi

  rm -f "$tmp"
  printf 'dnf exit code: %s\n' "$rc"

  if [ "$rc" -ne 0 ]; then
    overall_rc=1
  fi
}

check_services() {
  section "post-dnf service check"

  systemctl is-active docker nginx
  local rc=$?
  printf 'service check exit code: %s\n' "$rc"

  if [ "$rc" -ne 0 ]; then
    overall_rc=1
  fi
}

run_brew_upgrade() {
  section "brew upgrade"

  /home/linuxbrew/.linuxbrew/bin/brew upgrade
  local rc=$?
  printf 'brew exit code: %s\n' "$rc"

  if [ "$rc" -ne 0 ]; then
    overall_rc=1
  fi
}

run_dnf_update
check_services
run_brew_upgrade

exit "$overall_rc"
