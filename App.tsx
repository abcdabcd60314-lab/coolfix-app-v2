import React, { useEffect, useState } from 'react';
import { HashRouter as Router, Routes, Route, Outlet, useLocation } from 'react-router-dom';
import { supabase } from './lib/supabase';
import { motion, AnimatePresence } from 'motion/react';
import { Header } from './components/layout/Header';
import { BottomNav } from './components/layout/BottomNav';
import { AdminLayout } from './components/layout/AdminLayout';

// Pages - Customer
import LandingPage from './pages/LandingPage';
import LoginPage from './pages/LoginPage';
import NewOrderPage from './pages/NewOrderPage';
import DiagnosisPage from './pages/DiagnosisPage';
import SchedulePage from './pages/SchedulePage';
import ConfirmPage from './pages/ConfirmPage';
import OrdersPage from './pages/OrdersPage';
import OrderDetailPage from './pages/OrderDetailPage';
import PaymentPage from './pages/PaymentPage';
import ReviewPage from './pages/ReviewPage';
import ProfilePage from './pages/ProfilePage';

// Pages - Admin
import AdminDashboard from './pages/AdminDashboard';
import AdminOrders from './pages/AdminOrders';
import AdminTechnicians from './pages/AdminTechnicians';
import AdminServicesPage from './pages/AdminServicesPage';
import AdminReportsPage from './pages/AdminReportsPage';

// Pages - Technician
import TechTodayPage from './pages/TechnicianTodayPage';
import TechJobDetailPage from './pages/TechJobDetailPage';
import TechJobCompletePage from './pages/TechJobCompletePage';

function CustomerLayout() {
  const location = useLocation();
  return (
    <>
      <Header />
      <main className="pb-24">
        <AnimatePresence mode="wait">
          <motion.div
            key={location.pathname}
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            transition={{ duration: 0.2 }}
          >
            <Outlet />
          </motion.div>
        </AnimatePresence>
      </main>
      <BottomNav />
    </>
  );
}

export default function App() {
  const [toast, setToast] = useState<{message: string, visible: boolean}>({ message: '', visible: false });

  useEffect(() => {
    const channel = supabase.channel('public-orders')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, () => {
        setToast({ message: '系統收到新訂單或狀態已更新！', visible: true });
        setTimeout(() => setToast({ message: '', visible: false }), 4000);
      })
      .subscribe();
      
    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  return (
    <Router>
      <AnimatePresence>
        {toast.visible && (
          <motion.div 
            initial={{ opacity: 0, y: -50 }}
            animate={{ opacity: 1, y: 20 }}
            exit={{ opacity: 0, y: -50 }}
            className="fixed top-0 left-0 right-0 z-[9999] flex justify-center pointer-events-none"
          >
            <div className="bg-brand-primary text-white px-6 py-3 rounded-full shadow-2xl font-bold flex items-center gap-2">
              <span className="w-2 h-2 bg-green-400 rounded-full animate-pulse" />
              {toast.message}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
      <Routes>
        {/* Auth */}
        <Route path="/login" element={<LoginPage />} />
        
        {/* Customer Flow */}
        <Route element={<CustomerLayout />}>
          <Route path="/" element={<LandingPage />} />
          <Route path="/new-order" element={<NewOrderPage />} />
          <Route path="/diagnosis/:id" element={<DiagnosisPage />} />
          <Route path="/schedule/:id" element={<SchedulePage />} />
          <Route path="/confirm/:id" element={<ConfirmPage />} />
          <Route path="/orders" element={<OrdersPage />} />
          <Route path="/orders/:id" element={<OrderDetailPage />} />
          <Route path="/payment/:id" element={<PaymentPage />} />
          <Route path="/review/:id" element={<ReviewPage />} />
          <Route path="/profile" element={<ProfilePage />} />
        </Route>

        <Route path="*" element={<div className="p-20 text-center font-bold">404 - 找不到頁面</div>} />

        {/* Admin Flow */}
        <Route element={<AdminLayout />}>
          <Route path="/admin/dashboard" element={<AdminDashboard />} />
          <Route path="/admin/orders" element={<AdminOrders />} />
          <Route path="/admin/technicians" element={<AdminTechnicians />} />
          <Route path="/admin/services" element={<AdminServicesPage />} />
          <Route path="/admin/reports" element={<AdminReportsPage />} />
        </Route>

        {/* Technician Flow */}
        <Route path="/tech" element={<CustomerLayout />}> {/* Reuse header/nav for demo */}
          <Route path="today" element={<TechTodayPage />} />
          <Route path="jobs/:id" element={<TechJobDetailPage />} />
          <Route path="complete/:id" element={<TechJobCompletePage />} />
        </Route>
      </Routes>
    </Router>
  );
}
