local distribs_deb = ['debian-bullseye', 'debian-bookworm', 'debian-trixie', 'ubuntu-focal', 'ubuntu-jammy', 'ubuntu-noble'];
local distribs_rpm = ['centos-8', 'centos-9', 'centos-10'];

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

local build_test_jobs(name, image) = {
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
};

local publish_debian = {
  ['debian-publish']: {
    #'if': "${{ !vars.SKIP_PUBLISH && !vars.SKIP_PUBLISH_" + std.asciiUpper(std.strReplace(name, '-', '_')) + " }}",
    # FIXME: all debians
    #needs: [name + '-test-ARM64', name + '-test-X64'],
    uses: './.github/workflows/publish_rpm.yml',
    with: {
      #name: name,
    },
  },
};

local publish_rpm(name) = {
  [name + '-publish']: {
    'if': "${{ !vars.SKIP_PUBLISH && !vars.SKIP_PUBLISH_" + std.asciiUpper(std.strReplace(name, '-', '_')) + " }}",
    needs: [name + '-test-ARM64', name + '-test-X64'],
    uses: './.github/workflows/publish_rpm.yml',
    with: {
      name: name,
    },
  },
};

local imagemap = {
  'centos-8': 'oraclelinux:8',
  'centos-9': 'oraclelinux:9',
  'centos-10': 'oraclelinux:10',
  'debian-bullseye': 'debian:bullseye',
  'debian-bookworm': 'debian:bookworm',
  'debian-trixie': 'debian:trixie',
  'ubuntu-focal': 'ubuntu:20.04',
  'ubuntu-jammy': 'ubuntu:22.04',
  'ubuntu-noble': 'ubuntu:24.04',
};

local build_jobs_list = [
  build_test_jobs(p.key, p.value) for p in std.objectKeysValues(imagemap)
];

local all_jobs = {
  jobs:
    std.foldl(std.mergePatch, build_jobs_list, {}) +
    std.foldl(std.mergePatch, std.map(publish_rpm, distribs_rpm), {}) +
    publish_debian
};

{
  'build_test_publish.yml': build_test_publish_pipeline + all_jobs,
}
