# WarrantyOS — Invoice Parsing & Warranty Tracking System

A production-ready SaaS application that lets customers upload invoice PDFs, automatically extracts product data via AI parsing, and tracks warranty expiration across all products.

## Architecture

```
Customer uploads invoice PDF
        ↓
File stored in Supabase Storage
        ↓
Make.com webhook triggered
        ↓
PDF.co Invoice Parser extracts data
        ↓
POST /api/invoices with parsed JSON
        ↓
Stored in Supabase Postgres
        ↓
Dashboard auto-updates
        ↓
Warranty countdown = Invoice Date + 30 months
```

## Tech Stack

| Layer        | Technology              |
| ------------ | ----------------------- |
| Frontend     | Next.js 14 + Tailwind   |
| UI Library   | Shadcn UI + Radix       |
| Database     | Supabase (Postgres)     |
| Auth         | Supabase Auth           |
| Storage      | Supabase Storage        |
| Automation   | Make.com                |
| PDF Parsing  | PDF.co Invoice Parser   |
| Hosting      | Vercel                  |
| Dark Mode    | next-themes             |

---

## 1. Supabase Setup

### Create a project
1. Go to [supabase.com](https://supabase.com) → New Project
2. Note your **Project URL** and **anon key** (Settings → API)
3. Note your **service_role key** (Settings → API → service_role)

### Run the database schema
1. Open the SQL Editor in Supabase Dashboard
2. Paste the contents of `database/schema.sql`
3. Click **Run**

This creates:
- `customers` table (linked to Supabase Auth)
- `invoices` table (one customer → many invoices)
- `products` table (one invoice → many products, with warranty expiry)
- Row Level Security (RLS) policies
- Auto-create customer trigger on signup
- Dashboard view with warranty calculations
- Storage bucket for invoice PDFs

---

## 2. Environment Variables

Create a `.env.local` file in the project root:

```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...your-anon-key
SUPABASE_SERVICE_ROLE_KEY=eyJ...your-service-role-key
PDFCO_API_KEY=your-pdfco-api-key
NEXT_PUBLIC_MAKE_WEBHOOK_URL=https://hook.make.com/your-webhook-id
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

---

## 3. Local Development

```bash
# Install dependencies
npm install

# Run dev server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

---

## 4. Make.com Automation Setup

This is the automation pipeline that parses invoices after upload.

### Scenario: Invoice Parser Pipeline

**Step 1 — Webhook Trigger**
1. In Make.com, create a new Scenario
2. Add a **Webhooks → Custom webhook** trigger
3. Copy the webhook URL → set as `NEXT_PUBLIC_MAKE_WEBHOOK_URL`
4. The webhook receives:
   ```json
   {
     "file_url": "https://...supabase.co/storage/v1/.../invoice.pdf",
     "customer_id": "uuid-of-customer"
   }
   ```

**Step 2 — HTTP Module (PDF.co API)**
1. Add an **HTTP → Make a request** module
2. Configure:
   - URL: `https://api.pdf.co/v1/pdf/invoiceparser`
   - Method: POST
   - Headers: `x-api-key: YOUR_PDFCO_API_KEY`
   - Body (JSON):
     ```json
     {
       "url": "{{1.file_url}}",
       "inline": true
     }
     ```
3. PDF.co returns parsed invoice data with fields like:
   - `invoiceId` → invoice_number
   - `dateIssued` → invoice_date
   - `items[].description` → product_name
   - `items[].sku` or custom field → serial_number

**Step 3 — JSON Transformer**
1. Add a **Tools → Set multiple variables** module
2. Map PDF.co response to your schema:
   - `invoice_number` = `{{2.body.invoiceId}}`
   - `invoice_date` = `{{2.body.dateIssued}}`
   - Build `products` array from `{{2.body.items}}`

**Step 4 — HTTP POST to Your API**
1. Add another **HTTP → Make a request** module
2. Configure:
   - URL: `https://your-app.vercel.app/api/invoices`
   - Method: POST
   - Content-Type: `application/json`
   - Body:
     ```json
     {
       "invoice_number": "{{3.invoice_number}}",
       "invoice_date": "{{3.invoice_date}}",
       "products": {{3.products}},
       "customer_id": "{{1.customer_id}}",
       "pdf_url": "{{1.file_url}}"
     }
     ```

### Handling Multiple Products per Invoice

PDF.co's `items` array may contain multiple line items. Each item can have its own serial number. In Step 3, use Make.com's **Iterator** module if needed to loop through items and build the products array:

```json
{
  "products": [
    { "product_name": "Router X", "serial_number": "SN1923" },
    { "product_name": "Switch Y", "serial_number": "SN1924" },
    { "product_name": "Cable Z", "serial_number": "SN1925" }
  ]
}
```

---

## 5. API Reference

### POST /api/invoices

Creates an invoice with associated products and calculates warranty expiry.

**Request Body:**
```json
{
  "invoice_number": "INV-2024-001",
  "invoice_date": "2024-01-15",
  "products": [
    { "product_name": "Router X500", "serial_number": "SN-001923" },
    { "product_name": "Switch Pro", "serial_number": "SN-001924" }
  ],
  "customer_id": "uuid",
  "pdf_url": "https://..."
}
```

**Response (201):**
```json
{
  "message": "Invoice and products created successfully",
  "invoice": {
    "id": "uuid",
    "invoice_number": "INV-2024-001",
    "invoice_date": "2024-01-15",
    "product_count": 2
  }
}
```

### GET /api/invoices?customer_id=uuid

Returns all invoices and products for a customer.

---

## 6. Warranty Calculation

```
warranty_expiry_date = invoice_date + 30 months
days_remaining = warranty_expiry_date - today

Status:
  > 90 days  → Active (green)
  1-90 days  → Expiring Soon (amber)
  ≤ 0 days   → Expired (red)
```

All warranty calculations are done server-side for accuracy.

---

## 7. Deploy to Vercel

```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
vercel

# Set environment variables in Vercel dashboard:
# NEXT_PUBLIC_SUPABASE_URL
# NEXT_PUBLIC_SUPABASE_ANON_KEY
# SUPABASE_SERVICE_ROLE_KEY
# PDFCO_API_KEY
# NEXT_PUBLIC_MAKE_WEBHOOK_URL
# NEXT_PUBLIC_APP_URL
```

Or connect your GitHub repo to Vercel for automatic deployments.

---

## 8. File Structure

```
/app
  /login/page.tsx          — Login page
  /register/page.tsx       — Registration page
  /upload/page.tsx          — Invoice upload portal
  /dashboard/page.tsx       — Warranty dashboard
  /api/invoices/route.ts    — Invoice API endpoint
  layout.tsx                — Root layout with theme
  globals.css               — Global styles + CSS variables
/components
  /ui/                      — Shadcn UI components
  /dashboard/               — Sidebar, Header, Stats, InvoiceTable
  /upload/                  — FileUploader
  theme-provider.tsx
  theme-toggle.tsx
/lib
  supabase-browser.ts       — Browser Supabase client
  supabase-server.ts        — Server + Admin Supabase clients
  types.ts                  — TypeScript interfaces
  utils.ts                  — cn() utility
/utils
  warranty.ts               — Warranty calculation helpers
/database
  schema.sql                — Complete Postgres schema
middleware.ts               — Auth route protection
```

---

## 9. Features Checklist

- [x] Drag & drop PDF upload (multi-file)
- [x] File validation (PDF only, 10MB max)
- [x] Upload progress indicator
- [x] Make.com webhook integration
- [x] PDF.co invoice parsing pipeline
- [x] Supabase Auth (email/password)
- [x] JWT-protected routes via middleware
- [x] Row Level Security (customer isolation)
- [x] Invoice + product storage
- [x] Warranty expiry calculation (30 months)
- [x] Dashboard with stats cards
- [x] Bill-wise accordion grouping
- [x] Warranty status badges (Active / Expiring / Expired)
- [x] Days remaining countdown
- [x] Invoice search
- [x] Filter by warranty status
- [x] CSV export
- [x] Dark / light mode with system detection
- [x] Responsive (mobile sidebar overlay)
- [x] Multiple products per invoice support

---

## 10. Security

- Supabase Auth handles password hashing and session management
- Row Level Security ensures customers only see their own data
- Service role key is server-side only (never exposed to browser)
- Middleware redirects unauthenticated users
- API validates all inputs before database writes
- Storage policies restrict file access per user
