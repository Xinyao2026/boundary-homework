# Boundary Homework Beginner Guide

这份文档面向刚开始学习 Boundary、Vault、GCP Private Service Connect 和 HCP Terraform 的同学。它不是只告诉你“点哪里”，而是解释这个项目为什么这样设计、每个工具负责什么、关键代码在哪里、部署和验证时应该看什么。

## 1. 项目目标

这个 homework 的目标是搭建一条安全 SSH 访问链路：

```text
你的电脑 / Boundary Desktop
  -> HCP Boundary control plane
  -> ingress worker
  -> GCP Private Service Connect endpoint
  -> egress worker
  -> GCE target VM
  -> Vault SSH certificate credential injection
```

完成后，用户不需要知道目标 VM 的私钥，也不需要直接暴露 VM 公网 SSH。用户在 Boundary Desktop 里点击 `Connect`，Boundary 负责授权、选择 worker、从 Vault 获取短期 SSH certificate，然后通过 worker 链路连接到目标 VM。

最终验证结果应该类似：

```bash
whoami
# boundary

hostname
# boundary-homework-target-vm

ip addr show
# ens4: 10.30.1.6/32
```

## 2. 先认识几个核心概念

### Boundary

Boundary 是访问控制系统。它不直接保存长期 SSH 私钥，而是根据用户权限决定谁能访问哪个 target。

在本项目里 Boundary 负责：

- 管理 org、project、target、host catalog、role、group。
- 让用户通过 Boundary Desktop 发起 SSH session。
- 按 worker filter 选择 ingress worker 和 egress worker。
- 调用 Vault credential library 获取短期 SSH certificate。

### Worker

Worker 是 Boundary 的网络转发节点。你可以把它理解为 Boundary 的“接力站”。

本项目有两类 worker：

- ingress worker：靠近用户侧/Boundary control plane，接收来自客户端的会话流量。
- egress worker：靠近目标 VM，负责连接目标 VM 的 SSH 端口。

题目要求 egress worker 不能直接连 HCP Boundary controller，而是要通过 Private Service Connect 连 ingress worker。

### HCP Boundary

HCP Boundary 是 HashiCorp 托管的 Boundary control plane。我们不用自己部署 controller，只需要部署 self-managed workers 和配置 Boundary 资源。

### HCP Vault Dedicated

Vault 负责签发短期 SSH certificate。

本项目里 Vault 负责：

- 创建 `admin/boundary-test` namespace。
- 开启 SSH secrets engine。
- 生成 SSH CA。
- 创建 SSH signing role。
- 给 Boundary 创建一个受限 token，让 Boundary 只能请求签发 SSH certificate。

### Private Service Connect

Private Service Connect，简称 PSC，是 GCP 的私有服务连接能力。

本项目里：

- ingress VPC 发布一个 PSC service attachment。
- egress VPC 创建一个 PSC endpoint。
- egress worker 通过 PSC endpoint `10.30.1.2:9202` 连接 ingress worker。

验证 PSC 成功时应该看到：

```text
pscConnectionStatus: ACCEPTED
IPAddress: 10.30.1.2
```

### HCP Terraform

HCP Terraform 负责远程运行 Terraform。

本项目使用两个 workspace：

- `boundary-homework-ingress`
- `boundary-homework-egress-vault`

我们把它拆成两个 workspace 是因为 ingress 先创建 PSC service attachment，egress 再读取 ingress 的 output 来创建 PSC endpoint。

## 3. 工具分工

| 工具 | 在项目中的作用 |
| --- | --- |
| GitHub | 保存 Terraform 代码，触发 HCP Terraform runs。 |
| HCP Terraform | 执行 Terraform plan/apply/destroy，保存 state。 |
| Terraform Google provider | 创建 GCP VPC、VM、firewall、NAT、PSC 资源。 |
| Terraform Boundary provider | 创建 Boundary worker registration、scope、target、role、credential store。 |
| Terraform Vault provider | 创建 Vault namespace、SSH engine、policy、token。 |
| Terraform TFE provider | 在 egress workspace 中读取 ingress workspace outputs。 |
| HCP Boundary | 托管 Boundary control plane。 |
| Boundary Desktop | 用户侧客户端，用来发起 SSH session。 |
| HCP Vault Dedicated | 托管 Vault，用于 SSH certificate signing。 |
| GCP | 运行 self-managed workers、目标 VM、PSC 网络资源。 |

## 4. 代码结构

仓库结构：

```text
boundary-homework/
  README.md
  docs/
    boundary-homework-beginner-guide-zh.md
  terraform/
    workspaces/
      ingress/
        main.tf
        variables.tf
        outputs.tf
        versions.tf
        templates/
          ingress-worker-startup.sh.tftpl
      egress/
        main.tf
        variables.tf
        outputs.tf
        versions.tf
        templates/
          egress-worker-startup.sh.tftpl
          target-vm-startup.sh.tftpl
```

`ingress` workspace 只负责 ingress 侧：

- ingress VPC/subnet
- ingress worker VM
- Boundary ingress worker registration
- GCP internal load balancer
- PSC service attachment

`egress` workspace 负责剩下的部分：

- egress VPC/subnet/NAT
- PSC endpoint
- egress worker VM
- target VM
- Boundary org/project/target/host catalog/group/role
- Vault namespace/SSH engine/policy/token
- Boundary Vault credential store/library

## 5. 架构图

```text
                     HCP Boundary
                  control plane / UI
                          |
                          |
                 worker registration
                          |
                          v
Your laptop
Boundary Desktop
    |
    | SSH session
    v
ingress worker VM
GCP ingress VPC
port 9202
    |
    | published through internal TCP LB
    v
PSC service attachment
    |
    | Private Service Connect
    v
PSC endpoint 10.30.1.2
GCP egress VPC
    |
    v
egress worker VM
    |
    | SSH port 22
    v
target VM 10.30.1.6

Vault signs a short-lived SSH certificate during the session.
```

## 6. Workspace 1: ingress

代码路径：

```text
terraform/workspaces/ingress/main.tf
```

### Provider

```hcl
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "boundary" {
  addr                   = var.boundary_addr
  auth_method_id         = var.boundary_auth_method_id
  auth_method_login_name = var.boundary_login_name
  auth_method_password   = var.boundary_password
}
```

这里有两个 provider：

- `google` 用来创建 GCP 资源。
- `boundary` 用来在 HCP Boundary 中注册 worker。

### GCP network

```hcl
resource "google_compute_network" "ingress" {
  name                    = "${var.prefix}-ingress-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "ingress" {
  name          = "${var.prefix}-ingress-subnet"
  ip_cidr_range = var.ingress_subnet_cidr
  network       = google_compute_network.ingress.id
  region        = var.region
}
```

这段创建 ingress VPC 和子网。

### PSC NAT subnet

```hcl
resource "google_compute_subnetwork" "psc_nat" {
  name          = "${var.prefix}-psc-nat-subnet"
  ip_cidr_range = var.psc_nat_subnet_cidr
  network       = google_compute_network.ingress.id
  region        = var.region
  purpose       = "PRIVATE_SERVICE_CONNECT"
}
```

这个 subnet 不是给 VM 用的，而是给 PSC service attachment 做 NAT 用的。

### Boundary ingress worker registration

```hcl
resource "boundary_worker" "ingress" {
  scope_id    = "global"
  name        = "${var.prefix}-ingress-worker"
  description = "Ingress worker for Boundary homework"
}
```

这会在 Boundary 中创建一个 worker registration，并产生 activation token。VM 启动脚本会把这个 token 写入 worker 配置。

### Ingress worker VM

```hcl
resource "google_compute_instance" "ingress_worker" {
  name         = "${var.prefix}-ingress-worker"
  machine_type = "e2-small"
  zone         = var.zone
  tags         = ["boundary-ingress-worker"]

  metadata_startup_script = templatefile("${path.module}/templates/ingress-worker-startup.sh.tftpl", {
    boundary_cluster_id = var.boundary_cluster_id
    boundary_version    = var.boundary_version
    activation_token    = boundary_worker.ingress.controller_generated_activation_token
    public_addr         = "${google_compute_address.ingress_worker_public.address}:9202"
    worker_name         = "${var.prefix}-ingress-worker"
  })
}
```

VM 启动时会安装 Boundary binary，并生成 `/etc/boundary.d/worker.hcl`。

对应模板：

```text
terraform/workspaces/ingress/templates/ingress-worker-startup.sh.tftpl
```

关键配置：

```hcl
hcp_boundary_cluster_id = "${boundary_cluster_id}"

listener "tcp" {
  purpose = "proxy"
  address = "0.0.0.0:9202"
}

worker {
  public_addr = "${public_addr}"
  controller_generated_activation_token = "${activation_token}"

  tags {
    type = ["ingress"]
    env  = ["boundary-homework"]
    name = ["${worker_name}"]
  }
}
```

解释：

- `listener "tcp"` 让 worker 在 9202 端口接收 proxy traffic。
- `hcp_boundary_cluster_id` 表示这是 HCP Boundary worker。
- `public_addr` 让 Boundary client 能找到这个 ingress worker。
- tags 后面会被 target 的 worker filter 用来筛选。

### Internal load balancer

```hcl
resource "google_compute_instance_group" "ingress_workers" {
  name = "${var.prefix}-ingress-workers"

  instances = [
    google_compute_instance.ingress_worker.self_link,
  ]
}

resource "google_compute_region_backend_service" "ingress_proxy" {
  name                  = "${var.prefix}-ingress-proxy"
  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL"
}

resource "google_compute_forwarding_rule" "ingress_proxy" {
  name                  = "${var.prefix}-ingress-proxy-ilb"
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.ingress_proxy.id
  ip_protocol           = "TCP"
  all_ports             = true
  allow_global_access   = true
}
```

PSC service attachment 不能直接指向 VM，它需要指向一个 supported load balancer forwarding rule。这里用 internal TCP load balancer 把流量转给 ingress worker。

### PSC service attachment

```hcl
resource "google_compute_service_attachment" "ingress_proxy" {
  name                  = "${var.prefix}-ingress-psc-sa"
  connection_preference = "ACCEPT_AUTOMATIC"
  nat_subnets           = [google_compute_subnetwork.psc_nat.id]
  target_service        = google_compute_forwarding_rule.ingress_proxy.id
}
```

这就是“服务发布方”。egress VPC 会通过这个 service attachment 创建 consumer endpoint。

### Ingress outputs

```hcl
output "psc_service_attachment_self_link" {
  value = google_compute_service_attachment.ingress_proxy.self_link
}
```

egress workspace 会读取这个 output。

## 7. Workspace 2: egress + Vault + Boundary resources

代码路径：

```text
terraform/workspaces/egress/main.tf
```

### Providers

```hcl
provider "google" {}
provider "boundary" {}
provider "tfe" {}
provider "vault" {}
provider "vault" {
  alias = "boundary"
}
```

这里比 ingress 多了两个 provider：

- `tfe` 用来读取 ingress workspace 的 outputs。
- `vault` 用来配置 HCP Vault Dedicated。

两个 Vault provider 的区别：

- 默认 `vault` provider 使用 `admin` namespace，用来创建 child namespace。
- `vault.boundary` provider 使用 `admin/boundary-test` namespace，用来配置 SSH engine 和 policy。

### 读取 ingress outputs

```hcl
data "tfe_outputs" "ingress" {
  count        = var.psc_service_attachment_self_link == null ? 1 : 0
  organization = var.tfc_organization
  workspace    = var.ingress_workspace_name
}
```

这段让 egress workspace 自动拿到 ingress workspace 创建出来的 PSC service attachment self link。

### Local values

```hcl
locals {
  psc_service_attachment_self_link = var.psc_service_attachment_self_link == null ? data.tfe_outputs.ingress[0].nonsensitive_values.psc_service_attachment_self_link : var.psc_service_attachment_self_link
  egress_worker_upstream_addr      = var.egress_worker_upstream_addr == null ? "${google_compute_address.psc_endpoint.address}:9202" : var.egress_worker_upstream_addr

  vault_full_boundary_namespace = "${var.vault_admin_namespace}/${var.vault_boundary_namespace}"
  vault_ssh_signing_path        = "${var.vault_ssh_mount_path}/sign/${var.vault_ssh_role_name}"
}
```

关键点：

- `egress_worker_upstream_addr` 默认是 PSC endpoint 地址，例如 `10.30.1.2:9202`。
- 这是题目要求的核心：egress worker 通过 PSC endpoint 连接 ingress worker。

### Egress VPC 和 NAT

```hcl
resource "google_compute_network" "egress" {}
resource "google_compute_subnetwork" "egress" {}
resource "google_compute_router" "egress" {}
resource "google_compute_router_nat" "egress" {}
```

egress worker 和 target VM 都在 egress VPC 里。NAT 用于让 VM 下载 Boundary binary、apt packages 等。

### PSC endpoint

```hcl
resource "google_compute_address" "psc_endpoint" {
  name         = "${var.prefix}-psc-endpoint-ip"
  address_type = "INTERNAL"
}

resource "google_compute_forwarding_rule" "psc_endpoint" {
  name                    = "${var.prefix}-psc-endpoint"
  ip_address              = google_compute_address.psc_endpoint.id
  target                  = local.psc_service_attachment_self_link
  load_balancing_scheme   = ""
  allow_psc_global_access = false
}
```

这里创建 consumer-side PSC endpoint。最终 output 中应该看到：

```text
psc_endpoint_ip = 10.30.1.2
egress_worker_upstream_addr = 10.30.1.2:9202
```

如果 PSC endpoint 状态是 `CLOSED`，说明曾经连接的 service attachment 被删除过。代码里有一个重建触发器：

```hcl
resource "terraform_data" "psc_endpoint_recreate" {
  triggers_replace = [var.psc_endpoint_recreate_revision]
}
```

需要重建 endpoint 时，bump `psc_endpoint_recreate_revision` 即可。

### Boundary egress worker registration

```hcl
resource "boundary_worker" "egress" {
  scope_id    = "global"
  name        = "${var.prefix}-egress-worker"
}
```

这会创建 egress worker registration。

### Egress worker VM

```hcl
resource "google_compute_instance" "egress_worker" {
  name = "${var.prefix}-egress-worker"

  metadata_startup_script = templatefile("${path.module}/templates/egress-worker-startup.sh.tftpl", {
    boundary_version = var.boundary_version
    activation_token = boundary_worker.egress.controller_generated_activation_token
    upstream_addr    = local.egress_worker_upstream_addr
    worker_name      = "${var.prefix}-egress-worker"
  })
}
```

对应模板：

```text
terraform/workspaces/egress/templates/egress-worker-startup.sh.tftpl
```

关键配置：

```hcl
worker {
  auth_storage_path = "/var/lib/boundary"
  initial_upstreams = ["${upstream_addr}"]

  controller_generated_activation_token = "${activation_token}"

  tags {
    type = ["egress"]
    env  = ["boundary-homework"]
    name = ["${worker_name}"]
  }
}
```

解释：

- `initial_upstreams` 指向 ingress worker 的上游地址。
- 在本项目中，这个地址必须是 PSC endpoint，例如 `10.30.1.2:9202`。
- 如果这里变成公网 IP，就不符合题目要求。

### Boundary org / project / target

```hcl
resource "boundary_scope" "org" {
  name = var.boundary_org_name
}

resource "boundary_scope" "project" {
  scope_id = boundary_scope.org.id
  name     = var.boundary_project_name
}
```

作业要求的名称：

- Org: `Hashicorp-org`
- Project: `Hashicorp-project`

Host catalog 和 host：

```hcl
resource "boundary_host_catalog_static" "gce" {
  name = var.boundary_host_catalog_name
}

resource "boundary_host_static" "target_vm" {
  name    = var.boundary_host_name
  address = google_compute_instance.target_vm.network_interface[0].network_ip
}
```

作业要求的名称：

- Host Catalog: `hashicorp-catalog-boundary`
- Host: `ssh-target-hashicorp`

Target：

```hcl
resource "boundary_target" "ssh" {
  type         = "ssh"
  name         = var.boundary_target_name
  default_port = 22

  ingress_worker_filter = "\"/name\" == \"${var.prefix}-ingress-worker\""
  egress_worker_filter  = "\"/name\" == \"${var.prefix}-egress-worker\""

  injected_application_credential_source_ids = var.enable_vault_integration ? [
    boundary_credential_library_vault_ssh_certificate.boundary[0].id,
  ] : []
}
```

这里有三个重点：

- `type = "ssh"` 表示这是 SSH target。
- `ingress_worker_filter` 指定使用 ingress worker。
- `egress_worker_filter` 指定使用 egress worker。
- `injected_application_credential_source_ids` 绑定 Vault SSH credential library。

### Boundary group 和 role

```hcl
resource "boundary_group" "compute_ssh" {
  name       = var.boundary_compute_group_name
  member_ids = var.boundary_compute_group_member_ids
}

resource "boundary_role" "compute_ssh" {
  name          = var.boundary_compute_role_name
  principal_ids = [boundary_group.compute_ssh.id]

  grant_strings = [
    "ids=*;type=target;actions=list,read,authorize-session",
    "ids=*;type=session;actions=list,read,cancel:self",
  ]
}
```

作业要求的名称：

- Group: `compute_ssh_groups`
- Role: `compute_ssh_role`

`grant_strings` 是 Boundary 权限规则。这里允许 group 成员 list/read target，并发起 session。

### Vault namespace 和 SSH engine

```hcl
resource "vault_namespace" "boundary" {
  path = var.vault_boundary_namespace
}

resource "vault_mount" "ssh_client_signer" {
  provider = vault.boundary
  path     = var.vault_ssh_mount_path
  type     = "ssh"
}
```

本项目创建：

- Namespace: `admin/boundary-test`
- SSH engine path: `ssh-client-signer`

### Vault SSH CA 和 signing role

```hcl
resource "vault_ssh_secret_backend_ca" "boundary" {
  backend              = vault_mount.ssh_client_signer[0].path
  generate_signing_key = true
  key_type             = "ed25519"
}

resource "vault_ssh_secret_backend_role" "boundary_client" {
  name                    = var.vault_ssh_role_name
  backend                 = vault_mount.ssh_client_signer[0].path
  key_type                = "ca"
  allow_user_certificates = true
  allowed_users           = var.target_ssh_user
  default_user            = var.target_ssh_user
  allowed_extensions      = "permit-pty"
  ttl                     = "30m"
  max_ttl                 = "1h"
}
```

Vault 会生成一个 SSH CA，并允许签发用户为 `boundary` 的短期 SSH certificate。

### Vault token 给 Boundary 使用

```hcl
resource "vault_policy" "boundary_controller" {}
resource "vault_policy" "boundary_ssh" {}

resource "vault_token" "boundary" {
  policies          = [vault_policy.boundary_controller[0].name, vault_policy.boundary_ssh[0].name]
  no_default_policy = true
  no_parent         = true
  renewable         = true
  period            = "24h"
}
```

这不是 HCP Terraform 用来配置 Vault 的 admin token，而是 Terraform 创建出来给 Boundary 使用的受限 token。

Boundary 用它去 Vault 请求 SSH certificate。

### Boundary Vault credential store 和 library

```hcl
resource "boundary_credential_store_vault" "boundary" {
  name      = var.boundary_vault_credential_store_name
  address   = var.vault_addr
  namespace = local.vault_full_boundary_namespace
  token     = vault_token.boundary[0].client_token
}

resource "boundary_credential_library_vault_ssh_certificate" "boundary" {
  name     = var.boundary_vault_credential_library_name
  path     = local.vault_ssh_signing_path
  username = var.target_ssh_user
  key_type = "ed25519"
  ttl      = "30m"
}
```

作业要求的名称：

- Credential Store: `vault-credential-store`
- Credential Library: `vault_ssh_boundary`

连接 target 时，Boundary 会用 credential library 调 Vault 的 SSH signing endpoint。

### Target VM SSH trust

代码路径：

```text
terraform/workspaces/egress/templates/target-vm-startup.sh.tftpl
```

关键配置：

```bash
cat >/etc/ssh/trusted-user-ca-keys.pem <<'SSH_CA'
${trusted_user_ca_public_key}
SSH_CA

cat >/etc/ssh/sshd_config.d/99-boundary-vault-ca.conf <<'SSHD_CONFIG'
TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem
SSHD_CONFIG
```

这一步让目标 VM 信任 Vault 生成的 SSH CA。之后只要 Vault 签发的 certificate 合法，SSH server 就允许登录 `boundary` 用户。

## 8. HCP Terraform variables

### 两个 workspace 都需要的变量

Terraform variables：

- `boundary_auth_method_id`
- `boundary_login_name`
- `boundary_password`，Sensitive

GCP dynamic credentials 通常放在 variable set 中：

- `TFC_GCP_PROVIDER_AUTH=true`
- `TFC_GCP_PROJECT_NUMBER=<GCP project number>`
- `TFC_GCP_WORKLOAD_PROVIDER_NAME=<Workload Identity provider resource name>`
- `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL=<Terraform run service account email>`
- `TFC_GCP_PRINCIPAL_TYPE=service_account`

如果使用 `tfe_outputs`，egress workspace 还需要能访问 HCP Terraform API：

- `TFE_TOKEN`，Environment variable，Sensitive

### egress workspace 额外变量

Vault integration 需要：

- `enable_vault_integration=true`
- `vault_addr=<HCP Vault public URL，包括 :8200>`
- `vault_token=<HCP Vault admin token>`，Sensitive
- `vault_admin_namespace=admin`
- `vault_boundary_namespace=boundary-test`

如果 `vault_token` 过期，常见错误是：

```text
failed to lookup token
Code: 403
permission denied
invalid token
```

解决方法是重新在 HCP Vault Dedicated 生成 admin token，并更新 HCP Terraform 变量。

## 9. 部署顺序

### 第一步：部署 ingress

HCP Terraform workspace：

```text
boundary-homework-ingress
```

Working directory：

```text
terraform/workspaces/ingress
```

成功后应该有 outputs：

- `ingress_worker_public_ip`
- `ingress_worker_internal_ip`
- `psc_service_attachment_self_link`

Boundary Workers 页面应该看到：

- `boundary-homework-ingress-worker`
- `Release Version = Boundary v0.21.3+ent`
- `Last Seen` 是近期时间

### 第二步：部署 egress + Vault

HCP Terraform workspace：

```text
boundary-homework-egress-vault
```

Working directory：

```text
terraform/workspaces/egress
```

成功后应该有 outputs：

```text
psc_endpoint_ip = 10.30.1.2
egress_worker_upstream_addr = 10.30.1.2:9202
target_vm_internal_ip = 10.30.1.6
vault_boundary_namespace = admin/boundary-test
```

Boundary Workers 页面应该看到：

- `boundary-homework-egress-worker`
- `Release Version = Boundary v0.21.3+ent`
- `Last Seen` 是近期时间

## 10. 验证步骤

### 验证 PSC

在 Cloud Shell 中：

```bash
PROJECT_ID="hc-82e4f16a11f547f4b83356467c7"
REGION="asia-northeast1"

gcloud compute forwarding-rules describe boundary-homework-psc-endpoint \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format="yaml(name,IPAddress,pscConnectionStatus,target)"
```

期望：

```text
IPAddress: 10.30.1.2
pscConnectionStatus: ACCEPTED
```

如果是 `CLOSED`，说明 service attachment 可能被删除并重建过，consumer endpoint 需要重建。可以 bump：

```hcl
psc_endpoint_recreate_revision
```

然后重新 apply egress workspace。

### 验证 egress worker 能连 PSC endpoint

```bash
PROJECT_ID="hc-82e4f16a11f547f4b83356467c7"
ZONE="asia-northeast1-a"

gcloud compute ssh boundary-homework-egress-worker \
  --project="$PROJECT_ID" \
  --zone="$ZONE" \
  --tunnel-through-iap \
  --command='
    sudo systemctl is-active boundary
    timeout 5 bash -c "cat < /dev/null > /dev/tcp/10.30.1.2/9202" && echo "psc_reachable=yes" || echo "psc_reachable=no"
    sudo journalctl -u boundary -n 40 --no-pager
  '
```

期望：

```text
active
psc_reachable=yes
```

### 验证 Boundary Desktop SSH

在 Boundary Desktop 中打开 target：

```text
ssh-hashicorp-target
```

点击 `Connect`，然后用它提供的命令：

```bash
ssh 127.0.0.1 -p <local-port> -o NoHostAuthenticationForLocalhost=yes
```

注意是 `ssh`，不是 `sh`。

登录后运行：

```bash
whoami
hostname
ip addr show
```

期望：

```text
boundary
boundary-homework-target-vm
10.30.1.6
```

### 验证 Vault credential injection

在 Boundary Admin UI 中检查：

- Credential Store: `vault-credential-store`
- Credential Library: `vault_ssh_boundary`
- Target: `ssh-hashicorp-target`
- Target 的 Injected Application Credentials 包含 `vault_ssh_boundary`

这说明 Boundary 连接 SSH target 时会向 Vault 请求短期 SSH certificate。

## 11. 常见问题

### No ingress workers can handle this session

常见原因：

- ingress worker 没有上线。
- target 的 `ingress_worker_filter` 和 worker tags 不匹配。
- worker record 存在，但 worker 进程没有成功连上 HCP Boundary。

检查：

```bash
sudo systemctl is-active boundary
sudo journalctl -u boundary -n 80 --no-pager
```

### No egress workers can handle this session

常见原因：

- egress worker 没有上线。
- `initial_upstreams` 无法连接 PSC endpoint。
- PSC endpoint 是 `CLOSED`。
- target 的 `egress_worker_filter` 和 worker tags 不匹配。

检查：

```bash
gcloud compute forwarding-rules describe boundary-homework-psc-endpoint \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format="yaml(name,IPAddress,pscConnectionStatus,target)"
```

### PSC endpoint 是 CLOSED

`CLOSED` 通常说明服务发布方的 service attachment 曾经被删除，consumer endpoint 连接关闭。这个状态不会靠等待自动恢复。

解决：

1. 确认 ingress workspace apply 成功，service attachment 存在。
2. bump `psc_endpoint_recreate_revision`。
3. apply egress workspace，强制替换 `google_compute_forwarding_rule.psc_endpoint`。
4. 重新检查 `pscConnectionStatus: ACCEPTED`。

### Vault token invalid

错误：

```text
failed to lookup token
permission denied
invalid token
```

原因：

- HCP Terraform 中的 `vault_token` 过期或被 revoke。

解决：

1. 在 HCP Vault Dedicated 生成新的 admin token。
2. 更新 egress workspace 的 `vault_token`。
3. 重新 apply。

### Terraform run 提示找不到 .tf 文件

原因通常是 HCP Terraform workspace 的 working directory 设置错了。

正确设置：

```text
boundary-homework-ingress:
terraform/workspaces/ingress

boundary-homework-egress-vault:
terraform/workspaces/egress
```

## 12. 销毁顺序

如果要删除资源，建议顺序如下：

1. Boundary Desktop 中 End session。
2. HCP Terraform destroy `boundary-homework-egress-vault`。
3. HCP Terraform destroy `boundary-homework-ingress`。
4. 删除 HCP Vault Dedicated cluster。
5. 删除 HCP Boundary cluster。
6. GCP 临时 project 可以等自动回收。

不要先删 Vault 或 Boundary cluster，否则 Terraform destroy 可能因为 provider 连不上而失败。

## 13. Session recording 是否需要做

本 homework 的核心已经是：

- Boundary SSH target。
- Self-managed ingress/egress workers。
- GCP Private Service Connect。
- HCP Vault SSH certificate injection。
- Boundary Desktop 成功 SSH 到 GCE VM。

Session recording 是额外功能，不是本项目核心完成条件。

如果要做 session recording，需要：

- HCP Boundary Plus 或 Boundary Enterprise。
- Self-managed worker recording storage path。
- S3 或 S3-compatible object storage。
- target 开启 session recording。

如果当前 HCP UI 没有 Plus tier 选项，就可以在文档里说明：当前环境不支持 session recording，因此未实现。

## 14. 你应该记住的核心逻辑

这个项目最重要的不是某一行 Terraform，而是下面这条逻辑：

```text
Boundary 决定谁能访问什么
Vault 提供短期 SSH certificate
GCP PSC 提供私有网络连接
Worker 负责把用户流量转发到目标 VM
HCP Terraform 把所有资源用代码稳定地创建出来
```

再换一种说法：

```text
用户不拿长期私钥
目标 VM 不暴露公网 SSH
访问路径由 Boundary 控制
凭据由 Vault 临时签发
网络路径通过 PSC 私有连接
```

这就是这个 homework 想让你掌握的核心。
