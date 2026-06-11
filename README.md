# agent-runtime · OpenCode Runtime 镜像

`agent-runtime` 是 `agent-control` 调度用户 Runtime 时使用的 OpenCode 镜像构建仓库。

它的目标很单一：构建一个可以被 `agent-control` 创建为 Kubernetes Deployment 的 Runtime 镜像。镜像启动后运行 OpenCode Web，并暴露 `4096` 端口给 `agent-control` 代理访问。

## 官方依据

OpenCode 官方文档里和本镜像有关的点有三类。

### 1. 安装方式

OpenCode 支持通过 npm 安装：

```bash
npm install -g opencode-ai
```

本镜像使用这个方式安装 OpenCode CLI。

### 2. Web 启动方式

OpenCode Web 可以通过以下方式指定监听端口和地址：

```bash
opencode web --port 4096 --hostname 0.0.0.0
```

本镜像必须使用 Web 模式启动，不使用 `opencode serve`。

原因：本 Runtime 需要加载并运行项目级 OpenCode 配置中的 plugins；`serve` 模式不会加载运行项目级配置的 plugins。

### 3. 项目级配置目录

OpenCode 支持项目级配置和 `.opencode/` 目录。项目级目录使用复数子目录，例如：

```text
.opencode/agents/
.opencode/commands/
.opencode/modes/
.opencode/plugins/
.opencode/skills/
.opencode/tools/
.opencode/themes/
```

本仓库按这个结构提供最小项目级配置骨架。

## 镜像构建思路

本 Runtime 镜像做四件事：

1. 基于 Node.js 镜像提供 Node / npm 环境。
2. 安装 Python 3、pip、venv、Git、curl、bash、CA 证书等基础工具。
3. 使用 `npm install -g opencode-ai` 安装 OpenCode。
4. 将本仓库中的 `AGENTS.md` 和 `.opencode/` 复制到容器 `/app`，并以 Web 模式启动 OpenCode。

容器内默认项目目录是：

```text
/app
```

容器启动命令是：

```bash
opencode web --port 4096 --hostname 0.0.0.0
```

## 仓库结构

```text
.
├── AGENTS.md
├── Dockerfile
├── README.md
├── .dockerignore
├── .gitignore
└── .opencode
    ├── opencode.json
    ├── agents/
    ├── commands/
    ├── modes/
    ├── plugins/
    ├── skills/
    ├── tools/
    └── themes/
```

说明：

- `AGENTS.md` 是镜像内默认项目的规则示例，会被复制到容器 `/app/AGENTS.md`。
- `.opencode/opencode.json` 是本镜像参照 `feishu-bot` 模式提供的 OpenCode 项目级配置入口示例。
- `.opencode/agents/`、`.opencode/commands/`、`.opencode/modes/`、`.opencode/plugins/`、`.opencode/skills/`、`.opencode/tools/`、`.opencode/themes/` 是 OpenCode 项目级配置目录。
- `reminders/` 不是 OpenCode 官方项目级配置目录；它是特定插件可能产生或使用的运行时目录。本仓库不把 `reminders/` 作为默认结构提交。
- 本仓库不保存真实用户工作区，不保存真实凭证，不保存私有业务配置。

## 和 agent-control 的关系

`agent-control` 负责：

- 按用户创建 Runtime Deployment。
- 创建 Runtime Service。
- 维护 Redis 状态和租约。
- 代理 HTTP / SSE 请求。
- 管理用户和 Runtime 的绑定关系。

`agent-runtime` 只负责提供 Deployment 使用的容器镜像。

Runtime 实例跟用户绑定，不跟 scene 绑定。

## Dockerfile 做了什么

当前 Dockerfile 的关键步骤：

```dockerfile
FROM docker.1ms.run/library/node:22-slim
```

使用 Node 22 slim 作为基础镜像。

```dockerfile
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        python3 \
        python3-pip \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*
```

安装 Runtime 内常用基础工具。

```dockerfile
RUN npm install -g opencode-ai
```

按官方 npm 方式安装 OpenCode。

```dockerfile
WORKDIR /app
COPY .opencode/opencode.json .opencode/
COPY .opencode/agents/ .opencode/agents/
COPY .opencode/commands/ .opencode/commands/
COPY .opencode/modes/ .opencode/modes/
COPY .opencode/plugins/ .opencode/plugins/
COPY .opencode/skills/ .opencode/skills/
COPY .opencode/tools/ .opencode/tools/
COPY .opencode/themes/ .opencode/themes/
COPY AGENTS.md .
```

把默认项目规则和项目级 OpenCode 配置复制到容器 `/app`。

```dockerfile
EXPOSE 4096
CMD ["opencode", "web", "--port", "4096", "--hostname", "0.0.0.0"]
```

暴露 Runtime 端口，并以 Web 模式启动。

## 构建和验证

构建镜像：

```bash
docker build -t agent-runtime:local .
```

检查基础工具：

```bash
docker run --rm agent-runtime:local node --version
docker run --rm agent-runtime:local npm --version
docker run --rm agent-runtime:local python3 --version
docker run --rm agent-runtime:local opencode --version
```

运行 Runtime：

```bash
docker run --rm -p 4096:4096 agent-runtime:local
```

如果需要给 OpenCode 配置真实模型或供应商凭证，应在运行时通过环境变量、Secret 或挂载文件注入，不写入镜像和仓库。

## Kubernetes 部署建议

镜像内置的 `.opencode/` 只作为默认示例配置。真实部署时，建议由 `agent-control` 创建 Runtime Deployment，并通过 Kubernetes 配置能力替换或挂载实际项目配置。

推荐方式：

- 用 ConfigMap 挂载非敏感配置，例如 `/app/.opencode/opencode.json`。
- 用 ConfigMap 或只读卷挂载项目级 plugins、skills、agents、commands、modes、tools、themes。
- 用 Secret 注入模型供应商凭证、插件凭证和其它敏感参数。
- 用环境变量或 Secret 文件提供 OpenCode 所需的真实访问凭证。
- 不把真实配置、真实凭证、用户数据或私有插件烘进镜像。

示例挂载目标：

```text
/app/.opencode/opencode.json
/app/.opencode/plugins/
/app/.opencode/skills/
/app/.opencode/agents/
/app/.opencode/commands/
/app/.opencode/modes/
/app/.opencode/tools/
/app/.opencode/themes/
```

这样可以保持镜像稳定，把不同用户、不同环境、不同项目的 Runtime 配置交给 Kubernetes ConfigMap、Secret 和 volumeMount 管理。

建议在 Runtime Deployment 中显式配置容器安全上下文：

```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

如果业务确认 OpenCode、插件和挂载目录都不需要 root 权限，可以进一步配置 `runAsNonRoot: true`、`runAsUser`、`runAsGroup`。如果启用 `readOnlyRootFilesystem: true`，需要为 OpenCode 工作目录、临时目录、插件运行目录和用户 workdir 提供可写 volume。

## 安全边界

不要提交：

- 接口密钥、Token、Cookie、账号密码或密钥。
- `.env` 文件。
- kubeconfig 文件。
- 证书或私钥。
- 真实用户工作区数据。
- 私有 plugins、skills、tools 或业务配置。
