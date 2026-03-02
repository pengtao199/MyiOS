# AGENTS.md

## 1. 仓库定位（必须先理解）
- 本仓库是 **iOS UI/交互样例集合**，不是完整业务 App。
- `Demo` Target 只承担「样例展示容器」职责，不承载业务网络层、账号体系、持久化等正式应用架构。
- 后续开发目标：保证样例可快速预览、可对比、可复用，同时不破坏主 Target 编译稳定性。

## 2. 目录与文件边界（强约束）
- `Demo/`：参与 `Demo` Target 编译的正式示例代码（必须可编译）。
- `Demo/Demos/`：Demo 主目录。
- 简单单屏 demo：直接放 `Demo/Demos/XxxDemoView.swift`，不再额外嵌套子目录。
- 复杂 demo：使用 `Demo/Demos/<DemoName>/`，并把关联文件放在同一目录内。
- 复杂 demo 的外部依赖统一放：`Demo/Demos/<DemoName>/Dependencies/`。
- `Demo/Demos/IconShowcase/Dependencies/`：当前仅服务 IconShowcase 的底层实现。
- `Samples/`：不参与 Target 编译的参考内容与草稿区。
- `Samples/` 下的示例建议优先使用 `.md` 或说明文档；若放 `.swift`，必须保证不会被加入 `Demo` Target。

## 3. 新增示例的标准流程
1. 先判断复杂度：简单单屏用单文件；复杂 demo 再建 `Demo/Demos/<DemoName>/` 目录。
2. 每个示例必须提供 `#Preview`，并保证单文件可预览。
3. 示例入口由 `Demo/DemoApp.swift` 统一切换，不允许多个 `@main` 并存于同一 Target。
4. 复杂实验性代码先放 `Samples/`，稳定后再迁移到 `Demo/`。

## 4. 编译与可用性规则
- `Demo` Target 中禁止提交“半成品”代码（占位类型缺失、依赖不存在、不可编译 extension）。
- 使用 iOS 新 API（如 `GlassEffectContainer`）时，必须加 `#available` 和降级路径。
- 默认以当前 Target 最低系统版本为准进行兼容设计（当前构建设置显示为 iOS 17.0）。
- 不要把调试输出长期保留在交互主流程（`print` 仅允许临时调试，提交前清理或改为可控日志）。

## 5. UI 示例实现规范
- 单个示例文件职责单一：一个核心组件 + 必要的子视图，不要在一个文件内混入多个无关 demo。
- 状态管理优先 `@State`/`@Binding` 的最小闭包范围，避免跨示例共享可变状态。
- 常量（尺寸、间距、颜色）集中定义为局部 `private let`，避免魔法数字散落。
- 示例文案可中文，但结构命名（类型/方法/文件名）统一英文。

## 6. Dependencies 处理规则
- `Demo/Demos/<DemoName>/Dependencies/` 视为该 demo 的依赖层（可包含克隆的开源代码）。
- 非必要不改；必须改时，仅做最小补丁，并在变更注释中写明原因与影响范围。
- 禁止把业务逻辑耦合进 `Dependencies/`。
- 若发现私有 API 或高风险实现（如注释中明确 private API），在业务化前必须替换或隔离。
- 单依赖场景默认不再额外嵌套子目录，直接放在 `Dependencies/` 下；只有同一 demo 存在多个依赖时再分子目录。

## 7. 代码组织与命名
- 命名遵循 Swift 官方风格：类型/协议使用 `UpperCamelCase`，变量/函数/属性使用 `lowerCamelCase`。
- View 类型命名：`XxxDemoView`、`XxxShowcaseView`、`XxxCard`。
- 文件名必须与主类型一致或强相关，避免 `ContentView.swift` 这类泛名污染。
- 避免无语义缩写（仅保留通用缩写如 `URL`、`ID`、`UUID`）。
- 简单 demo 不嵌套目录，直接放 `Demo/Demos/`。
- 复杂 demo 才使用子目录，并在该目录内组织子文件与依赖。
- 依赖命名使用真实项目名：如 `LiquidGlassKit`，禁止 `xxxVendor`、`tempLib`、`newCode` 这类临时命名。

## 8. 提交前检查清单（每次必做）
1. 小改动（文案、样式微调、目录整理）默认不跑构建；仅在结构变更/依赖变更/编译相关改动时再跑构建检查。
2. 关键示例在 Preview 可打开，无红色编译错误。
3. 新增文件确认目标归属正确：草稿不进 Target，正式示例进 Target。
4. 无残留临时调试代码、无无用资源、无重复示例文件。
5. README 或 Samples 说明同步更新（新增示例时至少补一行用途说明）。

## 9. 明确禁止事项
- 禁止把不完整代码直接丢进 `Demo/`。
- 禁止在 `Demo` Target 里新增第二个 `@main`。
- 禁止在未做可用性判断时直接上 iOS 高版本专有 API。
- 禁止在未评估风险时改动 Dependencies 底层渲染逻辑。
- 禁止删除 `Samples/LegacyClockDemo/`（该目录作为保留的独立 demo）。

## 10. 克隆新依赖接入规则（后续统一执行）
- 新克隆代码必须先放进对应 demo 的 `Dependencies/`，不得直接散落在 `Demo/` 根目录。
- 若当前 demo 只有一套依赖，直接平铺在 `Dependencies/`；当出现第二套依赖时，再拆分 `Dependencies/<DependencyName>/`。
- 目录命名使用依赖官方仓库名或通用名（`UpperCamelCase`），不带 `-main`、`-master`、`copy` 后缀。
- 接入时只保留实际使用文件；示例 App、测试、CI、文档等无关文件默认不纳入主工程目录。
- 如依赖暂时只被一个 demo 使用，不提前抽共享层；当出现第二个 demo 复用时再考虑提取共享目录。
- 对克隆依赖的本地修改，必须在相邻位置补一句注释说明“为何修改”和“影响范围”。

## 11. 推荐演进方向（可逐步执行）
- 增加一个 `DemoIndexView` 作为统一示例目录页（分类展示每个 demo）。
- 把当前页面拆分为 `Pages/`、`Components/`、`Dependencies/` 三层目录，降低“文件混杂感”。
- 为每个可复用组件补一段简短注释：用途、输入参数、适用系统版本。
