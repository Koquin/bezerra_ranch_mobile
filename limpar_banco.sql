-- Script para limpar todos os dados do banco de dados
-- Execute no Supabase SQL Editor

-- Apagar dados respeitando as foreign keys (ordem importante)
DELETE FROM morte;
DELETE FROM nascimento;
DELETE FROM solicitacao_faixa;
DELETE FROM usuario WHERE admin IS NOT TRUE;

-- Atualiza versão de sincronização (força reset nos apps)
UPDATE app_config
SET value = (value::int + 1)::text,
    atualizado_em = NOW()
WHERE key = 'sync_version';

-- Opcional: Resetar sequences (IDs voltam para 1)
SELECT setval(pg_get_serial_sequence('morte', 'id'), 1);
SELECT setval(pg_get_serial_sequence('nascimento', 'id'), 1);
SELECT setval(pg_get_serial_sequence('solicitacao_faixa', 'id'), 1);
SELECT setval(pg_get_serial_sequence('usuario', 'id'), 1);
