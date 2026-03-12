"use client";

import { useState, useCallback } from "react";
import { useDropzone } from "react-dropzone";
import { createClient } from "@/lib/supabase-browser";
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
        const fileName = `${customerId}/${Date.now()}_${files[i].file.name}`;
        const { error: uploadError } = await supabase.storage.from("invoices").upload(fileName, files[i].file);
        if (uploadError) throw uploadError;

        setFiles((prev) => prev.map((f, idx) => (idx === i ? { ...f, progress: 50 } : f)));

        const { data: urlData } = supabase.storage.from("invoices").getPublicUrl(fileName);

        setFiles((prev) => prev.map((f, idx) => (idx === i ? { ...f, status: "processing", progress: 70 } : f)));

        // Trigger Make.com webhook
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
                {uploading ? (<><Loader2 className="mr-2 h-3 w-3 animate-spin" />Processing...</>) : (<><Upload className="mr-2 h-3 w-3" />Upload {pendingCount} file{pendingCount !== 1 ? "s" : ""}</>)}
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
                    <p className="text-xs text-muted-foreground">{(f.file.size / 1024 / 1024).toFixed(2)} MB{f.status === "processing" ? " — Parsing invoice..." : f.status === "done" ? " — Parsed successfully" : f.error ? ` — ${f.error}` : ""}</p>
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

