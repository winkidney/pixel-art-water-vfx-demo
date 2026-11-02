# 项目结构与路径迁移

根 README 面向首次访问者，先展示效果、运行方法和文档入口。Godot 的资源根目录独立在 demo/，文档与视频素材不参与工程资源导入。

| 原路径 | 现在的路径 | 用途 |
| --- | --- | --- |
| `tidal-grotto/` | `demo/` | Godot 运行工程 |
| `tidal-grotto/tools/` | `tools/` | 仓库级生成、检查与打包 |
| `tidal-grotto/docs/parameters.md` | `docs/guides/parameters.md` | 手工调参 |
| `tidal-grotto/docs/parameter-reference.md` | `docs/guides/parameter-reference.md` | 参数定义生成的文档 |
| `tidal-grotto/docs/stone-basin/` | `docs/assets/stone-basin/` | 日夜美术输入与来源 |
| 根目录的截图和演示 MP4 | `media/images/`、`media/demos/` | 可观看的演示 |
| `video/` 中的当前成片 | `media/video/pixel-water-shader.mp4` | 唯一当前视频入口 |
| `video/` 中的封面与音轨 | `media/images/covers/`、`media/audio/` | 发布媒体 |
| `video/edit-source/` | `production/video/` | 视频制作工程 |
| `video/evidence/` | `evidence/video/` | 成片验证 |
| `video/README.md` | `docs/video-production.md` | 交付和制作说明 |
| 旧版成片与同内容的旧文件名 | `media/archive/` | 历史版本，不删除原文件 |
| `work/` 和原有 ZIP | `.local/work/`、`.local/dist/legacy/` | 本机临时文件与旧压缩包 |

`designs/` 保留概念设计演变，`evidence/` 保留原始实验阶段。录制日志中的绝对路径表示录制时的位置，作为历史记录保留；当前文档链接、可运行工具与交付清单使用新路径。

本次只整理目录和入口，不调整着色器、参数默认值、美术素材或视频音画内容。Godot 用户数据目录和命名预设规则保持原设置。重新导入工程时选择 demo/project.godot。
