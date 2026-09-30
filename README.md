# REDCap Error Reports

Dockerised R pipeline that pulls records from a REDCap project, runs data-quality
validation, and produces a CSV error report. Portable across projects: all
site-specific values live in `.env`, and the pipeline logic lives in `00-main.R`.

---

## What it does

1. Reads configuration from `.env` (secrets, endpoints, scope).
2. Pulls records from REDCap within a configurable date window and, optionally,
   for a specific hospital (or set of hospitals).
3. Runs two validation batches:
   - `validate_data_entry` — per-field validation (ranges, required fields, etc.).
   - `validate_data_in_branching_logic` — cross-field / groupwise validation
     (admission diagnoses, discharge diagnoses, treatment groups, etc.).
4. Writes `tmp/ErrorReport.csv` on the host.

The container is built from `rocker/r-ver:4.1.2`; R packages come from
`renv.lock` and are installed into a persistent Docker volume, so rebuilds
after the first one are fast.

---

## Prerequisites

- **Docker Engine** ≥ 20.10 — <https://docs.docker.com/engine/install/>
- **Docker Compose v2** — the `docker compose` command, not the old `docker-compose`
- **Git**
- ~4 GB free disk for the R package volume
- Network access to the REDCap server
- A REDCap **API token** for the project with export rights

Check your environment:

```bash
docker --version
docker compose version
git --version
```

`docker compose version` must report **v2.22 or newer** to use
`docker compose watch` (optional).

---

## Quick start

```bash
# 1. Clone
git clone <your-repo-url> error-reports
cd error-reports

# 2. Create .env from the template and fill in your values
cp .env.example .env
$EDITOR .env           # paste your REDCap token, API URL, hospital ID, etc.

# 3. Create the output directory
mkdir -p tmp

# 4. Build and run
docker compose up --build
```

The report lands at `./tmp/ErrorReport.csv`.

For subsequent runs, edit source files and rerun:

```bash
docker compose restart <service-name>
docker compose logs -f <service-name>
```

or use the wrapper script (see below).

---

## Configuration — `.env`

`.env` is **not committed** (it holds secrets). Copy `.env.example` and fill
in the real values.

### Required

| Variable | Description | Example |
|---|---|---|
| `GITHUB_PAT` | GitHub personal access token — needed only if `RedcapData` is a private repo. Leave blank if you use the public fork. | `ghp_xxxxxxxx` |
| `REDCAP_API_URL` | Base URL of the REDCap instance (no trailing `/api/` unless your version requires it) | `https://redcap.example.org/api/` |
| `REDCAP_API_TOKEN` | API token for the target project | `ABCDEF0123456789...` |

### Report scope

| Variable | Description | Default |
|---|---|---|
| `REPORT_INTERVAL` | Days back from today to include | `14` |
| `HOSP_TO_VALIDATE` | Comma-separated hospital IDs to restrict the pull. Blank = all hospitals | (blank) |

### REDCap field names

These are the internal field names in your REDCap project. Rename if the project
uses different ones.

| Variable | Description | Default |
|---|---|---|
| `ID_VAR` | Primary record identifier field | `id` |
| `DATE_VAR` | Date-of-entry field used for the date window | `date_today` |
| `HOSP_VAR` | Hospital identifier field | `hosp_id` |
| `SURROGATE_ID_VAR` | Surrogate patient identifier field | `ipno` |

### Fetch behaviour

| Variable | Description | Default |
|---|---|---|
| `LOCAL` | `true` if querying REDCap via a local MySQL database (rare); `false` to use the HTTP API | `false` |
| `CHUNKED` | Fetch records in chunks | `true` |
| `CHUNK_SIZE` | Records per chunk when `CHUNKED=true` | `200` |

### Container / runtime

| Variable | Description | Default |
|---|---|---|
| `R_WORKERS` | Number of parallel R workers. Keep at 2 for a 4 GB container | `2` |
| `UID` | Your host user ID — `id -u` | `1000` |
| `GID` | Your host group ID — `id -g` | `1000` |

`UID` / `GID` matter because the container writes the report into `./tmp/` on
the host, and by default Docker would write as root. Setting them ensures the
file is owned by you.

---

## Files you may need to edit

| File | What it holds |
|---|---|
| `00-main.R` | The pipeline. Usually you only edit this if your REDCap project needs different validation logic. |
| `custom.R` | Site-specific validation rules, loaded by the pipeline. |
| `exclude.R` | Field-name regex patterns excluded from validation. |
| `validation.R` | Helper functions used by `00-main.R`. |
| `upd.csv` | Records of field updates — used to suppress stale error reports. |
| `.env` | **Secrets and configuration.** Never commit. |

---

## Running the pipeline

### Via `docker compose`

```bash
docker compose up
```

Blocks until the R script finishes. Then check `./tmp/ErrorReport.csv`.

### Via the wrapper script

For non-technical users, `run-report.sh` runs the container and opens the
report in LibreOffice Calc automatically:

```bash
chmod +x run-report.sh
./run-report.sh
```

The first time, you may need to install a desktop launcher (see below).

### Development / hot reload

`00-main.R` and other source files are **bind-mounted**, so editing them on the
host takes effect immediately. After an edit:

```bash
docker compose restart <service-name>
```

Or, if you have Compose v2.22+, use watch mode and it reruns on save:

```bash
docker compose watch
```

### Interactive R session

Drop into a live R session inside the container:

```bash
docker compose run --rm <service-name> R
```

Then inside R:

```r
source("00-main.R")
```

Faster than a full restart for debugging.

---

## Adding a desktop launcher (optional)

For users who want to double-click an icon instead of using a terminal.

### 1. Create the `.desktop` file

Create `<project>-report.desktop` in the project root:

```ini
[Desktop Entry]
Version=1.0
Type=Application
Name=<Project> Error Report
GenericName=REDCap Data Validator
Comment=Run the data-quality validation and open the report
Exec=/absolute/path/to/project/run-report.sh
Path=/absolute/path/to/project
Icon=utilities-terminal
Terminal=true
Categories=Utility;Office;
StartupNotify=true
```

Replace `/absolute/path/to/project/` with the real path. `Exec=` must be an
absolute path — desktop entries do not expand `~` or `$HOME`.

### 2. Install it in the applications menu

```bash
mkdir -p ~/.local/share/applications
cp <project>-report.desktop ~/.local/share/applications/
chmod +x ~/.local/share/applications/<project>-report.desktop
update-desktop-database ~/.local/share/applications 2>/dev/null || true
```

Search the project name in your application launcher and click the icon.

### 3. (Optional) Put an icon on the GNOME desktop

On GNOME 42+ (Ubuntu 22.04 and later), copying a `.desktop` file to
`~/Desktop` is not enough — GNOME also requires you to mark it as trusted
before it will run.

```bash
# Copy the launcher to the Desktop
cp <project>-report.desktop ~/Desktop/
chmod +x ~/Desktop/<project>-report.desktop

# Mark it as trusted so GNOME will run it
gio set ~/Desktop/<project>-report.desktop metadata::trusted true
```

On some GNOME versions you also need to right-click the desktop icon once and
pick **Allow Launching**. After that, double-clicking the icon runs the
pipeline.

If you're on KDE, XFCE, or an older GNOME, simply copying the file to
`~/Desktop/` and making it executable is usually enough — no trusted flag
needed.

---

## Adapting this pipeline to a new REDCap project

1. **Clone** this repository to a new directory.
2. **Edit `.env`** — set the new REDCap URL, token, field names, and
   `HOSP_TO_VALIDATE` for the new project.
3. **Rename the service** in `docker-compose.yml` (e.g. `paeds-reports` →
   `adult-reports`) so the container has a distinct name.
4. **Update the pipeline** if the new project has different validation
   requirements: edit `custom.R` and `validation.R`, or `00-main.R` itself.
5. **Update `renv.lock`** if you add R packages:
   ```r
   renv::snapshot()
   ```
   on your dev machine, then rebuild the image.
6. **Rebuild**:
   ```bash
   docker compose down -v
   docker compose up --build
   ```

---

## Security — what not to commit

`.gitignore` excludes the following. Do not remove these rules:

- `.env` — secrets
- `tmp/` — report output (contains record IDs)
- `renv/library/` — local library with symlinks to `/home/...`
- `*.log` — logs may contain URLs with tokens
- `*.R~`, `old-*.R`, `*_00-main.R` — editor backups

Before every push, verify nothing sensitive is tracked:

```bash
git grep -nE "REDCAP_API_TOKEN=[A-Z0-9]|ghp_|github_pat_" || echo "OK: no secrets"
```

If a token ever appears in a commit, in a build log, or in a screenshot,
**rotate it immediately**:

- REDCap token → ask your REDCap administrator to regenerate it
- GitHub PAT → <https://github.com/settings/tokens>

Rotating and re-adding to `.env` is faster than trying to scrub history.

---

## Troubleshooting

### `REDCAP_API_TOKEN is not set`

`.env` is missing or empty. Verify:

```bash
grep REDCAP_API_TOKEN .env
docker compose run --rm <service-name> R -q -e 'Sys.getenv("REDCAP_API_TOKEN")'
```

### `dir.create(...) is not TRUE`

You're running an older version of `00-main.R`. The report location must be
constructed with `file.path()`, not `file_system_checks(..., create = TRUE)`:

```r
report_location <- file.path(path_to_files, "tmp", "ErrorReport.csv")
if (!dir.exists(dirname(report_location))) {
  dir.create(dirname(report_location), recursive = TRUE, showWarnings = FALSE)
}
```

### `Permission denied` writing to `tmp/`

The bind mount is owned by root (from a previous root-owned container run).
Fix from the host:

```bash
sudo chown -R "$USER:$USER" tmp
```

### `Error: object 'error_report1' not found`

The parallel branch in `00-main.R` assigns to `error_report`, but the later
code expects `error_report1`. Fix by renaming in the parallel block:

```r
error_report1 <- clusterApplyLB(...)
```

### `RedcapData is not installed in this image`

The build step that installs it failed. Rebuild with a valid `GITHUB_PAT`:

```bash
docker compose build --no-cache
```

### Build fails on `textshaping` / `ragg` / `pkgdown`

Missing system libraries. The Dockerfile must include:

```
libharfbuzz-dev libfribidi-dev
```

for `textshaping`. Add them and rebuild.

### Build fails on `waldo` / `testthat` / `devtools`

These are dev-only packages. Exclude them from `renv::restore()` in the
Dockerfile:

```r
exclude = c("devtools", "testthat", "waldo")
```

### Container exits with `exec format error` or similar

The `.dockerignore` is pulling in a `renv/library/` with broken symlinks to
`/home/<old-user>/...`. Make sure `.dockerignore` contains:

```
renv/library/
renv/staging/
renv/cache/
```

### Reset everything

```bash
docker compose down -v
docker compose up --build
```

`-v` removes the named volumes (`renv-library`, `renv-cache`) — you'll pay the
package install cost again, but anything else is preserved.

---

## Repository layout

```
.
├── 00-main.R                    # Pipeline entry point
├── custom.R                     # Site-specific validation rules
├── exclude.R                    # Field-name exclusion patterns
├── validation.R                 # Helper functions
├── upd.csv                      # Field-update rules
├── Dockerfile                   # Image definition
├── docker-compose.yml           # Runtime orchestration
├── run-report.sh                # Wrapper for non-technical users
├── <project>-report.desktop     # Optional desktop launcher
├── .env.example                 # Template — copy to .env
├── .env                         # Secrets (not committed)
├── .gitignore, .dockerignore
├── renv.lock                    # R package lockfile
├── README.md                    # This file
└── tmp/                         # Output directory (bind-mounted)
    └── ErrorReport.csv
```

---

## License

(Add a license here — MIT, Apache-2.0, or whatever fits your organisation.)

## Contact

(Add your contact email here before publishing.)