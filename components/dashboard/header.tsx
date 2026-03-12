"use client";

import { ThemeToggle } from "@/components/theme-toggle";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Search, Bell, Menu, Shield } from "lucide-react";
import { useState } from "react";
import { Sidebar } from "./sidebar";

interface HeaderProps {
  customerName?: string;
}

export function Header({ customerName }: HeaderProps) {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  return (
    <>
      <header className="sticky top-0 z-40 flex h-16 items-center gap-4 border-b bg-card/80 backdrop-blur-sm px-6">
        <Button variant="ghost" size="icon" className="lg:hidden" onClick={() => setMobileMenuOpen(!mobileMenuOpen)}>
          <Menu className="h-5 w-5" />
        </Button>
        <div className="flex items-center gap-2 lg:hidden">
          <Shield className="h-5 w-5 text-primary" />
          <span className="font-bold text-sm">WarrantyOS</span>
        </div>
        <div className="flex-1 max-w-md hidden sm:block">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input placeholder="Search invoices, products..." className="pl-9 h-9 bg-background" />
          </div>
        </div>
        <div className="flex items-center gap-2 ml-auto">
          <Button variant="ghost" size="icon" className="relative h-9 w-9">
            <Bell className="h-4 w-4" />
            <span className="absolute top-1.5 right-1.5 h-2 w-2 bg-destructive rounded-full" />
          </Button>
          <ThemeToggle />
          {customerName && (
            <div className="hidden sm:flex items-center gap-2 pl-2 border-l ml-1">
              <div className="h-8 w-8 rounded-full bg-primary/10 flex items-center justify-center">
                <span className="text-xs font-bold text-primary">{customerName.charAt(0).toUpperCase()}</span>
              </div>
              <span className="text-sm font-medium">{customerName}</span>
            </div>
          )}
        </div>
      </header>
      {mobileMenuOpen && (
        <div className="fixed inset-0 z-50 lg:hidden">
          <div className="fixed inset-0 bg-black/50" onClick={() => setMobileMenuOpen(false)} />
          <div className="fixed left-0 top-0 bottom-0 w-64 bg-card z-50"><Sidebar /></div>
        </div>
      )}
    </>
  );
}

