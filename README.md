## Как работать с определенным подкаталогом из репозитория

```bash
# Клонирование удаленного репозитория с частичным клонированием
git clone --filter=blob:none --no-checkout https://github.com/skyP38/dc.git
cd dc/
# Выбор подкаталога для работы
git sparse-checkout set flow_editor_node
git checkout
```
