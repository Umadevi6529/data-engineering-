# Git Workflow for Data Engineers 🌿

## Why Git Matters in DE

Every pipeline, every script, every SQL query you write should be in Git.
Here's why:

- **Reproducibility**: If your pipeline broke last week, Git lets you see exactly
  what changed. `git diff HEAD~1` shows you.
- **Collaboration**: 5 DEs working on the same pipeline without Git = chaos.
- **CI/CD**: GitHub Actions can automatically test your pipeline on every commit.
- **Rollback**: Deployed bad code? `git revert` undoes it without deleting history.

---

## The Commit Message Convention

In DE teams, we follow **Conventional Commits**:

```
<type>(<scope>): <description>

Types:
  feat:     New feature (new pipeline, new table)
  fix:      Bug fix (null handling, wrong join)
  refactor: Code restructure (no behavior change)
  docs:     Documentation only
  test:     Adding tests
  chore:    Tooling, config changes

Examples:
  feat(etl): add customer dimension table loader
  fix(sql): handle null customer_id in orders join
  docs(phase-01): add Git workflow notes
  test(validator): add null check unit tests
```

---

## The DE Branching Strategy

```
main          ← Always stable. Deploys to production.
  │
  ├── develop ← Integration branch. Deploys to staging.
  │     │
  │     ├── feature/add-kafka-consumer
  │     ├── feature/fix-null-handling
  │     └── hotfix/order-count-bug
```

### Daily Workflow
```bash
# 1. Always start from up-to-date main
git checkout main
git pull origin main

# 2. Create a feature branch
git checkout -b feature/phase-01-csv-processor

# 3. Work, then commit often (small commits = easier reviews)
git add processor.py
git commit -m "feat(phase-01): add deduplication logic"

git add validator.py
git commit -m "feat(phase-01): add null and type validation"

# 4. Push your branch
git push origin feature/phase-01-csv-processor

# 5. Open a Pull Request on GitHub → get review → merge to main
```

---

## Key Commands Reference

```bash
# Setup
git config --global user.name "Your Name"
git config --global user.email "you@email.com"

# Inspection
git status          # What's changed?
git log --oneline   # Compact history
git diff            # See exact changes
git blame file.py   # Who wrote which line?

# Staging & Committing
git add file.py           # Stage one file
git add .                 # Stage all changes
git commit -m "message"   # Commit
git commit --amend        # Edit last commit (before push!)

# Branching
git branch                # List branches
git checkout -b feat/x    # Create + switch
git merge feat/x          # Merge into current branch
git branch -d feat/x      # Delete branch

# Remote
git remote add origin <url>
git push origin main
git pull origin main
git fetch                 # Download without merging

# Undoing
git restore file.py       # Discard working tree changes
git reset HEAD file.py    # Unstage
git revert <commit-hash>  # Safe undo (creates new commit)

# Stashing (save work without committing)
git stash           # Save dirty state
git stash pop       # Restore it
```

---

## merge vs rebase — The Eternal Debate

```
MERGE (safe, preserves history):
  main:    A ── B ── C ────────── M (merge commit)
  feature: A ── B ── D ── E ──┘

REBASE (clean history, rewrites commits):
  main:    A ── B ── C ── D' ── E' (replayed on top)
  (feature branch disappears — history is linear)

Rule of thumb for DE teams:
  - Use MERGE for shared/public branches (main, develop)
  - Use REBASE for local cleanup before opening a PR
  - NEVER rebase a branch others are working on!
```

---

## .gitignore for DE Projects

Always ignore:
- `*.env` — API keys, passwords (use environment variables instead)
- `*.log` — Log files (too large, not useful in history)
- `__pycache__/` — Python bytecode (auto-generated)
- `venv/` — Virtual environment (reproducible via requirements.txt)
- `*.csv` — Large data files (use Git LFS or store in S3)
- `target/` — dbt compiled files (auto-generated)
- `airflow.db` — SQLite DB for local Airflow

---

## GitHub Actions for DE (Preview — Phase 9)

```yaml
# .github/workflows/test.yml
name: Test Pipeline
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - name: Install deps
        run: pip install -r requirements.txt
      - name: Run tests
        run: python -m pytest
```

This runs your tests automatically on every commit!
