export function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

export function requireFields(body, fields) {
  const missing = fields.filter((field) =>
    body[field] === undefined || body[field] === null || body[field] === ""
  );

  if (missing.length) {
    const error = new Error(`Campos obrigatórios: ${missing.join(", ")}`);
    error.status = 400;
    throw error;
  }
}