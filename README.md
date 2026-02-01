# HiveForge Scripts

Central repository for automation scripts and tools used across HiveForge projects.

## 📦 Available Scripts

### [setup-repo](./setup-repo/)

Apply HiveForge repository standards to any repository in the organization.

**Features:**
- ✅ Enable auto-merge for Dependabot PRs
- ✅ Configure branch protection rules
- ✅ Verify required workflows exist
- ✅ Idempotent (safe to run multiple times)
- ✅ Cross-platform (PowerShell & Bash)

**Quick Start:**

**Windows (PowerShell):**
```powershell
# Download and run
Invoke-WebRequest https://raw.githubusercontent.com/hiveforge-sh/scripts/main/setup-repo/setup-repo-standards.ps1 -OutFile setup.ps1
./setup.ps1 -Repo your-repo-name
Remove-Item setup.ps1
```

**macOS/Linux (Bash):**
```bash
# Download and run
curl -sSL https://raw.githubusercontent.com/hiveforge-sh/scripts/main/setup-repo/setup-repo-standards.sh | bash -s your-repo-name
```

**Or clone once and reuse:**
```bash
git clone https://github.com/hiveforge-sh/scripts.git ~/hiveforge-scripts
~/hiveforge-scripts/setup-repo/setup-repo-standards.sh your-repo-name
```

## 🔧 Installation

### One-time Setup

Clone this repository to a convenient location:

```bash
git clone https://github.com/hiveforge-sh/scripts.git ~/hiveforge-scripts
```

Add to your PATH (optional):

**Bash/Zsh (~/.bashrc or ~/.zshrc):**
```bash
export PATH="$HOME/hiveforge-scripts/setup-repo:$PATH"
```

**PowerShell (Profile):**
```powershell
$env:PATH += ";$HOME\hiveforge-scripts\setup-repo"
```

### Direct Usage (No Installation)

Each script can be downloaded and run directly via `curl` or `Invoke-WebRequest`.

## 📚 Documentation

Each script directory contains:
- `README.md` - Detailed usage instructions
- Script files (`.ps1` for PowerShell, `.sh` for Bash)
- Configuration templates (if applicable)

## 🤝 Contributing

### Adding New Scripts

1. Create a new directory for your script category
2. Provide both PowerShell (`.ps1`) and Bash (`.sh`) versions
3. Include a `README.md` with usage instructions
4. Add entry to this main README
5. Test on Windows, macOS, and Linux

### Guidelines

- ✅ Always provide cross-platform versions (PowerShell + Bash)
- ✅ Make scripts idempotent (safe to run multiple times)
- ✅ Include comprehensive error handling
- ✅ Use color-coded output for clarity
- ✅ Document all parameters and examples
- ✅ Follow existing script patterns

See [hivemind's CROSS-PLATFORM-SCRIPTS.md](https://github.com/hiveforge-sh/hivemind/blob/master/docs/CROSS-PLATFORM-SCRIPTS.md) for detailed guidelines.

## 📋 Script Inventory

| Script | Description | Platforms |
|--------|-------------|-----------|
| [setup-repo](./setup-repo/) | Apply HiveForge repository standards | Windows, macOS, Linux |
| [aws](./aws/) | Configure AWS S3 + Route53 redirects | Windows, macOS, Linux |

*More scripts coming soon...*

## 🔐 Security

- Scripts use GitHub CLI (`gh`) for authentication
- No credentials are stored in this repository
- All API calls use the user's authenticated `gh` session
- Scripts require appropriate repository permissions

## 📄 License

MIT License - See individual script directories for specific licensing.

## 🐛 Issues & Support

Found a bug or have a feature request?

1. Check existing [issues](https://github.com/hiveforge-sh/scripts/issues)
2. Open a new issue with:
   - Script name and version
   - Operating system and shell version
   - Expected vs actual behavior
   - Steps to reproduce

## 🚀 Quick Links

- [HiveForge Organization](https://github.com/hiveforge-sh)
- [Hivemind Repository](https://github.com/hiveforge-sh/hivemind)
- [Repository Standards Documentation](https://github.com/hiveforge-sh/hivemind/blob/master/docs/REPOSITORY-STANDARDS.md)

---

**Maintained by the HiveForge team** 🐝
