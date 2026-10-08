import sqlite3,json
from pathlib import Path
MT=Path('C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130')
db=sqlite3.connect((MT/'gdtdb/gdt.db').as_uri()+'?mode=ro',uri=True);db.execute('pragma writable_schema=ON');db.row_factory=sqlite3.Row
rows=db.execute("select _name,materialCategory,materialType from material where materialType like '%emissive%' and (materialType like '%trans%' or materialType like '%add%') limit 25").fetchall()
print('TRANSPARENT_EMISSIVE',json.dumps([dict(r) for r in rows],indent=2))
rows=db.execute("select _name,materialCategory,materialType from material where materialType like '%unlit%' limit 15").fetchall()
print('UNLIT',json.dumps([dict(r) for r in rows],indent=2))
for name in ('mtl_tod_cyber_kit','chaos_pap_background'):
 r=dict(db.execute('select * from material where _name=?',(name,)).fetchone());print(name,json.dumps({k:v for k,v in r.items() if v and not k.startswith('_') and any(t in k.lower() for t in ('emiss','scale','blend','cull','alpha','color','material','sort','draw','depth'))},indent=2))
