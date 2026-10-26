# 📚 MyBookShelf - Gestor de Biblioteca Pessoal

O **MyBookShelf** é um aplicativo desenvolvido em Flutter para ajudar leitores a organizarem sua coleção de livros e, principalmente, manterem o hábito de leitura em dia através de um sistema de metas inteligentes.

O app funciona como uma biblioteca virtual (catálogo) e também como um "Personal Trainer" de leitura, calculando o ritmo necessário para terminar seus livros no prazo desejado.

## ✨ Funcionalidades Principais

### 📖 Gestão de Biblioteca

* **Cadastro Completo:** Título, Autor, Editora, Gênero, Preço, Nº de Páginas e Data de Compra.
* **Capa do Livro:** Adicione fotos usando a Câmera ou a Galeria do celular.
* **Status de Leitura:** Classificação automática em "Fila", "Lendo" e "Lidos".
* **Cadastro Rápido:** Opção "Já li este livro" para cadastrar coleções antigas rapidamente.
* **Busca:** Filtro rápido por título ou autor.

### 🚀 Tracker de Leitura Inteligente

* **Fluxo de Leitura:** Inicie um livro definindo uma meta e pause quando necessário (a meta é reajustada automaticamente).
* **Cálculo de Ritmo:** O app diz quantas páginas você precisa ler por dia para atingir a meta.
* **Indicadores de Urgência:**
  * 🟢 **Verde:** Ritmo tranquilo.
  * 🟠 **Laranja:** Necessário acelerar um pouco (> 30 pág/dia).
  * 🔴 **Vermelho:** Atrasado ou meta irrealista (> 100 pág/dia).
  * ⚫ **Cinza:** Leitura pausada.

### 📊 Dashboard e Histórico

* **Contadores:** Visualize rapidamente quantos livros tem no total, quantos está lendo e quantos já leu.
* **Histórico de Sessões:** Registro detalhado de cada vez que você leu (Data e página parada).
* **Avaliação:** Ao terminar, dê uma nota (1 a 5 estrelas) e escreva uma resenha.

### 💬 Citações (Quotes)
* **Guarde momentos marcantes:** Registre frases e trechos que te impactaram durante a leitura.
* **Referência rápida:** Salve o texto e o número da página para encontrar facilmente depois.
* **Coleção pessoal:** Visualize todas as suas citações salvas diretamente na tela de detalhes de cada livro.

### 📱 Leitor de eBooks Integrado (Novo!)

* **Suporte a Arquivos:** Importe seus livros digitais nos formatos **PDF** e **EPUB** diretamente do armazenamento do celular.
* **Leitura Interna:** Leia seus livros dentro do próprio app, sem necessidade de aplicativos externos.
* **Marcador Automático:** O app salva automaticamente a página onde você parou. Ao abrir o livro novamente, você continua exatamente do mesmo ponto.
* **Registro de Sessões:** Ao fechar o leitor, o app calcula quantas páginas foram lidas e cria um registro automático no seu "Histórico de Leitura".
* **Metadados:** O sistema identifica automaticamente o total de páginas do arquivo PDF/EPUB no momento do cadastro.

### ⚙️ Utilitários

* **Backup e Restauração:** Exporte seu banco de dados para o Google Drive/WhatsApp e restaure em outro celular.
* **Modo Escuro (Dark Mode):** Alternância de tema para leitura confortável à noite.

## 🛠️ Tecnologias Utilizadas

* **Linguagem:** Dart
* **Framework:** Flutter
* **Banco de Dados:** SQLite (via `sqflite`)
* **Pacotes Principais:**
  * `image_picker`: Acesso à câmera e galeria.
  * `flutter_rating_bar`: Sistema de avaliação por estrelas.
  * `intl`: Formatação de datas.
  * `share_plus`: Exportação de arquivos de backup.
  * `file_picker`: Importação de arquivos de backup.
  * `flutter_launcher_icons`: Gerenciamento de ícone do app.


## 🚀 Como Rodar o Projeto

Pré-requisitos: Ter o [Flutter SDK](https://docs.flutter.dev/get-started/install "null") instalado.

1. **Clone o repositório:**

   ```
   git clone https://github.com/PatrickGCS/MyBookShelf.git
   cd MyBookShelf
   ```
2. **Baixe as dependências:**

   ```
   flutter pub get
   ```
3. **Execute o App:**

   * Conecte seu celular Android via USB ou abra o Emulador.
   * Rode o comando:

   ```
   flutter run
   ```


## 📱 Gerando o APK (Android)

Para instalar no seu celular de forma definitiva:

1. Execute no terminal:
   ```
   flutter build apk --release
   ```
2. O arquivo estará em: `build/app/outputs/flutter-apk/app-release.apk`

## 🤝 Contribuição

Sinta-se à vontade para fazer um fork deste projeto e enviar Pull Requests. Sugestões de novas funcionalidades como "Gráfico de leitura mensal" ou "Notificações de lembrete" são bem-vindas!

## 📄 Licença e Uso

Este projeto está licenciado sob a licença **Creative Commons Atribuição-NãoComercial-CompartilhaIgual 4.0 Internacional (CC BY-NC-SA 4.0)** .

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Licença Creative Commons" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a>

### ✅ O que você PODE fazer:

* **Compartilhar:** Copiar e redistribuir o material em qualquer suporte ou formato.
* **Adaptar:** Remixar, transformar e criar a partir do material.
* **Estudo:** Usar este código para aprender Flutter e SQLite.

### 🚫 O que você NÃO PODE fazer:

* **Uso Comercial:** Você **não pode** usar o material para fins comerciais (Vender o app, colocar anúncios, vender o código fonte).
* **Sem Atribuição:** Se você compartilhar, deve dar o crédito apropriado.

Para ver o texto completo da licença, visite [Creative Commons 4.0 Legal Code](https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.pt "null").

Desenvolvido com 💙 em Flutter




