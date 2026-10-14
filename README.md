# warble-bootstrap

Clone the [warbletech](https://github.com/orgs/warbletech/repositories) org and keep the list of where each platform runs.

This repository does not install a cluster. The Rancher Desktop / k3s model stack is [`bootstrap.sh`](https://github.com/warbletech/warble-harness/blob/main/bootstrap.sh) in [warble-harness](https://github.com/warbletech/warble-harness).

## Clone the org

```bash
./scripts/clone-warbletech.sh --list
./scripts/clone-warbletech.sh
```

The script writes `~/warble-enterprise`. A checkout at the root of that folder can also run `./clone-warbletech.sh`, which calls this script.

## Platforms

See [docs/platforms.md](docs/platforms.md).

Apache-2.0. See [LICENSE](LICENSE).
