#!/usr/bin/env python3
"""
Claude Code PreToolUse Hook: Block Destructive SQL Operations.
Blocks DROP, TRUNCATE, and DELETE without WHERE.
Exits with code 2 to block tool execution, or code 0 to allow.
"""
import sys
import json
import re

def is_python_method(text: str, match_start: int) -> bool:
    """Check if keyword is preceded by a dot (e.g. df.drop or df.delete)."""
    if match_start > 0 and text[match_start - 1] == '.':
        return True
    return False

def check_destructive_sql(text: str):
    if not isinstance(text, str):
        return None

    # 1. Check DROP (e.g. DROP TABLE, DROP DATABASE, DROP VIEW, DROP SCHEMA, etc.)
    drop_pattern = r'\bDROP\s+(TABLE|DATABASE|SCHEMA|VIEW|INDEX|CATALOG|FUNCTION|PROCEDURE)\b'
    for match in re.finditer(drop_pattern, text, re.IGNORECASE):
        if not is_python_method(text, match.start()):
            return "Comando SQL 'DROP' detectado."

    if re.search(r'\bDROP\b', text, re.IGNORECASE) and re.search(r'\b(TABLE|DATABASE|SCHEMA|VIEW|INDEX|CATALOG)\b', text, re.IGNORECASE):
        return "Comando SQL 'DROP' detectado."

    # 2. Check TRUNCATE (e.g. TRUNCATE TABLE, TRUNCATE)
    for match in re.finditer(r'\bTRUNCATE\b', text, re.IGNORECASE):
        if not is_python_method(text, match.start()):
            return "Comando SQL 'TRUNCATE' detectado."

    # 3. Check DELETE without WHERE
    for match in re.finditer(r'\bDELETE\b', text, re.IGNORECASE):
        if is_python_method(text, match.start()):
            continue
        
        # Extract text after DELETE up to semicolon or end of string
        after_delete = text[match.end():]
        statement = after_delete.split(';')[0]
        
        if not re.search(r'\bWHERE\b', statement, re.IGNORECASE):
            return "Comando SQL 'DELETE' sem cláusula WHERE detectado."

    return None

def main():
    try:
        raw_input = sys.stdin.read()
        if not raw_input:
            sys.exit(0)
        
        data = json.loads(raw_input)
        tool_input = data.get("tool_input", {})
        
        texts_to_check = []
        if isinstance(tool_input, dict):
            for v in tool_input.values():
                if isinstance(v, str):
                    texts_to_check.append(v)
                elif isinstance(v, dict):
                    for sub_v in v.values():
                        if isinstance(sub_v, str):
                            texts_to_check.append(sub_v)

        for text in texts_to_check:
            reason = check_destructive_sql(text)
            if reason:
                sys.stderr.write(f"🚫 [HOOK BLOQUEADO] {reason}\n")
                sys.exit(2)

    except Exception:
        sys.exit(0)

    sys.exit(0)

if __name__ == "__main__":
    main()
