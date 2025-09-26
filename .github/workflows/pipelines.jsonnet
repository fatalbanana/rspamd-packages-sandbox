local build_pipeline(name, image) = {
  name: name,
  on: {
    push: {
      tags: [
        'v[0-9]+.[0-9]+.[0-9]+\\+[0-9]+',
      ],
    },
  },
  concurrency: {
    group: 'rspamd-packages-' + name,
    'cancel-in-progress': false,
  },
  jobs: {
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
  },
};

{
  'centos-8.yml': build_pipeline('centos-8', 'oraclelinux:8'),
  'centos-9.yml': build_pipeline('centos-9', 'oraclelinux:9'),
  'centos-10.yml': build_pipeline('centos-10', 'oraclelinux:10'),
  'debian-bullseye.yml': build_pipeline('debian-bullseye', 'debian:bullseye'),
  'debian-bookworm.yml': build_pipeline('debian-bookworm', 'debian:bookworm'),
  'debian-trixie.yml': build_pipeline('debian-trixie', 'debian:trixie'),
  'ubuntu-focal.yml': build_pipeline('ubuntu-focal', 'ubuntu:20.04'),
  'ubuntu-jammy.yml': build_pipeline('ubuntu-jammy', 'ubuntu:22.04'),
  'ubuntu-noble.yml': build_pipeline('ubuntu-noble', 'ubuntu:24.04'),
}
