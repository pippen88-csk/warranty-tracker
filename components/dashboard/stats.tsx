"use client";

import { Card, CardContent } from "@/components/ui/card";
import { FileText, Shield, AlertTriangle, XCircle } from "lucide-react";

interface StatsProps {
  totalInvoices: number;
  totalProducts: number;
  activeWarranties: number;
  expiringSoon: number;
  expired: number;
}

export function DashboardStats({ totalInvoices, totalProducts, activeWarranties, expiringSoon, expired }: StatsProps) {
  const stats = [
    { label: "Total Invoices", value: totalInvoices, icon: FileText, color: "text-blue-600 dark:text-blue-400", bg: "bg-blue-50 dark:bg-blue-950/30" },
    { label: "Active Warranties", value: activeWarranties, icon: Shield, color: "text-green-600 dark:text-green-400", bg: "bg-green-50 dark:bg-green-950/30" },
    { label: "Expiring Soon", value: expiringSoon, icon: AlertTriangle, color: "text-amber-600 dark:text-amber-400", bg: "bg-amber-50 dark:bg-amber-950/30" },
    { label: "Expired", value: expired, icon: XCircle, color: "text-red-600 dark:text-red-400", bg: "bg-red-50 dark:bg-red-950/30" },
  ];

  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      {stats.map((stat) => (
        <Card key={stat.label}>
          <CardContent className="p-5">
            <div className="flex items-center gap-3">
              <div className={`flex h-10 w-10 items-center justify-center rounded-lg ${stat.bg}`}>
                <stat.icon className={`h-5 w-5 ${stat.color}`} />
              </div>
              <div>
                <p className="text-2xl font-bold">{stat.value}</p>
                <p className="text-xs text-muted-foreground">{stat.label}</p>
              </div>
            </div>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}

