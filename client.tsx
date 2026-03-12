"use client";

import { FileUploader } from "@/components/upload/file-uploader";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { FileText, Zap, Shield } from "lucide-react";

export function UploadPageClient({ customerId }: { customerId: string }) {
  return (
    <div className="max-w-3xl mx-auto space-y-6">
      <div>
        <h2 className="text-2xl font-bold tracking-tight">Upload Invoices</h2>
        <p className="text-muted-foreground mt-1">Upload your invoice PDFs and we&apos;ll automatically extract product and warranty information.</p>
      </div>
      <Card>
        <CardHeader>
          <CardTitle className="text-lg">Invoice PDFs</CardTitle>
          <CardDescription>Drag and drop one or more PDF invoices. We&apos;ll parse them automatically.</CardDescription>
        </CardHeader>
        <CardContent>
          <FileUploader customerId={customerId} />
        </CardContent>
      </Card>
      <div className="grid gap-4 sm:grid-cols-3">
        {[
          { icon: FileText, title: "Upload PDF", desc: "Drop your invoice file and it's securely stored" },
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
