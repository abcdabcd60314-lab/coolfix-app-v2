-- 任務 1 & 2：建立表格、RLS、Triggers 以及 Storage Bucket
-- 請將此 SQL 全部複製到 Supabase SQL Editor 執行

-- 1. Enums
CREATE TYPE user_role AS ENUM ('customer', 'admin', 'technician');
CREATE TYPE order_status AS ENUM ('pending', 'assigned', 'on_the_way', 'in_progress', 'completed', 'paid', 'cancelled');
CREATE TYPE photo_type AS ENUM ('before', 'after');
CREATE TYPE photo_uploader AS ENUM ('customer', 'technician');

-- 2. Tables
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  phone TEXT,
  role user_role NOT NULL DEFAULT 'customer',
  name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.technicians (
  id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  service_areas TEXT[],
  skills TEXT[],
  avg_rating NUMERIC DEFAULT 0,
  total_jobs INT DEFAULT 0,
  is_available BOOLEAN DEFAULT true
);

CREATE TABLE public.service_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  base_price_min INT,
  base_price_max INT,
  estimated_minutes INT,
  description TEXT,
  is_active BOOLEAN DEFAULT true
);

CREATE TABLE public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  technician_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  service_type_id UUID REFERENCES public.service_types(id) ON DELETE SET NULL,
  status order_status NOT NULL DEFAULT 'pending',
  customer_description TEXT,
  estimated_price_min INT,
  estimated_price_max INT,
  final_price INT,
  scheduled_at TIMESTAMPTZ,
  address TEXT NOT NULL,
  address_lat NUMERIC,
  address_lng NUMERIC,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.order_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  type photo_type NOT NULL,
  uploaded_by photo_uploader NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE UNIQUE,
  customer_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  technician_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. RLS setup
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.technicians ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Helpers for RLS
CREATE OR REPLACE FUNCTION public.get_user_role(match_user_id UUID)
RETURNS user_role AS $$
BEGIN
  RETURN (SELECT role FROM public.users WHERE id = match_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- users policies
CREATE POLICY "Anyone can read users" ON public.users FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE TO authenticated USING (auth.uid() = id);
CREATE POLICY "Admin can full access users" ON public.users FOR ALL TO authenticated USING (public.get_user_role(auth.uid()) = 'admin');

-- technicians policies
CREATE POLICY "Anyone can read technicians" ON public.technicians FOR SELECT USING (true);
CREATE POLICY "Technician can update own profile" ON public.technicians FOR UPDATE TO authenticated USING (auth.uid() = id);
CREATE POLICY "Admin full access technicians" ON public.technicians FOR ALL TO authenticated USING (public.get_user_role(auth.uid()) = 'admin');

-- service_types policies
CREATE POLICY "Anyone can read service types" ON public.service_types FOR SELECT USING (true);
CREATE POLICY "Admin full access service types" ON public.service_types FOR ALL TO authenticated USING (public.get_user_role(auth.uid()) = 'admin');

-- orders policies
CREATE POLICY "Customers view own orders" ON public.orders FOR SELECT TO authenticated USING (auth.uid() = customer_id);
CREATE POLICY "Technicians view assigned orders" ON public.orders FOR SELECT TO authenticated USING (auth.uid() = technician_id);
CREATE POLICY "Customers insert orders" ON public.orders FOR INSERT TO authenticated WITH CHECK (auth.uid() = customer_id);
CREATE POLICY "Customers update pending orders" ON public.orders FOR UPDATE TO authenticated USING (auth.uid() = customer_id AND status = 'pending');
CREATE POLICY "Technicians update assigned orders" ON public.orders FOR UPDATE TO authenticated USING (auth.uid() = technician_id);
CREATE POLICY "Admin full access orders" ON public.orders FOR ALL TO authenticated USING (public.get_user_role(auth.uid()) = 'admin');

-- order_photos policies
CREATE POLICY "Customers view own order photos" ON public.order_photos FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.orders WHERE id = order_id AND customer_id = auth.uid()));
CREATE POLICY "Technicians view assigned order photos" ON public.order_photos FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.orders WHERE id = order_id AND technician_id = auth.uid()));
CREATE POLICY "Customers insert own order photos" ON public.order_photos FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM public.orders WHERE id = order_id AND customer_id = auth.uid()));
CREATE POLICY "Technicians insert assigned order photos" ON public.order_photos FOR INSERT TO authenticated WITH CHECK (EXISTS (SELECT 1 FROM public.orders WHERE id = order_id AND technician_id = auth.uid()));
CREATE POLICY "Admin full access order photos" ON public.order_photos FOR ALL TO authenticated USING (public.get_user_role(auth.uid()) = 'admin');

-- reviews policies
CREATE POLICY "Customers view own reviews" ON public.reviews FOR SELECT TO authenticated USING (customer_id = auth.uid());
CREATE POLICY "Technicians view own reviews" ON public.reviews FOR SELECT TO authenticated USING (technician_id = auth.uid());
CREATE POLICY "Customers insert own reviews" ON public.reviews FOR INSERT TO authenticated WITH CHECK (customer_id = auth.uid());
CREATE POLICY "Admin full access reviews" ON public.reviews FOR ALL TO authenticated USING (public.get_user_role(auth.uid()) = 'admin');

-- notifications policies
CREATE POLICY "Users view own notifications" ON public.notifications FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "Users update own notifications" ON public.notifications FOR UPDATE TO authenticated USING (user_id = auth.uid());
CREATE POLICY "Admin full access notifications" ON public.notifications FOR ALL TO authenticated USING (public.get_user_role(auth.uid()) = 'admin');

-- 4. Triggers
-- updated_at trigger for orders
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_orders_updated_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- trigger to auto create user on signup
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, role)
  VALUES (NEW.id, NEW.email, 'customer');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 5. Storage (Task 2)
INSERT INTO storage.buckets (id, name, public) VALUES ('order-photos', 'order-photos', false);

-- Storage Policies for order-photos
-- Authenticated users can insert
CREATE POLICY "Authenticated users can upload photos" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'order-photos');

-- Authenticated users can read photos (Further security can rely on user validation in backend or strict bucket paths)
CREATE POLICY "Authenticated users can read photos" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'order-photos');
CREATE POLICY "Admin full access objects" ON storage.objects FOR ALL TO authenticated USING (public.get_user_role(auth.uid()) = 'admin');

-- 6. Realtime (Task 5 requirement)
-- 啟用 orders 資料表的即時監聽功能
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
