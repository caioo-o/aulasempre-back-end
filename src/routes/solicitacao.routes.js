import { Router } from "express";
import { pool } from "../database/connection.js";
import { auth } from "../middlewares/auth.js";
import { asyncHandler, requireFields } from "../utils/http.js";

const router = Router();

router.post("/", auth(["ESCOLA"]), asyncHandler(async (req, res) => {
  requireFields(req.body, [
    "id_disciplina", "id_nivel_ensino", "data_aula",
    "horario_inicio", "horario_fim", "turma"
  ]);

  if (!req.user.id_escola) {
    return res.status(400).json({ erro: "Usuário não está vinculado a uma escola." });
  }

  const {
    id_disciplina, id_nivel_ensino, data_aula,
    horario_inicio, horario_fim, turma, observacoes = null
  } = req.body;

  const [result] = await pool.query(`
    INSERT INTO solicitacao_substituicao
    (id_escola, id_disciplina, id_nivel_ensino, data_aula,
     horario_inicio, horario_fim, turma, observacoes)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `, [
    req.user.id_escola, id_disciplina, id_nivel_ensino, data_aula,
    horario_inicio, horario_fim, turma, observacoes
  ]);

  res.status(201).json({
    id_solicitacao: result.insertId,
    status: "ABERTA"
  });
}));

router.get("/", auth(), asyncHandler(async (req, res) => {
  const { status } = req.query;

  let sql = `
    SELECT s.id_solicitacao, e.id_escola, e.nome AS escola,
           e.cidade AS cidade_escola, e.estado AS estado_escola,
           d.id_disciplina, d.nome AS disciplina,
           ne.id_nivel_ensino, ne.nome AS nivel_ensino,
           s.data_aula, s.horario_inicio, s.horario_fim,
           s.turma, s.observacoes, s.status, s.data_criacao
    FROM solicitacao_substituicao s
    JOIN escola e ON e.id_escola = s.id_escola
    JOIN disciplina d ON d.id_disciplina = s.id_disciplina
    JOIN nivel_ensino ne ON ne.id_nivel_ensino = s.id_nivel_ensino
    WHERE 1 = 1
  `;
  const params = [];

  if (req.user.tipo_usuario === "ESCOLA") {
    sql += " AND s.id_escola = ?";
    params.push(req.user.id_escola);
  }

  if (status) {
    sql += " AND s.status = ?";
    params.push(status);
  }

  sql += " ORDER BY s.data_aula, s.horario_inicio";

  const [rows] = await pool.query(sql, params);
  res.json(rows);
}));

router.get("/:id", auth(), asyncHandler(async (req, res) => {
  const [rows] = await pool.query(`
    SELECT s.*, e.nome AS escola, e.cidade AS cidade_escola,
           e.estado AS estado_escola, d.nome AS disciplina,
           ne.nome AS nivel_ensino
    FROM solicitacao_substituicao s
    JOIN escola e ON e.id_escola = s.id_escola
    JOIN disciplina d ON d.id_disciplina = s.id_disciplina
    JOIN nivel_ensino ne ON ne.id_nivel_ensino = s.id_nivel_ensino
    WHERE s.id_solicitacao = ?
  `, [req.params.id]);

  if (!rows.length) return res.status(404).json({ erro: "Solicitação não encontrada." });

  const item = rows[0];

  if (req.user.tipo_usuario === "ESCOLA" && item.id_escola !== req.user.id_escola) {
    return res.status(403).json({ erro: "Sem permissão." });
  }

  res.json(item);
}));

router.get("/:id/matches", auth(["ESCOLA"]), asyncHandler(async (req, res) => {
  const [solicitacoes] = await pool.query(
    "SELECT * FROM solicitacao_substituicao WHERE id_solicitacao = ? AND id_escola = ?",
    [req.params.id, req.user.id_escola]
  );

  if (!solicitacoes.length) {
    return res.status(404).json({ erro: "Solicitação não encontrada." });
  }

  const [rows] = await pool.query(`
    SELECT
      p.id_professor,
      u.nome AS professor,
      u.telefone,
      p.cidade,
      p.estado,
      p.anos_experiencia,
      p.status,
      COALESCE(ROUND(AVG(a.nota), 1), 0.0) AS media_avaliacoes
    FROM solicitacao_substituicao s
    JOIN professor_disciplina pd
      ON s.id_disciplina = pd.id_disciplina
    JOIN professor_nivel_ensino pne
      ON s.id_nivel_ensino = pne.id_nivel_ensino
     AND pd.id_professor = pne.id_professor
    JOIN professor p
      ON p.id_professor = pd.id_professor
    JOIN usuario u
      ON p.id_usuario = u.id_usuario
    JOIN disponibilidade disp
      ON disp.id_professor = p.id_professor
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
    LEFT JOIN avaliacao a
      ON a.id_professor = p.id_professor
    WHERE s.id_solicitacao = ?
      AND p.status = 'DISPONIVEL'
    GROUP BY p.id_professor, u.nome, u.telefone,
             p.cidade, p.estado, p.anos_experiencia, p.status
    ORDER BY media_avaliacoes DESC, p.anos_experiencia DESC
  `, [req.params.id]);

  res.json(rows);
}));

router.patch("/:id/status", auth(["ESCOLA"]), asyncHandler(async (req, res) => {
  const allowed = ["ABERTA", "EM_PROCESSO", "PREENCHIDA", "CONCLUIDA", "CANCELADA"];

  if (!allowed.includes(req.body.status)) {
    return res.status(400).json({ erro: "Status inválido." });
  }

  const [result] = await pool.query(`
    UPDATE solicitacao_substituicao
    SET status = ?
    WHERE id_solicitacao = ? AND id_escola = ?
  `, [req.body.status, req.params.id, req.user.id_escola]);

  if (!result.affectedRows) {
    return res.status(404).json({ erro: "Solicitação não encontrada." });
  }

  res.json({ mensagem: "Status atualizado." });
}));

export default router;