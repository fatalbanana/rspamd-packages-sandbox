#!/bin/bash
# Script to build Debian APT repository inside Docker container with newer reprepro
set -x
set -euo pipefail

REPO_DIR="/workspace/repos"
PACKAGES_DIR="/workspace/packages"

# Import GPG keys
gpg --batch --import /gpg/pubkey.asc
gpg --batch --import /gpg/seckey.asc
KEY_FPR=$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr:/ {print $10; exit}')

# Configure GPG for non-interactive signing
mkdir -p ~/.gnupg && chmod 700 ~/.gnupg
cat > ~/.gnupg/gpg.conf << 'EOF'
use-agent
pinentry-mode loopback
EOF
cat > ~/.gnupg/gpg-agent.conf << 'EOF'
allow-loopback-pinentry
EOF
gpg-connect-agent reloadagent /bye || true

# Test GPG signing
echo "test" | gpg --pinentry-mode loopback --passphrase-file /gpg/passphrase.txt -u "$KEY_FPR" --batch --sign -o /dev/null

# Setup SSH
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cp /ssh/id_rsa ~/.ssh/id_rsa && chmod 600 ~/.ssh/id_rsa
cp /ssh/known_hosts ~/.ssh/known_hosts && chmod 644 ~/.ssh/known_hosts

# Prefill with existing repo content
mkdir -p "$REPO_DIR/conf"
rsync -e "ssh -l $SSH_USERNAME -i ~/.ssh/id_rsa -o StrictHostKeyChecking=yes" -ru \
  "${UPLOAD_HOST}:${UPLOAD_SUFFIX}${TARGET_PATH}/" "$REPO_DIR/"
echo "--- Listing pre-filled repository content ---"
ls -lR "$REPO_DIR"

# Export public key for clients (remove old one first)
rm -f "$REPO_DIR/rspamd.asc"
gpg --batch --armor --output "$REPO_DIR/rspamd.asc" --export "$KEY_FPR"

# Prepare distributions file (recreate from scratch since we're rebuilding the database)
rm -f "$REPO_DIR/conf/distributions"
IFS=',' read -ra DIST_LIST <<< "$DIST_NAMES"
for d in "${DIST_LIST[@]}"; do
  codename="${d/ubuntu-/}"
  codename="${codename/debian-/}"
  ARCHS="source amd64"
  if compgen -G "$PACKAGES_DIR/${d}/*arm64*.deb" > /dev/null; then
    ARCHS="$ARCHS arm64"
  fi
  if [[ -n "${NIGHTLY:-}" ]]; then
    desc="Apt repository for rspamd nightly builds"
  else
    desc="Apt repository for rspamd stable builds"
  fi
  
  # Append distribution
  {
    printf '%s\n' "Origin: Rspamd"
    printf '%s\n' "Label: Rspamd"
    printf '%s\n' "Codename: ${codename}"
    printf '%s\n' "Architectures: ${ARCHS}"
    printf '%s\n' "Components: main"
    printf '%s\n' "Description: ${desc}"
    printf '%s\n' "SignWith: ${KEY_FPR}"
    printf '%s\n' "Limit: ${KEEP_BUILDS}"
    printf '\n'
  } >> "$REPO_DIR/conf/distributions"
done

# Remove old reprepro database - it's in legacy format and needs to be rebuilt
# Reprepro will automatically rebuild the database from existing dists/ when needed
if [ -d "$REPO_DIR/db" ]; then
  echo "Removing old reprepro database (will rebuild from dists/)..."
  rm -rf "$REPO_DIR/db"
fi

# Include packages
for d in "${DIST_LIST[@]}"; do
  codename="${d/ubuntu-/}"
  codename="${codename/debian-/}"
  shopt -s nullglob
  for deb_pkg in "$PACKAGES_DIR/${d}"/rspamd_*amd64*.deb; do
    reprepro -P extra -S mail -b "$REPO_DIR" -v --keepunreferencedfiles includedeb "$codename" "$deb_pkg"
  done
  for deb_pkg in "$PACKAGES_DIR/${d}"/rspamd-dbg_*amd64*.deb; do
    reprepro -P extra -S debug -b "$REPO_DIR" -v --keepunreferencedfiles includedeb "$codename" "$deb_pkg"
  done
  for deb_pkg in "$PACKAGES_DIR/${d}"/rspamd-asan_*amd64*.deb; do
    reprepro -P extra -S mail -b "$REPO_DIR" -v --keepunreferencedfiles includedeb "$codename" "$deb_pkg"
  done
  for deb_pkg in "$PACKAGES_DIR/${d}"/rspamd-asan-dbg_*amd64*.deb; do
    reprepro -P extra -S debug -b "$REPO_DIR" -v --keepunreferencedfiles includedeb "$codename" "$deb_pkg"
  done
  for deb_pkg in "$PACKAGES_DIR/${d}"/rspamd_*arm64*.deb; do
    reprepro -P extra -S mail -b "$REPO_DIR" -v --keepunreferencedfiles includedeb "$codename" "$deb_pkg"
  done
  for deb_pkg in "$PACKAGES_DIR/${d}"/rspamd-dbg_*arm64*.deb; do
    reprepro -P extra -S debug -b "$REPO_DIR" -v --keepunreferencedfiles includedeb "$codename" "$deb_pkg"
  done
  for deb_pkg in "$PACKAGES_DIR/${d}"/rspamd-asan_*arm64*.deb; do
    reprepro -P extra -S mail -b "$REPO_DIR" -v --keepunreferencedfiles includedeb "$codename" "$deb_pkg"
  done
  for deb_pkg in "$PACKAGES_DIR/${d}"/rspamd-asan-dbg_*arm64*.deb; do
    reprepro -P extra -S debug -b "$REPO_DIR" -v --keepunreferencedfiles includedeb "$codename" "$deb_pkg"
  done
done

# Export indices for all distributions to ensure everything is indexed
echo "Exporting indices..."
for d in "${DIST_LIST[@]}"; do
  codename="${d/ubuntu-/}"
  codename="${codename/debian-/}"
  reprepro -b "$REPO_DIR" export "$codename"
done

# Retention is handled by reprepro's Limit field
reprepro -b "$REPO_DIR" deleteunreferenced

# Upload
rsync -e "ssh -l $SSH_USERNAME -i ~/.ssh/id_rsa -o StrictHostKeyChecking=yes" -ru --delete \
  "$REPO_DIR/" "${UPLOAD_HOST}:${UPLOAD_SUFFIX}${TARGET_PATH}/"
