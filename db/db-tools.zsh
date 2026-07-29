# Generic Docker/Alembic DB tooling — reusable across any dockerized project
# with a `docker compose` db service and (optionally) Alembic migrations.
# Nothing project- or employer-specific lives in this file:
#
# - Per-project values (DB name/user, migrations dir, how alembic gets
#   invoked, etc.) come from a required `.dbtoolsrc` in the current
#   directory — see README.md in this directory for the full variable
#   list. There are no guessed defaults: if a value this tooling needs
#   isn't set, the function fails loudly rather than falling back to a
#   guess that might be wrong for this repo.
# - Anything that talks to a specific remote-environment tool (how you
#   open a session against staging/prod, how you stand up a proxy to one)
#   is delegated to `_dbtools_remote_connect` / `_dbtools_remote_proxy_start`
#   — hook functions this file calls but does not define. Define them
#   yourself in a separate file that isn't checked in (see README.md).

# Sources ./.dbtoolsrc into the caller's scope. Hard-fails if the file
# isn't there — every value this tooling needs is project-specific and
# must be spelled out explicitly, not guessed from the directory name.
_dbtools_require_config() {
  local config_file="${DBTOOLS_CONFIG_FILE:-.dbtoolsrc}"
  if [ ! -f "$config_file" ]; then
    echo "No $config_file in $(pwd) — see db/README.md for the required variables." >&2
    return 1
  fi
  source "$config_file"
}

# Run a CLI command inside the app/app-ui container
# dcli b ...  -> backend (app)
# dcli f ...  -> frontend (app-ui)
dcli() {
  local target="$1"; shift
  case "$target" in
    b) docker compose run --rm app bin/cli "$@" ;;
    f) docker compose run --rm app-ui bin/cli "$@" ;;
    *) echo "Usage: dcli <b|f> [args...]" ;;
  esac
}

# Connect to project databases across environments
# ddb dev          -> psql into the local docker-compose db (fzf if repo has more than one db-like service)
# ddb stg          -> psql into staging via the configured remote-connect hook
# ddb prod         -> psql into prod, read-only
# ddb prod --write -> psql into prod, read-write, behind a confirmation prompt
ddb() {
  local env="$1"; shift

  case "$env" in
    dev)
      local DB_NAME DB_USER
      _dbtools_require_config || return 1
      local db_name="${DB_NAME:?DB_NAME not set in .dbtoolsrc — see db/README.md}"
      local db_user="${DB_USER:?DB_USER not set in .dbtoolsrc — see db/README.md}"

      local services count service
      services=$(docker compose config --services 2>/dev/null | grep -i db)
      count=$(echo "$services" | grep -c .)
      if [ "$count" -le 1 ]; then
        service="$services"
      else
        service=$(echo "$services" | fzf --prompt="DB service > " --header="Multiple db services found")
      fi
      if [ -z "$service" ]; then
        echo "No db service found/selected."
        return 1
      fi
      docker compose exec "$service" psql -U "$db_user" -d "$db_name"
      ;;
    stg)
      _dbtools_remote_connect stg "$@"
      ;;
    prod)
      if [ "$1" = "--write" ]; then
        echo -n "This opens a WRITE session against PRODUCTION. Continue? [y/N] "
        read -r answer
        if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
          _dbtools_remote_connect prod --write
        else
          echo "Aborted."
        fi
      else
        _dbtools_remote_connect prod
      fi
      ;;
    *)
      echo "Usage: ddb <dev|stg|prod> [--write]"
      ;;
  esac
}

# Finds an alembic migration file matching <revision> (full or short hash)
# anywhere in git history (every branch/commit, no checkout needed) and
# writes it into <versions_dir> as an untracked file if it isn't there
# already. Echoes the restored (or already-present) path on success;
# returns 1 and prints nothing on failure. Pure "find it and put it there"
# — no messaging, no bookkeeping; `dmig` below builds on this.
#
# Prints "<path> fresh" if it had to write the file itself, or "<path>
# existing" if the file was already there (already restored earlier, or a
# real committed file) — callers use that to decide whether it's theirs to
# delete later. Never delete a path marked "existing".
_dmig_fetch_migration() {
  local rev="$1"
  local versions_dir="$2"
  # NOTE: don't name this "path" — it's a special zsh parameter tied to
  # $PATH, and a plain `local path` shadows it, breaking command lookup
  # (docker/grep/head all report "command not found") for the rest of this
  # function's scope, including subshells it spawns.

  # Search file CONTENTS, not filenames. Migration filenames only embed a
  # short ~6-char slug of the revision hash by convention (e.g.
  # "..._9a6cfd_add_smoothing_rule.py" for "9a6cfd048d77"), but alembic's
  # own error message always reports the FULL hash — a 12-char id will
  # never appear as a substring of a 6-char filename fragment, so matching
  # against filenames silently fails for anything but a short prefix.
  # Pickaxe (-G) for the actual `revision = "<hash>"` line instead: exact,
  # and works whether $rev is the full hash or a short prefix of it.
  local commit
  commit=$(git log --all --format=%H -G"revision = \"${rev}" -- "${versions_dir}/*.py" | tail -1)

  if [ -z "$commit" ]; then
    # Not reachable from any branch/tag either — check dangling commits
    # too. A commit can still be sitting in git's local object store even
    # with nothing pointing at it anymore (e.g. a force-push to a shared
    # branch that got overwritten, or a local reset/rebase that abandoned
    # it). `git log --all` can never see these; `git fsck --unreachable`
    # is what actually finds them.
    commit=$(git fsck --unreachable --no-reflogs 2>/dev/null \
      | awk '/unreachable commit/{print $3}' \
      | xargs -I{} git grep -l "revision = \"${rev}" {} -- "${versions_dir}/*.py" 2>/dev/null \
      | head -1 | cut -d: -f1)
  fi

  [ -z "$commit" ] && return 1

  # Grep the commit's own tree directly for the file containing the
  # matching revision line, rather than just listing every file the commit
  # touched — a single commit can add the file we want *and* modify/delete
  # unrelated files under versions_dir in the same diff (e.g. one commit
  # both replacing an old migration and adding its replacement), and
  # blindly taking the first touched file can grab the wrong one.
  local mig_path
  mig_path=$(git grep -l "revision = \"${rev}" "$commit" -- "${versions_dir}/*.py" 2>/dev/null | head -1 | cut -d: -f2)
  [ -z "$mig_path" ] && return 1

  if [ -e "$mig_path" ]; then
    echo "$mig_path existing"
    return 0
  fi

  if ! git show "${commit}:${mig_path}" > "$mig_path" 2>/dev/null || [ ! -s "$mig_path" ]; then
    rm -f "$mig_path"
    return 1
  fi
  echo "$mig_path fresh"
}

# Parses a migration file's `revision` and `down_revision` fields. Echoes
# "revision|down_revision" (down_revision empty string means base/None).
_dmig_parse_migration_file() {
  local f="$1" f_rev f_down
  f_rev=$(grep -E '^revision' "$f" | head -1 | sed -E 's/^revision *= *"([^"]*)".*/\1/')
  f_down=$(grep -E '^down_revision' "$f" | head -1)
  if echo "$f_down" | grep -q 'None'; then
    f_down=""
  else
    f_down=$(echo "$f_down" | sed -E 's/^down_revision *= *"([^"]*)".*/\1/')
  fi
  echo "${f_rev}|${f_down}"
}

# Builds a down_revision -> "revision|path" map for every local migration
# file under <versions_dir>, so "what comes after revision X" is a lookup
# instead of a re-scan. Echoes one "<down_revision> <revision>|<path>" pair
# per line — migrations with no down_revision (the base) are skipped since
# nothing can be "after" them via this map.
_dmig_build_children_map() {
  local versions_dir="$1"
  local f f_parsed f_rev f_down
  for f in "${versions_dir}"/*.py(N); do
    [ -e "$f" ] || continue
    f_parsed=$(_dmig_parse_migration_file "$f")
    f_rev="${f_parsed%%|*}"
    f_down="${f_parsed#*|}"
    [ -n "$f_down" ] && echo "$f_down $f_rev|$f"
  done
}

# Alembic helper — local by default, or against STAGING with -stg/--stg.
#
# What it does, in order:
# 1. Connects to the target DB and reads its actual current revision
#    directly out of alembic_version via raw SQL — never via `alembic
#    current`, so this step can never hit a script-resolution error.
#    - local (default): `docker compose exec` into the local db service.
#    - -stg/--stg: asks the configured `_dbtools_remote_proxy_start` hook
#      to stand up a proxy and hand back its container name + password,
#      then queries through a throwaway postgres client container over
#      that proxy.
# 2. Walks the migration chain BACKWARD from that revision, one
#    down_revision link at a time, all the way to the base. For each
#    revision: if its file is already present locally, use it as-is; if
#    not, restore it from git history via `_dmig_fetch_migration` — this
#    can happen for the current revision itself, or for any link further
#    back, however many times it takes. Prints what it's doing at each
#    step, since this search can take a moment.
# 3. Local mode only: if current_rev has no pending local migration ahead
#    of it yet (i.e. the DB is already at the local tip), checks whether
#    your models have changes that aren't captured in any migration yet
#    (via the configured alembic command's `check` subcommand). If they
#    do, asks whether to create one now and, if so, prompts for a
#    migration name and runs `<alembic> revision --autogenerate`. Skipped
#    (with a warning) when a pending local migration already exists — the
#    check diffs your live DB against your models, not against the
#    migration graph, so running it while a migration is still un-applied
#    would tangle "not yet upgraded" noise together with any real new
#    changes.
# 4. Walks FORWARD from current too, by scanning local migration files for
#    whichever one's down_revision points at current, then whichever one
#    points at that, and so on — this surfaces migrations you've written
#    locally but not pushed/applied yet (including one just created in
#    step 3). Forward migrations are only ever looked for locally
#    (there's nothing to restore from git for a migration nobody's pushed
#    anywhere).
# 5. Shows the full chain in chronological order (oldest at top, most
#    recent at the bottom — which may now be a local-only migration, not
#    necessarily "current"), marking restored entries `[RESTORED]`, a
#    migration just created in step 3 `[NEW, JUST CREATED]`, and the DB's
#    actual position `(CURRENT)`. Lets you pick any revision to land on
#    via fzf.
# 6. Depending on whether the pick is before or after current in the
#    chain, runs `alembic downgrade` or `alembic upgrade` accordingly
#    (against the proxy, in -stg mode). Picking current itself is a no-op.
# 7. Deletes every file it restored, and (in -stg mode) tears down the
#    proxy container, regardless of what happened above.
#
# Usage: dmig [-stg|--stg]
dmig() {
  local env_mode="local"
  case "${1:-}" in
    -stg|--stg)
      env_mode="stg"
      shift
      ;;
  esac

  local DB_NAME DB_USER DB_ENV_PREFIX MIGRATIONS_DIR DMIG_ALEMBIC_CMD DB_PROXY_NETWORK
  _dbtools_require_config || return 1

  local versions_dir="${MIGRATIONS_DIR:?MIGRATIONS_DIR not set in .dbtoolsrc — see db/README.md}"
  local alembic_cmd="${DMIG_ALEMBIC_CMD:?DMIG_ALEMBIC_CMD not set in .dbtoolsrc — see db/README.md}"
  local db_name="${DB_NAME:?DB_NAME not set in .dbtoolsrc — see db/README.md}"
  local db_user="${DB_USER:?DB_USER not set in .dbtoolsrc — see db/README.md}"
  local repo_name
  repo_name="${PWD:t}"

  local proxy_name pw host_var pw_var env_prefix

  if [ "$env_mode" = "stg" ]; then
    env_prefix="$(echo "${DB_ENV_PREFIX:?DB_ENV_PREFIX not set in .dbtoolsrc — see db/README.md}" | tr a-z A-Z)"
    host_var="${env_prefix}_DB_HOST"
    pw_var="${env_prefix}_DB_PASSWORD"

    echo "Starting stg DB proxy for $repo_name..."
    local proxy_result
    proxy_result=$(_dbtools_remote_proxy_start stg "$pw_var")
    if [ -z "$proxy_result" ]; then
      echo "Couldn't start a stg DB proxy — aborting."
      return 1
    fi
    proxy_name="${proxy_result%% *}"
    pw="${proxy_result#* }"
  fi

  echo "Reading current revision directly from the ${env_mode} DB (alembic_version)..."
  local current_rev
  if [ "$env_mode" = "stg" ]; then
    local proxy_network="${DB_PROXY_NETWORK:?DB_PROXY_NETWORK not set in .dbtoolsrc — see db/README.md}"
    current_rev=$(docker run --rm --network="$proxy_network" postgres:16 \
      psql "postgresql://${db_user}:${pw}@${proxy_name}:5432/${db_name}" -t -A \
      -c "select version_num from alembic_version;" 2>/dev/null | tr -d '[:space:]')
  else
    local service
    service=$(docker compose config --services 2>/dev/null | grep -i db | head -1)
    if [ -z "$service" ]; then
      echo "Couldn't find a db service in docker-compose.yaml."
      return 1
    fi
    current_rev=$(docker compose exec -T "$service" psql -U "$db_user" -d "$db_name" -t -A \
      -c "select version_num from alembic_version;" 2>/dev/null | tr -d '[:space:]')
  fi
  if [ -z "$current_rev" ]; then
    echo "Couldn't read a current revision from alembic_version — is the ${env_mode} DB reachable and migrated?"
    [ "$env_mode" = "stg" ] && docker kill "$proxy_name" >/dev/null 2>&1
    return 1
  fi
  echo "Current revision: $current_rev"

  local -a chain_lines chain_revs restored_paths
  local rev="$current_rev" mig_path mig_state down_rev message marker parsed iterations=0

  # --- Phase 1: walk backward from current to the base ---
  while [ -n "$rev" ]; do
    iterations=$((iterations + 1))
    if [ "$iterations" -gt 500 ]; then
      echo "Chain walk exceeded 500 steps — stopping (likely a cycle or a parsing bug)."
      break
    fi

    mig_path=$(grep -lE "^revision *= *\"${rev}\"" "${versions_dir}"/*.py 2>/dev/null | head -1)
    if [ -n "$mig_path" ]; then
      mig_state="local"
    else
      echo "$rev isn't in your local migration files — attempting to restore it from git history..."
      local fetch_result
      fetch_result=$(_dmig_fetch_migration "$rev" "$versions_dir")
      if [ -z "$fetch_result" ]; then
        echo "Couldn't find $rev anywhere — not locally, not in git history. Chain broken here."
        chain_lines=("!! chain broken: revision $rev not found locally or anywhere in git history" "${chain_lines[@]}")
        break
      fi
      mig_path="${fetch_result% *}"
      mig_state="${fetch_result##* }"
      if [ "$mig_state" = "fresh" ]; then
        echo "Restored $rev -> $mig_path"
        mig_state="restored"
        restored_paths+=("$mig_path")
      else
        echo "$rev found on disk already (untracked leftover, most likely) — using it as-is."
        mig_state="local"
      fi
    fi

    parsed=$(_dmig_parse_migration_file "$mig_path")
    down_rev="${parsed#*|}"
    message=$(head -1 "$mig_path" | sed 's/^"""//')

    marker=""
    [ "$rev" = "$current_rev" ] && marker="$marker (CURRENT)"
    [ "$mig_state" = "restored" ] && marker="$marker [RESTORED]"
    chain_lines=("${down_rev:-<base>} -> $rev, $message$marker" "${chain_lines[@]}")
    chain_revs=("$rev" "${chain_revs[@]}")

    rev="$down_rev"
  done

  local current_index=${#chain_revs[@]}

  # Build a down_revision -> child map once, so "what comes after X" is a
  # lookup instead of a re-scan. Used both by the model-change check below
  # (to tell whether current_rev already has a pending forward migration)
  # and by Phase 2's forward walk further down.
  local -A children_of
  local down_rev_key rest_val
  while IFS=' ' read -r down_rev_key rest_val; do
    children_of[$down_rev_key]="$rest_val"
  done < <(_dmig_build_children_map "$versions_dir")

  # --- Offer to create a migration for uncaptured model changes ---
  # Local mode only: autogenerating against stg doesn't fit the workflow
  # (migrations get written locally, then applied elsewhere via -stg).
  # Only runs when current_rev is at the local tip — see the comment on
  # step 3 above for why a pending forward migration disqualifies this.
  local new_migration_path=""
  if [ "$env_mode" = "local" ]; then
    if [ -n "${children_of[$current_rev]:-}" ]; then
      echo "Skipping the model-change check: you already have an unapplied local migration ahead of $current_rev — upgrade to tip first for a clean diff."
    else
      echo "Checking for model changes not yet captured in a migration..."
      local check_output check_status
      check_output=$(${=alembic_cmd} check 2>&1)
      check_status=$?
      if [ "$check_status" -eq 0 ]; then
        : # no changes detected
      elif ! echo "$check_output" | grep -q "New upgrade operations detected"; then
        # A non-zero exit here doesn't necessarily mean alembic found a real
        # diff — `alembic check` also exits non-zero if it couldn't even
        # run (e.g. a broken container/venv), which looks identical unless
        # we check for alembic's actual diff-found message. Treat anything
        # else as "couldn't run the check cleanly" and skip rather than
        # risk a false positive.
        echo "Skipping the model-change check: 'alembic check' didn't report a clear result — run '${alembic_cmd} check' yourself to see why."
      else
        echo -n "Model changes detected that aren't in a migration yet. Create one now? [y/N] "
        local create_answer
        read -r create_answer
        if [ "$create_answer" = "y" ] || [ "$create_answer" = "Y" ]; then
          echo -n "Migration name: "
          local mig_name
          read -r mig_name
          if [ -z "$mig_name" ]; then
            echo "No name given — skipping migration creation."
          else
            local before_files after_files
            before_files=$(ls "${versions_dir}"/*.py 2>/dev/null | sort)
            ${=alembic_cmd} revision --autogenerate -m "$mig_name"
            after_files=$(ls "${versions_dir}"/*.py 2>/dev/null | sort)
            new_migration_path=$(comm -13 <(echo "$before_files") <(echo "$after_files") | head -1)
            if [ -z "$new_migration_path" ]; then
              echo "Couldn't detect the newly created migration file — it may not have been written to ${versions_dir}."
            else
              echo "Created $new_migration_path"
              children_of=()
              while IFS=' ' read -r down_rev_key rest_val; do
                children_of[$down_rev_key]="$rest_val"
              done < <(_dmig_build_children_map "$versions_dir")
            fi
          fi
        fi
      fi
    fi
  fi

  # --- Phase 2: walk forward from current, local files only ---
  local fwd_rev="$current_rev" child child_rev child_path
  iterations=0
  while :; do
    iterations=$((iterations + 1))
    [ "$iterations" -gt 500 ] && { echo "Forward chain walk exceeded 500 steps — stopping."; break; }

    child="${children_of[$fwd_rev]:-}"
    [ -z "$child" ] && break
    child_rev="${child%%|*}"
    child_path="${child#*|}"
    message=$(head -1 "$child_path" | sed 's/^"""//')
    marker=""
    [ -n "$new_migration_path" ] && [ "$child_path" = "$new_migration_path" ] && marker=" [NEW, JUST CREATED]"
    chain_lines+=("$fwd_rev -> $child_rev, $message$marker")
    chain_revs+=("$child_rev")
    fwd_rev="$child_rev"
  done

  echo "--- migration chain (oldest first, most recent at the bottom) ---"
  local line
  for line in "${chain_lines[@]}"; do
    echo "$line"
  done

  # Keep fzf's default layout (prompt at the bottom, list growing upward
  # from it) — don't use --reverse, that also moves the prompt itself to
  # the top. Under the default layout, the FIRST line fed to fzf ends up
  # at the bottom next to the prompt, so feed chain_lines in reverse (most
  # recent first, oldest last) to land the most recent entry right next to
  # the prompt without touching the overall layout. Negative indices
  # (-1 = last element) count from the end regardless of whether this
  # shell has KSH_ARRAYS set, unlike positive indices.
  local -a reversed_lines
  local i
  for ((i = 1; i <= ${#chain_lines[@]}; i++)); do
    reversed_lines+=("${chain_lines[-i]}")
  done

  local picked target_rev target_index=0
  picked=$(printf '%s\n' "${reversed_lines[@]}" | fzf --prompt="Land on > " \
    --header="Pick the migration you wish to land on (this will cause an upgrade or a downgrade depending on which migration you pick)")
  if [ -z "$picked" ]; then
    echo "No migration selected."
  else
    target_rev=$(echo "$picked" | sed -E 's/.*-> *([a-f0-9]+).*/\1/')
    if [ -z "$target_rev" ]; then
      echo "Couldn't parse a revision id from: $picked"
    else
      for ((i = 1; i <= ${#chain_revs[@]}; i++)); do
        if [ "${chain_revs[i]}" = "$target_rev" ]; then
          target_index=$i
          break
        fi
      done
      if [ "$target_index" -eq 0 ]; then
        echo "Couldn't locate $target_rev in the chain — this shouldn't happen."
      elif [ "$target_index" -lt "$current_index" ]; then
        echo "Downgrading to $target_rev..."
        if [ "$env_mode" = "stg" ]; then
          docker compose run --rm -e "${host_var}=${proxy_name}" -e "${pw_var}=${pw}" app bin/cli alembic downgrade "$target_rev"
        else
          ${=alembic_cmd} downgrade "$target_rev"
        fi
      elif [ "$target_index" -gt "$current_index" ]; then
        echo "Upgrading to $target_rev..."
        if [ "$env_mode" = "stg" ]; then
          docker compose run --rm -e "${host_var}=${proxy_name}" -e "${pw_var}=${pw}" app bin/cli alembic upgrade "$target_rev"
        else
          ${=alembic_cmd} upgrade "$target_rev"
        fi
      else
        echo "$target_rev is already the current revision — nothing to do."
      fi
    fi
  fi

  if [ ${#restored_paths[@]} -gt 0 ]; then
    local p
    for p in "${restored_paths[@]}"; do
      rm -f -- "$p"
    done
    echo "--- cleaned up ${#restored_paths[@]} temporarily restored migration file(s): ${restored_paths[*]} ---"
  fi

  if [ "$env_mode" = "stg" ]; then
    echo "Stopping stg proxy ($proxy_name)..."
    docker kill "$proxy_name" >/dev/null 2>&1
  fi
}
