# my-sysadmin-scripts

Скрипт `script.sh` раз в 10 секунд снимает `free -h`, `df -h` и `uptime` и дописывает их в `monitor.log` блоком с временной меткой.

## Запуск

```bash
./script.sh
MAX_ITERATIONS=3 ./script.sh
LOG_FILE=/tmp/monitor.log ./script.sh
```

- `MAX_ITERATIONS` - сколько замеров сделать, по умолчанию 0 (без ограничения).
- `LOG_FILE` - куда писать, по умолчанию `monitor.log` в текущем каталоге.
- Остановка: Ctrl+C или `kill`, в лог допишется строка об остановке.

Пример вывода - в `sample_output.txt`.
