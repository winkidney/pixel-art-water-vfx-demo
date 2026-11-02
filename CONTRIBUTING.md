# 继续开发与验证

## 修改入口

- 场景、角色和时段：`demo/scripts/main.gd`。
- 水面与角色效果：`demo/shaders/`。
- 默认值、范围与预设：`demo/assets/water-parameters.json`、`demo/scripts/parameter_store.gd`。
- 面板：`demo/scripts/parameter_panel.gd`。
- 语义数据生成：`tools/build_maps.py`、`tools/build_stone_basin_maps.py`。

运行工程和视频制作工程相互独立。新增素材时保留来源、提示词与实际输入输出，不以可重生成代码代替原始生成素材。

## 检查

在仓库根目录执行 `python3 tools/verify_repository.py`，检查文档链接、Godot 资源与交付文件位置。

修改参数定义后，运行 `python3 tools/generate_parameter_reference.py`。图像处理工具的依赖见 `requirements-dev.txt`。

修改水面或角色着色器后，在真实图形会话中运行：

```sh
godot --path demo --script res://scripts/audit_stone_basin.gd
python3 tools/check_stone_basin_render.py
```

参数、面板和旧场景还有各自的检查脚本，见[运行与验证指南](docs/guides/running.md)及[验收索引](evidence/README.md)。headless 导入只检查工程加载与脚本解析，不能代替真实 GPU 画面验证。记录性能时应注明设备、渲染器和测量方式。

## 文件管理

当前可观看成果放 `media/`，旧版成片放 `media/archive/`；分镜、配音、无损取景与封面代码放 `production/video/`。生成报告与截图按实验阶段保存到 `evidence/`，临时文件与压缩包放 `.local/`。

根目录保留项目说明与配置，新增文档先加入[文档索引](docs/README.md)。移动文件时同步更新内部链接、工具路径与清单哈希。

`python3 tools/package_demo.py --dry-run --working-tree` 可预览当前工作快照的打包清单。正式打包默认要求干净工作区；显式使用 `--working-tree` 可记录尚未提交的工作快照，不会替你提交。
