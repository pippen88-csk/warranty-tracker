"use client";

import { useState } from "react";
import { ChevronDown, ChevronRight, FileText, ExternalLink, Search } from "lucide-react";
import { cn } from "@/utils/cn";
import { WarrantyBadge } from "./warranty-badge";
import { formatDate, formatDaysRemaining } from "@/utils/warranty";
import type { InvoiceWithProducts } from "@/lib/types";

interface InvoiceTableProps {
  invoices: InvoiceWithProducts[];
}

export function InvoiceTable({ invoices }: InvoiceTableProps) {
  const [expandedIds, setExpandedIds] = useState<Set<string>>(new Set());
  const [search, setSearch] = useState("");
  const [filterStatus, setFilterStatus] = useState<string>("all");

  const toggle = (id: string) => {
    setExpandedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const filtered = invoices.filter((inv) => {
    const matchesSearch =
      !search ||
      inv.invoice_number.toLowerCase().includes(search.toLowerCase()) ||
      inv.products.some(
        (p) =>
          p.product_name.toLowerCase().includes(search.toLowerCase()) ||
          p.serial_number.toLowerCase().includes(search.toLowerCase())
      );
    const matchesFilter =
      filterStatus === "all" ||
      inv.products.some((p) => p.warranty_status === filterStatus);
    return matchesSearch && matchesFilter;
  });

  return (
    <div className="space-y-4">
      {/* Search & Filter */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center gap-3">
        <div className="relative flex-1 max-w-sm w-full">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-surface-400" />
          <input
            type="text"
            placeholder="Search invoices, products, serials..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="input pl-10"
          />
        </div>
        <div className="flex items-center gap-1.5 p-1 bg-surface-100 dark:bg-surface-800 rounded-xl">
          {[
            { value: "all", label: "All" },
            { value: "active", label: "Active" },
            { value: "expiring_soon", label: "Expiring" },
            { value: "expired", label: "Expired" },
          ].map((f) => (
            <button
              key={f.value}
              onClick={() => setFilterStatus(f.value)}
              className={cn(
                "px-3 py-1.5 rounded-lg text-xs font-medium transition-all",
                filterStatus === f.value
                  ? "bg-white dark:bg-surface-700 shadow-sm text-surface-900 dark:text-surface-100"
                  : "text-surface-500 hover:text-surface-700 dark:hover:text-surface-300"
              )}
            >
              {f.label}
            </button>
          ))}
        </div>
      </div>

      {/* Table */}
      {filtered.length === 0 ? (
        <div className="card p-12 text-center">
          <FileText className="w-10 h-10 text-surface-300 dark:text-surface-600 mx-auto mb-3" />
          <p className="text-sm text-surface-500">No invoices found</p>
          <p className="text-xs text-surface-400 mt-1">
            {search ? "Try a different search term" : "Upload your first invoice to get started"}
          </p>
        </div>
      ) : (
        <div className="card overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b bg-surface-50/50 dark:bg-surface-800/50">
                  <th className="text-left text-xs font-medium text-surface-500 uppercase tracking-wider px-4 py-3 w-8" />
                  <th className="text-left text-xs font-medium text-surface-500 uppercase tracking-wider px-4 py-3">Invoice</th>
                  <th className="text-left text-xs font-medium text-surface-500 uppercase tracking-wider px-4 py-3">Date</th>
                  <th className="text-left text-xs font-medium text-surface-500 uppercase tracking-wider px-4 py-3">Products</th>
                  <th className="text-left text-xs font-medium text-surface-500 uppercase tracking-wider px-4 py-3">PDF</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {filtered.map((invoice) => {
                  const isOpen = expandedIds.has(invoice.id);
                  return (
                    <InvoiceRow key={invoice.id} invoice={invoice} isOpen={isOpen} onToggle={() => toggle(invoice.id)} />
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}

function InvoiceRow({
  invoice,
  isOpen,
  onToggle,
}: {
  invoice: InvoiceWithProducts;
  isOpen: boolean;
  onToggle: () => void;
}) {
  return (
    <>
      <tr onClick={onToggle} className="cursor-pointer hover:bg-surface-50 dark:hover:bg-surface-800/50 transition-colors">
        <td className="px-4 py-3">
          {isOpen ? <ChevronDown className="w-4 h-4 text-surface-400" /> : <ChevronRight className="w-4 h-4 text-surface-400" />}
        </td>
        <td className="px-4 py-3">
          <span className="text-sm font-semibold font-mono">{invoice.invoice_number}</span>
        </td>
        <td className="px-4 py-3 text-sm text-surface-500">{formatDate(invoice.invoice_date)}</td>
        <td className="px-4 py-3 text-sm text-surface-500">
          {invoice.products.length} product{invoice.products.length !== 1 ? "s" : ""}
        </td>
        <td className="px-4 py-3">
          {invoice.pdf_url && (
            <a href={invoice.pdf_url} target="_blank" rel="noreferrer" onClick={(e) => e.stopPropagation()} className="inline-flex items-center gap-1 text-xs text-brand-500 hover:text-brand-600">
              View <ExternalLink className="w-3 h-3" />
            </a>
          )}
        </td>
      </tr>
      {isOpen && invoice.products.map((product) => (
        <tr key={product.id} className="bg-surface-50/40 dark:bg-surface-800/30">
          <td className="px-4 py-2.5" />
          <td className="px-4 py-2.5 pl-10 text-sm">{product.product_name}</td>
          <td className="px-4 py-2.5 text-sm font-mono text-surface-500">{product.serial_number}</td>
          <td className="px-4 py-2.5">
            <div className="flex items-center gap-3">
              <WarrantyBadge status={product.warranty_status} />
              <span className="text-xs text-surface-400">{formatDaysRemaining(product.days_remaining)}</span>
            </div>
          </td>
          <td className="px-4 py-2.5 text-xs text-surface-400">Exp: {formatDate(product.warranty_expiry_date)}</td>
        </tr>
      ))}
    </>
  );
}
