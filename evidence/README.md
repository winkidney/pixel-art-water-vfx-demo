# 实机验证索引

| 阶段 | 入口 |
| --- | --- |
| 当前参数面板与默认画面对照 | [参数验收](parameters/README.md) |
| 158 项参数实际覆盖 | [覆盖报告](parameters/coverage-report.json) |
| 当前日夜场景回归 | [运行报告](parameters/scene-regression/runtime-report.json)、[像素检查](parameters/scene-regression/render-checks.json) |
| 首次石潭迁移 | [运行报告](stone-basin/runtime-report.json)、[像素检查](stone-basin/render-checks.json) |
| 旧洞窟兼容场景 | [最近回归](parameters/legacy-regression/runtime-report.json) |
| 技术讲解视频 | [成片检查](video/qa-report.json)、[标题与封面](video/title-cover-check.json)、[混音检查](video/bgm-mix-check.json) |

根目录中的洞窟截图和报告保留为早期实验依据。每项结论应结合原报告的设备、时间与运行方式阅读；录制输出规格不代替实时性能测量。目录调整的验证另见[结构检查](repository-structure.json)。
