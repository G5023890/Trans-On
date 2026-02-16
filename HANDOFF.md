# Handoff: SelectedTextOverlay / Trans-On

## Текущее состояние
- Проект: macOS Swift app (`AppKit`), SPM package `SelectedTextOverlay`.
- Рабочая директория: `/Users/grigorymordokhovich/Documents/Develop/Selected text`.
- Git не настроен в этой папке (`not a git repo`).

## Что уже реализовано
- Глобальный хоткей для захвата выделенного текста из активного приложения.
- Эмуляция `Cmd+C`, чтение clipboard, восстановление исходного содержимого clipboard.
- Оверлей-окно с тёмным полупрозрачным фоном, закрытие по `Esc`.
- Меню в статус-баре macOS.
- Окно настроек:
  - выбор клавиши (A-Z),
  - выбор модификаторов (`Command/Shift/Option/Control`),
  - размер шрифта,
  - автозапуск при логине.
- Сохранение настроек в `UserDefaults`.
- Перевод в русский через endpoint `translate.googleapis.com/translate_a/single` (неофициальный).
- Если текст уже содержит кириллицу, перевод не выполняется.

## Сборка и установка
- Скрипт: `scripts/build_and_install_app.sh`.
- Имя app: `Trans-On.app`.
- Сборка release, упаковка `.app`, копирование иконки, codesign, установка в `/Applications/Trans-On.app`.

## Важные файлы
- `Sources/SelectedTextOverlay/main.swift` — основная логика приложения.
- `scripts/build_and_install_app.sh` — сборка/установка/подпись app.
- `README.md` — описание запуска и прав в macOS.
- `QUESTIONS_AND_ANSWERS.md` — заметки по Google Translate API и ценам.

## Технический долг / риски
- Используется неофициальный Google Translate endpoint (`client=gtx`) — риск нестабильности/ограничений.
- Нет git-истории и commit-based handoff.
- Нет автотестов.

## Что логично делать дальше
1. Перейти на официальный Cloud Translation API (через backend/proxy).
2. Добавить обработку ошибок сети/лимитов и сообщения пользователю.
3. Инициализировать git-репозиторий для нормального трекинга изменений.
4. Добавить минимальные smoke/интеграционные проверки.
