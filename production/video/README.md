# 制作源文件

本版采用用户选中的 Higgs TTS 3 Q8_0 固定合成女声参考方法。完整交付与来源见[上级说明](../../docs/video-production.md)。

This audio was created with Boson AI's Higgs Audio: https://www.boson.ai/higgs-audio

## 内容

- `plan.json` 保存七章、23 个镜头、33 句讲稿与片头八项特性的出现时间。
- `capture-assets/` 保存 21 段真实 Godot 视口无损素材及 RGB 哈希。`record_showcase.gd` 录制基础镜头，`record_opening_flow.gd` 补录汇流隔离镜头。
- `narration-assets/` 保存本版实际使用的逐句 WAV、文本、拼接音频、原始输出、请求与生成记录。旧版 Kokoro 成片另有本地备份，不混入本版音轨。
- `reference/` 保存选定的 15.05 秒 Kokoro zf_001 合成参考录音、准确逐字稿与来源。该参考不是真人录音。
- `synthesize.py` 默认转入 `synthesize_higgs.py`，使用本地 audio.cpp v0.9.3、Q8_0 模型与固定参考。`synthesize_kokoro_legacy.py` 仅保留旧版生成方法，供来源追溯。
- `assemble_audio.py` 根据每句实际长度同步字幕、整理响度并写章节。本版最大 tempo 为 1.0，无加速。
- `render_video.py` 合成实机素材、图解、字幕、章节进度和二维码。`build_covers.py` 以真实截图分别排两种封面。
- `verify_video.py` 检查最终编码视频；`verify_opening.py` 检查八项标注并导出片头预览；`check_speech.py` 提供辅助识别，缓存以实际音频哈希判定。
- `typography.py` 与 `fonts/` 保存 Z 工坊像素黑体 12px、整数放大方法及许可。
- `model-provenance.json`、`HIGGS-LICENSE.txt`、`higgs-license-source.json`、`AUDIOCPP-LICENSE.txt` 保存本版模型、程序来源与许可。Kokoro 许可因参考来源而保留。

下列只写文件名的 Python 命令在 `production/video/` 目录执行；`tools/` 中的打包命令从仓库根目录执行。

## 复用已生成素材

需要 Python 3.12、FFmpeg 与当前项目。工作目录至少留 10 GB，不要放进 Git。已有 WAV 可直接重出，无需下载模型或启用 GPU。

```sh
python -m venv .video-venv
.video-venv/bin/python -m pip install -r requirements.txt
.video-venv/bin/python prepare_captures.py --work /path/to/work
.video-venv/bin/python assemble_audio.py --work /path/to/work --out /path/to/render
.video-venv/bin/python build_covers.py --work /path/to/work --out /path/to/render
.video-venv/bin/python render_video.py --project /path/to/pixel-art-water-vfx-demo --work /path/to/work --out /path/to/render
```

`--project` 指向包含 `demo/` 的仓库根目录。恢复素材后将 `capture-assets/flow-capture-check.json` 复制到渲染输出目录，再运行 `verify_opening.py --out /path/to/render`。`verify_video.py` 另需 OpenCV 与 pypinyin。辅助识别另需 Faster Whisper 1.2.1，已有结果可直接查看。复用时不必重做识别。

## 修改讲稿并重生成旁白

先修改 `plan.json`。另备本地 audio.cpp v0.9.3 CUDA 程序、依赖库与 `higgs-audio-v3-tts-4b-q8_0.gguf`。固定下载地址与 SHA-256 见 `model-provenance.json`。`--runtime-root` 下应有 `models/`、`runtime/audiocpp/`、`runtime/cuda-libs/` 和 `runtime/nccl/`，无需全局安装。权重和运行包未随本交付分发。

```sh
python synthesize.py --work /path/to/work --runtime-root /path/to/local-higgs-runtime
```

脚本校验权重、仅监听 127.0.0.1、传入固定参考录音和逐字稿。seed 为 20261102，text_chunk_size 为 40，温度、top-p 和 top-k 使用该运行程序默认值，不添加情绪或音高标签。短句生成完毕即退出自己的服务。

本版 `refs_tech` 的整句请求达到 token 上限，失败记录在 `narration-assets/attempts/`。成功版只把原文按句号拆开，逐段生成后拼接；`--split-ids` 明确记录这项处理。原始输出在 `narration-assets/raw/`，有效首尾裁剪和请求在 `narration-assets/higgs-logs/`。不裁掉句中停顿。改变讲稿后重做配音拼接、字幕和画面，并检查每段预算。识别结果只有辅助意义，不能代替人工试听。

## 重新取景

需要实际图形会话，不用 headless 空渲染代替。

```sh
godot --path /path/to/pixel-art-water-vfx-demo/demo --display-driver x11 --rendering-method gl_compatibility --script /path/to/pixel-art-water-vfx-demo/production/video/record_showcase.gd -- /path/to/work/captures
godot --path /path/to/pixel-art-water-vfx-demo/demo --display-driver x11 --rendering-method gl_compatibility --script /path/to/pixel-art-water-vfx-demo/production/video/record_opening_flow.gd -- /path/to/work/captures
```

第二段追加或替换汇流镜头记录。隔离镜头冻结背景波动，将原有汇流折射幅度设为 1.40 px，并在视频画面标明；裁切排除水幕及白沫，不更改游戏默认值或保存用户预设。21 段原始帧共约 2.88 GB。`archive_captures.py` 负责更新无损归档。

## 复现边界

GPU 驱动、运行版本和采样可能令重生成的语音及压缩视频字节不同。固定种子不保证跨平台逐采样相同。归档 RGB 片段和实际使用 WAV 都有哈希，可恢复本片输入。模型权重、完整环境与原始 RGB 缓存不随文件包分发。

## 重出背景音乐版

`music-assets/pixel-art-water.m4a` 是用户提供的原始音乐，来源与哈希见同目录 `provenance.json`。先按上面的流程生成纯旁白视频，再在另一个输出目录混音：

```sh
python mix_bgm.py --video /path/to/dry/godot-sea-of-stars-water-vfx.mp4 --narration /path/to/dry/narration.wav --music music-assets/pixel-art-water.m4a --out /path/to/mixed --music-db -14
```

脚本保存一条合并后的立体声 AAC 音轨，复制视频编码流并校验哈希。默认将音乐降低 14 dB，再用旁白做侧链压缩，首尾淡入淡出。输入视频和输出目录必须分开。`mix-settings.json` 与混音检查记录实际使用的数值。纯女声原始 WAV 和逐句素材仍可复用。

## 本版标题与封面

发布标题：Godot 复刻《星之海》通透像素水体效果｜2D 水面 Shader 原理拆解 | Sea of Stars。

封面由 build_covers.py 使用真实 Godot 日夜截图独立排版，分别输出 1920×1080 和 1600×1200。主画面放大通透水底和角色入水，保留夜间反光小窗。字体仍为原生 12px 像素字形的整数倍。cover-receipt.json 记录文本边界、截图裁切和哈希。

render_video.py 可传入 --audio-file /path/to/soundtrack.m4a，复制现有 AAC 混合音轨；只更新片头标题和视频元数据时，无需重新合成语音或混音。正式视频中的完整标题按主标题和副标题分两行呈现。

实际用于封面的两张原始 PNG 保存在 cover-assets/，生成器优先读取它们，可精确复用本次截图输入。

## 整理后的交付目录

当前成片为 `media/video/pixel-water-shader.mp4`，封面在 `media/images/covers/`，音轨在 `media/audio/`，讲稿与分镜在本目录，成片检查在 `evidence/video/`。这些路径相对仓库根目录。渲染器和检查器仍接收独立的 `--out` 工作目录，生成文件名统一为 `pixel-water-shader.mp4`。从仓库根目录执行 `python3 tools/package_video.py` 可重新打包制作源文件。
