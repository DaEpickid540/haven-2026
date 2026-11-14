# Haven sync script: safely gets the latest code from GitHub.
#
# Double-click tools\sync.cmd (or run: powershell -ExecutionPolicy Bypass -File tools\sync.ps1)
#
# What it does, in order:
#   1. Waits for you to close Godot (Godot rewrites project files while open).
#   2. Stops if a merge/rebase is already half-done, and tells you how to finish or undo it.
#   3. Saves any uncommitted work (including new files) to a git stash.
#   4. Pulls your current branch from GitHub (rebasing your own commits on top).
#   5. If you're on a feature branch, offers to merge the latest main into it.
#   6. Puts your saved work back.
# It never pushes and never deletes your work. If anything goes wrong it stops
# and prints exactly what to do next.

param(
    [switch]$Yes,            # answer "yes" to the merge-main question without asking
    [switch]$SkipGodotCheck  # testing only
)

$ErrorActionPreference = 'Continue'

function Say([string]$msg, [string]$color = 'Cyan') { Write-Host $msg -ForegroundColor $color }
function Step([string]$msg) { Write-Host ""; Write-Host "==> $msg" -ForegroundColor Cyan }
function Fail([string]$msg) {
    Write-Host ""
    Write-Host "STOPPED: $msg" -ForegroundColor Red
    exit 1
}
function Git-Ok { & git @args | Out-Host; return ($LASTEXITCODE -eq 0) }

# --- Find the repo ---------------------------------------------------------
Set-Location (Join-Path $PSScriptRoot '..')
$root = (& git rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $root) { Fail "This folder isn't a git repository." }
Set-Location $root
$gitDir = (& git rev-parse --git-dir)
Say "Repo: $root" 'DarkGray'

# --- 1. Godot must be closed -----------------------------------------------
if (-not $SkipGodotCheck) {
    while (Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue) {
        Say "Godot is open. Save your scenes, close Godot, then press Enter." 'Yellow'
        [void](Read-Host)
    }
}

# --- 2. Nothing half-finished ----------------------------------------------
if ((Test-Path "$gitDir/rebase-merge") -or (Test-Path "$gitDir/rebase-apply")) {
    Fail ("A rebase is already in progress.`n" +
          "  Finish it:  fix the conflicted files, then run  git add <file>  and  git rebase --continue`n" +
          "  Or undo it: git rebase --abort")
}
if (Test-Path "$gitDir/MERGE_HEAD") {
    Fail ("A merge is already in progress.`n" +
          "  Finish it:  fix the conflicted files, then run  git add <file>  and  git commit --no-edit`n" +
          "  Or undo it: git merge --abort")
}
$unmerged = (& git diff --name-only --diff-filter=U)
if ($unmerged) {
    Fail ("These files still have conflict markers (<<<<<<<):`n  " + ($unmerged -join "`n  ") +
          "`n  Fix them, run  git add <file>, then run this script again.")
}

$branch = (& git rev-parse --abbrev-ref HEAD)
if ($branch -eq 'HEAD') { Fail "You're not on a branch (detached HEAD). Run:  git checkout main" }
Say "Branch: $branch" 'DarkGray'

# --- Fetch -----------------------------------------------------------------
Step "Downloading the latest from GitHub"
if (-not (Git-Ok fetch --prune origin)) {
    Fail "Couldn't reach GitHub. Check your internet / GitHub login and try again."
}

# --- 3. Save uncommitted work ----------------------------------------------
$stashed = $false
if (& git status --porcelain) {
    Step "Saving your uncommitted changes"
    $stashMsg = "sync-script backup $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    if (-not (Git-Ok stash push --include-untracked -m $stashMsg)) {
        Fail "Couldn't save your changes. Nothing was changed."
    }
    $stashed = $true
}

$restoreHint = ""
if ($stashed) { $restoreHint = "`n  Your uncommitted work is safe in the stash. After fixing this, run:  git stash pop" }

# --- 4. Pull this branch ---------------------------------------------------
& git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Step "Updating '$branch' from GitHub"
    if (-not (Git-Ok pull --rebase --no-autostash)) {
        Fail ("Your commits conflict with what's on GitHub.`n" +
              "  Fix it:  open the conflicted files (git status lists them), keep what you want,`n" +
              "           remove the <<<<<<< ======= >>>>>>> lines, then  git add <file>  and  git rebase --continue`n" +
              "  Undo it: git rebase --abort" + $restoreHint)
    }
} else {
    Say "'$branch' isn't on GitHub yet, so there's nothing to pull for it." 'DarkGray'
}

# --- 5. Feature branch: bring in main --------------------------------------
if ($branch -ne 'main') {
    # Keep the local main branch up to date too (only if that's a simple fast-forward).
    & git fetch origin main:main 2>$null | Out-Null

    $behind = [int](& git rev-list --count "HEAD..origin/main")
    if ($behind -gt 0) {
        $answer = 'y'
        if (-not $Yes) {
            $answer = Read-Host "main has $behind new commit(s) that '$branch' doesn't. Merge them in? (Y/n)"
        }
        if ($answer -eq '' -or $answer -match '^[yY]') {
            Step "Merging latest main into '$branch'"
            if (-not (Git-Ok merge --no-edit origin/main)) {
                Fail ("main conflicts with your branch.`n" +
                      "  Fix it:  open the conflicted files (git status lists them), keep what you want,`n" +
                      "           remove the <<<<<<< ======= >>>>>>> lines, then  git add <file>  and  git commit --no-edit`n" +
                      "  Undo it: git merge --abort" + $restoreHint)
            }
        }
    }
}

# --- 6. Restore uncommitted work -------------------------------------------
if ($stashed) {
    Step "Putting your uncommitted changes back"
    if (-not (Git-Ok stash pop)) {
        $conflicted = (& git diff --name-only --diff-filter=U) -join "`n    "
        Fail ("Your uncommitted changes conflict with the new code. They're still saved (git stash list).`n" +
              "  Conflicted files:`n    $conflicted`n" +
              "  Files with <<<<<<< markers need fixing by hand. When done:  git add <file>  then  git stash drop`n" +
              "  Or, to just take GitHub's version of a file:  git checkout HEAD -- <file>`n" +
              "  (Tip: if it's project.godot and you didn't mean to change it, take GitHub's version.)")
    }
}

# --- Done ------------------------------------------------------------------
Step "Done! Latest commits:"
& git log --oneline -5
Write-Host ""
& git status -sb
Write-Host ""
Say "You're up to date. You can open Godot again." 'Green'
