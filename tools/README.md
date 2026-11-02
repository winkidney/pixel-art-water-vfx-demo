# 仓库工具

以下命令从仓库根目录执行。Python 图像工具依赖见 ../requirements-dev.txt，Godot 演示运行本身无需 Python。

| 工具 | 用途 |
| --- | --- |
| `verify_repository.py` | 检查内部链接、Godot 资源、Python 语法及交付清单 |
| `build_maps.py` | 重建原洞窟语义数据 |
| `build_stone_basin_maps.py` | 重建当前石潭遮罩 |
| `generate_parameter_reference.py` | 根据实际定义生成参数默认值与范围文档 |
| `check_render.py` | 检查旧场景的真实截图 |
| `check_stone_basin_render.py` | 检查当前日夜场景截图 |
| `package_demo.py` | 打包完整可分发工作快照；默认排除本地缓存 |

可先执行 `python3 tools/package_demo.py --dry-run --working-tree` 查看待打包规模，正式压缩包默认写入 `.local/dist/`。
