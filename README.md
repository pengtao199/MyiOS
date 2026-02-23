# MyiOS Demo 合集说明

这个仓库用于存放多个 iOS/SwiftUI 示例。

## 当前可运行工程
- Xcode 工程: `Demo.xcodeproj`
- 主 Target: `Demo`
- 入口文件: `Demo/DemoApp.swift`
- 当前示例页面: `Demo/CardSwipeDemoView.swift`

## 为什么之前会预览失败
你改名后，工程配置里目录名和实际文件夹名不一致，导致源码没有被正确编译。
另外，`DemoApp` 引用的页面类型名和实际 `struct` 名不一致，也会直接报错。

## 后续放“参考代码片段”的建议
如果后续有很多“不是完整可运行代码”的片段，不要直接放到 Target 会编译的 `.swift` 文件里。

推荐做法：
1. 放到仓库根目录的 `Samples/` 下，用 `.md` 或 `.txt` 保存。
2. 需要保留 Swift 高亮时，使用 `.swift.md`（例如 `login-flow.swift.md`）。
3. 只有要参与运行/预览的代码，才放进 `Demo/` 目录里。

## 建议目录结构
- `Demo/` 真实参与编译的 App 代码
- `Samples/` 参考片段与草稿（不参与编译）
- `README.md` 项目说明

## 常见问题排查
1. Xcode 报 `Cannot find 'XXX' in scope`
   - 检查 `DemoApp.swift` 里引用的视图名，是否和实际 `struct` 名一致。
2. 预览一直不刷新
   - 在 Xcode 里执行 `Product > Clean Build Folder`，再重新打开预览。
3. 改过文件名后异常
   - 确认工程导航里的文件名、磁盘文件名、`struct` 名三者一致。
