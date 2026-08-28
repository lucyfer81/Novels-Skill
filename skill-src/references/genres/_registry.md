# 题材注册表

> 本文件是题材包的唯一登记处，也是核心协议（SKILL.md 正文、references 根层文件、scripts）允许出现具体题材内容的镜像来源之一。
> 添加新题材：按 `_SPEC.md` 在本目录创建 `{genre}/` 题材包 → 在下表追加一行 → 同步更新 SKILL.md frontmatter description 的题材关键词。

| 顺序 | id | 显示名（zh） | 开场白选项文案 |
|------|----|------------|---------------|
| 1 | mystery | 推理悬疑 | 谜题、案件、真相 |
| 2 | romance | 爱情 | 关系、情感、时机 |

## 使用规则

- 初始化开场白的题材选项**按本表顺序**生成（A、B、C…），每行格式：`{字母}. {显示名} → {开场白选项文案}`
- `genre` 字段取值 = 本表 `id`，初始化时写入 `meta/project_info.md`
- 运行期锁定题材后，题材包路径为 `references/genres/{id}/`；🔴 严禁加载非当前题材的题材包
- `scripts/init_project.sh` 的默认 genre 取本表第一行
