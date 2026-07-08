import { useState, useCallback, createContext, useContext, type ReactNode } from 'react';
import apiClient from '../api/client';

interface AuthState {
  accessToken: string | null;
  refreshToken: string | null;
}

interface AuthContextValue extends AuthState {
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
}

// Auth tokens live in localStorage (persisted across reloads). They are read
// into context once on mount so every consumer observes a single source of
// truth and login/logout broadcast consistently. See SECURITY.md for the
// localStorage-vs-httpOnly-cookie tradeoff.
const AuthContext = createContext<AuthContextValue | null>(null);

function readTokens(): AuthState {
  return {
    accessToken: localStorage.getItem('access_token'),
    refreshToken: localStorage.getItem('refresh_token'),
  };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [auth, setAuth] = useState<AuthState>(readTokens);

  const login = useCallback(async (email: string, password: string) => {
    const response = await apiClient.post('/auth/login', { email, password });
    const { accessToken, refreshToken } = response.data.data;
    localStorage.setItem('access_token', accessToken);
    localStorage.setItem('refresh_token', refreshToken);
    setAuth({ accessToken, refreshToken });
  }, []);

  const register = useCallback(async (email: string, password: string) => {
    const response = await apiClient.post('/auth/register', { email, password });
    const { accessToken, refreshToken } = response.data.data;
    localStorage.setItem('access_token', accessToken);
    localStorage.setItem('refresh_token', refreshToken);
    setAuth({ accessToken, refreshToken });
  }, []);

  const logout = useCallback(async () => {
    try {
      const { refreshToken } = readTokens();
      if (refreshToken) {
        await apiClient.post('/auth/logout', { refreshToken });
      }
    } catch {
      // Ignore errors on logout
    }
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    setAuth({ accessToken: null, refreshToken: null });
  }, []);

  const value: AuthContextValue = {
    ...auth,
    isAuthenticated: !!auth.accessToken,
    login,
    register,
    logout,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return ctx;
}
