"""Non-destructive T-pose skinning of the supplied mesh. No downloaded assets."""
import json, struct, pathlib
import numpy as np

root=pathlib.Path(__file__).resolve().parents[1]
b=(root/'characters/HighPoly_Reference.glb').read_bytes()
n=struct.unpack_from('<I',b,12)[0]; g=json.loads(b[20:20+n]); data=bytearray(b[28+n:])
a=g['accessors'][0]; v=g['bufferViews'][a['bufferView']]
p=np.frombuffer(data,dtype='<f4',count=a['count']*3,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,3).copy()
bones=[('Hips',-1,(0,.98,0)),('Spine',0,(0,1.16,0)),('Chest',1,(0,1.4,0)),('Neck',2,(0,1.59,0)),('Head',3,(0,1.7,0)),
('LeftUpperArm',2,(.21,1.48,0)),('LeftForeArm',5,(.46,1.48,0)),('LeftHand',6,(.69,1.48,0)),
('RightUpperArm',2,(-.21,1.48,0)),('RightForeArm',8,(-.46,1.48,0)),('RightHand',9,(-.69,1.48,0)),
('LeftThigh',0,(.12,.94,0)),('LeftShin',11,(.17,.53,0)),('LeftFoot',12,(.21,.11,0)),
('RightThigh',0,(-.12,.94,0)),('RightShin',14,(-.17,.53,0)),('RightFoot',15,(-.21,.11,0))]
pos=np.array([x[2] for x in bones])
ends=[1,2,3,4,None,6,7,None,9,10,None,12,13,None,15,16,None]
dist=[]
for i,(_,_,start) in enumerate(bones):
    start=pos[i]; end=pos[ends[i]] if ends[i] is not None else start+np.array((0,.16,0) if i==4 else ((.12 if start[0]>0 else -.12),0,0) if 'Hand' in bones[i][0] else (0,-.06,.09))
    line=end-start; t=np.clip(((p-start)*line).sum(1)/(line@line),0,1)
    d=np.linalg.norm(p-(start+t[:,None]*line),axis=1)
    if i in [5,6,7,8,9,10]: d+=np.where((np.abs(p[:,0])<.19)|(p[:,1]<1.3),2,0)
    if i>=11: d+=np.where(p[:,1]>1.01,2,0)
    if i<5: d+=np.where((np.abs(p[:,0])>.30)&(p[:,1]>1.31),2,0)
    dist.append(d)
dist=np.array(dist).T; joints=np.argsort(dist,axis=1)[:,:4]
ds=np.take_along_axis(dist,joints,axis=1); weights=np.exp(-(ds-ds[:,0:1])*45); weights/=weights.sum(1,keepdims=True)
def accessor(arr,kind,component):
    while len(data)%4:data.append(0)
    offset=len(data); data.extend(arr.tobytes()); vi=len(g['bufferViews'])
    g['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':arr.nbytes})
    ai=len(g['accessors']); g['accessors'].append({'bufferView':vi,'componentType':component,'count':len(arr),'type':kind})
    return ai
attrs=g['meshes'][0]['primitives'][0]['attributes']
attrs['JOINTS_0']=accessor(joints.astype('<u2'),'VEC4',5123)
attrs['WEIGHTS_0']=accessor(weights.astype('<f4'),'VEC4',5126)
colors=np.tile([.66,.40,.26,1.],(len(p),1))
colors[(p[:,1]<1.13)&(p[:,1]>.61)]=[.07,.12,.23,1]
colors[(p[:,1]<1.13)&(p[:,1]>1.04)]=[.82,.68,.35,1]
colors[p[:,1]<.25]=[.055,.06,.085,1]
colors[(np.abs(p[:,0])>.66)&(p[:,1]>1.3)]=[.80,.13,.10,1]
attrs['COLOR_0']=accessor(colors.astype('<f4'),'VEC4',5126)
g['materials'][0]['pbrMetallicRoughness']['baseColorFactor']=[1,1,1,1]
g['materials'][0]['pbrMetallicRoughness']['roughnessFactor']=.68
g['nodes']=[{'name':'Boxer','children':[1,2]},{'name':'OriginalMesh','mesh':0,'skin':0}]
for i,(name,parent,point) in enumerate(bones):
    node={'name':name,'translation':(pos[i]-(pos[parent] if parent>=0 else np.zeros(3))).tolist()}
    children=[j+2 for j,x in enumerate(bones) if x[1]==i]
    if children:node['children']=children
    g['nodes'].append(node)
ibm=np.tile(np.eye(4,dtype='<f4'),(len(bones),1,1)); ibm[:,3,:3]=-pos
g['skins']=[{'name':'BoxingRig','joints':list(range(2,len(bones)+2)),'skeleton':2,'inverseBindMatrices':accessor(ibm,'MAT4',5126)}]
g['scenes']=[{'nodes':[0]}]; g['scene']=0
while len(data)%4:data.append(0)
g['buffers']=[{'byteLength':len(data)}]
j=json.dumps(g,separators=(',',':')).encode()
while len(j)%4:j+=b' '
out=struct.pack('<III',0x46546c67,2,28+len(j)+len(data))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(data),0x004e4942)+data
(root/'characters/boxer_rigged.glb').write_bytes(out)
print('Built',len(bones),'bones;',len(p),'original vertices; weights normalized:',np.max(abs(weights.sum(1)-1)))
