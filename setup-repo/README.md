# Setup Repository Standards

Automatically configure HiveForge repository standards on any repository in the organization.

## What It Does

This script configures a repository with HiveForge's standard settings:

1. ✅ **Enables auto-merge** - Allows Dependabot PRs to merge automatically
2. ✅ **Sets up branch protection** - Prevents force pushes and branch deletion
3. ✅ **Verifies workflows** - Checks for required GitHub Actions workflows

The script is **idempotent** - safe to run multiple times without side effects.

## Prerequisites

- [GitHub CLI (`gh`)](https://cli.github.com/) installed and authenticated
- Admin access to the target repository
- Repository must have at least one commit on the target branch

## Usage

### Windows (PowerShell)

**Quick run (download and execute):**
```powershell
Invoke-WebRequest https://raw.githubusercontent.com/hiveforge-sh/scripts/main/setup-repo/setup-repo-standards.ps1 -OutFile setup.ps1
./setup.ps1 -Repo your-repo-name
Remove-Item setup.ps1
```

**Or clone and run:**
```powershell
git clone https://github.com/hiveforge-sh/scripts.git
cd scripts/setup-repo
./setup-repo-standards.ps1 -Repo your-repo-name

# For repositories using 'master' instead of 'main'
./setup-repo-standards.ps1 -Repo your-repo-name -Branch master

# For different organization
./setup-repo-standards.ps1 -Owner myorg -Repo my-repo
```

### macOS / Linux (Bash)

**Quick run (download and execute):**
```bash
curl -sSL https://raw.githubusercontent.com/hiveforge-sh/scripts/main/setup-repo/setup-repo-standards.sh | bash -s your-repo-name
```

**Or clone and run:**
```bash
git clone https://github.com/hiveforge-sh/scripts.git
cd scripts/setup-repo
./setup-repo-standards.sh your-repo-name

# For repositories using 'master' instead of 'main'
./setup-repo-standards.sh your-repo-name master
```

## Parameters

### PowerShell

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-Repo` | Yes | - | Repository name (without owner) |
| `-Branch` | No | `main` | Branch to protect |
| `-Owner` | No | `hiveforge-sh` | GitHub organization or user |

### Bash

| Position | Required | Default | Description |
|----------|----------|---------|-------------|
| `$1` | Yes | - | Repository name |
| `$2` | No | `main` | Branch to protect |

Set `GITHUB_ORG` environment variable to change organization:
```bash
GITHUB_ORG=myorg ./setup-repo-standards.sh my-repo
```

## What Gets Configured

### 1. Auto-merge

Enables the auto-merge feature on the repository, allowing:
- PRs can use the "Enable auto-merge" button
- Dependabot PRs can merge automatically when CI passes
- Requires branch protection rules and passing checks

### 2. Branch Protection (Basic)

Sets up minimal branch protection on the default branch:
- ❌ Force pushes blocked
- ❌ Branch deletion blocked
- ⚠️ No required status checks (configure manually)
- ⚠️ No required reviews (configure manually)

### 3. Status Checks

The script does **not** automatically add required status checks because:
- Every repository has different CI job names
- Test matrices vary by project
- Manual configuration ensures correctness

**To add required checks**, update the branch protection:

```bash
gh api -X PUT repos/OWNER/REPO/branches/BRANCH/protection \
  --input branch-protection-template.json
```

Edit `branch-protection-template.json` and add your CI job names to `contexts` array.

## Example Output

```
🔧 Configuring repository: hiveforge-sh/my-project

✓ Checking auto-merge...
  ✅ Auto-merge already enabled (skipped)

✓ Checking branch protection on 'main'...
  ✅ Branch protection configured

✓ Checking Dependabot auto-merge workflow...
  ⚠️  Dependabot auto-merge workflow not found
     Copy from hivemind: .github/workflows/dependabot-auto-merge.yml

🎉 Repository configuration complete!

Configuration summary:
  Repository: my-project
  URL: https://api.github.com/repos/hiveforge-sh/my-project
  Auto-merge: True
  Branch: main (protected)
  Status checks: 0 required
  Force pushes: blocked
  Delete branch: blocked

Next steps:
  1. Copy workflow files from hivemind if needed:
     - .github/workflows/dependabot-auto-merge.yml
     - .github/workflows/test.yml (customize for your project)
     - .github/dependabot.yml

  2. Update branch protection with required status checks:
     gh api -X PUT repos/hiveforge-sh/my-project/branches/main/protection \
       --input protection.json
```

## Next Steps

After running this script:

1. **Copy workflow files** from [hivemind](https://github.com/hiveforge-sh/hivemind):
   ```bash
   # From the target repository
   curl -o .github/workflows/dependabot-auto-merge.yml \
     https://raw.githubusercontent.com/hiveforge-sh/hivemind/master/.github/workflows/dependabot-auto-merge.yml
   
   curl -o .github/dependabot.yml \
     https://raw.githubusercontent.com/hiveforge-sh/hivemind/master/.github/dependabot.yml
   ```

2. **Configure required status checks:**
   - Edit `branch-protection-template.json`
   - Add your CI job names to `contexts` array
   - Apply with: `gh api -X PUT repos/OWNER/REPO/branches/BRANCH/protection --input branch-protection-template.json`

3. **Customize test workflow:**
   - Copy `.github/workflows/test.yml` from hivemind
   - Modify for your tech stack (Python, Go, Rust, etc.)
   - Update job names to match what you added to branch protection

## Files Included

- `setup-repo-standards.ps1` - PowerShell version (Windows, macOS, Linux)
- `setup-repo-standards.sh` - Bash version (macOS, Linux, WSL)
- `branch-protection-template.json` - Template for branch protection rules

## Troubleshooting

### "Branch not protected" error
The branch must exist before it can be protected. Push at least one commit first.

### "Not Found" error
- Verify you have admin access to the repository
- Check the repository name is correct
- Ensure `gh` is authenticated: `gh auth status`

### Auto-merge not working
1. Verify it's enabled: `gh api repos/OWNER/REPO --jq '.allow_auto_merge'`
2. Check branch protection exists
3. Ensure required status checks are configured
4. Verify the PR has "Enable auto-merge" button clicked

### Permission denied
Run `gh auth refresh -s admin:org,repo` to ensure proper permissions.

## See Also

- [HiveForge Repository Standards](https://github.com/hiveforge-sh/hivemind/blob/master/docs/REPOSITORY-STANDARDS.md)
- [Cross-Platform Scripting Guidelines](https://github.com/hiveforge-sh/hivemind/blob/master/docs/CROSS-PLATFORM-SCRIPTS.md)
- [GitHub Branch Protection Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches)

## License

MIT License - See [LICENSE](../../LICENSE) for details.
