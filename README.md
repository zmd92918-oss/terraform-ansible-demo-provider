# Terraform + Ansible Demo（provider-ansible 版本）

在 Terraform state 里管理 Ansible 的执行结果。相比上一版（`null_resource` +
`local-exec`），这一版用官方 `ansible/ansible` provider 的 `ansible_host` /
`ansible_playbook` **resource** 来跑 Ansible，Ansible 的执行结果会作为
resource 属性写进 `terraform.tfstate`，而不是只打印在终端日志里就没了。

## 和上一版的核心区别

| | null_resource 版 | provider-ansible 版（这一版） |
|---|---|---|
| Ansible 怎么被调用 | `local-exec` 里跑一条 shell 命令 | 作为 `ansible_playbook` resource 被 Terraform 原生管理 |
| 执行结果记录在 state 里 | ❌ 只记录一个 trigger 的 hash | ✅ `ansible_playbook_stdout`、`ansible_playbook_stderr` 都在 state 里 |
| `terraform plan` 能看出变化 | ❌ | ✅（resource 会显示会被创建/replayable 触发） |
| 拿执行结果做断言 | 需要额外脚本 parse 终端输出 | 直接 `terraform output ansible_playbook_stdout` 或在别的 resource 里引用 |
| Inventory 管理方式 | 手写 `.ini` 模板文件 | `ansible_host` resource，变量直接写在 `.tf` 里，也进 state |

## 前置条件

跟上一版完全一样：本地要有 Terraform、Ansible（`ansible-playbook` 命令能跑）、
AWS CLI 配置好、SSH 密钥对已生成。这个 provider 底层还是调用你本地装好的
`ansible-playbook`，只是把执行过程和结果包装成了 Terraform resource。

## 使用步骤

```bash
cp terraform.tfvars.example terraform.tfvars   # 按需修改
terraform init      # 会额外下载 ansible/ansible provider
terraform plan
terraform apply
```

## 从 State 里看 Ansible 执行结果（这是这一版的重点）

`apply` 完成后，直接看 output：

```bash
terraform output ansible_playbook_stdout
```

或者直接从 state 里查这个 resource 的完整属性：

```bash
terraform state show ansible_playbook.web
```

会看到类似：

```
resource "ansible_playbook" "web" {
    id                       = "..."
    name                     = "xx.xx.xx.xx"
    playbook                 = "./ansible/playbook.yml"
    replayable               = true
    ansible_playbook_stdout  = <<-EOT
        PLAY [Install and start Nginx] ***
        TASK [Gathering Facts] ***
        ok: [xx.xx.xx.xx]
        ...
        PLAY RECAP ***
        xx.xx.xx.xx : ok=5 changed=3 unreachable=0 failed=0 ...
    EOT
    ansible_playbook_stderr  = ""
}
```

这就是"Terraform state 管理 Ansible"的直接体现：**Ansible 到底跑了什么、
结果如何，不再是一次性打印在终端就消失的日志，而是变成了可查询、可在其他
地方引用的 Terraform 数据。**

## 联合测试怎么用上这个特性

比如写个简单的 bash 断言脚本，检查 playbook 是否真的成功（`failed=0`）：

```bash
#!/bin/bash
set -e
terraform apply -auto-approve

STDOUT=$(terraform output -raw ansible_playbook_stdout)

if echo "$STDOUT" | grep -q "failed=0"; then
  echo "✅ Ansible playbook 执行成功"
else
  echo "❌ Ansible playbook 执行失败"
  echo "$STDOUT"
  exit 1
fi

curl -sf http://$(terraform output -raw instance_public_ip) > /dev/null \
  && echo "✅ Nginx 可访问" \
  || (echo "❌ Nginx 不可访问" && exit 1)
```

这种方式不需要额外 parse ansible-playbook 的原始终端日志，直接从
Terraform state/output 拿结果做断言，更适合接入 CI。

## 已知限制（provider 目前的行为，供参考）

- `replayable = true`：每次 `terraform apply` 都会重新执行 playbook（哪怕
  什么都没变），这是当前 provider 的已知行为，不是 bug。如果只想在真正
  有变化时才重跑，可以把 `replayable` 设为 `false`，但代价是"改了配置也
  不会自动重跑"，需要手动触发（比如改 `ansible_host` 的变量）。
- 这个 provider 本质上还是在本地 shell 出 `ansible-playbook` 命令，所以
  执行环境（Python 版本、collections 是否装好等）跟 `local-exec` 方式的
  要求是一样的。

## 清理资源

```bash
terraform destroy
```

## 文件结构

```
terraform-ansible-demo-provider/
├── main.tf                    # EC2、安全组、Key Pair、ansible_host、ansible_playbook
├── variables.tf
├── outputs.tf                  # 包含 ansible_playbook_stdout/stderr 输出
├── terraform.tfvars.example
└── ansible/
    ├── ansible.cfg
    └── playbook.yml            # 跟上一版一样，装 Nginx
```
