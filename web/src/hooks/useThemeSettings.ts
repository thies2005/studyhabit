import { useEffect, useState } from 'react';
import apiClient from '../api/client';
import { useAuth } from './useAuth';

export interface AppSettings {
  'theme.seedColorIndex'?: number;
  'theme.themeMode'?: number; // 0: system, 1: light, 2: dark
  [key: string]: any;
}

// Preset seeds matching the Flutter app
const PRESET_SEEDS = [
  { primary: '#85D2E0', container: '#006874' }, // Deep Teal
  { primary: '#D0BCFF', container: '#4F378B' }, // Purple
  { primary: '#9ECAFF', container: '#004A77' }, // Blue
  { primary: '#80DC89', container: '#005313' }, // Green
  { primary: '#FFB4AB', container: '#93000A' }, // Red
  { primary: '#FFB1C8', container: '#7D264A' }, // Pink
  { primary: '#FFB599', container: '#8D1500' }, // Orange
  { primary: '#E8C16C', container: '#5D4200' }, // Amber
  { primary: '#4ED8D9', container: '#004F50' }, // Cyan
  { primary: '#BFC2FF', container: '#0008A6' }, // Indigo
  { primary: '#89D6A1', container: '#00522B' }, // Emerald
  { primary: '#CCC2DC', container: '#332D41' }, // Slate
];

export function useThemeSettings() {
  const { isAuthenticated } = useAuth();
  const [settings, setSettings] = useState<AppSettings | null>(null);

  useEffect(() => {
    if (!isAuthenticated) return;

    const fetchSettings = async () => {
      try {
        const response = await apiClient.get('/settings');
        const data = response.data.data;
        setSettings(data);
        applySettings(data);
      } catch (error) {
        console.error('Failed to fetch settings:', error);
      }
    };

    fetchSettings();
  }, [isAuthenticated]);

  const applySettings = (data: AppSettings) => {
    const root = document.documentElement;

    // Apply Theme Mode (1: light, 2: dark, 0: system)
    const modeIndex = data['theme.themeMode'] ?? 0;
    if (modeIndex === 2) {
      root.classList.add('dark');
    } else if (modeIndex === 1) {
      root.classList.remove('dark');
    } else {
      // System
      if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
        root.classList.add('dark');
      } else {
        root.classList.remove('dark');
      }
    }

    // Apply Seed Color
    const seedIndex = data['theme.seedColorIndex'] ?? 0;
    const seed = PRESET_SEEDS[seedIndex] || PRESET_SEEDS[0];
    root.style.setProperty('--color-primary', seed.primary);
    root.style.setProperty('--color-primary-container', seed.container);
  };

  return { settings };
}
