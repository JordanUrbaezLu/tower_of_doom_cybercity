"""Remove microscopic collapse slivers before the BO3 converter does so silently."""
import math
def clean(data, min_edge=.001, min_altitude=.0005):
    kept=[]
    for face in data['faces']:
        a,b,c=[data['verts'][corner['v']] for corner in face]
        edges=(math.dist(a,b),math.dist(b,c),math.dist(c,a))
        u=[b[i]-a[i] for i in range(3)];v=[c[i]-a[i] for i in range(3)]
        cross=(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])
        height=math.sqrt(sum(x*x for x in cross))/max(max(edges),1e-20)
        if min(edges)<min_edge or height<min_altitude:continue
        kept.append(face)
    data['native_slivers_removed']=len(data['faces'])-len(kept)
    data['faces']=kept
    return data
