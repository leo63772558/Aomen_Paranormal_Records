"""Read this chat's latest rate-limit event without credentials or transcript output.

The app usage-limit tool currently returns Invalid app tool request. This is a
read-only fallback to the account rate-limit snapshot emitted in this chat's
token_count events, not a network request and not an agent-stop daemon.
"""
import argparse, datetime, json
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('--thread-id',default='01a1bcbc-a630-7a70-89bb-fb49bbcc92e0')
parser.add_argument('--output')
args=parser.parse_args()
root=Path('C:/Users/tffnf/.codex/sessions')
latest=None
for path in root.glob(f'2026/11/*/*{args.thread_id}*.jsonl'):
    with path.open(encoding='utf-8') as stream:
        for line in stream:
            try: item=json.loads(line)
            except (ValueError,UnicodeError): continue
            payload=item.get('payload',{})
            if not isinstance(payload,dict) or payload.get('type')!='token_count': continue
            limits=payload.get('rate_limits')
            if not isinstance(limits,dict): continue
            window=limits.get('primary')
            if not isinstance(window,dict) or window.get('window_minutes')!=300: continue
            stamp=item.get('timestamp','')
            if latest is None or stamp>latest['recorded_at']:
                latest={'source':'current_chat_token_count_rate_limits','recorded_at':stamp,
                        'window_minutes':300,'used_percent':window.get('used_percent'),
                        'resets_at':window.get('resets_at')}
if latest is None or latest['used_percent'] is None:
    raise SystemExit('No readable five-hour rate-limit snapshot; remaining quota is unknown.')
latest['remaining_percent']=max(0,min(100,100-latest['used_percent']))
now=datetime.datetime.now(datetime.timezone.utc)
recorded=datetime.datetime.fromisoformat(latest['recorded_at'].replace('Z','+00:00'))
latest['age_seconds']=round((now-recorded).total_seconds(),1)
latest['stop_threshold_reached']=latest['remaining_percent']<=5
latest['fresh']=latest['age_seconds']<=300
text=json.dumps(latest,ensure_ascii=False,indent=2)
if args.output:
    Path(args.output).write_text(text,encoding='utf-8')
print(text)
