# ImageGen 生成记录

生成日期：2026-11-01。使用内置 `image_gen.imagegen`，没有切换到 CLI/API fallback。工具没有返回可固定的模型版本、随机种子或采样参数，因此提示词可复用，但不能保证重新生成相同像素。

## 场景

项目文件：`assets/grotto-imagegen.png`。实际尺寸 1536×1024，不透明。原始文件名 `exec-f5e4493f-19f8-452c-979a-6c3b4eacd029.png`。用户附图作为风格和氛围参考，未要求保持原图构图。提示中提出平静的底图，实际生成仍有少量静态岸线白边，项目记录了这一限制。

完整提示词：

```text
Use case: stylized-concept. Asset type: background plate for an interactive pixel-art water rendering experiment. Create one original 3:2 landscape 1536x1024 pixel art environment, classic detailed 16-bit JRPG, oblique top-down view, crisp deliberate pixel clusters with a working resolution approximately 768x512. Subject: a tranquil tropical tidal grotto, dark layered basalt cliffs along top and left edge, pale ivory sand beach along bottom and right edges, lush ferns, a few magenta coral fans, turquoise crystals and moss. A very large open continuous central lagoon occupies about 65 percent of image from x=25% to 88%, y=25% to 85%. Lagoon bottom is visible, teal and turquoise, darker muted blue at top-left and light turquoise at bottom-right. Include sparse submerged rocks and coral seen on the bottom, restrained fine texture, subtle seabed shadows. A small single palm tree grows on a rocky islet near the upper-right part of lagoon. Natural irregular curved shoreline. Top right one thin waterfall from cliff to lagoon, pale bright streaks. Main large central lagoon must be clear and spacious for moving a character. Static environment plate ONLY: the lagoon is calm flat color and bottom texture, no surface wave lines, NO white foam, NO surface caustics, NO surface glints; those effects will be drawn live in the game. Palette: deep desaturated indigo and charcoal stone, warm cream sand, teal water, yellow-green foliage, touches of magenta coral. Soft even daylight, handcrafted coherent game environment. Do not make a screenshot of a UI. No people, no characters, no text, no labels, no border, no logo, no watermark. Reference image 1 is style/mood only; create a new original scene with a more open lagoon.
```

## 角色

项目文件：`assets/adventurer-imagegen.png`。实际尺寸 1254×1254，RGBA，保留生成 Alpha。原始文件名 `exec-f6bc4028-36e5-403a-b4d1-4fd504f0a2a8.png`。工具返回尺寸与提示尺寸不同，所以运行时按实际图宽高等分四格，再使用透明度阈值计算各格的有效区域。没有将尺寸假设硬编码为 1024。

完整提示词：

```text
Use case: stylized-concept. Asset type: transparent sprite atlas for a pixel JRPG water experiment. Create a clean 2 by 2 grid of FOUR full-body views of ONE original small adventurer. Each cell exactly equal 512x512 on a 1024x1024 canvas. Within every cell character centered horizontally and standing on baseline 86 percent cell height, full body comfortably inside with transparent margins. Same character in all four cells: short dark navy hair, light cream hooded cape folded behind shoulders, rust-orange tunic, dark brown boots, small teal satchel, warm skin. Chunky classic 16-bit JRPG sprite, crisp pixels, approximately 32x48 logical pixels each character, no smooth gradients, distinct readable silhouette, oblique top-down game view. Upper left cell FRONT facing viewer, upper right cell RIGHT profile facing right, lower left cell BACK facing away, lower right cell LEFT profile facing left. Neutral standing pose, arms slightly separate from torso so silhouette is visible, feet shoulder width apart. These are four directional game sprite views, NOT portrait or character design sheet. No ground shadow, no platform, no ground, no props outside character, no text, no grid lines, no labels, no border, no watermark. Background must be truly transparent.
```

## 资源边界

上面两张图片是美术来源。深度图、语义轮廓、Shader 中的焦散与波纹属于运行时数据和程序效果。原始美术文件直接复制到项目，没有通过重画、抠图或替换纹理冒充生成结果。运行时的裁切、缩放与透明阈值处理保留原始文件。

文件 SHA-256 记录在同目录 `asset-manifest.json`。
