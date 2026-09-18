import { Router } from "express";
import { pool } from "../database/connection.js";
import { auth } from "../middlewares/auth.js";
import { asyncHandler, requireFields } from "../utils/http.js";

const router = Router();

router.get("/", auth(), asyncHandler(async (req, res) => {
  const { cidade, estado, status } = req.query;

  let sql = `
    SELECT p.id_professor, u.id_usuario, u.nome, u.email, u.telefone,
           p.nome_profissional, p.descricao, p.anos_experiencia,
           p.cidade, p.estado, p.status
    FROM professor p
    JOIN usuario u ON p.id_usuario = u.id_usuario
    WHERE u.ativo = 1
  `;
  const params = [];

  if (cidade) { sql += " AND p.cidade = ?"; params.push(cidade); }
  if (estado) { sql += " AND p.estado = ?"; params.push(estado); }
  if (status) { sql += " AND p.status = ?"; params.push(status); }

  sql += " ORDER BY u.nome";

  const [rows] = await pool.query(sql, params);
  res.json(rows);
}));

router.get("/:id", auth(), asyncHandler(async (req, res) => {
  const [rows] = await pool.query(`
    SELECT p.*, u.nome, u.email, u.telefone
    FROM professor p
    JOIN usuario u ON p.id_usuario = u.id_usuario
    WHERE p.id_professor = ?
  `, [req.params.id]);

  if (!rows.length) return res.status(404).json({ erro: "Professor não encontrado." });

  const professor = rows[0];

  const [formacoes] = await pool.query(
    "SELECT * FROM formacao WHERE id_professor = ? ORDER BY ano_conclusao DESC",
    [req.params.id]
  );

  const [disciplinas] = await pool.query(`
    SELECT d.id_disciplina, d.nome, d.descricao
    FROM professor_disciplina pd
    JOIN disciplina d ON d.id_disciplina = pd.id_disciplina
    WHERE pd.id_professor = ?
    ORDER BY d.nome
  `, [req.params.id]);

  const [niveis] = await pool.query(`
    SELECT ne.id_nivel_ensino, ne.nome, ne.descricao
    FROM professor_nivel_ensino pne
    JOIN nivel_ensino ne ON ne.id_nivel_ensino = pne.id_nivel_ensino
    WHERE pne.id_professor = ?
    ORDER BY ne.id_nivel_ensino
  `, [req.params.id]);

  const [disponibilidades] = await pool.query(
    "SELECT * FROM disponibilidade WHERE id_professor = ? AND ativo = 1 ORDER BY dia_semana, horario_inicio",
    [req.params.id]
  );

  const [avaliacoes] = await pool.query(`
    SELECT id_avaliacao, nota, comentario, data_avaliacao
    FROM avaliacao WHERE id_professor = ?
    ORDER BY data_avaliacao DESC
  `, [req.params.id]);

  res.json({ ...professor, formacoes, disciplinas, niveis_ensino: niveis, disponibilidades, avaliacoes });
}));

router.post("/", auth(["PROFESSOR"]), asyncHandler(async (req, res) => {
  requireFields(req.body, ["cidade", "estado"]);

  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    const [userRows] = await connection.query(
      "SELECT id_usuario, tipo_usuario FROM usuario WHERE id_usuario = ? AND ativo = 1",
      [req.user.id_usuario]
    );

    if (!userRows.length || userRows[0].tipo_usuario !== "PROFESSOR") {
      await connection.rollback();
      return res.status(400).json({ erro: "Usuário não é um professor válido." });
    }

    const [already] = await connection.query(
      "SELECT id_professor FROM professor WHERE id_usuario = ?",
      [req.user.id_usuario]
    );

    if (already.length) {
      await connection.rollback();
      return res.status(409).json({ erro: "Perfil de professor já existe." });
    }

    const {
      nome_profissional = null,
      descricao = null,
      anos_experiencia = 0,
      cidade,
      estado,
      status = "DISPONIVEL"
    } = req.body;

    const [result] = await connection.query(`
      INSERT INTO professor
      (id_usuario, nome_profissional, descricao, anos_experiencia, cidade, estado, status)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `, [req.user.id_usuario, nome_profissional, descricao, anos_experiencia, cidade, estado, status]);

    await connection.commit();
    res.status(201).json({ id_professor: result.insertId });
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}));

router.put("/:id", auth(["PROFESSOR"]), asyncHandler(async (req, res) => {
  const [owner] = await pool.query(
    "SELECT id_usuario FROM professor WHERE id_professor = ?",
    [req.params.id]
  );

  if (!owner.length || owner[0].id_usuario !== req.user.id_usuario) {
    return res.status(403).json({ erro: "Você só pode editar seu próprio perfil." });
  }

  const allowed = ["nome_profissional", "descricao", "anos_experiencia", "cidade", "estado", "status"];
  const fields = [];
  const values = [];

  for (const field of allowed) {
    if (req.body[field] !== undefined) {
      fields.push(`${field} = ?`);
      values.push(req.body[field]);
    }
  }

  if (!fields.length) return res.status(400).json({ erro: "Nenhum campo para atualizar." });

  values.push(req.params.id);

  await pool.query(`UPDATE professor SET ${fields.join(", ")} WHERE id_professor = ?`, values);
  res.json({ mensagem: "Perfil atualizado." });
}));

router.get("/:id/substituicoes", auth(), asyncHandler(async (req, res) => {
  const [rows] = await pool.query(`
    SELECT sub.id_substituicao, sub.data_substituicao, sub.horario_inicio,
           sub.horario_fim, sub.status AS status_substituicao,
           e.nome AS escola, d.nome AS disciplina, s.turma,
           av.nota, av.comentario AS feedback_escola
    FROM substituicao sub
    JOIN solicitacao_substituicao s ON s.id_solicitacao = sub.id_solicitacao
    JOIN escola e ON e.id_escola = s.id_escola
    JOIN disciplina d ON d.id_disciplina = s.id_disciplina
    LEFT JOIN avaliacao av ON av.id_substituicao = sub.id_substituicao
    WHERE sub.id_professor = ?
    ORDER BY sub.data_substituicao DESC
  `, [req.params.id]);

  res.json(rows);
}));

router.post("/:id/disponibilidade", auth(["PROFESSOR"]), asyncHandler(async (req, res) => {
  requireFields(req.body, ["dia_semana", "horario_inicio", "horario_fim"]);

  const [owner] = await pool.query(
    "SELECT id_usuario FROM professor WHERE id_professor = ?",
    [req.params.id]
  );

  if (!owner.length || owner[0].id_usuario !== req.user.id_usuario) {
    return res.status(403).json({ erro: "Você só pode alterar sua disponibilidade." });
  }

  const [result] = await pool.query(`
    INSERT INTO disponibilidade
    (id_professor, dia_semana, horario_inicio, horario_fim)
    VALUES (?, ?, ?, ?)
  `, [
    req.params.id,
    req.body.dia_semana,
    req.body.horario_inicio,
    req.body.horario_fim
  ]);

  res.status(201).json({ id_disponibilidade: result.insertId });
}));

export default router;