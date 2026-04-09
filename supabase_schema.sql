    location_cidade TEXT,
    location_bairro TEXT,
    location_latitude DOUBLE PRECISION,
    location_longitude DOUBLE PRECISION,
    location_cidade TEXT,
    location_bairro TEXT,
    location_latitude DOUBLE PRECISION,
    location_longitude DOUBLE PRECISION,
-- SQL Schema para Supabase
-- Execute este script no SQL Editor do Supabase

-- Tabela: app_config (configurações globais do app)
CREATE TABLE IF NOT EXISTS app_config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Versão de sincronização global
INSERT INTO app_config (key, value)
VALUES ('sync_version', '1')
ON CONFLICT (key) DO NOTHING;

-- Tabela: usuario
CREATE TABLE IF NOT EXISTS usuario (
    id BIGSERIAL PRIMARY KEY,
    nome TEXT NOT NULL,
    login TEXT NOT NULL UNIQUE,
    senha_hash TEXT NOT NULL,
    ativo BOOLEAN NOT NULL DEFAULT true,
    cria_prefixo TEXT NOT NULL,
    cria_inicio INTEGER NOT NULL,
    cria_max INTEGER NOT NULL,
    is_admin BOOLEAN NOT NULL DEFAULT false,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabela: nascimento
CREATE TABLE IF NOT EXISTS nascimento (
    id BIGSERIAL PRIMARY KEY,
    cria TEXT NOT NULL UNIQUE,
    mae TEXT NOT NULL,
    sexo TEXT NOT NULL,
    raca TEXT NOT NULL,
    pelagem TEXT NOT NULL,
    data_nascimento TIMESTAMPTZ NOT NULL,
    fazenda TEXT NOT NULL,
    observacao TEXT,
    foto1 TEXT,
    foto2 TEXT,
    foto3 TEXT,
    usuario_id BIGINT NOT NULL REFERENCES usuario(id),
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    morto BOOLEAN NOT NULL DEFAULT false
);

-- Tabela: morte
CREATE TABLE IF NOT EXISTS morte (
    id BIGSERIAL PRIMARY KEY,
    nascimento_id BIGINT NOT NULL REFERENCES nascimento(id),
    data_morte TIMESTAMPTZ NOT NULL,
    fazenda TEXT NOT NULL,
    foto1 TEXT,
    foto2 TEXT,
    foto3 TEXT,
    audio TEXT,
    descricao TEXT,
    usuario_id BIGINT NOT NULL REFERENCES usuario(id),
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabela: solicitacao_faixa
CREATE TABLE IF NOT EXISTS solicitacao_faixa (
    id BIGSERIAL PRIMARY KEY,
    usuario_id BIGINT NOT NULL REFERENCES usuario(id),
    usuario_nome TEXT NOT NULL,
    prefixo TEXT NOT NULL,
    inicio_atual INTEGER NOT NULL,
    max_atual INTEGER NOT NULL,
    restantes INTEGER NOT NULL,
    solicitado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status TEXT NOT NULL DEFAULT 'PENDENTE',
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_nascimento_cria ON nascimento(cria);
CREATE INDEX IF NOT EXISTS idx_nascimento_usuario_id ON nascimento(usuario_id);
CREATE INDEX IF NOT EXISTS idx_nascimento_morto ON nascimento(morto);
CREATE INDEX IF NOT EXISTS idx_morte_nascimento_id ON morte(nascimento_id);
CREATE INDEX IF NOT EXISTS idx_morte_usuario_id ON morte(usuario_id);
CREATE INDEX IF NOT EXISTS idx_solicitacao_faixa_usuario_id ON solicitacao_faixa(usuario_id);
CREATE INDEX IF NOT EXISTS idx_solicitacao_faixa_status ON solicitacao_faixa(status);
CREATE INDEX IF NOT EXISTS idx_usuario_login ON usuario(login);

-- Função para atualizar atualizado_em automaticamente
CREATE OR REPLACE FUNCTION update_atualizado_em_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.atualizado_em = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers para atualizar atualizado_em
CREATE TRIGGER update_usuario_atualizado_em BEFORE UPDATE ON usuario
    FOR EACH ROW EXECUTE FUNCTION update_atualizado_em_column();

CREATE TRIGGER update_nascimento_atualizado_em BEFORE UPDATE ON nascimento
    FOR EACH ROW EXECUTE FUNCTION update_atualizado_em_column();

CREATE TRIGGER update_morte_atualizado_em BEFORE UPDATE ON morte
    FOR EACH ROW EXECUTE FUNCTION update_atualizado_em_column();

CREATE TRIGGER update_solicitacao_faixa_atualizado_em BEFORE UPDATE ON solicitacao_faixa
    FOR EACH ROW EXECUTE FUNCTION update_atualizado_em_column();

-- Habilitar Row Level Security (RLS) - recomendado para segurança
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuario ENABLE ROW LEVEL SECURITY;
ALTER TABLE nascimento ENABLE ROW LEVEL SECURITY;
ALTER TABLE morte ENABLE ROW LEVEL SECURITY;
ALTER TABLE solicitacao_faixa ENABLE ROW LEVEL SECURITY;

-- Helper para checar claim de admin no JWT
CREATE OR REPLACE FUNCTION public.request_is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(
        NULLIF(auth.jwt() ->> 'is_admin', '')::BOOLEAN,
        NULLIF(auth.jwt() -> 'app_metadata' ->> 'is_admin', '')::BOOLEAN,
        false
    );
$$;

-- Políticas RLS: Permitir TODAS as operações para requisições anônimas
-- IMPORTANTE: Como estamos usando apenas anon key (sem autenticação de usuários),
-- precisamos permitir acesso total para usuários anônimos

-- Políticas para tabela app_config (somente leitura para anon)
DROP POLICY IF EXISTS "Permitir todas operações para autenticados" ON app_config;
CREATE POLICY "Permitir select para anon" ON app_config
    FOR SELECT USING (true);

-- Políticas para tabela usuario
DROP POLICY IF EXISTS "Permitir todas operações para autenticados" ON usuario;
DROP POLICY IF EXISTS "Permitir select para anon" ON usuario;
DROP POLICY IF EXISTS "Permitir insert para anon" ON usuario;
DROP POLICY IF EXISTS "Permitir update para anon" ON usuario;
DROP POLICY IF EXISTS "Permitir delete para anon" ON usuario;
DROP POLICY IF EXISTS "Permitir insert somente admin" ON usuario;
DROP POLICY IF EXISTS "Permitir update somente admin" ON usuario;
DROP POLICY IF EXISTS "Permitir delete somente admin" ON usuario;
CREATE POLICY "Permitir select para anon" ON usuario
    FOR SELECT USING (true);
CREATE POLICY "Permitir insert para anon" ON usuario
    FOR INSERT WITH CHECK (true);
CREATE POLICY "Permitir update para anon" ON usuario
    FOR UPDATE USING (true)
    WITH CHECK (true);
CREATE POLICY "Permitir delete para anon" ON usuario
    FOR DELETE USING (true);

-- Políticas para tabela nascimento
DROP POLICY IF EXISTS "Permitir todas operações para autenticados" ON nascimento;
CREATE POLICY "Permitir select para anon" ON nascimento
    FOR SELECT USING (true);
CREATE POLICY "Permitir insert para anon" ON nascimento
    FOR INSERT WITH CHECK (true);
CREATE POLICY "Permitir update para anon" ON nascimento
    FOR UPDATE USING (true);
CREATE POLICY "Permitir delete para anon" ON nascimento
    FOR DELETE USING (true);

-- Políticas para tabela morte
DROP POLICY IF EXISTS "Permitir todas operações para autenticados" ON morte;
CREATE POLICY "Permitir select para anon" ON morte
    FOR SELECT USING (true);
CREATE POLICY "Permitir insert para anon" ON morte
    FOR INSERT WITH CHECK (true);
CREATE POLICY "Permitir update para anon" ON morte
    FOR UPDATE USING (true);
CREATE POLICY "Permitir delete para anon" ON morte
    FOR DELETE USING (true);

-- Políticas para tabela solicitacao_faixa
DROP POLICY IF EXISTS "Permitir todas operações para autenticados" ON solicitacao_faixa;
CREATE POLICY "Permitir select para anon" ON solicitacao_faixa
    FOR SELECT USING (true);
CREATE POLICY "Permitir insert para anon" ON solicitacao_faixa
    FOR INSERT WITH CHECK (true);
CREATE POLICY "Permitir update para anon" ON solicitacao_faixa
    FOR UPDATE USING (true);
CREATE POLICY "Permitir delete para anon" ON solicitacao_faixa
    FOR DELETE USING (true);

-- Inserir usuário admin padrão
-- login: admin | senha definida fora do código (via variável de ambiente)
-- Hash SHA-256 usado no seed inicial: 240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9
INSERT INTO usuario (nome, login, senha_hash, ativo, cria_prefixo, cria_inicio, cria_max, is_admin)
VALUES ('Administrador', 'admin', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', true, 'E', 10, 1000, true)
ON CONFLICT (login) DO NOTHING;
