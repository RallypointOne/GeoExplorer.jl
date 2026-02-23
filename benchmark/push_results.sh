#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_FILE="$SCRIPT_DIR/results.json"
WORKTREE_DIR="$REPO_ROOT/.benchmark-worktree"
BRANCH="benchmark-results"

if [ ! -f "$RESULTS_FILE" ]; then
    echo "Error: $RESULTS_FILE not found. Run benchmarks first:"
    echo "  julia --project=benchmark benchmark/run.jl"
    exit 1
fi

# Clean up any leftover worktree
if [ -d "$WORKTREE_DIR" ]; then
    git -C "$REPO_ROOT" worktree remove --force "$WORKTREE_DIR" 2>/dev/null || rm -rf "$WORKTREE_DIR"
fi

# Ensure the branch exists on the remote (or create an orphan locally)
if git -C "$REPO_ROOT" ls-remote --exit-code origin "$BRANCH" >/dev/null 2>&1; then
    git -C "$REPO_ROOT" fetch origin "$BRANCH"
    git -C "$REPO_ROOT" worktree add "$WORKTREE_DIR" "origin/$BRANCH"
    git -C "$WORKTREE_DIR" checkout -B "$BRANCH" "origin/$BRANCH"
else
    git -C "$REPO_ROOT" worktree add --orphan "$WORKTREE_DIR" -b "$BRANCH"
fi

# Copy results and commit
cp "$RESULTS_FILE" "$WORKTREE_DIR/results.json"
cd "$WORKTREE_DIR"
git add results.json
if git diff --cached --quiet; then
    echo "No changes to benchmark results."
else
    git commit -m "Update benchmark results ($(date -u +'%Y-%m-%d %H:%M UTC'))"
    git push origin "$BRANCH"
    echo "Benchmark results pushed to $BRANCH branch."
fi

# Clean up worktree
cd "$REPO_ROOT"
git worktree remove --force "$WORKTREE_DIR"
