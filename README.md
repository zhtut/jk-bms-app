# JK BMS Monitor — 极空保护板电脑端监控

跨平台（Windows / macOS / Linux / Web）的极空（JK）BMS 储能保护板 **蓝牙只读监控** 程序，Flutter 编写。界面风格对齐极空官方 App。

> ⚠️ 本项目仅提供**监控**功能，不向保护板写入任何参数/开关指令。
> 协议逆向自社区开源项目，仅供个人学习使用。

## 功能

- 🔍 BLE 扫描 / 连接极空保护板（服务 `0xFFE0`，特征 `0xFFE1`）
- 📟 **自动识别协议变体**：JK02-24S / JK02-32S（PB 储能系列）/ JK04（新款 float 布局），也支持手动覆盖
- 🔋 实时监控：SOC / 总压 / 电流 / 功率 / 每串电芯电压与内阻 / 温度组 / MOS 与均衡状态 / 容量 / 循环次数 / SOH
- ⚠️ 告警位解析（32 项中文对照）+ 设备事件日志（0xA1）
- 📈 历史趋势图（内存环形缓冲约 1 小时）+ CSV 导出
- 🛠 调试页：原始帧 hex 收发日志（方便比对官方 App / 继续逆向）
- 🔁 断线自动重连（指数退避，可关闭）

## 快速开始

### 环境

- Flutter SDK ≥ 3.35（开发使用 3.47.8 stable）
- Windows：Visual Studio 2022（"使用 C++ 的桌面开发"工作负载）+ 蓝牙 4.0+ 适配器
- macOS：Xcode；Linux：`ninja-build libgtk-3-dev bluez`

### 运行

```bash
flutter pub get

# Windows 桌面
flutter run -d windows

# macOS / Linux
flutter run -d macos
flutter run -d linux

# Web (必须 Chrome/Edge; 本地调试允许 http://localhost)
flutter run -d chrome

# 单元测试 (协议层, 使用真实抓包帧)
flutter test
```

### 发布构建

```bash
flutter build windows --release   # build\windows\x64\runner\Release\
flutter build macos --release
flutter build linux --release
flutter build web --release       # 部署需 HTTPS
```

## 发布 Release

发布完全由 GitHub Actions 完成（`.github/workflows/release.yml`），本地无需编译：

```bash
git add -A && git commit -m "..." && git push          # 1. 推送代码
git tag v1.0.0 && git push origin v1.0.0               # 2. 打 tag 触发发布
```

tag 推送后 Actions 自动在 **windows / linux / macos / web** 四个环境构建，
打包为 `jkbms-monitor-<版本>-<平台>.zip` 并创建 GitHub Release（release notes 自动生成），
在仓库的 Releases 页查看进度与产物。

> macOS 产物未签名：用户首次打开需右键 → 打开（Gatekeeper 提示属正常现象）。

## 使用提示（连不上/无数据先看这里）

1. **保护板蓝牙通常只允许一个连接** — 先断开手机上的极空 BMS App。
2. 部分型号需短按保护板电源键唤醒蓝牙。
3. Web 版仅支持 Chrome / Edge / Opera，且页面必须运行在 `https://` 或 `localhost`；点击"扫描"后在浏览器弹窗中选择设备。
4. 连接成功但长时间无数据：
   - 打开 **调试页** 看是否有 RX 帧。有帧但数据不对 → 到 **设备页** 手动切换协议变体；
   - 完全无帧 → 该板可能是老固件（`4E 57` 旧协议），当前版本暂未实现，欢迎提 issue 附上调试页截图/hex。
5. Windows 若扫描不到设备：确认系统设置中蓝牙已开；个别老旧适配器不支持 BLE。

## 协议说明

BLE 通道使用极空**新版协议**（与 esphome-jk-bms main 分支一致）：

- 命令帧 20 字节：`AA 55 90 EB` + 命令字（`0x96` 电芯信息 / `0x97` 设备信息 / `0xA1` 日志）+ 求和 CRC
- 响应帧 300 字节：`55 AA EB 90` + 帧类型 + 按变体绝对偏移解析 + CRC@299
- 连接后发送 `0x97`、`0x96`，随后保护板周期性推送电芯信息帧（约 0.5~2s）

详细字段表见 [docs/技术方案.md](docs/技术方案.md)。协议层为纯 Dart，位于 `lib/protocol/`，
单测夹具为 esphome-jk-bms 源码注释中的真实设备抓包帧（`tools/gen_fixtures.dart` 自动提取，CRC 全部校验通过）。

## 项目结构

```
lib/
├─ protocol/     # 帧常量/CRC/组帧器 · 三变体解码器 · 告警与日志码表 (纯 Dart, 可单测)
├─ services/     # BLE 封装 · 会话编排(握手/重试/看门狗) · 历史缓冲
├─ state/        # AppController (ChangeNotifier + provider)
├─ ui/           # 页面(连接/监控/电芯/告警/参数/设备/调试) + 自绘控件(电池仪表/电芯条形图/趋势图)
└─ models.dart   # 快照/设备信息/参数/日志/历史采样模型
docs/技术方案.md  # 完整技术方案与协议速查
refs/            # esphome-jk-bms 协议参考源码 (仅供研究, 不属于构建)
tools/           # fixture 生成脚本
```

## 免责声明

- 本项目为**第三方独立开发**的开源工具，与成都极空科技有限公司（JIKONG / JK BMS）**无任何 affiliation、授权或背书关系**。
  "极空""JK""JK BMS" 等商标归其权利人所有，本项目仅作兼容性描述之用。
- 协议信息全部来自**公开社区逆向成果**（见下），本仓库不包含任何官方软件代码、固件、图标或素材。
- 本程序**仅读取**保护板公开广播的遥测数据，不写入任何参数、不控制任何开关、不刷写固件。
- 仅供**个人学习与自用**。使用者因使用本软件造成的任何损失（包括但不限于电池损坏）自行承担。
- 不构成法律意见；商业使用请咨询律师（另见下方 flutter_blue_plus 授权限制）。

## 致谢与许可

- 协议逆向参考：[syssi/esphome-jk-bms](https://github.com/syssi/esphome-jk-bms)（事实标准参考实现）、
  [fl4p/batmon-ha](https://github.com/fl4p/batmon-ha)、[patman15/aiobmsble](https://github.com/patman15/aiobmsble)、DIYSolarForum 社区
- BLE 插件：[flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) — 注意其 2.x 采用
  FlutterBluePlus License：个人/非商业用途免费（本程序按 nonprofit 使用）；**商业分发需购买授权**。
- 本项目代码以 [MIT](LICENSE) 许可开放，但请勿用于任何可能危害电池安全的写操作场景。
