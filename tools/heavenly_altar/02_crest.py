import sys,importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import design_lib as D
importlib.reload(D)
from design_lib import *
D.group='03 Celestial crest'
CZ=104
disc('Crest | deep rear titanium drum',0,CZ,-19,21.4,12,dark)
ring('Crest | machined rear gold rim',0,CZ,-19.6,21.2,.65,9,gold)
ring('Crest | outer ivory armor',0,CZ,-23,20.2,2.3,3.5,ivory)
ring('Crest | outside gold bevel',0,CZ,-24,21.4,.5,1,goldlight)
ring('Crest | outer warm conductor',0,CZ,-24.3,20.9,.22,.5,warm)
ring('Crest | inner warm conductor',0,CZ,-24.3,17.8,.28,.5,white)
ring('Crest | inset shadow annulus',0,CZ,-23.7,16.6,1.1,1.5,dark)
ring('Crest | inner titanium annulus',0,CZ,-24.2,15.8,.8,1,steel)
disc('Crest | dark celestial field',0,CZ,-24,15.2,1.5,optic)
ring('Crest | inner violet arc',0,CZ,-25,13.4,.32,.55,violet)
ring('Crest | pink orbit',0,CZ,-25.5,11.2,.22,.5,pink)
ring('Crest | gold optic rim',0,CZ,-25.4,10.4,.55,.7,goldlight)
ring('Crest | cyan inner optic',0,CZ,-25.8,9.8,.18,.5,cyan)
disc('Crest | central blue lens',0,CZ,-25,9.4,.7,optic)
for i in range(48):
    a=math.tau*i/48
    ring('Crest | segmented ceramic index',0,CZ,-24.25,19.25,2.05,.8,ivory2,start=a+.016,end=a+math.tau/48-.016,N=3)
    r1,r2=18.5,20.1
    line('Crest | luminous radial tick',[(r1*math.cos(a),CZ+r1*math.sin(a)),(r2*math.cos(a),CZ+r2*math.sin(a))],-24.7,.12,white if i%3 else warm)
    if i%4==0:
        bolt('Crest | outer dial fastener',21.05*math.cos(a),CZ+21.05*math.sin(a),-24.1,.18)
for i in range(12):
    a=math.tau*i/12+.14
    ring('Crest | segmented inner machinery',0,CZ,-24.25,14.7,1.6,.8,dark,start=a,end=a+.37,N=5)
    line('Crest | interior spoke',[(12*math.cos(a),CZ+12*math.sin(a)),(16*math.cos(a),CZ+16*math.sin(a))],-24.6,.17,gold)
    disc('Crest | calibration pilot',12.7*math.cos(a),CZ+12.7*math.sin(a),-25,.16,.2,cyan,12)
# Four raised, separately housed glyph medallions at cardinal directions.
for idx,a in enumerate((0,math.pi/2,math.pi,math.pi*1.5)):
    x,z=16.6*math.cos(a),CZ+16.6*math.sin(a)
    disc('Rune | gold pedestal',x,z,-26,5,3,gold)
    disc('Rune | graphite well',x,z,-26.7,4.55,1,dark)
    ring('Rune | gold rim',x,z,-27.1,4.6,.35,.7,goldlight)
    ring('Rune | violet luminous rim',x,z,-27.5,4.15,.23,.5,pink)
    disc('Rune | recessed blue enamel',x,z,-26.9,3.88,.5,optic)
    ring('Rune | inner hairline',x,z,-27.3,3.65,.08,.3,violet)
    up=idx in (1,3)
    pts=[(x,z+2.65),(x-2.6,z-1.95),(x+2.6,z-1.95)] if up else [(x,z-2.8),(x-2.6,z+1.9),(x+2.6,z+1.9)]
    outline('Rune | illuminated triangular glyph',pts,-27.7,.15,cyan if not up else violet)
    if up:
        little=[(x,z+.5),(x-.85,z-.95),(x+.85,z-.95)]
        outline('Rune | nested triangle',little,-27.7,.09,white)
    for q in (-1,1):box('Rune | clasp',(x+q*4.7,-26.8,z),(.9,1,.8),goldlight,.08)
# Central alchemical triangle, golden circle, and point light core.
outline('Crest | central triangle',[(0,CZ+8.5),(-6.9,CZ-4.7),(6.9,CZ-4.7)],-27,.29,goldlight)
outline('Crest | triangle illuminated inner edge',[(0,CZ+7.9),(-6.4,CZ-4.35),(6.4,CZ-4.35)],-27.25,.08,white)
ring('Crest | central alchemical circle',0,CZ-1.5,-27.2,2.8,.33,.5,goldlight)
disc('Crest | inner blue star',0,CZ-1.5,-27.35,.6,.25,cyan,32)
# Fine celestial circuit tracery in the otherwise dark field.
for i in range(24):
    a=math.tau*i/24+.05;r=8.6
    x,z=r*math.cos(a),CZ+r*math.sin(a)
    line('Crest | starfield circuit',[(x,z),(x*.9,CZ+(z-CZ)*.9)],-25.9,.03,cyan)
    if i%3==0:disc('Crest | star node',x,z,-25.95,.08,.1,white,8)
D.group='04 Crown fins and halo'
for s in (-1,1):
    for j in range(2):
        pts=[(s*(8+j*1.5),122),(s*(9+j*1.5),129-j*.8),(s*(10+j*1.5),131-j*.8),(s*(11+j*1.5),128-j*.8),(s*(11+j*1.5),122)]
        panel('Crown | upward gold prong',pts,-8+j*1.3,5,gold,.15)
        line('Crown | ivory blade edge',[(s*(9+j*1.5),123),(s*(10+j*1.5),129-j*.8)],-8.3+j*1.3,.35,ivory2)
ring('Crest | suspended rear violet halo',0,CZ,-5,24,.18,.3,violet,start=.1,end=math.pi-.1,N=140)
ring('Crest | suspended rear gold halo',0,CZ,-3,26,.15,.3,warm,start=.2,end=math.pi-.2,N=140)
for s in (-1,1):
    for k in range(4):
        a=.45+k*.54
        if s<0:a=math.pi-a
        ring('Crest | bright halo packet',0,CZ,-5.1,24,.3,.3,white,start=a,end=a+.12,N=8)
save('02 articulated celestial dial and four glyph medallions')
