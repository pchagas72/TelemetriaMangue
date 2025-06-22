# Telemetria-Mangue

Um programa da equipe Mangue-Baja que recebe dados em tempo real de nossos servidores e carros, por rádio.

## Sobre quick fixes e avisos

O código pode muito bem quebrar apenas por movê-lo dentro do seu sistema, portanto, boas práticas são:

- Executar _flutter clean_ e _flutter doctor_ sempre que for executar, compilar ou editar o código.
- Boas práticas com git, clonar e fazer o pull requests necessários. Não bagunçar os arquivos.
- Boas práticas com Dart, afinal, warnings podem se tornar erros.

## Sobre as dependências

Para entender de fato as dependências do programa, estude o arquivo ./pubspec.yaml, é lá que as dependências são declaradas.

Sobre as versões essenciais:

- fl\_chart, essa biblioteca PRECISA estar na versão 0.66.2, pois, após esta versão, houveram atualizações que mudam a sintaxe da biblioteca.
- Pelo tópico passado, faz-se necessário atualizar o código.

## Sobre os afazeres (todo):

Esta lista está em ordem de _prioridade_.

- Wrapper para android.
- Adicionar debugger.
- Implementar documentação.
- Atualizar código para adaptar-se à versões mais recentes das bibliotecas.
