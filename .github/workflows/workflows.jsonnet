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

local distribs_deb = [
  key for key in std.objectFields(imagemap)
  if std.startsWith(key, "debian-") || std.startsWith(key, "ubuntu-")
];

local distribs_rpm = [
  key for key in std.objectFields(imagemap)
  if std.startsWith(key, "centos-")
];

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
  local test_steps(arch) = [
    {
      name: 'Check if tests should be skipped',
      id: 'check_skip',
      run: |||
  if [ -z "${{ vars.SKIP_TESTS }}" ] || [ -z "${{ vars.SKIP_TESTS_%s }}" ]; then
    echo "Skipping tests as per configuration.";
    echo skip_tests=true >> $GITHUB_OUTPUT
  else
    echo "Proceeding with tests.";
  fi
||| % std.asciiUpper(std.strReplace(name, '-', '_'))
    },
    {
      name: 'Run tests',
      'if': "${{ ! steps.check_skip.outputs.skip_tests }}",
      uses: './.github/workflows/test_package.yml',
      with: test_with(arch),
    },
  ],
  local maybe_test_job(arch) = {
    maybe_test: {
      ['steps']: test_steps(arch),
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
    needs: name + '-build-X64',
    ['name']: 'maybe skip tests',
    ['runs-on']: 'ubuntu-24.04',
    jobs: maybe_test_job('X64'),
  },
  [name + '-test-ARM64']: {
    needs: name + '-build-ARM64',
    ['name']: 'maybe skip tests',
    ['runs-on']: 'ubuntu-24.04',
    jobs: maybe_test_job('ARM64'),
  },
};

local distribs_deb_test = [
  "%s-test-%s" % [dist, arch]
  for dist in distribs_deb
  for arch in ["X64", "ARM64"]
];

local publish_debian = {
  'debian-publish': {
    //'if': "${{ !vars.SKIP_PUBLISH && !vars.SKIP_PUBLISH_" + std.asciiUpper(std.strReplace(name, '-', '_')) + " }}",
    needs: distribs_deb_test,
    uses: './.github/workflows/publish_deb.yml',
    with: {
      names: std.join(',', distribs_deb),
    },
  },
};

local publish_rpm(name) = {
  [name + '-publish']: {
    'if': '${{ !vars.SKIP_PUBLISH && !vars.SKIP_PUBLISH_' + std.asciiUpper(std.strReplace(name, '-', '_')) + ' }}',
    needs: [name + '-test-ARM64', name + '-test-X64'],
    uses: './.github/workflows/publish_rpm.yml',
    with: {
      name: name,
    },
  },
};

local build_jobs_list = [
  build_test_jobs(p.key, p.value)
  for p in std.objectKeysValues(imagemap)
];

local all_jobs = {
  jobs:
    std.foldl(std.mergePatch, build_jobs_list, {}) +
    std.foldl(std.mergePatch, std.map(publish_rpm, distribs_rpm), {}) +
    publish_debian,
};

{
  'build_test_publish.yml': build_test_publish_pipeline + all_jobs,
}
