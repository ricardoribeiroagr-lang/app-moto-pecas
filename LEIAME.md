# App Moto Peças Faxinal: o que falta para colocar no ar

O app já está configurado com:
- o projeto do Supabase (URL e chave publishable);
- a logo e os dados da empresa no PDF da OS;
- a moto 3D (`moto.glb`) com as peças clicáveis;
- o ícone para "Adicionar à tela inicial" no celular.

Faltam três passos, todos no computador.

## 1. Criar o banco (uma vez só)

1. Entre em https://supabase.com e abra o projeto.
2. No menu lateral, clique em **SQL Editor** e depois em **New query**.
3. Abra o arquivo `schema.sql` desta pasta no Bloco de Notas, copie tudo (Ctrl+A, Ctrl+C), cole no editor e clique em **Run**.
   O resultado deve ser "Success. No rows returned".
4. Em **Authentication → Sign In / Providers**, desligue **Allow new users to sign up**.

## 2. Criar os logins da equipe

Em **Authentication → Users → Add user → Create new user**, informe o e-mail e a senha de cada pessoa.
Marque **Auto Confirm User** para que a pessoa já consiga entrar.

## 3. Colocar no ar (Netlify)

1. Acesse https://app.netlify.com/drop e entre (ou crie uma conta grátis).
2. Arraste a pasta **`app`** (não a pasta de fora) para a página.
3. Você recebe um link. Em **Site configuration → Change site name**, dá para trocar por algo como `motopecasfaxinal.netlify.app`.
4. No celular, abra o link e use **Adicionar à tela inicial**.

Para atualizar o app no futuro, abra o site na Netlify, vá em **Deploys** e arraste a pasta `app` de novo.

## Catálogo pelo app (administrador)

Entrando com **ricardoribeiro94@hotmail.com**, aparece o botão **Catálogo** no topo. Por ele você:
- cadastra peças e serviços, muda preço e horas de mão de obra e desativa o que não usa;
- cadastra modelos de moto e o ajuste de preço de cada um;
- define o valor padrão da hora e do km de deslocamento.

Os outros usuários veem e usam os preços, mas não alteram. Para incluir outro administrador, rode no SQL Editor do Supabase:
`insert into admins (email) values ('email@exemplo.com');`

## Instalar no celular

- **Android / computador (Chrome ou Edge):** toque em **Instalar app** no topo do app (ou no menu ⋮ → Instalar app).
- **iPhone (Safari):** Compartilhar → **Adicionar à Tela de Início**.

## Atualizações

O site na Netlify está ligado ao GitHub (repositório privado `app-moto-pecas`). Toda alteração enviada ao repositório é publicada sozinha.

## Ajustes do dia a dia

- **Preços e serviços:** Supabase → **Table Editor → catalogo**. `preco` é o preço da peça no modelo base (CG 160) e `horas` é a mão de obra. Para tirar um serviço do app sem apagar o histórico, marque `ativo = false`.
- **Modelos de moto:** tabela `modelos`. O `multiplicador` ajusta o preço das peças por modelo.
- **Dados da empresa, valor da hora, valor padrão do km de deslocamento e texto do PDF:** bloco CONFIGURAÇÃO no início do `app/index.html`.

## Crédito do modelo 3D

"Motorcycle", de Silas6 (Sketchfab), licença CC BY 4.0. O crédito já aparece no app e precisa continuar visível.
