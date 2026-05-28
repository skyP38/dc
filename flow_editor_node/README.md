# flow_editor_node

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


`shell.nix` - необходимые пакеты для NixOs (`nix-shell`)

Перед сборкой рекоммендуется:
```bash
flutter pub get
```

Под Linux:
```bash
flutter runn -d linux
```

Web-версия:
```bash
flutter run -d web-server --web-hostname localhost --web-port 8080
```

Если что-то перестало работать или нужно пересобрать под новую платформу:
```bash
flutter doctor
```
