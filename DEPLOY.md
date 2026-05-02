# Open Design 部署文档

## 基本信息

| 项目 | 值 |
|---|---|
| 上游仓库 | https://github.com/nexu-io/open-design |
| Fork 仓库 | https://github.com/SharpCX/open-design |
| Railway 项目 | passionate-purpose |
| Railway 服务 | open-design |
| 部署地址 | https://open-design-production-f0ad.up.railway.app |
| Health Check | `GET /api/health` |
| Railway 项目 ID | `a616fe01-0c29-4682-8891-85c21100b0b0` |
| Railway 服务 ID | `2c4b9633-c5d8-4442-8291-f14f65fc86eb` |

## 架构

Open Design 是一个 pnpm monorepo，包含：
- `apps/web` — Next.js 16 前端（生产环境静态导出到 `apps/web/out/`）
- `apps/daemon` — Express 后端 + SQLite（`better-sqlite3`）

生产模式为单进程：daemon 同时提供 API 和静态前端文件。

## 文件位置

| 文件 | 路径 | 用途 |
|---|---|---|
| 部署 Dockerfile | `/Users/shawn/cx/code/open-design-deploy/Dockerfile` | Railway 构建用，clone fork 并构建 |
| railway.toml | `/Users/shawn/cx/code/open-design-deploy/railway.toml` | Railway 构建配置 |
| Fork 本地目录 | `/Users/shawn/cx/code/open-design` | fork 的完整代码 |
| 本项目目录 | `/Users/shawn/cx/code/cxneutrl/deploy-open-design/` | 初始部署文件参考（已过时） |

## Dockerfile Patch 说明

构建时对上游代码做了两个 patch（通过 `sed` 命令）：

### Patch 1：绑定地址
```
apps/daemon/src/server.ts
```
将 `app.listen(port, '127.0.0.1', ...)` 改为 `app.listen(port, '0.0.0.0', ...)`

**原因：** Railway 要求服务监听 `0.0.0.0`，否则外部无法访问。

### Patch 2：跳过 TypeScript 类型检查
```
apps/web/next.config.ts
```
在 Next.js 配置中注入 `typescript: { ignoreBuildErrors: true }`

**原因：** 上游 `SettingsDialog.tsx` 有一个类型错误（`'settings.maxTokens'` 不是有效的 `keyof Dict`），导致 `next build` 失败。

## 重新部署

```bash
cd /Users/shawn/cx/code/open-design-deploy
railway link --project a616fe01-0c29-4682-8891-85c21100b0b0 --environment production --service open-design
railway up
```

构建大约需要 5-8 分钟（clone + pnpm install + better-sqlite3 编译 + Next.js build + tsc build）。

## 同步上游更新

```bash
cd /Users/shawn/cx/code/open-design

# 首次添加上游 remote（只需一次）
git remote add upstream https://github.com/nexu-io/open-design.git

# 同步
git fetch upstream
git merge upstream/master
git push

# 然后重新部署
cd /Users/shawn/cx/code/open-design-deploy && railway up
```

**注意：** 如果上游修改了 `apps/daemon/src/server.ts` 中的 `app.listen` 行，或者修改了 `apps/web/next.config.ts`，Dockerfile 中的 sed patch 可能需要调整。构建失败时检查 build logs：
```bash
railway logs --build
```

## Railway CLI 常用命令

```bash
railway status          # 查看服务状态
railway logs            # 查看运行日志
railway logs --build    # 查看构建日志
railway domain          # 查看域名
railway variables       # 查看环境变量
railway up              # 部署
```

## 环境变量

当前未设置自定义环境变量。Railway 自动注入 `PORT`，Dockerfile CMD 将其映射为 `OD_PORT`。

如需持久化 SQLite 数据（默认容器重启会丢失），可在 Railway Dashboard 中添加 Volume 并设置：
- `OD_DATA_DIR` 指向 Volume 挂载路径

## 注意事项

- SQLite 数据存储在容器内，重启会丢失。如需持久化，需挂载 Railway Volume。
- 默认使用 BYOK 模式（Anthropic API），在 Settings 对话框中输入 API Key 即可使用。
- Fork 仓库的 `main` 分支包含部署相关的额外 commit（Dockerfile、.dockerignore、.railwayignore、next.config.ts 修改），这些仅用于部署，不影响功能。
