# 没 Mac 怎么拿到能注入的 dylib：GitHub Actions 白嫖 macOS 编译

巨魔注入器（TrollFools）要的是**编译好的 `DYBoost.dylib`**。iOS 的 Objective-C 只能在 macOS + Xcode SDK 上编，
GitHub Actions 免费提供 macOS 机器，所以这条路是零成本的。

> 关键点：仓库设成 **Public**，macOS runner 才完全免费；Private 仓库也能跑，只是消耗免费额度
> （Free 账号 2000 分钟/月，macOS 按 10 倍计费，够跑十几次，但别乱点）。

---

## 第 1 步：建仓库

1. GitHub → 右上角 `+` → **New repository**
2. 名字随便（比如 `DYBoost`），**Public**，勾 **Add a README**（这样仓库非空，方便网页上传）
3. Create repository

## 第 2 步：传文件

把 `DYBoost-repo.zip` 解开，会看到两个目录：

```
DYBoost/     <- 源码 + 打包脚本
.github/     <- Actions 工作流（隐藏目录，别漏了）
```

在仓库首页点 **Add file → Upload files**，把这两个目录**整体**拖进去。
注意 `.github` 是点开头的隐藏目录，Windows 资源管理器里正常显示，别跳过。

上传完仓库根目录应该长这样：

```
.github/workflows/build-deb.yml
DYBoost/Makefile
DYBoost/control
DYBoost/DYBoost.plist
DYBoost/Tweak.xm
DYBoost/src/...
DYBoost/tools/...
DYBoost/layout/...
```

确认 `DYBoost/src/` 下一堆 `.m` 都在（最容易漏的是子目录）。

## 第 3 步：跑编译

1. 仓库页面 → 顶部 **Actions**
2. 左边点 **build-dyboost**
3. 右边 **Run workflow** → 分支选 `main`
   - `scheme`：`trollstore`（默认，就是给巨魔用的）
   - `make_release`：✅ 勾上（勾了会顺手发个 Release，手机能直接下载，省得登 GitHub 下 Artifact）
4. 点绿色 **Run workflow**

等 3～6 分钟，转绿勾就完事。

## 第 4 步：取产物

**勾了 make_release**：仓库首页右边 **Releases** → 最新一条 → 下面三个文件：

| 文件 | 用途 |
|---|---|
| `DYBoost.dylib` | **注入用这个**，最省事 |
| `DYBoost_1.0.0_iphoneos-arm64.deb` | 也能直接喂给 TrollFools，它会自己解里面的 dylib |
| `DYBoost-1.0.0-trollstore.zip` | 上面俩的压缩包 |

**没勾**：Actions → 那条运行记录 → 最下面 **Artifacts** → `DYBoost-dylib-deb-zip` → 下载 zip（需要登录 GitHub）。

> `make_release` 如果报 403 权限错误：仓库 **Settings → Actions → General → Workflow permissions**
> 改成 **Read and write permissions** 再跑一次。

## 第 5 步：注入

1. 手机 Safari 打开 Release 页面，下载 **`DYBoost.dylib`**（存到「文件」App）
2. 文件 App 里点它 → 分享 → **TrollFools（巨魔注入器）**
3. App 列表选**抖音** → 注入
4. **彻底杀掉抖音后台进程再打开**（不杀进程 dylib 不会 load，这步最容易漏）

之后：抖音里长按或用悬浮球 → 插件面板。
换版本：巨魔注入器 → 抖音 → 管理 → 长按 `DYBoost.dylib` → 替换。

---

## 排错

| 现象 | 原因 / 处理 |
|---|---|
| Actions 报 `xcrun: error: SDK "iphoneos" cannot be located` | 极少见，重新跑一次；或把 `runs-on: macos-latest` 改成 `macos-14` |
| 编译报某个类名/API 找不到 | 把 Actions 的 stderr 贴出来，我改 |
| Artifact 是空的 | 看日志里 `ls -la packages/` 那步，dylib 没生成说明编译挂了 |
| 注入后抖音闪退 | 先确认抖音版本 ≥ 15.0 系统；把崩溃前的系统日志给我 |

## 隐私

源码里没有任何你的个人信息。AI 的 API Key 存在手机钥匙串里，**不会进仓库**，也不会被写进配置备份导出。
唯一要注意的是：Public 仓库等于公开源码，别往里塞自己的密钥文件。
