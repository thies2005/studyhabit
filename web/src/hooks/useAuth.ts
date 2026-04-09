import { useState, useCallback } from 'react';
import apiClient from '../api/client';

interface AuthState {
  accessToken: string | null;
  refreshToken: string | null;
}

export function useAuth() {
  const [auth, setAuth] = useState<AuthState>(() => {
    const access = localStorage.getItem('access_token');
    const refresh = localStorage.getItem('refresh_token');
    return { accessToken: access, refreshToken: refresh };
  });

  const isAuthenticated = !!auth.accessToken;

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
      await apiClient.post('/auth/logout');
    } catch {
      // Ignore errors on logout
    }
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    setAuth({ accessToken: null, refreshToken: null });
  }, []);

  return { isAuthenticated, auth, login, register, logout };
}
