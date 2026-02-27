# KesherApp — plano de ação para corrigir autenticação/cadastro

Objetivo: corrigir o login do `super_admin` de forma reproduzível.

## Sintoma reportado

Tela de admin retorna: **"Erro de Autenticação — Credenciais inválidas"**.

Interpretação técnica: o backend está respondendo caminho de falha de login (normalmente `401`), causado por usuário não encontrado, senha inválida, usuário bloqueado/inativo ou inconsistência de ambiente.

## Bloqueio atual deste ambiente

Acesso ao GitHub externo está bloqueado aqui (`CONNECT tunnel failed, response 403`), então não consigo abrir o código do `KesherAppnew` diretamente deste container.

## Passo 1 — Diagnóstico no banco (execute no ambiente do app)

```sql
-- 1) Encontrar usuário por email (normalizado)
SELECT id, email, role, is_active, blocked, password_hash
FROM users
WHERE lower(trim(email)) = 'fabiosilva@fabiosilva.com.br';

-- 2) Checar duplicidade por case
SELECT lower(trim(email)) AS normalized_email, count(*)
FROM users
GROUP BY lower(trim(email))
HAVING count(*) > 1;
```

Critérios esperados:
- usuário existe
- `role = super_admin`
- ativo e não bloqueado
- senha armazenada em hash

## Passo 2 — Reset seguro do super admin

1. Rotacione a senha imediatamente (credencial exposta).
2. Gere hash no mesmo serviço usado no login.
3. Atualize `password_hash` com o novo hash.

> Importante: nunca salvar senha em texto puro em seed/migration.

## Passo 3 — Verificação no backend (código)

Checklist mínimo no endpoint de login:
- normaliza email com `trim().toLowerCase()`
- busca usuário por email normalizado
- valida `isActive`/`blocked`
- compara senha com função de `compare`
- emite token com role `super_admin`

## Passo 4 — Vercel (itens que mais quebram login)

No projeto da API no Vercel, valide:
- `DATABASE_URL` apontando para o banco correto (produção vs homologação)
- `JWT_SECRET` presente e não vazio
- `NODE_ENV=production`
- variáveis de hash/crypto iguais ao ambiente onde usuário foi criado

Depois de ajustar variáveis, faça **redeploy**.

## Passo 5 — Logs de diagnóstico (sem dados sensíveis)

Padronize motivo de falha:
- `USER_NOT_FOUND`
- `USER_INACTIVE`
- `USER_BLOCKED`
- `INVALID_PASSWORD`
- `ROLE_NOT_ALLOWED`

No Vercel, confira os logs da função na tentativa de login para identificar o motivo real.

## Passo 6 — Testes manuais objetivos

1. Login com super admin após reset de senha.
2. Confirmar HTTP 200 e token válido.
3. Acessar rota protegida de admin com esse token.
4. Confirmar acesso negado para usuário sem `super_admin`.

Exemplo de teste direto no endpoint (troque URL e senha):

```bash
curl -i -X POST https://SEU-DOMINIO.vercel.app/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"fabiosilva@fabiosilva.com.br","password":"SENHA_NOVA"}'
```

## Passo 7 — Hardening recomendado

- Forçar troca de senha no próximo login de contas administrativas.
- Habilitar MFA para `super_admin`.
- Adicionar rate-limit no endpoint de login.

## Execução rápida (script)

Para validar login + acesso admin de ponta a ponta, use:

```bash
BASE_URL="https://SEU-DOMINIO.vercel.app" \
ADMIN_EMAIL="fabiosilva@fabiosilva.com.br" \
ADMIN_PASSWORD="SENHA_NOVA" \
./engineering/scripts/kesherapp-auth-smoke.sh
```

Se suas rotas forem diferentes, ajuste:

```bash
LOGIN_PATH="/api/auth/login" \
ADMIN_PATH="/api/admin/me" \
BASE_URL="https://SEU-DOMINIO.vercel.app" \
ADMIN_EMAIL="fabiosilva@fabiosilva.com.br" \
ADMIN_PASSWORD="SENHA_NOVA" \
./engineering/scripts/kesherapp-auth-smoke.sh
```
