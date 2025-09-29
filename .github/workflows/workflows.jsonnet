local build_test_release_pipeline = {
  name: 'build_test_release',
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
  local build_with = {
    name: name,
    nightly: '${{ inputs.nightly }}',
  },
  local test_with(arch) = {
    name: name,
    platform: '${{ runner.arch }}',
    revision: '${{ needs.' + name + '-build-' + arch + '.outputs.revision }}',
  },
  [name + '-build-X64']: {
    'runs-on': 'ubuntu-24.04',
    'outputs': {
      revision: '${{ steps.build_packages.outputs.revision }}',
    },
    steps: [
      {
        uses: 'actions/checkout@v4',
      },
      {
        id: 'build_packages',
        uses: '${{ github.repository }}/.github/workflows/build_packages.yml@${{ github.sha }}',
        with: build_with,
      },
    ],
  },
  [name + '-build-ARM64']: {
    'runs-on': 'ubuntu-24.04-arm',
    steps: [
      {
        uses: 'actions/checkout@v4',
      },
      {
        uses: '${{ github.repository }}/.github/workflows/build_packages.yml@${{ github.sha }}',
        with: build_with,
      },
    ],
  },
  [name + '-test-X64']: {
    container: {
      image: image,
    },
    needs: name + '-build-X64',
    'runs-on': 'ubuntu-24.04',
    steps: [
      {
        uses: 'actions/checkout@v4',
      },
      {
        uses: '${{ github.repository }}/.github/workflows/test_package.yml@${{ github.sha }}',
        with: test_with('X64'),
      },
    ],
  },
  [name + '-test-ARM64']: {
    container: {
      image: image,
    },
    needs: name + '-build-ARM64',
    'runs-on': 'ubuntu-24.04-arm',
    steps: [
      {
        uses: 'actions/checkout@v4',
      },
      {
        uses: '${{ github.repository }}/.github/workflows/test_package.yml@${{ github.sha }}',
        with: test_with('ARM64'),
      },
    ],
  },
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
  'build_test_release.yml': build_test_release_pipeline + all_platform_jobs,
}
