"""Validate both offline editions; write reports/screenshots only on request."""
import argparse
from datetime import date
from functools import partial
from html.parser import HTMLParser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import re
import sys
from threading import Thread
from urllib.parse import quote, unquote, urlsplit

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.course_data import numeric_answer

ROOT = Path(__file__).resolve().parents[1]
TOP_PAGES = {"index.html", "taxonomy.html", "learning-path.html", "checklist.html"}
FEEDBACK = {"zh": ("请先", "再试", "数值正确"), "en": ("Please enter", "Try again", "Correct")}


def require(condition, message):
    if not condition:
        raise ValueError(str(message))


class PageInfo(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.ids, self.labels, self.links = [], [], []
        self.keys, self.answers, self.demos = [], [], []
        self.lang, self.h1_count = None, 0
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        classes = attrs.get("class", "").split()
        if "id" in attrs:
            self.ids.append(attrs["id"])
        if tag == "html":
            self.lang = attrs.get("lang")
        if tag == "h1":
            self.h1_count += 1
        if tag == "label" and "for" in attrs:
            self.labels.append(attrs["for"])
        for key in ("href", "src"):
            if attrs.get(key):
                resource = key == "src" or (tag == "link" and attrs.get("rel") == "stylesheet")
                self.links.append((attrs[key], resource))
        if "complete" in classes:
            self.keys.append(attrs.get("data-key"))
        if "quiz" in classes:
            self.answers.append(numeric_answer(attrs.get("data-answer"), "quiz"))
        if "lab" in classes:
            self.demos.append(attrs.get("data-demo"))


def check_link(root, file, url, resource, infos):
    parsed = urlsplit(url)
    if parsed.scheme or parsed.netloc:
        require(not resource, (file, "offline resource must be local", url))
        return
    target = (file.parent / unquote(parsed.path)).resolve() if parsed.path else file
    require(target.is_relative_to(root), (file, "link leaves repository", url))
    require(target.exists(), (file, "broken local link", url))
    if target.suffix == ".html" and parsed.fragment:
        require(target in infos and unquote(parsed.fragment) in infos[target].ids,
                (file, "missing fragment", url))


def check_structure(root=ROOT):
    root = root.resolve()
    manifests, editions, infos, identities = {}, {}, {}, {}
    for lang, base in (("zh", root), ("en", root / "en")):
        manifest = json.loads((base / "course-manifest.json").read_text(encoding="utf-8"))
        manifests[lang] = manifest
        expected = {base / name: [] for name in TOP_PAGES}
        keys, pairs, field_ids = [], {}, []
        lesson_count = project_count = 0
        for field in manifest["fields"]:
            ident, folder = field["id"], field["folder"]
            require(re.fullmatch(r"\d{2}", ident), (lang, "invalid field id", ident))
            require(re.fullmatch(re.escape(ident) + r"-[^/\\]+", folder), (lang, folder))
            field_ids.append(ident)
            expected[base / folder / "index.html"] = []
            pairs[(ident, "index.html")] = base / folder / "index.html"
            for lesson in field["lessons"]:
                require(re.fullmatch(r"\d{2}\.html", lesson["file"]), (lang, lesson))
                path = base / folder / lesson["file"]
                require(path not in expected, (lang, "duplicate lesson", path))
                expected[path] = [lesson["key"]]
                keys.append(lesson["key"])
                pairs[(ident, lesson["file"])] = path
                lesson_count += 1
            if "project" in field:
                require(field["project"]["file"] == "research.html", (lang, field["project"]))
                path = base / folder / "research.html"
                expected[path] = [ident + "-research"]
                keys.append(ident + "-research")
                pairs[(ident, "research.html")] = path
                project_count += 1
        require(len(field_ids) == len(set(field_ids)), (lang, "duplicate field id"))
        require(all(keys) and len(keys) == len(set(keys)), (lang, "duplicate progress key"))
        require(lesson_count == manifest["lesson_count"], (lang, "lesson count"))
        require(project_count == manifest["project_count"], (lang, "project count"))
        require(sum(len(f["all_topics"]) for f in manifest["fields"]) == manifest["topic_entry_count"],
                (lang, "topic count"))
        actual = set(base.glob("*.html"))
        for folder in base.iterdir():
            if folder.is_dir() and re.match(r"\d{2}-", folder.name):
                actual.update(folder.rglob("*.html"))
        require(actual == expected.keys(), (lang, "missing/orphan pages", sorted(actual ^ expected.keys())))
        expected[base / "checklist.html"] = keys
        editions[lang] = sorted(expected)
        for name in TOP_PAGES:
            pairs[("top", name)] = base / name
        identities[lang] = pairs
        for path, progress in expected.items():
            info = PageInfo(path.read_text(encoding="utf-8"))
            infos[path] = info
            require(info.lang == ("en" if lang == "en" else "zh-CN"), (path, "language"))
            require(info.h1_count == 1 and "main" in info.ids, (path, "heading/main"))
            require(len(info.ids) == len(set(info.ids)), (path, "duplicate HTML ids"))
            require(set(info.labels) <= set(info.ids), (path, "label without input"))
            require(info.keys == progress, (path, "progress differs from manifest"))
            if re.fullmatch(r"\d{2}\.html", path.name):
                require(len(info.answers) == 2, (path, "expected two assembled quizzes"))
        require(sum(len(infos[p].demos) for p in expected) == manifest["demo_count"], (lang, "demo count"))

    require(identities["zh"].keys() == identities["en"].keys(), "Edition structures differ")
    counterparts = {}
    for identity, zh in identities["zh"].items():
        en = identities["en"][identity]
        counterparts[zh], counterparts[en] = en, zh
        require(infos[zh].keys == infos[en].keys, (zh, en, "bilingual progress"))
        require(infos[zh].answers == infos[en].answers, (zh, en, "bilingual answers"))
        require(infos[zh].demos == infos[en].demos, (zh, en, "bilingual demos"))
    folders = [[zh["folder"], en["folder"]] for zh, en in
               zip(manifests["zh"]["fields"], manifests["en"]["fields"])]
    for script in (root / "assets/course.js", root / "en/assets/course.js"):
        match = re.search(r"const LANG_MAP=(\[.*?\]);", script.read_text(encoding="utf-8"))
        require(match and json.loads(match[1]) == folders, (script, "stale language map"))
    for file, info in infos.items():
        for url, resource in info.links:
            check_link(root, file, url, resource, infos)
    official = json.loads((root / "classification-reference.json").read_text(encoding="utf-8"))
    codes = [item["code"] for item in official["categories"]]
    field_ids = {int(f["id"]) for f in manifests["zh"]["fields"]}
    require(len(set(codes)) == len(codes) == 51, "Invalid classification snapshot")
    require(all(item["local_fields"] and set(item["local_fields"]) <= field_ids
                for item in official["categories"]), "Invalid classification mapping")
    return manifests, editions, infos, counterparts


# Run the actual handlers in every quiz without thousands of actionability waits.
# Real Playwright click/Enter interactions are also checked on representative pages.
QUIZ_CHECK = """feedback => {
 const errors=[];
 document.querySelectorAll('.quiz').forEach((quiz,index) => {
  const input=quiz.querySelector('input'),result=quiz.querySelector('.feedback');
  const expected=Number(quiz.dataset.answer);
  const cases=[['',0],['1e309',0],[String(Math.abs(expected)*3+123),1],
   [String(expected),2],['0',expected===0?2:1]];
  if(expected===0) cases.push(['0.0001',1]);
  else cases.push([String(expected*1.019),2],[String(expected*1.021),1],[String(-expected),1]);
  cases.forEach(([value,state],i) => {
   input.value=value;
   if(i%2) input.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',bubbles:true}));
   else quiz.querySelector('button').click();
   if(!result.textContent.startsWith(feedback[state]))
    errors.push({quiz:index,value,expected,state,feedback:result.textContent});
  });
 });
 return errors;
}"""


def contrast(foreground, background):
    def luminance(rgb):
        channels = [int(v) / 255 for v in re.findall(r"\d+", rgb)[:3]]
        linear = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in channels]
        return sum(a * b for a, b in zip(linear, (0.2126, 0.7152, 0.0722)))
    a, b = sorted((luminance(foreground), luminance(background)))
    return (b + 0.05) / (a + 0.05)


def check_http_progress(browser, root, audit):
    """Verify live progress across four tabs, including a project URL prefix."""
    from playwright.sync_api import expect
    _, editions, infos, counterparts = audit
    lesson = next(p for p in editions["zh"] if infos[p].answers)
    selector = f'.complete[data-key="{infos[lesson].keys[0]}"]'

    class QuietHandler(SimpleHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_GET(self):
            prefix = "/" + quote(root.name) + "/"
            if not urlsplit(self.path).path.startswith(prefix):
                self.send_error(404)
                return
            self.path = self.path[len(prefix) - 1:]
            super().do_GET()

    server = ThreadingHTTPServer(("127.0.0.1", 0), partial(QuietHandler, directory=str(root)))
    thread = Thread(target=server.serve_forever, daemon=True)
    thread.start()
    context, errors = browser.new_context(), []
    try:
        origin = f"http://127.0.0.1:{server.server_port}/"
        def url(path):
            return origin + quote(path.relative_to(root.parent).as_posix())
        pages = []
        for file in (lesson, root / "checklist.html", counterparts[lesson], root / "en/checklist.html"):
            page = context.new_page()
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(url(file))
            pages.append(page)
        pages[0].locator(selector).check()
        for page in pages:
            expect(page.locator(selector)).to_be_checked()
        pages[1].locator(selector).uncheck()
        for page in pages:
            expect(page.locator(selector)).not_to_be_checked()
        pages[2].locator(selector).check()
        pages[0].locator("header a.lang").click()
        require(pages[0].url == url(counterparts[lesson]), "Language switch lost project prefix")
        expect(pages[0].locator(selector)).to_be_checked()
        pages[0].locator("header a.lang").click()
        require(pages[0].url == url(lesson), "Language switch did not round-trip")
        pages[3].evaluate("localStorage.clear()")
        # Browsers send storage events to other documents, not the initiating tab.
        for page in pages[:3]:
            expect(page.locator(selector)).not_to_be_checked()
        pages[3].reload()
        expect(pages[3].locator(selector)).not_to_be_checked()
        require(not errors, errors)
    finally:
        context.close()
        server.shutdown()
        server.server_close()
        thread.join()


def check_browser(root, audit, screenshots=False):
    from playwright.sync_api import expect, sync_playwright
    _, editions, infos, counterparts = audit
    errors, requests = [], []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch()
        context = browser.new_context(viewport={"width": 1280, "height": 900}, offline=True)
        page = context.new_page()
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on("requestfailed", lambda request: errors.append((request.url, request.failure)))
        page.on("request", lambda request: requests.append(request.url)
                if urlsplit(request.url).scheme in {"http", "https"} else None)
        for lang, pages in editions.items():
            for number, file in enumerate(pages, 1):
                page.goto(file.as_uri())
                require(page.evaluate("document.styleSheets.length > 0"), (file, "stylesheet not loaded"))
                require(page.evaluate("document.documentElement.scrollWidth <= innerWidth"), file)
                switch = page.locator("header a.lang")
                require(switch.count() == 1, (file, "missing language switch"))
                target = (file.parent / unquote(urlsplit(switch.get_attribute("href")).path)).resolve()
                require(target == counterparts[file], (file, "wrong counterpart", target))
                if infos[file].answers:
                    failures = page.evaluate(QUIZ_CHECK, FEEDBACK[lang])
                    require(not failures, (file, "quiz regression", failures))
                if infos[file].keys:
                    page.locator(".complete").first.evaluate(
                        "el=>{el.checked=true;el.dispatchEvent(new Event('change'));}")
                    page.reload()
                    require(page.locator(".complete").first.is_checked(), (file, "progress not persisted"))
                    page.locator(".complete").first.uncheck()
                for lab in page.locator(".lab").all():
                    slider, old = lab.locator("input[type=range]"), lab.locator(".lab-result").inner_text()
                    for value in ("1", "8", "10"):
                        slider.fill(value)
                        slider.dispatch_event("input")
                        result = lab.locator(".lab-result").inner_text()
                        drawing = lab.locator("svg").inner_html()
                        require(drawing and not re.search(r"NaN|Infinity", result + drawing), (file, value))
                    require(result != old, (file, "demo did not update"))
                page.set_viewport_size({"width": 390, "height": 844})
                require(page.evaluate("document.documentElement.scrollWidth <= innerWidth"), ("mobile", file))
                page.set_viewport_size({"width": 1280, "height": 900})
                if number % 100 == 0:
                    print(f"Checked {lang}: {number}/{len(pages)} pages", flush=True)
            base = root / "en" if lang == "en" else root
            page.goto((base / "taxonomy.html").as_uri())
            search = page.locator("#topic-search")
            search.fill("turbulence" if lang == "en" else "湍流")
            field_count = len(audit[0][lang]["fields"])
            require(0 < page.locator(".taxonomy-field:visible").count() < field_count, (lang, "search"))
            search.fill("no-such-topic-012345")
            require(page.locator(".taxonomy-field:visible").count() == 0, (lang, "empty search"))
            search.fill("")
            require(page.locator(".taxonomy-field:visible").count() == field_count, (lang, "search reset"))
            lesson = next(p for p in pages if p.parent.name.startswith("00-") and p.name == "01.html")
            page.goto(lesson.as_uri())
            quiz = page.locator(".quiz").first
            quiz.locator("input").fill(quiz.get_attribute("data-answer"))
            quiz.locator("button").click()
            expect(quiz.locator(".feedback")).to_contain_text(FEEDBACK[lang][2])
            quiz.locator("input").press("Enter")
            expect(quiz.locator(".feedback")).to_contain_text(FEEDBACK[lang][2])
            page.emulate_media(color_scheme="dark")
            page.set_viewport_size({"width": 390, "height": 844})
            colors = page.evaluate("""() => {
             const s=q=>getComputedStyle(document.querySelector(q));
             return [[s('input[type=number]').color,s('input[type=number]').backgroundColor],
              [s('button').color,s('button').backgroundColor],[s('svg text').fill,s('svg').backgroundColor]];
            }""")
            require(all(contrast(*pair) >= 4.5 for pair in colors), (lang, "dark contrast", colors))
            if screenshots and lang == "zh":
                page.screenshot(path=str(root / "verification/dark-sample.png"), full_page=True)
            page.emulate_media(color_scheme="light")
            page.set_viewport_size({"width": 1280, "height": 900})
        require(not errors and not requests, ("offline errors/network requests", errors, requests))
        context.close()
        check_http_progress(browser, root, audit)
        blocked = browser.new_context(offline=True)
        blocked.add_init_script("""for(const method of ['getItem','setItem'])
          Storage.prototype[method]=()=>{throw new DOMException('Disabled','SecurityError')};""")
        for lang, pages in editions.items():
            page = blocked.new_page()
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(next(p for p in pages if infos[p].answers).as_uri())
            require(not page.evaluate(QUIZ_CHECK, FEEDBACK[lang]), (lang, "storage-disabled quiz"))
            page.locator(".complete").check()
            require(page.locator(".storage-note").inner_text(), (lang, "storage fallback"))
            page.close()
        blocked.close()
        require(not errors, errors)
        if screenshots:
            page = browser.new_page(viewport={"width": 1280, "height": 900}, offline=True)
            for name, file, width in (
                ("home-desktop.png", root / "index.html", 1280),
                ("lesson-desktop.png", root / "05-光学与光子学/01.html", 1280),
                ("lesson-mobile.png", root / "05-光学与光子学/01.html", 390),
                ("advanced-mobile.png", root / "07-量子力学/04.html", 390),
            ):
                page.set_viewport_size({"width": width, "height": 900 if width == 1280 else 844})
                page.goto(file.as_uri())
                page.screenshot(path=str(root / "verification" / name), full_page=True)
        browser.close()


def write_reports(root, audit, report_date):
    manifests, editions, infos, _ = audit
    pages = sum(map(len, editions.values()))
    quizzes = sum(len(info.answers) for info in infos.values())
    demos = sum(len(info.demos) for info in infos.values())
    command = f"python tools/check_course.py --write-report --report-date {report_date}"
    zh = f"""# 教材检查记录

检查日期：{report_date}。运行命令：{command}。

- {pages} 页（中文 {len(editions['zh'])}、英文 {len(editions['en'])}），每版 {manifests['zh']['lesson_count']} 课；共 {quizzes} 道交互自测、{demos} 个演示。
- 清单与实际页面、课程和项目数量、进度键、双语答案、语言映射一致；本地链接和锚点有效，HTML id 唯一，标签关联有效，资源可离线加载。
- 离线 Chromium 逐页检查全部自测的空值、无效值、正确/错误/零值/符号及容差边界，抽查真实点击和回车；无脚本错误和网络请求。
- 全部页面通过 1280 px 与 390 px 检查，全部演示在滑块最小、中间、最大值生成有限 SVG 数值。
- 完成标记刷新后保留；本地 HTTP 子目录下四个同时打开的中英课程/清单页双向同步，语言切换往返保持路径与进度，清空存储同步取消标记。
- 禁用存储仍可答题和勾选；深色模式输入框、按钮、SVG 文字对比度至少 4.5:1；中英分类搜索通过。
- 截图：home-desktop.png、lesson-desktop.png、lesson-mobile.png、advanced-mobile.png、dark-sample.png。

限制：功能检查不证明所有物理陈述正确。内容修订与来源见 REVIEW.md；file:// 存储行为由浏览器决定，需要稳定跨页面保存时可采用 README 的本地 HTTP 方式。
"""
    en = f"""# Verification report

Date: {report_date}. Command: {command}.

- {pages} pages ({len(editions['zh'])} Chinese, {len(editions['en'])} English), {manifests['en']['lesson_count']} lessons per edition, {quizzes} quizzes, {demos} diagrams.
- Verified manifest paths/counts, progress keys, bilingual answers, language maps, local links/fragments, unique ids, labels, and offline assets.
- Loaded every page in offline Chromium; tested every quiz with empty, invalid, correct/incorrect, zero, sign, and tolerance cases, plus representative real click/Enter actions. No script errors or network requests.
- Checked every page at 1280 px and 390 px; checked all demos at slider minimum, intermediate, and maximum values.
- Verified reload persistence, live four-tab bilingual lesson/checklist synchronization under an HTTP project prefix, language round trips, storage-clear synchronization, and storage-disabled fallback.
- Numeric inputs, buttons, and SVG labels pass 4.5:1 dark-mode contrast; taxonomy searches pass in both languages.
- Screenshots: home-desktop.png, lesson-desktop.png, lesson-mobile.png, advanced-mobile.png, dark-sample.png.

Limits: functional checks do not establish correctness of every physics statement. See REVIEW.en.md for content corrections and sources. File-URL storage depends on browser policy; the README documents a local HTTP alternative.
"""
    (root / "verification/REPORT.md").write_text(zh, encoding="utf-8")
    (root / "verification/REPORT.en.md").write_text(en, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--structure-only", action="store_true", help="Run without Playwright")
    parser.add_argument("--write-report", action="store_true", help="Update reports and screenshots")
    parser.add_argument("--report-date", type=date.fromisoformat, default=date.today())
    args = parser.parse_args()
    if args.structure_only and args.write_report:
        parser.error("--write-report requires the full browser checks")
    audit = check_structure()
    if not args.structure_only:
        check_browser(ROOT, audit, screenshots=args.write_report)
    if args.write_report:
        write_reports(ROOT, audit, args.report_date)
    _, editions, infos, _ = audit
    print(f"PASS: {sum(map(len, editions.values()))} pages, "
          f"{sum(bool(info.answers) for info in infos.values())} lesson pages, "
          f"{sum(len(info.answers) for info in infos.values())} quizzes, "
          f"{sum(len(info.demos) for info in infos.values())} diagrams"
          + (" (structure only)." if args.structure_only else ", offline desktop/mobile and HTTP progress."))


if __name__ == "__main__":
    main()
