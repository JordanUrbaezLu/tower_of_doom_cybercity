"""Upstream MCP ClientSession into the cyber inducer's live Blender (port 9884).

Same transport as the Heavenly Altar / reference-one studios. Run with the
Tower II MCP environment (it carries `mcp` + `blender_mcp`):
  ../tower_of_doom_II_hellbound/tmp/gold_sword_env/Scripts/python.exe \
      tools/inducer_cyber/mcp_call.py <stage.py>      # execute a stage script
  ... mcp_call.py screenshot                           # capture the live viewport
  ... mcp_call.py                                      # scene info
Transcripts + screenshots land in tmp/inducer_cyber/mcp/.
"""
import asyncio, base64, datetime, json, os, pathlib, sys
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT/'tmp/inducer_cyber/mcp'
OUT.mkdir(parents=True, exist_ok=True)
PROMPT = 'Design and build a cyber-styled Rampage Inducer for Tower of Doom in its isolated live Blender studio.'


async def main():
    env = dict(os.environ, BLENDER_MCP_DISABLE_TELEMETRY='1', BLENDER_HOST='127.0.0.1', BLENDER_PORT='9884')
    params = StdioServerParameters(command=sys.executable, args=['-m', 'blender_mcp.server'], env=env)
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write, read_timeout_seconds=datetime.timedelta(seconds=900)) as session:
            await session.initialize()
            if len(sys.argv) < 2:
                name, args = 'get_scene_info', {'user_prompt': PROMPT}
            elif sys.argv[1] == 'screenshot':
                size = int(sys.argv[2]) if len(sys.argv) > 2 else 1400
                name, args = 'get_viewport_screenshot', {'max_size': size, 'user_prompt': PROMPT}
            else:
                path = pathlib.Path(sys.argv[1]).resolve()
                code = '__file__ = ' + repr(str(path)) + '\n' + path.read_text(encoding='utf-8-sig')
                name, args = 'execute_blender_code', {'code': code, 'user_prompt': PROMPT}
            result = await session.call_tool(name, args)
            stamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
            (OUT/(stamp + '.json')).write_text(json.dumps(result.model_dump(mode='json'), indent=2))
            for content in result.content:
                if hasattr(content, 'text'):
                    print(content.text)
                elif getattr(content, 'type', '') == 'image':
                    path = OUT/(stamp + '.png')
                    path.write_bytes(base64.b64decode(content.data))
                    print('SCREENSHOT', path)
            if result.isError or any('Error executing code' in getattr(c, 'text', '') for c in result.content):
                raise SystemExit(1)

asyncio.run(main())
