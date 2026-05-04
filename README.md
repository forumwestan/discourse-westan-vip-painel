# discourse-westan-vip-painel

Plugin Discourse independente para o **Painel VIP** da Westan.

## O que ele faz

- Cria a rota `/vip-painel`.
- Mostra o painel apenas para membros do grupo configurado, por padrão `vip`.
- Permite que o membro VIP escolha:
  - tema/badge;
  - estilo de nickname;
  - exibir/ocultar badge;
  - exibir/ocultar card personalizado;
  - título personalizado do perfil.
- Aplica nos tópicos:
  - cor/degradê do nickname;
  - badge ao lado das informações do post;
  - título personalizado abaixo do nome.

## Configuração

Em **Admin → Settings → Plugins**:

| Setting | Descrição |
|---|---|
| `westan_vip_painel_enabled` | Habilita o plugin |
| `westan_vip_painel_group` | Grupo que pode acessar o painel, por padrão `vip` |
| `westan_vip_painel_themes_json` | Catálogo JSON dos temas/badges |
| `westan_vip_painel_nickname_styles_json` | Catálogo JSON das cores/degradês do nickname |

## Instalação

No `app.yml` do Discourse:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/forumwestan/discourse-westan-vip-painel.git
```

Depois:

```bash
cd /var/discourse
./launcher rebuild app
```

## Desativar plugin antigo

Quando este plugin estiver validado, remova ou comente o antigo:

```text
https://github.com/forumwestan/vip-westan
```

Depois rode outro rebuild.
