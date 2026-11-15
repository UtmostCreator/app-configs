# T1 spike: three facts the selection diff depends on

Run on the linux-desktop host, chezmoi v2.70.3, in scratch directories (a
scratch HOME with its own XDG dirs for chezmoi; a scratch flake for the lock
check). Nothing under the real home was written.

## 1. `chezmoi status` leaves the state database byte-identical

Scratch source with three files, applied once, then one source file edited, one
added and one target deleted by hand. `chezmoi --source=SRC status --no-tty
</dev/null` printed

    M .a
    DA .b
    A .c

and the sha256 and the mtime of chezmoistate.boltdb were identical before and
after (sha256 f707ef9f...). The column pair `DA` (X not blank, Y not blank) is
what the design classifies as a conflict.

## 2. `chezmoi status` while another chezmoi holds the database

An exclusive flock on the database file (the lock a writing chezmoi takes) made
`chezmoi status` fail after about 1 s with

    chezmoi: timeout obtaining persistent state lock, is another instance of chezmoi running?

exit 1. It neither blocks indefinitely nor reads a stale state, so the diff
treats it as "chezmoi source: unknown" (exit 11), not as "no changes". The
database was still byte-identical afterwards.

## 3. `--no-write-lock-file` keeps flake.lock untouched

A scratch flake with one unlocked path input and no flake.lock:

    nix eval --no-write-lock-file .#v   -> prints 1, no flake.lock created
    nix eval .#v                        -> prints 1, flake.lock created

So the flag is what stops a read-only eval from writing a lock file when the
committed one is stale. On the real repo with a current lock, the sha256 of
nix/flake.lock was identical before and after the evals below.

## 4. Eval time on this host (warm Nix eval cache cold, one run each)

| evaluation                                 | wall time |
| ------------------------------------------ | --------- |
| group members (committed default, 4 evals inside one expression) | 19.3 s |
| current state (the selection applied)      | 8.0 to 8.4 s |
| total of the two                           | about 27 s |

This is over the roughly 20 s the design allowed. Recorded as asked, work
continues; the members eval is the cost (it extends the host configuration five
times). Whether to trim it, cache it, or make it optional is the user's decision.
