#!/bin/bash
set -euo pipefail

USERS_DIR="/users-config"

echo "Initializing users from ${USERS_DIR}"

if [ ! -d "${USERS_DIR}" ]; then
  echo "No users directory mounted at ${USERS_DIR}, creating it"
  mkdir -p "${USERS_DIR}"
fi

# If users dir is empty, try to seed it from repository-provided /opt/repo-users
if [ -d "/opt/repo-users" ]; then
  shopt -s nullglob
  repo_count=0
  for _ in /opt/repo-users/*/; do repo_count=$((repo_count+1)); break; done
  cfg_count=0
  for _ in ${USERS_DIR}/*/; do cfg_count=$((cfg_count+1)); break; done
  # Check image version marker
  repo_ver_file="/opt/repo-users/.image_version"
  vol_ver_file="${USERS_DIR}/.image_version"
  repo_ver=""
  vol_ver=""
  if [ -f "$repo_ver_file" ]; then repo_ver=$(cat "$repo_ver_file"); fi
  if [ -f "$vol_ver_file" ]; then vol_ver=$(cat "$vol_ver_file"); fi

  if [ "$repo_ver" != "$vol_ver" ]; then
    echo "Repo image version ($repo_ver) differs from volume ($vol_ver). Applying merge/seed from /opt/repo-users"
    # For each user dir in repo, merge into volume (create if missing).
    for ud in /opt/repo-users/*/ ; do
      [ -d "$ud" ] || continue
      uname=$(basename "$ud")
      echo "Merging user $uname from repo"
      mkdir -p "${USERS_DIR}/$uname"
      # Merge authorized_keys: append non-duplicate lines
      if [ -f "$ud/authorized_keys" ]; then
        mkdir -p "${USERS_DIR}/$uname"
        touch "${USERS_DIR}/$uname/authorized_keys"
        # combine and dedupe
        cat "$ud/authorized_keys" "$USERS_DIR/$uname/authorized_keys" 2>/dev/null | awk '!seen[$0]++' > "/tmp/ak.$$"
        mv "/tmp/ak.$$" "${USERS_DIR}/$uname/authorized_keys"
      fi
      # Copy password if not exists in volume (do not overwrite)
      if [ -f "$ud/password" ] && [ ! -f "${USERS_DIR}/$uname/password" ]; then
        cp "$ud/password" "${USERS_DIR}/$uname/password"
      fi
      # Copy other files that don't exist yet
      for f in "$ud"*; do
        [ -e "$f" ] || continue
        base=$(basename "$f")
        if [ "$base" = "authorized_keys" ] || [ "$base" = "password" ]; then
          continue
        fi
        if [ ! -e "${USERS_DIR}/$uname/$base" ]; then
          cp -a "$f" "${USERS_DIR}/$uname/$base"
        fi
      done
    done
    # update volume version marker
    if [ -n "$repo_ver" ]; then
      echo "$repo_ver" > "$vol_ver_file"
    fi
  else
    # If volume empty and repo has users, do a simple seed
    if [ $cfg_count -eq 0 ] && [ $repo_count -gt 0 ]; then
      echo "Seeding ${USERS_DIR} from /opt/repo-users"
      cp -a /opt/repo-users/. ${USERS_DIR}/
    fi
  fi
fi

if [ ! -d "${USERS_DIR}" ]; then
  echo "No users directory mounted at ${USERS_DIR}, skipping user creation"
else
  for d in ${USERS_DIR}/*/ ; do
    [ -d "$d" ] || continue
    username=$(basename "$d")
    echo "Processing user: $username"

    # Create user if not exists
    if ! id "$username" >/dev/null 2>&1; then
      useradd -m -s /bin/bash "$username"
      echo "$username ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/${username}
    fi

    # Setup .ssh
    mkdir -p /home/${username}/.ssh
    if [ -f "${d}authorized_keys" ]; then
      cat "${d}authorized_keys" >> /home/${username}/.ssh/authorized_keys
    fi
    if [ -f "${d}id_rsa.pub" ]; then
      cat "${d}id_rsa.pub" >> /home/${username}/.ssh/authorized_keys
    fi
    chown -R ${username}:${username} /home/${username}/.ssh || true
    chmod 700 /home/${username}/.ssh || true
    chmod 600 /home/${username}/.ssh/authorized_keys || true

    # If password file present, set password (useful for testing; not recommended for production)
    if [ -f "${d}password" ]; then
      passwd=$(cat "${d}password")
      echo "${username}:${passwd}" | chpasswd
    fi
  done
fi

echo "Starting sshd..."
/usr/sbin/sshd -D
