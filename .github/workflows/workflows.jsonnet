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

local build_jobs(name, image, nightly) = {
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
          nightly: nightly,
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
          nightly: nightly,
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

local all_build_jobs(nightly) = {
  jobs: 
    build_jobs('centos-8', 'oraclelinux:8', nightly) +
    build_jobs('centos-9', 'oraclelinux:9', nightly) +
    build_jobs('centos-10', 'oraclelinux:10', nightly) +
    build_jobs('debian-bullseye', 'debian:bullseye', nightly) +
    build_jobs('debian-bookworm', 'debian:bookworm', nightly) +
    build_jobs('debian-trixie', 'debian:trixie', nightly) +
    build_jobs('ubuntu-focal', 'ubuntu:20.04', nightly) +
    build_jobs('ubuntu-jammy', 'ubuntu:22.04', nightly) +
    build_jobs('ubuntu-noble', 'ubuntu:24.04', nightly)
};

{
  'nightly.yml': nightly_pipeline + all_build_jobs(true),
  'release.yml': release_pipeline + all_build_jobs(false),
}
