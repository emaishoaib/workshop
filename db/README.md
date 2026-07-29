# db/

Generic Docker/Alembic database tooling: `ddb` (connect to a project DB across
environments) and `dmig` (walk and navigate an Alembic migration chain,
including offering to generate a migration for uncommitted model changes).

## `db-tools.zsh`

Version controlled. Deliberately has no employer- or project-specific
defaults baked in — every value it needs comes from a required `.dbtoolsrc`
file in whatever project directory you run `ddb`/`dmig` from, and every
remote-environment action is delegated to hook functions it calls but does
not define (see `local.zsh` below). If either is missing, the function
fails with an error telling you what's missing, rather than guessing.

### Required `.dbtoolsrc` variables

Create a `.dbtoolsrc` in the root of each project repo you use this tooling
in (it's project-specific, so it lives in that project, not here). It'll
contain values specific to that project/employer, so it should never be
committed — `setup.sh` handles this for you: it configures
`core.excludesfile` (creating `~/.gitignore_global` if you don't already
have one set) and adds `.dbtoolsrc` to it, so it's ignored in every repo on
the machine, regardless of that repo's own `.gitignore`.

| Variable | Used by | Meaning |
|---|---|---|
| `DB_NAME` | `ddb dev`, `dmig` | Local Postgres database name |
| `DB_USER` | `ddb dev`, `dmig` | Local Postgres user |
| `MIGRATIONS_DIR` | `dmig` | Path (relative to repo root) to the Alembic `versions/` directory |
| `DMIG_ALEMBIC_CMD` | `dmig` | Full command prefix that runs alembic for this project, e.g. `dcli b alembic` — `dmig` appends a subcommand (`check`, `upgrade <rev>`, etc.) and word-splits this value, so a multi-word override works |
| `DB_ENV_PREFIX` | `dmig -stg` only | Prefix used to build the env var names (`<PREFIX>_DB_HOST`, `<PREFIX>_DB_PASSWORD`) passed into the container when migrating against staging |
| `DB_PROXY_NETWORK` | `dmig -stg` only | Docker network the staging DB proxy container is reachable on |

### Required hook functions

Define these yourself, in a file that is **not** checked into this repo
(see `local.zsh`), and make sure it's sourced alongside `db-tools.zsh`:

- **`_dbtools_remote_connect <env> [--write]`** — open an interactive
  `psql` session against the named remote environment (`stg`, `prod`).
  `--write` is only ever passed for `prod`.
- **`_dbtools_remote_proxy_start <env> <pw_var_name>`** — stand up
  whatever's needed to reach `<env>`'s DB from this machine (a Cloud SQL
  Auth Proxy, an SSH tunnel, whatever fits), pull the DB password for it,
  and echo exactly one line: `<container_name> <password>`. Print your own
  errors and return non-zero on failure — `dmig` just checks for empty
  output.

## `local.zsh`

Gitignored. This is where the *actual* implementation of the two hook
functions above lives — tied to a specific employer's internal tooling,
so it's deliberately kept out of this repo. `init.zsh` sources it only if
the file exists, so a fresh clone of this repo works fine without it
(`ddb`/`dmig` just won't have anything to call for `stg`/`prod`/`-stg`
until you add your own).
