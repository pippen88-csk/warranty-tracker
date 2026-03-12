#!/bin/bash
set -e
echo "Fixing 3 broken files..."

echo "  1/3 Fixing components/dashboard/invoice-table.tsx..."
cat > components/dashboard/invoice-table.tsx << 'ENDFILE'
"use client";

import { useState } from "react";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { InvoiceGroup } from "@/lib/types";
import { formatDate } from "@/utils/warranty";
import { Search, Download, FileText, ExternalLink } from "lucide-react";
import { cn } from "@/lib/utils";

type FilterType = "all" | "active" | "expiring_soon" | "expired";

export function InvoiceTable({ invoiceGroups }: { invoiceGroups: InvoiceGroup[] }) {
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState<FilterType>("all");

  const filtered = invoiceGroups
    .map((group) => {
      const matchedProducts = group.products.filter((p) => {
        const matchesSearch = !search ||
          p.product_name.toLowerCase().includes(search.toLowerCase()) ||
          p.serial_number?.toLowerCase().includes(search.toLowerCase()) ||
          group.invoice_number.toLowerCase().includes(search.toLowerCase());
        const matchesFilter = filter === "all" || p.warranty_status === filter;
        return matchesSearch && matchesFilter;
      });
      if (matchedProducts.length === 0) return null;
      return { ...group, products: matchedProducts };
    })
    .filter(Boolean) as InvoiceGroup[];

  const exportCSV = () => {
    const headers = ["Invoice Number", "Invoice Date", "Product Name", "Serial Number", "Warranty Expiry", "Days Remaining", "Status"];
    const rows = invoiceGroups.flatMap((g) =>
      g.products.map((p) => [g.invoice_number, g.invoice_date, p.product_name, p.serial_number || "", p.warranty_expiry_date, p.days_remaining.toString(), p.warranty_status])
    );
    const csv = [headers, ...rows].map((r) => r.join(",")).join("\n");
    const blob = new Blob([csv], { type: "text/csv" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "warranties_" + new Date().toISOString().split("T")[0] + ".csv";
    a.click();
    URL.revokeObjectURL(url);
  };

  const badgeVariant = (s: string) => s === "active" ? "active" as const : s === "expiring_soon" ? "expiring" as const : "expired" as const;
  const statusLabel = (s: string) => s === "active" ? "Active" : s === "expiring_soon" ? "Expiring Soon" : "Expired";
  const daysColor = (s: string) => s === "active" ? "text-green-600 dark:text-green-400" : s === "expiring_soon" ? "text-amber-600 dark:text-amber-400" : "text-red-600 dark:text-red-400";

  return (
    <Card>
      <CardHeader>
        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <CardTitle className="text-lg">Your Invoices</CardTitle>
          <div className="flex items-center gap-2">
            <div className="relative flex-1 sm:w-64">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <Input placeholder="Search invoices..." className="pl-9 h-9" value={search} onChange={(e) => setSearch(e.target.value)} />
            </div>
            <Button variant="outline" size="sm" onClick={exportCSV}>
              <Download className="h-3.5 w-3.5 mr-1.5" />CSV
            </Button>
          </div>
        </div>
        <div className="flex gap-1 mt-2">
          {(["all", "active", "expiring_soon", "expired"] as FilterType[]).map((f) => (
            <Button key={f} variant={filter === f ? "default" : "ghost"} size="sm" className="text-xs h-7" onClick={() => setFilter(f)}>
              {f === "all" ? "All" : f === "active" ? "Active" : f === "expiring_soon" ? "Expiring" : "Expired"}
            </Button>
          ))}
        </div>
      </CardHeader>
      <CardContent>
        {filtered.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-12 text-center">
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-muted">
              <FileText className="h-6 w-6 text-muted-foreground" />
            </div>
            <p className="mt-3 text-sm font-medium">No invoices found</p>
            <p className="text-xs text-muted-foreground mt-1">
              {search || filter !== "all" ? "Try adjusting your search or filters" : "Upload your first invoice to get started"}
            </p>
          </div>
        ) : (
          <Accordion type="multiple" className="w-full">
            {filtered.map((group) => (
              <AccordionItem key={group.invoice_id} value={group.invoice_id}>
                <AccordionTrigger className="hover:no-underline py-3">
                  <div className="flex items-center gap-3 text-left">
                    <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-muted">
                      <FileText className="h-4 w-4 text-muted-foreground" />
                    </div>
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-semibold text-sm">{group.invoice_number}</span>
                        <span className="text-xs text-muted-foreground">{group.products.length} product{group.products.length !== 1 ? "s" : ""}</span>
                      </div>
                      <p className="text-xs text-muted-foreground">{formatDate(group.invoice_date)}</p>
                    </div>
                  </div>
                </AccordionTrigger>
                <AccordionContent>
                  <div className="rounded-lg border overflow-hidden">
                    <div className="hidden sm:grid grid-cols-12 gap-2 px-4 py-2.5 bg-muted/50 text-xs font-medium text-muted-foreground">
                      <div className="col-span-3">Product</div>
                      <div className="col-span-2">Serial No.</div>
                      <div className="col-span-2">Warranty Expiry</div>
                      <div className="col-span-2">Days Left</div>
                      <div className="col-span-2">Status</div>
                      <div className="col-span-1"></div>
                    </div>
                    {group.products.map((product, idx) => (
                      <div key={product.id} className={cn("grid grid-cols-1 sm:grid-cols-12 gap-2 px-4 py-3 text-sm items-center", idx !== group.products.length - 1 && "border-b")}>
                        <div className="col-span-3 font-medium">{product.product_name}</div>
                        <div className="col-span-2 text-muted-foreground font-mono text-xs">{product.serial_number || "\u2014"}</div>
                        <div className="col-span-2 text-muted-foreground">{formatDate(product.warranty_expiry_date)}</div>
                        <div className="col-span-2">
                          <span className={cn("font-semibold tabular-nums", daysColor(product.warranty_status))}>
                            {product.days_remaining > 0 ? product.days_remaining + " days" : "Expired"}
                          </span>
                        </div>
                        <div className="col-span-2">
                          <Badge variant={badgeVariant(product.warranty_status)}>{statusLabel(product.warranty_status)}</Badge>
                        </div>
                        <div className="col-span-1 flex justify-end">
                          {group.pdf_url && (
                            <a href={group.pdf_url} target="_blank" rel="noopener noreferrer">
                              <Button variant="ghost" size="icon" className="h-7 w-7"><ExternalLink className="h-3 w-3" /></Button>
                            </a>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                </AccordionContent>
              </AccordionItem>
            ))}
          </Accordion>
        )}
      </CardContent>
    </Card>
  );
}
ENDFILE

echo "  2/3 Fixing app/api/invoices/route.ts..."
cat > app/api/invoices/route.ts << 'ENDFILE'
import { NextRequest, NextResponse } from "next/server";
import { createAdminSupabase } from "@/lib/supabase-server";
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

    const supabase = createAdminSupabase();

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

    const supabase = createAdminSupabase();
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
ENDFILE

echo "  3/3 Fixing app/dashboard/page.tsx..."
cat > app/dashboard/page.tsx << 'ENDFILE'
import { createServerSupabase } from "@/lib/supabase-server";
import { redirect } from "next/navigation";
import { Sidebar } from "@/components/dashboard/sidebar";
import { Header } from "@/components/dashboard/header";
import { DashboardStats } from "@/components/dashboard/stats";
import { InvoiceTable } from "@/components/dashboard/invoice-table";
import type { InvoiceGroup, ProductWithWarranty } from "@/lib/types";
import { differenceInDays, parseISO } from "date-fns";

export const dynamic = "force-dynamic";

export default async function DashboardPage() {
  const supabase = createServerSupabase();
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) redirect("/login");

  const { data: customer } = await supabase.from("customers").select("*").eq("auth_id", session.user.id).single();
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
ENDFILE

echo ""
echo "All 3 files fixed!"
echo ""
echo "Now run:"
echo "  git add ."
echo '  git commit -m "Fix broken imports"'
echo "  git push"
