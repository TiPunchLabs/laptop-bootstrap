# docker_port_filter

Internal helper: lets only listed IPv4 sources reach one port that Docker publishes
beyond loopback. Not in the playbook on its own: `open_webui` and `portainer`
import it (`import_role`, so the caller's tag applies to every task) with
`tasks_from: present` when their bind address is not `127.*`, and
`tasks_from: absent` otherwise. Its `main` task list only refuses a direct call.

The mechanism, its packet path, event table and limits are documented once, in the
[`open_webui` README](../open_webui/README.md#how-the-filter-works). Per caller:

| Caller | Chain | Unit | Script | Mapping dropped |
|---|---|---|---|---|
| `open_webui` | `OPEN-WEBUI-INGRESS` | `open-webui-firewall.service` | `/usr/local/sbin/open-webui-firewall` | host 3030 → container 8080 |
| `portainer` | `PORTAINER-INGRESS` | `portainer-firewall.service` | `/usr/local/sbin/portainer-firewall` | host 9443 → container 9443 |

Each caller has its own chain, hook, unit and script. A chain returns every packet
that is not its own mapping, so several filters chain in DOCKER-USER without
interfering, and removing one leaves the others in place.

## Parameters

| Variable | Description |
|---|---|
| `docker_port_filter_name` | Short name: unit `<name>-firewall.service`, script `/usr/local/sbin/<name>-firewall` |
| `docker_port_filter_chain` | Dedicated chain, unique per caller |
| `docker_port_filter_label`, `docker_port_filter_owner_role` | Text in the rendered files and messages |
| `docker_port_filter_container_name` | Stopped before the rules change when its host port changes |
| `docker_port_filter_bind_address`, `docker_port_filter_host_port`, `docker_port_filter_container_port` | The published mapping |
| `docker_port_filter_allowed_sources` | IPv4 addresses/CIDRs that pass (required when present) |

`absent` needs only the name and the chain. The caller validates its
own values (IPv4, sources) and keeps the order: filter present → container →
filter absent.
