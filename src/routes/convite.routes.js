import { Router } from "express";
import { pool } from "../database/connection.js";
import { auth } from "../middlewares/auth.js";
import { asyncHandler, requireFields } from "../utils/http.js";

const router = Router();

router.post("/", auth(["ESCOLA"]), asyncHandler(async (req, res) => {
  requireFields(req.body, ["id_solicitacao", "id_professor"]);

  const [sol] = await pool.query(
    "SELECT * FROM solicitacao_substituicao WHERE id_solicitacao = ? AND id_escola = ?",
    [req.body.id_solicitacao, req.user.id_escola]
  );

  if (!sol.length) return res.status(404).json({ erro: "Solicitação não encontrada." });

  const [match] = await pool.query(`
    SELECT p.id_professor
    FROM professor p
    JOIN professor_disciplina pd ON pd.id_professor = p.id_professor
    JOIN professor_nivel_ensino pne ON pne.id_professor = p.id_professor
    WHERE p.id_professor = ?
      AND pd.id_disciplina = ?
      AND pne.id_nivel_ensino = ?
      AND p.status = 'DISPONIVEL'
  `, [
    req.body.id_professor,
    sol[0].id_disciplina,
    sol[0].id_nivel_ensino
  ]);

  if (!match.length) {
    return res.status(400).json({ erro: "Professor não atende aos critérios básicos da solicitação." });
  }

  try {
    const [result] = await pool.query(`
      INSERT INTO convite (id_solicitacao, id_professor, observacao)
      VALUES (?, ?, ?)
    `, [
      req.body.id_solicitacao,
      req.body.id_professor,
      req.body.observacao || null
    ]);

    await pool.query(
      "UPDATE solicitacao_substituicao SET status = 'EM_PROCESSO' WHERE id_solicitacao = ?",
      [req.body.id_solicitacao]
    );

    res.status(201).json({ id_convite: result.insertId, status: "PENDENTE" });
  } catch (error) {
    if (error.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ erro: "Já existe convite para este professor nessa solicitação." });
    }
    throw error;
  }
}));

router.get("/", auth(), asyncHandler(async (req, res) => {
  let sql = `
    SELECT c.id_convite, c.id_solicitacao, c.id_professor,
           c.data_envio, c.data_resposta, c.status, c.observacao,
           e.nome AS escola, d.nome AS disciplina,
           s.data_aula, s.horario_inicio, s.horario_fim, s.turma
    FROM convite c
    JOIN solicitacao_substituicao s ON s.id_solicitacao = c.id_solicitacao
    JOIN escola e ON e.id_escola = s.id_escola
    JOIN disciplina d ON d.id_disciplina = s.id_disciplina
    WHERE 1 = 1
  `;
  const params = [];

  if (req.user.tipo_usuario === "PROFESSOR") {
    const [p] = await pool.query(
      "SELECT id_professor FROM professor WHERE id_usuario = ?",
      [req.user.id_usuario]
    );

    if (!p.length) return res.json([]);

    sql += " AND c.id_professor = ?";
    params.push(p[0].id_professor);
  } else {
    sql += " AND s.id_escola = ?";
    params.push(req.user.id_escola);
  }

  sql += " ORDER BY c.data_envio DESC";

  const [rows] = await pool.query(sql, params);
  res.json(rows);
}));

router.patch("/:id/resposta", auth(["PROFESSOR"]), asyncHandler(async (req, res) => {
  if (!["ACEITO", "RECUSADO"].includes(req.body.status)) {
    return res.status(400).json({ erro: "status deve ser ACEITO ou RECUSADO." });
  }

  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    const [professor] = await connection.query(
      "SELECT id_professor FROM professor WHERE id_usuario = ? FOR UPDATE",
      [req.user.id_usuario]
    );

    if (!professor.length) {
      await connection.rollback();
      return res.status(404).json({ erro: "Perfil de professor não encontrado." });
    }

    const idProfessor = professor[0].id_professor;

    const [convites] = await connection.query(`
      SELECT c.*, s.data_aula, s.horario_inicio, s.horario_fim, s.id_escola
      FROM convite c
      JOIN solicitacao_substituicao s ON s.id_solicitacao = c.id_solicitacao
      WHERE c.id_convite = ? AND c.id_professor = ?
      FOR UPDATE
    `, [req.params.id, idProfessor]);

    if (!convites.length) {
      await connection.rollback();
      return res.status(404).json({ erro: "Convite não encontrado." });
    }

    const convite = convites[0];

    if (convite.status !== "PENDENTE") {
      await connection.rollback();
      return res.status(409).json({ erro: "Este convite já foi respondido." });
    }

    const agora = new Date();

    if (req.body.status === "RECUSADO") {
      await connection.query(`
        UPDATE convite
        SET status = 'RECUSADO', data_resposta = ?, observacao = ?
        WHERE id_convite = ?
      `, [agora, req.body.observacao || null, req.params.id]);

      await connection.commit();
      return res.json({ mensagem: "Convite recusado." });
    }

    const [conflitos] = await connection.query(`
      SELECT id_substituicao
      FROM substituicao
      WHERE id_professor = ?
        AND status IN ('AGENDADA', 'EM_ANDAMENTO')
        AND data_substituicao = ?
        AND horario_inicio < ?
        AND horario_fim > ?
      FOR UPDATE
    `, [
      idProfessor,
      convite.data_aula,
      convite.horario_fim,
      convite.horario_inicio
    ]);

    if (conflitos.length) {
      await connection.rollback();
      return res.status(409).json({ erro: "Professor já possui substituição nesse horário." });
    }

    await connection.query(`
      UPDATE convite
      SET status = 'ACEITO', data_resposta = ?, observacao = ?
      WHERE id_convite = ?
    `, [agora, req.body.observacao || null, req.params.id]);

    await connection.query(`
      INSERT INTO substituicao
      (id_solicitacao, id_professor, id_convite, data_substituicao,
       horario_inicio, horario_fim, status)
      VALUES (?, ?, ?, ?, ?, ?, 'AGENDADA')
    `, [
      convite.id_solicitacao,
      idProfessor,
      convite.id_convite,
      convite.data_aula,
      convite.horario_inicio,
      convite.horario_fim
    ]);

    await connection.query(`
      UPDATE solicitacao_substituicao
      SET status = 'PREENCHIDA'
      WHERE id_solicitacao = ?
    `, [convite.id_solicitacao]);

    await connection.query(`
      UPDATE professor
      SET status = 'EM_SUBSTITUICAO'
      WHERE id_professor = ?
    `, [idProfessor]);

    await connection.commit();

    res.json({ mensagem: "Convite aceito e substituição agendada." });
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}));

export default router;