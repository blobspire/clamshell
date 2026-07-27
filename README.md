# clamshell

Keep a Mac awake with the lid closed, on battery — so long-running work survives
closing the laptop and putting it in a bag.

```
  clamshell — keeping this Mac awake with the lid closed

  ✓ lid-close sleep disabled    (pmset disablesleep 1)
  ✓ idle/system/disk sleep held (caffeinate pid 40871)
  ✓ auth: interactive (Touch ID or password), timestamp kept warm
  ✓ auto-restores sleep at 10% battery

  Press Ctrl-C to stop and restore normal sleep.
  Leave this window open — it is the only thing holding the lid awake.

  🔋 awake 00:14:32   battery 71%   used 16%, ~6:12 left · lid closed
```

## Why not `caffeinate`?

Because `caffeinate` does not work for this, and it fails silently.

`caffeinate` prevents **idle** sleep — the machine nodding off because you
stopped typing. Closing the lid is a different code path entirely, and
`caffeinate` has no effect on it. You can watch this yourself:

```console
$ caffeinate -dimsu &          # every flag it has
$ pmset -g assertions
   PreventUserIdleSystemSleep   ← idle only
   PreventUserIdleDisplaySleep  ← idle only
   PreventSystemSleep           ← AC only
```

None of those govern the lid. macOS normally permits lid-closed operation only
on AC power *with* an external display attached. The one setting that actually
lifts the restriction is `pmset disablesleep`, which requires root.

`clamshell` sets it, holds it while you watch, and clears it on exit.

## The safety problem this is built around

`pmset disablesleep 1` is **written to disk and survives reboots.** Set it and
forget it, and your Mac will never sleep again — rebooting won't save you:

```console
$ plutil -p /Library/Preferences/com.apple.PowerManagement.plist
  "SystemPowerSettings" => {
    "SleepDisabled" => 1        ← persisted
  }
```

That's why `clamshell` is a **foreground process** rather than a daemon or a
one-shot toggle. It holds your terminal on purpose. A visible window with a
ticking battery counter is the thing that makes you remember to stop it.

On exit — Ctrl-C, `SIGTERM`, `SIGHUP`, closing the terminal — it restores normal
sleep. All three signals are covered.

The one case it can't handle is `kill -9`, which no process can trap. If that
happens:

```console
$ clamshell --off
```

## Install

Requires macOS. No dependencies beyond what ships with the OS.

```console
$ git clone https://github.com/blobspire/clamshell.git
$ install -m 755 clamshell/clamshell ~/.local/bin/clamshell
```

Make sure `~/.local/bin` is on your `PATH`.

## Usage

```console
$ clamshell                    # run; Ctrl-C restores sleep
$ clamshell --status           # is sleep currently disabled?
$ clamshell --off              # recovery — restore sleep
```

| option | default | meaning |
|---|---|---|
| `--min-battery N` | `10` | restore sleep and exit at N% battery; `0` disables |
| `--interval N` | `5` | status refresh, seconds |
| `-h, --help` | | full help, including sudo setup |
| `-V, --version` | | print version |

### Low-battery auto-restore

By default, at 10% battery `clamshell` restores normal sleep and exits, letting
the Mac suspend cleanly instead of hard-dying at 0%. A normal sleep preserves
your work; a power loss does not. Disable with `--min-battery 0`.

## Authentication

Changing power settings needs `sudo`. To avoid typing a password every run,
pick one:

### Touch ID (recommended)

No standing grant — you authorize each invocation with a fingerprint.

```console
$ sudo cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local
$ sudo sed -i '' 's/^#auth/auth/' /etc/pam.d/sudo_local
```

`sudo_local` is Apple's supported hook and survives OS updates. Because
`pam_tid` is `sufficient` rather than `required`, a failed or unavailable
sensor falls through to your password — there's no way to lock yourself out.

Does **not** work inside `tmux`/`screen` without
[`pam_reattach`](https://github.com/fabianishere/pam_reattach).

### Passwordless sudoers rule

Scoped to two exact commands — not `pmset` generally, not root generally.

```console
$ printf '%s\n' "$(id -un) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0" > /tmp/cs
$ visudo -c -f /tmp/cs && sudo install -m 0440 -o root -g wheel /tmp/cs /etc/sudoers.d/clamshell
```

**Validate with `visudo -c` before installing.** A malformed file in
`/etc/sudoers.d/` makes `sudo` refuse to run at all.

Worst case if this rule is abused: your laptop declines to sleep. The argument
vector is fixed, so there's no privilege escalation path.

## What actually happens in your bag

Honest expectations, because the lid is the least of your problems:

- **Wi-Fi is what kills agents, not sleep.** Walk out of range and in-flight
  network requests fail. Tether to a phone hotspot if the work needs the
  network.
- **It runs at full power, not idle.** A sealed bag with no airflow means
  heat-soak and throttling. Expect a few hours of battery, not ten.
- **The display is not held on.** `clamshell` deliberately omits `caffeinate -d`,
  so the screen sleeps normally when the lid is open and the panel is off at the
  hardware level when it's shut.

## Development

```console
$ shellcheck clamshell     # must be clean; CI enforces it
```

`.shellcheckrc` enables the optional checks that catch real bugs and skips the
purely cosmetic ones (`SC2250` braces, `SC2292` bracket style).

Keep it **bash 3.2 compatible** — that's what `/bin/bash` is on macOS and always
will be. No associative arrays, no `${var^^}`, no `mapfile`.

Note that a clean ShellCheck run is a floor, not a ceiling. It catches quoting
and syntax traps; it cannot tell you whether the logic is right. The
`pipefail` + `grep -q` SIGPIPE bug that made lid detection silently report "no
lid" on a MacBook passed lint without complaint.

## License

MIT
