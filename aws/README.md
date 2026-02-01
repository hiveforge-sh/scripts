# AWS Redirect Setup

Automated scripts to configure AWS S3 + Route53 for short redirect URLs.

## What It Does

Creates a simple redirect service at `get.hiveforge.sh` (or any subdomain) that redirects to GitHub raw URLs:

**Before:**
```bash
curl -sSL https://raw.githubusercontent.com/hiveforge-sh/scripts/master/setup-repo/setup-repo-standards.sh | bash -s repo-name
```

**After:**
```bash
curl -sL http://get.hiveforge.sh/setup-repo.sh | bash -s repo-name
```

## Prerequisites

1. **AWS CLI installed**
   - Windows: `winget install Amazon.AWSCLI`
   - macOS: `brew install awscli`
   - Linux: [Install guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

2. **AWS credentials configured**
   ```bash
   aws configure
   ```

3. **Route53 hosted zone** for your domain

See full prerequisites and permissions in [README.md](./README.md).

## Quick Start

**PowerShell:**
```powershell
./setup-aws-redirects.ps1
```

**Bash:**
```bash
./setup-aws-redirects.sh
```

**Result:**
- Creates `get.hiveforge.sh` redirect service
- URLs: `http://get.hiveforge.sh/setup-repo.sh` and `.ps1`
- DNS propagation: 5-10 minutes

## Documentation

See [README.md](./README.md) for:
- Detailed prerequisites
- Usage examples
- HTTPS setup (CloudFront)
- Cost estimates
- Troubleshooting
- Security notes

## Quick Test

After setup (wait 5-10 min for DNS):
```bash
curl -I http://get.hiveforge.sh/setup-repo.sh
# Should return: HTTP/1.1 302 Found
```
