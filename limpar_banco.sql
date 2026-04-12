-- Script para limpar dados operacionais no Supabase
-- Mantém a tabela de usuários intacta.
-- Execute no Supabase SQL Editor.

BEGIN;

-- Limpa tabelas de rotina e reinicia os IDs para começar em 1.
TRUNCATE TABLE
    public.baixa_log,
    public.transferencia_log,
    public.nascimento_log,
    public.animal,
    public.solicitacao_faixa
RESTART IDENTITY;

-- Atualiza versão de sincronização (força reset nos apps).
UPDATE public.app_config
SET value = (value::int + 1)::text,
        atualizado_em = NOW()
WHERE key = 'sync_version';

COMMIT;
