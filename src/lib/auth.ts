"use client";

/**
 * Auth state store.
 *
 * Holds the current user profile and exposes login/register/logout
 * actions that wrap the underlying API client. Token storage is
 * delegated to api.ts (localStorage).
 */

import { create } from "zustand";
import { api, setToken, type UserInfo } from "./api";

interface AuthState {
  user: UserInfo | null;
  loading: boolean;
  error: string | null;
  init: () => Promise<void>;
  login: (identifier: string, password: string) => Promise<boolean>;
  register: (
    username: string,
    email: string,
    password: string,
  ) => Promise<boolean>;
  logout: () => Promise<void>;
  refresh: () => Promise<void>;
}

export const useAuth = create<AuthState>((set) => ({
  user: null,
  loading: false,
  error: null,
  init: async () => {
    const token =
      typeof window !== "undefined" ? localStorage.getItem("zv_token") : null;
    if (!token) {
      set({ user: null });
      return;
    }
    try {
      const u = await api.me();
      set({ user: u });
    } catch {
      setToken(null);
      set({ user: null });
    }
  },
  login: async (identifier, password) => {
    set({ loading: true, error: null });
    try {
      const res = await api.login({ identifier, password });
      if (res.token) {
        setToken(res.token);
        const u = await api.me();
        set({ user: u, loading: false });
        return true;
      }
      set({
        loading: false,
        error: res.message ?? "登录失败，请检查凭据",
      });
      return false;
    } catch (e) {
      set({
        loading: false,
        error: e instanceof Error ? e.message : "登录失败",
      });
      return false;
    }
  },
  register: async (username, email, password) => {
    set({ loading: true, error: null });
    try {
      const res = await api.register({ username, email, password });
      if (res.token) {
        setToken(res.token);
        const u = await api.me();
        set({ user: u, loading: false });
        return true;
      }
      set({
        loading: false,
        error: res.message ?? "注册失败，请稍后重试",
      });
      return false;
    } catch (e) {
      set({
        loading: false,
        error: e instanceof Error ? e.message : "注册失败",
      });
      return false;
    }
  },
  logout: async () => {
    try {
      await api.logout();
    } catch {
      // ignore - token will be cleared locally anyway
    }
    setToken(null);
    set({ user: null });
  },
  refresh: async () => {
    try {
      const u = await api.me();
      set({ user: u });
    } catch {
      set({ user: null });
    }
  },
}));
