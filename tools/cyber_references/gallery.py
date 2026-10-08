"""Publish a local review gallery of actual masters and exported source models."""
import hashlib,json,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
views=['front','back','head','arm','leg','chest','back_detail']
entries=[]
for i,word in enumerate(('one','two','three'),1):
    folder=ROOT/('art/cyber_reference_'+word+'_mcp');master=folder/('reference_'+word+'.blend')
    digest=hashlib.sha256(master.read_bytes()).hexdigest()
    if i>1:
        for view in views:
            record=json.loads((folder/(view+'.render.json')).read_text())
            assert record['master_sha256']==digest,(word,view,'stale preview')
            assert record['image_sha256']==hashlib.sha256((folder/(view+'.png')).read_bytes()).hexdigest()
    games=[p.stem.removeprefix('export_') for p in sorted((folder/'game_preview').glob('export_*.png'))]
    if i>1:
        for view in games:
            record=json.loads((folder/'game_preview'/('export_'+view+'.json')).read_text())
            if record.get('image_sha256'):
                assert hashlib.sha256((folder/'game_preview'/('export_'+view+'.png')).read_bytes()).hexdigest()==record['image_sha256'],(word,view,'preview image changed')
            for path,expected in record['source_binary_and_texture_hashes'].items():
                assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==expected,(word,view,'stale native preview',path)
    entries.append({'word':word,'title':'Reference '+str(i),'role':'Armored sprinter only' if i==3 else 'Regular zombies','ref':'CyberZombie'+str(i)+'.png','views':views,'native':games})
html='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Cyber zombie equipment — reference review</title>
<style>*{box-sizing:border-box}body{margin:0;background:#0c1015;color:#e4e9ed;font:16px system-ui}header{padding:24px 32px;border-bottom:1px solid #26313d}h1{font-size:25px;margin:0 0 8px}p{margin:8px 0;color:#a9b6c2}nav,.views{display:flex;gap:8px;flex-wrap:wrap;margin-top:14px}button,a.pill{background:#18222c;color:#dfe8f0;border:1px solid #344654;border-radius:7px;padding:9px 14px;cursor:pointer;font:inherit;text-decoration:none}button[aria-pressed=true]{border-color:#39d4e5;color:#72e3ec;background:#12333b}main{padding:20px 32px}.stage{display:grid;grid-template-columns:minmax(0,1.1fr) minmax(300px,1fr);gap:20px}figure{margin:0;background:#101820;border:1px solid #273540;border-radius:10px;overflow:hidden}figure img{width:100%;height:72vh;object-fit:contain;display:block}figcaption{padding:12px 16px;color:#b7c5d0}.reference img{object-fit:contain}.muted{font-size:13px;color:#97a9b8}footer{padding:20px 32px;color:#92a6b6}@media(max-width:900px){.stage{grid-template-columns:1fr}figure img{height:65vh}header,main,footer{padding:18px}}</style>
<header><h1>Cyber zombie equipment</h1><p>References one and two: regular zombies. Reference three: armored sprinter only.</p><nav id="models"></nav><nav id="modes"></nav><div class="views" id="views"></div></header>
<main><div class="stage"><figure><img id="model" alt="Actual Blender model render"><figcaption id="caption"></figcaption></figure><figure class="reference"><a id="refLink" target="_blank"><img id="reference" alt="User supplied equipment reference"></a><figcaption>Original equipment reference · click to enlarge</figcaption></figure></div><p class="muted">Game export views use the actual model binaries and baked textures, rendered in Blender. In-game lighting, animation clearance, and performance still need your playtest.</p><nav><a class="pill" id="blend">Open Blender master</a><a class="pill" id="report">Validation report</a></nav></main><footer>Original zombie bodies, heads and skin weights retained. Worn metal, chipped enamel, fitted restraints, cyan cells and emissive purple lines.</footer>
<script>const models=DATA;const request=new URLSearchParams(location.search);let current=Math.max(0,Math.min(2,Number(request.get('ref')||2)-1)),mode=request.get('mode')==='master'?'master':'native',view=request.get('view')||'front';const el=id=>document.getElementById(id);function button(text,selected,fn){let b=document.createElement('button');b.textContent=text;b.setAttribute('aria-pressed',selected);b.onclick=fn;return b}function render(){let m=models[current],base='../cyber_reference_'+m.word+'_mcp/';el('models').replaceChildren(...models.map((m,i)=>button(m.title+' · '+m.role,i===current,()=>{current=i;view='front';render()})));el('modes').replaceChildren(...['native','master'].map(v=>button(v==='native'?'Game export':'Detailed master',mode===v,()=>{mode=v;view='front';render()})));let list=mode==='native'?m.native:m.views;if(!list.includes(view))view=list[0];el('views').replaceChildren(...list.map(v=>button(v.replaceAll('_',' '),view===v,()=>{view=v;render()})));el('model').src=base+(mode==='native'?'game_preview/export_':'')+view+'.png';el('reference').src=base+m.ref;el('refLink').href=base+m.ref;el('caption').textContent=m.title+' · '+m.role+' · '+(mode==='native'?'Game export':'Detailed master')+' · '+view.replaceAll('_',' ');el('blend').href=base+'reference_'+m.word+'.blend';el('report').href=base+'validation.json'}render();</script></html>'''.replace('DATA',json.dumps(entries))
html=html.replace('Original zombie bodies, heads and skin weights retained.',
                  'Original rigs and skin weights retained. Armored forearms replaced by spike swords; rear armor spikes enlarged.')
target=ROOT/'art/cyber_zombie_roster/review.html'
backup=ROOT/'tmp/reference_23_backup/previous_review.html'
if not backup.exists():shutil.copy2(target,backup)
target.write_text(html,encoding='utf-8')
for word in ('two','three'):
    folder=ROOT/('art/cyber_reference_'+word+'_mcp')
    url='../cyber_zombie_roster/review.html?ref='+('3' if word=='three' else '2')
    (folder/'review.html').write_text('<!doctype html><meta http-equiv="refresh" content="0;url='+url+'"><a href="'+url+'">Open equipment gallery</a>')
rosterpath=ROOT/'art/cyber_zombie_roster/roster.json';roster=json.loads(rosterpath.read_text())
roster['status']='Blender references: 1/2 regular, 3 armored only. Original integration: docs/149; latest armored remodel: docs/173.'
for model in roster['models']:
    ref=3 if model['style']=='sprinter' else (2 if model['style'] in ('trooper','relay') else 1)
    word={1:'one',2:'two',3:'three'}[ref];model['reference']=ref
    model['equipment_master']='art/cyber_reference_'+word+'_mcp/reference_'+word+'.blend'
    if ref==2:model['description']='Reference 2: layered spinal machine, paired supply pipes, separate flank return, copper induction chamber, amber regulator, supported neural cell; twin chest cells and fitted limb braces.'
    elif ref==3:model['description']='Armored only: enclosed executioner helmet with a folded steel jaw and a brilliant red eye slit, elbow-to-tip spike swords, enlarged rear armor spikes, industrial collar, hazard case and knee brace; shared worn gunmetal, abraded edges and blackened fittings throughout; back tank and frame removed; model scale 1.33, arms-down walking.'
rosterpath.write_text(json.dumps(roster,indent=2)+'\n')
print('REFERENCE_GALLERY_READY',target)
