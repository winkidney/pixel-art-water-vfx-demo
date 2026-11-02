# 素材与许可索引

## 运行美术

当前底图与角色放在 `demo/assets/`，技术遮罩由 `tools/` 中的脚本生成。

- [石潭日夜清理、提示词与来源](stone-basin/README.md)
- [当前美术输入输出清单](stone-basin/asset-manifest.json)
- [原始洞窟与角色生成记录](legacy/imagegen.md)
- [原始素材清单](legacy/asset-manifest.json)
- [概念采用记录](../../designs/selection.json)

用户参考图用于风格和构图探索。ImageGen 提示词及实际输出已保存，不能保证重新生成相同像素。

## 视频制作素材

- 像素字体：[来源](../../production/video/fonts/SOURCE.json)、[SIL OFL 1.1](../../production/video/fonts/zlabs-pixel-font-OFL.txt)。
- Higgs 配音：[模型及运行程序来源](../../production/video/model-provenance.json)、[许可](../../production/video/HIGGS-LICENSE.txt)。
- 合成女声参考：[来源](../../production/video/reference/provenance.json)、[Kokoro 许可](../../production/video/KOKORO-LICENSE.txt)。
- audio.cpp：[许可](../../production/video/AUDIOCPP-LICENSE.txt)。
- 用户提供的 Suno 音乐：[输入与哈希](../../production/video/music-assets/provenance.json)。

视频署名保存在[发布说明](../../media/video/description.txt)，包含 Boson AI Higgs Audio。运行 Godot 演示不需要安装这些视频制作模型。

## 项目级许可

仓库目前没有统一的项目级 `LICENSE`。第三方组件各自保留原许可，生成素材和用户提供素材按上述来源分别记录。
