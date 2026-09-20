# discourse-westan-vip-painel

Plugin Discourse **Ajustes do Premium**. Integra as cores do antigo `vip-westan` ao painel, preservando `/vip-painel` e os campos salvos.

## Acesso

| Membro | Recursos |
| --- | --- |
| Assinante no grupo `westan_vip_painel_premium_group` | Cores, selo verificado, título, catálogo de badges e badge próprio |
| VIP apenas no grupo `westan_vip_painel_group` | Escolha da cor, na tela **Ajuste do VIP** |
| Sem nenhum dos grupos | Sem acesso para salvar ajustes |

Padrões: `vip_elegivel` para assinantes pagantes; `vip` para VIP geral/resgatado. A assinatura é reconhecida pela participação no grupo, não pelo pagamento em si: a administração continua incluindo/removendo os pagantes manualmente. Ser administrador não concede automaticamente a aparência Premium.

As permissões são verificadas no servidor. Campos Premium enviados por um VIP resgatado são rejeitados. Ao perder o grupo, os efeitos deixam de ser expostos, mas suas preferências são preservadas. Se o Westan Pontos estiver instalado, a validade do VIP resgatado é conferida ao abrir/salvar o painel; a remoção agendada continua sendo responsabilidade do plugin de pontos.

## Migração dos dois plugins para um

1. Anote o valor de `vip_color_field_id` no plugin antigo e confira os membros do grupo pagante.
2. Instale/atualize este repositório. Configure `westan_vip_painel_color_field_id` com o mesmo ID antigo (padrão: `6`). Durante a coexistência temporária, o ID antigo tem precedência.
3. Confira `westan_vip_painel_group` e `westan_vip_painel_premium_group`. VIP resgatado nunca deve ser incluído automaticamente no grupo de pagantes.
4. Remova **somente a linha de clone do `vip-westan`** do `containers/app.yml`, mantendo a linha deste painel. Reconstrua o container pelo procedimento habitual do Discourse. Não apague o campo de usuário nem seus valores.
5. Recarregue o fórum e teste com um pagante, um VIP resgatado e um membro comum. Não mantenha os dois plugins carregados permanentemente: eles registram o mesmo serializer `user_vip_color`.

Nenhuma migração apaga dados. O painel lê/escreve o mesmo `user_field_<ID>` e continua expondo `user_vip_color`. As antigas escolhas `westan_vip_nickname_style_id` também têm fallback. O catálogo antigo permanece oculto apenas para essa compatibilidade.

Valores legados sem cores cadastradas são preservados, mas sua aparência continua dependendo do tema que os desenhava. Cadastre as cores correspondentes no catálogo novo antes de remover CSS antigo. Não remova indiscriminadamente outros componentes do Horizon.

## Catálogos e badge próprio

Administração em `/admin/plugins/westan-vip-painel`: catálogo de badges e mapeamentos de aparência das cores. O seletor usa exclusivamente as opções do campo de usuário original do `vip-westan` (mais `Padrão`, para limpar a escolha). Os mapeamentos e valores antigos salvos não adicionam opções ao seletor. Escolhas antigas são preservadas até o membro selecionar outra cor. O `value` do mapeamento corresponde ao texto normalizado do campo; `from` e `to` são hexadecimais `#RRGGBB`.

A prévia aplica as classes `vip-color-*` do tema original e inclui os mesmos gradientes como fallback. A aba ativa é lilás. Membros logados elegíveis a Premium veem a faixa “Você agora é premium” na home (`/` e seu acesso por `/latest`), com link para `/vip-painel`; visitantes, VIP resgatado, categorias e tópicos não a exibem.

Badge próprio: logo **opcional**, PNG/WEBP de **no mínimo 230×90 px**, e fundo **obrigatório**, PNG/JPG/GIF de **no mínimo 455×120 px**, até **5 MB por arquivo**, URLs HTTPS. Ambas as dimensões devem atingir o mínimo; imagens maiores e outras proporções são aceitas. Sem logo, o badge exibe apenas o fundo, sem texto sobreposto. O logo se ajusta sem distorção e o fundo preenche a área com recorte. O servidor inspeciona o conteúdo e as dimensões pelo downloader seguro do Discourse; URLs privadas/redirecionamentos não permitidos são bloqueados. As imagens continuam hospedadas na URL informada e devem permanecer disponíveis. O envio aplica diretamente o badge, sem fila de moderação.

O selo fica depois do nome nos posts, perfil e user card. Seu tooltip é montado fora do contêiner do nome para não ser cortado. Cores do painel seguem as variáveis do tema Discourse, sem um alternador próprio de light/dark.

## Verificação de desenvolvimento

Testes locais de regras com modelos simplificados:

```sh
ruby test/permissions_test.rb
NODE_PATH=/caminho/dev/node_modules node test/decorations.cjs
```

O segundo requer `jsdom`. Para compilar templates/estilos e gerar uma prévia interativa com dados simulados, instale em um diretório de desenvolvimento separado `sass`, `handlebars`, `content-tag` e `@glimmer/syntax`:

```sh
NODE_PATH=/caminho/dev/node_modules node scripts/preview.cjs /caminho/preview
```

As prévias não enviam alterações ao fórum. Testes HTTP reais precisam de uma instalação de desenvolvimento do Discourse e banco de testes:

```sh
LOAD_PLUGINS=1 bundle exec rspec plugins/discourse-westan-vip-painel/spec/requests/premium_panel_spec.rb
```

Antes de produção, verificar upload inválido/válido, permissões, atualização do post, user card, perfil, tema claro/escuro e remoção de grupo no Discourse/Horizon real.
