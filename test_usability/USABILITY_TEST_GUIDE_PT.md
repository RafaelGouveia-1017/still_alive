# StillAlive - Guia de Teste de Usabilidade 2026

## 1. Introdução

**StillAlive** é uma aplicação móvel de segurança pessoal, centrada no utilizador, que permite configurar um temporizador de segurança. O utilizador inicia o temporizador antes de sair de casa ou iniciar qualquer atividade solitária, e deve verificar-se (check-in) antes do tempo expirar. Caso o check-in não aconteça a tempo, o sistema dispara automaticamente um protocolo de emergência — enviando SMS, alertas via Telegram e/ou Discord aos contactos configurados, incluindo localização, nome do temporizador e registo do evento.

Além disso, a plataforma permite gerir contactos de emergência, personalizar mensagens, configurar integrações com plataformas de comunicação (Telegram, Discord), exportar/importar backups e consultar o histórico de eventos.

### O que é um teste de usabilidade?

Neste teste, vais explorar a aplicação StillAlive enquanto realizas um conjunto de tarefas do dia a dia. O foco **não está em avaliar as tuas capacidades**. Estamos a avaliar a aplicação. Não existem respostas certas ou erradas. Queremos observar como utilizas a plataforma de forma natural e perceber o que funciona bem e o que pode ser melhorado.

Agradecemos a tua participação neste teste de usabilidade da StillAlive. O teu contributo é essencial para melhorar a experiência da aplicação. Este documento explica, de forma simples, tudo o que precisas de saber antes de começar.

### Objetivo

O objetivo deste teste é identificar possíveis dificuldades de utilização, avaliar a clareza da interface e compreender como novos utilizadores interagem com a aplicação durante as primeiras sessões de uso, especialmente em contextos de configuração crítica (emergência, contactos, integrações). Os resultados recolhidos serão utilizados para identificar melhorias na experiência do utilizador e otimizar a usabilidade geral da aplicação.

<div class="page"/>

## 2. Antes de começar

### O que precisas

- Um telemóvel (sistema Android) com acesso à internet
- O link da aplicação: [Google Play](https://play.google.com/store/apps/details?id=com.appsbyrafa.stillalive)
- Cerca de **15 a 30 minutos** disponíveis, sem interrupções
- Uma conta **Discord** ou **Telegram** para testes de integração _(opcional)_

### Recomendações

- Fecha outras aplicações desnecessários antes de começar
- Ativa o **modo avião e desativa-o** se quiseres testar SMS
- Não é necessária preparação prévia — **não leias manuais nem tutoriais antes do teste**
- Tens liberdade para explorar a aplicação entre tarefas
- Se tiveres dúvidas, pergunta em voz alta — é parte do teste

> **Privacidade**
> Nenhum dado pessoal é recolhido ou utilizado para fins comerciais.

<div class="page"/>

## 3. Como funciona a sessão

A sessão está dividida em tarefas que seguem o percurso natural de um novo utilizador na **StillAlive**.

Primeiro executamos o **percurso essencial** (15–30 min). Se houver tempo, seguimos para tarefas opcionais.

### Percurso essencial (obrigatório)

| Passo | Tarefa                           | Objetivo                                      | Critério de sucesso                             | Duração |
| ----- | -------------------------------- | --------------------------------------------- | ----------------------------------------------- | ------- |
| 1     | Splash → Onboarding → Home       | Avaliar primeiro contacto com a app           | Utilizador chega à Home sem ajuda               | 1–2 min |
| 2     | Adicionar primeiro contacto      | Testar persistência de contactos              | Contacto visível na lista                       | 1–3 min |
| 3     | Configurar temporizador          | Validar fluxo de configuração do temporizador | temporizador ativo com anel de contagem visível | 3–6 min |
| 4     | Verificar check-in               | Medir facilidade do gesto principal           | Check-in realizado em menos de 30 seg           | 1-3 min |
| 5     | Cancelar / pausar o temporizador | Avaliar comportamento em desativação          | temporizador cancelado com feedback visual      | 0-1 min |

<b>Total estimado: 13–20 min</b>

### Percurso complementar (opcional)

| Passo | Tarefa                                 | Objetivo                               | Critério de sucesso                    | Duração |
| ----- | -------------------------------------- | -------------------------------------- | -------------------------------------- | ------- |
| 6     | Configurar integração Telegram/Discord | Avaliar fluxo de setup de integrações  | Integração ativa e testada com sucesso | 5–7 min |
| 7     | Personalizar mensagem de alerta        | Testar customização do conteúdo        | Mensagem personalizada salva           | 2–5 min |
| 8     | Consultar histórico de eventos         | Medir clareza da informação histórica  | Utilizador identifica eventos e estado | 2–5 min |
| 9     | Testar backup/restore                  | Validar fluxo de exportação/importação | Backup gerado e importado              | 1–3 min |

<b>Extra estimado: 20–30 min</b>

<div class="page"/>

## 4. Os 9 passos do teste

Para cada passo, tens uma lista de tarefas a realizar.

<table>
    <tr>
        <th colspan="3" style="text-align: left; font-size: 22px;">Passo 1 — Splash → Onboarding → Home</th>
    </tr>
    <tr>
        <th>Tarefas</th>
        <th>Métricas de sucesso</th>
        <th>Pontos a observar</th>
    </tr>
    <tr>
        <td>
        <ul>
            <li>Encontrar o botão de "Começar" ou equivalente no onboarding</li>
            <li>Avançar por todas as páginas de onboarding sem ajuda</li>
            <li>Identificar a navegação inferior (Home, Contactos, Histórico, Integrações, Definições)</li>
            <li>Regressar à app após fechar e verificar o estado</li>
        <ul>
        </td>
        <td>
        <ul style="list-style-type: '✓ ';">
            <li>Chega ao dashboard em menos de 2 min</li>
            <li>Nenhuma dúvida na navegação inicial</li>
            <li>Reconhece o estado do temporizador (ativo/inativo)</li>
        <ul>
        </td>
        <td>
        <ul style="list-style-type: none;">
            <li>! Confusão nas páginas de onboarding</li>
            <li>? Linguagem das instruções clara?</li>
            <li>? Ícones da bottom nav reconhecíveis?</li>
        <ul>
        </td>
    </tr>
</table>

<table> <tr> <th colspan="3" style="text-align: left; font-size: 22px;">Passo 2 — Adicionar primeiro contacto rápido</th> </tr> <tr> <th>Tarefas</th> <th>Métricas de sucesso</th> <th>Pontos a observar</th> </tr> <tr> <td> <ul> <li>Navegar até Contactos a partir da bottom nav</li> <li>Encontrar um contacto (pode pesquisar por nome ou telefone)</li> <li>Adicionar contacto na lista de contactos rápidos</li> <li>Verificar que o contacto recebe o estado de contacto rápido</li> <li>Voltar a Home e verificar que o contacto se encontra na lista</li> </ul> </td> <td> <ul style="list-style-type: '✓ ';"> <li>Encontra a secção de contactos em menos de 30 seg</li> <li>Contacto adicionado e visível na lista após guardar</li> <li>Feedback visual claro após guardar</li> </ul> </td> <td> <ul style="list-style-type: none;"> <li>! Utilizador procura o botão "Adicionar" no sítio errado</li> <li>? Diferença entre contactos pouco clara</li> <li>? Avatar com iniciais / cor gerada automaticamente — intuitivo?</li> </ul> </td> </tr> </table>

<table> <tr> <th colspan="3" style="text-align: left; font-size: 22px;">Passo 3 — Configurar temporizador</th> </tr> <tr> <th>Tarefas</th> <th>Métricas de sucesso</th> <th>Pontos a observar</th> </tr> <tr> <td> <ul> <li>Tap no botão de iniciar / criar temporizador</li> <li>Escolher duração (ex: 30 minutos)</li> <li>Adicionar destinatários (contactos + integrações)</li> <li>Personalizar mensagem de emergência <em>(opcional)</em></li> <li>Iniciar o temporizador</li> </ul> </td> <td> <ul style="list-style-type: '✓ ';"> <li>Configura e inicia o temporizador em menos de 4 min</li> <li>Anel de contagem visível e legível</li> <li>Estado "ativo" claro na UI</li> </ul> </td> <td> <ul style="list-style-type: none;"> <li>! Confusão entre "duração" e "tempo de tolerância"</li> <li>? Lógica de múltiplos destinatários (SMS + Telegram) clara?</li> <li>? Personalização da mensagem de emergência — acessível?</li> </ul> </td> </tr> </table>

<table> <tr> <th colspan="3" style="text-align: left; font-size: 22px;">Passo 4 — Cancelar o temporizador</th> </tr> <tr> <th>Tarefas</th> <th>Métricas de sucesso</th> <th>Pontos a observar</th> </tr> <tr> <td> <ul> <li>Com o temporizador ativo, encontrar o botão de "Cancelar"</li> <li>Observar o feedback visual após o cancelamento</li> <li>Verificar se o estado do temporizador muda</li> </ul> </td> <td> <ul style="list-style-type: '✓ ';"> <li>Cancelamento realizado em menos de 30 segundos</li> <li>Feedback visual claro após o cancelamento (ex: anel volta ao início, notificação)</li> <li>Estado do temporizador atualizado corretamente</li> </ul> </td> <td> <ul style="list-style-type: none;"> <li>! Botão de cancelamento em local inesperado</li> <li>? O utilizador percebe que o temporizador foi "resetado" ou "concluído"?</li> <li>? Feedback auditivo/tátil presente e útil?</li> </ul> </td> </tr> </table>

<table> <tr> <th colspan="3" style="text-align: left; font-size: 22px;">Passo 5 — Pausar o temporizador</th> </tr> <tr> <th>Tarefas</th> <th>Métricas de sucesso</th> <th>Pontos a observar</th> </tr> <tr> <td> <ul> <li>Iniciar um novo temporizador</li> <li>Decidir pausá-lo após alguns minutos</li> <li>Procurar o botão de pausa</li> <li>Observar o comportamento após pausa (histórico, estado)</li> </ul> </td> <td> <ul style="list-style-type: '✓ ';"> <li>Pausa o temporizador em menos de 2 minutos</li> <li>Feedback visual claro após pausar</li> <li>Histórico atualizado corretamente</li> </ul> </td> <td> <ul style="list-style-type: none;"> <li>! Confusão entre "cancelar" e "pausar"</li> <li>? É claro que o temporizador foi pausado (e não um cancelamento falso)?</li> <li>? A password de proteção (se configurada) é solicitada?</li> </ul> </td> </tr> </table>

<table> <tr> <th colspan="3" style="text-align: left; font-size: 22px;">Passo 6 — Configurar integração Telegram/Discord</th> </tr> <tr> <th>Tarefas</th> <th>Métricas de sucesso</th> <th>Pontos a observar</th> </tr> <tr> <td> <ul> <li>Navegar até Integrações</li> <li>Selecionar Telegram ou Discord</li> <li>Introduzir o Bot Token</li> <li>Testar a conexão</li> <li>Observar o estado "ativo" / "falhado"</li> </ul> </td> <td> <ul style="list-style-type: '✓ ';"> <li>Conecta à integração em menos de 6 min</li> <li>Estado da integração visível (ativo/falhado)</li> <li>Teste de mensagem realizado com sucesso</li> </ul> </td> <td> <ul style="list-style-type: none;"> <li>! Confusão entre "token" e "ID do bot"</li> <li>? O utilizador sabe onde encontrar o token (ex: @BotFather)?</li> <li>? Mensagens de erro claras quando o token está inválido?</li> </ul> </td> </tr> </table>

<table> <tr> <th colspan="3" style="text-align: left; font-size: 22px;">Passo 7 — Personalizar mensagem de alerta</th> </tr> <tr> <th>Tarefas</th> <th>Métricas de sucesso</th> <th>Pontos a observar</th> </tr> <tr> <td> <ul> <li>Navegar até Definições → Mensagem de Emergência</li> <li>Inserir uma nova mensagem padrão</li> <li>Guardar e verificar</li> </ul> </td> <td> <ul style="list-style-type: '✓ ';"> <li>Editou e guardou a mensagem em menos de 3 min</li> <li>Mensagem personalizada aparece nos testes</li> </ul> </td> <td> <ul style="list-style-type: none;"> <li>! Utilizador procura a opção no sítio errado</li> <li>? Limite de caracteres indicado?</li> </ul> </td> </tr> </table>

<table> <tr> <th colspan="3" style="text-align: left; font-size: 22px;">Passo 8 — Consultar histórico de eventos</th> </tr> <tr> <th>Tarefas</th> <th>Métricas de sucesso</th> <th>Pontos a observar</th> </tr> <tr> <td> <ul> <li>Navegar até Histórico</li> <li>Identificar eventos recentes</li> <li>Distinguir entre "temporizador concluído" e "alerta enviado"</li> <li>Tocar num evento para ver detalhes (hora, destino, localização)</li> </ul> </td> <td> <ul style="list-style-type: '✓ ';"> <li>Encontra o histórico em menos de 30 seg</li> <li>Compreende o estado de cada evento</li> <li>Detalhes legíveis ao tocar num evento</li> </ul> </td> <td> <ul style="list-style-type: none;"> <li>! Confusão entre "alerta" e "check-in"</li> <li>? Cores / ícones que distinguem estados claros?</li> <li>? Localização exibida de forma útil?</li> </ul> </td> </tr> </table>

<table> <tr> <th colspan="3" style="text-align: left; font-size: 22px;">Passo 9 — Testar backup / restore</th> </tr> <tr> <th>Tarefas</th> <th>Métricas de sucesso</th> <th>Pontos a observar</th> </tr> <tr> <td> <ul> <li>Navegar até Definições → Backup</li> <li>Exportar o backup</li> <li>Verificar que o ficheiro é criado</li> <li><em>(Opcional)</em> Criar um novo temporizador e re-importar o backup</li> </ul> </td> <td> <ul style="list-style-type: '✓ ';"> <li>Exporta o backup em menos de 3 min</li> <li>Ficheiro de backup criado e acessível</li> <li>Reimportação funcional (se testada)</li> </ul> </td> <td> <ul style="list-style-type: none;"> <li>! Confusão entre "exportar" e "importar"</li> <li>? Formato do ficheiro (.zip) claro?</li> <li>? O utilizador percebe onde o ficheiro é guardado?</li> </ul> </td> </tr> </table>

<div class="page"/>

## 5. Exploração Autónoma

Após a conclusão das tarefas principais, o utilizador terá alguns minutos para explorar livremente a aplicação **StillAlive**. O objetivo desta fase é observar o comportamento natural do utilizador quando não existem instruções específicas, permitindo perceber quais funcionalidades despertam mais interesse e como o utilizador navega pela aplicação de forma espontânea.

Durante este período, o utilizador pode:

- Aceder a qualquer secção da aplicação
- Explorar definições avançadas (temas, localização, QR Code)
- Repetir ações realizadas anteriormente
- Tentar funcionalidades que não foram apresentadas

Esta fase ajuda a identificar se a estrutura da aplicação é intuitiva e se os elementos da interface incentivam a exploração e descoberta de funcionalidades.

<div class="page"/>

## 6. Questionário Pós-Teste

Após concluir todas as tarefas e a fase de exploração, pedimos ao participante que responda a um pequeno questionário de usabilidade. O objetivo deste questionário é recolher a opinião do utilizador sobre a sua experiência geral com a aplicação, incluindo aspetos relacionados com a facilidade de utilização, clareza da interface e satisfação global.

As respostas fornecidas ajudarão a equipa de desenvolvimento a compreender melhor a experiência dos utilizadores e a identificar possíveis melhorias na aplicação.

**Link do questionário:**
<https://forms.gle/xDBuvY5upay8Rb479>

O questionário demora aproximadamente **3 a 6 minutos** a completar e todas as respostas serão utilizadas apenas para fins de avaliação e melhoria da plataforma.

Agradecemos novamente a tua participação e o contributo para melhorar a experiência da **StillAlive**.
