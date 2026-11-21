"""Rebuild the game's offline handbook from the checked-in Chinese course pages."""

from collections import defaultdict
from html.parser import HTMLParser
import json
from pathlib import Path
from tempfile import NamedTemporaryFile


LIBRARY = Path(__file__).resolve().parent
REPO = LIBRARY.parent.parent

# Keep the neutron example within a collision simulation. Use model quantities
# for dosimetry and distinguish ionic screening from polymer persistence length.
EDITED_LESSONS = {
    "10-de3d2cf4": [
        ["物理模型", "中子和静止原子核发生弹性散射时，能把一部分动能转移给反冲核。吸收概率也随能量变化，截面曲线上的局部峰称为共振。"],
        ["关系式", "ξ = ⟨ln(E碰前 / E碰后)⟩，表示一次碰撞平均带来的对数能量损失。"],
        ["模拟例子", "在封闭的虚拟碰撞盒里，分别让粒子与等质量、较大质量的靶粒子正面弹性碰撞。比较反冲速度并核对碰撞前后的总能量。"],
        ["适用范围", "单次正碰用于说明动量与能量交换。统计平均还需说明散射角分布、粒子初态与能量范围。"],
        ["换个条件", "用相同的初速、多组散射角重复模拟，比较单次结果与平均能量损失。"],
    ],
    "15-05574fb6": [
        ["物理模型", "吸收剂量描述单位质量中沉积的能量。采用辐射权重后可计算器官或组织的当量剂量。"],
        ["关系式", "D = ΔE / Δm，1 Gy = 1 J/kg。Hₜ = Σᵣ wᵣ Dₜ,ᵣ，当量剂量使用 Sv。"],
        ["模拟例子", "质量 4 kg 的均匀模型体共吸收 2 mJ，平均吸收剂量为 0.5 mGy。"],
        ["适用范围", "平均值依赖所选质量和区域。空间分布不均匀时，可分别计算各区域的能量沉积。"],
        ["换个条件", "把相同沉积能量集中到模型体一半的质量中，该区域的平均吸收剂量怎样变化？"],
    ],
    "15-b9d08ea3": [
        ["物理模型", "半透膜两侧的溶质浓度差可引起渗透压差。溶液中的可动离子会屏蔽带电表面附近的静电场。"],
        ["关系式", "理想稀溶液满足 Δπ ≈ RT Δc，其中 c 为溶质粒子浓度。"],
        ["例题", "在恒温、理想稀溶液近似下，将两侧的浓度差加倍，渗透压差也加倍。另在离子溶液中提高离子强度，可缩短德拜屏蔽长度。"],
        ["适用范围", "德拜长度刻画静电势的衰减距离。链的持久长度刻画弯曲方向的相关尺度，这两种长度描述不同现象。"],
        ["换个条件", "只改变离子强度时，预测远离带电表面的探针能够测得的静电势怎样变化。"],
    ],
}


class CoursePage(HTMLParser):
    """Read visible teaching blocks, preserving inline links and mathematical text."""

    def __init__(self, path):
        super().__init__(convert_charrefs=True)
        self.path = path
        self.blocks = defaultdict(list)
        self.key = None
        self.title = None
        self.heading = ""
        self.details_depth = 0
        self.tag = None
        self.fragments = []
        self.feed(path.read_text(encoding="utf-8"))
        self.close()

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if tag == "input" and "complete" in attributes.get("class", "").split():
            self.key = attributes["data-key"]
        if tag == "details":
            self.details_depth += 1
        if self.details_depth or self.tag is not None:
            return
        if tag in {"h1", "h2", "h3", "p", "li"} or (
            tag == "div" and attributes.get("class") == "formula"
        ):
            self.tag = tag
            self.fragments = []

    def handle_data(self, data):
        if self.tag is not None:
            self.fragments.append(data)

    def handle_endtag(self, tag):
        if tag == "details":
            self.details_depth -= 1
        if tag != self.tag:
            return
        text = "".join(self.fragments).strip()
        if tag in {"h2", "h3"}:
            self.heading = text
        elif tag == "h1":
            self.title = text
        elif text:
            self.blocks[self.heading, tag].append(text)
        self.tag = None

    def first(self, *headings, tag="p"):
        for heading in headings:
            blocks = self.blocks.get((heading, tag), [])
            if blocks:
                return blocks[0]
        raise ValueError(f"{self.path}: missing {tag} under {headings}")


def lesson_sections(page, item):
    headings = ("理解模型", "问题与物理图像")
    formula = page.first(*headings, tag="div")
    if item["formula"] != formula:
        raise ValueError(f"{page.path}: formula does not match the manifest")
    sections = [["物理模型", page.first(*headings)], ["关系式", formula]]
    derivation = page.blocks.get(("从假设走到结果", "li"), [])
    if derivation:
        sections.append(["推导", "\n".join(f"{n}. {step}" for n, step in enumerate(derivation, 1))])
    sections.extend([
        ["例题", page.first("带着推理看例题", "例题与核对")],
        ["适用范围", page.first("检查边界", "适用边界")],
        ["换个条件", page.first("迁移练习", "迁移与反例")],
    ])
    return sections


def research_sections(page):
    return [
        ["研究问题", page.first("研究问题与实施步骤")],
        ["复现检查", page.first("已知结果：必须先复现")],
        ["交付物", "\n".join(page.blocks["交付物", "p"])],
        ["误差与局限", page.first("容易出现的误判")],
        ["扩展问题", page.first("扩展问题")],
        ["同行复核", "记录问题、方法、版本、数据来源与不确定度。请同伴或教师依据报告和复现材料核查结论。"],
    ]


def build_catalog():
    manifest = json.loads((REPO / "course-manifest.json").read_text(encoding="utf-8"))
    catalog = {"fields": [], "entries": []}
    keys = set()
    for field in manifest["fields"]:
        catalog["fields"].append({"id": field["id"], "name": field["name"]})
        items = list(field["lessons"])
        if field.get("project"):
            items.append(field["project"])
        for item in items:
            path = Path(field["folder"], item["file"])
            page = CoursePage(REPO / path)
            key = item.get("key", f"{field['id']}-research")
            if page.key != key or page.title != item["title"] or key in keys:
                raise ValueError(f"{path}: inconsistent title or progress key {key}")
            keys.add(key)
            if key in EDITED_LESSONS:
                sections = EDITED_LESSONS[key]
            elif item["kind"] == "project":
                sections = research_sections(page)
            else:
                sections = lesson_sections(page, item)
            if any(not text.strip() for _, text in sections):
                raise ValueError(f"{path}: empty teaching section")
            catalog["entries"].append({
                "key": key, "field": field["id"], "title": page.title, "stage": item["stage"],
                "kind": item["kind"], "source": path.as_posix(), "sections": sections,
            })
    for kind, count in (("lesson", "lesson_count"), ("project", "project_count")):
        if sum(entry["kind"] == kind for entry in catalog["entries"]) != manifest[count]:
            raise ValueError(f"Incomplete {kind} coverage")
    return catalog


def main():
    catalog = build_catalog()
    output = LIBRARY / "course_library.json"
    encoded = (json.dumps(catalog, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    if not output.exists() or output.read_bytes() != encoded:
        with NamedTemporaryFile(dir=LIBRARY, delete=False, suffix=".tmp") as stream:
            temporary = Path(stream.name)
            stream.write(encoded)
        try:
            temporary.replace(output)
        finally:
            temporary.unlink(missing_ok=True)
    print(f"{len(catalog['entries'])} entries across {len(catalog['fields'])} fields")


if __name__ == "__main__":
    main()
