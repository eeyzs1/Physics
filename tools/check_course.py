"""Structural checks plus real offline Chromium interaction checks."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import unquote, urlparse
from datetime import date
import re
import json
from playwright.sync_api import sync_playwright

ROOT=Path(__file__).resolve().parents[1]
class Links(HTMLParser):
 def __init__(self): super().__init__(); self.links=[]
 def handle_starttag(self,tag,attrs):
  for key,val in attrs:
   if key in ('href','src') and val:self.links.append(val)

manifest=json.loads((ROOT/'course-manifest.json').read_text(encoding='utf-8'))
official=json.loads((ROOT/'classification-reference.json').read_text(encoding='utf-8'))
assert len({x['code'] for x in official['categories']})==len(official['categories'])==51
field_ids={int(f['id']) for f in manifest['fields']}
assert all(x['local_fields'] and set(x['local_fields'])<=field_ids for x in official['categories'])
pages=sorted(ROOT.rglob('*.html'))
en_pages=[p for p in pages if p.is_relative_to(ROOT/'en')]
en_set=set(en_pages);zh_pages=[p for p in pages if p not in en_set]
manifests={'zh':manifest,'en':json.loads((ROOT/'en'/'course-manifest.json').read_text(encoding='utf-8'))}
for tree,plist in (('zh',zh_pages),('en',en_pages)):
 m=manifests[tree];expected=m['lesson_count']+m['project_count']+len(m['fields'])+4
 assert len(plist)==expected,(tree,len(plist),expected)
for file in pages:
 text=file.read_text(encoding='utf-8'); parser=Links();parser.feed(text)
 lang='en' if file in en_set else 'zh-CN'
 assert f'lang="{lang}"' in text and 'id="main"' in text,file
 for url in parser.links:
  if urlparse(url).scheme or url.startswith('#'):continue
  target=file.parent/unquote(url.split('#')[0]);assert target.exists(),(file,url)
lessons=[p for p in pages if re.fullmatch(r'\d{2}\.html',p.name)]
projects=[p for p in pages if p.name=='research.html']
for tree in ('zh','en'):
 m=manifests[tree]
 assert len([p for p in lessons if (p in en_set)==(tree=='en')])==m['lesson_count'],tree
 assert len([p for p in projects if (p in en_set)==(tree=='en')])==m['project_count'],tree
report=[]; errors=[]; demo_count={'zh':0,'en':0}
FEEDBACK={'zh':('请先','再试','正确'),'en':('Please enter','Try again','Correct')}
with sync_playwright() as p:
 browser=p.chromium.launch()
 page=browser.new_page(viewport={'width':1280,'height':900},offline=True)
 page.on('pageerror',lambda error:errors.append(str(error)))
 for file in pages:
  tree='en' if file in en_set else 'zh';fb=FEEDBACK[tree]
  page.goto(file.as_uri());page.wait_for_load_state('load')
  assert page.locator('h1').count()==1,file
  assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'),file
  lang_a=page.locator('header a.lang')
  assert lang_a.count()==1,file
  lhref=lang_a.get_attribute('href');ltarget=file.parent/unquote(lhref.split('#')[0])
  assert ltarget.exists(),(file,lhref)
  if file in lessons:
   for quiz in page.locator('.quiz').all():
    answer=quiz.get_attribute('data-answer')
    quiz.locator('button').click();assert fb[0] in quiz.locator('.feedback').inner_text()
    quiz.locator('input').fill(str(abs(float(answer))*3+123));quiz.locator('button').click()
    assert fb[1] in quiz.locator('.feedback').inner_text(),file
    quiz.locator('input').fill(answer);quiz.locator('input').press('Enter')
    assert fb[2] in quiz.locator('.feedback').inner_text(),file
  if page.locator('.complete').count():
   box=page.locator('.complete').first;box.check();page.reload();assert box.is_checked(),file
   box.uncheck()
  if page.locator('.lab').count():
   demo_count[tree]+=1
   assert page.locator('.lab svg').inner_html(),file
   old=page.locator('.lab-result').inner_text()
   slider=page.locator('input[type=range]');slider.fill('8');slider.dispatch_event('input')
   assert page.locator('.lab-result').inner_text()!=old,file
   assert 'NaN' not in page.locator('.lab-result').inner_text(),file
  page.set_viewport_size({'width':390,'height':844})
  assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'),('mobile',file)
  page.set_viewport_size({'width':1280,'height':900})
 assert not errors,errors
 for tree in ('zh','en'):
  assert demo_count[tree]==manifests[tree]['demo_count'],(tree,demo_count[tree],manifests[tree]['demo_count'])
 page.goto((ROOT/'taxonomy.html').as_uri())
 search=page.locator('#topic-search');search.fill('湍流')
 assert page.locator('.taxonomy-field:visible').count()>0
 assert page.locator('.taxonomy-field:visible').count()<len(manifest['fields'])
 search.fill('不存在的分类012345');assert page.locator('.taxonomy-field:visible').count()==0
 search.fill('');assert page.locator('.taxonomy-field:visible').count()==len(manifest['fields'])
 page.goto((ROOT/'en'/'taxonomy.html').as_uri())
 search.fill('turbulence')
 assert page.locator('.taxonomy-field:visible').count()>0
 assert page.locator('.taxonomy-field:visible').count()<len(manifests['en']['fields'])
 search.fill('no-such-topic-012345');assert page.locator('.taxonomy-field:visible').count()==0
 search.fill('');assert page.locator('.taxonomy-field:visible').count()==len(manifests['en']['fields'])
 out=ROOT/'verification';out.mkdir(exist_ok=True)
 page.goto((ROOT/'index.html').as_uri());page.screenshot(path=str(out/'home-desktop.png'),full_page=True)
 file=next(p for p in lessons if p not in en_set and p.parent.name.startswith('05-') and p.name=='01.html')
 page.goto(file.as_uri());page.screenshot(path=str(out/'lesson-desktop.png'),full_page=True)
 page.set_viewport_size({'width':390,'height':844});page.screenshot(path=str(out/'lesson-mobile.png'),full_page=True)
 page.goto(next(p for p in lessons if p not in en_set and p.parent.name.startswith('07-') and p.name=='04.html').as_uri())
 page.screenshot(path=str(out/'advanced-mobile.png'),full_page=True)
 browser.close()
report=f'''# 教材检查记录

检查日期：{date.today().isoformat()}。运行命令：`python tools/check_course.py`。

- {len(pages)} 个 HTML 页面（中文 {len(zh_pages)}、英文 {len(en_pages)}）本地链接全部有效：每棵树 {manifest['lesson_count']} 节正文、{manifest['project_count']} 项研究训练、{len(manifest['fields'])} 个领域入口，以及首页/分类树/路线/核心概念清单。
- Chromium 在离线模式下逐页加载（两棵树），无 JavaScript 异常。
- {len(lessons)} 课（中英各 {manifest['lesson_count']}）的空答案、错误答案、正确答案及回车提交验证通过，反馈语言与页面语言一致。
- 正文与研究训练的完成标记经刷新仍可恢复；检查后已清除测试标记。
- {demo_count['zh']+demo_count['en']} 个演示（每棵树 {demo_count['zh']} 个）均生成 SVG，滑块调节后结果改变，无 NaN。
- 全部页面在 1280 px 与 390 px 视口检查，无水平溢出。
- 分类搜索匹配、无结果与清空恢复检查通过（中文"湍流"与英文 turbulence）。
- 语言切换链接在两棵树的页面上生成并指向存在的对应页面。
- arXiv 物理组快照的 {len(official['categories'])} 个代码无重复，且全部映射到存在的本地目录；此检查不代表教程覆盖了每个代码的全部内容。
- 截图：home-desktop.png、lesson-desktop.png、lesson-mobile.png、advanced-mobile.png。

限制：自动检查不证明所有物理陈述正确；已进行公式、例题与答案的编写者核对，仍未经过领域专家逐条审校。课程含核心/高阶选题与研究训练，但未覆盖全部专题。
'''
(ROOT/'verification'/'REPORT.md').write_text(report,encoding='utf-8')
print(f'PASS: {len(pages)} pages ({len(zh_pages)} zh + {len(en_pages)} en), {len(lessons)} quizzes, {len(projects)} projects, {demo_count["zh"]}+{demo_count["en"]} diagrams, offline desktop/mobile, persistence, taxonomy search in both languages.')
