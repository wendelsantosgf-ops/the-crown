# The Crown — ativação do MVP
1. No Supabase do **The Crown**, abra SQL Editor e execute `supabase/migrations/20261102_crown_mvp.sql`.
2. Em Vercel → projeto The Crown → Settings → Environment Variables, adicione:
   - `NEXT_PUBLIC_SUPABASE_URL` = Project URL
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY` = chave pública **anon** / publishable (não use service_role ou secret key).
3. Faça um novo deploy depois de salvar as variáveis.
4. Crie sua conta no site e conclua o perfil. Caso o Supabase exija confirmação de e-mail, confirme antes de entrar.
5. No Supabase → Authentication → Users, copie o UUID do **seu** usuário e execute no SQL Editor:
```sql
insert into public.crown_admins(user_id) values ('COLE_SEU_UUID_AQUI')
on conflict do nothing;
```
6. Recarregue a página. Aparecerá Administração, para publicar desafios e aprovar envios.

**Segurança:** nunca coloque a senha do banco, chave `service_role` ou secret key em variáveis `NEXT_PUBLIC_*`. As políticas RLS e funções SQL impedem que usuários se deem pontos ou aprovem as próprias participações. As tabelas são novas e isoladas dos outros projetos.

**Limites do MVP:** autenticação, perfil, desafios, envio para revisão, aprovação e ranking funcionam após configuração. Transmissões, apostas, mensagens, arquivos, imagem de capa, recuperação de senha e moderação avançada não estão implementados. O ranking mostra até 50 perfis. A sessão local é simples e não implementa renovação automática do token: após expirar, o usuário deve entrar novamente.
