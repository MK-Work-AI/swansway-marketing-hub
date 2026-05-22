# Swansway Marketing Hub — Deployment Guide
### Full stack: Supabase · Vercel · Anthropic API

---

## What you're deploying

| File | Purpose | Size |
|------|---------|------|
| `index.html` | Main hub — 11 brands, Brief Builder, Q-Plan upload | 281KB |
| `admin.html` | Admin dashboard — budgets, KPIs, channel config | 93KB |
| `supabase-schema.sql` | Database schema — run once | 9KB |
| `vercel.json` | Vercel deployment config | 1KB |

**Features included:**
- Group marketing plan — all 11 Swansway brands
- Per-brand plans: strategy, centres, campaigns, audiences, budget, KPIs
- ✏️ Campaign Brief Builder — 6-step, PESO model, science-based allocation, PDF export
- 📋 Save & load briefs — stored per user in Supabase
- 📄 Q-Plan upload — upload manufacturer PDF/DOCX per brand, Claude extracts and structures all requirements
- 🔒 Sign in / Sign up — Supabase auth, per-user data isolation (RLS)
- ⚙️ Admin dashboard — configure budgets, targets, channels, KPIs, campaign calendar

---

## Accounts you need

| Service | Free tier | Sign up |
|---------|-----------|---------|
| GitHub | Yes | github.com |
| Supabase | Yes (500MB, unlimited users) | supabase.com |
| Vercel | Yes (unlimited deploys) | vercel.com |
| Anthropic | Pay-as-you-go (~$0.01 per Q-plan upload) | console.anthropic.com |

---

## Step 1 — GitHub repo (5 mins)

1. Go to **github.com** → click **+** → **New repository**
2. Name: `swansway-marketing-hub`
3. Visibility: **Private** ← important
4. Click **Create repository**
5. Upload these 4 files to the root:
   - `index.html`
   - `admin.html`
   - `vercel.json`
   - `supabase-schema.sql`

---

## Step 2 — Supabase (10 mins)

### 2a. Create project
1. Go to **app.supabase.com** → **New project**
2. Name: `swansway-marketing-hub`
3. Region: **Europe West (London)**
4. Set a strong database password → save it
5. Click **Create new project** — takes ~90 seconds

### 2b. Run the schema
1. Left sidebar → **SQL Editor** → **New query**
2. Open `supabase-schema.sql`, select all, copy
3. Paste into the SQL editor → click **Run**
4. Expected result: `Success. No rows returned.`
5. Verify: go to **Table Editor** — you should see:
   - `profiles`
   - `briefs`
   - `brand_plans`

### 2c. Enable email auth
1. Left sidebar → **Authentication** → **Providers**
2. **Email** should already be enabled — confirm it is
3. Leave **Confirm email** ON (users get a confirmation link)

### 2d. Copy your API credentials
1. Left sidebar → **Project Settings** (cog icon) → **API**
2. Copy and save both:
   - **Project URL** — `https://xxxxxxxxxxxx.supabase.co`
   - **anon public key** — long string starting `eyJhbGci…`

---

## Step 3 — Anthropic API key (3 mins)

1. Go to **console.anthropic.com** → sign in
2. Left sidebar → **API Keys** → **Create Key**
3. Name it: `swansway-hub`
4. Copy the key — it starts `sk-ant-api03-…`
5. Save it — you won't see it again

> **Cost:** Each Q-plan upload uses ~2,000–4,000 input tokens + ~4,000 output tokens.  
> At current pricing that's roughly **£0.01–0.03 per document upload**. A very cheap operation.

---

## Step 4 — Add credentials to index.html (2 mins)

Open `index.html` in any text editor. Search for these three lines and replace the placeholder values:

```javascript
// Line ~2940 — Supabase
const SUPABASE_URL      = 'YOUR_SUPABASE_URL';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';

// Line ~3320 — Anthropic  
const ANTHROPIC_API_KEY = 'YOUR_ANTHROPIC_API_KEY';
```

Replace with your actual values:

```javascript
const SUPABASE_URL      = 'https://xxxxxxxxxxxx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
const ANTHROPIC_API_KEY = 'sk-ant-api03-...';
```

Save the file. Commit and push to GitHub.

> **Security note:** The Supabase `anon` key is safe to expose client-side — Row Level Security ensures users only access their own data. The Anthropic key is also used client-side here; for a higher-security setup, proxy it through a Vercel serverless function (ask Marcus/IT if needed).

---

## Step 5 — Deploy to Vercel (5 mins)

1. Go to **vercel.com** → **Add New Project**
2. Click **Import Git Repository** → select `swansway-marketing-hub`
3. Framework preset: **Other** (leave all defaults)
4. Click **Deploy**
5. Wait ~30 seconds → you'll see a live URL:  
   `https://swansway-marketing-hub.vercel.app`

### 5a. Update Supabase with your live URL
1. Back in Supabase → **Authentication** → **URL Configuration**
2. **Site URL**: `https://swansway-marketing-hub.vercel.app`
3. **Redirect URLs** → add: `https://swansway-marketing-hub.vercel.app/**`
4. Click **Save**

### 5b. Custom domain (optional, 15 mins)
1. Vercel project → **Settings** → **Domains**
2. Add: `hub.swanswaygroup.com` (or your preferred subdomain)
3. Add the DNS record shown in Vercel to your domain registrar
4. Propagates in 5–30 minutes
5. Update the Supabase Site URL to match your custom domain

---

## Step 6 — Create accounts (2 mins)

1. Open your live Vercel URL
2. Click **Sign in** (white button, top right of header)
3. Click **Create Account** tab
4. Enter your name, email (`marcus@swanswaygroup.com`), password
5. Check email → click confirmation link
6. Sign in → you're live

Repeat for each team member. Every user gets their own briefs and Q-plans — no cross-contamination.

---

## Day 1 usage checklist

- [ ] Sign in works ✓
- [ ] Navigate to a brand (e.g. Audi) → all 6 tabs load
- [ ] Brief Builder → build a test brief → Step 6 → Save brief
- [ ] 📋 My Briefs → test brief appears
- [ ] Load saved brief → restores correctly
- [ ] Navigate to Audi → Q-Plan tab → upload a test PDF
- [ ] Q-Plan processes and displays campaigns, actions, dates
- [ ] Admin dashboard (`/admin.html`) → sign in → edit a budget figure
- [ ] Export config from admin → JSON downloads

---

## How auto-deploy works

Vercel watches your GitHub repo. Any time you push a change to `index.html` or `admin.html`, Vercel deploys the new version automatically in ~30 seconds. No manual steps.

**To update the hub:** edit `index.html` → save → push to GitHub → done.

---

## Feature reference

### Brief Builder
- 6-step wizard: Brand → Campaign type → Budget → Audiences → PESO channels → Output
- Science-based allocation (Ehrenberg-Bass, Binet & Field, Byron Sharp)
- CPL benchmarks per brand pulled from playbook data
- Save to Supabase → retrieve from 📋 My Briefs panel
- PDF export via browser print

### Q-Plan Upload
- Accepts PDF, DOCX, PPTX, TXT
- Sends to Claude Sonnet 4.5 for structured extraction
- Extracts: campaigns, dates, models, creative specs, co-op funding, mandatories, action items
- Action items are tick-off checkboxes (state persists in localStorage per brand/quarter)
- Previous plans stored in Supabase → accessible from 📂 Previous plans button
- Auto-loads most recent active plan when you open a brand page

### Admin dashboard (`/admin.html`)
- Password protected (default: `swansway2026` — change on first login)
- Configure: group budget, all 11 brand budgets/targets/CPL, channel mix, KPIs, calendar
- Save to Supabase → hub reads and reflects your configuration
- Take snapshots for year-on-year archiving
- Export/import full config as JSON
- `archiveAndNewYear()` function in Google Sheets (if also using Sheets backend)

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Sign in button does nothing | Check `SUPABASE_URL` and `SUPABASE_ANON_KEY` are pasted correctly |
| "Invalid API key" on sign in | You may have used the `service_role` key — use `anon` key |
| Confirmation email not arriving | Check spam; or in Supabase Auth → Users → confirm manually |
| Q-Plan upload fails | Check `ANTHROPIC_API_KEY` is correct; check browser console for error |
| Q-Plan shows no actions | Document may be a scanned image PDF — try DOCX version instead |
| Admin page won't load | Ensure `admin.html` is uploaded to the repo root |
| Brief not saving | Must be signed in; check Supabase `briefs` table has RLS policies |
| `brand_plans` table missing | Re-run `supabase-schema.sql` — safe to run again, uses `if not exists` |
| Changes not appearing | Wait 60 seconds after GitHub push for Vercel to redeploy |

---

## File structure in GitHub repo

```
swansway-marketing-hub/         ← private GitHub repo
├── index.html                  ← Main hub (281KB — everything in one file)
├── admin.html                  ← Admin dashboard (93KB)
├── vercel.json                 ← Deployment config
├── supabase-schema.sql         ← Run once in Supabase SQL editor
└── DEPLOYMENT.md               ← This guide
```

---

## Database tables

| Table | Purpose |
|-------|---------|
| `profiles` | Team member display names, auto-created on signup |
| `briefs` | Saved campaign briefs from Brief Builder |
| `brand_plans` | Uploaded manufacturer Q-plans, Claude-extracted |
| `AuditLog` | (Google Sheets only) Save action log |

All tables have Row Level Security — users only see their own rows.

---

## Costs at scale

| Usage | Monthly cost estimate |
|-------|-----------------------|
| 5 users, daily use | ~£0 (all free tiers) |
| 50 Q-plan uploads/month | ~£0.50–1.50 (Anthropic only) |
| Supabase storage | Free up to 500MB (~50,000 briefs) |
| Vercel hosting | Free (unlimited bandwidth on hobby plan) |

---

*Swansway Motor Group · Marketing Hub · Built May 2026*  
*Stack: Supabase · Vercel · Anthropic Claude · Vanilla JS · Zero dependencies*
