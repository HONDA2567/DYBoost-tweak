# DYBoost —— 抖音功能增强 & 界面美化插件（iOS Tweak）

对标你给的 `抖音优化_28.50_7855_无根.deb`（`com.siwenjiajia.tweak`，iOS 无根越狱注入包，
基于 DYYY/DYKiller 那一套思路）。**本项目是重写实现，不含原 deb 的任何代码/资源**，
只是把它的功能面拆成两层重新做了一遍：功能增强 + 界面美化。

目标 App：`com.ss.iphone.ugc.Aweme`（抖音）。

---

## 一、功能清单

### 增强（Enhance）
| 功能 | 说明 |
|---|---|
| 无水印下载 | `playwm → play`、剔除 `watermark` 参数；本地 model 抓不到时用公开 web 接口兜底 |
| 复制无水印直链 | 直链写进剪贴板 |
| 图集 / 封面 / 背景音乐保存 | 图集批量写相册；音频走文件导出 |
| 播放倍速 | 0.5x ~ 3.0x，长按临时倍速，双指上下滑调倍速 |
| 点击进度条跳转 / 双指调亮度·音量 | 双指手势，不和上下刷视频冲突 |
| 长按菜单 | 长按视频弹下载/直链/封面/音频/倍速/清屏/面板 |
| 双击动作 | 关 / 面板 / 下载 / 清屏 / 复制直链 |
| 清屏模式 | 只保留播放器相关视图，其余隐藏 |
| 帧率胶囊 / 作品数据 / 直播时长 | 左上角 FPS、右侧点赞评论收藏真实数据、直播间计时 |
| 悬浮球 | 单击快捷菜单、长按开面板、拖动吸附边缘、闲置淡出 |
| 配置备份 | 导出/导入 JSON（剪贴板或文件） |
| **AI 助手** | 视频总结 / 评论总结 / 写评论回复 / 翻译 / 自定义指令，接你自己的 OpenAI 兼容接口 |

### 美化（Beautify）
| 功能 | 说明 |
|---|---|
| 底栏玻璃 | 毛玻璃 / iOS 26 原生 `UIGlassEffect`（探测失败自动回落磨砂），可设圆角、隐藏文字 |
| 顶栏玻璃 | 导航条毛玻璃化 |
| 主题色 | 自定义强调色，用系统取色器 |
| 进度条样式 | 原生 / 细线 / 胶囊 / 亮色脉冲，高度与颜色可调 |
| 面板与图标 | 明暗跟随/固定、面板圆角、悬浮球大小与透明度、图标包（默认/极简/霓虹/自定义图片） |
| 元素隐藏 | 广告、直播入口、商城锚点、搜索入口、防沉迷条、弹幕、AI 浮钮、故事圈、评论输入框、正在输入、已读回执 |
| 诊断页 | 显示每条隐藏规则实际命中的抖音类名，方便版本升级后自查 |

---

## 二、目录结构

```
DYBoost/
├─ Makefile              Theos 构建（arm64/arm64e，rootless/roothide/trollstore）
├─ control               包信息
├─ DYBoost.plist         注入过滤：com.ss.iphone.ugc.Aweme
├─ Tweak.xm              入口：__attribute__((constructor))，只用 runtime hook，不链 substrate
├─ tools/
│  ├─ pack_deb.py        纯 Python 打 deb/zip（Windows 也能跑，不依赖 dpkg-deb）
│  ├─ build.sh           macOS 一键 编译 + 打包
│  ├─ calibrate.py       真机校准：类名清单 -> 候选类名表（可 --apply）
│  ├─ gen_prefs_plist.py 生成设置 App 的 PreferenceLoader plist
│  └─ layout/...         PreferenceLoader entry.plist（Theos 自动 stage）
└─ src/
   ├─ DYBKeys.h/.m(DYBPrefs)  设置项与默认值（NSUserDefaults suite）
   ├─ DYBHookKit.h/.m         runtime hook / 类名解析 / 安全 KVC / ivar 扫描
   ├─ DYBAweme.h/.m           从抖音 model 里盲取字段（不依赖私有头文件）
   ├─ DYBMedia.h/.m           直链解析、下载、存相册、文件导出
   ├─ DYBActions.h/.m         所有动作的入口（悬浮球/手势/面板共用）
   ├─ DYBBeauty.h/.m          底栏/顶栏/进度条/隐藏规则/清屏
   ├─ DYBFloatBall.h/.m       悬浮球
   ├─ DYBGesture.h/.m         长按/双击/双指手势
   ├─ DYBStats.h/.m           FPS / 作品数据 / 直播时长
   ├─ DYBPanel.h/.m           内置控制面板（不需要 PreferenceLoader）
   ├─ DYBMenu.h/.m            任意位置弹原生菜单
   ├─ DYBHUD.h/.m             Toast / Loading
   ├─ DYBTheme.h/.m           明暗、主题色、玻璃材质
   └─ DYBContext.h/.m         当前页面/当前作品上下文
```

---

## 二·补、AI 助手

接到**你自己的** OpenAI 兼容接口（`/v1/chat/completions`），官方 / DeepSeek / 通义 / 硅基流动 / 本地 Ollama
（`http://192.168.x.x:11434/v1`）都行。

配置位置：面板 → **AI 助手** → 接口设置

| 项 | 说明 |
|---|---|
| 启用 AI | 关掉后悬浮球/长按菜单里不再出现 AI 入口 |
| 接口地址 | `https://api.openai.com/v1`、`https://api.deepseek.com/v1` … |
| 路径 | 默认 `/chat/completions`；地址里已经带了就忽略 |
| 模型名 | `gpt-4o-mini` / `deepseek-chat` / `qwen-plus` / `llama3` … |
| API Key | 存**本机钥匙串**；写不进钥匙串才退化存 NSUserDefaults（且不会进配置备份） |
| 温度 / 最大 token | 常规参数 |
| 测试连接 | 发一条极短请求验证配置 |

能做的事：

1. **总结当前视频** —— 用作品文案生成要点
2. **总结评论区** —— 抓屏幕上可见的评论（最多 30 条，纯视图层级扫描，不碰抖音 API）
3. **写评论回复** —— 先让你挑一条评论，生成后可一键**填入评论输入框**
4. **翻译当前文案**
5. **自定义指令** —— 自己写 prompt，自动附上下文

提示词全部可改（面板 → AI 助手 → 提示词），占位符：`{desc} {author} {comments} {comment} {text} {command} {context}`。

隐私边界：**只会发到你自己填的那个接口**，除此之外不联网；AI 相关请求走 NSURLSession，
不写抖音的日志/埋点。API Key 不进配置备份导出。

---

## 二·补二、真机校准（抖音版本变了以后）

依赖类名解析的功能（隐藏元素那几项）会随抖音版本失效。

### 已内置：40.6.0 实测校准（默认）

```bash
python3 tools/calibrate.py --preset aweme-40.6.0 --apply
```

72 个类名全部来自 `抖音 40.6.0 (build 406019)` 砸壳 IPA 的 `__objc_classname`
（17.5 万个类名里人工筛的，已逐个校验存在于该版本）。首选项：

| 规则 | 命中类 |
|---|---|
| 广告 | `AWEAdTagView` |
| 直播标记 | `AWEFeedLiveMarkView` |
| 商城挂车 | `AWEAwemeGoodsTag` |
| 顶栏搜索 | `AWEDCFeedSearchBarView` |
| 防沉迷 | `AWEFeedAntiAddictMaskView` |
| 弹幕 | `AWEAwemeBarrageAwemeView` |
| AI 浮钮 | `AWEGeneralSearchAIBallButton` |
| 故事圈 | `AWEUserAvatarRingAvatarView` |
| 评论输入框 | `AWECommentInputBackgroundView` |
| 进度条 | `AWEDPlayerProgressView` |

换版本时按下面流程重做一遍即可。

### 换版本怎么重做

1. 有砸壳 IPA 最好（**不解压整个包**，只抽两个段，几秒）：

```bash
python3 tools/extract_ipa_classes.py 抖音_XX.X.ipa -o aweme_classes
# -> aweme_classes.txt（类名）/ aweme_classes.meth.txt（方法名）
python3 tools/calibrate.py aweme_classes.txt            # 自动打分给建议
```

   加密的（有 `LC_ENCRYPTION_INFO_64` 且 `cryptid != 0`）读不出来，脚本会直接报。

2. 面板 → **数据与诊断** → `导出校准报告（分享）`（或 `导出全部类名（分享）`）
   报告内容：抖音版本 / 顶层 VC 类链 / 视图类名 / 当前作品解析结果 / 每条隐藏规则命中情况 /
   所有 `AWE* IES* FDS* …` 类名。
2. 把文件传回电脑：

```bash
python3 tools/calibrate.py DYBoost-report.txt           # 先看建议
python3 tools/calibrate.py DYBoost-report.txt --apply   # 直接改写 src/DYBBeauty.m（会备份 .bak）
python3 tools/calibrate.py --macho ./Aweme --apply      # 有砸壳 Mach-O 时更准
```

脚本逻辑：只认**强关键词命中**（`danmaku` / `storyring` / `commentinput` / `antiaddict` …），
弱关键词（如 `ad`）不能单独决定，避免把 `AWEGradientView` 这种误判成广告；
同时排除 `Model/Manager/Service/DataController/WebView` 等非视图类，每条规则最多 8 个候选，
原有候选一律保留在前面。

---

## 二·补三、PreferenceBundle（设置 App 入口）

`layout/Library/PreferenceLoader/Preferences/DYBoost.plist`，61 个 specifier，
表驱动生成（改 `tools/gen_prefs_plist.py` 里的 TABLE 后重跑即可）：

```bash
python3 tools/gen_prefs_plist.py
```

- 读写的是同一个 suite `com.seagull.dyboost`，改完发 Darwin 通知 `com.seagull.dyboost.prefs`，
  抖音进程里立刻生效（不需要重启 App）。
- **只在越狱设备上生效**（要往设置 App 注入）。巨魔注入器是往抖音里塞 dylib，
  设置 App 不会有入口 —— 那种环境用内置面板（悬浮球长按）。
- 复杂项（取色、提示词、配置导入导出）仍然只在内置面板里。

---

## 三、编译 → 打 deb

> **重要**：deb 只是个容器，里面必须有一个**编译好的 arm64 dylib**。
> 三条路：本机 macOS（方案 A，出 arm64+arm64e fat，最稳）→ GitHub Actions（方案 B，没 Mac 用这个）
> → Windows 本机用 zig 交叉编译（方案 C，出纯 arm64，立刻能拿）。

### 方案 A：本机 macOS

```bash
cd DYBoost
./tools/build.sh trollstore     # 巨魔注入器用这个
./tools/build.sh rootless       # 无根越狱用这个
./tools/build.sh roothide
# 产物：packages/com.seagull.dyboost_1.0-1_iphoneos-arm64.deb
```

手动版：

```bash
export THEOS=~/theos
make clean && make -j$(sysctl -n hw.ncpu)
python3 tools/pack_deb.py --scheme trollstore
```

已越狱设备可直接装：`make install THEOS_PACKAGE_SCHEME=rootless`；
卸载 `dpkg -r com.seagull.dyboost`（无根用 `/var/jb/usr/bin/dpkg`）。

### 方案 B：GitHub Actions（没 Mac 就用这个）

**完整图文步骤见 [`docs/GITHUB_ACTIONS.md`](docs/GITHUB_ACTIONS.md)。** 简述：

1. 把整个仓库 push 到 GitHub（建议 **Public**，macOS runner 才免费）；
2. Actions → `build-dyboost` → **Run workflow**：scheme 选 `trollstore`，`make_release` 勾上；
3. 跑完去 **Releases** 下载（或 Artifacts 里下 `DYBoost-dylib-deb-zip`）：
   - `DYBoost.dylib` ← **巨魔注入器就注这个**
   - `com.seagull.dyboost_1.0-1_iphoneos-arm64.deb` ← 也能直接喂给 TrollFools
   - `DYBoost-1.0-1-trollstore.zip` ← 上面俩的压缩包

CI 用的是 `tools/build.py`（xcrun clang，不依赖 Theos），出 **arm64 + arm64e** fat。

### 方案 C：Windows 本机交叉编译（zig，不用等 CI）

zig 自带 clang 和 Mach-O 后端，配一份 iPhoneOS SDK 就能在 Windows 上直接出 dylib：

```bat
winget install zig.zig
:: 下一份 iPhoneOS SDK（任意版本），解压到 DYBoost\tools\sdk\iPhoneOS*.sdk\
python tools\build.py --sdk D:\sdk\iPhoneOS17.5.sdk --pack trollstore --format all
```

产出 `packages/DYBoost.dylib` + `.deb` + `.zip`。
**限制：zig 编不出 arm64e，只有 arm64。** 注入后抖音打不开的话，改用方案 A/B 的 fat 版本。

两个坑（脚本已处理，手动编要注意）：
- SDK zip 里的 `.tbd` 是 macOS 符号链接，Windows 解压会变成文本指针，链接时会报
  `failed to parse TBD file`，需要把 symlink 还原成目标文件内容；
- `.xm` 后缀 zig 的 driver 不认，会静默产出 0 字节 `.o`，要先复制成 `.m`。

### 方案 D：已经有 dylib 了，只想打包

```bash
python3 tools/pack_deb.py --dylib /path/DYBoost.dylib --scheme trollstore --out dist
python3 tools/pack_deb.py --dylib /path/DYBoost.dylib --format all   # deb + zip 都出
```

### install_name 与「dylib not found」

注入器把 dylib 放进 App 的 `Frameworks/` 再改 load command，两种写法各出一版：

```bash
python3 tools/build.py --pack none                       # packages/DYBoost.dylib
                                                         #   LC_ID_DYLIB = @rpath/DYBoost.dylib（默认）
python3 tools/build.py --pack none --suffix=-execpath \
        --install-name @executable_path/Frameworks/DYBoost.dylib
                                                         # packages/DYBoost-execpath.dylib
```

先试默认版；抖音启动报 `image not found` 就换 `-execpath` 那版。

---

## 三·补、巨魔注入器（TrollFools）怎么注

1. 把 deb（或 zip / dylib）存进 iPhone 自带「文件」App（建议「我的 iPhone」下新建个文件夹）；
2. 在「文件」里点这个 deb → 分享 → 选**巨魔注入器**；
3. 选目标 App：**抖音** → 确认注入；
4. 等它重新签名装好，**完全杀掉抖音后台再打开**（不杀进程插件不会 load）。

需要注意的几点：

- 巨魔注入器**只搬二进制**，deb 里除了 dylib 之外的资源文件不会进 App 包。
  DYBoost 已经按这个限制设计：**不依赖任何随包资源**，图标用 SF Symbols / 你自选的图片
  （以 base64 存在 NSUserDefaults 里），配置也全在 NSUserDefaults suite `com.seagull.dyboost`。
- **不依赖 CydiaSubstrate**：所有 hook 走 `libobjc` runtime（`method_setImplementation`），
  所以巨魔环境里没有 Substrate / ElleKit 也能正常工作。
- 注入器会把 dylib 塞进 App 的 Frameworks 并改 Mach-O 的 load command，
  所以抖音自己更新后需要**重新注入一次**。
- 要换版本：巨魔注入器 → 抖音 → 管理 → 找到 `DYBoost.dylib` 长按 → 替换。

### 打不开 / 卡死怎么办（1.0.1 起带三道保险）

历史上出现过「注入后抖音一打开就冻住」，根因是**对象图扫描太贪**：
`viewDidAppear` 里同步跑 `DYBFindObject(vc, ..., 6)`，抖音首页 VC 持有整个 feed 数据源
（几百个 model × 上百 ivar），深度 6 展开能到 10^6 量级，主线程直接冻死。
1.0.1 做了三件事：

1. **扫描有预算**（`DYBHookKit`）：最多 1200 个节点 / 20ms / 深度 5，
   且 `UIView` `UIViewController` `CALayer` `UIImage` `NSData` 的 ivar 一律不深入。
2. **按需扫描**（`DYBContext.setNeedsModel:`）：默认不扫。只有你打开了面板、
   点过快捷菜单、或开了「作品数据」浮窗，才允许在 RunLoop 空闲时扫（2.5s 节流）。
3. **安全层**（`DYBSafe`）：
   - 主线程看门狗：8 秒没响应 → 自动降一级并写盘，**下次启动生效**；
     连最轻一级都卡 → 直接整体停用，保证抖音能开。
   - 分级启动：stage 1 = 只挂悬浮球 + 手势；stage 2 = 加美化 hook 与作品扫描。
   - kill switch：一键彻底不装载。

面板 → **安全与排障** 里可以：停用插件 / 切轻量模式 / 看自动降级次数 / 手动扫一次作品。

**已经卡死、连面板都进不去时的手动救砖**（Filza 或其它能改 plist 的工具）：

```
/var/mobile/Containers/Data/Application/<抖音UUID>/Library/Preferences/com.seagull.dyboost.plist
```

加一条 `DYB.killSwitch = YES`（Boolean），彻底杀后台再开抖音，插件就不会装载了。
嫌麻烦就直接巨魔注入器 → 抖音 → 管理 → 删掉 `DYBoost.dylib`，再注入新版本。

---

## 四、怎么用

1. **悬浮球**（默认开）：点一下 = 快捷菜单，长按 = 打开插件面板，拖到边上会吸附。
2. **长按视频**（默认开）：弹快捷菜单；想让它吃掉抖音自己的菜单，打开「拦截抖音原生长按菜单」。
3. **双击屏幕**：默认关；开启后按设置执行动作（注意会和点赞共存）。
4. **双指上下滑**：调亮度 / 音量 / 倍速。
5. **插件面板**：所有开关、滑杆、取色、备份、诊断都在里面；**双击标题栏**切换明暗。

---

## 五、几个工程上的取舍

1. **不写死抖音类名。** 所有内部类都用「候选类名列表」在运行时解析（`DYBFirstClass`），
   解析不到就自动降级，绝不会因为版本升级导致抖音崩溃。
2. **字段盲取。** `DYBAweme` 用候选属性名 + ivar 扫描 + URL 分类抓视频/图集/音频/封面/统计，
   抓不到就走公开 web 接口 `iesdouyin iteminfo` 兜底。
3. **Hook 用 runtime 而非 Logos 静态 hook。** `DYBHookKit` 基于 `class_addMethod` /
   `method_setImplementation` + `imp_implementationWithBlock`，只在进程内生效，不碰抖音 Mach-O。
4. **相册权限有护栏。** 宿主没声明 `NSPhotoLibraryAddUsageDescription` 时不写相册，
   自动改为系统文件导出，避免直接崩。
5. **不做伪造数据。** 原 deb 里的「作品数据伪装」这类功能没有实现，只显示真实数据。
6. **不联网上传任何数据。** 只有「无水印直链兜底解析」会请求一次公开接口。

---

## 六、已知限制

- 依赖类名解析的功能（隐藏元素那几项）在抖音大版本更新后可能失效 → 看面板里的「诊断」页，
  显示「未命中」就说明类名变了，改 `src/DYBBeauty.m` 里 `DYBHideRules()` 的候选列表即可。
- 「正在输入 / 已读回执」属于实验项，候选类名为猜测值，命中才生效。
- 倍速依赖能扫到 `AVPlayer`；抖音换播放器实现时该项会静默失效（其它功能不受影响）。
- 仅供个人学习与自用，请勿用于任何违反抖音用户协议或法律法规的场景。
