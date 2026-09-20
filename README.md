# discourse-westan-vip-painel

Plugin Discourse **Ajustes do Premium**. Integra as cores do antigo `vip-westan` ao painel, preservando `/vip-painel` e os campos salvos.

## Acesso

| Membro | Recursos |
| --- | --- |
| Assinante no grupo `westan_vip_painel_premium_group` | Cores, selo verificado, título, catálogo de badges e badge próprio |
| VIP apenas no grupo `westan_vip_painel_group` | Escolha da cor, na tela **Ajustes da cor** |
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

Administração em `/admin/plugins/westan-vip-painel`: catálogo de badges e paleta única de cores. O `value` da cor corresponde ao texto normalizado do antigo campo de usuário; `from` e `to` são cores hexadecimais `#RRGGBB`.

Badge próprio: logo PNG/WEBP **230×90 px** e fundo PNG/JPG/GIF **455×120 px**, até **5 MB por arquivo**, URLs HTTPS. O servidor inspeciona o conteúdo e as dimensões pelo downloader seguro do Discourse; URLs privadas/redirecionamentos não permitidos são bloqueados. As imagens continuam hospedadas na URL informada e devem permanecer disponíveis. O envio aplica diretamente o badge, sem fila de moderação.

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
