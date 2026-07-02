# Estrutura do Projeto WYD 7.54 (Ziglang)

Este documento descreve a estrutura do projeto open-source para o servidor do jogo WYD versão 7.54, desenvolvido em Ziglang.

## Visão Geral

O projeto é modularizado para facilitar o desenvolvimento e a manutenção, separando as responsabilidades de comunicação, lógica de negócio, persistência de dados e a lógica de jogo scriptável.

## Módulos Principais

### 1. `server` (Servidor de Comunicação)

*   **Função:** É o módulo principal do servidor, responsável pela comunicação direta com os clientes do jogo. Ele gerencia as conexões, o envio e recebimento de pacotes de dados, e a coordenação geral das interações entre cliente e servidor.
*   **Tecnologia:** Desenvolvido em Ziglang, aproveitando as capacidades de concorrência e baixo nível para um desempenho eficiente.

### 2. `core` (Entidades de Domínio)

*   **Função:** Contém as entidades de domínio fundamentais do projeto. Estas são as estruturas de dados que representam os elementos chave do jogo e do sistema.
*   **Conteúdo:**
    *   **`Account`:** Representa as contas de usuário, incluindo informações como login, senha (hash), status, e quaisquer outros dados relacionados à conta.
    *   **`Character`:** Representa os personagens dos jogadores, contendo atributos como nome, classe, nível, inventário, posição no mapa, etc.
    *   Outras entidades de domínio relevantes para o funcionamento do jogo.
*   **Tecnologia:** Implementado em Ziglang, garantindo tipos seguros e controle de memória.

### 3. `db` (Camada de Persistência de Dados)

*   **Função:** Este módulo define as interfaces e implementações para a comunicação com diferentes sistemas de banco de dados. Ele abstrai a lógica de persistência, permitindo que o restante do projeto interaja com os dados de forma uniforme, independentemente do backend de armazenamento.
*   **Implementações Atuais:**
    *   **`filedb`:** Atualmente, a única implementação disponível, responsável pela persistência de dados via arquivos no sistema de arquivos local. Isso é útil para prototipagem e desenvolvimento inicial, ou para cenários onde um banco de dados relacional completo não é necessário.
*   **Extensibilidade:** Projetado para permitir futuras implementações de drivers para bancos de dados mais robustos (ex: PostgreSQL, SQLite, MySQL) conforme a necessidade do projeto.
*   **Tecnologia:** Ziglang.

### 4. `brain` (Lógica de Jogo)

*   **Função:** Este é o coração da lógica de jogo, onde as regras e comportamentos específicos do jogo são definidos e executados em resposta a eventos.
*   **Linguagem de Script:** As lógicas de jogo são escritas em **Lua**. Isso oferece grande flexibilidade e permite que desenvolvedores ou designers de jogo ajustem o comportamento do jogo sem a necessidade de recompilar o servidor principal.
*   **Integração:** O módulo `brain` integra um interpretador Lua que executa os scripts definidos a cada evento que ocorre no jogo (ex: movimento de personagem, uso de item, interação com NPC, ataque, etc.).
*   **Eventos:** O `server` dispara eventos que o `brain` processa, aplicando as regras definidas nos scripts Lua.
*   **Tecnologia:** Ziglang para o motor de integração e chamadas aos scripts Lua.
