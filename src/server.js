import app from "./app.js";
import { testConnection } from "./database/connection.js";

const PORT = process.env.PORT || 3000;

try {
  await testConnection();
  app.listen(PORT, () => {
    console.log(`AulaSempre API rodando em http://localhost:${PORT}`);
  });
} catch (error) {
  console.error("Não foi possível iniciar a API:", error.message);
  process.exit(1);
}