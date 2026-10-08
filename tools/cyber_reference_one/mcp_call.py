"""Upstream MCP ClientSession, same transport as the Tower II sword, own port."""
import asyncio, datetime, json, os, pathlib, sys, base64
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT/'tmp/cyber_reference_one_mcp'
OUT.mkdir(parents=True, exist_ok=True)
PROMPT = 'Use Blender MCP to reconstruct equipment from CyberZombie1.png on the existing zombie, with mechanical arm and hand, detailed worn materials, harness and cyber hardware.'
async def main():
    env = dict(os.environ, BLENDER_MCP_DISABLE_TELEMETRY='1', BLENDER_HOST='127.0.0.1', BLENDER_PORT='9877')
    params = StdioServerParameters(command=sys.executable, args=['-m','blender_mcp.server'], env=env)
    async with stdio_client(params) as (read, write):
        async with ClientSession(read,write,read_timeout_seconds=datetime.timedelta(seconds=600)) as session:
            await session.initialize()
            if len(sys.argv)<2:
                name='get_scene_info'; args={'user_prompt':PROMPT}
            elif sys.argv[1]=='screenshot':
                name='get_viewport_screenshot'; args={'max_size':1400,'user_prompt':PROMPT}
            else:
                path=pathlib.Path(sys.argv[1]).resolve()
                name='execute_blender_code'; args={'code':'__file__ = '+repr(str(path))+'\n'+path.read_text(encoding='utf-8-sig'),'user_prompt':PROMPT}
            result=await session.call_tool(name,args)
            stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
            (OUT/(stamp+'.json')).write_text(json.dumps(result.model_dump(mode='json'),indent=2))
            for content in result.content:
                if hasattr(content,'text'):print(content.text)
                elif getattr(content,'type','')=='image':
                    path=OUT/(stamp+'.png');path.write_bytes(base64.b64decode(content.data));print('SCREENSHOT',path)
            if result.isError or any('Error executing code' in getattr(c,'text','') for c in result.content):raise SystemExit(1)
asyncio.run(main())
