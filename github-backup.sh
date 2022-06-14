#!/usr/bin/env bash

# Copyright (C) 2021 Uco Mesdag
# Description:  Bash script to backup all your Github repositories. All
#               repositories are individually archived to a `.tar.bz2` archive
#               and then gathered in a single archive. You can set the number of
#               backups to keep and it supports `git-lfs`. Repositories can be
#               restored to a new location with `git push --mirror <remote>`.

USERNAME=""              # github username or organization name
API_TOKEN=""             # https://github.com/settings/tokens
ACCOUNT_TYPE="user"      # user -or- org
KEEP=5                   # number of backups to keep
DEST=""                  # backup destination (default: script directory)
TMP=""                   # temp directory (default: script directory)

###

# Set language
export LC_ALL=en_US.UTF-8

# Load .config file if it exists
SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 || exit; pwd -P)"
[ -f "$SCRIPT_DIR"/.config ] && source "$SCRIPT_DIR"/.config

# Use defaults for GITHUB_ parameters that are not set
[[ -z "${GITHUB_USERNAME}" ]] && GITHUB_USERNAME=$USERNAME
[[ -z "${GITHUB_API_TOKEN}" ]] && GITHUB_API_TOKEN=$API_TOKEN
[[ -z "${GITHUB_ACCOUNT_TYPE}" ]] && GITHUB_ACCOUNT_TYPE=$ACCOUNT_TYPE
[[ -z "${GITHUB_BACKUP_KEEP}" ]] && GITHUB_BACKUP_KEEP=$KEEP
[[ -z "${GITHUB_BACKUP_DEST}" ]] && GITHUB_BACKUP_DEST=$DEST
[[ -z "${GITHUB_BACKUP_TMP}" ]] && GITHUB_BACKUP_TMP=$TMP

# Check for git and git-lfs
which git >/dev/null 2>&1 || (echo "Please install 'git' first." && exit 1)
git lfs >/dev/null 2>&1 || (echo "Please install 'git-lfs', see: https://git-lfs.github.com/." && exit 1)

# Check if credentials are provided
[ "$GITHUB_USERNAME" == "" ] && echo "Please either edit this script and add your Github 'user' or 'organization', or expose it by exporting it prior to running this script." && exit 1
[ "$GITHUB_API_TOKEN" == "" ] && echo "Please either edit this script and add your Github 'token', or expose it by exporting it prior to running this script." && exit 1

# Check if provided directories exist else unset them
[ "$GITHUB_BACKUP_DEST" != "" ] && [ -d "$GITHUB_BACKUP_DEST" ] ||  GITHUB_BACKUP_DEST=""
[ "$GITHUB_BACKUP_TMP" != "" ] && [ -d "$GITHUB_BACKUP_TMP" ] ||  GITHUB_BACKUP_TMP=""

# Set DEST and TMP to current directory if not set
[ "$GITHUB_BACKUP_DEST" == "" ] && GITHUB_BACKUP_DEST="$SCRIPT_DIR"
[ "$GITHUB_BACKUP_TMP" == "" ] && GITHUB_BACKUP_TMP="$(mktemp -d "$SCRIPT_DIR"/.github.XXXXXXXXXX)"

# Run as the owner of the TMP directory, this fixes the error:
# "dubious ownership in repository"
RUNAS_USER=$(ls -ld "$GITHUB_BACKUP_TMP"/.. | awk '{print $3}')
RUNAS="sudo -u $RUNAS_USER "
chown $RUNAS_USER "$GITHUB_BACKUP_TMP"

# Get the list of repositories
GITHUB_REPO_LIST=''
for PAGE in {1..10}; do
  RESULT=$(curl -s  -H "Authorization: token ${GITHUB_API_TOKEN}" \
    "https://api.github.com/${GITHUB_ACCOUNT_TYPE}/repos?visibility=all&affiliation=owner&per_page=100&page=${PAGE}" | \
    grep -w clone_url | grep -o '[^"]\+://.\+.git')
  [ $? -ne 0 ] && break
  GITHUB_REPO_LIST="${GITHUB_REPO_LIST}${RESULT} "
done

# Check for empty repository list
[ "$GITHUB_REPO_LIST" == "" ] && echo "No repositories found." && exit 1

# Iterate over the repository list
for REPO in $GITHUB_REPO_LIST; do
  echo "=== $REPO" && cd "$GITHUB_BACKUP_TMP" || exit
  REPO_NAME=$(echo "$REPO" | sed "s/^https:\/\/github\.com\/${GITHUB_USERNAME}\/\(.*\)$/\1/")
  REPO=$(echo "$REPO" | sed "s/^https:\/\/\github.com\//https:\/\/${GITHUB_USERNAME}:${GITHUB_API_TOKEN}@github.com\//")
  $RUNAS git clone --mirror "$REPO"
  cd "$GITHUB_BACKUP_TMP/$REPO_NAME" && $RUNAS git lfs fetch --all
  $RUNAS git fsck
  [ $? -ne 0 ] && echo -e "\n===\nWARNING: issues found with '$REPO_NAME'\n===" && exit 1
  echo -e "Archiving to '${REPO_NAME}.tar.bz2'...\n"
  cd "$GITHUB_BACKUP_TMP" && $RUNAS tar -cjf ${REPO_NAME}.tar.bz2 "$REPO_NAME"
  rm -rf "$REPO_NAME"
done

echo -e "Archiving 'all' to 'github.backup.$(date +%Y%m%d.%H%M%S).tar.bz2'..."
$RUNAS tar -cjf "$GITHUB_BACKUP_DEST/github.backup.$(date +%FT%H.%M).tar.bz2" *.tar.bz2

echo "Cleaning up..."
cd "$SCRIPT_DIR" || exit
rm -rf .github.*
cd "$GITHUB_BACKUP_DEST" || exit
BACKUP_COUNT=$(ls -1q github.backup.*.tar.bz2 | wc -l)
if [ "$BACKUP_COUNT" -gt "$GITHUB_BACKUP_KEEP" ]; then
  ls -1r github.backup.*.tar.bz2 | tail -n "$(expr ${BACKUP_COUNT:-0} - ${GITHUB_BACKUP_KEEP:-0})" | xargs rm --
fi

echo "Done!"
