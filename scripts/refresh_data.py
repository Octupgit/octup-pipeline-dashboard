#!/usr/bin/env python3
"""
Auto-sync script for Octup RevOps Pipeline Dashboard.
Fetches live data from HubSpot and updates the baked-in JS arrays in the HTML file.

Usage: HS_PAT=<token> python3 scripts/refresh_data.py
"""

import os, json, re, sys, urllib.request, urllib.error
from datetime import datetime, timezone, timedelta

# ── Config ────────────────────────────────────────────────────────────────────
HS_PAT    = os.environ.get('HS_PAT', '')
HTML_FILE = os.path.join(os.path.dirname(__file__), '..', 'octup-pipeline-dashboard.html')
PORTAL    = '26004468'

ACTIVE_STAGES = [
    '2918051007',  # NBM
    '2918051008',  # Stalled
    '608286675',   # Discovery
    '740160705',   # Presentation
    '608286676',   # Solution Alignment
    '4988070119',  # Trial
    '608286677',   # Commercial Review
]

OWNER_IDS   = {'29896105', '29422733', '30284350', '74016070'}
PIPELINE_ID = '394300639'  # 3PL New Business

SOURCE_MAP = {
    'DIRECT_TRAFFIC':    'Direct',
    'ORGANIC_SEARCH':    'Organic Search',
    'REFERRALS':         'Referral',
    'SOCIAL_MEDIA':      'Social',
    'EMAIL_MARKETING':   'Email',
    'PAID_SEARCH':       'Paid Search',
    'OTHER_CAMPAIGNS':   'Campaign',
    'OFFLINE':           'Outbound Sales',
    'EVENT':             'Event or Webinar',
    'PAID_SOCIAL':       'Paid Social',
}

# ── HubSpot API helpers ───────────────────────────────────────────────────────
def hs_get(path):
    url = f'https://api.hubapi.com{path}'
    req = urllib.request.Request(url, headers={
        'Authorization': f'Bearer {HS_PAT}',
        'Content-Type': 'application/json',
    })
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())

def hs_post(path, body):
    url = f'https://api.hubapi.com{path}'
    data = json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, headers={
        'Authorization': f'Bearer {HS_PAT}',
        'Content-Type': 'application/json',
    }, method='POST')
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())

def search_all(path, body, key='results'):
    """Paginate through all results from a search endpoint."""
    all_items, after = [], None
    while True:
        if after:
            body['after'] = after
        resp = hs_post(path, body)
        all_items.extend(resp.get(key, []))
        after = resp.get('paging', {}).get('next', {}).get('after')
        if not after:
            break
    return all_items

def get_all(path, key='results'):
    """Paginate through all results from a GET endpoint."""
    all_items, after = [], None
    while True:
        url = path + (f'&after={after}' if after else '')
        resp = hs_get(url)
        all_items.extend(resp.get(key, []))
        after = resp.get('paging', {}).get('next', {}).get('after')
        if not after:
            break
    return all_items

# ── Data helpers ──────────────────────────────────────────────────────────────
def fmt_date(val):
    if not val:
        return ''
    s = str(val)
    if s.isdigit() and len(s) > 10:
        try:
            return datetime.fromtimestamp(int(s)/1000, tz=timezone.utc).strftime('%Y-%m-%d')
        except:
            pass
    return s[:10]

def safe_int(v, default=0):
    try:
        return int(float(v)) if v else default
    except:
        return default

def safe_str(v):
    if v is None:
        return ''
    return str(v).replace('\n', ' ').replace('\r', '').strip()

def deal_source(props):
    return safe_str(props.get('deal_source', ''))

# ── Fetch deals ───────────────────────────────────────────────────────────────
def fetch_open_deals():
    print('  Fetching open deals...')
    props = [
        'dealname','amount','dealstage','hubspot_owner_id','createdate',
        'closedate','hs_next_step','hs_created_by_user_id','notes_last_updated',
        'deal_source','hs_v2_date_entered_current_stage','reengage_date','hs_priority',
    ]
    body = {
        'filterGroups': [{'filters': [
            {'propertyName': 'dealstage', 'operator': 'IN',  'values': ACTIVE_STAGES},
            {'propertyName': 'pipeline',  'operator': 'EQ',  'value':  PIPELINE_ID},
        ]}],
        'properties': props,
        'limit': 100,
    }
    deals = search_all('/crm/v3/objects/deals/search', body)

    rows, stage_entered = [], {}
    for d in deals:
        p = d['properties']
        did = d['id']
        entered = fmt_date(p.get('hs_v2_date_entered_current_stage', ''))
        if entered:
            stage_entered[did] = entered
        rows.append([
            did,
            safe_str(p.get('dealname')),
            safe_int(p.get('amount')),
            safe_str(p.get('dealstage')),
            safe_str(p.get('hubspot_owner_id')),
            fmt_date(p.get('createdate')),
            fmt_date(p.get('closedate')),
            safe_str(p.get('hs_next_step')),
            safe_str(p.get('hs_created_by_user_id')),
            fmt_date(p.get('notes_last_updated')),
            deal_source(p),
            fmt_date(p.get('reengage_date')),   # [11] Reengage Date
            safe_str(p.get('hs_priority')).upper() if p.get('hs_priority') else '',  # [12] Priority (HIGH/MEDIUM/LOW)
        ])
    print(f'  → {len(rows)} open deals, {len(stage_entered)} stage dates')
    return rows, stage_entered

def fetch_closed_deals(stage, days_back=1825):
    # stage is the actual HubSpot stage ID (e.g. '608286678' for won, '608286679' for lost)
    # days_back=1825 (~5 years) to capture all historical deals
    print(f'  Fetching stage={stage} deals (last {days_back}d, pipeline {PIPELINE_ID})...')
    cutoff = int((datetime.now(timezone.utc) - timedelta(days=days_back)).timestamp() * 1000)
    props = ['dealname','amount','closedate','createdate','hubspot_owner_id',
             'hs_created_by_user_id','dealstage','deal_source']
    body = {
        'filterGroups': [{'filters': [
            {'propertyName': 'dealstage',  'operator': 'EQ',  'value': stage},
            {'propertyName': 'closedate',  'operator': 'GTE', 'value': str(cutoff)},
            {'propertyName': 'pipeline',   'operator': 'EQ',  'value': PIPELINE_ID},
        ]}],
        'properties': props,
        'limit': 100,
    }
    deals = search_all('/crm/v3/objects/deals/search', body)
    print(f'  → {len(deals)} deals')
    return deals

def build_won(deals):
    rows = []
    for d in deals:
        p = d['properties']
        rows.append([
            d['id'],
            safe_str(p.get('dealname')),
            safe_int(p.get('amount')),
            fmt_date(p.get('closedate')),
            safe_str(p.get('hubspot_owner_id')),
            safe_str(p.get('hs_created_by_user_id')),
            deal_source(p),
            fmt_date(p.get('createdate')),   # [7] createDate — for WoW chart
        ])
    return rows

def build_lost(deals):
    rows = []
    for d in deals:
        p = d['properties']
        rows.append([
            d['id'],
            safe_str(p.get('dealname')),
            safe_int(p.get('amount')),
            fmt_date(p.get('closedate')),
            safe_str(p.get('hubspot_owner_id')),
            safe_str(p.get('hs_created_by_user_id')),
            safe_str(p.get('dealstage')),
            deal_source(p),
            fmt_date(p.get('createdate')),   # [8] createDate — for WoW chart
        ])
    return rows

# ── Fetch activities ──────────────────────────────────────────────────────────
def batch_deal_associations(ids, eng_type_lc):
    """Fetch deal associations for a batch of engagement IDs in one API call.
    Returns dict {eng_id_str: [deal_id_str, ...]}
    """
    if not ids:
        return {}
    # HubSpot batch read: up to 100 per call
    result = {}
    chunk_size = 100
    for i in range(0, len(ids), chunk_size):
        chunk = ids[i:i+chunk_size]
        body = {'inputs': [{'id': str(eid)} for eid in chunk]}
        try:
            resp = hs_post(
                f'/crm/v4/associations/{eng_type_lc}/deals/batch/read', body
            )
            for r in resp.get('results', []):
                from_id = str(r.get('from', {}).get('id', ''))
                to_ids  = [str(a.get('toObjectId', '')) for a in r.get('to', [])]
                if from_id:
                    result[from_id] = to_ids
        except Exception as e:
            print(f'  ⚠ Batch assoc {eng_type_lc}: {e}')
    return result

def fetch_engagements(eng_type, days_back=60):
    print(f'  Fetching {eng_type} engagements (last {days_back}d)...')
    cutoff = int((datetime.now(timezone.utc) - timedelta(days=days_back)).timestamp() * 1000)
    try:
        props = ['hs_timestamp','hubspot_owner_id','hs_engagement_type',
                 'hs_activity_type','hs_call_title','hs_meeting_title',
                 'hs_meeting_outcome','hs_email_subject','hs_body_preview',
                 'hs_email_direction']
        body = {
            'filterGroups': [{'filters': [
                {'propertyName': 'hs_engagement_type', 'operator': 'EQ', 'value': eng_type},
                {'propertyName': 'hs_timestamp', 'operator': 'GTE', 'value': str(cutoff)},
            ]}],
            'properties': props,
            'limit': 100,
        }
        items = search_all('/crm/v3/objects/engagements/search', body)
        print(f'  → {len(items)} {eng_type}s')
        return items
    except Exception as e:
        print(f'  ⚠ Could not fetch {eng_type}: {e}')
        return []

def build_meetings(items):
    if not items:
        return []
    ids = [e['id'] for e in items]
    assoc_map = batch_deal_associations(ids, 'meetings')
    rows = []
    for e in items:
        p = e['properties']
        rows.append({
            'id': e['id'],
            'type': 'MEETING',
            'title': safe_str(p.get('hs_meeting_title') or p.get('hs_call_title', '')),
            'timestamp': fmt_date(p.get('hs_timestamp', '')),
            'outcome': safe_str(p.get('hs_meeting_outcome', '')),
            'ownerId': safe_str(p.get('hubspot_owner_id', '')),
            'dealIds': assoc_map.get(e['id'], []),
        })
    return rows

def build_calls(items):
    if not items:
        return []
    ids = [e['id'] for e in items]
    assoc_map = batch_deal_associations(ids, 'calls')
    rows = []
    for e in items:
        p = e['properties']
        rows.append({
            'id': e['id'],
            'title': safe_str(p.get('hs_call_title', '')),
            'timestamp': fmt_date(p.get('hs_timestamp', '')),
            'ownerId': safe_str(p.get('hubspot_owner_id', '')),
            'dealIds': assoc_map.get(e['id'], []),
        })
    return rows

def build_emails(items):
    if not items:
        return []
    ids = [e['id'] for e in items]
    assoc_map = batch_deal_associations(ids, 'emails')
    rows = []
    for e in items:
        p = e['properties']
        rows.append({
            'id': e['id'],
            'subject': safe_str(p.get('hs_email_subject', '')),
            'timestamp': fmt_date(p.get('hs_timestamp', '')),
            'ownerId': safe_str(p.get('hubspot_owner_id', '')),
            'dealIds': assoc_map.get(e['id'], []),
            'direction': safe_str(p.get('hs_email_direction', '')),
        })
    return rows

# ── JS serialisation ──────────────────────────────────────────────────────────
def js_str(v):
    return "'" + str(v).replace('\\','\\\\').replace("'","\\'") + "'"

def js_row(row):
    parts = []
    for v in row:
        if isinstance(v, int):
            parts.append(str(v))
        else:
            parts.append(js_str(v))
    return '[' + ','.join(parts) + ']'

def js_array(rows):
    return '[\n' + ',\n'.join('  ' + js_row(r) for r in rows) + '\n]'

def js_stage_entered(d):
    items = ','.join(f"'{k}':'{v}'" for k, v in sorted(d.items()))
    return '{\n  ' + items + '\n}'

def js_obj_array(rows):
    """Serialize list of dicts as JS array of objects."""
    parts = []
    for obj in rows:
        kv = []
        for k, v in obj.items():
            if isinstance(v, list):
                kv.append(f'{k}:{json.dumps(v)}')
            elif isinstance(v, int):
                kv.append(f'{k}:{v}')
            else:
                kv.append(f'{k}:{js_str(v)}')
        parts.append('{' + ','.join(kv) + '}')
    return '[\n' + ',\n'.join('  ' + p for p in parts) + '\n]'

# ── HTML replacement ──────────────────────────────────────────────────────────
def replace_block(html, var_name, new_value, open_char='[', close_char=']'):
    """Find `const VAR = [...];` or `const VAR = {...};` and replace the value."""
    pattern = rf'(const {re.escape(var_name)}\s*=\s*){re.escape(open_char)}[\s\S]*?{re.escape(close_char)};'
    replacement = rf'\g<1>{new_value};'
    new_html, n = re.subn(pattern, replacement, html, count=1)
    if n == 0:
        print(f'  ⚠ WARNING: could not find const {var_name} — skipping')
    return new_html

def update_html(html, deals, stage_entered, won, lost, meetings, calls, emails):
    now_utc = datetime.now(timezone.utc)
    now_str = now_utc.strftime('%Y-%m-%d %H:%M UTC')
    now_iso = now_utc.strftime('%Y-%m-%dT%H:%M:%SZ')
    print(f'  Replacing arrays in HTML (synced at {now_str})...')

    # Update sync timestamp constant
    html = re.sub(
        r"const LAST_SYNC_UTC = '[^']*';",
        f"const LAST_SYNC_UTC = '{now_iso}'; // AUTO-SYNC:TIMESTAMP — updated by refresh_data.py",
        html
    )

    html = replace_block(html, 'DEALS',         js_array(deals))
    html = replace_block(html, 'STAGE_ENTERED', js_stage_entered(stage_entered), '{', '}')
    html = replace_block(html, 'WON_DEALS',     js_array(won))
    html = replace_block(html, 'LOST_DEALS',    js_array(lost))

    if meetings:
        html = replace_block(html, 'MEETINGS', js_obj_array(meetings))
    if calls:
        html = replace_block(html, 'CALLS',    js_obj_array(calls))
    if emails:
        html = replace_block(html, 'EMAILS',   js_obj_array(emails))

    # Update last-synced comment at top of file
    html = re.sub(
        r'(// Last auto-synced:).*',
        rf'\1 {now_str}',
        html
    )
    return html

# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    if not HS_PAT:
        print('ERROR: HS_PAT environment variable not set.')
        print('Usage: HS_PAT=pat-na1-xxxx python3 scripts/refresh_data.py')
        sys.exit(1)

    print('=== Octup Dashboard — HubSpot Data Refresh ===')

    deals, stage_entered = fetch_open_deals()
    won   = build_won(fetch_closed_deals('608286678'))   # Closed Won stage ID
    lost  = build_lost(fetch_closed_deals('608286679'))  # Closed Lost stage ID

    # Engagements are best-effort — won't fail the sync if missing
    meeting_raw = fetch_engagements('MEETING', days_back=60)
    call_raw    = fetch_engagements('CALL',    days_back=60)
    email_raw   = fetch_engagements('EMAIL',   days_back=120)

    meetings = build_meetings(meeting_raw)
    calls    = build_calls(call_raw)
    emails   = build_emails(email_raw)

    html_path = os.path.abspath(HTML_FILE)
    print(f'\nUpdating {html_path}...')
    with open(html_path, 'r', encoding='utf-8') as f:
        html = f.read()

    html = update_html(html, deals, stage_entered, won, lost, meetings, calls, emails)

    with open(html_path, 'w', encoding='utf-8') as f:
        f.write(html)

    print(f'\n✅ Done — {len(deals)} open, {len(won)} won, {len(lost)} lost, '
          f'{len(meetings)} meetings, {len(calls)} calls, {len(emails)} emails')

if __name__ == '__main__':
    main()
