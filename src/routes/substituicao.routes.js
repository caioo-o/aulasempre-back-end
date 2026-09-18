import { Router } from "express";
import { pool } from "../database/connection.js";
import { auth } from "../middlewares/auth.js";
import { asyncHandler, requireFields } from "../utils/http.js";

const router = Router();

router.get("/", auth(), asyncHandler(async (req, res) => {
  let sql = `
    SELECT sub.id_substituicao, sub.id_solicitacao, sub.id_professor,
           sub.data_substituicao, sub.horario_inicio, sub.horario_fim,
           sub.status, sub.observacoes,
           e.id_escola, e.nome AS escola,
           d.id_disciplina, d.nome AS disciplina,
           s.turma
    FROM substituicao sub
    JOIN solicitacao_substituicao s ON s.id_solicitacao = sub.id_solicitacao
    JOIN escola e ON e.id_escola = s.id_escola
    JOIN disciplina d ON d.id_disciplina = s.id_disciplina
    WHERE 1 = 1
  `;
  const params = [];

  if (req.user.tipo_usuario === "ESCOLA") {
    sql += " AND s.id_escola = ?";
    params.push(req.user.id_escola);
  } else {
    const [p] = await pool.query(
      "SELECT id_professor FROM professor WHERE id_usuario = ?",
      [req.user.id_usuario]
    );
    if (!p.length) return res.json([]);
    sql += " AND sub.id_professor = ?";
    params.push(p[0].id_professor);
  }

  sql += " ORDER BY sub.data_substituicao DESC, sub.horario_inicio DESC";

  const [rows] = await pool.query(sql, params);
  res.json(rows);
}));

router.patch("/:id/status", auth(), asyncHandler(async (req, res) => {
  const allowed = ["AGENDADA", "EM_ANDAMENTO", "REALIZADA", "CANCELADA", "FALTA_PROFESSOR"];

  if (!allowed.includes(req.body.status)) {
    return res.status(400).json({ erro: "Status inválido." });
  }

  const [rows] = await pool.query(`
    SELECT sub.*, s.id_escola
    FROM substituicao sub
    JOIN solicitacao_substituicao s ON s.id_solicitacao = sub.id_solicitacao
    WHERE sub.id_substituicao = ?
  `, [req.params.id]);

  if (!rows.length) return res.status(404).json({ erro: "Substituição não encontrada." });

  const item = rows[0];

  let autorizado = false;

  if (req.user.tipo_usuario === "ESCOLA") {
    autorizado = item.id_escola === req.user.id_escola;
  } else {
    const [p] = await pool.query(
      "SELECT id_professor FROM professor WHERE id_usuario = ?",
      [req.user.id_usuario]
    );
    autorizado = p.length && p[0].id_professor === item.id_professor;
  }

  if (!autorizado) return res.status(403).json({ erro: "Sem permissão." });

  await pool.query(
    "UPDATE substituicao SET status = ? WHERE id_substituicao = ?",
    [req.body.status, req.params.id]
  );

  res.json({ mensagem: "Status da substituição atualizado." });
}));

router.post("/:id/avaliacao", auth(["ESCOLA"]), asyncHandler(async (req, res) => {
  requireFields(req.body, ["nota"]);

  const nota = Number(req.body.nota);

  if (!Number.isInteger(nota) || nota < 1 || nota > 5) {
    return res.status(400).json({ erro: "A nota deve ser um número inteiro de 1 a 5." });
  }

  const [rows] = await pool.query(`
    SELECT sub.id_substituicao, sub.id_professor, sub.status, s.id_escola
    FROM substituicao sub
    JOIN solicitacao_substituicao s ON s.id_solicitacao = sub.id_solicitacao
    WHERE sub.id_substituicao = ?
  `, [req.params.id]);

  if (!rows.length) return res.status(404).json({ erro: "Substituição não encontrada." });

  const item = rows[0];

  if (item.id_escola !== req.user.id_escola) {
    return res.status(403).json({ erro: "Você não pode avaliar uma substituição de outra escola." });
  }

  if (item.status !== "REALIZADA") {
    return res.status(400).json({ erro: "A avaliação só pode ser feita após a substituição ser realizada." });
  }

  try {
    const [result] = await pool.query(`
      INSERT INTO avaliacao
      (id_substituicao, id_professor, nota, comentario)
      VALUES (?, ?, ?, ?)
    `, [
      req.params.id,
      item.id_professor,
      nota,
      req.body.comentario || null
    ]);

    res.status(201).json({ id_avaliacao: result.insertId });
  } catch (error) {
    if (error.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ erro: "Esta substituição já possui avaliação." });
    }
    throw error;
  }
}));

router.get("/:id/avaliacao", auth(), asyncHandler(async (req, res) => {
  const [rows] = await pool.query(`
    SELECT a.*
    FROM avaliacao a
    JOIN substituicao sub ON sub.id_substituicao = a.id_substituicao
    JOIN solicitacao_substituicao s ON s.id_solicitacao = sub.id_solicitacao
    WHERE a.id_substituicao = ?
  `, [req.params.id]);

  if (!rows.length) return res.status(404).json({ erro: "Avaliação não encontrada." });

  res.json(rows[0]);
}));

export default router;