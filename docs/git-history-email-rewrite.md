# Git history email rewrite (approval-gated, destructive)

Personal author/committer emails appear in the **commit history** (not just
working-tree files). Removing them rewrites every commit SHA from the first
affected commit onward, which **invalidates open PRs and requires a
force-push**. This is intentionally **not** run by any agent or bootstrap
script. Run it yourself, deliberately, after the conditions below are met.

> Working-tree **file** content was already scrubbed (see
> `docs/migration-followups.md`). This document covers only the **history**
> rewrite of commit-author metadata.

## What is in history

Two personal identities appear as author/committer in `git log`
(values intentionally not repeated here):

- a personal `@gmail.com` address, and
- a `@rabbies.com` work address.

Confirm the current set on your machine before rewriting:

```bash
git log --format='%an <%ae> | %cn <%ce>' | sort -u
```

## Preconditions (all must hold)

1. No open PR depends on the current SHAs, **or** every collaborator has
   agreed to re-clone/reset after the force-push.
2. Clean worktree: `git status` shows nothing to commit.
3. A backup exists: `git branch backup/pre-email-rewrite` and/or
   `git bundle create ../app-configs-backup.bundle --all`.
4. `git-filter-repo` is installed (`nix shell nixpkgs#git-filter-repo`).

## Procedure (mailmap approach — safest, reviewable)

1. Create a `.mailmap` that maps the old identities to the GitHub noreply
   address (already used by some commits — `…@users.noreply.github.com`):

   ```
   # .mailmap  (Proper Name <canonical@users.noreply.github.com> <old@email>)
   UtmostCreator <22347676+UtmostCreator@users.noreply.github.com> <PERSONAL_GMAIL>
   UtmostCreator <22347676+UtmostCreator@users.noreply.github.com> <WORK_EMAIL>
   ```

   Replace `PERSONAL_GMAIL` / `WORK_EMAIL` with the real values from the
   `git log` command above. Keep this `.mailmap` out of the final history if
   you do not want the old values recorded — pass it via `--mailmap` from a
   path outside the repo.

2. Dry-run the analysis (no rewrite):

   ```bash
   git filter-repo --mailmap /path/outside/repo/.mailmap --dry-run
   ```

3. Run the rewrite (rewrites all SHAs):

   ```bash
   git filter-repo --mailmap /path/outside/repo/.mailmap
   ```

   `git-filter-repo` removes the `origin` remote by design after a rewrite.

4. Verify no personal emails remain:

   ```bash
   git log --format='%ae %ce' | sort -u | grep -iE 'gmail|rabbies' && echo "STILL PRESENT" || echo "clean"
   ```

5. Re-add the remote and force-push (coordinate first):

   ```bash
   git remote add origin git@github.com:UtmostCreator/app-configs.git
   git push --force-with-lease --all origin
   git push --force-with-lease --tags origin
   ```

## Rollback

- Restore from the backup branch: `git reset --hard backup/pre-email-rewrite`.
- Or from the bundle: `git clone ../app-configs-backup.bundle restored`.

## Prevent recurrence

Set your repo-local identity to the noreply address so new commits never
leak a personal email:

```bash
git config user.name  "UtmostCreator"
git config user.email "22347676+UtmostCreator@users.noreply.github.com"
```
