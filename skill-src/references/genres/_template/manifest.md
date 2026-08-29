# 题材包：{显示名}（{genre}）

genre: {genre}
display: {显示名}
core_doc: {核心设定文档文件名，如 xxx.md}
core_skeleton: {core_doc 常驻骨架节的 ## 标题，如 xxx；未声明则 core_doc 全文读取}
signal_doc: {投放物地图文件名，如 xxx.md}
signal_term: {投放物单数术语}
status_section: {/status 题材区块标题}
sanitize_fields: {characters.md 中须对无真相视角剔除的字段，逗号分隔}
templates:
  style_guide: {style_guide 模板文件名}
  characters: {characters 模板文件名}
  core_doc: {core_doc 模板文件名}
  signal_doc: {signal_doc 模板文件名}
  outline: {outline 模板文件名}

> 填充说明见 `_SPEC.md` 第 2 节；完成后删除本行及以下待办。
> - [ ] 与 `_registry.md` 的 id / 显示名一致
> - [ ] sanitize_fields 所列字段存在于 characters 模板
