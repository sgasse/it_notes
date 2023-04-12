# Git

```bash
# Show different commits between two branches
git log --left-right --graph --cherry-mark --oneline main...other_branch
```

```bash
# Push `origin/main` to `origin/other_branch`
git push origin origin/main:other_branch
```

```bash
# "Undo" git changes

# Inspect reflog to find state that you want to go back to
git reflog

# Go back to state one ref change ago (e.g. before a wrong `commit --amend`)
git reset --hard 'HEAD@{1}'
```
