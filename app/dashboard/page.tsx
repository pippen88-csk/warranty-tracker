import { redirect } from "next/navigation";
import { createServerSupabase } from "@/lib/supabase-server";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { StatsCards } from "@/components/dashboard/stats-cards";
import { InvoiceTable } from "@/components/dashboard/invoice-table";
import { enrichProduct } from "@/utils/warranty";
import type { InvoiceWithProducts, Invoice, Product } from "@/lib/types";
import Link from "next/link";
import { Upload } from "lucide-react";

export const dynamic = "force-dynamic";

async function getInvoicesWithProducts(userId: string): Promise<InvoiceWithProducts[]> {
  const supabase = createServerSupabase();

  const { data: invoices, error: invError } = await supabase
    .from("invoices")
    .select("*")
    .eq("customer_id", userId)
    .order("invoice_date", { ascending: false });

  if (invError || !invoices) return [];

  const invoiceIds = invoices.map((inv: Invoice) => inv.id);
  if (invoiceIds.length === 0) return [];

  const { data: products, error: prodError } = await supabase
    .from("products")
    .select("*")
    .in("invoice_id", invoiceIds);

  if (prodError) return [];

  const productsByInvoice = (products || []).reduce(
    (acc: Record<string, Product[]>, product: Product) => {
      if (!acc[product.invoice_id]) acc[product.invoice_id] = [];
      acc[product.invoice_id].push(product);
      return acc;
    },
    {} as Record<string, Product[]>
  );

  return invoices.map((invoice: Invoice) => ({
    ...invoice,
    products: (productsByInvoice[invoice.id] || []).map(enrichProduct),
  }));
}

export default async function DashboardPage() {
  const supabase = createServerSupabase();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const invoices = await getInvoicesWithProducts(user.id);

  return (
    <DashboardShell title="Warranty Dashboard">
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-lg font-semibold">Overview</h2>
            <p className="text-sm text-surface-500 mt-0.5">Track all your product warranties in one place</p>
          </div>
          <Link href="/upload" className="btn-primary">
            <Upload className="w-4 h-4" /> Upload Invoice
          </Link>
        </div>
        <StatsCards invoices={invoices} />
        <InvoiceTable invoices={invoices} />
      </div>
    </DashboardShell>
  );
}

