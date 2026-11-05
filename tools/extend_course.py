from pathlib import Path
from html import escape as E
import json
from advanced_content import lessons
from expanded_fields import FIELDS, EXTRA, PROJECTS

MORE_TOPICS = '''
00|科学计数法；有效数字；单位制；标量与向量；复数；微积分；概率；线性代数
01|质点系；冲量与碰撞；中心力；开普勒问题；约束与广义坐标；刚体欧拉方程；拉格朗日力学；哈密顿力学；正则变换；经典场；弹性力学
02|受迫振动；拍频与简正模式；波动方程；色散；群速度；声辐射；超声；声子；冲击波；孤立波；声学超材料
03|热机与制冷；化学势；麦克斯韦关系；玻尔兹曼分布；费米气体；玻色气体；临界现象；重整化群；玻尔兹曼方程；输运理论；随机过程；随机热力学
04|边值问题；多极展开；电介质；磁介质；电磁势与规范；辐射；天线；波导；等离子体电磁响应；相对论电动力学
05|傅里叶光学；成像与像差；相干理论；光纤；集成光子学；超快光学；纳米光学；近场光学；激光光谱；全息；光机械；量子光学
06|四矢量；相对论碰撞；等效原理；微分几何；史瓦西时空；旋转黑洞；引力透镜；数值相对论；引力实验；引力波探测；量子引力候选理论
07|薛定谔方程；谐振子；氢原子；密度矩阵；角动量耦合；全同粒子；变分法；微扰论；散射理论；路径积分；开放量子系统；量子测量理论
08|原子碰撞；超精细结构；分子转动；分子振动；选择定则；激光冷却；玻色凝聚；光晶格；里德伯原子；原子钟；强场原子物理；团簇
09|晶格与倒格子；声子；电子输运；半导体；磁序；强关联；超导与超流；量子霍尔效应；拓扑材料；低维材料；无序与局域化；软物质；液晶；玻璃；颗粒物质；主动凝聚态
10|核壳模型；集体模型；α、β、γ 衰变；核反应截面；核裂变；核聚变；重离子；核物质状态方程；奇异核；核合成；核结构探测
11|量子电动力学；量子色动力学；电弱理论；希格斯机制；中微子；味物理；对撞机现象学；格点场论；有效场论；规范理论；重整化；对称性与反常；暗物质候选；弦论与量子引力候选
12|动理学；磁流体；等离子体波；不稳定性；磁重联；磁约束；惯性约束；低温等离子体；尘埃等离子体；强耦合等离子体；高能量密度物理；等离子体诊断
13|太阳物理；恒星结构与演化；系外行星；星际介质；星系动力学；星系形成；高能天体；致密星；黑洞天体；宇宙微波背景；大尺度结构；暗物质观测；暗能量；宇宙早期；多信使天文学
14|地震学；地磁；重力测量；地热；矿物物理；行星内部；大气物理；海洋物理；气候物理；电离层；磁层；太阳风；空间天气；宇宙线传播
15|生物分子；蛋白质折叠；膜物理；单分子力学；分子马达；细胞力学；神经生物物理；群体与生态物理；X 射线成像；磁共振；超声；图像重建；剂量学；放射物理
16|常微分方程；偏微分方程；特殊函数；复分析；格林函数；积分变换；张量；微分几何；群与表示；泛函分析；变分法；拓扑；可积系统；严格数学物理
17|数值线性代数；数值积分；常微分方程算法；有限差分；有限元；谱方法；蒙特卡洛；分子动力学；量子多体计算；反问题；科学机器学习；高性能计算；可复现工作流
18|计量与标定；不确定度；贝叶斯推断；探测器；低噪声电子学；信号处理；真空技术；低温技术；光学实验；数据采集；控制系统；实验设计；统计检验
'''

def parse(text, count):
 out=[]
 for line in text.strip().splitlines():
  a=line.split('\t' if '\t' in line else '|');assert len(a)==count,(len(a),a[:2]);out.append(a)
 return out

def extend(root, base_rows, page, link, sources):
 fields={int(a[0]):{'id':a[0],'name':a[1],'group':a[2],'pre':a[3],'topics':a[4].split('；')} for a in base_rows}
 for a in parse(FIELDS,5):fields[int(a[0])]={'id':a[0],'name':a[1],'group':a[2],'pre':a[3],'topics':a[4].split('；')}
 for n,f in fields.items():f['folder']=f"{f['id']}-{f['name']}";f['lessons']=[]
 # Original 38 lessons are preserved, with their existing progress keys.
 for n in range(19):
  a=base_rows[n]
  for i in range(2): fields[n]['lessons'].append({'title':a[5+i*7],'file':f'{i+1:02d}.html','stage':'入门','kind':'lesson'})
 refs={
  0:('MIT：单变量微积分','https://ocw.mit.edu/courses/18-01sc-single-variable-calculus-fall-2010/'),
  1:('David Tong：Classical Dynamics','https://davidtong.org/teaching/classical-dynamics/'),
  3:('David Tong：Statistical Physics','https://davidtong.org/teaching/statistical-physics/'),
  11:('David Tong：Quantum Field Theory','https://davidtong.org/teaching/quantum-field-theory/'),
 }
 default_ref=('David Tong：分级物理讲义目录','https://davidtong.org/teaching/')
 def reference(n):
  if n in refs:return refs[n]
  topic_refs={4:'electromagnetism',6:'general-relativity',7:'quantum-mechanics',8:'topics-in-quantum-mechanics',9:'solid-state-physics',12:'electromagnetism',13:'cosmology',15:'mathematical-biology',19:'fluid-mechanics',21:'topics-in-quantum-mechanics',22:'topics-in-quantum-mechanics'}
  if n in topic_refs:return (f'David Tong：{topic_refs[n]}','https://davidtong.org/teaching/'+topic_refs[n]+'/')
  if n in [2,4,5,6,7,9,13,16,19,20,22]:return default_ref
  return ('MIT OpenCourseWare：物理课程检索','https://ocw.mit.edu/search/?d=Physics')
 content_rows=lessons()+parse(EXTRA,13)
 for a in content_rows:
  ident,title,pre,concept,formula,derivation,example,q,answer,solution,limit,transfer,transfer_solution=a
  n=int(ident);f=fields[n];i=len(f['lessons'])+1;filename=f'{i:02d}.html'
  stage=('本科核心' if i==3 else '高阶选题') if n<=18 else ('入门' if i==1 else '本科核心')
  if n==0:stage='数学准备'
  ref_title,ref_url=reference(n)
  steps=derivation.split('；')
  body=f'''<nav>{link('总览','../index.html')} / {link(f['name'],'index.html')} / 第 {i} 课</nav><p class="eyebrow">{E(stage)} · 约 30–60 分钟</p><h1>{E(title)}</h1><p class="lead">目标：跟随推导建立模型，独立计算一个新情形，并指出近似何时失效。</p><aside>先修：{E(pre)}。先修不熟时先回到 {link('数学准备','../00-学习准备/index.html')}。同一分支的两节入门课不等于满足所有高阶先修。</aside><section><h2>问题与物理图像</h2><p>{E(concept)}</p><div class="formula">{E(formula)}</div><h2>从假设走到结果</h2><ol>{''.join('<li>'+E(s)+'。</li>' for s in steps)}</ol><p>请在纸上补出中间代数步骤。不能复现时，先指出卡住的等式，再向我提问。</p></section><section><h2>例题与核对</h2><p>{E(example)}</p><h3>适用边界</h3><p>{E(limit)}</p></section><section class="quiz" data-answer="{E(answer)}"><h2>独立计算</h2><label for="answer">{E(q)}（只填数值）</label><div class="answer-row"><input id="answer" type="number" step="any" inputmode="decimal"><button type="button" class="check">检查答案</button></div><p class="feedback" role="status"></p><details><summary>展开本题解答</summary><p>{E(solution)}</p></details><h3>迁移与反例</h3><p>{E(transfer)}</p><details><summary>对照迁移题解答</summary><p>{E(transfer_solution)}</p></details></section><section><h2>进入下一阶段前</h2><ol><li>不看正文，重新写出本课推导并解释每个符号。</li><li>从适用边界选一个被忽略因素，说明如何修改模型。</li><li>隔 1、3、7 天重做两道题，并把不懂的步骤发给我。</li></ol><p>参考入口：{link(ref_title,ref_url)}。这些入口用于继续系统学习，不表示本小课已覆盖整门大学课程；具体课程和文献见 {link('分级学习路线','../learning-path.html')}。</p><label><input type="checkbox" class="complete" data-key="{ident}-deep-{i}"> 我能独立推导并解释近似条件</label><p class="storage-note"></p></section><nav class="bottom-nav">{link('上一课',f'{i-1:02d}.html' if i>1 else 'index.html')}{link('返回分支与下一步','index.html')}</nav>'''
  folder=root/f['folder'];folder.mkdir(exist_ok=True);(folder/filename).write_text(page(title,body),encoding='utf-8')
  f['lessons'].append({'title':title,'file':filename,'stage':stage,'kind':'lesson'})
 # Research preparation pages have explicit deliverables and known-result checks.
 project_rows=parse(PROJECTS,7)
 for ident,title,method,checks,deliverables,failures,extension in project_rows:
  n=int(ident);f=fields[n]
  body=f'''<nav>{link('全部领域','../index.html')} / {link(f['name'],'index.html')}</nav><p class="eyebrow">研究训练 · 建议 1–3 周，按先修和任务调整</p><h1>{E(title)}</h1><p class="lead">这是复现型训练：先复现已知结果，再比较模型与证据。做完不自动等于提出了原创成果。</p><aside>开始条件：能完成本分支已编写课程，并补齐项目用到的数学、编程或统计。真实实验可用公开数据或合成数据替代，必须明确标注来源。</aside><section><h2>研究问题与实施步骤</h2><p>{E(method)}</p><ol><li>用一页写清研究问题、变量、假设和可被推翻的预测。</li><li>先做一个可解析或可手算的最小例子，再扩展参数范围。</li><li>固定单位、初始条件、边界条件、算法版本与随机种子。</li><li>改变分辨率、样本量或模型假设，检查结论是否稳健。</li></ol><h2>已知结果：必须先复现</h2><p>{E(checks)}</p><p>若不符合，应先排查实现、单位和假设，再讨论新的物理解释。吻合也不能替代独立验证。</p></section><section><h2>交付物</h2><p>{E(deliverables)}</p><p>另交一份 4–8 页报告：问题、方法、结果、误差与局限、可复现步骤、参考资料。图必须有坐标、单位、图注；定量结论必须附不确定度或数值收敛证据。</p><h3>容易出现的误判</h3><p>{E(failures)}</p><h3>扩展问题</h3><p>{E(extension)}</p></section><section><h2>论文阅读与评议</h2><ol><li>从 {link('分支论文分类入口','../taxonomy.html')} 找到相关主题，在该领域教材或综述中选择一篇适合的论文。</li><li>记录题目、作者、年份、稳定链接、研究问题、关键假设与核心图表。</li><li>重现一个结论，并写出至少一个未解决问题；区分原文结论和自己的推断。</li><li>把报告与计算发给我复核，或请该领域教师、研究者评议；没有评议前不把自评当作研究能力认证。</li></ol><p>当前页面没有替你虚构具体论文、数据或实验结果。前沿结论需在项目实施时重新检索和核实。</p><details><summary>自评量规（0–2 分/项）</summary><p>问题可检验；理论推导完整；结果可复现；误差分析可信；替代解释被检查；论证与引用清楚。每项 0=缺失，1=部分，2=充分。满分 12 也只代表本项目报告达标，不代表该领域已精通。</p></details><label><input type="checkbox" class="complete" data-key="{ident}-research"> 我已提交并复核本项目证据</label><p class="storage-note"></p></section><nav>{link('返回分支','index.html')}</nav>'''
  (root/f['folder']/'research.html').write_text(page(title,body),encoding='utf-8')
  f['project']={'title':title,'file':'research.html','stage':'研究训练','kind':'project'}
 more={int(a[0]):a[1].split('；') for a in parse(MORE_TOPICS,2)}
 taxonomy=[];cards=[];readme_table=[]
 stages=['入门','本科核心','高阶选题','研究训练']
 for n,f in fields.items():
  topics=list(dict.fromkeys(f['topics']+more.get(n,[])));f['all_topics']=topics
  lesson_list=''.join(f'<li><strong>{E(item["stage"])}</strong> · {link(item["title"],item["file"])}</li>' for item in f['lessons'])
  if 'project' in f:lesson_list+=f'<li><strong>研究训练</strong> · {link(f["project"]["title"],"research.html")}</li>'
  missing='部分专题尚未展开为完整课程。已有高阶小课只讲一个选题，不相当于该分支全部研究生课程。'
  body=f'''<nav>{link('总览','../index.html')} / {link('分类树','../taxonomy.html')} / {link('学习路线','../learning-path.html')}</nav><p class="eyebrow">{f['id']} / {E(f['group'])}</p><h1>{E(f['name'])}</h1><p class="lead">先修：{E(f['pre'])}。</p><h2>已编写的课程与训练</h2><ol class="lesson-list">{lesson_list}</ol><aside>{missing}</aside><section><h2>细分方向地图</h2><p>这里列的是导航分类。列出一个名称不表示其完整教程已写完；本目录上方只把实际存在的课程标为已编写。</p><div class="tags">{''.join('<span>'+E(t)+'</span>' for t in topics)}</div></section><section><h2>分阶段学习要求</h2><ol><li>入门：能定性解释概念、统一单位、解简单模型题。</li><li>本科核心：系统学习该领域控制方程与实验，完成多章推导和习题；本目录小课仅为选题示范。</li><li>高阶：补数学与专门工具，阅读相应研究生教材，复现典型模型；未写出的专题继续列为待补。</li><li>研究训练：复现结果、验证误差、阅读论文、接受评议，之后才逐步尝试原创问题。</li></ol><p>系统教材：{link(*reference(n))}。跨分支先修与里程碑见 {link('完整分级路线','../learning-path.html')}。</p></section>'''
  (root/f['folder']/'index.html').write_text(page(f['name'],body),encoding='utf-8')
  folder=f['folder'];count=len(f['lessons']);project_count=1 if 'project' in f else 0
  cards.append(f'<a class="card" href="{E(folder)}/index.html"><span>{f["id"]} / {E(f["group"])}</span><h2>{E(f["name"])}</h2><p>{E("；".join(topics[:6]))}</p><small>{count} 节正文课'+(' + 1 项研究训练' if project_count else '')+'</small></a>')
  taxonomy.append(f'<section id="field-{n}" class="taxonomy-field"><h2>{f["id"]} · {link(f["name"],folder+"/index.html")}</h2><p>{E(f["group"])} · 已有 {count} 节选题教程'+('与研究训练任务' if project_count else '')+'；细分方向未全部写成课程。</p><ul>'+''.join('<li>'+E(t)+'</li>' for t in topics)+'</ul></section>')
  readme_table.append(f'| {f["id"]} | [{f["name"]}]({folder}/index.html) | {f["group"]} | {count} | '+('1' if project_count else '—')+' |')
 total=sum(len(f['lessons']) for f in fields.values()); topic_count=sum(len(f['all_topics']) for f in fields.values())
 source_note=f'''<p>分类参考：{link('APS PhySH','https://physh.org/')} 和 {link('arXiv Category Taxonomy','https://arxiv.org/category_taxonomy')}（核对日期 2026-11-01）。这里是为学习重新组织的中文导航，不是对官方分类的逐项翻译或完整镜像；研究领域、物理系统、技术和相关学科是不同维度，会相互交叉。</p>'''
 taxonomy_body=f'''<nav>{link('学习首页','index.html')} / {link('分级路线','learning-path.html')}</nav><p class="eyebrow">分类地图与覆盖边界</p><h1>分支不能只用一张<br>互斥名单装下。</h1><p class="lead">本地导航含 {len(fields)-1} 个学习领域和共同准备，合计 {topic_count} 个方向条目（跨领域名称可重复）。这是较广的学习地图，仍不声称囊括物理学全部分类。</p><section><h2>同时使用四种视角</h2><ol><li>基础理论：经典力学、电磁学、热力学统计、量子与相对论。</li><li>研究对象与尺度：原子、核、粒子、凝聚态、等离子体、地球与宇宙。</li><li>研究方法：理论、数学、计算、实验、观测、数据分析；这些方法贯穿各分支。</li><li>应用与相关学科：医学、化学、能源、信息、历史与教育；它们不全是与基础理论并列的“主分支”。</li></ol>{source_note}<p>相同主题可能有多个归属：量子光学连接光学与原子物理；磁重联连接空间与等离子体；主动软物质连接凝聚态与生物物理。这里用多个入口表达这种关系。</p></section><label for="topic-search">按方向名称搜索</label><input id="topic-search" type="search" placeholder="例如：超导、湍流、量子引力" aria-describedby="topic-status"><p id="topic-status" role="status">显示全部领域</p>'''+''.join(taxonomy)+'''<section><h2>还有哪些不能声称已经覆盖</h2><p>细分技术、具体材料、特定天体、不断出现的交叉方向，无法靠固定目录穷尽。弦论、量子引力和超出标准模型的某些方案是候选理论，不与实验已确认结论混写。前沿分类更新时应重新核查官方主题体系。</p></section>'''
 (root/'taxonomy.html').write_text(page('分类树与覆盖范围',taxonomy_body,0),encoding='utf-8')
 official=json.loads((root/'classification-reference.json').read_text(encoding='utf-8'))
 official_rows=''.join('<tr><td>'+E(item['code'])+'</td><td>'+'、'.join(link(fields[n]['name'],fields[n]['folder']+'/index.html') for n in item['local_fields'])+'</td></tr>' for item in official['categories'])
 official_section=f'''<section><h2>arXiv 物理组分类逐项对照</h2><p>对照范围：2026-11-01 获取的官方页面 Physics 组全部 {len(official['categories'])} 个末级分类代码。下表每项均有本地导航归属；这只证明在这一明确口径下没有漏掉代码，不证明每项都有完整教程，也不代表全部物理学分类。</p><div class="table-scroll"><table><thead><tr><th>官方分类代码</th><th>本地学习入口</th></tr></thead><tbody>{official_rows}</tbody></table></div><p>映射为本教材的编辑选择；跨学科条目允许多个入口。代码事实来源：{link('arXiv 分类原页',official['source'])}。本地快照：{link('classification-reference.json','classification-reference.json')}。</p></section>'''
 taxonomy_body=taxonomy_body.replace('<label for="topic-search">',official_section+'<label for="topic-search">')
 (root/'taxonomy.html').write_text(page('分类树与覆盖范围',taxonomy_body,0),encoding='utf-8')
 path_body=f'''<nav>{link('首页','index.html')} / {link('分类树','taxonomy.html')}</nav><p class="eyebrow">从学习知识走向独立判断</p><h1>入门 → 核心 → 高阶<br>→ 研究训练。</h1><p class="lead">“大师”不是一个可以凭读完文件授予的等级。这里把目标拆成可以检查的能力，按先修前进，而不是按网页数量估计水平。</p><section><h2>阶段 0：准备</h2><p>学习代数、三角函数、单位和图像；继续补微积分、复数、线性代数、概率。对应 {link('学习准备','00-学习准备/index.html')}。通过条件：能给物理式检查量纲、解释导数和积分、解二阶线性方程与简单本征值题。</p><h2>阶段 1：基础物理</h2><p>顺序为经典力学 → 振动波动 → 热学、电磁学 → 光学 → 狭义相对论与量子入门。先学现象与实验依据，再建立模型。通过条件：能独立画受力图、做能量账本、用场解释相互作用、用概率解释量子测量。</p><h2>阶段 2：本科核心</h2><p>系统补分析力学、矢量电磁学、热力学与统计、量子力学；并行学习数学方法、实验测量和计算。当前各分支第 03 课是选题切入，不足以替代完整学期。应读主教材对应章节，完成章后题并接受批改。</p><h2>阶段 3：高阶专门化</h2><p>选择 1–2 个方向深入：例如凝聚态需要多体与统计；粒子需要相对论量子理论和场论；引力需要微分几何；流体需要 PDE 与稳定性。当前第 04 课只示范部分高阶方法，其他主题在分类树中仍为待补。</p><h2>阶段 4：研究训练与独立工作</h2><p>先复现已知结果，再比较模型与数据，阅读综述和论文，逐步形成可检验的新问题。通过条件应包括导师或同行评议、可复现材料和对局限的准确判断。原创研究没有统一保证完成的年限。</p></section><section><h2>按学习目标安排训练</h2><ol><li>概念兴趣：先遍历入门课，找到想深入的两三个问题。</li><li>大学基础：围绕四大理论安排连续学期，不能只做本项目的短自测。</li><li>研究准备：锁定具体方向，补先修、完成复现项目，并获得外部反馈。</li></ol><p>每周可采用：2 次概念与推导、2 次独立习题、1 次实验或计算、1 次闭卷复习。时长按你的基础调整，当前没有虚构个人测评结果。</p></section><section><h2>系统课程与开放资料</h2><ul><li>{link('OpenStax 大学物理','https://openstax.org/subjects/science')}：基础教材与章后题。</li><li>{link('MIT OCW 8.01SC','https://ocw.mit.edu/courses/8-01sc-classical-mechanics-fall-2016/')}：完整力学课程的例题和练习组织。</li><li>{link('David Tong 讲义目录','https://davidtong.org/teaching/')}：本科到研究生的理论物理讲义，按每门课先修阅读。</li><li>{link('arXiv 学科目录','https://arxiv.org/category_taxonomy')}：找论文主题入口；预印本需独立核对论证与后续评议。</li></ul><p>外链需要联网；当前中文小课和训练说明均可离线阅读。</p></section><h2>逐领域课程与项目</h2><div class="grid">'''+''.join(cards)+'</div>'
 (root/'learning-path.html').write_text(page('分级学习路线',path_body,0),encoding='utf-8')
 intro=f'''<p class="eyebrow">中文离线物理教材 · 范围与完成度公开</p><h1>看清物理全景，<br>逐步学会做研究。</h1><p class="lead">从基础概念、控制方程和推导，走向计算、实验与论文复现。每一阶段都用可检查的证据检验学习。</p><div class="stats"><span><strong>{len(fields)-1}</strong>学习领域 + 共同准备</span><span><strong>{total}</strong>已编写正文课</span><span><strong>{len(project_rows)}</strong>研究训练任务</span><span><strong>{len(base_rows)}</strong>交互图示</span></div><section><h2>先看两张地图</h2><p>{link('分类树：所有本地列出的方向与覆盖边界','taxonomy.html')} → {link('分级路线：先修、阶段与考核','learning-path.html')}。</p><p>当前共有 {total} 节正文课与 {len(project_rows)} 项复现训练说明；这是扩展后的选题教材。未完成全部子方向的系统教材，也不把读完页面等同于精通。分类覆盖与课程完成度是两件事。</p><p>零基础先 00 → 01 → 02，再学 03、04、05，之后进入相对论、量子和感兴趣的专门方向。高级课程必须另外补齐数学先修。</p></section><h2>课程目录</h2><div class="grid">'''+''.join(cards)+f'''</div><section><h2>本地使用</h2><p>双击 index.html 即可离线学习；参考书与论文外链需联网。完成标记保存在当前浏览器，可能受本地文件存储限制，不等于能力认证。</p>{source_note}</section>'''
 (root/'index.html').write_text(page('物理学学习手册',intro,0),encoding='utf-8')
 manifest={'lesson_count':total,'project_count':len(project_rows),'topic_entry_count':topic_count,'demo_count':len(base_rows),'fields':list(fields.values())}
 (root/'course-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
 md='''# 物理学学习手册

入口：[HTML 首页](index.html) · [详细分类树](taxonomy.html) · [入门到研究训练路线](learning-path.html)

## 先回答范围问题

上一版的 18 项是粗粒度教学归类，没有列完所有分类；38 节是入门选题课，没有写完全部子方向。当前补成 **25 个学习领域 + 共同准备**，单列流体、非线性、量子信息、化学物理、加速器、应用与能源、基础历史教育；相关学科不冒充互斥的基础主分支。

**仍不能声称“所有物理分类全部列完”或“入门到大师的所有教程全部写好”。** 物理学分类有交叉且持续发展；阅读教材也不能替代实验、计算、论文研读与导师/同行反馈。

分类核对参考 [APS PhySH](https://physh.org/) 与 [arXiv 分类](https://arxiv.org/category_taxonomy)，核对日期 2026-11-01。本地分类是面向学习的重组，不是官方目录的逐项完整复制。

## 当前实际交付

'''+f'- **{total} 节正文课**：原 38 节入门课、38 节数学/核心/高阶选题、14 节新增领域课程。\n- **{len(project_rows)} 项研究复现训练**：都有实施方法、已知结果检查、交付要求、误判提醒与扩展问题。\n- **{topic_count} 个方向条目**（跨领域名称可重复）：分类树列出导航，不将每条名称算作已完成教程。\n- **{len(base_rows)} 个交互图示**；全部正文、图示和自测可离线使用。\n'+'''
## 已有课程目录

| 编号 | 学习领域 | 类型 | 正文课 | 研究训练 |
|---|---|---|---:|---:|
'''+ '\n'.join(readme_table)+'''

## 学习顺序与完成标准

1. 高中数学与单位 → 微积分、复数、线性代数和概率。
2. 力学 → 波动 → 热学与电磁 → 光学 → 相对论和量子。
3. 分析力学、理论电磁学、热统、量子与数学方法形成本科核心；必须补整章练习。
4. 选 1–2 个专门方向深入研究生教材，再完成本地复现任务。
5. 阅读论文、独立形成问题、实施研究并接受评议，逐步培养独立研究能力。

每节正文有解释、推导或例题、自测、答案和适用范围。新增推导课有独立迁移题与解答。短题答对不是通过一个阶段的充分条件。

## 尚未完成的工作

- 分类树中全部细分方向的逐专题长篇课程、完整推导和成套分级题库。
- 四大理论每门完整学期的系统章程、全章练习与逐题批改。
- 研究生专题的全套讲义与各专题特有的实验或计算工具。
- 针对你的真实作答做出的分级测评、项目批改与研究反馈。

以上缺口已经在各分支首页与学习路线标出，不用自动生成的空标题充当完成的教材。

## 维护与验证

- 内容：`tools/build_course.py` 保留原课，`advanced_content.py`、`expanded_fields.py` 存新增内容，`extend_course.py` 生成扩展页面。
- 重建：`python tools/build_course.py`。每次都会从内容源生成当前版本。
- 依赖：Python 3.10+；验证工具需先 `pip install -r requirements.txt`，再运行 `python -m playwright install chromium` 安装浏览器。
- 验证：`python tools/check_course.py`。检查链接、离线加载、答题、进度与手机布局；不把功能检查等同于物理专家审校。
- 清单：`course-manifest.json`；检查记录：`verification/REPORT.md`。
- 教学方法沿用 [teach skill](https://github.com/mattpocock/skills/blob/main/skills/productivity/teach/SKILL.md) 的小课时、检索练习与间隔复习；未全局安装第三方 skill。
'''
 (root/'README.md').write_text(md,encoding='utf-8')
 with (root/'README.md').open('a',encoding='utf-8') as out:out.write(f'\n## 官方分类对照\n\n已对照 arXiv 物理组全部 {len(official["categories"])} 个末级分类代码（2026-11-01 页面快照），每项有本地导航归属。详见 [分类树中的对照表](taxonomy.html) 和 [机器可读快照](classification-reference.json)。这是相对于指定来源的分类覆盖检查，不是所有教程已完成的证明。\n')
 with (root/'README.md').open('a',encoding='utf-8') as out:
  out.write('\n## 详细子方向清单\n\n以下是本地学习导航；列出名称不等于已完成该专题教程。跨领域主题允许重复，不能用条目总数衡量学科覆盖率。\n')
  for f in fields.values():out.write('\n### '+f['id']+' '+f['name']+'\n\n'+'；'.join(f['all_topics'])+'。\n')
 resources='# 教材与方法来源\n\n查阅日期：2026-11-01。正文和习题为原创编写；以下为核对、延伸阅读入口，不整段复制教材。\n\n'+ '\n'.join(f'- [{title}]({url})' for title,url in sources.values())+'\n\n教学方法：[teach SKILL.md](https://github.com/mattpocock/skills/blob/main/skills/productivity/teach/SKILL.md)。使用短课、目标、反馈、检索与间隔复习；不要求安装该 skill。技能目录检索入口：[skills.sh](https://skills.sh/)。\n\nOpenStax 适合作为主教材；费曼讲义用于第二遍理解，难度更高；CERN 与 NASA 用于研究对象与领域概览。涉及高级方向时，先修与后续路线比急于背公式更重要。\n\n## 扩展版补充参考\n\n- [APS PhySH](https://physh.org/)：分类维度核对。\n- [arXiv 学科目录](https://arxiv.org/category_taxonomy)：论文方向导航。\n- [David Tong 讲义目录](https://davidtong.org/teaching/)：分级理论课程入口。\n- [MIT OCW 8.01SC](https://ocw.mit.edu/courses/8-01sc-classical-mechanics-fall-2016/)：系统力学课程。\n\n新增内容为原创推导与训练设计；入口链接不代表每一页已获得领域专家逐条审校。前沿项目实施时需重新核对具体文献。\n'
 (root/'RESOURCES.md').write_text(resources,encoding='utf-8')
 (root/'MISSION.md').write_text('# 学习目标\n\n用户希望建立覆盖物理学各方向的中文 HTML 教材，并从入门逐步达到独立研究水平。目录、课程正文与研究训练的完成度必须区分。\n\n当前执行：扩充分支与分级选题课，补研究复现训练；不把“大师”当作仅靠阅读可授予的阶段。\n',encoding='utf-8')
 (root/'NOTES.md').write_text('# 教学偏好与状态\n\n中文、离线 HTML、概念可视化。暂按高中数学起步，高阶先修明确列出。用户尚未作答，不推断掌握程度。用户要求继续扩展至研究级，不再局限于两节入门课。分类树比正文覆盖范围更广，未写出的专题明确标出。\n',encoding='utf-8')
 print(f'Expanded: {len(fields)} entrances; {total} lessons; {len(project_rows)} projects; {topic_count} topic entries.')
