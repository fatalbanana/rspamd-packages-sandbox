# Package Retention Documentation

## Overview

Both RPM and Debian package repositories implement automatic retention logic to keep only the most recent N versions of packages, where N is controlled by the `KEEP_BUILDS` variable (default: 10).

## Configuration

The retention behavior is controlled by the `KEEP_BUILDS` GitHub variable:
- If not set, defaults to `10`
- Must be a positive integer
- If set to `0` or a non-numeric value, retention logic is skipped

## RPM Retention (publish_rpm.yml)

### How It Works

1. **Grouping**: Packages are grouped by base name after stripping `-debuginfo` and `-debugsource` suffixes
   - Example: `rspamd`, `rspamd-debuginfo`, `rspamd-debugsource` → all grouped as `rspamd`

2. **Sorting**: Within each group, packages are sorted by build time (BUILDTIME metadata) in descending order

3. **Retention**: The newest N builds (EVRs - Epoch:Version-Release) are kept per group

4. **Cleanup**: Old RPM files are removed from disk before creating repository metadata

### Example

With `KEEP_BUILDS=3`:
```
Before retention:
  rspamd-3.10.0-1 (built 2025-01-10)
  rspamd-3.9.0-1  (built 2025-01-05)
  rspamd-3.8.0-1  (built 2024-12-20)
  rspamd-3.7.0-1  (built 2024-12-10)
  rspamd-debuginfo-3.10.0-1
  rspamd-debuginfo-3.9.0-1
  rspamd-debuginfo-3.8.0-1
  rspamd-debuginfo-3.7.0-1

After retention:
  rspamd-3.10.0-1 ✓
  rspamd-3.9.0-1 ✓
  rspamd-3.8.0-1 ✓
  rspamd-3.7.0-1 ✗ REMOVED
  rspamd-debuginfo-3.10.0-1 ✓
  rspamd-debuginfo-3.9.0-1 ✓
  rspamd-debuginfo-3.8.0-1 ✓
  rspamd-debuginfo-3.7.0-1 ✗ REMOVED
```

## Debian Retention (publish_deb.yml)

### How It Works

1. **Grouping**: Packages are grouped by base name after stripping `-dbg` suffix
   - Example: `rspamd`, `rspamd-dbg` → grouped as `rspamd`
   - Example: `rspamd-asan`, `rspamd-asan-dbg` → grouped as `rspamd-asan`

2. **Sorting**: Within each group, packages are sorted by version using `dpkg --compare-versions` in descending order

3. **Retention**: The newest N versions are kept per group

4. **Cleanup**: Old packages are removed from the reprepro index using `removematched`, then a staging directory is built containing only indexed files, which is uploaded with `rsync --delete` to remove unreferenced files from the remote server

### Example

With `KEEP_BUILDS=3`:
```
Before retention:
  rspamd 3.10.0-1
  rspamd-dbg 3.10.0-1
  rspamd 3.9.0-1
  rspamd-dbg 3.9.0-1
  rspamd 3.8.0-1
  rspamd-dbg 3.8.0-1
  rspamd 3.7.0-1
  rspamd-dbg 3.7.0-1
  rspamd-asan 3.10.0-1
  rspamd-asan-dbg 3.10.0-1
  rspamd-asan 3.9.0-1
  rspamd-asan-dbg 3.9.0-1
  rspamd-asan 3.8.0-1
  rspamd-asan-dbg 3.8.0-1

After retention:
  rspamd 3.10.0-1 ✓
  rspamd-dbg 3.10.0-1 ✓
  rspamd 3.9.0-1 ✓
  rspamd-dbg 3.9.0-1 ✓
  rspamd 3.8.0-1 ✓
  rspamd-dbg 3.8.0-1 ✓
  rspamd 3.7.0-1 ✗ REMOVED
  rspamd-dbg 3.7.0-1 ✗ REMOVED
  rspamd-asan 3.10.0-1 ✓
  rspamd-asan-dbg 3.10.0-1 ✓
  rspamd-asan 3.9.0-1 ✓
  rspamd-asan-dbg 3.9.0-1 ✓
  rspamd-asan 3.8.0-1 ✓
  rspamd-asan-dbg 3.8.0-1 ✓
```

Note: Since rspamd and rspamd-asan are built from the same source with synchronized version numbers, even though they're separate groups, they effectively keep the same N versions.

## Key Similarities

Both implementations:
- Use the same `KEEP_BUILDS` variable
- Group related packages together (main + debug symbols)
- Keep the newest N versions/builds
- Remove older versions from the repository
- Handle edge cases correctly (empty lists, single version, etc.)

## Key Differences

| Aspect | RPM | Debian |
|--------|-----|--------|
| Grouping suffix | Strips `-debuginfo`, `-debugsource` | Strips `-dbg` |
| Sorting method | By build time (BUILDTIME metadata) | By version (dpkg --compare-versions) |
| Cleanup method | Direct file deletion | Index removal + staging upload |
| Per-architecture | Yes | No (handled at distribution level) |

These differences are appropriate for the respective package formats and repository structures.

## Testing

The retention logic can be tested using the `test_retention.yml` workflow, which:
1. Downloads pre-built packages from a previous workflow run
2. Publishes them using the publish_rpm.yml and publish_deb.yml workflows
3. Verifies that retention is applied correctly

To test retention:
1. Run a build workflow multiple times to create several versions
2. Trigger the test_retention workflow with a run_id
3. Verify that only the newest N versions are retained in the repository
