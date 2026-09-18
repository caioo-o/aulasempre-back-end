# Roteiro rápido de testes no Postman

## 1. Health

GET `http://localhost:3000/health`

## 2. Login

POST `http://localhost:3000/api/auth/login`

```json
{
  "email": "seu-email",
  "senha": "sua-senha"
}
```

Copie o `token`.

## 3. Listar disciplinas

GET `http://localhost:3000/api/catalogos/disciplinas`

## 4. Listar níveis

GET `http://localhost:3000/api/catalogos/niveis-ensino`

## 5. Criar solicitação como escola

POST `http://localhost:3000/api/solicitacoes`

Header:

`Authorization: Bearer TOKEN`

Body:

```json
{
  "id_disciplina": 1,
  "id_nivel_ensino": 4,
  "data_aula": "2026-09-21",
  "horario_inicio": "07:30:00",
  "horario_fim": "11:30:00",
  "turma": "3º Ano B - Médio",
  "observacoes": "Geometria Analítica."
}
```

## 6. Match

GET `http://localhost:3000/api/solicitacoes/1/matches`

## 7. Convite

POST `http://localhost:3000/api/convites`

```json
{
  "id_solicitacao": 1,
  "id_professor": 1
}
```

## 8. Professor responde

PATCH `http://localhost:3000/api/convites/1/resposta`

```json
{
  "status": "ACEITO"
}
```

Isso deve criar uma substituição `AGENDADA`.

## 9. Marcar como realizada

PATCH `http://localhost:3000/api/substituicoes/ID/status`

```json
{
  "status": "REALIZADA"
}
```

## 10. Avaliar

POST `http://localhost:3000/api/substituicoes/ID/avaliacao`

```json
{
  "nota": 5,
  "comentario": "Excelente aula."
}
```
