import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { lazy, Suspense, Component, ReactNode, useEffect } from 'react';
import { AuthProvider, useAuth } from './hooks/useAuth';

// Lazy loaded pages
const Login = lazy(() => import('./pages/Login'));
const Register = lazy(() => import('./pages/Register'));
const Dashboard = lazy(() => import('./pages/Dashboard'));
const Subjects = lazy(() => import('./pages/Subjects'));
const SubjectDetail = lazy(() => import('./pages/SubjectDetail'));
const Stats = lazy(() => import('./pages/Stats'));
const Achievements = lazy(() => import('./pages/Achievements'));
const Settings = lazy(() => import('./pages/Settings'));
const Layout = lazy(() => import('./components/Layout'));
import { useThemeSettings } from './hooks/useThemeSettings';
import { ProjectProvider } from './contexts/ProjectContext';

// Error Boundary Component
interface ErrorBoundaryProps {
  children: ReactNode;
}

interface ErrorBoundaryState {
  hasError: boolean;
  error?: Error;
}

class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('ErrorBoundary caught an error:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen bg-background flex items-center justify-center p-4">
          <div className="bg-surfaceContainerHighest rounded-2xl p-8 max-w-md w-full shadow-lg">
            <div className="text-center mb-6">
              <span className="text-6xl mb-4 block">⚠️</span>
              <h1 className="text-2xl font-bold text-onSurface font-heading mb-2">
                Something went wrong
              </h1>
              <p className="text-sm text-gray-400 font-body">
                An unexpected error occurred. Please try refreshing the page.
              </p>
            </div>
            {this.state.error && import.meta.env.DEV && (
              <details className="mb-6">
                <summary className="text-sm text-gray-400 font-body cursor-pointer hover:text-onSurface">
                  Error details
                </summary>
                <pre className="mt-2 p-4 bg-background rounded-lg text-xs text-red-400 font-body overflow-auto max-h-32">
                  {this.state.error.toString()}
                </pre>
              </details>
            )}
            <button
              onClick={() => window.location.reload()}
              className="w-full px-4 py-3 bg-primary hover:bg-primary-container text-white rounded-lg font-medium font-body transition-colors"
            >
              Refresh Page
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}

// Loading fallback component
const LoadingFallback = () => (
  <div className="min-h-screen bg-background flex items-center justify-center">
    <div className="flex flex-col items-center gap-4">
      <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      <p className="text-sm text-gray-400 font-body">Loading...</p>
    </div>
  </div>
);

const ProtectedRoute = ({ children }: { children: ReactNode }) => {
  const { isAuthenticated } = useAuth();
  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }
  return <>{children}</>;
};

function AppShell() {
  // Apply theme settings on load
  useThemeSettings();

  // Set dark mode on mount initially as fallback,
  // but useThemeSettings will override it based on user preferences.
  useEffect(() => {
    document.documentElement.classList.add('dark');
  }, []);

  return (
    <Router>
      <Suspense fallback={<LoadingFallback />}>
        <ErrorBoundary>
          <Routes>
            <Route path="/login" element={<Login />} />
            <Route path="/register" element={<Register />} />
            <Route
              element={
                <ProtectedRoute>
                  <Suspense fallback={<LoadingFallback />}>
                    <ProjectProvider>
                      <Layout />
                    </ProjectProvider>
                  </Suspense>
                </ProtectedRoute>
              }
            >
              <Route path="/dashboard" element={<Dashboard />} />
              <Route path="/subjects" element={<Subjects />} />
              <Route path="/subjects/:subjectId" element={<SubjectDetail />} />
              <Route path="/stats" element={<Stats />} />
              <Route path="/achievements" element={<Achievements />} />
              <Route path="/settings" element={<Settings />} />
            </Route>
            <Route path="/" element={<Navigate to="/dashboard" replace />} />
            <Route path="*" element={<Navigate to="/dashboard" replace />} />
          </Routes>
        </ErrorBoundary>
      </Suspense>
    </Router>
  );
}

function App() {
  return (
    <AuthProvider>
      <AppShell />
    </AuthProvider>
  );
}

export default App;
