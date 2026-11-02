# 技术、美术与制作参考

成片标题为《Godot 复刻《星之海》通透像素水体效果｜2D 水面 Shader 原理拆解 | Sea of Stars》，表现方法是本项目的二维视觉近似。下列视频与讨论提供启发，不构成《星之海》官方实现证据。

## 水体技术

1. **How I Created 2D Pixel Art Water For My Indie Game**，Fishy Games，2025-05-10。独立水层、高度、焦散、位移、像素采样、倒影与岸线动画。
   [完整视频](https://www.youtube.com/watch?v=DkfKwfjaVx0) · [高度图 0:56](https://www.youtube.com/watch?v=DkfKwfjaVx0&t=56s) · [纹理位移 5:28](https://www.youtube.com/watch?v=DkfKwfjaVx0&t=328s) · [倒影 6:55](https://www.youtube.com/watch?v=DkfKwfjaVx0&t=415s)
2. **How I Created Pixel Art Oceans | Pixel Perfect**，Red Giraffe，2026-03-22。深度、折射、泡沫、反射和统一像素尺度，原视频为 Unity 三维水体。
   [完整视频](https://www.youtube.com/watch?v=RU3EReALbEU) · [Depth 1:06](https://www.youtube.com/watch?v=RU3EReALbEU&t=66s) · [Refraction 3:44](https://www.youtube.com/watch?v=RU3EReALbEU&t=224s) · [Foam 6:42](https://www.youtube.com/watch?v=RU3EReALbEU&t=402s)
3. **How did Sea of Stars render varying submersion on water?**，r/gamedev，u/Jpar125。水线与精灵形状的社区讨论。
   [帖子与评论](https://www.reddit.com/r/gamedev/comments/1d3cdqq/how_did_sea_of_stars_render_varying_submersion_on/)

两个 YouTube 标题、日期、作者和摘要依据实验期间保存的作者元数据及英语自动字幕；未完成视频逐帧核对。Reddit 正文已核查，其中多种结构解释均属推测。项目使用函数焦散、距离场泡沫与局部高度近似，具体区别见[参考与实现边界](references.md)。

## Godot 官方资料

- **CanvasItem shaders**：[二维着色器说明](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html)
- **Multiple resolutions**：[视口与整数缩放](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html)
- **Importing images**：[图像与透明边缘导入](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html)
- **FileAccess** 与 **JSON**：[文件读写](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html)、[JSON 数据](https://docs.godotengine.org/en/stable/classes/class_json.html)

## 美术与字体

- 用户提供的像素 JRPG 水景、冬季森林和幽暗遗迹截图用于风格探索；没有为未核实的原发布页编造标题或链接。最终运行场景采用宽瀑布石阶泉湾。
- **ImageGen 场景与四方向角色**：[初版生成记录](assets/legacy/imagegen.md)、[日夜清理提示词与素材来源](assets/stone-basin/README.md)、[采用概念归档](../designs/stone-basin-widefall-v5/README.md)。哈希记录可追溯实际输出，不能保证重生相同像素。
- **Z Labs Pixel 12px M CN / Z 工坊像素黑体 12px M CN**：Astro_2539，用户此前技术封面使用的字体。[来源记录](../production/video/fonts/SOURCE.json)、[SIL OFL 1.1 许可](../production/video/fonts/zlabs-pixel-font-OFL.txt)。
- 两张封面使用[真实取景记录](../production/video/capture-assets/capture-report.json)中的截图，参考封面只提供版式方向。

## 旁白与制作

- **pixel-art-water**：用户提供的背景音乐 `pixel-art-water.m4a`，内嵌元数据标注 Suno 制作。[实际输入与哈希](../production/video/music-assets/provenance.json)。混音降低音乐音量，讲话时进一步衰减，首尾淡入淡出。
本版女声署名：This audio was created with Boson AI's Higgs Audio: https://www.boson.ai/higgs-audio

- **Higgs TTS 3**，Boson AI：[官方模型与 Creator Use 说明](https://huggingface.co/bosonai/higgs-tts-3-4b)、[官方许可](https://huggingface.co/bosonai/higgs-tts-3-4b/blob/main/LICENSE)。本版实际发声模型为 Q8_0 量化版本，固定权重 revision 和哈希见[来源记录](../production/video/model-provenance.json)。
- **audio.cpp v0.9.3**：[推理程序](https://github.com/0xShug0/audio.cpp)、[Higgs 本地集成](https://github.com/0xShug0/audio.cpp/blob/main/docs/models/higgs_audio_tts.md)。本机临时回环服务，完成后退出。
- **Kokoro-82M-v1.1-zh**，hexgrad，预设女声 `zf_001`，用于固定合成参考录音：[模型与说明](https://huggingface.co/hexgrad/Kokoro-82M-v1.1-zh)、[官方中文示例](https://huggingface.co/hexgrad/Kokoro-82M-v1.1-zh/blob/main/samples/make_zh.py)、[程序代码](https://github.com/hexgrad/kokoro)。模型与程序为 Apache-2.0，随源文件保留许可和来源。
- **FFmpeg**：[官方文档](https://ffmpeg.org/documentation.html)。用于视频编码、保音高调速、响度整理、音轨与章节封装。
- **项目设计与证据**：[设计说明](water-vfx-design.md)、[实验复盘](water-vfx-retrospective.md)、[运行中调参验收](../evidence/parameters/README.md)。

片尾项目二维码指向 [pixel-art-water-vfx-demo](https://github.com/winkidney/pixel-art-water-vfx-demo)。该仓库为私人仓库，需要访问权限；视频与源文件尚未自动发布到公开平台。
