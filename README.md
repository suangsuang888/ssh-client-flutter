# SSH 客户端（Flutter）

一个跨平台的 SSH 小工具，一套代码同时支持 **Android** 和 **Windows**。

## 功能

- **连接管理**：添加 / 编辑 / 删除 SSH 连接，支持密码和私钥（PEM）两种登录方式，配置保存在本机。
- **SSH 终端**：完整的交互式终端（基于 xterm），支持窗口大小自适应、标题同步。
- **文件浏览（SFTP）**：浏览远程目录，上传、下载、删除、重命名、新建文件夹；文件夹优先排序，显示大小和修改时间。
- **WebDAV 备份 / 恢复**：把全部连接配置备份成一个 JSON 文件上传到你的 WebDAV 服务器，换设备时一键恢复。

## 目录结构

```
lib/
  main.dart                        应用入口
  models/
    connection_profile.dart        连接配置 / WebDAV 设置的数据模型
  services/
    profile_store.dart             本地存储（shared_preferences）
    ssh_service.dart               建立 SSH 连接
    webdav_backup.dart             WebDAV 备份 / 恢复
  screens/
    home_screen.dart               连接列表
    profile_edit_screen.dart       添加 / 编辑连接
    terminal_screen.dart           SSH 终端
    file_browser_screen.dart       SFTP 文件浏览
    backup_screen.dart             WebDAV 备份 / 恢复
```

## 构建方法

### 1. 安装 Flutter

按官方文档安装 Flutter SDK（需要 Flutter ≥ 3.19，Dart ≥ 3.3）：https://docs.flutter.dev/get-started/install

### 2. 生成平台工程

本仓库只包含 `lib/` 源码和 `pubspec.yaml`。进入项目目录后运行一次，生成 android / windows 平台文件夹：

```bash
flutter create --platforms=android,windows --project-name ssh_client .
```

### 3. Android 权限（重要）

发布版需要联网权限。打开 `android/app/src/main/AndroidManifest.xml`，在 `<manifest ...>` 标签内、` <application>` 之前加一行：

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

（调试版 Flutter 会自动加，发布版必须手动加，否则连不上服务器。）

### 4. 拉取依赖并运行 / 打包

```bash
flutter pub get

# 调试运行（连上手机或在 Windows 上直接跑）
flutter run

# 打包 Android APK（产物在 build/app/outputs/flutter-apk/app-release.apk）
flutter build apk --release

# 打包 Windows 程序（必须在 Windows 电脑上执行，产物在 build/windows/x64/runner/Release/）
flutter build windows --release
```

> Windows 的 `.exe` 只能在 Windows 系统上编译，Linux/macOS 上无法生成。

## 使用说明

1. 首页点右下角 **+** 添加连接：填名称、主机（域名/IP，支持 IPv6）、端口、用户名，选择密码或私钥登录。
2. 点连接卡片直接打开终端；点右侧菜单可选择「文件浏览」。
3. 文件浏览里：点文件夹进入，左上角箭头返回上一级；顶部按钮可上传文件、新建文件夹、刷新；每个文件右侧菜单可下载 / 重命名 / 删除。下载的文件保存在应用文档目录。
4. 首页右上角云图标进入 WebDAV 备份：填好 WebDAV 地址、用户名、密码和远程目录，先「测试连接」，再「备份」；换设备时在新设备填同样的信息点「恢复」即可。

## 安全提示

- 连接配置（含密码、私钥）以明文 JSON 存在本机应用数据里，WebDAV 备份文件同样包含这些凭据。请只在你信任的设备和 WebDAV 服务器上使用。
- 当前版本对服务器主机密钥采取“直接接受”策略（个人工具简化处理）。如需更严格，可在 `lib/services/ssh_service.dart` 的 `onVerifyHostKey` 里实现指纹比对与记忆。

## 依赖

- [dartssh2](https://pub.dev/packages/dartssh2) — SSH / SFTP 客户端
- [xterm](https://pub.dev/packages/xterm) — 终端模拟器
- [webdav_client](https://pub.dev/packages/webdav_client) — WebDAV 客户端
- shared_preferences、file_picker、path_provider、path
