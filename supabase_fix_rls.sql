-- EXECUTE ESTE SQL NO SUPABASE SQL EDITOR PARA LIBERAR ACESSO TOTAL
-- Regra: permitir SELECT/INSERT/UPDATE/DELETE para todos em todas as tabelas do app.

-- Tabelas usadas pelo app: acesso total.
DO $$
DECLARE
  t TEXT;
  tables_full_access TEXT[] := ARRAY[
    'app_config',
    'usuario',
    'animal',
    'nascimento_log',
    'baixa_log',
    'transferencia_log',
    'solicitacao_faixa'
  ];
BEGIN
  FOREACH t IN ARRAY tables_full_access LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);

      EXECUTE format('DROP POLICY IF EXISTS "Permitir todas operacoes para autenticados" ON public.%I', t);
      EXECUTE format('DROP POLICY IF EXISTS "Permitir todas operações para autenticados" ON public.%I', t);
      EXECUTE format('DROP POLICY IF EXISTS "Permitir select para anon" ON public.%I', t);
      EXECUTE format('DROP POLICY IF EXISTS "Permitir insert para anon" ON public.%I', t);
      EXECUTE format('DROP POLICY IF EXISTS "Permitir update para anon" ON public.%I', t);
      EXECUTE format('DROP POLICY IF EXISTS "Permitir delete para anon" ON public.%I', t);
      EXECUTE format('DROP POLICY IF EXISTS "Permitir insert somente admin" ON public.%I', t);
      EXECUTE format('DROP POLICY IF EXISTS "Permitir update somente admin" ON public.%I', t);
      EXECUTE format('DROP POLICY IF EXISTS "Permitir delete somente admin" ON public.%I', t);

      EXECUTE format('CREATE POLICY "Permitir select para anon" ON public.%I FOR SELECT USING (true)', t);
      EXECUTE format('CREATE POLICY "Permitir insert para anon" ON public.%I FOR INSERT WITH CHECK (true)', t);
      EXECUTE format('CREATE POLICY "Permitir update para anon" ON public.%I FOR UPDATE USING (true) WITH CHECK (true)', t);
      EXECUTE format('CREATE POLICY "Permitir delete para anon" ON public.%I FOR DELETE USING (true)', t);
    END IF;
  END LOOP;
END
$$;
