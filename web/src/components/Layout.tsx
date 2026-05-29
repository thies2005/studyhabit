import { Outlet, Link, useNavigate, useLocation } from 'react-router-dom';
import { useState } from 'react';
import { useAuth } from '../hooks/useAuth';
import ProjectSwitcher from './ProjectSwitcher';

export default function Layout() {
  const navigate = useNavigate();
  const location = useLocation();
  const { logout } = useAuth();
  const [isSidebarOpen, setSidebarOpen] = useState(false);


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
        className="md:hidden fixed top-4 left-4 z-50 p-2 bg-surfaceContainerHighest rounded-lg text-onSurface"
        onClick={() => setSidebarOpen(!isSidebarOpen)}
      >
        <span className="material-symbols-rounded">menu</span>
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
          w-72 bg-surfaceContainer border-r border-surfaceContainerHigh
          transform transition-transform duration-300 ease-in-out
          ${isSidebarOpen ? 'translate-x-0' : '-translate-x-full'} md:translate-x-0
          flex flex-col rounded-r-3xl md:rounded-none shadow-2xl md:shadow-none
        `}
      >
        {/* Logo Section */}
        <div className="p-8 border-b border-surfaceContainerHigh">
          <div className="flex items-center space-x-3">
            <span className="text-4xl text-primary material-symbols-rounded">school</span>
            <h1 className="text-2xl font-bold text-onSurface font-heading tracking-tight">Studyhabit</h1>
          </div>
        </div>


        {/* Navigation Items */}
        <nav className="flex-1 p-6 space-y-2 overflow-y-auto">
          {navItems.map((item) => {
            const isActive = location.pathname.startsWith(item.to);
            return (
              <Link
                key={item.to}
                to={item.to}
                onClick={() => setSidebarOpen(false)}
                className={`flex items-center space-x-4 px-5 py-4 rounded-full font-heading font-medium transition-all duration-300 ${
                  isActive
                    ? 'bg-primary-container text-primary-onContainer shadow-md'
                    : 'text-onSurfaceVariant hover:bg-surfaceContainerHigh hover:text-onSurface'
                }`}
              >
                <span className="material-symbols-rounded text-2xl">{item.icon}</span>
                <span>{item.label}</span>
              </Link>
            );
          })}
        </nav>

        {/* Bottom Actions */}
        <div className="p-6 border-t border-surfaceContainerHigh space-y-2">
          {/* Settings */}
          <Link
            to="/settings"
            onClick={() => setSidebarOpen(false)}
            className="flex items-center space-x-4 px-5 py-4 rounded-full text-onSurfaceVariant hover:bg-surfaceContainerHigh hover:text-onSurface transition-all duration-300 font-heading font-medium"
          >
            <span className="material-symbols-rounded text-2xl">settings</span>
            <span className="font-medium">Settings</span>
          </Link>

          {/* Log Out */}
          <button
            onClick={handleLogout}
            className="w-full flex items-center space-x-4 px-5 py-4 rounded-full text-error hover:bg-error-container/20 transition-all duration-300 font-heading font-medium"
          >
            <span className="material-symbols-rounded text-2xl">logout</span>
            <span className="font-medium">Log Out</span>
          </button>
        </div>
      </aside>

      {/* Main Content Area */}
      <main className="flex-1 flex flex-col min-h-screen bg-background">
        {/* Top Bar */}
        <header className="glass sticky top-0 z-30 px-4 md:px-8 py-4 md:py-5 border-b border-surfaceContainerHigh">
          <div className="flex items-center justify-between">
            <div className="flex-1 ml-12 md:ml-0">
              <ProjectSwitcher />
            </div>

            <div className="flex items-center space-x-2 sm:space-x-4 md:space-x-6">
              {/* Notifications */}
              <button className="relative p-2 text-onSurfaceVariant hover:bg-surfaceContainerHigh hover:text-onSurface rounded-full transition-all duration-300">
                <span className="material-symbols-rounded text-2xl">notifications</span>
                <span className="absolute top-1 right-1 w-2.5 h-2.5 bg-error rounded-full border-2 border-background"></span>
              </button>

              {/* Timer */}
              <button className="hidden sm:block p-2 text-onSurfaceVariant hover:bg-surfaceContainerHigh hover:text-onSurface rounded-full transition-all duration-300">
                <span className="material-symbols-rounded text-2xl">timer</span>
              </button>

              {/* Start Session Button */}
              <button className="flex items-center space-x-2 px-4 sm:px-6 py-2 sm:py-3 bg-primary hover:bg-primary-container text-background hover:text-primary-onContainer rounded-full font-heading font-bold transition-all duration-300 hover:scale-105 active:scale-95 shadow-lg hover:shadow-primary/20">
                <span className="material-symbols-rounded text-xl">play_arrow</span>
                <span className="hidden sm:inline">Start</span>
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
