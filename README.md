# Rspamd Package Builder

Build and release Rspamd packages using GitHub Actions.

## Overview

This repository contains GitHub Actions workflows to build and test Rspamd packages for multiple Linux distributions:
- **Debian/Ubuntu**
- **CentOS/RHEL**

## Configuration

### Repository Variables

Configure these in your repository settings under Settings → Secrets and variables → Actions → Variables:

#### Build Control Flags

| Variable | Description | Default |
|----------|-------------|---------|
| `SKIP_TESTS` | Skip tests for all distributions | (not set) |
| `SKIP_TESTS_<DISTRO>_<VERSION>` | Skip tests for specific distribution (e.g., `SKIP_TESTS_CENTOS_8`, `SKIP_TESTS_DEBIAN_BOOKWORM`, `SKIP_TESTS_UBUNTU_NOBLE`) | (not set) |

> **Note**: Set these variables to any non-empty value (e.g., `true`, `1`, `yes`) to enable the skip behavior.
> 
> **Pattern**: Per-distribution test skip variables follow the pattern `SKIP_TESTS_<DISTRO>_<VERSION>` where distro names are uppercase with underscores (e.g., `CENTOS`, `DEBIAN`, `UBUNTU`) and versions use their codename or number.

## Supported Distributions

### Debian-based
- Debian: bookworm, bullseye, trixie
- Ubuntu: focal, jammy, noble

### RPM-based
- CentOS/RHEL: 8, 9, 10

## Architecture

- **Build**: Packages are built in parallel for all distributions
- **Test**: Packages are tested in containers matching target distributions
