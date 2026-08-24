"use client";

/**
 * React Query provider.
 *
 * Wraps the entire app with a single QueryClient. The client is
 * created once and stored in a ref so it survives across renders.
 *
 * Errors are not retried by default to avoid double-charged API
 * calls during development.
 */

import { useState } from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";

export function QueryProvider({ children }: { children: React.ReactNode }) {
  const [client] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            retry: 1,
            staleTime: 30_000,
            refetchOnWindowFocus: false,
          },
        },
      }),
  );
  return (
    <QueryClientProvider client={client}>{children}</QueryClientProvider>
  );
}
