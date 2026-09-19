"""Call the local Godot AI MCP server and retain its original JSON responses."""

import argparse
import asyncio
import base64
import json
from pathlib import Path

from mcp import ClientSession
from mcp.client.streamable_http import streamable_http_client


async def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://127.0.0.1:8000/mcp")
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--schema")
    parser.add_argument("--tool")
    parser.add_argument("--args", default="{}")
    parser.add_argument("--args-file", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    async with streamable_http_client(args.url) as (read, write, _):
        async with ClientSession(read, write) as session:
            await session.initialize()
            if args.list or args.schema:
                result = await session.list_tools()
                value = [
                    tool.model_dump(mode="json", exclude_none=True)
                    if args.schema else {"name": tool.name, "description": tool.description}
                    for tool in result.tools
                    if not args.schema or tool.name == args.schema
                ]
            else:
                if not args.tool:
                    parser.error("supply --list, --schema or --tool")
                arguments = json.loads(args.args_file.read_text(encoding="utf-8") if args.args_file else args.args)
                result = await session.call_tool(args.tool, arguments)
                value = result.model_dump(mode="json", exclude_none=True)
            if args.output:
                args.output.parent.mkdir(parents=True, exist_ok=True)
                args.output.write_text(json.dumps(value, indent=2), encoding="utf-8")
            # Preserve images in the raw report; print paths instead of base64.
            if isinstance(value, dict):
                for index, content in enumerate(value.get("content", [])):
                    if content.get("type") == "image" and args.output:
                        suffix = ".png" if content.get("mimeType") == "image/png" else ".jpg"
                        target = args.output.with_name(args.output.stem + f"-{index}" + suffix)
                        target.write_bytes(base64.b64decode(content.pop("data")))
                        content["saved_image"] = str(target)
            print(json.dumps(value, indent=2))
            return int(isinstance(value, dict) and bool(value.get("isError")))


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
