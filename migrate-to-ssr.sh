#!/bin/bash
set -e
echo "============================================"
echo "  Supabase SSR Migration — Full Rewrite"
echo "============================================"
echo ""

# ─── 1. Fix package.json ───
echo "1/9  Updating package.json (replacing auth-helpers with @supabase/ssr)..."
cat > package.json << 'EOF'
{
  "name": "warranty-tracker",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "@radix-ui/react-accordion": "^1.1.2",
    "@radix-ui/react-label": "^2.0.2",
    "@radix-ui/react-progress": "^1.0.3",
    "@radix-ui/react-slot": "^1.0.2",
    "@supabase/ssr": "^0.5.2",
    "@supabase/supabase-js": "^2.47.0",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.1.0",
    "date-fns": "^3.3.0",
    "lucide-react": "^0.316.0",
    "next": "14.2.25",
    "next-themes": "^0.2.1",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-dropzone": "^14.2.3",
    "tailwind-merge": "^2.2.0"
  },
  "devDependencies": {
    "@types/node": "^20.11.0",
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "autoprefixer": "^10.4.17",
    "postcss": "^8.4.33",
    "tailwindcss": "^3.4.1",
    "tailwindcss-animate": "^1.0.7",
    "typescript": "^5.3.3"
  }
}
EOF

# ─── 2. Create new Supabase folder structure ───
echo "2/9  Creating lib/supabase/ folder..."
mkdir -p lib/supabase

# ─── 3. Browser Client ───
echo "3/9  Writing lib/supabase/client.ts (browser client)..."
cat > lib/supabase/client.ts << 'EOF'
import { createBrowserClient } from "@supabase/ssr";

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
EOF

# ─── 4. Server Client ───
echo "4/9  Writing lib/supabase/server.ts (server client)..."
cat > lib/supabase/server.ts << 'EOF'
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export async function createClient() {
  const cookieStore = cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            );
          } catch {
            // setAll was called from a Server Component.
            // This can be ignored if middleware is refreshing sessions.
          }
        },
      },
    }
  );
}
EOF

# ─── 5. Admin Client (for API routes using service_role key) ───
echo "5/9  Writing lib/supabase/admin.ts (admin/service-role client)..."
cat > lib/supabase/admin.ts << 'EOF'
import { createClient } from "@supabase/supabase-js";

export function createAdminClient() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );
}
EOF

# ─── 6. Middleware helper ───
echo "6/9  Writing lib/supabase/middleware.ts + middleware.ts..."
cat > lib/supabase/middleware.ts << 'EOF'
import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value)
          );
          supabaseResponse = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  // Refresh the auth token
  const {
    data: { user },
  } = await supabase.auth.getUser();

  // Redirect unauthenticated users away from protected routes
  const protectedPaths = ["/dashboard", "/upload"];
  const isProtected = protectedPaths.some((path) =>
    request.nextUrl.pathname.startsWith(path)
  );

  if (isProtected && !user) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("redirect", request.nextUrl.pathname);
    return NextResponse.redirect(loginUrl);
  }

  // Redirect authenticated users away from auth pages
  const authPaths = ["/login", "/register"];
  const isAuthPage = authPaths.some((path) =>
    request.nextUrl.pathname.startsWith(path)
  );

  if (isAuthPage && user) {
    return NextResponse.redirect(new URL("/dashboard", request.url));
  }

  return supabaseResponse;
}
EOF

cat > middleware.ts << 'EOF'
import { type NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/middleware";

export async function middleware(request: NextRequest) {
  return await updateSession(request);
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
EOF

# ─── 7. Remove old Supabase files ───
echo "7/9  Removing old Supabase client files..."
rm -f lib/supabase-browser.ts lib/supabase-server.ts

# ─── 8. Rewrite all pages that use Supabase ───
echo "8/9  Rewriting all pages with updated Supabase imports..."

# --- app/page.tsx ---
cat > app/page.tsx << 'EOF'
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export default async function Home() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (user) redirect("/dashboard");
  else redirect("/login");
}
EOF

# --- app/login/page.tsx ---
cat > app/login/page.tsx << 'EOF'
"use client";

import { useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Shield, Loader2 } from "lucide-react";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const router = useRouter();
  const searchParams = useSearchParams();
  const redirectTo = searchParams.get("redirect") || "/dashboard";

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) { setError(error.message); setLoading(false); return; }
    router.push(redirectTo);
    router.refresh();
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-background px-4">
      <div className="w-full max-w-md">
        <div className="flex items-center justify-center gap-3 mb-8">
          <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-primary">
            <Shield className="h-6 w-6 text-primary-foreground" />
          </div>
          <div>
            <h1 className="text-xl font-bold tracking-tight">WarrantyOS</h1>
            <p className="text-xs text-muted-foreground">Invoice & Warranty Tracker</p>
          </div>
        </div>
        <Card>
          <CardHeader className="space-y-1">
            <CardTitle className="text-xl">Sign in</CardTitle>
            <CardDescription>Enter your email and password to access your dashboard</CardDescription>
          </CardHeader>
          <form onSubmit={handleLogin}>
            <CardContent className="space-y-4">
              {error && <div className="rounded-lg bg-destructive/10 text-destructive text-sm p-3">{error}</div>}
              <div className="space-y-2">
                <Label htmlFor="email">Email</Label>
                <Input id="email" type="email" placeholder="you@company.com" value={email} onChange={(e) => setEmail(e.target.value)} required />
              </div>
              <div className="space-y-2">
                <Label htmlFor="password">Password</Label>
                <Input id="password" type="password" placeholder="Min 6 characters" value={password} onChange={(e) => setPassword(e.target.value)} required />
              </div>
            </CardContent>
            <CardFooter className="flex flex-col gap-3">
              <Button type="submit" className="w-full" disabled={loading}>
                {loading ? <><Loader2 className="mr-2 h-4 w-4 animate-spin" />Signing in...</> : "Sign in"}
              </Button>
              <p className="text-sm text-muted-foreground text-center">
                No account?{" "}
                <Link href="/register" className="text-primary hover:underline font-medium">Create one</Link>
              </p>
            </CardFooter>
          </form>
        </Card>
      </div>
    </div>
  );
}
EOF

# --- app/register/page.tsx ---
cat > app/register/page.tsx << 'EOF'
"use client";

import { useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Shield, Loader2 } from "lucide-react";

export default function RegisterPage() {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");
    if (password.length < 6) { setError("Password must be at least 6 characters"); setLoading(false); return; }
    const supabase = createClient();
    const { error } = await supabase.auth.signUp({ email, password, options: { data: { name } } });
    if (error) { setError(error.message); setLoading(false); return; }
    setSuccess(true);
    setLoading(false);
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-background px-4">
      <div className="w-full max-w-md">
        <div className="flex items-center justify-center gap-3 mb-8">
          <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-primary">
            <Shield className="h-6 w-6 text-primary-foreground" />
          </div>
          <div>
            <h1 className="text-xl font-bold tracking-tight">WarrantyOS</h1>
            <p className="text-xs text-muted-foreground">Invoice & Warranty Tracker</p>
          </div>
        </div>
        <Card>
          <CardHeader className="space-y-1">
            <CardTitle className="text-xl">Create account</CardTitle>
            <CardDescription>Enter your details to get started</CardDescription>
          </CardHeader>
          {success ? (
            <CardContent>
              <div className="rounded-lg bg-green-50 dark:bg-green-950/30 text-green-800 dark:text-green-400 text-sm p-4">
                <p className="font-medium">Check your email</p>
                <p className="mt-1">We sent a confirmation link to <strong>{email}</strong>.</p>
              </div>
              <div className="mt-4"><Link href="/login"><Button variant="outline" className="w-full">Back to sign in</Button></Link></div>
            </CardContent>
          ) : (
            <form onSubmit={handleRegister}>
              <CardContent className="space-y-4">
                {error && <div className="rounded-lg bg-destructive/10 text-destructive text-sm p-3">{error}</div>}
                <div className="space-y-2"><Label htmlFor="name">Full Name</Label><Input id="name" type="text" placeholder="Jane Smith" value={name} onChange={(e) => setName(e.target.value)} required /></div>
                <div className="space-y-2"><Label htmlFor="email">Email</Label><Input id="email" type="email" placeholder="you@company.com" value={email} onChange={(e) => setEmail(e.target.value)} required /></div>
                <div className="space-y-2"><Label htmlFor="password">Password</Label><Input id="password" type="password" placeholder="Min 6 characters" value={password} onChange={(e) => setPassword(e.target.value)} required minLength={6} /></div>
              </CardContent>
              <CardFooter className="flex flex-col gap-3">
                <Button type="submit" className="w-full" disabled={loading}>
                  {loading ? <><Loader2 className="mr-2 h-4 w-4 animate-spin" />Creating...</> : "Create account"}
                </Button>
                <p className="text-sm text-muted-foreground text-center">Already have an account? <Link href="/login" className="text-primary hover:underline font-medium">Sign in</Link></p>
              </CardFooter>
            </form>
          )}
        </Card>
      </div>
    </div>
  );
}
EOF

# --- app/dashboard/page.tsx ---
cat > app/dashboard/page.tsx << 'EOF'
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
import { Sidebar } from "@/components/dashboard/sidebar";
import { Header } from "@/components/dashboard/header";
import { DashboardStats } from "@/components/dashboard/stats";
import { InvoiceTable } from "@/components/dashboard/invoice-table";
import type { InvoiceGroup, ProductWithWarranty } from "@/lib/types";
import { differenceInDays, parseISO } from "date-fns";

export const dynamic = "force-dynamic";

export default async function DashboardPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: customer } = await supabase.from("customers").select("*").eq("auth_id", user.id).single();
  if (!customer) redirect("/login");

  const { data: invoices } = await supabase
    .from("invoices")
    .select("id, invoice_number, invoice_date, pdf_url, customer_id, products (id, product_name, serial_number, warranty_expiry_date, created_at)")
    .eq("customer_id", customer.id)
    .order("invoice_date", { ascending: false });

  const invoiceGroups: InvoiceGroup[] = (invoices || []).map((inv: any) => {
    const products: ProductWithWarranty[] = (inv.products || []).map((p: any) => {
      const daysRemaining = differenceInDays(parseISO(p.warranty_expiry_date), new Date());
      return {
        ...p,
        invoice_id: inv.id,
        days_remaining: daysRemaining,
        warranty_status: daysRemaining > 90 ? "active" : daysRemaining > 0 ? "expiring_soon" : "expired",
      };
    });
    return { invoice_id: inv.id, invoice_number: inv.invoice_number, invoice_date: inv.invoice_date, pdf_url: inv.pdf_url, products };
  });

  const allProducts = invoiceGroups.flatMap((g) => g.products);
  const stats = {
    totalInvoices: invoiceGroups.length,
    totalProducts: allProducts.length,
    activeWarranties: allProducts.filter((p) => p.warranty_status === "active").length,
    expiringSoon: allProducts.filter((p) => p.warranty_status === "expiring_soon").length,
    expired: allProducts.filter((p) => p.warranty_status === "expired").length,
  };

  return (
    <div className="flex min-h-screen">
      <Sidebar />
      <div className="flex-1 flex flex-col">
        <Header customerName={customer.name} />
        <main className="flex-1 p-6 lg:p-8 space-y-6">
          <div>
            <h2 className="text-2xl font-bold tracking-tight">Warranty Dashboard</h2>
            <p className="text-muted-foreground mt-1">Track all your product warranties in one place.</p>
          </div>
          <DashboardStats {...stats} />
          <InvoiceTable invoiceGroups={invoiceGroups} />
        </main>
      </div>
    </div>
  );
}
EOF

# --- app/upload/page.tsx ---
cat > app/upload/page.tsx << 'EOF'
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
import { Sidebar } from "@/components/dashboard/sidebar";
import { Header } from "@/components/dashboard/header";
import { UploadPageClient } from "./client";

export default async function UploadPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: customer } = await supabase.from("customers").select("*").eq("auth_id", user.id).single();
  if (!customer) redirect("/login");

  return (
    <div className="flex min-h-screen">
      <Sidebar />
      <div className="flex-1 flex flex-col">
        <Header customerName={customer.name} />
        <main className="flex-1 p-6 lg:p-8">
          <UploadPageClient customerId={customer.id} />
        </main>
      </div>
    </div>
  );
}
EOF

# --- app/upload/client.tsx (uses browser client) ---
cat > app/upload/client.tsx << 'EOF'
"use client";

import { FileUploader } from "@/components/upload/file-uploader";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { FileText, Zap, Shield } from "lucide-react";

export function UploadPageClient({ customerId }: { customerId: string }) {
  return (
    <div className="max-w-3xl mx-auto space-y-6">
      <div>
        <h2 className="text-2xl font-bold tracking-tight">Upload Invoices</h2>
        <p className="text-muted-foreground mt-1">Upload your invoice PDFs and we will automatically extract product and warranty information.</p>
      </div>
      <Card>
        <CardHeader>
          <CardTitle className="text-lg">Invoice PDFs</CardTitle>
          <CardDescription>Drag and drop one or more PDF invoices.</CardDescription>
        </CardHeader>
        <CardContent>
          <FileUploader customerId={customerId} />
        </CardContent>
      </Card>
      <div className="grid gap-4 sm:grid-cols-3">
        {[
          { icon: FileText, title: "Upload PDF", desc: "Drop your invoice file and it is securely stored" },
          { icon: Zap, title: "Auto-Parse", desc: "AI extracts invoice number, products, and serial numbers" },
          { icon: Shield, title: "Track Warranty", desc: "30-month warranty countdown starts automatically" },
        ].map((item) => (
          <div key={item.title} className="flex gap-3 p-4 rounded-lg border bg-card">
            <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-primary/10">
              <item.icon className="h-4 w-4 text-primary" />
            </div>
            <div>
              <p className="text-sm font-medium">{item.title}</p>
              <p className="text-xs text-muted-foreground mt-0.5">{item.desc}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
EOF

# --- app/api/invoices/route.ts (uses admin client) ---
cat > app/api/invoices/route.ts << 'EOF'
import { NextRequest, NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { addMonths, parseISO, format } from "date-fns";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { invoice_number, invoice_date, products, customer_id, pdf_url } = body;

    if (!invoice_number || !invoice_date || !customer_id) {
      return NextResponse.json({ error: "Missing required fields: invoice_number, invoice_date, customer_id" }, { status: 400 });
    }

    if (!products || !Array.isArray(products) || products.length === 0) {
      return NextResponse.json({ error: "products must be a non-empty array" }, { status: 400 });
    }

    for (const product of products) {
      if (!product.product_name) {
        return NextResponse.json({ error: "Each product must have a product_name" }, { status: 400 });
      }
    }

    const supabase = createAdminClient();

    const { data: customer, error: custError } = await supabase
      .from("customers").select("id").eq("id", customer_id).single();

    if (custError || !customer) {
      return NextResponse.json({ error: "Customer not found" }, { status: 404 });
    }

    const { data: invoice, error: invError } = await supabase
      .from("invoices")
      .insert({ customer_id, invoice_number, invoice_date, pdf_url: pdf_url || null, status: "parsed" })
      .select()
      .single();

    if (invError) {
      console.error("Invoice insert error:", invError);
      return NextResponse.json({ error: "Failed to create invoice" }, { status: 500 });
    }

    const parsedDate = parseISO(invoice_date);
    const productRows = products.map((p: { product_name: string; serial_number?: string }) => ({
      invoice_id: invoice.id,
      product_name: p.product_name,
      serial_number: p.serial_number || null,
      warranty_expiry_date: format(addMonths(parsedDate, 30), "yyyy-MM-dd"),
    }));

    const { data: insertedProducts, error: prodError } = await supabase
      .from("products").insert(productRows).select();

    if (prodError) {
      console.error("Product insert error:", prodError);
      await supabase.from("invoices").delete().eq("id", invoice.id);
      return NextResponse.json({ error: "Failed to create products" }, { status: 500 });
    }

    return NextResponse.json({
      message: "Invoice and products created successfully",
      invoice: { id: invoice.id, invoice_number, invoice_date, product_count: insertedProducts.length },
    }, { status: 201 });
  } catch (err: any) {
    console.error("API error:", err);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}

export async function GET(req: NextRequest) {
  try {
    const customerId = new URL(req.url).searchParams.get("customer_id");
    if (!customerId) return NextResponse.json({ error: "customer_id is required" }, { status: 400 });

    const supabase = createAdminClient();
    const { data: invoices, error } = await supabase
      .from("invoices")
      .select("id, invoice_number, invoice_date, pdf_url, status, created_at, products (id, product_name, serial_number, warranty_expiry_date)")
      .eq("customer_id", customerId)
      .order("invoice_date", { ascending: false });

    if (error) return NextResponse.json({ error: error.message }, { status: 500 });
    return NextResponse.json({ invoices });
  } catch {
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
EOF

# --- components/dashboard/sidebar.tsx (uses browser client for logout) ---
cat > components/dashboard/sidebar.tsx << 'EOF'
"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { cn } from "@/lib/utils";
import { LayoutDashboard, Upload, Shield, LogOut } from "lucide-react";
import { createClient } from "@/lib/supabase/client";

const navItems = [
  { label: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
  { label: "Upload Invoice", href: "/upload", icon: Upload },
];

export function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();

  const handleLogout = async () => {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push("/login");
    router.refresh();
  };

  return (
    <aside className="hidden lg:flex flex-col w-64 border-r bg-card min-h-screen">
      <div className="flex items-center gap-3 px-6 py-5 border-b">
        <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary">
          <Shield className="h-5 w-5 text-primary-foreground" />
        </div>
        <div>
          <h1 className="text-base font-bold tracking-tight">WarrantyOS</h1>
          <p className="text-[11px] text-muted-foreground">Invoice Tracker</p>
        </div>
      </div>
      <nav className="flex-1 px-3 py-4 space-y-1">
        {navItems.map((item) => {
          const isActive = pathname === item.href;
          return (
            <Link key={item.href} href={item.href} className={cn("flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors", isActive ? "bg-primary/10 text-primary" : "text-muted-foreground hover:bg-accent hover:text-accent-foreground")}>
              <item.icon className="h-4 w-4" />
              {item.label}
            </Link>
          );
        })}
      </nav>
      <div className="border-t px-3 py-4">
        <button onClick={handleLogout} className="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-muted-foreground hover:bg-accent hover:text-accent-foreground transition-colors">
          <LogOut className="h-4 w-4" />
          Sign Out
        </button>
      </div>
    </aside>
  );
}
EOF

# --- components/upload/file-uploader.tsx (uses browser client for storage) ---
cat > components/upload/file-uploader.tsx << 'EOF'
"use client";

import { useState, useCallback } from "react";
import { useDropzone } from "react-dropzone";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { Upload, FileText, CheckCircle2, XCircle, Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";

interface UploadFile {
  file: File;
  status: "pending" | "uploading" | "processing" | "done" | "error";
  progress: number;
  error?: string;
}

export function FileUploader({ customerId }: { customerId: string }) {
  const [files, setFiles] = useState<UploadFile[]>([]);
  const [uploading, setUploading] = useState(false);

  const onDrop = useCallback((acceptedFiles: File[]) => {
    const newFiles = acceptedFiles
      .filter((f) => f.type === "application/pdf" && f.size <= 10 * 1024 * 1024)
      .map((file) => ({ file, status: "pending" as const, progress: 0 }));
    setFiles((prev) => [...prev, ...newFiles]);
  }, []);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: { "application/pdf": [".pdf"] },
    maxSize: 10 * 1024 * 1024,
    multiple: true,
  });

  const uploadFiles = async () => {
    setUploading(true);
    const supabase = createClient();

    for (let i = 0; i < files.length; i++) {
      if (files[i].status !== "pending") continue;

      setFiles((prev) => prev.map((f, idx) => (idx === i ? { ...f, status: "uploading", progress: 20 } : f)));

      try {
        const fileName = customerId + "/" + Date.now() + "_" + files[i].file.name;
        const { error: uploadError } = await supabase.storage.from("invoices").upload(fileName, files[i].file);
        if (uploadError) throw uploadError;

        setFiles((prev) => prev.map((f, idx) => (idx === i ? { ...f, progress: 50 } : f)));

        const { data: urlData } = supabase.storage.from("invoices").getPublicUrl(fileName);

        setFiles((prev) => prev.map((f, idx) => (idx === i ? { ...f, status: "processing", progress: 70 } : f)));

        const webhookUrl = process.env.NEXT_PUBLIC_MAKE_WEBHOOK_URL;
        if (webhookUrl) {
          await fetch(webhookUrl, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ file_url: urlData.publicUrl, customer_id: customerId }),
          });
        }

        setFiles((prev) => prev.map((f, idx) => (idx === i ? { ...f, status: "done", progress: 100 } : f)));
      } catch (err: any) {
        setFiles((prev) => prev.map((f, idx) => idx === i ? { ...f, status: "error", error: err.message || "Upload failed" } : f));
      }
    }
    setUploading(false);
  };

  const removeFile = (index: number) => setFiles((prev) => prev.filter((_, i) => i !== index));
  const pendingCount = files.filter((f) => f.status === "pending").length;

  return (
    <div className="space-y-6">
      <div {...getRootProps()} className={cn("relative border-2 border-dashed rounded-xl p-12 text-center cursor-pointer transition-all", isDragActive ? "border-primary bg-primary/5" : "border-border hover:border-primary/50 hover:bg-accent/50")}>
        <input {...getInputProps()} />
        <div className="flex flex-col items-center gap-3">
          <div className={cn("flex h-14 w-14 items-center justify-center rounded-full transition-colors", isDragActive ? "bg-primary/10" : "bg-muted")}>
            <Upload className={cn("h-6 w-6 transition-colors", isDragActive ? "text-primary" : "text-muted-foreground")} />
          </div>
          <div>
            <p className="text-base font-medium">{isDragActive ? "Drop your invoices here" : "Drag & drop invoice PDFs"}</p>
            <p className="text-sm text-muted-foreground mt-1">or click to browse — PDF only, max 10MB each</p>
          </div>
        </div>
      </div>
      {files.length > 0 && (
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-medium">{files.length} file{files.length !== 1 ? "s" : ""} selected</h3>
            {pendingCount > 0 && (
              <Button onClick={uploadFiles} disabled={uploading} size="sm">
                {uploading ? <><Loader2 className="mr-2 h-3 w-3 animate-spin" />Processing...</> : <><Upload className="mr-2 h-3 w-3" />Upload {pendingCount} file{pendingCount !== 1 ? "s" : ""}</>}
              </Button>
            )}
          </div>
          {files.map((f, i) => (
            <Card key={i} className="overflow-hidden">
              <CardContent className="p-4">
                <div className="flex items-center gap-3">
                  <div className={cn("flex h-10 w-10 shrink-0 items-center justify-center rounded-lg", f.status === "done" ? "bg-green-50 dark:bg-green-950/30" : f.status === "error" ? "bg-red-50 dark:bg-red-950/30" : "bg-muted")}>
                    {f.status === "done" ? <CheckCircle2 className="h-5 w-5 text-green-600 dark:text-green-400" /> : f.status === "error" ? <XCircle className="h-5 w-5 text-red-600 dark:text-red-400" /> : (f.status === "uploading" || f.status === "processing") ? <Loader2 className="h-5 w-5 text-primary animate-spin" /> : <FileText className="h-5 w-5 text-muted-foreground" />}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium truncate">{f.file.name}</p>
                    <p className="text-xs text-muted-foreground">{(f.file.size / 1024 / 1024).toFixed(2)} MB{f.status === "processing" ? " — Parsing invoice..." : f.status === "done" ? " — Parsed successfully" : f.error ? " — " + f.error : ""}</p>
                    {(f.status === "uploading" || f.status === "processing") && <Progress value={f.progress} className="h-1.5 mt-2" />}
                  </div>
                  {f.status === "pending" && <Button variant="ghost" size="sm" onClick={() => removeFile(i)} className="text-muted-foreground">Remove</Button>}
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
EOF

# ─── 9. Reinstall packages ───
echo "9/9  Reinstalling packages..."
rm -rf node_modules package-lock.json
npm install

echo ""
echo "============================================"
echo "  Migration complete! Testing build..."
echo "============================================"
echo ""
npx next build
