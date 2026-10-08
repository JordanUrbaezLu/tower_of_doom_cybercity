"""Use the upstream MCP transport for the inducer's own live Blender studio."""
import asyncio, datetime, json, os, pathlib, sys
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
ROOT = pathlib.Path(__file__).resolve().parents[2]
async def main():
    env = dict(os.environ, BLENDER_MCP_DISABLE_TELEMETRY='1', BLENDER_HOST='127.0.0.1', BLENDER_PORT='9884')
    params = StdioServerParameters(command=sys.executable, args=['-m','blender_mcp.server'], env=env)
    async with stdio_client(params) as (read,write):
        async with ClientSession(read,write,read_timeout_seconds=datetime.timedelta(seconds=600)) as session:
            await session.initialize()
            path = pathlib.Path(sys.argv[1]).resolve()
            result = await session.call_tool('execute_blender_code', {'code':'__file__ = '+repr(str(path))+'\n'+path.read_text(encoding='utf-8-sig'), 'user_prompt':'Inspect and correct the actual ported Rampage Inducer against the supplied Call of Duty references.'})
            for content in result.content:
                if hasattr(content,'text'): print(content.text)
            if result.isError or any('Error executing code' in getattr(c,'text','') for c in result.content): raise SystemExit(1)
asyncio.run(main())
