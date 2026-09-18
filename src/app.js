import "dotenv/config";
import express from "express";
import cors from "cors";

import authRoutes from "./routes/auth.routes.js";
import professorRoutes from "./routes/professor.routes.js";
import escolaRoutes from "./routes/escola.routes.js";
import catalogRoutes from "./routes/catalog.routes.js";
import solicitacaoRoutes from "./routes/solicitacao.routes.js";
import conviteRoutes from "./routes/convite.routes.js";
import substituicaoRoutes from "./routes/substituicao.routes.js";

const app = express();

app.use(cors({
  origin: process.env.CORS_ORIGIN || "*"
}));
app.use(express.json());

app.get("/health", (req, res) => {
  res.json({ ok: true, projeto: "AulaSempre API" });
});

app.use("/api/auth", authRoutes);
app.use("/api/professores", professorRoutes);
app.use("/api/escolas", escolaRoutes);
app.use("/api/catalogos", catalogRoutes);
app.use("/api/solicitacoes", solicitacaoRoutes);
app.use("/api/convites", conviteRoutes);
app.use("/api/substituicoes", substituicaoRoutes);

app.use((req, res) => {
  res.status(404).json({ erro: "Rota não encontrada." });
});

app.use((err, req, res, next) => {
  console.error(err);
  res.status(err.status || 500).json({
    erro: err.message || "Erro interno do servidor."
  });
});

export default app;