-- =============================================================================
-- PROJETO ACADÊMICO: AulaSempre
-- SGBD: MySQL 8.x
-- FERRAMENTA: MySQL Workbench
-- ARQUIVO: aulasempre.sql
-- DESCRIÇÃO: Script completo contendo DDL (criação do banco, tabelas, PKs, FKs,
--            constraints e índices), DML (dados fictícios para teste) e
--            DQL (12 consultas analíticas e de integração com API/Match).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. CRIAÇÃO E SELEÇÃO DO BANCO DE DADOS
-- -----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS aulasempre
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE aulasempre;

-- Desativar temporariamente checagem de FK para recriação limpa (se necessário)
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS avaliacao;
DROP TABLE IF EXISTS substituicao;
DROP TABLE IF EXISTS convite;
DROP TABLE IF EXISTS solicitacao_substituicao;
DROP TABLE IF EXISTS disponibilidade;
DROP TABLE IF EXISTS professor_nivel_ensino;
DROP TABLE IF EXISTS nivel_ensino;
DROP TABLE IF EXISTS professor_disciplina;
DROP TABLE IF EXISTS disciplina;
DROP TABLE IF EXISTS formacao;
DROP TABLE IF EXISTS professor;
DROP TABLE IF EXISTS usuario;
DROP TABLE IF EXISTS escola;

SET FOREIGN_KEY_CHECKS = 1;

-- -----------------------------------------------------------------------------
-- 2. CRIAÇÃO DAS TABELAS (DDL COM PK, FK, CONSTRAINTS E CHECK)
-- -----------------------------------------------------------------------------

-- TABELA: escola
-- Armazena os dados cadastrais das instituições de ensino parceiras
CREATE TABLE escola (
    id_escola INT AUTO_INCREMENT,
    nome VARCHAR(150) NOT NULL,
    cnpj VARCHAR(18) UNIQUE NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    telefone VARCHAR(20) NULL,
    cidade VARCHAR(100) NOT NULL,
    estado CHAR(2) NOT NULL,
    endereco VARCHAR(255) NULL,
    data_cadastro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ativo TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT pk_escola PRIMARY KEY (id_escola)
) ENGINE=InnoDB;

-- TABELA: usuario
-- Armazena os dados de autenticação e acesso de qualquer usuário (Escola ou Professor).
-- Se for colaborador de uma escola, vincula-se à escola através de id_escola (1:N).
CREATE TABLE usuario (
    id_usuario INT AUTO_INCREMENT,
    id_escola INT NULL,
    nome VARCHAR(150) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    senha VARCHAR(255) NOT NULL,
    telefone VARCHAR(20) NULL,
    tipo_usuario ENUM('ESCOLA', 'PROFESSOR') NOT NULL,
    ativo TINYINT(1) NOT NULL DEFAULT 1,
    data_cadastro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_usuario PRIMARY KEY (id_usuario),
    CONSTRAINT fk_usuario_escola FOREIGN KEY (id_escola)
        REFERENCES escola (id_escola)
        ON DELETE SET NULL
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- TABELA: professor
-- Armazena o perfil profissional do professor (extensão 1:1 de usuario)
CREATE TABLE professor (
    id_professor INT AUTO_INCREMENT,
    id_usuario INT NOT NULL UNIQUE,
    nome_profissional VARCHAR(150) NULL,
    descricao TEXT NULL,
    anos_experiencia INT NOT NULL DEFAULT 0,
    cidade VARCHAR(100) NOT NULL,
    estado CHAR(2) NOT NULL,
    status ENUM('DISPONIVEL', 'INDISPONIVEL', 'EM_SUBSTITUICAO') NOT NULL DEFAULT 'DISPONIVEL',
    data_cadastro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_professor PRIMARY KEY (id_professor),
    CONSTRAINT fk_professor_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuario (id_usuario)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_professor_experiencia CHECK (anos_experiencia >= 0)
) ENGINE=InnoDB;

-- TABELA: formacao
-- Armazena os títulos acadêmicos e especializações do professor (1:N)
CREATE TABLE formacao (
    id_formacao INT AUTO_INCREMENT,
    id_professor INT NOT NULL,
    curso VARCHAR(150) NOT NULL,
    instituicao VARCHAR(150) NOT NULL,
    tipo_formacao ENUM('GRADUACAO', 'LICENCIATURA', 'BACHARELADO', 'POS_GRADUACAO', 'MESTRADO', 'DOUTORADO') NOT NULL,
    ano_conclusao INT NULL,
    status ENUM('CONCLUIDO', 'EM_ANDAMENTO', 'INCOMPLETO') NOT NULL DEFAULT 'CONCLUIDO',
    CONSTRAINT pk_formacao PRIMARY KEY (id_formacao),
    CONSTRAINT fk_formacao_professor FOREIGN KEY (id_professor)
        REFERENCES professor (id_professor)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_formacao_ano CHECK (ano_conclusao IS NULL OR (ano_conclusao >= 1950 AND ano_conclusao <= 2100))
) ENGINE=InnoDB;

-- TABELA: disciplina
-- Catálogo de matérias ofertadas pela plataforma
CREATE TABLE disciplina (
    id_disciplina INT AUTO_INCREMENT,
    nome VARCHAR(100) NOT NULL UNIQUE,
    descricao VARCHAR(255) NULL,
    ativo TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT pk_disciplina PRIMARY KEY (id_disciplina)
) ENGINE=InnoDB;

-- TABELA: professor_disciplina (Associativa N:N)
-- Relaciona quais matérias cada professor está capacitado a lecionar
CREATE TABLE professor_disciplina (
    id_professor INT NOT NULL,
    id_disciplina INT NOT NULL,
    CONSTRAINT pk_professor_disciplina PRIMARY KEY (id_professor, id_disciplina),
    CONSTRAINT fk_pd_professor FOREIGN KEY (id_professor)
        REFERENCES professor (id_professor)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_pd_disciplina FOREIGN KEY (id_disciplina)
        REFERENCES disciplina (id_disciplina)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- TABELA: nivel_ensino
-- Catálogo de etapas educacionais (ex: Fundamental I, Fundamental II, Médio)
CREATE TABLE nivel_ensino (
    id_nivel_ensino INT AUTO_INCREMENT,
    nome VARCHAR(100) NOT NULL UNIQUE,
    descricao VARCHAR(255) NULL,
    ativo TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT pk_nivel_ensino PRIMARY KEY (id_nivel_ensino)
) ENGINE=InnoDB;

-- TABELA: professor_nivel_ensino (Associativa N:N)
-- Relaciona as faixas etárias / níveis educacionais em que o professor atua
CREATE TABLE professor_nivel_ensino (
    id_professor INT NOT NULL,
    id_nivel_ensino INT NOT NULL,
    CONSTRAINT pk_professor_nivel_ensino PRIMARY KEY (id_professor, id_nivel_ensino),
    CONSTRAINT fk_pne_professor FOREIGN KEY (id_professor)
        REFERENCES professor (id_professor)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_pne_nivel FOREIGN KEY (id_nivel_ensino)
        REFERENCES nivel_ensino (id_nivel_ensino)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- TABELA: disponibilidade
-- Registra as janelas de horários semanais fixas do professor
CREATE TABLE disponibilidade (
    id_disponibilidade INT AUTO_INCREMENT,
    id_professor INT NOT NULL,
    dia_semana ENUM('DOMINGO', 'SEGUNDA', 'TERCA', 'QUARTA', 'QUINTA', 'SEXTA', 'SABADO') NOT NULL,
    horario_inicio TIME NOT NULL,
    horario_fim TIME NOT NULL,
    ativo TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT pk_disponibilidade PRIMARY KEY (id_disponibilidade),
    CONSTRAINT fk_disponibilidade_professor FOREIGN KEY (id_professor)
        REFERENCES professor (id_professor)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_disp_horario CHECK (horario_inicio < horario_fim)
) ENGINE=InnoDB;

-- TABELA: solicitacao_substituicao
-- Demanda de substituição emergencial ou programada aberta por uma escola
CREATE TABLE solicitacao_substituicao (
    id_solicitacao INT AUTO_INCREMENT,
    id_escola INT NOT NULL,
    id_disciplina INT NOT NULL,
    id_nivel_ensino INT NOT NULL,
    data_aula DATE NOT NULL,
    horario_inicio TIME NOT NULL,
    horario_fim TIME NOT NULL,
    turma VARCHAR(50) NOT NULL,
    observacoes TEXT NULL,
    status ENUM('ABERTA', 'EM_PROCESSO', 'PREENCHIDA', 'CONCLUIDA', 'CANCELADA') NOT NULL DEFAULT 'ABERTA',
    data_criacao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_solicitacao PRIMARY KEY (id_solicitacao),
    CONSTRAINT fk_solicitacao_escola FOREIGN KEY (id_escola)
        REFERENCES escola (id_escola)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_solicitacao_disciplina FOREIGN KEY (id_disciplina)
        REFERENCES disciplina (id_disciplina)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_solicitacao_nivel FOREIGN KEY (id_nivel_ensino)
        REFERENCES nivel_ensino (id_nivel_ensino)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT chk_solic_horario CHECK (horario_inicio < horario_fim)
) ENGINE=InnoDB;

-- TABELA: convite
-- Convites individuais enviados aos professores compatíveis para uma solicitação
CREATE TABLE convite (
    id_convite INT AUTO_INCREMENT,
    id_solicitacao INT NOT NULL,
    id_professor INT NOT NULL,
    data_envio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_resposta DATETIME NULL,
    status ENUM('PENDENTE', 'ACEITO', 'RECUSADO', 'EXPIRADO', 'CANCELADO') NOT NULL DEFAULT 'PENDENTE',
    observacao VARCHAR(255) NULL,
    CONSTRAINT pk_convite PRIMARY KEY (id_convite),
    CONSTRAINT fk_convite_solicitacao FOREIGN KEY (id_solicitacao)
        REFERENCES solicitacao_substituicao (id_solicitacao)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_convite_professor FOREIGN KEY (id_professor)
        REFERENCES professor (id_professor)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    -- Impede convites duplicados para a mesma solicitação e professor
    CONSTRAINT uq_solicitacao_professor UNIQUE (id_solicitacao, id_professor)
) ENGINE=InnoDB;

-- TABELA: substituicao
-- Registro oficial e histórico do atendimento da aula pelo professor
CREATE TABLE substituicao (
    id_substituicao INT AUTO_INCREMENT,
    id_solicitacao INT NOT NULL,
    id_professor INT NOT NULL,
    id_convite INT NULL UNIQUE,
    data_substituicao DATE NOT NULL,
    horario_inicio TIME NOT NULL,
    horario_fim TIME NOT NULL,
    status ENUM('AGENDADA', 'EM_ANDAMENTO', 'REALIZADA', 'CANCELADA', 'FALTA_PROFESSOR') NOT NULL DEFAULT 'AGENDADA',
    observacoes TEXT NULL,
    CONSTRAINT pk_substituicao PRIMARY KEY (id_substituicao),
    CONSTRAINT fk_substituicao_solicitacao FOREIGN KEY (id_solicitacao)
        REFERENCES solicitacao_substituicao (id_solicitacao)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_substituicao_professor FOREIGN KEY (id_professor)
        REFERENCES professor (id_professor)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_substituicao_convite FOREIGN KEY (id_convite)
        REFERENCES convite (id_convite)
        ON DELETE SET NULL
        ON UPDATE CASCADE,
    CONSTRAINT chk_subst_horario CHECK (horario_inicio < horario_fim)
) ENGINE=InnoDB;

-- TABELA: avaliacao
-- Avaliação de desempenho e pontualidade enviada pela escola após a substituição
CREATE TABLE avaliacao (
    id_avaliacao INT AUTO_INCREMENT,
    id_substituicao INT NOT NULL UNIQUE, -- 1:1 estrito com substituicao
    id_professor INT NOT NULL,
    nota TINYINT UNSIGNED NOT NULL,
    comentario TEXT NULL,
    data_avaliacao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_avaliacao PRIMARY KEY (id_avaliacao),
    CONSTRAINT fk_avaliacao_substituicao FOREIGN KEY (id_substituicao)
        REFERENCES substituicao (id_substituicao)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_avaliacao_professor FOREIGN KEY (id_professor)
        REFERENCES professor (id_professor)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    -- Restrição de nota válida entre 1 e 5
    CONSTRAINT chk_avaliacao_nota CHECK (nota >= 1 AND nota <= 5)
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 3. ÍNDICES DE OTIMIZAÇÃO (PERFORMANCE E AGILIDADE DE MATCH)
-- -----------------------------------------------------------------------------

-- Otimização para consultas de autenticação e busca por e-mail
CREATE INDEX idx_usuario_email_ativo ON usuario (email, ativo);
CREATE INDEX idx_escola_cidade_uf ON escola (cidade, estado);

-- Otimização do algoritmo de Match (filtro de professores por cidade/status)
CREATE INDEX idx_professor_status_cidade ON professor (status, cidade, estado);

-- Otimização para filtros de agenda e cruzamento de disponibilidade
CREATE INDEX idx_disp_prof_dia_horario ON disponibilidade (dia_semana, horario_inicio, horario_fim, ativo);

-- Otimização de busca no mural de solicitações
CREATE INDEX idx_solic_status_data ON solicitacao_substituicao (status, data_aula);
CREATE INDEX idx_solic_match_filtro ON solicitacao_substituicao (id_disciplina, id_nivel_ensino, data_aula);

-- Otimização do painel de convites pendentes e respostas
CREATE INDEX idx_convite_status_envio ON convite (status, data_envio);

-- Otimização do histórico de substituições e relatórios de escolas
CREATE INDEX idx_subst_prof_data ON substituicao (id_professor, data_substituicao, status);

-- Otimização para cálculo de médias de pontuação de professores
CREATE INDEX idx_avaliacao_prof_nota ON avaliacao (id_professor, nota);

-- -----------------------------------------------------------------------------
-- 4. INSERÇÃO DE DADOS FICTÍCIOS DE TESTE (DML)
-- -----------------------------------------------------------------------------

-- Inserção de 3 Escolas
INSERT INTO escola (nome, cnpj, email, telefone, cidade, estado, endereco) VALUES
('Colégio São Paulo Integrado', '11.222.333/0001-44', 'contato@colegiosaopaulo.com.br', '(11) 3214-5500', 'São Paulo', 'SP', 'Av. Paulista, 1500 - Bela Vista'),
('Instituto Educacional Dom Bosco', '22.333.444/0001-55', 'direcao@domboscoedu.com.br', '(11) 2987-1122', 'São Paulo', 'SP', 'Rua Domingos de Morais, 800 - Vila Mariana'),
('Academia Moderna de Campinas', '33.444.555/0001-66', 'rh@modernacampinas.com.br', '(19) 3789-4400', 'Campinas', 'SP', 'Av. Barão de Itapura, 2100 - Guanabara');

-- Inserção de 8 Usuários (3 gestores de escola e 5 professores)
INSERT INTO usuario (id_escola, nome, email, senha, telefone, tipo_usuario) VALUES
-- Usuários de Escolas
(1, 'Renata Vasconcellos (Coordenação SP)', 'renata.coord@colegiosaopaulo.com.br', '$2y$10$e8wF9q6h9J9zL7T8yG0rP.u1A7B3c6E9F0G1H2I3J4K5L6M7N8O9P', '(11) 98765-1111', 'ESCOLA'),
(2, 'Carlos Eduardo (Diretor Dom Bosco)', 'carlos.direcao@domboscoedu.com.br', '$2y$10$e8wF9q6h9J9zL7T8yG0rP.u1A7B3c6E9F0G1H2I3J4K5L6M7N8O9P', '(11) 98765-2222', 'ESCOLA'),
(3, 'Mariana Fontes (RH Campinas)', 'mariana.rh@modernacampinas.com.br', '$2y$10$e8wF9q6h9J9zL7T8yG0rP.u1A7B3c6E9F0G1H2I3J4K5L6M7N8O9P', '(19) 98765-3333', 'ESCOLA'),
-- Usuários Professores
(NULL, 'Lucas Silva Martins', 'lucas.matematica@gmail.com', '$2y$10$e8wF9q6h9J9zL7T8yG0rP.u1A7B3c6E9F0G1H2I3J4K5L6M7N8O9P', '(11) 97111-0001', 'PROFESSOR'),
(NULL, 'Beatriz Albuquerque Lima', 'beatriz.letras@gmail.com', '$2y$10$e8wF9q6h9J9zL7T8yG0rP.u1A7B3c6E9F0G1H2I3J4K5L6M7N8O9P', '(11) 97222-0002', 'PROFESSOR'),
(NULL, 'Rodrigo Mendes de Oliveira', 'rodrigo.fisica@gmail.com', '$2y$10$e8wF9q6h9J9zL7T8yG0rP.u1A7B3c6E9F0G1H2I3J4K5L6M7N8O9P', '(11) 97333-0003', 'PROFESSOR'),
(NULL, 'Camila Rocha Nogueira', 'camila.historia@gmail.com', '$2y$10$e8wF9q6h9J9zL7T8yG0rP.u1A7B3c6E9F0G1H2I3J4K5L6M7N8O9P', '(19) 97444-0004', 'PROFESSOR'),
(NULL, 'Fernando Costa Guimarães', 'fernando.biologia@gmail.com', '$2y$10$e8wF9q6h9J9zL7T8yG0rP.u1A7B3c6E9F0G1H2I3J4K5L6M7N8O9P', '(11) 97555-0005', 'PROFESSOR');

-- Inserção dos 5 Professores (associados aos usuários 4 a 8)
INSERT INTO professor (id_usuario, nome_profissional, descricao, anos_experiencia, cidade, estado, status) VALUES
(4, 'Prof. Lucas Silva', 'Especialista em Matemática Financeira e Raciocínio Lógico para Ensino Médio e Vestibulares.', 8, 'São Paulo', 'SP', 'DISPONIVEL'),
(5, 'Profª. Beatriz Lima', 'Licenciada em Letras e Literatura, com foco em redação para o ENEM e produção textual.', 5, 'São Paulo', 'SP', 'DISPONIVEL'),
(6, 'Prof. Rodrigo Mendes', 'Físico com mestrado em Ensino de Ciências e experiência prática em laboratório escolar.', 12, 'São Paulo', 'SP', 'DISPONIVEL'),
(7, 'Profª. Camila Nogueira', 'Historiadora e pesquisadora atuante no Ensino Fundamental II e Médio.', 4, 'Campinas', 'SP', 'DISPONIVEL'),
(8, 'Prof. Fernando Costa', 'Biólogo especialista em Ecologia e Ciências Naturais para Fundamental e Médio.', 6, 'São Paulo', 'SP', 'DISPONIVEL');

-- Inserção de Formações Acadêmicas (1:N)
INSERT INTO formacao (id_professor, curso, instituicao, tipo_formacao, ano_conclusao, status) VALUES
(1, 'Licenciatura em Matemática', 'Universidade de São Paulo (USP)', 'LICENCIATURA', 2016, 'CONCLUIDO'),
(1, 'Pós-Graduação em Educação Matemática', 'PUC-SP', 'POS_GRADUACAO', 2019, 'CONCLUIDO'),
(2, 'Letras - Português e Inglês', 'UNESP', 'LICENCIATURA', 2019, 'CONCLUIDO'),
(2, 'Mestrado em Estudos Literários', 'UNICAMP', 'MESTRADO', 2022, 'CONCLUIDO'),
(3, 'Bacharelado em Física', 'UNICAMP', 'BACHARELADO', 2012, 'CONCLUIDO'),
(3, 'Licenciatura Plena em Física', 'USP', 'LICENCIATURA', 2014, 'CONCLUIDO'),
(3, 'Mestrado em Ensino de Física', 'USP', 'MESTRADO', 2017, 'CONCLUIDO'),
(4, 'História - Memória e Sociedade', 'PUC-Campinas', 'LICENCIATURA', 2020, 'CONCLUIDO'),
(5, 'Ciências Biológicas', 'UFSCar', 'LICENCIATURA', 2018, 'CONCLUIDO');

-- Inserção de 8 Disciplinas
INSERT INTO disciplina (nome, descricao) VALUES
('Matemática', 'Cálculo, álgebra, geometria plana e espacial e estatística aplicada.'),
('Língua Portuguesa', 'Gramática, interpretação de texto e redação formal.'),
('Física', 'Mecânica clássica, termologia, óptica, ondulatória e eletromagnetismo.'),
('Química', 'Química geral, físico-química, química orgânica e experimentos laboratoriais.'),
('Biologia', 'Citologia, genética, evolução, ecologia e anatomia humana.'),
('História', 'História Geral, do Brasil, contemporânea e cidadania.'),
('Geografia', 'Geopolítica, geografia física, demografia e cartografia.'),
('Inglês', 'Compreensão auditiva, conversação, gramática e leitura instrumental.');

-- Associação Professor x Disciplina (N:N)
INSERT INTO professor_disciplina (id_professor, id_disciplina) VALUES
(1, 1), -- Lucas leciona Matemática
(2, 2), -- Beatriz leciona Língua Portuguesa
(2, 8), -- Beatriz leciona Inglês
(3, 3), -- Rodrigo leciona Física
(3, 1), -- Rodrigo leciona Matemática
(4, 6), -- Camila leciona História
(4, 7), -- Camila leciona Geografia
(5, 5), -- Fernando leciona Biologia
(5, 4); -- Fernando leciona Química

-- Inserção de Níveis de Ensino
INSERT INTO nivel_ensino (nome, descricao) VALUES
('Educação Infantil', 'Atendimento para crianças de 0 a 5 anos.'),
('Ensino Fundamental I', 'Anos Iniciais: do 1º ao 5º ano do Ensino Fundamental.'),
('Ensino Fundamental II', 'Anos Finais: do 6º ao 9º ano do Ensino Fundamental.'),
('Ensino Médio', 'Do 1º ao 3º ano do Ensino Médio e preparação para vestibulares.');

-- Associação Professor x Nível de Ensino (N:N)
INSERT INTO professor_nivel_ensino (id_professor, id_nivel_ensino) VALUES
(1, 3), -- Lucas atua no Fundamental II
(1, 4), -- Lucas atua no Ensino Médio
(2, 3), -- Beatriz atua no Fundamental II
(2, 4), -- Beatriz atua no Ensino Médio
(3, 4), -- Rodrigo atua no Ensino Médio
(4, 3), -- Camila atua no Fundamental II
(4, 4), -- Camila atua no Ensino Médio
(5, 2), -- Fernando atua no Fundamental I
(5, 3), -- Fernando atua no Fundamental II
(5, 4); -- Fernando atua no Ensino Médio

-- Inserção de Disponibilidades
INSERT INTO disponibilidade (id_professor, dia_semana, horario_inicio, horario_fim) VALUES
-- Prof. Lucas (Matemática)
(1, 'SEGUNDA', '07:00:00', '12:30:00'),
(1, 'QUARTA',  '07:00:00', '12:30:00'),
(1, 'SEXTA',   '13:30:00', '18:00:00'),
-- Profª. Beatriz (Português/Inglês)
(2, 'SEGUNDA', '07:30:00', '12:00:00'),
(2, 'TERCA',   '07:30:00', '17:00:00'),
(2, 'QUINTA',  '13:00:00', '18:00:00'),
-- Prof. Rodrigo (Física/Matemática)
(3, 'SEGUNDA', '07:00:00', '12:00:00'),
(3, 'TERCA',   '13:00:00', '18:00:00'),
(3, 'QUARTA',  '07:00:00', '17:00:00'),
-- Profª. Camila (História/Geografia)
(4, 'TERCA',   '08:00:00', '12:00:00'),
(4, 'QUINTA',  '08:00:00', '17:00:00'),
-- Prof. Fernando (Biologia/Química)
(5, 'SEGUNDA', '13:00:00', '18:00:00'),
(5, 'QUARTA',  '07:30:00', '12:30:00'),
(5, 'SEXTA',   '07:30:00', '12:30:00');

-- Inserção de Solicitações de Substituição
INSERT INTO solicitacao_substituicao (id_escola, id_disciplina, id_nivel_ensino, data_aula, horario_inicio, horario_fim, turma, observacoes, status, data_criacao) VALUES
-- Solicitação 1: Matemática no Colégio São Paulo (Compatível com Lucas e Rodrigo)
(1, 1, 4, '2026-09-21', '07:30:00', '11:30:00', '3º Ano B - Médio', 'Professor titular teve consulta médica inesperada. Conteúdo: Geometria Analítica.', 'ABERTA', '2026-09-16 08:00:00'),
-- Solicitação 2: Língua Portuguesa no Dom Bosco (Compatível com Beatriz)
(2, 2, 4, '2026-09-22', '08:00:00', '10:00:00', '1º Ano A - Médio', 'Afastamento por licença curta. Conteúdo: Modernismo literário.', 'EM_PROCESSO', '2026-09-16 09:30:00'),
-- Solicitação 3: História na Academia Moderna de Campinas (Compatível com Camila)
(3, 6, 3, '2026-09-24', '08:30:00', '11:00:00', '8º Ano Fundamental', 'Falta abonada. Conteúdo: Revolução Industrial.', 'ABERTA', '2026-09-16 10:15:00'),
-- Solicitação 4: Física no Colégio São Paulo (Já realizada no passado)
(1, 3, 4, '2026-09-14', '08:00:00', '11:00:00', '2º Ano Médio', 'Substituição pontual emergencial concluída com sucesso.', 'CONCLUIDA', '2026-09-12 14:00:00'),
-- Solicitação 5: Biologia no Colégio São Paulo (Já realizada no passado)
(1, 5, 4, '2026-09-11', '08:00:00', '11:30:00', '3º Ano Médio', 'Afastamento para congresso científico.', 'CONCLUIDA', '2026-09-09 11:20:00');

-- Inserção de Convites
INSERT INTO convite (id_solicitacao, id_professor, data_envio, data_resposta, status, observacao) VALUES
-- Convite para Solicitação 1 (Aberta)
(1, 1, '2026-09-16 08:30:00', NULL, 'PENDENTE', 'Aguardando confirmação do professor Lucas'),
-- Convites para Solicitação 2 (Em Processo)
(2, 2, '2026-09-16 09:45:00', '2026-09-16 10:00:00', 'ACEITO', 'Professora Beatriz aceitou a substituição'),
-- Convites para Solicitações Passadas (Concluídas)
(4, 3, '2026-09-12 15:00:00', '2026-09-12 15:30:00', 'ACEITO', 'Prof. Rodrigo aceitou e compareceu'),
(5, 5, '2026-09-09 12:00:00', '2026-09-09 12:45:00', 'ACEITO', 'Prof. Fernando compareceu e concluiu');

-- Inserção de Substituições Efetivadas (Histórico)
INSERT INTO substituicao (id_solicitacao, id_professor, id_convite, data_substituicao, horario_inicio, horario_fim, status, observacoes) VALUES
-- Substituição 1 (Passada - Prof. Rodrigo no Colégio SP)
(4, 3, 3, '2026-09-14', '08:00:00', '11:00:00', 'REALIZADA', 'Substituição cumprida pontualmente. Ótima didática.'),
-- Substituição 2 (Passada - Prof. Fernando no Colégio SP)
(5, 5, 4, '2026-09-11', '08:00:00', '11:30:00', 'REALIZADA', 'Excelente aula de Biologia Molecular.'),
-- Substituição 3 (Futura - Profª. Beatriz no Dom Bosco)
(2, 2, 2, '2026-09-22', '08:00:00', '10:00:00', 'AGENDADA', 'Aguardando data prevista para execução.');

-- Inserção de Avaliações
INSERT INTO avaliacao (id_substituicao, id_professor, nota, comentario, data_avaliacao) VALUES
(1, 3, 5, 'Excelente professor! Dominou a turma, seguiu a ementa à risca e os alunos elogiaram bastante a didática.', '2026-09-14 13:00:00'),
(2, 5, 4, 'Muito bom profissional, pontual e muito educado. Cumpriu todo o cronograma estabelecido.', '2026-09-11 14:00:00');

-- =============================================================================
-- 5. CONSULTAS DE TESTE E DEMONSTRAÇÃO (DQL)
-- =============================================================================

-- Consulta 1: Listar todos os professores cadastrados com dados do usuário
SELECT 
    p.id_professor,
    u.nome AS nome_completo,
    p.nome_profissional,
    u.email,
    u.telefone,
    p.cidade,
    p.estado,
    p.anos_experiencia,
    p.status
FROM professor p
INNER JOIN usuario u ON p.id_usuario = u.id_usuario
ORDER BY u.nome ASC;

-- Consulta 2: Listar professores e suas respectivas disciplinas
SELECT 
    p.id_professor,
    u.nome AS professor,
    GROUP_CONCAT(d.nome ORDER BY d.nome SEPARATOR ', ') AS disciplinas_habilitadas
FROM professor p
INNER JOIN usuario u ON p.id_usuario = u.id_usuario
INNER JOIN professor_disciplina pd ON p.id_professor = pd.id_professor
INNER JOIN disciplina d ON pd.id_disciplina = d.id_disciplina
GROUP BY p.id_professor, u.nome
ORDER BY u.nome ASC;

-- Consulta 3: Listar professores e suas formações acadêmicas
SELECT 
    u.nome AS professor,
    f.curso,
    f.instituicao,
    f.tipo_formacao,
    f.ano_conclusao,
    f.status AS status_formacao
FROM formacao f
INNER JOIN professor p ON f.id_professor = p.id_professor
INNER JOIN usuario u ON p.id_usuario = u.id_usuario
ORDER BY u.nome ASC, f.ano_conclusao DESC;

-- Consulta 4: Listar professores e os níveis de ensino em que atuam
SELECT 
    u.nome AS professor,
    GROUP_CONCAT(ne.nome ORDER BY ne.id_nivel_ensino SEPARATOR ' | ') AS niveis_ensino
FROM professor p
INNER JOIN usuario u ON p.id_usuario = u.id_usuario
INNER JOIN professor_nivel_ensino pne ON p.id_professor = pne.id_professor
INNER JOIN nivel_ensino ne ON pne.id_nivel_ensino = ne.id_nivel_ensino
GROUP BY p.id_professor, u.nome
ORDER BY u.nome ASC;

-- Consulta 5: Listar professores disponíveis em um dia da semana e faixa de horário
-- Exemplo: Professores disponíveis em SEGUNDA-FEIRA entre 07:30 e 11:30
SELECT DISTINCT
    p.id_professor,
    u.nome AS professor,
    p.cidade,
    disp.dia_semana,
    disp.horario_inicio,
    disp.horario_fim
FROM professor p
INNER JOIN usuario u ON p.id_usuario = u.id_usuario
INNER JOIN disponibilidade disp ON p.id_professor = disp.id_professor
WHERE disp.ativo = 1
  AND p.status = 'DISPONIVEL'
  AND disp.dia_semana = 'SEGUNDA'
  AND disp.horario_inicio <= '07:30:00'
  AND disp.horario_fim >= '11:30:00'
ORDER BY u.nome ASC;

-- Consulta 6: Listar solicitações abertas com dados da escola e disciplina
SELECT 
    s.id_solicitacao,
    e.nome AS escola,
    e.cidade AS cidade_escola,
    d.nome AS disciplina,
    ne.nome AS nivel_ensino,
    s.data_aula,
    s.horario_inicio,
    s.horario_fim,
    s.turma,
    s.status
FROM solicitacao_substituicao s
INNER JOIN escola e ON s.id_escola = e.id_escola
INNER JOIN disciplina d ON s.id_disciplina = d.id_disciplina
INNER JOIN nivel_ensino ne ON s.id_nivel_ensino = ne.id_nivel_ensino
WHERE s.status IN ('ABERTA', 'EM_PROCESSO')
ORDER BY s.data_aula ASC, s.horario_inicio ASC;

-- Consulta 7: MATCH - Encontrar professores compatíveis com uma solicitação
-- Considera: Mesma disciplina, mesmo nível de ensino e disponibilidade compatível com o dia/horário da aula
-- Exemplo para a Solicitação ID 1 (Matemática no Ensino Médio, 2026-09-21 [Segunda-feira], 07:30 às 11:30)
SELECT 
    p.id_professor,
    u.nome AS professor,
    u.telefone,
    p.cidade,
    p.anos_experiencia,
    d.nome AS disciplina,
    ne.nome AS nivel_ensino,
    disp.dia_semana,
    disp.horario_inicio AS disponibilidade_inicio,
    disp.horario_fim AS disponibilidade_fim,
    COALESCE(ROUND(AVG(a.nota), 1), 0.0) AS media_avaliacoes
FROM solicitacao_substituicao s
JOIN professor_disciplina pd ON s.id_disciplina = pd.id_disciplina
JOIN professor_nivel_ensino pne ON s.id_nivel_ensino = pne.id_nivel_ensino AND pd.id_professor = pne.id_professor
JOIN professor p ON pd.id_professor = p.id_professor
JOIN usuario u ON p.id_usuario = u.id_usuario
JOIN disciplina d ON s.id_disciplina = d.id_disciplina
JOIN nivel_ensino ne ON s.id_nivel_ensino = ne.id_nivel_ensino
JOIN disponibilidade disp ON p.id_professor = disp.id_professor
    AND disp.ativo = 1
    AND disp.dia_semana = CASE DAYOFWEEK(s.data_aula)
        WHEN 1 THEN 'DOMINGO'
        WHEN 2 THEN 'SEGUNDA'
        WHEN 3 THEN 'TERCA'
        WHEN 4 THEN 'QUARTA'
        WHEN 5 THEN 'QUINTA'
        WHEN 6 THEN 'SEXTA'
        WHEN 7 THEN 'SABADO'
    END
    AND disp.horario_inicio <= s.horario_inicio
    AND disp.horario_fim >= s.horario_fim
LEFT JOIN avaliacao a ON p.id_professor = a.id_professor
WHERE s.id_solicitacao = 1
  AND p.status = 'DISPONIVEL'
GROUP BY 
    p.id_professor, u.nome, u.telefone, p.cidade, p.anos_experiencia,
    d.nome, ne.nome, disp.dia_semana, disp.horario_inicio, disp.horario_fim
ORDER BY media_avaliacoes DESC, p.anos_experiencia DESC;

-- Consulta 8: Histórico de substituições de um professor específico
-- Exemplo: Professor ID 3 (Rodrigo Mendes)
SELECT 
    sub.id_substituicao,
    sub.data_substituicao,
    sub.horario_inicio,
    sub.horario_fim,
    sub.status AS status_substituicao,
    e.nome AS escola,
    d.nome AS disciplina,
    sol.turma,
    av.nota AS nota_recebida,
    av.comentario AS feedback_escola
FROM substituicao sub
INNER JOIN solicitacao_substituicao sol ON sub.id_solicitacao = sol.id_solicitacao
INNER JOIN escola e ON sol.id_escola = e.id_escola
INNER JOIN disciplina d ON sol.id_disciplina = d.id_disciplina
LEFT JOIN avaliacao av ON sub.id_substituicao = av.id_substituicao
WHERE sub.id_professor = 3
ORDER BY sub.data_substituicao DESC;

-- Consulta 9: Média de avaliação e total de avaliações de cada professor
SELECT 
    p.id_professor,
    u.nome AS professor,
    p.anos_experiencia,
    COUNT(a.id_avaliacao) AS total_avaliacoes,
    ROUND(AVG(a.nota), 2) AS media_nota
FROM professor p
INNER JOIN usuario u ON p.id_usuario = u.id_usuario
LEFT JOIN avaliacao a ON p.id_professor = a.id_professor
GROUP BY p.id_professor, u.nome, p.anos_experiencia
ORDER BY media_nota DESC, total_avaliacoes DESC;

-- Consulta 10: Convites pendentes de resposta
SELECT 
    c.id_convite,
    e.nome AS escola_solicitante,
    d.nome AS disciplina,
    s.data_aula,
    s.horario_inicio,
    s.horario_fim,
    u.nome AS professor_convidado,
    u.telefone AS contato_professor,
    c.data_envio,
    c.status AS status_convite
FROM convite c
INNER JOIN solicitacao_substituicao s ON c.id_solicitacao = s.id_solicitacao
INNER JOIN escola e ON s.id_escola = e.id_escola
INNER JOIN disciplina d ON s.id_disciplina = d.id_disciplina
INNER JOIN professor p ON c.id_professor = p.id_professor
INNER JOIN usuario u ON p.id_usuario = u.id_usuario
WHERE c.status = 'PENDENTE'
ORDER BY c.data_envio DESC;

-- Consulta 11: Todas as substituições realizadas por uma escola específica
-- Exemplo: Escola ID 1 (Colégio São Paulo Integrado)
SELECT 
    sub.id_substituicao,
    sub.data_substituicao,
    sub.horario_inicio,
    sub.horario_fim,
    u.nome AS professor_substituto,
    d.nome AS disciplina,
    s.turma,
    sub.status AS status_substituicao,
    a.nota AS nota_atribuida
FROM substituicao sub
INNER JOIN solicitacao_substituicao s ON sub.id_solicitacao = s.id_solicitacao
INNER JOIN professor p ON sub.id_professor = p.id_professor
INNER JOIN usuario u ON p.id_usuario = u.id_usuario
INNER JOIN disciplina d ON s.id_disciplina = d.id_disciplina
LEFT JOIN avaliacao a ON sub.id_substituicao = a.id_substituicao
WHERE s.id_escola = 1
  AND sub.status = 'REALIZADA'
ORDER BY sub.data_substituicao DESC;

-- Consulta 12: Professores mais avaliados (volume de feedbacks e médias)
-- Não impõe classificação fechada, permitindo ao Back-end ponderar volume x qualidade
SELECT 
    p.id_professor,
    u.nome AS professor,
    p.cidade,
    p.anos_experiencia,
    COUNT(a.id_avaliacao) AS qtd_avaliacoes,
    ROUND(AVG(a.nota), 2) AS media_nota,
    MIN(a.nota) AS menor_nota,
    MAX(a.nota) AS maior_nota
FROM professor p
INNER JOIN usuario u ON p.id_usuario = u.id_usuario
INNER JOIN avaliacao a ON p.id_professor = a.id_professor
GROUP BY p.id_professor, u.nome, p.cidade, p.anos_experiencia
ORDER BY qtd_avaliacoes DESC, media_nota DESC;
