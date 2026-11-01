# 像素水体 Mini 实验

独立 Godot 4 项目。提供 158 项运行中参数控制，可手工调节并管理命名预设。打开 `tidal-grotto/project.godot` 后按 F5 运行。

当前默认场景为已采用的宽瀑布石潭，右上角切换白天和夜晚。水体迁移已完成，包含动态瀑布、深浅水、折射、焦散、涟漪、角色浸没与夜间反光。

- [设计与技术说明](docs/water-vfx-design.md)：技术如何影响画面、组合流程与调参建议
- [完整实验复盘](docs/water-vfx-retrospective.md)：设计演变、问题修正、验证证据与边界
- [调参验收记录](evidence/parameters/README.md)
- [调参面板实机演示](parameter-workbench-demo.mp4) · [面板预览](parameter-workbench-preview.png)
- [手工调参说明](tidal-grotto/docs/parameters.md) · [全部参数默认值与范围](tidal-grotto/docs/parameter-reference.md)
- [白天 / 夜晚实机对照](stone-basin-runtime-comparison.png)
- [30 秒实机视频](stone-basin-day-night-demo.mp4)
- [Godot 项目压缩包](stone-basin-godot4.zip)
- [已确认设计归档](designs/stone-basin-widefall-v5/README.md)
- [迁移记录、提示词与来源](tidal-grotto/docs/stone-basin/README.md)
- [运行检查](evidence/stone-basin/runtime-report.json) 与 [像素检查](evidence/stone-basin/render-checks.json)

- [运行说明](tidal-grotto/README.md)
- [ImageGen 素材和完整提示词](tidal-grotto/docs/imagegen.md)
- [参考与实现边界](tidal-grotto/docs/references.md)
- [验证结果](tidal-grotto/docs/validation.md)
- [原洞窟 29 秒演示](tidal-grotto-demo.mp4)

`evidence/` 保存真实窗口截图、运行报告与渲染差异检查。项目源码、原始素材、演示与证据纳入本仓库；Godot 缓存和可重新生成的压缩包不纳入版本历史。
