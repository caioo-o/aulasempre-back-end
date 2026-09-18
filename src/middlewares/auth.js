import jwt from "jsonwebtoken";

export function auth(requiredRoles = []) {
  return (req, res, next) => {
    const header = req.headers.authorization;

    if (!header?.startsWith("Bearer ")) {
      return res.status(401).json({ erro: "Token não informado." });
    }

    try {
      const token = header.slice(7);
      const payload = jwt.verify(token, process.env.JWT_SECRET);

      if (requiredRoles.length && !requiredRoles.includes(payload.tipo_usuario)) {
        return res.status(403).json({ erro: "Usuário sem permissão para esta operação." });
      }

      req.user = payload;
      next();
    } catch {
      return res.status(401).json({ erro: "Token inválido ou expirado." });
    }
  };
}