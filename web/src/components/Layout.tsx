import { Outlet, Link, useNavigate, useLocation } from 'react-router-dom';
import { useState } from 'react';
import { useAuth } from '../hooks/useAuth';
import ProjectSwitcher from './ProjectSwitcher';

export default function Layout() {
  const navigate = useNavigate();
  const location = useLocation();
  const { logout } = useAuth();
  const [isSidebarOpen, setSidebarOpen] = useState(false);
  const [deepWorkMode, setDeepWorkMode] = useState(false);

  const handleLogout = async () => {
    await logout();
    navigate('/login');
  };

  const navItems = [
    { to: '/dashboard', label: 'Home', icon: 'home' },
    { to: '/subjects', label: 'Subjects', icon: 'library_books' },
    { to: '/stats', label: 'Stats', icon: 'monitoring' },
    { to: '/achievements', label: 'Achievements', icon: 'emoji_events' },
  ];

  return (
    <div className="min-h-screen bg-background flex">
      {/* Mobile Menu Button */}
      <button
        className="md:hidden fixed top-4 left-4 z-50 p-2 bg-surfaceHigh rounded-lg text-onSurface"
        onClick={() => setSidebarOpen(!isSidebarOpen)}
      >
        <span className="material-icons">menu</span>
      </button>

      {/* Mobile Overlay */}
      {isSidebarOpen && (
        <div
          className="md:hidden fixed inset-0 bg-black/50 z-40"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Left Sidebar */}
      <aside
        className={`
          fixed md:static inset-y-0 left-0 z-40
          w-64 bg-background border-r border-surfaceHigh
          transform transition-transform duration-300 ease-in-out
          ${isSidebarOpen ? 'translate-x-0' : '-translate-x-full'} md:translate-x-0
          flex flex-col
        `}
      >
        {/* Logo Section */}
        <div className="p-6 border-b border-surfaceHigh">
          <div className="flex items-center space-x-3">
            <span className="text-3xl">📚</span>
            <h1 className="text-xl font-bold text-onSurface font-heading">Study Sanctuary</h1>
          </div>
        </div>

        {/* Deep Work Mode Toggle */}
        <div className="p-4 border-b border-surfaceHigh">
          <div className="flex items-center justify-between">
            <span className="text-sm text-onSurface font-body">Deep Work Mode</span>
            <button
              onClick={() => setDeepWorkMode(!deepWorkMode)}
              className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                deepWorkMode ? 'bg-primary' : 'bg-gray-600'
              }`}
            >
              <span
                className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                  deepWorkMode ? 'translate-x-6' : 'translate-x-1'
                }`}
              />
            </button>
          </div>
        </div>

        {/* Navigation Items */}
        <nav className="flex-1 p-4 space-y-2 overflow-y-auto">
          {navItems.map((item) => {
            const isActive = location.pathname.startsWith(item.to);
            return (
              <Link
                key={item.to}
                to={item.to}
                onClick={() => setSidebarOpen(false)}
                className={`flex items-center space-x-3 px-4 py-3 rounded-lg font-body transition-colors ${
                  isActive
                    ? 'bg-primary text-background'
                    : 'text-onSurface hover:bg-surfaceHigh'
                }`}
              >
                <span className="material-icons">{item.icon}</span>
                <span className="font-medium">{item.label}</span>
              </Link>
            );
          })}
        </nav>

        {/* Bottom Actions */}
        <div className="p-4 border-t border-surfaceHigh space-y-2">
          {/* Settings */}
          <Link
            to="/settings"
            onClick={() => setSidebarOpen(false)}
            className="flex items-center space-x-3 px-4 py-3 rounded-lg text-onSurface hover:bg-surfaceHigh transition-colors font-body"
          >
            <span className="material-icons">settings</span>
            <span className="font-medium">Settings</span>
          </Link>

          {/* Log Out */}
          <button
            onClick={handleLogout}
            className="w-full flex items-center space-x-3 px-4 py-3 rounded-lg text-red-400 hover:bg-red-500/10 transition-colors font-body"
          >
            <span className="material-icons">logout</span>
            <span className="font-medium">Log Out</span>
          </button>
        </div>
      </aside>

      {/* Main Content Area */}
      <main className="flex-1 flex flex-col min-h-screen bg-surface">
        {/* Top Bar */}
        <header className="bg-surfaceHigh border-b border-surfaceHigh px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex-1">
              <ProjectSwitcher />
            </div>

            <div className="flex items-center space-x-4">
              {/* Notifications */}
              <button className="p-2 text-onSurface hover:bg-background rounded-lg transition-colors relative">
                <span className="material-icons">notifications</span>
                <span className="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full"></span>
              </button>

              {/* Timer */}
              <button className="p-2 text-onSurface hover:bg-background rounded-lg transition-colors">
                <span className="material-icons">timer</span>
              </button>

              {/* Start Session Button */}
              <button className="flex items-center space-x-2 px-4 py-2 bg-primary hover:bg-primary-container text-white rounded-lg font-medium transition-colors font-body">
                <span className="material-icons">play_arrow</span>
                <span>Start Session</span>
              </button>
            </div>
          </div>
        </header>

        {/* Page Content */}
        <div className="flex-1 overflow-auto">
          <Outlet />
        </div>
      </main>
    </div>
  );
}
