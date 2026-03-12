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
