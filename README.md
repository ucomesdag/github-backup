# Github Backup

Bash script to backup all your Github repositories. All repositories are individually archived to a `.tar.bz2` archive and then gathered in a single archive. You can set the number of backups to keep and it supports `git-lfs`. Repositories can be restored to a new location with `git push --mirror <remote>` or accessed locally with `git bundle my-repo.bundle && git clone my-repo.bundle ../my-repo`.


## Usage

1. Create a [Github token](https://github.com/settings/tokens).

   For users the scope should be `repo` (all) and for organizations `read:org`.

2. Set it up.

- Either export your settings prior to running the script:

```
export GITHUB_USERNAME='github-username'
export GITHUB_API_TOKEN='github-token'
export GITHUB_ACCOUNT_TYPE='user'
export GITHUB_BACKUP_KEEP='5'
export GITHUB_BACKUP_DEST='/path/to/destination-of-the-backup'
```

- Or create a .config file in the script directory:

```
GITHUB_USERNAME='github-username'                       # github username or organization name
GITHUB_API_TOKEN='github-token'                         # https://github.com/settings/tokens
GITHUB_ACCOUNT_TYPE='user'                              # user -or- org (default: user)
GITHUB_BACKUP_KEEP='5'                                  # number of backups to keep (default: 5)
GITHUB_BACKUP_DEST='/path/to/destination-of-the-backup' # backup destination (default: script directory)
```

3. Make it executable:

  ```
  chmod +x github-backup.sh
  ```

4. Run it:

  ```
  ./github-backup.sh
  ```
