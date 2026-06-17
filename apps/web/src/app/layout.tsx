import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "2IGV Reviewer",
  description: "Human-led, AI-assisted systematic review workspace"
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
