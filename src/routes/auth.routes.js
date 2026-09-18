import { Router } from "express";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { pool } from "../database/connection.js";
import { asyncHandler, requireFields } from "../utils/http.js";

const router = Router();

router.post("/login", asyncHandler(async (req, res) => {
  requireFields(req.body, ["email", "senha"]);

  const [rows] = await pool.query(
    `SELECT id_usuario, id_escola, nome, email, senha, telefone, tipo_usuario, ativo
     FROM usuario WHERE email = ? LIMIT 1`,
    [req.body.email]
  );

  if (!rows.length || !rows[0].ativo) {
    return res.status(401).json({ erro: "E-mail ou senha inválidos." });
  }

  const user = rows[0];
  const senhaValida = await bcrypt.compare(req.body.senha, user.senha);

  if (!senhaValida) {
    return res.status(401).json({ erro: "E-mail ou senha inválidos." });
  }

  const token = jwt.sign(
    {
      id_usuario: user.id_usuario,
      id_escola: user.id_escola,
      tipo_usuario: user.tipo_usuario
    },
    process.env.JWT_SECRET,
    { expiresIn: "8h" }
  );

  delete user.senha;

  res.json({ token, usuario: user });
}));

router.post("/cadastro", asyncHandler(async (req, res) => {
  requireFields(req.body, ["nome", "email", "senha", "tipo_usuario"]);

  const { nome, email, senha, telefone, tipo_usuario, id_escola = null } = req.body;

  if (!["ESCOLA", "PROFESSOR"].includes(tipo_usuario)) {
    return res.status(400).json({ erro: "tipo_usuario deve ser ESCOLA ou PROFESSOR." });
  }

  const [existing] = await pool.query(
    "SELECT id_usuario FROM usuario WHERE email = ?",
    [email]
  );

  if (existing.length) {
    return res.status(409).json({ erro: "E-mail já cadastrado." });
  }

  const hash = await bcrypt.hash(senha, 10);

  const [result] = await pool.query(
    `INSERT INTO usuario
      (id_escola, nome, email, senha, telefone, tipo_usuario)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [id_escola, nome, email, hash, telefone || null, tipo_usuario]
  );

  res.status(201).json({
    id_usuario: result.insertId,
    mensagem: "Usuário cadastrado com sucesso."
  });
}));

export default router;