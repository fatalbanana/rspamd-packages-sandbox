# Rspamd Package Builder

Build and release Rspamd packages using GitHub Actions.

## Overview

This repository contains GitHub Actions workflows to build, test, and publish Rspamd packages for multiple Linux distributions:
- **Debian/Ubuntu**: Using aptly for APT repository management
- **CentOS/RHEL**: Using createrepo_c for RPM repository management

## Configuration

### Repository Variables

Configure these in your repository settings under Settings → Secrets and variables → Actions → Variables:

#### General Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `KEEP_BUILDS_STABLE` | Number of stable package versions to retain per distribution | `10` |
| `KEEP_BUILDS_NIGHTLY` | Number of nightly package versions to retain per distribution | `10` |
| `UPLOAD_HOST_KNOWN_HOSTS` | SSH known_hosts entries for upload server | (required) |
| `UPLOAD_SUFFIX` | Path prefix on upload server | `rspamd.com/dist/` |

#### Build Control Flags

| Variable | Description | Default |
|----------|-------------|---------|
| `SKIP_PUBLISH` | Skip publishing step entirely | (not set) |
| `SKIP_TESTS` | Skip tests for all distributions | (not set) |
| `SKIP_TESTS_<DISTRO>_<VERSION>` | Skip tests for specific distribution (e.g., `SKIP_TESTS_CENTOS_8`, `SKIP_TESTS_DEBIAN_BOOKWORM`, `SKIP_TESTS_UBUNTU_NOBLE`) | (not set) |

> **Note**: Set these variables to any non-empty value (e.g., `true`, `1`, `yes`) to enable the skip behavior.
> 
> **Pattern**: Per-distribution test skip variables follow the pattern `SKIP_TESTS_<DISTRO>_<VERSION>` where distro names are uppercase with underscores (e.g., `CENTOS`, `DEBIAN`, `UBUNTU`) and versions use their codename or number.

#### Debian/Ubuntu Publishing

| Variable | Description | Default |
|----------|-------------|---------|
| `TARGET_DEB_STABLE` | Target path for stable Debian packages | `apt-stable` |
| `TARGET_DEB_UNSTABLE` | Target path for nightly Debian packages | `apt` |
| `APT_REPO_URL_STABLE` | Public URL of stable APT repository (for mirroring) | `https://rspamd.com/apt-stable/` |
| `APT_REPO_URL_UNSTABLE` | Public URL of nightly APT repository (for mirroring) | `https://rspamd.com/apt/` |

#### RPM Publishing

| Variable | Description | Default |
|----------|-------------|---------|
| `TARGET_RPM_STABLE` | Target path for stable RPM packages | `rpm-stable` |
| `TARGET_RPM_UNSTABLE` | Target path for nightly RPM packages | `rpm` |

### Repository Secrets

Configure these in your repository settings under Settings → Secrets and variables → Actions → Secrets:

#### GPG Signing

| Secret | Description |
|--------|-------------|
| `GPG_PRIVATE_KEY` | GPG private key in ASCII armored format for signing packages |
| `GPG_PASSPHRASE` | Passphrase for the GPG private key |
| `GPG_KEY_ID` | GPG key ID/fingerprint |

#### SSH Upload Keys

| Secret | Description |
|--------|-------------|
| `SSH_KEY_DEB_STABLE` | SSH private key for uploading stable Debian packages |
| `SSH_KEY_DEB_UNSTABLE` | SSH private key for uploading nightly Debian packages |
| `SSH_KEY_RPM_STABLE` | SSH private key for uploading stable RPM packages |
| `SSH_KEY_RPM_UNSTABLE` | SSH private key for uploading nightly RPM packages |
| `SSH_USERNAME` | SSH username for upload server |

#### Server Configuration

| Secret | Description |
|--------|-------------|
| `UPLOAD_HOST` | SSH hostname/IP for package upload server |

## Workflows

### Nightly Builds

Triggered daily at midnight UTC or manually via workflow dispatch.

Builds packages for all supported distributions and publishes to nightly repositories.

### Debian/Ubuntu Publishing

**Tool**: [aptly](https://github.com/aptly-dev/aptly) (automatically installs latest version)

**Process**:
1. Mirrors existing published repository from public URL
2. Imports existing packages to local repository
3. Applies retention policy (removes versions beyond `KEEP_BUILDS`)
4. Adds new packages
5. Publishes repository with GPG signing
6. Uploads to server via rsync

**Repository Metadata**:
- Origin: `Rspamd`
- Label: `Rspamd`
- Suite: (empty)
- Component: `main`

**Concurrency**: One job per variant (nightly/stable) - jobs queue if multiple triggered

### RPM Publishing

**Tool**: `createrepo_c` (from Ubuntu packages)

**Process**:
1. Downloads existing repository metadata
2. Adds new packages
3. Applies retention policy
4. Regenerates repository metadata with GPG signing
5. Uploads to server via rsync

**Concurrency**: One job per distribution per variant (e.g., centos-8-nightly, centos-9-stable)

## Supported Distributions

### Debian-based
- Debian: bookworm, bullseye, trixie
- Ubuntu: focal, jammy, noble

### RPM-based
- CentOS/RHEL: 8, 9, 10

## Local Development

To test the workflows locally, you'll need to set up the required secrets and variables in your GitHub repository settings.

## Architecture

- **Build**: Packages are built in parallel for all distributions
- **Test**: Packages are tested in containers matching target distributions
- **Publish**: Packages are published to repository with retention management
- **Concurrency**: Publishing jobs are serialized per variant to prevent conflicts

## Retention Policy

The `KEEP_BUILDS_STABLE` and `KEEP_BUILDS_NIGHTLY` variables control how many versions of each package are kept per distribution for stable and nightly builds respectively:
- When adding new packages, old versions beyond this limit are removed
- Applied separately per package (rspamd, rspamd-dbg, rspamd-asan, rspamd-asan-dbg)
- Cleanup happens before new packages are added
- You can set different retention for nightly (e.g., keep 5) vs stable (e.g., keep 20) builds
