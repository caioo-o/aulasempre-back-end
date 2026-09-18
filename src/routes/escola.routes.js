import { Router } from "express";
import { pool } from "../database/connection.js";
import { auth } from "../middlewares/auth.js";
import { asyncHandler } from "../utils/http.js";

const router = Router();

router.get("/me", auth(["ESCOLA"]), asyncHandler(async (req, res) => {
  if (!req.user.id_escola) {
    return res.status(404).json({ erro: "Usuário não está vinculado a uma escola." });
  }

  const [rows] = await pool.query(
    "SELECT * FROM escola WHERE id_escola = ?",
    [req.user.id_escola]
  );

  if (!rows.length) return res.status(404).json({ erro: "Escola não encontrada." });
  res.json(rows[0]);
}));

export default router;