"""Parallax engine API package: the Python implementation behind bin/plx-engine.

cli.py parses and validates flags and owns the exit path; lane.py holds what is
shared across engines (lane state, owned children, prompt assembly, usage
record); codex.py, claude.py, grok.py, devin.py and gemini.py are one adapter
each, exposing run(lane) and usage(src).

USAGE:
    from plx_engine.cli import main
    sys.exit(main(sys.argv[1:]))
"""
