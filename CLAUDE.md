# Working on Haulwise

## Releases: one CurseForge upload a day
- Commits go to `main` (and onto the owner's PC to try) as before. Committing doesn't release
  anything: the daily *Community data* workflow makes the day's one upload.
- That upload is new code only when `GP.VERSION` in `Core.lua` has no tag yet; otherwise it's the
  last released code (the newest `v<version>` tag) with the day's data. So never bump the version
  before the owner says "push": the bump is the go-ahead.
- When the owner says "push": bump `GP.VERSION`, update `CHANGELOG.md`, the guide's news
  (`Guide.lua`) and `docs/CURSEFORGE.md`, and send CURSEFORGE.md to the owner to paste in
  (CurseForge's API can't change the description). The "New in" line at the top only covers that
  release; older versions are in the changelog. The code goes out, tested, with the next daily
  upload (scheduled 04:37 UTC; GitHub often runs it hours later).
- Urgent fixes the owner wants out now: bump the version and run the *Release* workflow by hand
  (`gh api -X POST repos/KaayceeGamer/haulwise/actions/workflows/release.yml/dispatches -f ref=main`).
  That day's data upload then waits, so there's still only one upload a day.
