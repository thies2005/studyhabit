import { useEffect, useState, useCallback } from 'react';
import apiClient from './client';

export function useApi<T>(url: string, options?: { enabled?: boolean }) {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchData = useCallback(async (signal?: AbortSignal) => {
    try {
      setLoading(true);
      setError(null);
      const response = await apiClient.get<{ data: T }>(url, { signal });
      setData(response.data.data);
    } catch (err: unknown) {
      // Ignore aborts from unmounted components / superseded requests.
      if (err instanceof DOMException && err.name === 'AbortError') return;
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  }, [url]);

  useEffect(() => {
    if (options?.enabled !== false) {
      const controller = new AbortController();
      fetchData(controller.signal);
      return () => controller.abort();
    }
  }, [fetchData, options?.enabled]);

  return { data, loading, error, refetch: () => fetchData() };
}

export function useMutation<T, V>() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const mutate = useCallback(async (url: string, method: 'post' | 'patch' | 'delete', variables?: V) => {
    try {
      setLoading(true);
      setError(null);
      const response = await apiClient[method]<{ data: T }>(url, variables);
      return response.data.data;
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'An error occurred');
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  return { mutate, loading, error };
}
