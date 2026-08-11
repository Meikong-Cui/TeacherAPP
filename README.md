# 语亦丰康复 · 教师端 App（Flutter）

儿童康复教育系统的**教师端 App**，基于前端原型 `children-rehab-prototype/app.html` 的演示结构开发，使用 Flutter 3.44 + Riverpod + GoRouter 实现。

## 技术栈

- **Flutter 3.44** + Dart 3
- **flutter_riverpod** —— 状态管理
- **go_router** —— 路由（底部 Tab 壳 + 详情/功能页）
- **geolocator** —— 获取当前定位（上下班签到围栏判定）
- **geocoding** —— 经纬度反查地址（预留）
- **http** —— 真实后端接口调用（JWT Bearer 鉴权）
- **image_picker** —— 手写照片 / 图片选择并 base64 上传
- **shared_preferences** —— 主题与本地状态持久化

## 已实现功能

### 基础（移植自 demo）

- 登录页（真实登录：`POST /api/auth/login`，JWT 写入 `AuthStore` 持久化；未登录拦截跳登录页）
- 首页待办概览 + 快捷入口
- 儿童列表 / 儿童详情（IEP 进度、动态时间线）
- 评估任务列表 / 评估填写
- IEP 目标
- 训练记录
- 康复指导
- 消息提醒
- 我的（主题：亮色 / 深色 / 跟随系统）

### 新增：上下班签到（1km 围栏）

- 入口：首页「上下班签到」/ 我的「上下班签到」→ `/clock-in`
- 打卡地点按**校区**配置（`data/models/campus.dart`，坐标当前为示例值，真实环境由后台下发）
- 获取当前定位 → **Haversine 球面距离**计算到打卡点距离
- **仅在 ≤ 1000 米范围内允许签到**（超出则拦截并提示）
- 支持「上班 / 下班」两类打卡，记录时间、地点、距离并本地展示
- **演示模式：模拟定位开关**：免去真实定位依赖，可一键设定「在打卡点 (0m)」或「偏离 1.5km」验证围栏逻辑
- 围栏可视化：中心为打卡点，外圈为 1000 米围栏，圆点为当前位置
- 后端保存接口预留：`POST /api/attendance/clock-in`（`core/constants.dart` + `clock_in/data/clock_in_repository.dart`）

### 新增：AI 写教案（接口预留）

- 入口：首页「AI 写教案」/ 我的「AI 写教案」→ `/ai-lesson-plan`
- 表单：儿童姓名 / 发展领域 / 训练目标 → 调用生成
- 后端接口已预留：`POST /api/ai/lesson-plan`（后端 `oa-ai` 模块，角色门禁 `TEACHER,PRINCIPAL`）
- 当前 AI 能力（DeepSeek）后续接入，App 端返回**示例结果**并明确标注「接口已预留」
- 真实调用代码已在 `ai_lesson_plan_repository.dart` 中以 `TODO(backend)` 注释占位

### 新增：财务报销申请（教师端）

- 入口：首页「财务报销」/ 我的「财务报销」→ `/reimbursement/list`
- 三页：报销列表（`/reimbursement/list`）/ 申请表单（`/reimbursement/new`）/ 详情（`/reimbursement/:id`）
- 申请表单：标题 / 类别（教学用品·差旅交通·办公用品·培训费·其他）/ 事由 / 多项明细（名称·金额·备注），实时合计
- 提交走真实后端 `POST /api/reimbursement`，可在「我的申请」查看后端返回列表（`GET /api/reimbursement/mine`）；审批由财务/园长在 OA 后台完成
- 后端接口已预留：`POST /api/reimbursement`（后端 `oa-reimbursement` 模块，教师提交、财务/园长审批）
- 真实接口实现见 `reimbursement_repository.dart`（JWT 自动附带）；后端 `oa-reimbursement` 已就绪
- OA 网页端对应审批页：`报销审批` 菜单（`finance` 分组，FINANCE/PRINCIPAL 可见），路径 `page/reimbursement-approval`

### 新增：康复档案填表 + 手写照片（真实后端 oa-rehab）

- 入口：首页「康复档案」/ 我的「康复档案」→ `/rehab`（列表）→ `/rehab/:id`（详情）
- 详情 5 个 Tab：概览/任务、首次评估、持续评估、教学计划、手写照片
  - **首次评估**：查看/填写表单（听力检测数据等），`POST /api/rehab/first-eval` 提交
  - **持续评估**：列表 + 新增，`POST /api/rehab/cont-eval`
  - **教学计划**：新建 / AI 补全（`POST /api/rehab/plan/:id/ai-generate`，占位待 DeepSeek）/ 编辑
  - **手写照片**：`image_picker` 选图 → base64 → `POST /api/rehab/photos` 上传，绑定档案
- 首页「待办任务」来自后端 `GET /api/rehab/tasks/pending`，可一键 `POST /api/rehab/tasks/:id/complete`
- 数据层：`rehab_repository.dart` + `provider/rehab_provider.dart`（`RehabArchiveDetailNotifier`、`pendingTasksProvider`）

### 新增：公章使用审批（真实后端 oa-rehab / SealApproval）

- 入口：首页「用章申请」/ 我的「用章申请」→ `/seal/apply`（申请）→ `/seal`（我的申请列表）
- 申请表单：用章类型 / 份数 / 事由 / 用章时间；提交 `POST /api/seal`（申请人按 JWT 自动填充）
- 列表展示状态（待审批/通过/驳回），审批人（PRINCIPAL/ADMIN/FINANCE）可 `PUT /api/seal/:id/approve?status=&comment=`
- 数据层：`seal_repository.dart` + `provider/seal_provider.dart`

### 新增：任务到期提醒（真实后端）

- 首页待办区接入 `pendingTasksProvider`（后端 `GET /api/rehab/tasks/pending`），取代原 mock 待办
- 任务完成实时回写后端并刷新列表（目前为进入首页拉取，未接系统级推送）

## 目录结构

```
lib/
├── main.dart
├── app/
│   ├── router.dart          # GoRouter 路由表
│   └── theme.dart           # Teal 主题（亮/暗）
├── core/
│   ├── constants.dart       # 后端地址、接口路径、围栏半径
│   └── theme_mode_notifier.dart
├── data/
│   ├── models/              # User/Child/Assessment/Message/Campus/ClockRecord...
│   └── mock_data.dart       # 演示数据（移植自 mock-data.js）
├── shared/
│   ├── app_shell.dart       # 底部 Tab 导航壳
│   └── ui.dart              # 通用组件 + 主题切换按钮
└── features/
    ├── auth/                # 登录
    ├── home/                # 首页
    ├── children/            # 儿童/评估/IEP/训练/指导
    ├── messages/
    ├── profile/
    ├── clock_in/            # 上下班签到（geo + repository + provider + screen）
    ├── ai_lesson_plan/      # AI 教案（repository + provider + screen）
    ├── rehab/               # 康复档案（model + repository + provider + 列表/详情五 Tab）
    ├── seal/                # 公章审批（model + repository + 申请/列表页）
    └── reimbursement/       # 财务报销（model + repository + provider + 列表/申请/详情三页）
```

## 运行

```bash
# 前置：Flutter 3.44+ 已安装并加入 PATH
cd teacher_app
flutter pub get
flutter run            # 连接真机 / 模拟器（定位功能需真机或带定位的模拟器）
```

### 平台权限配置

- **Android**：`android/app/src/main/AndroidManifest.xml` 已包含
  `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`
- **iOS**：当前工程**尚未生成 `ios` 目录**（之前只产出了 Android 平台）。在 Mac 上
  `flutter create --platforms=ios .` 生成 iOS 工程后，需补加定位权限描述到
  `ios/Runner/Info.plist`（geolocator 必需，否则签到在 iOS 崩溃 / App Store 审核被拒）：
  `NSLocationWhenInUseUsageDescription` / `NSLocationAlwaysAndWhenInUseUsageDescription`。
- **Web**：定位需 HTTPS 或 localhost 环境

## 接口预留汇总

| 功能 | 方法 | 路径 | 状态 |
| --- | --- | --- | --- |
| 登录鉴权 | POST | `/api/auth/login` | ✅ 已接（JWT 持久化） |
| 康复档案列表 | GET | `/api/rehab/archives` | ✅ 已接 |
| 康复档案详情 | GET | `/api/rehab/archives/:id` | ✅ 已接 |
| 首次评估 | POST/PUT | `/api/rehab/first-eval` · `/:id` | ✅ 已接 |
| 持续评估 | POST | `/api/rehab/cont-eval` | ✅ 已接 |
| 教学计划 | POST/PUT | `/api/rehab/plan` · `/:id` | ✅ 已接 |
| 教学计划 AI 补全 | POST | `/api/rehab/plan/:id/ai-generate` | 占位（待 DeepSeek） |
| 手写照片上传 | POST | `/api/rehab/photos` | ✅ 已接（base64） |
| 待办任务 | GET | `/api/rehab/tasks/pending` | ✅ 已接 |
| 任务完成 | POST | `/api/rehab/tasks/:id/complete` | ✅ 已接 |
| 用章申请 | POST | `/api/seal` | ✅ 已接 |
| 用章审批 | PUT | `/api/seal/:id/approve` | ✅ 已接（PRINCIPAL/ADMIN/FINANCE） |
| 财务报销申请 | POST | `/api/reimbursement` | ✅ 已接（后端 oa-reimbursement） |
| 报销列表（我的） | GET | `/api/reimbursement/mine` | ✅ 已接 |
| 考勤打卡保存 | POST | `/api/attendance/clock-in` | 预留（本地演示） |
| AI 教案生成 | POST | `/api/ai/lesson-plan` | 预留（后端 oa-ai 已就绪） |
| 儿童 / 评估 / IEP 等 | GET | `/api/...` | 演示数据，待接入 |

> 接入真实后端时：将 `data/mock_data.dart` 替换为 API 调用，并在 repository 中填入 `TODO(backend)` 标注的真实请求（携带 JWT）。

## 后续：评估任务接入数据库（规划）

目标流程：**评估任务从数据库抽取练习题 → 教师答题 → 自动/手动打分 → 生成评估文本 → 上传本次答题**。
当前 App 仅有 mock 数据、无真实 HTTP/token；后端**尚无评估/题库模块**。连接前需补齐：

### 1. 先定契约（两端并行的前提）
- 定义 JSON/OpenAPI 契约：题目（题型 / 选项 / 分值 / 参考答案 / 所属领域）、评估任务（绑定儿童 + 量表 + 题目集）、答题提交（每题作答 + 得分）、评估结果（总分 + 分级 + 评估文本）。
- 明确「抽题」策略：任务创建时固定题目集（随任务下发，利于离线）还是进入时动态抽取。
- 明确评分方：**建议服务端算分**保证一致；评估文本先用模板生成，后续接 `oa-ai`（DeepSeek）产出自然语言段落。

### 2. 后端（oa-backend，需新建 `oa-assessment` 模块）
- 实体/表：题目库、题目、评估任务、答题记录、评估结果（PostgreSQL Flyway + H2 双写，沿用现有约定）。
- REST API：`GET /api/assessment/tasks?childId=`（拉任务 + 题目）、`POST /api/assessment/attempts`（提交答题）、`GET /api/assessment/attempts?taskId=`（历史）。
- 角色门禁：沿用 JWT，`TEACHER` 可答题/提交，`PRINCIPAL/ADMIN` 可管理题库。
- 评分规则服务 + 评估文本生成（模板先行，预留接 `oa-ai`）。

### 3. App 端（teacher_app）
- **鉴权接入**：登录改真实接口、JWT 存 `flutter_secure_storage`、请求拦截器自动带 `Authorization`（当前为演示登录，仅 shared_preferences 存主题）。
- **HTTP 客户端**：封装 Dio/http，统一 baseUrl（环境切换：模拟器 `10.0.2.2` / 真机局域网 IP / 生产域名）、超时、错误与日志。
- **数据模型对齐**：扩展 `Assessment` / `AssessmentQuestion`（题型、分值、参考答案、分级、`Attempt`、`Result`），对齐后端 DTO。
- **Repository 抽象**：新增 `AssessmentRepository`（参照 `clock_in_repository` 的 `TODO(backend)` 模式），mock/remote 可切换，保留离线开发能力。
- **答题 UI 升级**：支持量表打分（1–5 分 / 星级）、多选、填空/观察记录；按题型渲染；实现自动评分与模板化评估文本。
- **提交与离线队列**：`POST /api/assessment/attempts` 带 token；网络失败重试 + 本地暂存补传（SharedPreferences / 本地库）。
- **任务列表接入**：评估任务列表改为按儿童从后端拉取，保留 mock 模式。

> 现状对照：Phase 3 已完成**登录鉴权 / 康复档案 / 公章审批 / 财务报销 / 任务提醒**的真实后端联调（见上文）；仅**评估任务（Assessment）与儿童档案列表**仍为 mock，且后端**尚无评估/题库模块**。两者都需新建/补齐后才能联调。

## 构建 APK（本机已验证）

已在本机完成 `app-debug.apk` 构建（产物：`build/app/outputs/flutter-apk/app-debug.apk`，约 144MB，含调试符号）。

> **2026-07-27 修复**：二级页（签到 / 学生详情 / 评估 / IEP 等）按系统返回键会直接退出 App。
> 根因：详情路由是 `StatefulShellRoute` 的**顶层兄弟路由**，原跳转用 `context.go(...)` 整体替换根导航栈、清掉了 Shell；已全部改为 `context.push(...)`，返回即弹回列表。已重新打包 APK 并真机验证。

```bash
flutter pub get
flutter build apk --debug        # 输出 app-debug.apk
flutter build apk --release      # 若需发布包（需自签或上传密钥）
```

### 本机构建环境坑（已解决，记录备查）
- **Gradle 发行包镜像**：`services.gradle.org` 被墙，已将
  `android/gradle/wrapper/gradle-wrapper.properties` 的 `distributionUrl` 改为腾讯云镜像
  `https://mirrors.cloud.tencent.com/gradle/gradle-9.1.0-all.zip`。
- **中文路径**：项目目录含中文（`教育app`）会被 AGP 拒绝。本机用目录联接绕开：
  `C:\flutter` → 实际 flutter SDK，`C:\android-sdk` → 实际 android-sdk；
  `android/local.properties` 中 `flutter.sdk` / `sdk.dir` 指向这两个无中文短路径。
  正式迁移到其他机器时，请改回真实绝对路径或把工程放到纯英文目录。
- **compileSdk / targetSdk = 36**：`geolocator` / `shared_preferences` 最新版要求 compileSdk ≥ 36，
  已显式设置 `android/app/build.gradle.kts` 的 `compileSdk=36`、`targetSdk=36`，并安装 `platforms;android-36`。
- **移除 `geocoding` 依赖**：该插件编译于 API 33，其 AndroidX 依赖要求 34，触发 AGP `checkAarMetadata`
  失败；当前代码未使用逆地理编码，已从 `pubspec.yaml` 移除。
- **pub 镜像**：`pub.dev` 被墙，构建时设 `PUB_HOSTED_URL=https://pub.flutter-io.cn`、
  `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`。

## 构建 iOS / 打包苹果应用（需在 Mac 上完成）

> ⚠️ **iOS 打包无法在 Windows 完成**，必须在 macOS + Xcode 环境中进行。本工程当前**只有 Android 平台**，
> `ios` 目录需在 Mac 上生成。Apple 生态的硬性门槛：**仅 iOS 模拟器可免费运行；真机安装 / TestFlight / 上架 App Store
> 都必须有 Apple Developer 账号（个人 $99/年）**——租 Mac 不等于能免费把 App 装进 iPhone。

### 一次性前置（Mac 上）
- **Xcode**（App Store 免费下，需 Apple ID）+ Xcode Command Line Tools（`xcode-select --install`）
- **Flutter SDK**：放到英文路径（如 `~/flutter`），加入 PATH
- **CocoaPods**：`sudo gem install cocoapods` 或 `brew install cocoapods`
- **Apple Developer 账号**（$99/年）：真机测试 / 分发 / 上架必需

### 打包步骤
```bash
# 1. 把工程拷到 Mac（建议英文路径，如 ~/teacher_app），安装依赖
cd ~/teacher_app
flutter pub get

# 2. 生成 iOS 工程（当前缺 ios 目录）。注意：此命令会 regen 平台模板文件，
#    若之后还要打 Android 包，需重新确认 AndroidManifest 定位权限与 compileSdk=36 未被覆盖
flutter create --platforms=ios .

# 3. 安装 iOS 原生依赖
cd ios && pod install && cd ..

# 4. 补 iOS 定位权限：在 ios/Runner/Info.plist 加（geolocator 必需）
#    NSLocationWhenInUseUsageDescription   = "用于上下班签到时定位打卡点"
#    NSLocationAlwaysAndWhenInUseUsageDescription = "用于上下班签到时定位打卡点"

# 5. Xcode 打开 ios/Runner.xcworkspace
#    - 设 Bundle ID（如 com.yyf.teacherapp，需唯一）
#    - Signing & Capabilities：选 Team（你的 Developer 账号），勾选 Automatically manage signing

# 6. 真机测试
flutter run          # 连 iPhone（设备需在该 Developer 账号下注册 UDID）

# 7. 打包 ipa
flutter build ipa    # 产出 build/ios/ipa/*.ipa；或 Xcode → Product → Archive → Distribute App
```

### 分发方式选择
- **模拟器**（免费，不需 Developer 账号）：`flutter run` 选 iOS Simulator，仅能验证 UI，无法测真实定位。
- **真机直装 / Ad Hoc**：需 Developer 账号，注册设备 UDID，适合内部测试。
- **TestFlight**：需 Developer 账号，上传后邀请测试员，适合小范围分发。
- **App Store 上架**：需 Developer 账号 + 审核，正式发布。

### 本机已踩/需注意的点
- **iOS 定位权限必加**：之前只在 Android 的 `AndroidManifest.xml` 加了权限，iOS 端 `Info.plist` 没有；
  不补会导致签到在 iOS 直接崩溃，且上架审核必被拒。
- **`flutter create` 会覆盖 Android 配置**：在 Mac 生成 ios 时可能重写 android 模板文件，
  生成后请确认 `AndroidManifest.xml` 定位权限、`build.gradle.kts` 的 `compileSdk=36` 仍在。
- **图标**：默认占位图标可跑通流程，上架需提交正式 App Icon 全套（建议用 `flutter_launcher_icons` 生成）。
- **架构**：iOS 需 arm64；Apple Silicon（M 系列）Mac 原生支持，Intel Mac 需 Rosetta 跑部分工具链。
- **中文路径**：Mac 上构建同样建议工程放在英文路径，避免偶发工具链解析问题。


