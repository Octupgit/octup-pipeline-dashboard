#!/usr/bin/env python3
"""
Auto-sync script for Octup RevOps Pipeline Dashboard.
Fetches live data from HubSpot and updates the baked-in JS arrays in the HTML file.

Usage: HS_PAT=<token> python3 scripts/refresh_data.py
"""

import os, json, re, sys, time, urllib.request, urllib.error
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

OWNER_IDS   = {'29896105', '29422733', '30284350', '74016070', '33508297'}  # added Joshua Jackson
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

STAGE_NAMES = {
    '2918051007': 'NBM',
    '2918051008': 'Stalled',
    '608286675':  'Discovery',
    '740160705':  'Presentation',
    '608286676':  'Solution Alignment',
    '4988070119': 'Trial',
    '608286677':  'Commercial Review',
    '608286678':  'Won',
    '608286679':  'Lost',
}

LEAD_STATUS_MAP = {
    'new':                  'New Lead',
    'open':                 'Open',
    'in_progress':          'In Progress',
    'open_deal':            'Has Deal',
    'unqualified':          'Unqualified',
    'attempted_to_contact': 'Attempted',
    'connected':            'Connected',
    'bad_timing':           'Bad Timing',
}

COMPANY_LIFECYCLE_MAP = {
    '737555912':          'Prospect',
    '737479612':          'MQL',
    '737555913':          'SQL',
    '737555914':          'Opportunity',
    '261097686':          'Client / Trial',
    '737555917':          'Account Active',
    'customer':           'Brand Client',
    '575905252':          'Unqualified',
    '739392741':          'Closed Lost',
    '614568683':          'Churned',
    'marketingqualifiedlead': 'Brand MQL',
    'lead':               'Lead',
    '5022983403':         'For Review',
}

# Lifecycle stage IDs → internal stage key for LIFECYCLE_CONTACTS
LIFECYCLE_STAGE_IDS = {
    '737555912': 'prospect',
    '737479612': 'mql',
    '737555913': 'sql',
    '737555914': 'opportunity',
    '737555917': 'active',
}

# ── HubSpot API helpers ───────────────────────────────────────────────────────
# HubSpot search API allows 4 req/sec on standard tier. We throttle pagination
# loops to stay under that, and back off on any 429 the server sends anyway.
PAGINATE_SLEEP = 0.25   # seconds between paginated requests
MAX_RETRIES    = 5
BASE_BACKOFF   = 1.0    # seconds; doubles each retry, capped at 30s

def _hs_request(req):
    """Execute an HTTP request with retry on 429 and 5xx.
    Honors HubSpot's Retry-After header when present."""
    for attempt in range(MAX_RETRIES):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            transient = e.code == 429 or 500 <= e.code < 600
            if not transient or attempt == MAX_RETRIES - 1:
                raise
            retry_after = e.headers.get('Retry-After') if e.headers else None
            try:
                wait = float(retry_after) if retry_after else min(BASE_BACKOFF * (2 ** attempt), 30.0)
            except ValueError:
                wait = min(BASE_BACKOFF * (2 ** attempt), 30.0)
            print(f'  ⚠ HubSpot {e.code} on {req.full_url[:80]}... retry {attempt + 1}/{MAX_RETRIES} in {wait:.1f}s')
            time.sleep(wait)
        except urllib.error.URLError as e:
            if attempt == MAX_RETRIES - 1:
                raise
            wait = min(BASE_BACKOFF * (2 ** attempt), 30.0)
            print(f'  ⚠ HubSpot network error ({e}). retry {attempt + 1}/{MAX_RETRIES} in {wait:.1f}s')
            time.sleep(wait)

def hs_get(path):
    url = f'https://api.hubapi.com{path}'
    req = urllib.request.Request(url, headers={
        'Authorization': f'Bearer {HS_PAT}',
        'Content-Type': 'application/json',
    })
    return _hs_request(req)

def hs_post(path, body):
    url = f'https://api.hubapi.com{path}'
    data = json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, headers={
        'Authorization': f'Bearer {HS_PAT}',
        'Content-Type': 'application/json',
    }, method='POST')
    return _hs_request(req)

def search_all(path, body, key='results'):
    """Paginate through all results from a search endpoint."""
    all_items, after, first = [], None, True
    while True:
        if after:
            body['after'] = after
        if not first:
            time.sleep(PAGINATE_SLEEP)
        resp = hs_post(path, body)
        first = False
        all_items.extend(resp.get(key, []))
        after = resp.get('paging', {}).get('next', {}).get('after')
        if not after:
            break
    return all_items

def get_all(path, key='results'):
    """Paginate through all results from a GET endpoint."""
    all_items, after, first = [], None, True
    while True:
        url = path + (f'&after={after}' if after else '')
        if not first:
            time.sleep(PAGINATE_SLEEP)
        resp = hs_get(url)
        first = False
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
        'deal_source','event_source','hs_v2_date_entered_current_stage','hs_priority',
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
            safe_str(p.get('event_source', '')),                                      # [11] srcDetail (Deal Source Details)
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
             'hs_created_by_user_id','dealstage','deal_source','event_source','closed_lost_reason']
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
            fmt_date(p.get('createdate')),              # [7] createDate — for WoW chart
            safe_str(p.get('event_source', '')),  # [8] srcDetail
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
            fmt_date(p.get('createdate')),              # [8] createDate — for WoW chart
            safe_str(p.get('closed_lost_reason')),      # [9] closed lost reason
            safe_str(p.get('event_source', '')),  # [10] srcDetail
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

# ── Marketing contacts (form submissions) ─────────────────────────────────────
FORM_LIST_ID = '154243004'   # "Get Demo Form Requests" saved list in HubSpot

SOURCE_KEY_MAP = {
    'DIRECT_TRAFFIC': 'direct',
    'ORGANIC_SEARCH': 'organic',
    'REFERRALS':      'other',
    'SOCIAL_MEDIA':   'organic',
    'EMAIL_MARKETING':'email',
    'PAID_SEARCH':    'google',
    'PAID_SOCIAL':    'meta',
    'OTHER_CAMPAIGNS':'other',
    'OFFLINE':        'other',
}

def fetch_contact_deal_assocs(contact_ids):
    """Batch-fetch deal associations for a list of contact IDs.
    Returns dict {contact_id_str: [deal_id_str, ...]}
    """
    if not contact_ids:
        return {}
    result = {}
    chunk_size = 100
    for i in range(0, len(contact_ids), chunk_size):
        chunk = contact_ids[i:i+chunk_size]
        body = {'inputs': [{'id': str(cid)} for cid in chunk]}
        try:
            resp = hs_post('/crm/v4/associations/contacts/deals/batch/read', body)
            for r in resp.get('results', []):
                from_id = str(r.get('from', {}).get('id', ''))
                to_ids  = [str(a.get('toObjectId', '')) for a in r.get('to', [])]
                if from_id:
                    result[from_id] = to_ids
        except Exception as e:
            print(f'  ⚠ Batch contact-deal assoc: {e}')
    return result

def fetch_all_lifecycle_contacts():
    """Fetch contacts at all 5 lifecycle stages (Prospect → MQL → SQL → Opportunity → Active)."""
    print('  Fetching lifecycle contacts (all stages)...')
    stage_ids = list(LIFECYCLE_STAGE_IDS.keys())
    props = ['firstname','lastname','email','company',
             'hs_analytics_source','hs_analytics_source_data_1',
             'createdate','lifecyclestage','num_associated_deals']
    body = {
        'filterGroups': [
            {'filters': [{'propertyName': 'lifecyclestage', 'operator': 'EQ', 'value': sid}]}
            for sid in stage_ids
        ],
        'properties': props,
        'sorts': [{'propertyName': 'createdate', 'direction': 'DESCENDING'}],
        'limit': 100,
    }
    contacts = search_all('/crm/v3/objects/contacts/search', body)
    print(f'  → {len(contacts)} lifecycle contacts')
    return contacts

def build_lifecycle_contacts(raw):
    rows = []
    for c in raw:
        p = c.get('properties', {})
        first = safe_str(p.get('firstname', ''))
        last  = safe_str(p.get('lastname', ''))
        name  = (f'{first} {last}'.strip()) or safe_str(p.get('email', ''))
        email = safe_str(p.get('email', ''))
        company = safe_str(p.get('company', '')) or '—'

        src       = safe_str(p.get('hs_analytics_source', ''))
        src_data1 = safe_str(p.get('hs_analytics_source_data_1', ''))
        source_label = SOURCE_MAP.get(src, 'Direct')
        source_key   = SOURCE_KEY_MAP.get(src, 'direct')
        if src in ('PAID_SEARCH', 'PAID_SOCIAL'):
            s1 = src_data1.lower()
            if 'linkedin' in s1:
                source_key, source_label = 'linkedin', 'LinkedIn Ads'
            elif 'facebook' in s1 or 'meta' in s1 or 'instagram' in s1:
                source_key, source_label = 'meta', 'Meta Ads'
            else:
                source_key, source_label = 'google', 'Google Ads'

        lifecycle_raw = safe_str(p.get('lifecyclestage', ''))
        stage = LIFECYCLE_STAGE_IDS.get(lifecycle_raw, '')
        stage_label = COMPANY_LIFECYCLE_MAP.get(lifecycle_raw, lifecycle_raw.title() if lifecycle_raw else '')
        create_date = fmt_date(p.get('createdate', ''))
        deal_count  = safe_int(p.get('num_associated_deals', 0))

        rows.append({
            'name':          name,
            'email':         email,
            'company':       company,
            'source':        source_label,
            'source_key':    source_key,
            'date':          create_date,
            'stage':         stage,
            'stage_label':   stage_label,
            'has_deal':      deal_count > 0,
            'deal_count':    deal_count,
        })
    rows.sort(key=lambda r: r['date'], reverse=True)
    return rows

def js_lifecycle_contacts(rows):
    parts = []
    for r in rows:
        has_deal = 'true' if r['has_deal'] else 'false'
        parts.append(
            f"{{name:{js_str(r['name'])},email:{js_str(r['email'])},company:{js_str(r['company'])},"
            f"source:{js_str(r['source'])},source_key:{js_str(r['source_key'])},"
            f"date:{js_str(r['date'])},stage:{js_str(r['stage'])},stage_label:{js_str(r['stage_label'])},"
            f"has_deal:{has_deal},deal_count:{r['deal_count']}}}"
        )
    return '[\n' + ',\n'.join('  ' + p for p in parts) + '\n]'

def fetch_contact_company_assocs(contact_ids):
    """Batch-fetch primary company ID for each contact."""
    if not contact_ids:
        return {}
    result = {}
    chunk_size = 100
    for i in range(0, len(contact_ids), chunk_size):
        chunk = contact_ids[i:i+chunk_size]
        body = {'inputs': [{'id': str(cid)} for cid in chunk]}
        try:
            resp = hs_post('/crm/v4/associations/contacts/companies/batch/read', body)
            for r in resp.get('results', []):
                from_id = str(r.get('from', {}).get('id', ''))
                to_ids  = [str(a.get('toObjectId', '')) for a in r.get('to', [])]
                if from_id and to_ids:
                    result[from_id] = to_ids[0]
        except Exception as e:
            print(f'  ⚠ Batch contact-company assoc: {e}')
    return result

def fetch_company_lifecycle_stages(company_ids):
    """Batch-read lifecyclestage for a list of company IDs."""
    if not company_ids:
        return {}
    result = {}
    ids = list(set(str(c) for c in company_ids if c))
    chunk_size = 100
    for i in range(0, len(ids), chunk_size):
        chunk = ids[i:i+chunk_size]
        body = {'inputs': [{'id': cid} for cid in chunk], 'properties': ['lifecyclestage']}
        try:
            resp = hs_post('/crm/v3/objects/companies/batch/read', body)
            for r in resp.get('results', []):
                cid   = str(r.get('id', ''))
                stage = safe_str(r.get('properties', {}).get('lifecyclestage', ''))
                if cid:
                    result[cid] = COMPANY_LIFECYCLE_MAP.get(stage, stage)
        except Exception as e:
            print(f'  ⚠ Batch company lifecycle: {e}')
    return result

def fetch_mkt_contacts():
    """Fetch contacts who submitted demo/pricing forms via CRM search (no lists scope needed)."""
    print('  Fetching marketing contacts (form submissions)...')
    try:
        props = ['firstname','lastname','email','company',
                 'hs_analytics_source','hs_analytics_source_data_1','hs_analytics_source_data_2',
                 'createdate','recent_conversion_event_name','num_associated_deals',
                 'hs_lead_status','lifecyclestage']
        # Match exact HubSpot saved list forms: "Get Demo Landing Page Form", "Pricing Request Form"
        body = {
            'filterGroups': [
                {'filters': [{'propertyName': 'recent_conversion_event_name',
                              'operator': 'EQ', 'value': 'Get Demo Landing Page Form'}]},
                {'filters': [{'propertyName': 'recent_conversion_event_name',
                              'operator': 'EQ', 'value': 'Pricing Request Form'}]},
            ],
            'properties': props,
            'sorts': [{'propertyName': 'createdate', 'direction': 'DESCENDING'}],
            'limit': 100,
        }
        contacts = search_all('/crm/v3/objects/contacts/search', body)
        print(f'  Found {len(contacts)} form submission contacts')
        return contacts
    except Exception as e:
        print(f'  ⚠ Could not fetch mkt contacts: {e}')
        return []

def build_mkt_contacts(raw, contact_deal_assocs=None, deal_stage_map=None, contact_company_assocs=None, company_lifecycle_map=None):
    rows = []
    for c in raw:
        p = c.get('properties', {})
        first = safe_str(p.get('firstname', ''))
        last  = safe_str(p.get('lastname', ''))
        name  = (f'{first} {last}'.strip()) or safe_str(p.get('email', ''))
        email = safe_str(p.get('email', ''))
        company = safe_str(p.get('company', '')) or '—'

        src       = safe_str(p.get('hs_analytics_source', ''))
        src_data1 = safe_str(p.get('hs_analytics_source_data_1', ''))
        src_data2 = safe_str(p.get('hs_analytics_source_data_2', ''))

        source_label = SOURCE_MAP.get(src, 'Direct')
        source_key   = SOURCE_KEY_MAP.get(src, 'direct')
        if src in ('PAID_SEARCH', 'PAID_SOCIAL'):
            s1 = src_data1.lower()
            if 'linkedin' in s1:
                source_key = 'linkedin'
                source_label = 'LinkedIn Ads'
            elif 'facebook' in s1 or 'meta' in s1 or 'instagram' in s1:
                source_key = 'meta'
                source_label = 'Meta Ads'
            else:
                source_key = 'google'
                source_label = 'Google Ads'

        create_date = fmt_date(p.get('createdate', ''))
        conversion  = safe_str(p.get('recent_conversion_event_name', '')).lower()
        form_type   = 'Demo Meeting' if any(kw in conversion for kw in ['meeting', 'booking', 'calendly', 'book demo']) else 'Demo Form'
        deal_count  = safe_int(p.get('num_associated_deals', 0))

        # Lead status and lifecycle stage
        lifecycle_raw  = safe_str(p.get('lifecyclestage', ''))
        lead_status_raw = safe_str(p.get('hs_lead_status', ''))
        lead_status    = LEAD_STATUS_MAP.get(lead_status_raw, lead_status_raw.replace('_', ' ').title() if lead_status_raw else '')

        # Company lifecycle stage (primary company)
        company_id = contact_company_assocs.get(c['id'], '') if contact_company_assocs else ''
        company_lifecycle = company_lifecycle_map.get(company_id, '') if (company_lifecycle_map and company_id) else ''

        # Best deal stage for this contact (prefer open/won over lost)
        deal_stage = ''
        if contact_deal_assocs is not None and deal_stage_map is not None:
            assoc_deal_ids = contact_deal_assocs.get(c['id'], [])
            best = ''
            for did in assoc_deal_ids:
                ds = deal_stage_map.get(str(did), '')
                if not ds:
                    continue
                if ds not in ('Won', 'Lost'):
                    best = ds  # prefer active deal stage
                    break
                if not best:
                    best = ds  # fallback to won/lost
            deal_stage = best

        rows.append({
            'name':           name,
            'email':          email,
            'company':        company,
            'source':         source_label,
            'source_key':     source_key,
            'campaign':       src_data1 or '—',
            'traffic_source': src_data2 or src_data1 or '—',
            'form':           form_type,
            'date':           create_date,
            'last_activity':  f'{create_date} · Form submitted',
            'has_deal':       deal_count > 0,
            'deal_count':     deal_count,
            'lifecycle_stage':  lifecycle_raw,
            'lead_status':      lead_status,
            'deal_stage':       deal_stage,
            'company_lifecycle':company_lifecycle,
        })

    rows.sort(key=lambda r: r['date'], reverse=True)
    return rows

def js_mkt_contacts(rows):
    parts = []
    for r in rows:
        has_deal = 'true' if r['has_deal'] else 'false'
        parts.append(
            f"{{name:{js_str(r['name'])},email:{js_str(r['email'])},company:{js_str(r['company'])},"
            f"source:{js_str(r['source'])},source_key:{js_str(r['source_key'])},"
            f"campaign:{js_str(r['campaign'])},traffic_source:{js_str(r['traffic_source'])},"
            f"form:{js_str(r['form'])},date:{js_str(r['date'])},"
            f"last_activity:{js_str(r['last_activity'])},has_deal:{has_deal},deal_count:{r['deal_count']},"
            f"lifecycle_stage:{js_str(r.get('lifecycle_stage',''))},lead_status:{js_str(r.get('lead_status',''))},"
            f"deal_stage:{js_str(r.get('deal_stage',''))},company_lifecycle:{js_str(r.get('company_lifecycle',''))}}}"
        )
    return '[\n' + ',\n'.join('  ' + p for p in parts) + '\n]'

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

def update_html(html, deals, stage_entered, won, lost, meetings, calls, emails, mkt_contacts=None, lifecycle_contacts=None):
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
    if mkt_contacts:
        html = replace_block(html, 'MKT_CONTACTS', js_mkt_contacts(mkt_contacts))
    if lifecycle_contacts is not None:
        html = replace_block(html, 'LIFECYCLE_CONTACTS', js_lifecycle_contacts(lifecycle_contacts))

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
    won_raw  = fetch_closed_deals('608286678')   # Closed Won stage ID
    lost_raw = fetch_closed_deals('608286679')   # Closed Lost stage ID
    won  = build_won(won_raw)
    lost = build_lost(lost_raw)

    # Build deal-stage lookup for contact enrichment
    deal_stage_map = {}
    for d in deals:
        deal_stage_map[str(d[0])] = STAGE_NAMES.get(str(d[3]), str(d[3]))
    for d in won:
        deal_stage_map[str(d[0])] = 'Won'
    for d in lost:
        deal_stage_map[str(d[0])] = 'Lost'

    # Engagements are best-effort — won't fail the sync if missing
    meeting_raw = fetch_engagements('MEETING', days_back=60)
    call_raw    = fetch_engagements('CALL',    days_back=60)
    email_raw   = fetch_engagements('EMAIL',   days_back=120)

    meetings = build_meetings(meeting_raw)
    calls    = build_calls(call_raw)
    emails   = build_emails(email_raw)

    lifecycle_raw_all     = fetch_all_lifecycle_contacts()
    lifecycle_contacts    = build_lifecycle_contacts(lifecycle_raw_all)

    mkt_raw               = fetch_mkt_contacts()
    contact_ids           = [c['id'] for c in mkt_raw]
    contact_deal_assocs   = fetch_contact_deal_assocs(contact_ids)
    contact_company_assocs= fetch_contact_company_assocs(contact_ids)
    company_ids           = list(contact_company_assocs.values())
    company_lifecycle_map = fetch_company_lifecycle_stages(company_ids)
    mkt_contacts          = build_mkt_contacts(mkt_raw, contact_deal_assocs, deal_stage_map, contact_company_assocs, company_lifecycle_map)

    html_path = os.path.abspath(HTML_FILE)
    print(f'\nUpdating {html_path}...')
    with open(html_path, 'r', encoding='utf-8') as f:
        html = f.read()

    html = update_html(html, deals, stage_entered, won, lost, meetings, calls, emails, mkt_contacts, lifecycle_contacts)

    with open(html_path, 'w', encoding='utf-8') as f:
        f.write(html)

    print(f'\n✅ Done — {len(deals)} open, {len(won)} won, {len(lost)} lost, '
          f'{len(meetings)} meetings, {len(calls)} calls, {len(emails)} emails, '
          f'{len(mkt_contacts)} mkt contacts, {len(lifecycle_contacts)} lifecycle contacts')

if __name__ == '__main__':
    main()
