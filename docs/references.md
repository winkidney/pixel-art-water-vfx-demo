# 参考与实现边界

本页区分参考来源、项目自己的实现与分阶段验证。初版实验形成于 2026-11-01，本次来源及版本说明整理于 2026-11-02，对照源码 `0fe0c87`。完整解释见[设计与技术说明](water-vfx-design.md)和[实验复盘](water-vfx-retrospective.md)。

## 1. 最初的视频与讨论

### Fishy Games：二维像素水体

[How I Created 2D Pixel Art Water For My Indie Game](https://www.youtube.com/watch?v=DkfKwfjaVx0)，Fishy Games，2025-05-10，8 分 41 秒。

作者讲解水与陆地分层，以高度图表达浅深，叠加焦散、纹理位移、像素采样、精灵倒影与岸线动画。它启发本项目先建立可分离的效果层，再统一像素尺度。可从以下位置回看：

| 内容 | 约略定位 |
| --- | --- |
| 高度图 | [0:56](https://www.youtube.com/watch?v=DkfKwfjaVx0&t=56s) |
| 焦散 | [1:46](https://www.youtube.com/watch?v=DkfKwfjaVx0&t=106s) |
| 纹理位移 | [5:28](https://www.youtube.com/watch?v=DkfKwfjaVx0&t=328s) |
| 像素中心采样 | [6:37](https://www.youtube.com/watch?v=DkfKwfjaVx0&t=397s) |
| 倒影 | [6:55](https://www.youtube.com/watch?v=DkfKwfjaVx0&t=415s) |
| 岸线动画 | [7:56](https://www.youtube.com/watch?v=DkfKwfjaVx0&t=476s) |

本项目采用 RGBA 语义图、拟合深度、整数折射与翻转角色副本。函数焦散、距离场泡沫、连续角色水线和调参系统是项目的具体实现，不能写成照搬教程算法。

### Reddit：角色浸没水线讨论

[How did Sea of Stars render varying submersion on water?](https://www.reddit.com/r/gamedev/comments/1d3cdqq/how_did_sea_of_stars_render_varying_submersion_on/)，r/gamedev，提问者 u/Jpar125。

问题关注水线如何随角色身体形状弯曲。评论者 u/AuraTummyache 提出给精灵使用弯曲梯度，再按水深选择对应水线；其他评论还讨论三维水面、法线和高度图。这提供了“精灵局部形状与地图浸没深度可以分开处理”的可行方向。

本项目用局部纵向高度加横向二次曲线近似角色形状，由地图深度驱动水位，再处理水下颜色、透明度、扰动和接触亮线。这里没有复原《星之海》的内部代码。帖子和评论属于社区推测，不能用来证明该游戏采用何种底层结构。

本次可读取正文，页面只提供相对发布时间，未填写未核实的精确发布日期。

### Red Giraffe：三维像素海洋

[How I Created Pixel Art Oceans | Pixel Perfect](https://www.youtube.com/watch?v=RU3EReALbEU)，Red Giraffe，2026-03-22，13 分 34 秒。

作者在 Unity 三维平面水体中组合深度着色、折射、顶点波动、泡沫和镜像相机反射，并处理统一像素尺度。作者章节包括：

| 内容 | 定位 |
| --- | --- |
| Depth | [1:06](https://www.youtube.com/watch?v=RU3EReALbEU&t=66s) |
| Refraction | [3:44](https://www.youtube.com/watch?v=RU3EReALbEU&t=224s) |
| Displacement | [5:05](https://www.youtube.com/watch?v=RU3EReALbEU&t=305s) |
| Foam | [6:42](https://www.youtube.com/watch?v=RU3EReALbEU&t=402s) |
| Reflections | [8:45](https://www.youtube.com/watch?v=RU3EReALbEU&t=525s) |

本项目借鉴各层配合与统一像素尺度的原则，用二维距离场、贴图采样与函数光带达到相应观感，没有采用三维顶点波、实时深度缓冲或第二反射相机。该视频也不是 Godot 二维操作教程。

### 视频核验范围

上面两个视频的标题、作者、上传日期、时长和内容摘要，依据实验期间保存的作者元数据与英语自动字幕。第一条视频的约略定位来自自动字幕，第二条来自作者章节。初次抓取视频流返回 HTTP 403，未完成逐帧播放核对；文档整理时也未取得可逐帧核查的视频正文。字幕可能存在术语识别错误，定位用于回看，不能当成精确画面标注。

工作目录中的原始元数据和字幕未纳入仓库，文档保留直接链接与必要摘要，不复制整份字幕。项目效果的验证来自自己的 GPU 截图和实际窗口记录。

## 2. Godot 官方资料

| 官方资料 | 与本项目的对应 |
| --- | --- |
| [CanvasItem shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html) | 二维着色器、`UV`、`TEXTURE`、`COLOR` 和 `unshaded` 的语义 |
| [Multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html) | 低分辨率绘制与整数缩放的原理；具体 `SubViewport` 实现以本项目为准 |
| [Importing images](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html) | 图像导入与透明边缘处理；本项目技术遮罩关闭边缘修复并使用最近邻 |
| [FileAccess](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html) 与 [JSON](https://docs.godotengine.org/en/stable/classes/class_json.html) | 本机预设的文件读写与序列化 |

官方 stable 文档会随引擎版本更新。项目实际验收版本为 Godot 4.7.2，现有实现行为以源码和保存证据为准。当前水面直接读取传入的 `seabed`，没有使用屏幕纹理或 `BackBufferCopy`。

## 3. 用户附图与 ImageGen 素材

用户提供的图像用于视角、像素语言、配色与场景结构参考。热带水景、冬季森林和幽暗遗迹分别进入不同设计轮次，最终采用石阶泉湾的宽瀑布日夜方案。原始概念的水线、焦散、灯火和反光是静态示意，不构成程序效果的证据。

原型美术提示词见 [imagegen.md](assets/legacy/imagegen.md)，当前日夜底图、输入角色与哈希见[迁移记录](assets/stone-basin/README.md)。内置 ImageGen 没有提供可固定的模型版本或随机种子，提示词与哈希可以追溯输入输出，不能保证重新生成相同像素。

## 4. 实验中发现并修正的问题

以下前六项来自初版洞窟，后续石潭迁移又补上独立瀑布、环境反光和前景遮挡。完整阶段记录见[实验复盘](water-vfx-retrospective.md)。

1. 生成角色的 Alpha 中存在几乎不可见的杂点。直接用非零透明包围框会把人物缩小，现以 0.25 透明度阈值计算各方向有效范围。
2. 粗水域轮廓切进岩壁，泡沫出现在岩石上。现结合语义轮廓、水色与补洞处理，并排除突出物件。
3. 用颜色分类制作深度会误判中性水下石块。现按连续水盆轮廓计算深度，可走数据单独定义。
4. 直接朝目标移动会在凸岸卡住。现加入小网格绕行，检查完整往返路径。
5. 大头角色按普通比例浸没时会淹到脸。现按实际比例校准水线，并将涟漪对齐出水位置。
6. 默认透明边缘修复改写技术遮罩 RGB，造成越界。现关闭该导入选项，并检查岸外像素变化。

## 5. 初版与当前版本的边界

初版洞窟没有独立瀑布动画，也没有完整的前景物件遮挡。此前文档将它们写在“当前边界”下，本次明确为历史状态。石潭版本已经有 `waterfall.gdshader`、前景接地高度遮罩与脚点遮挡，最新验证见[参数与场景验收](../evidence/parameters/README.md)。

当前仍保留以下边界：

- 底图包含静态水色、瀑布与落水白沫，关闭程序层不会变成干海床。
- 水深、可走范围与物件语义为本图校准。潮位改变水色和浸没，不移动岸线。
- 环境反光是二维投影和函数光带，角色倒影是翻转副本，没有完整物理反射或动态光照求解。
- 角色只有四个静态朝向配程序运动，未制作完整行走和游泳帧。
- 水下石块未逐个建立体积和碰撞，黄昏仍只有概念稿。
- 新地图需要重建语义数据、反光与汇流锚点、导航和验证。已有短时性能只代表报告中的机器。
