import { useState, useCallback, useEffect, createContext, useContext, type ReactNode } from 'react';
import apiClient from '../api/client';

interface AuthState {
  accessToken: string | null;
  refreshToken: string | null;
  userEmail: string | null;
}

interface AuthContextValue extends AuthState {
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

function readTokens(): AuthState {
  return {
    accessToken: localStorage.getItem('access_token'),
    refreshToken: localStorage.getItem('refresh_token'),
    userEmail: localStorage.getItem('user_email'),
  };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [auth, setAuth] = useState<AuthState>(readTokens);

  useEffect(() => {
    if (auth.accessToken && !auth.userEmail) {
      apiClient.get('/auth/me')
        .then((res) => {
          const email = res.data.data?.email;
          if (email) {
            localStorage.setItem('user_email', email);
            setAuth((prev) => ({ ...prev, userEmail: email }));
          }
        })
        .catch((err) => {
          console.warn('Session check failed:', err);
        });
    }
  }, [auth.accessToken, auth.userEmail]);

  const login = useCallback(async (email: string, password: string) => {
    try {
      const response = await apiClient.post('/auth/login', { email, password });
      const { accessToken, refreshToken, user } = response.data.data;
      const finalEmail = user?.email || email;
      localStorage.setItem('access_token', accessToken);
      localStorage.setItem('refresh_token', refreshToken);
      localStorage.setItem('user_email', finalEmail);
      setAuth({ accessToken, refreshToken, userEmail: finalEmail });
    } catch (err: any) {
      const msg = err.response?.data?.message || (err instanceof Error ? err.message : 'Login failed');
      throw new Error(msg);
    }
  }, []);

  const register = useCallback(async (email: string, password: string) => {
    try {
      const response = await apiClient.post('/auth/register', { email, password });
      const data = response.data?.data;
      const accessToken = data?.accessToken;
      const refreshToken = data?.refreshToken;
      const user = data?.user;
      if (!accessToken || !refreshToken) {
        throw new Error(response.data?.message || 'Registration succeeded, but no session token was received. Please sign in.');
      }
      const finalEmail = user?.email || email;
      localStorage.setItem('access_token', accessToken);
      localStorage.setItem('refresh_token', refreshToken);
      localStorage.setItem('user_email', finalEmail);
      setAuth({ accessToken, refreshToken, userEmail: finalEmail });
    } catch (err: any) {
      if (err.response?.status === 409) {
        throw new Error(err.response?.data?.message || 'An account with this email already exists. Please sign in.');
      }
      const msg = err.response?.data?.message || (err instanceof Error ? err.message : 'Registration failed');
      throw new Error(msg);
    }
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
    localStorage.removeItem('user_email');
    setAuth({ accessToken: null, refreshToken: null, userEmail: null });
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
