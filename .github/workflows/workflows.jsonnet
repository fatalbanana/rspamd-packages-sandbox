local release_pipeline = {
  name: 'release',
  on: {
    push: {
      tags: [
        'v[0-9]+.[0-9]+.[0-9]+\\+[0-9]+',
      ],
    },
  },
  concurrency: {
    group: 'rspamd-packages-release',
    'cancel-in-progress': false,
  },
};

local nightly_pipeline = {
  name: 'nightly',
  on: {
    schedule: [
      {
        cron: '0 0 * * *',
      },
    ],
    workflow_dispatch: {},
  },
  concurrency: {
    group: 'rspamd-packages-nightly',
    'cancel-in-progress': true,
  },
};

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
  [name + '-build-X64']: {
    'runs-on': 'ubuntu-24.04',
    steps: [
      {
        uses: 'actions/checkout@v4',
      },
      {
        uses: './.github/actions/build_packages',
        with: {
          name: name,
          nightly: '${{ inputs.nightly }}',
        },
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
        uses: './.github/actions/build_packages',
        with: {
          name: name,
          nightly: '${{ inputs.nightly }}',
        },
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
        uses: './.github/actions/test_package',
        with: {
          name: name,
          platform: '${{ runner.arch }}',
        },
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
        uses: './.github/actions/test_package',
        with: {
          name: name,
          platform: '${{ runner.arch }}',
        },
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
    platform_jobs('ubuntu-noble', 'ubuntu:24.04')
};

{
  'build_test_release.yml': build_test_release_pipeline + all_platform_jobs,
}
