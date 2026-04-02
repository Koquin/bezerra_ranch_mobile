-- EXECUTE ESTE SQL NO SUPABASE SQL EDITOR PARA CORRIGIR O ERRO DE RLS

-- Remover políticas antigas
DROP POLICY IF EXISTS "Permitir todas operações para autenticados" ON app_config;
DROP POLICY IF EXISTS "Permitir todas operações para autenticados" ON usuario;
DROP POLICY IF EXISTS "Permitir todas operações para autenticados" ON nascimento;
DROP POLICY IF EXISTS "Permitir todas operações para autenticados" ON morte;
DROP POLICY IF EXISTS "Permitir todas operações para autenticados" ON solicitacao_faixa;

-- Políticas para tabela app_config (somente leitura para anon)
CREATE POLICY "Permitir select para anon" ON app_config
    FOR SELECT USING (true);

-- Políticas para tabela usuario (acesso total para anon)
CREATE POLICY "Permitir select para anon" ON usuario
    FOR SELECT USING (true);
CREATE POLICY "Permitir insert para anon" ON usuario
    FOR INSERT WITH CHECK (true);
CREATE POLICY "Permitir update para anon" ON usuario
    FOR UPDATE USING (true);
CREATE POLICY "Permitir delete para anon" ON usuario
    FOR DELETE USING (true);

-- Políticas para tabela nascimento (acesso total para anon)
CREATE POLICY "Permitir select para anon" ON nascimento
    FOR SELECT USING (true);
CREATE POLICY "Permitir insert para anon" ON nascimento
    FOR INSERT WITH CHECK (true);
CREATE POLICY "Permitir update para anon" ON nascimento
    FOR UPDATE USING (true);
CREATE POLICY "Permitir delete para anon" ON nascimento
    FOR DELETE USING (true);

-- Políticas para tabela morte (acesso total para anon)
CREATE POLICY "Permitir select para anon" ON morte
    FOR SELECT USING (true);
CREATE POLICY "Permitir insert para anon" ON morte
    FOR INSERT WITH CHECK (true);
CREATE POLICY "Permitir update para anon" ON morte
    FOR UPDATE USING (true);
CREATE POLICY "Permitir delete para anon" ON morte
    FOR DELETE USING (true);

-- Políticas para tabela solicitacao_faixa (acesso total para anon)
CREATE POLICY "Permitir select para anon" ON solicitacao_faixa
    FOR SELECT USING (true);
CREATE POLICY "Permitir insert para anon" ON solicitacao_faixa
    FOR INSERT WITH CHECK (true);
CREATE POLICY "Permitir update para anon" ON solicitacao_faixa
    FOR UPDATE USING (true);
CREATE POLICY "Permitir delete para anon" ON solicitacao_faixa
    FOR DELETE USING (true);
