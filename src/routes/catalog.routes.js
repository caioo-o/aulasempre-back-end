import { Router } from "express";
import { pool } from "../database/connection.js";
import { asyncHandler } from "../utils/http.js";

const router = Router();

router.get("/disciplinas", asyncHandler(async (req, res) => {
  const [rows] = await pool.query(
    "SELECT id_disciplina, nome, descricao, ativo FROM disciplina WHERE ativo = 1 ORDER BY nome"
  );
  res.json(rows);
}));

router.get("/niveis-ensino", asyncHandler(async (req, res) => {
  const [rows] = await pool.query(
    "SELECT id_nivel_ensino, nome, descricao, ativo FROM nivel_ensino WHERE ativo = 1 ORDER BY id_nivel_ensino"
  );
  res.json(rows);
}));

export default router;