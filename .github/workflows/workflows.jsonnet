local build_test_publish_pipeline = {
  name: 'build_test_publish',
  on: {
    workflow_call: {
      inputs: {
        nightly: {
          required: false,
          type: 'string',
        },
      },
    },
  },
};

local platform_jobs(name, image) = {
  local build_with(arch) = {
    name: name,
    nightly: '${{ inputs.nightly }}',
    platform: arch,
  },
  local test_with(arch) = {
    name: name,
    image: image,
    platform: arch,
    revision: '${{ needs.' + name + '-build-' + arch + '.outputs.revision }}',
  },
  local publish_workflow = if std.startsWith(name, 'centos-') then './.github/workflows/publish_rpm.yml' else './.github/workflows/publish_deb.yml',
  local publish_step(arch) = {
    'if': "${{ (success() || needs." + name + "-test-" + arch + ".result == 'skipped') && (!vars.SKIP_PUBLISH && !vars.SKIP_PUBLISH_" + std.asciiUpper(std.strReplace(name, '-', '_')) + ") }}",
    needs: [name + '-test-' + arch],
    uses: publish_workflow,
    with: {
      name: name,
      platform: arch,
    },
  },
  [name + '-build-X64']: {
    uses: './.github/workflows/build_packages.yml',
    with: build_with('X64'),
  },
  [name + '-build-ARM64']: {
    uses: './.github/workflows/build_packages.yml',
    with: build_with('ARM64'),
  },
  [name + '-test-X64']: {
    'if': '${{ !vars.SKIP_TESTS && !vars.SKIP_TESTS_' + std.asciiUpper(std.strReplace(name, '-', '_')) + ' }}',
    needs: name + '-build-X64',
    uses: './.github/workflows/test_package.yml',
    with: test_with('X64'),
  },
  [name + '-test-ARM64']: {
    'if': '${{ !vars.SKIP_TESTS && !vars.SKIP_TESTS_' + std.asciiUpper(std.strReplace(name, '-', '_')) + ' }}',
    needs: name + '-build-ARM64',
    uses: './.github/workflows/test_package.yml',
    with: test_with('ARM64'),
  },
  [name + '-publish-X64']: publish_step('X64'),
  [name + '-publish-ARM64']: publish_step('ARM64'),
};

local all_platform_jobs = {
  jobs:
    platform_jobs('centos-8', 'oraclelinux:8') +
    platform_jobs('centos-9', 'oraclelinux:9') +
    platform_jobs('centos-10', 'oraclelinux:10') +
    platform_jobs('debian-bullseye', 'debian:bullseye') +
    platform_jobs('debian-bookworm', 'debian:bookworm') +
    platform_jobs('debian-trixie', 'debian:trixie') +
    platform_jobs('ubuntu-focal', 'ubuntu:20.04') +
    platform_jobs('ubuntu-jammy', 'ubuntu:22.04') +
    platform_jobs('ubuntu-noble', 'ubuntu:24.04'),
};

{
  'build_test_publish.yml': build_test_publish_pipeline + all_platform_jobs,
}
