# Config Documentation Hygiene — Thin Reference Pattern

## The rule

**Never embed live configuration values in markdown documentation.** No YAML blocks with `provider:`, `model:`, `base_url:`, `api_key:`, or `fallback_providers:` lists in `.md` files.

## Why

Config changes weekly. Embedded blocks go stale in hours. The agent must then "fix" documentation that was designed to break — wasting tokens and user patience. Maarten treats this as inexcusable laziness.

## The alternative

Documentation points to the live config files. Readers run a command to see current values.

### Bad — embedded block (stale immediately)

```yaml
fallback_providers:
  - provider: example-provider
    model: example-model
  - provider: another-provider
    model: another-model
```

### Good — thin reference pointing to live config

```bash
python3 - <<'PY'
import yaml
from pathlib import Path
for f in [Path.home()/'.hermes/config.yaml', *sorted((Path.home()/'.hermes/profiles').glob('*/config.yaml'))]:
    data = yaml.safe_load(f.read_text()) or {}
    print(f.parent.name if 'profiles' in str(f) else 'default')
    print('  model:', data.get('model'))
    print('  fallbacks:', data.get('fallback_providers'))
PY
```

## Where this applies

- `05 - AI/08 - Model Notes/Model Configuration.md`
- `05 - AI/03 - Personas/Hermes Agent Profiles.md`
- `05 - AI/Dev/gateway-fallback-fix.md`
- Any skill reference under `~/.hermes/skills/**` that documents Hermes provider/model/fallback chains
- Cron pipeline docs if they mention provider/model routing

## Exceptions

Historical case studies (`references/2026-06-03-deepseek-removal-and-writeback.md`) may quote config blocks **as historical evidence** — but must be explicitly framed as "what the config looked like at time X", not current reference.

Generic templates (`references/model-provider-plugins.md`) may use placeholder values (`provider-slug`, `model-name`) — but never real provider/model names from the live config.

## Verification

Run this after any documentation change to confirm no embedded config crept back in:

```bash
python3 - <<'PY'
from pathlib import Path
roots=[
    Path.home()/'.hermes/skills',
    Path('/Users/absorbo/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian/05 - AI'),
]
hits=[]
for root in roots:
    for p in root.rglob('*.md'):
        if any(x in str(p) for x in ['deepseek-removal','model-provider-plugins']): continue
        txt=p.read_text()
        in_code=False
        for i,line in enumerate(txt.splitlines(),1):
            if line.strip().startswith('```'):
                in_code=not in_code if not in_code else False
                continue
            if in_code and any(m in line for m in ['provider:','model:','base_url:','api_key:']) and '```' not in line:
                if 'data.get(' in line or 'model.get(' in line: continue
                hits.append((str(p),i,line.strip()[:80]))
print('HITS',len(hits))
for h in hits[:20]: print('\t'.join(map(str,h)))
PY
```
